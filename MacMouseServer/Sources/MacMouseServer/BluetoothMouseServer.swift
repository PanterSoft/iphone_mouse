import Foundation
import CoreBluetooth
import AppKit

class BluetoothMouseServer: NSObject, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager!
    private var characteristic: CBMutableCharacteristic?
    private var connectedCentral: CBCentral?

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

        print("Starting Bluetooth advertising...")
        print("  Service UUID: \(serviceUUID)")
        print("  Device name: Mac Mouse Server")
        peripheralManager.startAdvertising(advertisementData)
        print("✓ Bluetooth service is advertising. iPhone can now discover and connect.")
        print("  Make sure Bluetooth is enabled on both devices and they are nearby.")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        connectedCentral = central
        print("✅ iPhone connected via Bluetooth")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        connectedCentral = nil
        print("❌ iPhone disconnected (Bluetooth)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
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
        DispatchQueue.main.async {
            let currentLocation = NSEvent.mouseLocation
            let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

            let newX = currentLocation.x + deltaX
            let newY = currentLocation.y - deltaY

            let clampedX = max(screenFrame.minX, min(screenFrame.maxX, newX))
            let clampedY = max(screenFrame.minY, min(screenFrame.maxY, newY))

            let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: clampedX, y: clampedY), mouseButton: .left)
            moveEvent?.post(tap: .cghidEventTap)
        }
    }
}

