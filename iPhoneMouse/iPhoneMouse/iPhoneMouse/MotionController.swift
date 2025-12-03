import Foundation
import ARKit
import CoreMotion
import Combine

class MotionController: NSObject, ObservableObject {
    var arSession: ARSession? {
        return _arSession
    }

    private var _arSession: ARSession?
    private var referenceTransform: simd_float4x4?

    private var motionManager: CMMotionManager?
    private var timer: Timer?
    private var velocityX: Double = 0.0
    private var velocityY: Double = 0.0
    private var lastUpdateTime: Date?
    private var imuReference: CMAttitude?
    private var imuCalibrationOffset: (roll: Double, pitch: Double) = (0, 0)
    @Published var isCalibrated: Bool = false

    // Smoothing filter (exponential moving average)
    private var smoothedDeltaX: Double = 0.0
    private var smoothedDeltaY: Double = 0.0
    private let smoothingFactor: Double = 0.7  // 0.0 = no smoothing, 1.0 = full smoothing

    // Controller mode
    private var controllerTimer: Timer?
    private var controllerDirection: (x: Int, y: Int) = (0, 0)
    private let controllerSpeed: Double = 5.0  // pixels per update

    weak var bluetoothManager: BluetoothManager?
    weak var multipeerManager: MultipeerManager?

    private var sensitivity: Double {
        SettingsManager.shared.sensitivity
    }
    private let minMovement: Double = 0.5
    private let damping: Double = 0.85
    private let minAcceleration: Double = 0.01

    override init() {
        super.init()
    }

    func startMotionUpdates() {
        let controlMode = SettingsManager.shared.controlMode

        switch controlMode {
        case .motion:
            let sensorType = SettingsManager.shared.sensorType
            switch sensorType {
            case .arkit:
                startARKit()
            case .imu:
                startIMU()
            }
        case .controller:
            startControllerMode()
        }
    }

    private func startARKit() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("⚠ ARKit not supported on this device")
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        }

        _arSession = ARSession()
        _arSession?.delegate = self

        _arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func startIMU() {
        stopMotionUpdates()

        motionManager = CMMotionManager()
        guard let motionManager = motionManager, motionManager.isDeviceMotionAvailable else {
            print("⚠ Device motion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        lastUpdateTime = Date()

        timer = Timer.scheduledTimer(withTimeInterval: motionManager.deviceMotionUpdateInterval, repeats: true) { [weak self] _ in
            self?.processIMUMotion()
        }
    }

    func stopMotionUpdates() {
        _arSession?.pause()
        _arSession = nil
        referenceTransform = nil

        motionManager?.stopDeviceMotionUpdates()
        timer?.invalidate()
        timer = nil
        motionManager = nil

        controllerTimer?.invalidate()
        controllerTimer = nil
        controllerDirection = (0, 0)

        velocityX = 0.0
        velocityY = 0.0
        lastUpdateTime = nil
        isCalibrated = false
        imuReference = nil
        imuCalibrationOffset = (0, 0)
        smoothedDeltaX = 0.0
        smoothedDeltaY = 0.0
    }

    func resetReference() {
        referenceTransform = nil
        velocityX = 0.0
        velocityY = 0.0
    }

    func calibrateIMU() {
        guard let motionManager = motionManager,
              let deviceMotion = motionManager.deviceMotion else {
            return
        }

        // Store reference attitude for calibration
        let attitude = deviceMotion.attitude
        imuReference = attitude.copy() as? CMAttitude
        imuCalibrationOffset = (attitude.roll, attitude.pitch)

        // Reset velocities when calibrating
        velocityX = 0.0
        velocityY = 0.0

        // Mark as calibrated (session-only, not persisted)
        isCalibrated = true
    }

    func updateSensorType() {
        stopMotionUpdates()
        startMotionUpdates()
    }

    func updateSensitivity() {
        // Sensitivity is read from SettingsManager.shared, no action needed
    }

    func updateVisualization() {
        // Visualization is handled by ARVisualizationView, no action needed
    }

    private func processIMUMotion() {
        guard let motionManager = motionManager,
              let deviceMotion = motionManager.deviceMotion,
              let lastTime = lastUpdateTime else {
            return
        }

        let currentTime = Date()
        let deltaTime = currentTime.timeIntervalSince(lastTime)
        lastUpdateTime = currentTime

        guard deltaTime > 0 else { return }

        let userAcceleration = deviceMotion.userAcceleration
        var accelX = userAcceleration.x
        var accelY = userAcceleration.y

        // Apply calibration offset if calibrated
        // The offset accounts for phone case tilt and uneven surfaces
        if let reference = imuReference {
            // Get current attitude
            let currentAttitude = deviceMotion.attitude

            // Calculate relative attitude change from calibration reference
            // This gives us the change in orientation since calibration
            let relativeAttitude = currentAttitude.copy() as! CMAttitude
            relativeAttitude.multiply(byInverseOf: reference)

            // Get the roll and pitch differences from calibration
            let rollDiff = relativeAttitude.roll
            let pitchDiff = relativeAttitude.pitch

            // Compensate for static tilt: if phone is tilted, gravity affects acceleration
            // Subtract the tilt component to get pure movement acceleration
            // The sin() of the angle gives us the gravity component in that axis
            accelX -= sin(rollDiff) * 0.15  // Compensate for roll tilt
            accelY -= sin(pitchDiff) * 0.15  // Compensate for pitch tilt
        }

        if abs(accelX) < minAcceleration && abs(accelY) < minAcceleration {
            velocityX *= damping
            velocityY *= damping
        } else {
            velocityX += accelX * deltaTime * sensitivity
            velocityY += accelY * deltaTime * sensitivity
        }

        if abs(velocityX) > minMovement || abs(velocityY) > minMovement {
            sendMovement(deltaX: velocityX, deltaY: velocityY)
            velocityX = 0.0
            velocityY = 0.0
        }
    }

    private func sendMovement(deltaX: Double, deltaY: Double) {
        // Send raw movement data - Mac will handle all smoothing/interpolation
        if let bluetoothManager = bluetoothManager, bluetoothManager.isConnected {
            bluetoothManager.sendMovement(deltaX: deltaX, deltaY: deltaY)
        } else if let multipeerManager = multipeerManager, multipeerManager.isConnected {
            multipeerManager.sendMovement(deltaX: deltaX, deltaY: deltaY)
        }
    }

    // MARK: - Controller Mode
    private func startControllerMode() {
        stopMotionUpdates()

        controllerTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.processControllerMovement()
        }
    }

    private func processControllerMovement() {
        guard controllerDirection.x != 0 || controllerDirection.y != 0 else { return }

        let deltaX = Double(controllerDirection.x) * controllerSpeed
        let deltaY = Double(controllerDirection.y) * controllerSpeed

        sendMovement(deltaX: deltaX, deltaY: deltaY)
    }

    func setControllerDirection(x: Int, y: Int) {
        controllerDirection = (x, y)
    }
}

extension MotionController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard SettingsManager.shared.sensorType == .arkit else { return }

        let cameraTransform = frame.camera.transform

        if referenceTransform == nil {
            referenceTransform = cameraTransform
            return
        }

        guard let reference = referenceTransform else { return }

        let deltaTransform = simd_mul(simd_inverse(reference), cameraTransform)
        let translation = deltaTransform.columns.3

        let deltaX = Double(translation.x) * sensitivity
        let deltaY = Double(translation.y) * sensitivity

        sendMovement(deltaX: deltaX, deltaY: -deltaY)

        referenceTransform = cameraTransform
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("✗ ARKit error: \(error.localizedDescription)")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("⚠ ARKit session interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("✓ ARKit session resumed")
    }
}

