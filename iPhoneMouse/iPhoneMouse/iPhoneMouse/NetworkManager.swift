import Foundation
import Network
import Combine

class NetworkManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var connectionError: String?

    private var connection: NWConnection?
    private let port: UInt16 = 12345

    func connect(to ipAddress: String) {
        guard !ipAddress.isEmpty else { return }

        isConnecting = true
        connectionError = nil

        let host = NWEndpoint.Host(ipAddress)
        let port = NWEndpoint.Port(integerLiteral: port)
        let endpoint = NWEndpoint.hostPort(host: host, port: port)

        let parameters = NWParameters.tcp
        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.isConnecting = false
                    self?.connectionError = nil
                case .failed(let error):
                    self?.isConnected = false
                    self?.isConnecting = false
                    self?.connectionError = "Connection failed: \(error.localizedDescription)"
                    self?.connection = nil
                case .cancelled:
                    self?.isConnected = false
                    self?.isConnecting = false
                    self?.connection = nil
                default:
                    break
                }
            }
        }

        connection?.start(queue: .global())
    }

    func sendMovement(deltaX: Double, deltaY: Double) {
        guard isConnected, let connection = connection else { return }

        // Create a simple protocol: "MOVE:dx,dy\n"
        let message = "MOVE:\(deltaX),\(deltaY)\n"
        guard let data = message.data(using: .utf8) else { return }

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.connectionError = "Send error: \(error.localizedDescription)"
                }
            }
        })
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        isConnecting = false
        connectionError = nil
    }
}

