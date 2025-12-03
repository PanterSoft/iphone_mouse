import Foundation
import CoreBluetooth
import AppKit

class BluetoothMouseServer: NSObject, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager!
    private var characteristic: CBMutableCharacteristic?
    private var connectedCentral: CBCentral?
    private static var activeServer: BluetoothMouseServer?

    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let characteristicUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABD")

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func start() {
        switch peripheralManager.state {
        case .poweredOn:
            setupService()
        case .poweredOff:
            print("✗ Bluetooth is turned off")
        case .unauthorized:
            print("✗ Bluetooth permission denied - check System Settings")
        case .unsupported:
            print("✗ Bluetooth not supported")
        default:
            break
        }
    }

    // MARK: - CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            setupService()
        case .poweredOff:
            print("✗ Bluetooth is turned off")
        case .unauthorized:
            print("✗ Bluetooth permission denied - check System Settings")
        case .unsupported:
            print("✗ Bluetooth not supported")
        default:
            break
        }
    }

    private func setupService() {
        characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic!]

        peripheralManager.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("✗ Error adding Bluetooth service: \(error.localizedDescription)")
            return
        }

        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Mac Mouse Server"
        ]

        peripheralManager.startAdvertising(advertisementData)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        connectedCentral = central
        BluetoothMouseServer.activeServer = self
        print("✅ iPhone connected via Bluetooth")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        connectedCentral = nil
        if BluetoothMouseServer.activeServer === self {
            BluetoothMouseServer.activeServer = nil
        }
        print("❌ iPhone disconnected (Bluetooth)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        // Only process if this is the active server or no server is active yet
        if BluetoothMouseServer.activeServer == nil {
            BluetoothMouseServer.activeServer = self
        }
        guard BluetoothMouseServer.activeServer === self else { return }

        for request in requests {
            guard let data = request.value else { continue }

            if let message = String(data: data, encoding: .utf8) {
                processMessage(message)
            }

            peripheralManager.respond(to: request, withResult: .success)
        }
    }

    private func processMessage(_ message: String) {
        let lines = message.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("MOVE:") {
                let components = line.dropFirst(5).components(separatedBy: ",")
                if components.count == 2,
                   let deltaX = Double(components[0]),
                   let deltaY = Double(components[1]) {
                    moveMouse(deltaX: deltaX, deltaY: deltaY)
                }
            }
        }
    }

    private func moveMouse(deltaX: Double, deltaY: Double) {
        // Only process if this is the active server
        guard BluetoothMouseServer.activeServer === self else { return }

        // Add raw movement data to smoother (Mac handles all smoothing/interpolation)
        MouseMovementSmoother.shared.addMovement(deltaX: deltaX, deltaY: deltaY)
    }
}

