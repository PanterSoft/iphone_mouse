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
        let sensorType = SettingsManager.shared.sensorType

        switch sensorType {
        case .arkit:
            startARKit()
        case .imu:
            startIMU()
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
        velocityX = 0.0
        velocityY = 0.0
        lastUpdateTime = nil
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

        let attitude = deviceMotion.attitude
        imuReference = attitude.copy() as? CMAttitude
        imuCalibrationOffset = (attitude.roll, attitude.pitch)
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
        let accelX = userAcceleration.x
        let accelY = userAcceleration.y

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
        if abs(deltaX) > minMovement || abs(deltaY) > minMovement {
            if let bluetoothManager = bluetoothManager, bluetoothManager.isConnected {
                bluetoothManager.sendMovement(deltaX: deltaX, deltaY: deltaY)
            } else if let multipeerManager = multipeerManager, multipeerManager.isConnected {
                multipeerManager.sendMovement(deltaX: deltaX, deltaY: deltaY)
            }
        }
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

