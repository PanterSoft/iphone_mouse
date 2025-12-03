import Foundation
import CoreBluetooth
import Network

/// Helper to verify Info.plist is being read and permissions are requested
class PermissionChecker {
    static func checkInfoPlist() {
        // Check if we can read our bundle's Info.plist
        if let infoPlist = Bundle.main.infoDictionary {
            print("✓ Info.plist is being read")

            // Check for required keys
            let requiredKeys = [
                "NSBluetoothAlwaysUsageDescription",
                "NSBluetoothPeripheralUsageDescription",
                "NSLocalNetworkUsageDescription",
                "NSBonjourServices"
            ]

            for key in requiredKeys {
                if let value = infoPlist[key] {
                    print("  ✓ Found: \(key)")
                    if key == "NSBonjourServices" {
                        print("    Value: \(value)")
                        if let array = value as? [String] {
                            print("    Type: Array with \(array.count) items")
                            for item in array {
                                print("      - \(item)")
                            }
                        } else {
                            print("    ⚠️ WARNING: NSBonjourServices is not an array! Type: \(type(of: value))")
                        }
                    }
                } else {
                    print("  ✗ Missing: \(key)")
                }
            }
        } else {
            print("✗ ERROR: Cannot read Info.plist from bundle!")
        }
    }

    static func requestBluetoothPermission() {
        // Creating CBCentralManager should trigger permission dialog
        // This is a test to verify it works
        let manager = CBCentralManager(delegate: nil, queue: .main)
        print("CBCentralManager created - Bluetooth permission should be requested")
        print("Current state: \(manager.state.rawValue)")
    }
}
