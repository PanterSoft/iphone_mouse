import Foundation
import CoreBluetooth
import AppKit

class BluetoothMouseServer: NSObject, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager!
    private var characteristic: CBMutableCharacteristic?
    private var connectedCentral: CBCentral?

    // Bluetooth service UUID
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let characteristicUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABD")

    override init() {
        super.init()
        print("🔵 Initializing Bluetooth Peripheral Manager (this will request Bluetooth permission)...")
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        print("🔵 Bluetooth Peripheral Manager initialized - waiting for state update...")
    }

    func start() {
        print("Starting Bluetooth Mouse Server...")
        print("Checking Bluetooth state...")

        // Check current state
        switch peripheralManager.state {
        case .poweredOn:
            print("✓ Bluetooth is powered on")
            setupService()
        case .poweredOff:
            print("✗ Bluetooth is turned off. Please enable Bluetooth in System Settings.")
        case .unauthorized:
            print("✗ Bluetooth permission denied.")
            print("  macOS may prompt for permission. If not, check System Settings > Privacy & Security > Bluetooth")
        case .unsupported:
            print("✗ Bluetooth is not supported on this Mac.")
        case .resetting:
            print("⚠ Bluetooth is resetting... waiting...")
        case .unknown:
            print("⚠ Bluetooth state unknown. Waiting for state update...")
        @unknown default:
            print("⚠ Unknown Bluetooth state: \(peripheralManager.state.rawValue)")
        }
    }

    // MARK: - CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("Bluetooth state changed: \(peripheral.state.rawValue)")
        switch peripheral.state {
        case .poweredOn:
            print("✓ Bluetooth is now powered on")
            setupService()
        case .poweredOff:
            print("✗ Bluetooth is turned off. Please enable Bluetooth in System Settings.")
        case .unauthorized:
            print("✗ Bluetooth permission denied.")
            print("  Go to: System Settings > Privacy & Security > Bluetooth")
            print("  Make sure Bluetooth access is enabled for Terminal or this app")
        case .unsupported:
            print("✗ Bluetooth is not supported on this Mac.")
        case .resetting:
            print("⚠ Bluetooth is resetting...")
        case .unknown:
            print("⚠ Bluetooth state unknown.")
        @unknown default:
            print("⚠ Unknown Bluetooth state: \(peripheral.state.rawValue)")
        }
    }

    private func setupService() {
        // Create characteristic
        characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        // Create service
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic!]

        // Add service to peripheral
        peripheralManager.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("✗ Error adding Bluetooth service: \(error.localizedDescription)")
            return
        }

        print("✓ Bluetooth service added successfully")

        // Start advertising
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
        print("✅ iPhone CONNECTED via Bluetooth!")
        print("   Central ID: \(central.identifier)")
        print("   Mouse control is now active!")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        connectedCentral = nil
        print("❌ iPhone disconnected via Bluetooth")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let data = request.value else { continue }

            // Process the movement data
            if let message = String(data: data, encoding: .utf8) {
                processMessage(message)
            }

            // Respond to the request
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

