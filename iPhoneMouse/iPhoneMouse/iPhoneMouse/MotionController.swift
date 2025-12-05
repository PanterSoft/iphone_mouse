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
    private var lastUpdateTime: Date?
    private var imuReference: CMAttitude?
    @Published var isCalibrated: Bool = false

    // For XY plane mode: track last position to calculate deltas
    private var lastRoll: Double = 0.0
    private var lastPitch: Double = 0.0

    // Controller mode
    private var controllerTimer: Timer?
    private var controllerDirection: (x: Int, y: Int) = (0, 0)
    private let controllerSpeed: Double = 5.0  // pixels per update

    weak var bluetoothManager: BluetoothManager?
    weak var multipeerManager: MultipeerManager?

    private var sensitivity: Double {
        SettingsManager.shared.sensitivity
    }

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

        lastUpdateTime = nil
        isCalibrated = false
        imuReference = nil
        lastRoll = 0.0
        lastPitch = 0.0
    }

    func resetReference() {
        referenceTransform = nil
        // Reset IMU reference for XY plane mode
        if let motionManager = motionManager,
           let deviceMotion = motionManager.deviceMotion {
            let attitude = deviceMotion.attitude
            imuReference = attitude.copy() as? CMAttitude
            lastRoll = 0.0
            lastPitch = 0.0
        }
    }

    func calibrateIMU() {
        guard let motionManager = motionManager,
              let deviceMotion = motionManager.deviceMotion else {
            return
        }

        // Store reference attitude for XY plane mode
        // This is the "zero position" when device is flat on table
        let attitude = deviceMotion.attitude
        imuReference = attitude.copy() as? CMAttitude

        // Reset last position tracking
        lastRoll = 0.0
        lastPitch = 0.0

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
              let deviceMotion = motionManager.deviceMotion else {
            return
        }

        // For XY plane mode, we need a reference attitude to track changes from
        guard let reference = imuReference else {
            return
        }

        // Get current attitude
        let currentAttitude = deviceMotion.attitude

        // Calculate relative attitude change from calibration reference
        // This gives us the change in orientation since the device was zeroed
        let relativeAttitude = currentAttitude.copy() as! CMAttitude
        relativeAttitude.multiply(byInverseOf: reference)

        // For XY plane mode (device flat on table):
        // - Roll (rotation around X-axis, left-right tilt) → horizontal movement (X)
        // - Pitch (rotation around Y-axis, forward-backward tilt) → vertical movement (Y)
        //
        // When device is flat: roll ≈ 0, pitch ≈ 0
        // Tilting left (negative roll) → move cursor left (negative X)
        // Tilting right (positive roll) → move cursor right (positive X)
        // Tilting forward (positive pitch) → move cursor down (positive Y)
        // Tilting backward (negative pitch) → move cursor up (negative Y)

        let currentRoll = relativeAttitude.roll
        let currentPitch = relativeAttitude.pitch

        // Calculate change from last position
        let deltaRoll = currentRoll - lastRoll
        let deltaPitch = currentPitch - lastPitch

        // Update last position
        lastRoll = currentRoll
        lastPitch = currentPitch

        // Convert attitude changes to mouse movement
        // Scale by sensitivity and convert radians to pixels
        // Typical roll/pitch range: -π/2 to π/2, scale appropriately
        // Invert signs to match expected movement direction
        let deltaX = -deltaRoll * sensitivity * 100.0  // Roll → X movement (inverted)
        let deltaY = -deltaPitch * sensitivity * 100.0   // Pitch → Y movement (inverted)

        // Only send movement if significant
        if abs(deltaX) > 0.1 || abs(deltaY) > 0.1 {
            sendMovement(deltaX: deltaX, deltaY: deltaY)
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

        // Controller: y=1 is up button, y=-1 is down button
        // We send: up (y=1) → positive deltaY, down (y=-1) → negative deltaY
        // Mac will invert: positive → negative (up), negative → positive (down)
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

        // When phone is flat on table:
        // X = left-right movement (positive = right)
        // Z = forward-backward movement (depth along table) → maps to screen Y
        // ARKit: positive Z = forward (away from camera), negative Z = backward (toward camera)
        // We want: forward (positive Z) = cursor DOWN (positive Y in macOS)
        // So: deltaY should be positive when Z is positive
        let deltaX = Double(translation.x) * sensitivity
        let deltaY = Double(-translation.z) * sensitivity  // Invert Z: forward = positive Y = down

        // Send movement (Y will be inverted on Mac side for macOS coordinate system)
        sendMovement(deltaX: deltaX, deltaY: deltaY)

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

