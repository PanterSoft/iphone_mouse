import Foundation
import AppKit

// Set to true to run cursor circle test instead of server
let runCircleTest = false
// Set to true to show visualization window
let showVisualization = true

if runCircleTest {
    CursorTest.runCircleTest()
    RunLoop.main.run()
} else {
    print("🚀 iPhone Mouse Server starting...")
    print("Press Ctrl+C to stop\n")

    let bluetoothServer = BluetoothMouseServer()
    let multipeerServer = MultipeerMouseServer()

    bluetoothServer.start()
    multipeerServer.start()

    print("✅ Servers ready - waiting for iPhone connection...\n")

    // Show visualization window if enabled
    if showVisualization {
        let visualizerWindow = MouseDataVisualizerWindowController()
        visualizerWindow.showWindow(nil)
        print("📊 Visualization window opened\n")
    }

    RunLoop.main.run()
}

