import Foundation
import CoreBluetooth
import Combine

/// Bluetooth HID Service Implementation
/// Uses CoreBluetooth to send HID-formatted mouse reports
/// Note: iOS cannot act as a true HID peripheral like Android, but we send HID-formatted data
class BluetoothHidService: NSObject, MouseProtocol {
    @Published private var _isConnected: Bool = false
    @Published private var _connectionError: String?

    var isConnected: Published<Bool>.Publisher { $_isConnected }
    var connectionError: Published<String?>.Publisher { $_connectionError }

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var mouseCharacteristic: CBCharacteristic?

    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let characteristicUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABD")

    // Background queue for Bluetooth operations (prevents UI blocking)
    private let bluetoothQueue = DispatchQueue(label: "com.iphone.mouse.bluetooth", qos: .userInitiated)

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: nil, queue: bluetoothQueue)
        centralManager.delegate = self
    }

    func connect() throws {
        guard centralManager.state == .poweredOn else {
            throw MouseConnectionError.bluetoothNotAvailable
        }

        // Start scanning for the service
        bluetoothQueue.async { [weak self] in
            self?.centralManager.scanForPeripherals(withServices: [self?.serviceUUID ?? CBUUID()], options: nil)
        }
    }

    func disconnect() {
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }

            if let peripheral = self.connectedPeripheral {
                self.centralManager.cancelPeripheralConnection(peripheral)
            }

            self.centralManager.stopScan()
            self.connectedPeripheral = nil
            self.mouseCharacteristic = nil

            DispatchQueue.main.async {
                self._isConnected = false
                self._connectionError = nil
            }
        }
    }

    func sendInput(deltaX: Int16, deltaY: Int16, buttons: UInt8, scroll: Int8) throws {
        guard _isConnected,
              let peripheral = connectedPeripheral,
              let characteristic = mouseCharacteristic else {
            throw MouseConnectionError.notConnected
        }

        // Create HID report
        let report = MouseHIDReport(buttons: buttons, deltaX: deltaX, deltaY: deltaY, scroll: scroll)
        let data = report.toData()

        // Send on background queue to prevent blocking
        bluetoothQueue.async { [weak self] in
            guard let self = self, self._isConnected else { return }

            // Use writeWithoutResponse for lowest latency (fire and forget)
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothHidService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            DispatchQueue.main.async {
                self._connectionError = nil
            }
        case .poweredOff:
            DispatchQueue.main.async {
                self._isConnected = false
                self._connectionError = "Bluetooth is turned off"
            }
        case .unauthorized:
            DispatchQueue.main.async {
                self._isConnected = false
                self._connectionError = "Bluetooth permission denied"
            }
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self._isConnected = false
            self._connectionError = "Connection failed: \(error?.localizedDescription ?? "Unknown error")"
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self._isConnected = false
            if let error = error {
                self._connectionError = "Disconnected: \(error.localizedDescription)"
            }
        }
        connectedPeripheral = nil
        mouseCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothHidService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                mouseCharacteristic = characteristic
                DispatchQueue.main.async {
                    self._isConnected = true
                    self._connectionError = nil
                }
                break
            }
        }
    }
}

/// Connection errors
enum MouseConnectionError: LocalizedError {
    case bluetoothNotAvailable
    case notConnected
    case wifiConnectionFailed
    case invalidData

    var errorDescription: String? {
        switch self {
        case .bluetoothNotAvailable:
            return "Bluetooth is not available"
        case .notConnected:
            return "Not connected to target device"
        case .wifiConnectionFailed:
            return "WiFi connection failed"
        case .invalidData:
            return "Invalid data format"
        }
    }
}
