import Foundation
import Network
import Combine

class BonjourDiscoveryManager: NSObject, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isDiscovering: Bool = false
    @Published var discoveredServices: [DiscoveredService] = []
    @Published var connectionError: String?
    @Published var status: ConnectionStatus = .stopped

    enum ConnectionStatus: Equatable {
        case stopped
        case starting
        case discovering
        case connected
        case error(String)
    }

    struct DiscoveredService: Identifiable {
        let id: String
        let name: String
        let hostName: String
        let port: Int
    }

    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    private var connection: NWConnection?
    private let serviceType = "_iphonemouse._tcp"
    private let serviceDomain = "local."

    override init() {
        super.init()
    }

    func startDiscovery() {
        guard status == .stopped else { return }

        discoveredServices = []

        // Create browser and start searching - this will trigger Local Network permission
        // Must be called synchronously to trigger permission dialog
        browser = NetServiceBrowser()
        browser?.delegate = self

        // Update status first
        DispatchQueue.main.async {
            self.status = .starting
            self.isDiscovering = true
            self.connectionError = nil
        }

        // Start searching immediately - this triggers the permission request
        // Note: If permission is denied, you'll get error -72008
        browser?.searchForServices(ofType: serviceType, inDomain: serviceDomain)

        // Update status after starting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.status == .starting {
                self.status = .discovering
            }
        }
    }

    func stopDiscovery() {
        browser?.stop()
        browser = nil
        services = []

        connection?.cancel()
        connection = nil

        DispatchQueue.main.async {
            self.status = .stopped
            self.isDiscovering = false
            self.discoveredServices = []
            self.isConnected = false
        }
    }

    func connect(to service: DiscoveredService) {
        guard let netService = services.first(where: { $0.name == service.name }) else {
            connectionError = "Service not found"
            return
        }

        netService.resolve(withTimeout: 5.0)

        // The connection will be established in didResolveAddress
        // For now, we'll create a connection using the service info
        let host = NWEndpoint.Host(service.hostName)
        let port = NWEndpoint.Port(integerLiteral: UInt16(service.port))
        let endpoint = NWEndpoint.hostPort(host: host, port: port)

        let parameters = NWParameters.tcp
        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.status = .connected
                    self?.connectionError = nil
                case .failed(let error):
                    self?.isConnected = false
                    self?.status = .error(error.localizedDescription)
                    self?.connectionError = "Connection failed: \(error.localizedDescription)"
                    self?.connection = nil
                case .cancelled:
                    self?.isConnected = false
                    self?.status = .stopped
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

        DispatchQueue.main.async {
            self.isConnected = false
            self.status = .stopped
            self.isDiscovering = false
        }
    }

    func reconnect() {
        // Allow restarting after disconnect
        if status == .stopped {
            startDiscovery()
        }
    }
}

// MARK: - NetServiceBrowserDelegate
extension BonjourDiscoveryManager: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll(where: { $0 == service })

        DispatchQueue.main.async {
            self.discoveredServices.removeAll(where: { $0.name == service.name })
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch error: Error) {
        // Error -72008 typically means Local Network permission is denied
        let nsError = error as NSError
        var errorMessage = error.localizedDescription

        if nsError.domain == "NSNetServicesErrorDomain" {
            switch nsError.code {
            case -72008:
                errorMessage = "Local Network permission denied. Go to Settings > Privacy & Security > Local Network and enable iPhone Mouse."
            case -72000:
                errorMessage = "Bonjour service name collision"
            case -72001:
                errorMessage = "Bonjour service not found"
            default:
                errorMessage = "Bonjour error \(nsError.code): \(error.localizedDescription)"
            }
        }

        DispatchQueue.main.async {
            self.status = .error(errorMessage)
            self.connectionError = errorMessage
            self.isDiscovering = false
        }
    }
}

// MARK: - NetServiceDelegate
extension BonjourDiscoveryManager: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses,
              !addresses.isEmpty else { return }

        // Parse the first IPv4 address
        for addressData in addresses {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let success = addressData.withUnsafeBytes { bytes in
                let sockaddr = bytes.bindMemory(to: sockaddr.self).baseAddress!
                return getnameinfo(sockaddr, socklen_t(addressData.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0
            }

            if success {
                let hostString = String(cString: hostname)
                let service = DiscoveredService(
                    id: sender.name,
                    name: sender.name,
                    hostName: hostString,
                    port: Int(sender.port)
                )

                DispatchQueue.main.async {
                    if !self.discoveredServices.contains(where: { $0.id == service.id }) {
                        self.discoveredServices.append(service)
                    }
                }
                break
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve error: Error) {
        DispatchQueue.main.async {
            self.connectionError = "Failed to resolve service: \(error.localizedDescription)"
        }
    }
}
