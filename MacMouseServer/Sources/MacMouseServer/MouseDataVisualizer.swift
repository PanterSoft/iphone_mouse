import SwiftUI
import AppKit
import Combine

/// Data point for visualization
struct MouseDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let deltaX: Double
    let deltaY: Double
    let buttons: UInt8
    let scroll: Int8
}

/// Observable class to collect and store mouse data
class MouseDataCollector: ObservableObject {
    static let shared = MouseDataCollector()

    @Published var dataPoints: [MouseDataPoint] = []
    @Published var totalPackets: Int = 0
    @Published var packetsPerSecond: Double = 0.0
    @Published var totalDeltaX: Double = 0.0
    @Published var totalDeltaY: Double = 0.0
    @Published var lastDeltaX: Double = 0.0
    @Published var lastDeltaY: Double = 0.0
    @Published var lastButtons: UInt8 = 0
    @Published var lastScroll: Int8 = 0
    @Published var connectionType: String = "Not Connected"

    private var packetTimestamps: [Date] = []
    private let maxDataPoints = 500 // Keep last 500 points for trajectory
    private var updateTimer: Timer?

    private init() {
        // Update packets per second every second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePacketsPerSecond()
        }
    }

    func recordData(deltaX: Double, deltaY: Double, buttons: UInt8, scroll: Int8, connectionType: String) {
        DispatchQueue.main.async {
            let point = MouseDataPoint(
                timestamp: Date(),
                deltaX: deltaX,
                deltaY: deltaY,
                buttons: buttons,
                scroll: scroll
            )

            self.dataPoints.append(point)
            if self.dataPoints.count > self.maxDataPoints {
                self.dataPoints.removeFirst()
            }

            self.totalPackets += 1
            self.totalDeltaX += deltaX
            self.totalDeltaY += deltaY
            self.lastDeltaX = deltaX
            self.lastDeltaY = deltaY
            self.lastButtons = buttons
            self.lastScroll = scroll
            self.connectionType = connectionType

            self.packetTimestamps.append(Date())
            // Keep only last 2 seconds of timestamps
            let cutoff = Date().addingTimeInterval(-2.0)
            self.packetTimestamps.removeAll { $0 < cutoff }
        }
    }

    private func updatePacketsPerSecond() {
        DispatchQueue.main.async {
            let cutoff = Date().addingTimeInterval(-1.0)
            self.packetTimestamps.removeAll { $0 < cutoff }
            self.packetsPerSecond = Double(self.packetTimestamps.count)
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.dataPoints.removeAll()
            self.totalPackets = 0
            self.totalDeltaX = 0.0
            self.totalDeltaY = 0.0
            self.lastDeltaX = 0.0
            self.lastDeltaY = 0.0
            self.lastButtons = 0
            self.lastScroll = 0
            self.packetTimestamps.removeAll()
            self.packetsPerSecond = 0.0
        }
    }
}

/// SwiftUI view for visualizing mouse data
struct MouseDataVisualizerView: View {
    @StateObject private var collector = MouseDataCollector.shared
    @State private var showTrajectory = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("iPhone Mouse Data Visualization")
                    .font(.headline)
                    .padding()
                Spacer()
                Button("Reset") {
                    collector.reset()
                }
                .padding()
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                HStack(alignment: .top, spacing: 20) {
                    // Left column: Status and data
                    VStack(alignment: .leading, spacing: 20) {
                        // Connection Status
                        connectionStatusView

                        // Real-time Values
                        realTimeValuesView

                        // Statistics
                        statisticsView

                        // Button States
                        buttonStatesView
                    }
                    .frame(minWidth: 350)

                    // Right column: Trajectory Graph
                    if showTrajectory {
                        trajectoryView
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
    }

    private var connectionStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection Status")
                .font(.headline)
            HStack {
                Circle()
                    .fill(collector.connectionType.contains("Not") ? Color.red : Color.green)
                    .frame(width: 12, height: 12)
                Text(collector.connectionType)
                    .font(.body)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var realTimeValuesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Real-time Values")
                .font(.headline)

            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text("Delta X")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", collector.lastDeltaX))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(collector.lastDeltaX != 0 ? .blue : .secondary)
                }

                VStack(alignment: .leading) {
                    Text("Delta Y")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", collector.lastDeltaY))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(collector.lastDeltaY != 0 ? .blue : .secondary)
                }

                VStack(alignment: .leading) {
                    Text("Scroll")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(collector.lastScroll)")
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(collector.lastScroll != 0 ? .orange : .secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 10) {
                GridRow {
                    Text("Packets Received:")
                    Text("\(collector.totalPackets)")
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("Packets/Second:")
                    Text(String(format: "%.1f", collector.packetsPerSecond))
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("Total ΔX:")
                    Text(String(format: "%.2f", collector.totalDeltaX))
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("Total ΔY:")
                    Text(String(format: "%.2f", collector.totalDeltaY))
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("Total Distance:")
                    Text(String(format: "%.2f", sqrt(collector.totalDeltaX * collector.totalDeltaX + collector.totalDeltaY * collector.totalDeltaY)))
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var buttonStatesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Button States")
                .font(.headline)

            HStack(spacing: 20) {
                buttonIndicator(name: "Left", isPressed: collector.lastButtons & MouseMovementProtocol.Buttons.left != 0)
                buttonIndicator(name: "Right", isPressed: collector.lastButtons & MouseMovementProtocol.Buttons.right != 0)
                buttonIndicator(name: "Middle", isPressed: collector.lastButtons & MouseMovementProtocol.Buttons.middle != 0)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func buttonIndicator(name: String, isPressed: Bool) -> some View {
        HStack {
            Circle()
                .fill(isPressed ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 16, height: 16)
            Text(name)
                .font(.body)
        }
    }

    private var trajectoryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Movement Trajectory")
                .font(.headline)

            GeometryReader { geometry in
                TrajectoryGraphView(dataPoints: collector.dataPoints)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(minHeight: 400) // Minimum height for trajectory
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// View that draws the trajectory graph
struct TrajectoryGraphView: View {
    let dataPoints: [MouseDataPoint]

    var body: some View {
        Canvas { context, size in
            guard !dataPoints.isEmpty else { return }

            // Calculate bounds
            let maxX = dataPoints.map { abs($0.deltaX) }.max() ?? 1.0
            let maxY = dataPoints.map { abs($0.deltaY) }.max() ?? 1.0
            let scale = min(size.width / (maxX * 2), size.height / (maxY * 2)) * 0.8

            // Draw axes
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                },
                with: .color(.gray.opacity(0.3)),
                lineWidth: 1
            )

            // Draw trajectory
            if dataPoints.count > 1 {
                var currentX: Double = size.width / 2
                var currentY: Double = size.height / 2

                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: currentX, y: currentY))

                        for point in dataPoints {
                            currentX += point.deltaX * scale
                            currentY -= point.deltaY * scale // Invert Y for screen coordinates

                            // Clamp to bounds
                            currentX = max(0, min(size.width, currentX))
                            currentY = max(0, min(size.height, currentY))

                            path.addLine(to: CGPoint(x: currentX, y: currentY))
                        }
                    },
                    with: .color(.blue),
                    lineWidth: 2
                )
            }

            // Draw current position
            if let lastPoint = dataPoints.last {
                let centerX = size.width / 2
                let centerY = size.height / 2
                let currentX = centerX + lastPoint.deltaX * scale
                let currentY = centerY - lastPoint.deltaY * scale

                context.fill(
                    Path { path in
                        path.addEllipse(in: CGRect(
                            x: currentX - 4,
                            y: currentY - 4,
                            width: 8,
                            height: 8
                        ))
                    },
                    with: .color(.red)
                )
            }
        }
    }
}

/// Window controller for the visualization
class MouseDataVisualizerWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "iPhone Mouse Data Visualization"
        window.center()
        window.setFrameAutosaveName("MouseDataVisualizer")

        let hostingView = NSHostingView(rootView: MouseDataVisualizerView())
        window.contentView = hostingView

        self.init(window: window)
    }
}

