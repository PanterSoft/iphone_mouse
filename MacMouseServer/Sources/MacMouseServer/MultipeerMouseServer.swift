import Foundation
import MultipeerConnectivity
import AppKit

class MultipeerMouseServer: NSObject {
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    // Service type must match iOS app exactly
    // Must be 1-15 characters, lowercase, alphanumeric and hyphens only
    private let serviceType = "iphonemouse"
    private var myPeerID: MCPeerID

    override init() {
        // Create peer ID with Mac's hostname
        let hostname = Host.current().name ?? "Mac Mouse Server"
        myPeerID = MCPeerID(displayName: hostname)
        super.init()
    }

    func start() {
        print("Starting Wi-Fi Direct (Multipeer) Mouse Server...")
        print("Service type: \(serviceType)")
        print("Peer name: \(myPeerID.displayName)")

        // Create session with encryption
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        // Start advertising
        // Multipeer works over Wi-Fi Direct and Bluetooth, no network required
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self

        print("Starting Multipeer advertising...")
        print("  Service type: \(serviceType)")
        print("  Peer name: \(myPeerID.displayName)")
        advertiser?.startAdvertisingPeer()
        print("✓ Wi-Fi Direct service is advertising. iPhone can now discover and connect.")
        print("  Note: This works without Wi-Fi network - uses peer-to-peer connection")
        print("  Make sure Wi-Fi and Bluetooth are enabled on both devices")
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
        DispatchQueue.main.async {
            let currentLocation = NSEvent.mouseLocation
            let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

            let newX = currentLocation.x + deltaX
            let newY = currentLocation.y - deltaY

            let clampedX = max(screenFrame.minX, min(screenFrame.maxX, newX))
            let clampedY = max(screenFrame.minY, min(screenFrame.maxY, newY))

            let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: clampedX, y: clampedY), mouseButton: .left)
            moveEvent?.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerMouseServer: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("✅ iPhone CONNECTED via Wi-Fi Direct: \(peerID.displayName)")
            print("   Mouse control is now active!")
        case .connecting:
            print("📱 iPhone connecting via Wi-Fi Direct: \(peerID.displayName)")
        case .notConnected:
            print("❌ iPhone disconnected via Wi-Fi Direct: \(peerID.displayName)")
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = String(data: data, encoding: .utf8) {
            processMessage(message)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerMouseServer: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accept all invitations
        print("✓ Received connection invitation from: \(peerID.displayName)")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("✗ Failed to start advertising: \(error.localizedDescription)")
        print("  Error details: \(error)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didStartAdvertisingPeer error: Error?) {
        if let error = error {
            print("✗ Advertising error: \(error.localizedDescription)")
        } else {
            print("✓ Advertising started successfully")
        }
    }
}

