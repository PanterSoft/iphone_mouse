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


    private func moveMouse(deltaX: Double, deltaY: Double, buttons: UInt8, scroll: Int8) {
        // Only process if this is the active server
        guard MultipeerMouseServer.activeServer === self else { return }

        // Record data for visualization
        MouseDataCollector.shared.recordData(
            deltaX: deltaX,
            deltaY: deltaY,
            buttons: buttons,
            scroll: scroll,
            connectionType: "Wi-Fi Direct"
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

// MARK: - MCSessionDelegate
extension MultipeerMouseServer: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            MultipeerMouseServer.activeServer = self
            print("✅ iPhone connected via Wi-Fi Direct")
            MouseDataCollector.shared.connectionType = "Wi-Fi Direct"
        case .connecting:
            break
        case .notConnected:
            if MultipeerMouseServer.activeServer === self {
                MultipeerMouseServer.activeServer = nil
            }
            print("❌ iPhone disconnected (Wi-Fi Direct)")
            MouseDataCollector.shared.connectionType = "Not Connected"
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Set as active server if not already set
        if MultipeerMouseServer.activeServer == nil {
            MultipeerMouseServer.activeServer = self
        }
        guard MultipeerMouseServer.activeServer === self else { return }

        // Decode HID mouse report format
        if let (deltaX, deltaY, buttons, scroll) = MouseMovementProtocol.decode(data) {
            moveMouse(deltaX: deltaX, deltaY: deltaY, buttons: buttons, scroll: scroll)
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

