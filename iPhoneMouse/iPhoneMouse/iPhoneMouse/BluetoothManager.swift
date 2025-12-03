import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectionError: String?
    @Published var status: ConnectionStatus = .stopped

    enum ConnectionStatus: Equatable {
        case stopped
        case starting
        case scanning
        case connected
        case error(String)
    }

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var mouseCharacteristic: CBCharacteristic?

    // Bluetooth service UUID (must match Mac server)
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let characteristicUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABD")

    struct DiscoveredDevice: Identifiable {
        let id: UUID
        let peripheral: CBPeripheral
        let name: String
    }

    override init() {
        super.init()
        // Create CBCentralManager on main queue to ensure permission request happens immediately
        // queue: nil uses the main queue, which is required for permission dialogs
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                self.status = .scanning
                self.startScanning()
            case .poweredOff:
                self.status = .error("Bluetooth is turned off")
                self.connectionError = "Bluetooth is not available. Please enable Bluetooth in Settings."
            case .unauthorized:
                self.status = .error("Bluetooth permission denied")
                self.connectionError = "Bluetooth permission denied. Please grant access in Settings."
            case .unsupported:
                self.status = .error("Bluetooth not supported")
                self.connectionError = "Bluetooth is not supported on this device."
            default:
                self.status = .stopped
            }
        }
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        DispatchQueue.main.async {
            self.status = .scanning
            self.isScanning = true
            self.discoveredDevices = []
        }
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func stopScanning() {
        centralManager.stopScan()
        DispatchQueue.main.async {
            self.status = .stopped
            self.isScanning = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown Device"

        // Check if we already have this device
        if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            let device = DiscoveredDevice(id: peripheral.identifier, peripheral: peripheral, name: deviceName)
            DispatchQueue.main.async {
                self.discoveredDevices.append(device)
            }
        }
    }

    func connect(to device: DiscoveredDevice) {
        stopScanning()
        isScanning = false
        connectionError = nil
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(device.peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionError = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
            self.isConnected = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedPeripheral = nil
            self.mouseCharacteristic = nil
            if let error = error {
                self.connectionError = "Disconnected: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - CBPeripheralDelegate

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
                    self.isConnected = true
                    self.status = .connected
                    self.connectionError = nil
                }
                break
            }
        }
    }

    func sendMovement(deltaX: Double, deltaY: Double) {
        guard isConnected,
              let peripheral = connectedPeripheral,
              let characteristic = mouseCharacteristic else { return }

        let message = "MOVE:\(deltaX),\(deltaY)\n"
        guard let data = message.data(using: .utf8) else { return }

        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }

    func disconnect() {
        stopScanning()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        mouseCharacteristic = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.status = .stopped
            self.connectionError = nil
        }
    }

    func reconnect() {
        // Allow restarting scanning after disconnect
        if status == .stopped && centralManager.state == .poweredOn {
            startScanning()
        }
    }
}

