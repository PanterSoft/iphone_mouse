import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var motionController = MotionController()
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var multipeerManager = MultipeerManager()
    @StateObject private var bonjourManager = BonjourDiscoveryManager()
    @StateObject private var networkManager = NetworkManager()

    @State private var isConnected: Bool = false
    @State private var discoveryTimeout: Bool = false
    @State private var selectedDevice: Any? = nil
    @State private var intendedConnectionMethod: ConnectionMethod? = nil

    private let discoveryTimeoutSeconds: TimeInterval = 15

    var body: some View {
        VStack(spacing: 30) {
            if !isConnected {
                discoveryView
            } else {
                connectedView
            }
        }
        .task {
            // Verify Info.plist is being read (debug only - remove in production)
            #if DEBUG
            PermissionChecker.checkInfoPlist()
            #endif

            // Use .task instead of .onAppear to ensure it runs immediately
            // This ensures permission requests happen as soon as the view appears
            startDiscovery()
        }
        .onAppear {
            // When app appears (e.g., returning from Settings), restart discovery
            // This allows retry after user enables permissions
            if !isConnected {
                startDiscovery()
            }
        }
        .onChange(of: isConnected) { oldValue, newValue in
            // When disconnecting (going from connected to not connected), restart discovery
            // But only if we're not in the middle of connecting to a new device
            if oldValue == true && newValue == false && intendedConnectionMethod == nil {
                // Small delay to ensure disconnect is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startDiscovery()
                }
            }
        }
        .onChange(of: bluetoothManager.isConnected) { oldValue, newValue in
            if newValue && intendedConnectionMethod == .bluetooth {
                handleConnection(method: .bluetooth)
            }
        }
        .onChange(of: multipeerManager.isConnected) { oldValue, newValue in
            if newValue && intendedConnectionMethod == .multipeer {
                handleConnection(method: .multipeer)
            }
        }
        .onChange(of: bonjourManager.isConnected) { oldValue, newValue in
            if newValue && intendedConnectionMethod == .bonjour {
                handleConnection(method: .bonjour)
            }
        }
    }

    private var discoveryView: some View {
        VStack(spacing: 20) {
            Text("iPhone Mouse")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Searching for Mac...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Using Wi-Fi Direct, Bluetooth, and Wi-Fi")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                statusRow(title: "Wi-Fi Direct", status: multipeerManager.status)
                statusRow(title: "Bluetooth", status: bluetoothManager.status)
                statusRow(title: "Wi-Fi (Bonjour)", status: bonjourManager.status)
            }
            .padding(.horizontal)

            // Show specific error messages if any
            if let bonjourStatus = bonjourManager.status as? BonjourDiscoveryManager.ConnectionStatus,
               case .error(let msg) = bonjourStatus, msg.contains("Local Network") {
                VStack(spacing: 8) {
                    Text("⚠️ Local Network Permission Needed")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    Text("iOS doesn't always show a permission dialog for Local Network access. Please enable it manually:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }

                    Text("Then go to: Privacy & Security > Local Network > iPhone Mouse")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            if let multipeerStatus = multipeerManager.status as? MultipeerManager.ConnectionStatus,
               case .error(let msg) = multipeerStatus, msg.contains("Local Network") {
                VStack(spacing: 8) {
                    Text("⚠️ Local Network Permission Needed")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    Text("iOS doesn't always show a permission dialog for Local Network access. Please enable it manually:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }

                    Text("Then go to: Privacy & Security > Local Network > iPhone Mouse")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }

            if discoveryTimeout {
                VStack(spacing: 10) {
                    ProgressView()
                        .padding()

                    Text("Discovery timeout. Make sure:")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("• Mac server is running")
                        Text("• Both devices are on the same Wi-Fi network")
                        Text("• Firewall allows Bonjour/mDNS")
                        Text("• Local Network permission granted")
                        Text("  Go to: Settings > Privacy & Security > Local Network")
                        Text("  Find 'iPhone Mouse' and enable it")
                        Text("  (If not listed, restart the app after granting permission)")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)

                    Button(action: {
                        restartDiscovery()
                    }) {
                        Text("Try Again")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
            } else {
                ProgressView()
                    .padding()
            }

            // Show discovered devices
            if !allDiscoveredDevices.isEmpty {
                List(allDiscoveredDevices) { device in
                    Button(action: {
                        connectToDevice(device)
                    }) {
                        HStack {
                            Image(systemName: "desktopcomputer")
                                .foregroundColor(.blue)
                            Text(device.name)
                                .foregroundColor(.primary)
                            Spacer()
                            protocolBadge(for: device.method)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
    }

    private var connectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Connected")
                .font(.title)
                .fontWeight(.bold)

            Text("Move your iPhone to control the mouse")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                motionController.resetReference()
            }) {
                Text("Reset Position")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Button(action: {
                disconnect()
            }) {
                Text("Disconnect")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .padding()
    }

    private func statusRow(title: String, status: Any) -> some View {
        HStack {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text("\(title): \(statusText(status))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func statusColor(_ status: Any) -> Color {
        if let bluetoothStatus = status as? BluetoothManager.ConnectionStatus {
            switch bluetoothStatus {
            case .stopped, .error:
                return .gray
            case .starting, .scanning:
                return .yellow
            case .connected:
                return .green
            }
        } else if let multipeerStatus = status as? MultipeerManager.ConnectionStatus {
            switch multipeerStatus {
            case .stopped, .error:
                return .gray
            case .starting, .browsing:
                return .yellow
            case .connected:
                return .green
            }
        } else if let bonjourStatus = status as? BonjourDiscoveryManager.ConnectionStatus {
            switch bonjourStatus {
            case .stopped, .error:
                return .gray
            case .starting, .discovering:
                return .yellow
            case .connected:
                return .green
            }
        }
        return .gray
    }

    private func statusText(_ status: Any) -> String {
        if let bluetoothStatus = status as? BluetoothManager.ConnectionStatus {
            switch bluetoothStatus {
            case .stopped: return "Stopped"
            case .starting: return "Starting..."
            case .scanning: return "Scanning..."
            case .connected: return "Connected"
            case .error(let msg): return "Error: \(msg)"
            }
        } else if let multipeerStatus = status as? MultipeerManager.ConnectionStatus {
            switch multipeerStatus {
            case .stopped: return "Stopped"
            case .starting: return "Starting..."
            case .browsing: return "Browsing..."
            case .connected: return "Connected"
            case .error(let msg): return "Error: \(msg)"
            }
        } else if let bonjourStatus = status as? BonjourDiscoveryManager.ConnectionStatus {
            switch bonjourStatus {
            case .stopped: return "Stopped"
            case .starting: return "Starting..."
            case .discovering: return "Discovering..."
            case .connected: return "Connected"
            case .error(let msg): return "Error: \(msg)"
            }
        }
        return "Unknown"
    }

    private func protocolBadge(for method: ConnectionMethod) -> some View {
        HStack(spacing: 4) {
            Image(systemName: protocolIcon(for: method))
                .font(.caption)
            Text(protocolName(for: method))
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(protocolColor(for: method))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(protocolColor(for: method).opacity(0.15))
        .cornerRadius(8)
    }

    private func protocolIcon(for method: ConnectionMethod) -> String {
        switch method {
        case .bluetooth:
            return "wave.3.right.circle.fill"
        case .multipeer:
            return "wifi.circle.fill"
        case .bonjour:
            return "network"
        }
    }

    private func protocolName(for method: ConnectionMethod) -> String {
        switch method {
        case .bluetooth:
            return "Bluetooth"
        case .multipeer:
            return "Wi-Fi Direct"
        case .bonjour:
            return "Wi-Fi"
        }
    }

    private func protocolColor(for method: ConnectionMethod) -> Color {
        switch method {
        case .bluetooth:
            return .blue
        case .multipeer:
            return .green
        case .bonjour:
            return .orange
        }
    }

    private var allDiscoveredDevices: [DiscoveredDeviceItem] {
        var devices: [DiscoveredDeviceItem] = []

        for device in bluetoothManager.discoveredDevices {
            devices.append(DiscoveredDeviceItem(
                id: "bluetooth-\(device.id.uuidString)",
                name: device.name,
                method: .bluetooth,
                bluetoothDevice: device
            ))
        }

        for peer in multipeerManager.discoveredDevices {
            devices.append(DiscoveredDeviceItem(
                id: "multipeer-\(peer.id)",
                name: peer.name,
                method: .multipeer,
                multipeerPeer: peer
            ))
        }

        for service in bonjourManager.discoveredServices {
            devices.append(DiscoveredDeviceItem(
                id: "bonjour-\(service.id)",
                name: service.name,
                method: .bonjour,
                bonjourService: service
            ))
        }

        return devices
    }

    private func startDiscovery() {
        // CRITICAL: These calls must happen synchronously on the main thread
        // to trigger iOS permission dialogs. Do NOT wrap these in async blocks.

        // Reset timeout
        discoveryTimeout = false

        // Bluetooth: CBCentralManager was created in BluetoothManager.init()
        // The permission dialog should have appeared when the manager was initialized.
        // If it didn't, check that Info.plist has NSBluetoothAlwaysUsageDescription
        // Restart scanning if stopped
        if bluetoothManager.status == .stopped {
            bluetoothManager.reconnect()
        }

        // Multipeer (Wi-Fi Direct): This MUST be called synchronously to trigger permission
        // MCNearbyServiceBrowser.startBrowsingForPeers() triggers Local Network permission
        // Note: Local Network permission may not show a dialog - check Settings if needed
        if case .stopped = multipeerManager.status {
            multipeerManager.startBrowsing()
        } else if case .error = multipeerManager.status {
            // If there was an error, try to restart (user may have fixed permission)
            multipeerManager.startBrowsing()
        }

        // Bonjour: This MUST be called synchronously to trigger permission
        // NetServiceBrowser.searchForServices() triggers Local Network permission
        // Note: Local Network permission may not show a dialog - check Settings if needed
        if bonjourManager.status == .stopped {
            bonjourManager.startDiscovery()
        } else if case .error = bonjourManager.status {
            // If there was an error, try to restart
            bonjourManager.startDiscovery()
        }

        // Set timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + discoveryTimeoutSeconds) {
            if !isConnected && allDiscoveredDevices.isEmpty {
                discoveryTimeout = true
            }
        }
    }

    private func restartDiscovery() {
        discoveryTimeout = false
        stopAllDiscovery()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startDiscovery()
        }
    }

    private func stopAllDiscovery() {
        bluetoothManager.stopScanning()
        multipeerManager.stopBrowsing()
        bonjourManager.stopDiscovery()
    }

    private func connectToDevice(_ device: DiscoveredDeviceItem) {
        // Set the intended connection method before disconnecting
        intendedConnectionMethod = device.method

        // Disconnect managers that are NOT the intended connection method
        // Also disconnect the intended manager if it's already connected (switching connections)
        switch device.method {
        case .bluetooth:
            if multipeerManager.isConnected {
                multipeerManager.disconnect()
            }
            if bonjourManager.isConnected {
                bonjourManager.disconnect()
            }
            if bluetoothManager.isConnected {
                bluetoothManager.disconnect()
            }
            networkManager.disconnect()
        case .multipeer:
            if bluetoothManager.isConnected {
                bluetoothManager.disconnect()
            }
            if bonjourManager.isConnected {
                bonjourManager.disconnect()
            }
            // For multipeer, only disconnect if already connected
            // Don't stop browsing as we need it for connection
            if multipeerManager.isConnected {
                multipeerManager.disconnect()
            }
            networkManager.disconnect()
        case .bonjour:
            if bluetoothManager.isConnected {
                bluetoothManager.disconnect()
            }
            if multipeerManager.isConnected {
                multipeerManager.disconnect()
            }
            if bonjourManager.isConnected {
                bonjourManager.disconnect()
            }
            networkManager.disconnect()
        }

        motionController.stopMotionUpdates()

        // Reset connection state
        isConnected = false
        discoveryTimeout = false

        // Stop discovery for other methods, but keep the intended method's discovery active
        // (needed for multipeer which requires active browser)
        switch device.method {
        case .bluetooth:
            multipeerManager.stopBrowsing()
            bonjourManager.stopDiscovery()
        case .multipeer:
            bluetoothManager.stopScanning()
            bonjourManager.stopDiscovery()
            // Ensure multipeer is browsing - it's needed for connection
            if multipeerManager.status == .stopped {
                multipeerManager.startBrowsing()
            }
        case .bonjour:
            bluetoothManager.stopScanning()
            multipeerManager.stopBrowsing()
            // Bonjour can connect directly without active discovery
        }

        // Connect using the selected method
        switch device.method {
        case .bluetooth:
            if let bluetoothDevice = device.bluetoothDevice {
                bluetoothManager.connect(to: bluetoothDevice)
            }
        case .multipeer:
            if let peer = device.multipeerPeer {
                // Ensure session and browser are active for multipeer
                if case .stopped = multipeerManager.status {
                    // Start browsing and wait for session to be ready
                    multipeerManager.startBrowsing()
                    // Wait longer for session to be fully initialized
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.multipeerManager.connect(to: peer)
                    }
                } else if case .error = multipeerManager.status {
                    // If there was an error, restart browsing
                    multipeerManager.startBrowsing()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.multipeerManager.connect(to: peer)
                    }
                } else {
                    // Browser is active (browsing or connected)
                    // Always add a small delay to ensure session is fully ready
                    // This helps prevent the first connection attempt from failing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.multipeerManager.connect(to: peer)
                    }
                }
            }
        case .bonjour:
            if let service = device.bonjourService {
                bonjourManager.connect(to: service)
            }
        }
    }

    private func handleConnection(method: ConnectionMethod) {
        // Verify this is the intended connection method
        guard intendedConnectionMethod == method else {
            // This connection is not the one we want, disconnect it
            switch method {
            case .bluetooth:
                bluetoothManager.disconnect()
            case .multipeer:
                multipeerManager.disconnect()
            case .bonjour:
                bonjourManager.disconnect()
            }
            return
        }

        isConnected = true
        discoveryTimeout = false

        // Set the appropriate manager in motion controller
        motionController.bluetoothManager = method == .bluetooth ? bluetoothManager : nil
        motionController.networkManager = (method == .bonjour || method == .multipeer) ? networkManager : nil

        // For multipeer and bonjour, we need to set up the network manager connection
        if method == .multipeer {
            // Multipeer handles its own connection
            motionController.multipeerManager = multipeerManager
        } else if method == .bonjour {
            // Bonjour handles its own connection
            motionController.bonjourManager = bonjourManager
        }

        // Start motion updates - the reference will be set automatically after a short delay
        // This ensures the reference is set correctly when connection is established
        motionController.startMotionUpdates()
    }

    private func disconnect() {
        stopAllDiscovery()
        bluetoothManager.disconnect()
        multipeerManager.disconnect()
        bonjourManager.disconnect()
        networkManager.disconnect()

        motionController.stopMotionUpdates()
        isConnected = false
        discoveryTimeout = false
        intendedConnectionMethod = nil
    }

    enum ConnectionMethod {
        case bluetooth
        case multipeer
        case bonjour
    }

    struct DiscoveredDeviceItem: Identifiable {
        let id: String
        let name: String
        let method: ConnectionMethod
        let bluetoothDevice: BluetoothManager.DiscoveredDevice?
        let multipeerPeer: MultipeerManager.DiscoveredPeer?
        let bonjourService: BonjourDiscoveryManager.DiscoveredService?

        init(id: String, name: String, method: ConnectionMethod, bluetoothDevice: BluetoothManager.DiscoveredDevice? = nil, multipeerPeer: MultipeerManager.DiscoveredPeer? = nil, bonjourService: BonjourDiscoveryManager.DiscoveredService? = nil) {
            self.id = id
            self.name = name
            self.method = method
            self.bluetoothDevice = bluetoothDevice
            self.multipeerPeer = multipeerPeer
            self.bonjourService = bonjourService
        }
    }
}

#Preview {
    ContentView()
}
