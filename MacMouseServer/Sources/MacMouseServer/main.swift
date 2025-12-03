import Foundation
import AppKit

print("🚀 Starting iPhone Mouse Server...")
print("   Bluetooth, Wi-Fi (Bonjour), and Wi-Fi Direct modes are active")
print("")
print("⚠️  IMPORTANT PERMISSIONS:")
print("   1. Accessibility: System Settings > Privacy & Security > Accessibility")
print("      Add this app and enable it (required for mouse control)")
print("   2. Bluetooth: macOS will prompt when the server starts")
print("      If not prompted, check: System Settings > Privacy & Security > Bluetooth")
print("   3. Local Network: Requested when network services start")
print("      If not prompted, check: System Settings > Privacy & Security > Local Network")
print("      For command-line tools, permission may be tied to Terminal")
print("")
print("Press Ctrl+C to stop\n")

// Create servers - this will trigger permission requests
print("📡 Initializing servers and requesting permissions...")
let wifiServer = MacMouseServer()
let bluetoothServer = BluetoothMouseServer()
let multipeerServer = MultipeerMouseServer()

// Start all servers - this triggers permission requests
print("\n🔵 Starting Bluetooth server (will request Bluetooth permission)...")
bluetoothServer.start()

print("🌐 Starting Wi-Fi (Bonjour) server (will request Local Network permission)...")
wifiServer.start()

print("📶 Starting Wi-Fi Direct (Multipeer) server (will request Local Network permission)...")
multipeerServer.start()

print("\n✅ All servers started")
print("📱 Waiting for iPhone to connect...\n")

// Keep the program running
RunLoop.main.run()

