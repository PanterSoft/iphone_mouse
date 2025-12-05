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
        MouseDataCollector.shared.connectionType = "Bluetooth"
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        connectedCentral = nil
        if BluetoothMouseServer.activeServer === self {
            BluetoothMouseServer.activeServer = nil
        }
        print("❌ iPhone disconnected (Bluetooth)")
        MouseDataCollector.shared.connectionType = "Not Connected"
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        // Set as active server if not already set
        if BluetoothMouseServer.activeServer == nil {
            BluetoothMouseServer.activeServer = self
        }
        guard BluetoothMouseServer.activeServer === self else { return }

        for request in requests {
            guard let data = request.value else { continue }

            // Decode HID mouse report format
            if let (deltaX, deltaY, buttons, scroll) = MouseMovementProtocol.decode(data) {
                moveMouse(deltaX: deltaX, deltaY: deltaY, buttons: buttons, scroll: scroll)
            }

            peripheralManager.respond(to: request, withResult: .success)
        }
    }

    private func moveMouse(deltaX: Double, deltaY: Double, buttons: UInt8, scroll: Int8) {
        // Only process if this is the active server
        guard BluetoothMouseServer.activeServer === self else { return }

        // Record data for visualization
        MouseDataCollector.shared.recordData(
            deltaX: deltaX,
            deltaY: deltaY,
            buttons: buttons,
            scroll: scroll,
            connectionType: "Bluetooth"
        )

        // Directly move cursor with received deltas (no smoothing, no accumulation)
        DispatchQueue.main.async {
            MouseMovementSmoother.shared.moveCursor(deltaX: deltaX, deltaY: deltaY)
        }

        // Handle button clicks (future implementation)
        if buttons != 0 {
            handleMouseButtons(buttons)
        }

        // Handle scroll (future implementation)
        if scroll != 0 {
            handleScroll(scroll)
        }
    }

    private func handleMouseButtons(_ buttons: UInt8) {
        // TODO: Implement mouse button clicks
        // Use CGEvent to post mouse down/up events
    }

    private func handleScroll(_ scroll: Int8) {
        // TODO: Implement scroll wheel
        // Use CGEvent to post scroll events
    }
}

