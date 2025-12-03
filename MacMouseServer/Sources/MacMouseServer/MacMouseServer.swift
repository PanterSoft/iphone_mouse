import Foundation
import Network
import AppKit
#if canImport(ifaddrs)
import ifaddrs
#endif

class MacMouseServer: NSObject {
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private let port: UInt16 = 12345
    private var netService: NetService?
    private let serviceType = "_iphonemouse._tcp"
    private let serviceDomain = "local."

    override init() {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .wifi
        parameters.prohibitExpensivePaths = true

        let port = NWEndpoint.Port(integerLiteral: 12345)
        listener = try! NWListener(using: parameters, on: port)

        super.init()

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
    }

    func start() {
        print("🌐 Requesting Local Network permission (checking network interfaces)...")
        if let ipAddress = getIPv4Address() {
            print("✓ Server IPv4 address: \(ipAddress)")
            print("  Network access appears to be working")
        } else {
            print("⚠ Could not determine IPv4 address")
            print("  This might indicate Local Network permission is needed")
            print("  Check: System Settings > Privacy & Security > Local Network")
        }

        listener.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    self.startBonjour()
                }
            case .waiting(let error):
                let errorDesc = error.localizedDescription.lowercased()
                if errorDesc.contains("network") || errorDesc.contains("permission") || errorDesc.contains("denied") {
                    print("⚠ Network permission may be needed - check System Settings")
                }
            case .failed(let error):
                print("✗ Network server failed: \(error.localizedDescription)")
            default:
                break
            }
        }

        listener.start(queue: .global())
    }

    private func startBonjour() {
        let hostname = Host.current().name ?? "Mac Mouse Server"
        netService = NetService(domain: serviceDomain, type: serviceType, name: hostname, port: Int32(port))
        netService?.delegate = self
        netService?.includesPeerToPeer = false
        netService?.publish()
    }

    private func stopBonjour() {
        netService?.stop()
        netService = nil
    }

    private func getIPv4Address() -> String? {
        var wifiAddress: String?
        var ethernetAddress: String?
        var otherAddress: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                           &hostname, socklen_t(hostname.count),
                           nil, socklen_t(0), NI_NUMERICHOST)
                let address = String(cString: hostname)

                guard !address.hasPrefix("127.") && !address.hasPrefix("169.254.") else { continue }

                if name == "en0" || name == "en1" {
                    wifiAddress = address
                } else if name.hasPrefix("en") && (name == "en2" || name == "en3" || name == "en4") {
                    if ethernetAddress == nil {
                        ethernetAddress = address
                    }
                } else if name.hasPrefix("en") {
                    if otherAddress == nil {
                        otherAddress = address
                    }
                }
            }
        }

        return wifiAddress ?? ethernetAddress ?? otherAddress
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        let connectionID = UUID().uuidString.prefix(8)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ iPhone connected via Wi-Fi")
                self.receiveData(on: connection)
            case .cancelled:
                print("❌ iPhone disconnected (Wi-Fi)")
                if let index = self.connections.firstIndex(where: { $0 === connection }) {
                    self.connections.remove(at: index)
                }
            case .failed(let error):
                print("❌ Connection failed: \(error.localizedDescription)")
                if let index = self.connections.firstIndex(where: { $0 === connection }) {
                    self.connections.remove(at: index)
                }
            default:
                break
            }
        }

        connection.start(queue: .global())
    }

    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, isComplete, error in
            if let error = error {
                print("✗ Receive error: \(error.localizedDescription)")
                return
            }

            if let data = data, let message = String(data: data, encoding: .utf8) {
                self?.processMessage(message)
            }

            if !isComplete {
                self?.receiveData(on: connection)
            }
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
            let newY = currentLocation.y - deltaY  // Invert Y because screen Y increases upward

            let clampedX = max(screenFrame.minX, min(screenFrame.maxX, newX))
            let clampedY = max(screenFrame.minY, min(screenFrame.maxY, newY))

            let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: clampedX, y: clampedY), mouseButton: .left)
            moveEvent?.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - NetServiceDelegate
extension MacMouseServer: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("✗ Bonjour service failed to publish!")
        print("  Error: \(errorDict)")
        if let errorCode = errorDict[NetService.errorCode]?.intValue {
            print("  Error code: \(errorCode)")
            switch errorCode {
            case -72000:
                print("  → Service name collision (try restarting)")
            case -72001:
                print("  → Service not found")
            case -72003:
                print("  → Bad argument")
            case -72004:
                print("  → Cancelled")
            case -72005:
                print("  → Invalid service")
            default:
                print("  → Unknown error")
            }
        }
    }

    func netServiceWillPublish(_ sender: NetService) {
    }
}

