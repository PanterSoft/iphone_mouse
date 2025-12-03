import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var motionController = MotionController()
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var multipeerManager = MultipeerManager()

    @State private var isConnected: Bool = false
    @State private var discoveryTimeout: Bool = false
    @State private var selectedDevice: Any? = nil
    @State private var intendedConnectionMethod: ConnectionMethod? = nil
    @State private var showSettings: Bool = false
    @ObservedObject private var settings = SettingsManager.shared

    private let discoveryTimeoutSeconds: TimeInterval = 15

    var body: some View {
        VStack(spacing: 30) {
            if !isConnected {
                discoveryView
            } else {
                connectedView
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(motionController: motionController)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .task {
            startDiscovery()
        }
        .onAppear {
            if !isConnected {
                startDiscovery()
            }
        }
        .onChange(of: settings.sensorType) { _, _ in
            if isConnected {
                motionController.updateSensorType()
            }
        }
        .onChange(of: isConnected) { oldValue, newValue in
            if oldValue == true && newValue == false && intendedConnectionMethod == nil {
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
    }

    private var discoveryView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("iPhone Mouse")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                }
            }
            .padding(.horizontal)

            Text("Searching for Mac...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Using Wi-Fi Direct and Bluetooth")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                statusRow(title: "Wi-Fi Direct", status: multipeerManager.status)
                statusRow(title: "Bluetooth", status: bluetoothManager.status)
            }
            .padding(.horizontal)

            // Show specific error messages if any
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
                        Text("• Both devices have Bluetooth enabled")
                        Text("• Local Network permission granted (for Wi-Fi Direct)")
                        Text("  Go to: Settings > Privacy & Security > Local Network")
                        Text("  Find 'iPhone Mouse' and enable it")
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
        ZStack {
            if settings.sensorType == .arkit && settings.showARVisualization {
                ARVisualizationViewWrapper(motionController: motionController)
            }

            VStack(spacing: 20) {
                if !(settings.sensorType == .arkit && settings.showARVisualization) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Connected")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(sensorInstructionText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

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
            .background(settings.sensorType == .arkit && settings.showARVisualization ?
                       Color.black.opacity(0.3) : Color.clear)
            .cornerRadius(settings.sensorType == .arkit && settings.showARVisualization ? 0 : 10)
        }
    }

    private var sensorInstructionText: String {
        switch settings.sensorType {
        case .arkit:
            return "Move your iPhone on the table to control the mouse"
        case .imu:
            return "Move your iPhone on the table to control the mouse"
        }
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
        }
    }

    private func protocolName(for method: ConnectionMethod) -> String {
        switch method {
        case .bluetooth:
            return "Bluetooth"
        case .multipeer:
            return "Wi-Fi Direct"
        }
    }

    private func protocolColor(for method: ConnectionMethod) -> Color {
        switch method {
        case .bluetooth:
            return .blue
        case .multipeer:
            return .green
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

        return devices
    }

    private func startDiscovery() {
        discoveryTimeout = false

        if bluetoothManager.status == .stopped {
            bluetoothManager.reconnect()
        }

        if case .stopped = multipeerManager.status {
            multipeerManager.startBrowsing()
        } else if case .error = multipeerManager.status {
            multipeerManager.startBrowsing()
        }


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
    }

    private func connectToDevice(_ device: DiscoveredDeviceItem) {
        intendedConnectionMethod = device.method

        // Disconnect other managers, but preserve the one we're about to use
        switch device.method {
        case .bluetooth:
            if multipeerManager.isConnected {
                multipeerManager.disconnect()
            }
            if bluetoothManager.isConnected {
                bluetoothManager.disconnect()
            }
            multipeerManager.stopBrowsing()
        case .multipeer:
            if bluetoothManager.isConnected {
                bluetoothManager.disconnect()
            }
            bluetoothManager.stopScanning()
            // If multipeer is already connected, disconnect it first
            if multipeerManager.isConnected {
                multipeerManager.disconnect()
            }
        }

        motionController.stopMotionUpdates()
        isConnected = false
        discoveryTimeout = false

        // Connect using the selected method
        switch device.method {
        case .bluetooth:
            if let bluetoothDevice = device.bluetoothDevice {
                bluetoothManager.connect(to: bluetoothDevice)
            }
        case .multipeer:
            if let peer = device.multipeerPeer {
                // Ensure browsing is active
                if case .stopped = multipeerManager.status {
                    multipeerManager.startBrowsing()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.multipeerManager.connect(to: peer)
                    }
                } else if case .error = multipeerManager.status {
                    multipeerManager.startBrowsing()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.multipeerManager.connect(to: peer)
                    }
                } else {
                    // If we just disconnected, wait a moment before connecting
                    if multipeerManager.isConnected == false {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.multipeerManager.connect(to: peer)
                        }
                    } else {
                        // Browsing is active and not connected, connect immediately
                        multipeerManager.connect(to: peer)
                    }
                }
            }
        }
    }

    private func handleConnection(method: ConnectionMethod) {
        guard intendedConnectionMethod == method else {
            switch method {
            case .bluetooth:
                bluetoothManager.disconnect()
            case .multipeer:
                multipeerManager.disconnect()
            }
            return
        }

        isConnected = true
        discoveryTimeout = false

        motionController.bluetoothManager = method == .bluetooth ? bluetoothManager : nil
        motionController.multipeerManager = method == .multipeer ? multipeerManager : nil

        motionController.startMotionUpdates()
    }

    private func disconnect() {
        stopAllDiscovery()
        bluetoothManager.disconnect()
        multipeerManager.disconnect()

        motionController.stopMotionUpdates()
        isConnected = false
        discoveryTimeout = false
        intendedConnectionMethod = nil
    }

    enum ConnectionMethod {
        case bluetooth
        case multipeer
    }

    struct DiscoveredDeviceItem: Identifiable {
        let id: String
        let name: String
        let method: ConnectionMethod
        let bluetoothDevice: BluetoothManager.DiscoveredDevice?
        let multipeerPeer: MultipeerManager.DiscoveredPeer?

        init(id: String, name: String, method: ConnectionMethod, bluetoothDevice: BluetoothManager.DiscoveredDevice? = nil, multipeerPeer: MultipeerManager.DiscoveredPeer? = nil) {
            self.id = id
            self.name = name
            self.method = method
            self.bluetoothDevice = bluetoothDevice
            self.multipeerPeer = multipeerPeer
        }
    }
}

#Preview {
    ContentView()
}
