import Foundation
import AppKit

print("🚀 iPhone Mouse Server starting...")
print("Press Ctrl+C to stop\n")

let wifiServer = MacMouseServer()
let bluetoothServer = BluetoothMouseServer()
let multipeerServer = MultipeerMouseServer()

bluetoothServer.start()
wifiServer.start()
multipeerServer.start()

print("✅ Servers ready - waiting for iPhone connection...\n")

RunLoop.main.run()

