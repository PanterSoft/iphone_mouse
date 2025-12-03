import Foundation
import AppKit

print("🚀 iPhone Mouse Server starting...")
print("Press Ctrl+C to stop\n")

let bluetoothServer = BluetoothMouseServer()
let multipeerServer = MultipeerMouseServer()

bluetoothServer.start()
multipeerServer.start()

print("✅ Servers ready - waiting for iPhone connection...\n")

RunLoop.main.run()

