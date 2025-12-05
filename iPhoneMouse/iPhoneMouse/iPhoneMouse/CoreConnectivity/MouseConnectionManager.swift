import Foundation
import Combine

/// Connection mode enumeration
enum ConnectionMode {
    case bluetooth
    case wifi(host: String, udpPort: UInt16, tcpPort: UInt16)
}

/// Central manager for mouse connectivity
/// Handles switching between Bluetooth and WiFi modes
class MouseConnectionManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    @Published var currentMode: ConnectionMode?

    private var currentService: MouseProtocol?
    private var cancellables = Set<AnyCancellable>()

    /// Connect using specified mode
    func connect(mode: ConnectionMode) throws {
        // Disconnect existing connection
        disconnect()

        // Create appropriate service
        let service: MouseProtocol

        switch mode {
        case .bluetooth:
            service = BluetoothHidService()
        case .wifi(let host, let udpPort, let tcpPort):
            service = WifiNetworkService(targetHost: host, udpPort: udpPort, tcpPort: tcpPort)
        }

        currentService = service
        currentMode = mode

        // Subscribe to connection status
        service.isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)

        service.connectionError
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionError)

        // Connect
        try service.connect()
    }

    /// Disconnect from current service
    func disconnect() {
        currentService?.disconnect()
        currentService = nil
        currentMode = nil
        isConnected = false
        connectionError = nil
    }

    /// Send mouse input using current service
    func sendInput(deltaX: Int16, deltaY: Int16, buttons: UInt8 = 0, scroll: Int8 = 0) throws {
        guard let service = currentService else {
            throw MouseConnectionError.notConnected
        }

        try service.sendInput(deltaX: deltaX, deltaY: deltaY, buttons: buttons, scroll: scroll)
    }

    /// Convenience method for sending movement only
    func sendMovement(deltaX: Double, deltaY: Double) throws {
        // Convert Double to Int16 (clamp to valid range)
        let clampedX = Int16(max(-32768, min(32767, Int16(deltaX))))
        let clampedY = Int16(max(-32768, min(32767, Int16(deltaY))))

        try sendInput(deltaX: clampedX, deltaY: clampedY, buttons: 0, scroll: 0)
    }

    /// Convenience method for button clicks
    func sendButtonClick(_ button: MouseButtons) throws {
        // Send button down
        try sendInput(deltaX: 0, deltaY: 0, buttons: button.rawValue, scroll: 0)

        // Small delay then button up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            try? self.sendInput(deltaX: 0, deltaY: 0, buttons: 0, scroll: 0)
        }
    }
}

/// Button constants matching HID standard
enum MouseButtons: UInt8 {
    case left = 0x01
    case right = 0x02
    case middle = 0x04
}
