import Foundation
import Network
import Combine

/// WiFi Network Service Implementation
/// Uses UDP for movement data (zero latency, fire and forget)
/// Uses TCP for control commands (reliable delivery)
class WifiNetworkService: MouseProtocol {
    @Published private var _isConnected: Bool = false
    @Published private var _connectionError: String?

    var isConnected: Published<Bool>.Publisher { $_isConnected }
    var connectionError: Published<String?>.Publisher { $_connectionError }

    // Network configuration
    private var targetHost: String
    private var udpPort: UInt16  // For movement data (UDP)
    private var tcpPort: UInt16  // For control commands (TCP)

    // UDP connection for movement (low latency)
    private var udpConnection: NWConnection?

    // TCP connection for control (reliable)
    private var tcpConnection: NWConnection?

    // Background queue for network operations (prevents UI blocking)
    private let networkQueue = DispatchQueue(label: "com.iphone.mouse.network", qos: .userInitiated)

    // UDP endpoint
    private var udpEndpoint: NWEndpoint?

    init(targetHost: String, udpPort: UInt16 = 8888, tcpPort: UInt16 = 8889) {
        self.targetHost = targetHost
        self.udpPort = udpPort
        self.tcpPort = tcpPort
    }

    func connect() throws {
        // Resolve hostname to IP address
        let host = NWEndpoint.Host(targetHost)
        let udpEndpoint = NWEndpoint.hostPort(host: host, port: NWEndpoint.Port(integerLiteral: udpPort))
        let tcpEndpoint = NWEndpoint.hostPort(host: host, port: NWEndpoint.Port(integerLiteral: tcpPort))

        self.udpEndpoint = udpEndpoint

        // Create UDP connection for movement data
        let udpParams = NWParameters.udp
        udpParams.allowFastOpen = true  // Reduce connection overhead
        udpParams.allowLocalEndpointReuse = true

        udpConnection = NWConnection(to: udpEndpoint, using: udpParams)
        udpConnection?.stateUpdateHandler = { [weak self] state in
            self?.handleUDPStateChange(state)
        }

        // Create TCP connection for control commands
        let tcpParams = NWParameters.tcp
        tcpParams.allowFastOpen = true

        tcpConnection = NWConnection(to: tcpEndpoint, using: tcpParams)
        tcpConnection?.stateUpdateHandler = { [weak self] state in
            self?.handleTCPStateChange(state)
        }

        // Start connections on background queue
        networkQueue.async { [weak self] in
            self?.udpConnection?.start(queue: self?.networkQueue ?? DispatchQueue.global())
            self?.tcpConnection?.start(queue: self?.networkQueue ?? DispatchQueue.global())
        }
    }

    func disconnect() {
        networkQueue.async { [weak self] in
            self?.udpConnection?.cancel()
            self?.tcpConnection?.cancel()
            self?.udpConnection = nil
            self?.tcpConnection = nil
            self?.udpEndpoint = nil

            DispatchQueue.main.async {
                self?._isConnected = false
                self?._connectionError = nil
            }
        }
    }

    func sendInput(deltaX: Int16, deltaY: Int16, buttons: UInt8, scroll: Int8) throws {
        guard _isConnected, let udpEndpoint = udpEndpoint else {
            throw MouseConnectionError.notConnected
        }

        // Clamp 16-bit deltas to 8-bit for WiFi packet (minimize latency)
        // This is acceptable because mouse movement is typically small increments
        // Large movements are broken into multiple packets
        let clampedX = WiFiMousePacket.clampToInt8(deltaX)
        let clampedY = WiFiMousePacket.clampToInt8(deltaY)

        // Create WiFi packet
        let packet = WiFiMousePacket(
            header: WiFiMousePacket.headerMouse,
            buttons: buttons,
            deltaX: clampedX,
            deltaY: clampedY,
            scroll: scroll
        )

        let data = packet.toData()

        // Send via UDP on background queue (fire and forget, zero latency)
        networkQueue.async { [weak self] in
            guard let self = self, let connection = self.udpConnection else { return }

            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    // Log error but don't block (UDP is best-effort)
                    print("UDP send error: \(error.localizedDescription)")
                }
            })
        }
    }

    // MARK: - Private Methods

    private func handleUDPStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            // UDP is ready (connectionless, so this just means socket is bound)
            DispatchQueue.main.async {
                if self.tcpConnection?.state == .ready {
                    self._isConnected = true
                    self._connectionError = nil
                }
            }
        case .failed(let error):
            DispatchQueue.main.async {
                self._isConnected = false
                self._connectionError = "UDP connection failed: \(error.localizedDescription)"
            }
        case .cancelled:
            DispatchQueue.main.async {
                self._isConnected = false
            }
        default:
            break
        }
    }

    private func handleTCPStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            // TCP is ready
            DispatchQueue.main.async {
                if self.udpConnection?.state == .ready {
                    self._isConnected = true
                    self._connectionError = nil
                }
            }
        case .failed(let error):
            DispatchQueue.main.async {
                self._isConnected = false
                self._connectionError = "TCP connection failed: \(error.localizedDescription)"
            }
        case .cancelled:
            DispatchQueue.main.async {
                self._isConnected = false
            }
        default:
            break
        }
    }

    /// Send control command via TCP (reliable delivery)
    /// Use this for button clicks, configuration, etc.
    func sendControlCommand(_ command: Data) throws {
        guard _isConnected, let connection = tcpConnection else {
            throw MouseConnectionError.notConnected
        }

        networkQueue.async {
            connection.send(content: command, completion: .contentProcessed { error in
                if let error = error {
                    print("TCP send error: \(error.localizedDescription)")
                }
            })
        }
    }
}
