import Foundation
import MultipeerConnectivity
import AppKit

class MultipeerMouseServer: NSObject {
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private let serviceType = "iphonemouse"
    private var myPeerID: MCPeerID
    private static var activeServer: MultipeerMouseServer?

    override init() {
        let hostname = Host.current().name ?? "Mac Mouse Server"
        myPeerID = MCPeerID(displayName: hostname)
        super.init()
    }

    func start() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self

        advertiser?.startAdvertisingPeer()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        session?.disconnect()
        advertiser = nil
        session = nil
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
        // Only process if this is the active server
        guard MultipeerMouseServer.activeServer === self else { return }

        // Add raw movement data to smoother (Mac handles all smoothing/interpolation)
        MouseMovementSmoother.shared.addMovement(deltaX: deltaX, deltaY: deltaY)
    }
}

// MARK: - MCSessionDelegate
extension MultipeerMouseServer: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            MultipeerMouseServer.activeServer = self
            print("✅ iPhone connected via Wi-Fi Direct")
        case .connecting:
            break
        case .notConnected:
            let wasActive = MultipeerMouseServer.activeServer === self
            if wasActive {
                MultipeerMouseServer.activeServer = nil
                print("❌ iPhone disconnected (Wi-Fi Direct)")
            }
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Only process if this is the active server or no server is active yet
        if MultipeerMouseServer.activeServer == nil {
            MultipeerMouseServer.activeServer = self
        }
        guard MultipeerMouseServer.activeServer === self else { return }

        if let message = String(data: data, encoding: .utf8) {
            processMessage(message)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerMouseServer: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("✗ Wi-Fi Direct advertising failed: \(error.localizedDescription)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didStartAdvertisingPeer error: Error?) {
        if let error = error {
            print("✗ Wi-Fi Direct error: \(error.localizedDescription)")
        }
    }
}

