import Foundation
import CoreMotion
import Combine

class MotionController: ObservableObject {
    private let motionManager = CMMotionManager()
    private var referenceAttitude: CMAttitude?
    private var timer: Timer?
    weak var bluetoothManager: BluetoothManager?
    weak var multipeerManager: MultipeerManager?
    weak var bonjourManager: BonjourDiscoveryManager?

    private let sensitivity: Double = 800.0
    private let deadZone: Double = 0.05

    init() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 Hz
    }

    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, let deviceMotion = self.motionManager.deviceMotion else { return }
            self.referenceAttitude = deviceMotion.attitude.copy() as? CMAttitude
        }

        timer = Timer.scheduledTimer(withTimeInterval: motionManager.deviceMotionUpdateInterval, repeats: true) { [weak self] _ in
            self?.processMotion()
        }
    }

    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        timer?.invalidate()
        timer = nil
        referenceAttitude = nil
    }

    private func processMotion() {
        guard let deviceMotion = motionManager.deviceMotion,
              let referenceAttitude = referenceAttitude else {
            return
        }

        let currentAttitude = deviceMotion.attitude
        let relativeAttitude = currentAttitude.copy() as! CMAttitude
        relativeAttitude.multiply(byInverseOf: referenceAttitude)

        let deltaX = relativeAttitude.roll * sensitivity
        let deltaY = relativeAttitude.pitch * sensitivity

        let filteredDeltaX = abs(deltaX) > deadZone * sensitivity ? deltaX : 0
        let filteredDeltaY = abs(deltaY) > deadZone * sensitivity ? deltaY : 0

        if abs(filteredDeltaX) > 0.5 || abs(filteredDeltaY) > 0.5 {
            if let bluetoothManager = bluetoothManager, bluetoothManager.isConnected {
                bluetoothManager.sendMovement(deltaX: filteredDeltaX, deltaY: filteredDeltaY)
            } else if let multipeerManager = multipeerManager, multipeerManager.isConnected {
                multipeerManager.sendMovement(deltaX: filteredDeltaX, deltaY: filteredDeltaY)
            } else if let bonjourManager = bonjourManager, bonjourManager.isConnected {
                bonjourManager.sendMovement(deltaX: filteredDeltaX, deltaY: filteredDeltaY)
            }
        }
    }

    func resetReference() {
        if let deviceMotion = motionManager.deviceMotion {
            referenceAttitude = deviceMotion.attitude.copy() as? CMAttitude
        }
    }
}

