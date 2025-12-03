import Foundation
import MultipeerConnectivity
import Combine
import UIKit

class MultipeerManager: NSObject, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isBrowsing: Bool = false
    @Published var discoveredDevices: [DiscoveredPeer] = []
    @Published var connectionError: String?
    @Published var status: ConnectionStatus = .stopped

    enum ConnectionStatus: Equatable {
        case stopped
        case starting
        case browsing
        case connected
        case error(String)
    }

    struct DiscoveredPeer: Identifiable {
        let id: String
        let peerID: MCPeerID
        let name: String
    }

    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private let serviceType = "iphonemouse"
    private var myPeerID: MCPeerID

    override init() {
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    func startBrowsing() {
        guard status == .stopped else { return }

        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self

        browser?.startBrowsingForPeers()

        DispatchQueue.main.async {
            self.status = .browsing
            self.isBrowsing = true
            self.connectionError = nil
        }
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        browser = nil
        session = nil

        DispatchQueue.main.async {
            self.status = .stopped
            self.isBrowsing = false
            self.discoveredDevices = []
            self.isConnected = false
        }
    }

    func connect(to peer: DiscoveredPeer) {
        if session == nil || browser == nil {
            if status == .stopped {
                startBrowsing()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.connect(to: peer)
                }
            }
            return
        }

        guard let session = session, let browser = browser else { return }

        if session.connectedPeers.contains(where: { $0.displayName == peer.peerID.displayName }) {
            DispatchQueue.main.async {
                self.isConnected = true
                self.status = .connected
            }
            return
        }

        if !session.connectedPeers.isEmpty {
            session.disconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let session = self.session, let browser = self.browser {
                    browser.invitePeer(peer.peerID, to: session, withContext: nil, timeout: 30)
                }
            }
        } else {
            browser.invitePeer(peer.peerID, to: session, withContext: nil, timeout: 30)
        }
    }

    func sendMovement(deltaX: Double, deltaY: Double) {
        guard isConnected,
              let session = session,
              !session.connectedPeers.isEmpty else { return }

        let message = "MOVE:\(deltaX),\(deltaY)\n"
        guard let data = message.data(using: .utf8) else { return }

        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            DispatchQueue.main.async {
                self.connectionError = "Send error: \(error.localizedDescription)"
            }
        }
    }

    func disconnect() {
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        browser = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.status = .stopped
            self.isBrowsing = false
        }
    }

    func reconnect() {
        if status == .stopped {
            startBrowsing()
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.isConnected = true
                self.status = .connected
                self.connectionError = nil
            case .connecting:
                if self.status != .browsing {
                    self.status = .browsing
                }
            case .notConnected:
                self.isConnected = false
                if self.status == .connected {
                    self.status = .browsing
                }
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let peer = DiscoveredPeer(id: peerID.displayName, peerID: peerID, name: peerID.displayName)

        DispatchQueue.main.async {
            if !self.discoveredDevices.contains(where: { $0.id == peer.id }) {
                self.discoveredDevices.append(peer)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredDevices.removeAll(where: { $0.id == peerID.displayName })
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let nsError = error as NSError
        var errorMessage = error.localizedDescription

        if nsError.code == -72008 || errorMessage.contains("NSNetServicesErrorDomain") {
            errorMessage = "Local Network permission denied. Go to Settings > Privacy & Security > Local Network and enable iPhone Mouse."
        } else if errorMessage.contains("permission") || errorMessage.contains("denied") ||
           (nsError.domain.contains("network") && nsError.code < 0) {
            errorMessage = "Local Network permission may be needed. Go to Settings > Privacy & Security > Local Network and enable iPhone Mouse."
        }

        DispatchQueue.main.async {
            self.status = .error(errorMessage)
            self.connectionError = errorMessage
            self.isBrowsing = false
        }
    }
}
