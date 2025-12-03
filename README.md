# iPhone Mouse

Use your iPhone as a wireless mouse for your Mac by tracking device movement and translating it to cursor movements.

## Features

- Real-time motion tracking using CoreMotion
- **Bluetooth support** - Connect via Bluetooth Low Energy (BLE)
- **Wi-Fi support** - Connect via local network (TCP)
- Simple connection interface with device scanning
- Low latency mouse control
- Automatic IP address display on Mac server

## Setup

### Mac Server Setup

1. **Build the Mac server:**
   ```bash
   ./build_mac_server.sh
   ```
   Or manually:
   ```bash
   cd MacMouseServer
   swift build -c release
   ```

2. **Run the server:**
   ```bash
   ./run_mac_server.sh
   ```
   Or directly:
   ```bash
   MacMouseServer/.build/release/MacMouseServer
   ```

   The run script will automatically build the server if it's not already built.

3. **Grant Required Permissions:**
   - **Accessibility** (Required for mouse control):
     - Go to System Settings > Privacy & Security > Accessibility
     - Add the MacMouseServer executable to the list and enable it
   - **Bluetooth** (Required for Bluetooth mode):
     - Go to System Settings > Privacy & Security > Bluetooth
     - Enable Bluetooth access if prompted
     - Make sure Bluetooth is enabled in System Settings > Bluetooth
   - **Local Network** (Required for Wi-Fi mode):
     - Go to System Settings > Privacy & Security > Local Network
     - Enable local network access if prompted
   - **Note**: macOS may prompt for these permissions automatically when the server starts

4. **Verify the server is running:**
   - The server will display status messages for each mode
   - Look for "✓ Bluetooth service is advertising" for Bluetooth
   - Look for "✓ Wi-Fi Direct service is advertising" for Wi-Fi Direct
   - Look for "✓ Advertising started successfully" for Bonjour

### iOS App Setup

**Note:** Due to the complexity of Xcode project files, it's recommended to create the project in Xcode:

1. **Create a new Xcode project:**
   - Open Xcode
   - File > New > Project
   - Choose "iOS" > "App"
   - Name: `iPhoneMouse`
   - Interface: SwiftUI
   - Language: Swift
   - Save it in the same directory as this README (or choose a location)

2. **Replace default files:**
   - Delete the default `ContentView.swift` and `iPhoneMouseApp.swift` files
   - Copy all files from the `iPhoneMouse/` folder into your new project:
     - `iPhoneMouseApp.swift`
     - `ContentView.swift`
     - `MotionController.swift`
     - `NetworkManager.swift`
     - `iPhoneMouse.entitlements` (add to project)
     - `Assets.xcassets` folder contents

3. **Configure the app:**
   - Select your development team in Signing & Capabilities
   - Ensure the bundle identifier is set (e.g., `com.iphone.mouse`)
   - Build and run on your iPhone

4. **Connect:**

   **Bluetooth Mode (Recommended):**
   - Select "Bluetooth" in the connection mode picker
   - The app will automatically scan for your Mac
   - Tap on "Mac Mouse Server" when it appears
   - Start moving your iPhone to control the mouse!

   **Wi-Fi Mode:**
   - Select "Wi-Fi" in the connection mode picker
   - Enter your Mac's IP address (shown in the Mac server terminal)
   - Tap "Connect"
   - Start moving your iPhone to control the mouse!

## How It Works

1. The iOS app uses CoreMotion to track device orientation changes
2. Movement data is sent over TCP to the Mac server
3. The Mac server translates the movement data into mouse cursor movements
4. The cursor position is updated in real-time

## Requirements

- iOS 17.0+
- macOS 13.0+
- **Bluetooth mode:** Bluetooth enabled on both devices
- **Wi-Fi mode:** Both devices on the same local network
- Accessibility permissions granted on Mac

## Troubleshooting

**Bluetooth Mode:**
- **iPhone not seeing Mac:**
  - Check Mac server terminal - look for "✓ Bluetooth service is advertising"
  - Ensure Bluetooth is enabled on both devices (System Settings > Bluetooth)
  - Check System Settings > Privacy & Security > Bluetooth on Mac - ensure access is granted
  - Make sure devices are within Bluetooth range (typically 10 meters)
  - Try restarting the Mac server
  - On iPhone, check Settings > Privacy & Security > Bluetooth - ensure access is granted
- **Connection fails:**
  - Check Mac server terminal for error messages
  - Verify Bluetooth state shows "powered on" in terminal output
  - Try disabling and re-enabling Bluetooth on both devices

**Wi-Fi Direct Mode:**
- **iPhone not seeing Mac:**
  - Check Mac server terminal - look for "✓ Wi-Fi Direct service is advertising"
  - Ensure Wi-Fi is enabled on both devices (even if not connected to a network)
  - Ensure Bluetooth is enabled on both devices (Multipeer uses both)
  - Try restarting both the Mac server and the iPhone app
  - Check iPhone Settings > Privacy & Security > Local Network - ensure access is granted
- **Connection fails:**
  - Check Mac server terminal for error messages
  - Make sure both devices have Wi-Fi and Bluetooth enabled

**Wi-Fi (Bonjour) Mode:**
- **Connection fails:** Make sure both devices are on the same Wi-Fi network
- **Can't find IP:** Check the Mac server terminal output - it displays the IP automatically
- **Firewall blocking:** Ensure port 12345 is not blocked by firewall
- **Discovery error:** Check iPhone Settings > Privacy & Security > Local Network - ensure access is granted

**General:**
- **Mouse doesn't move:**
  - Check that Accessibility permissions are granted on Mac (System Settings > Privacy & Security > Accessibility)
  - Make sure the MacMouseServer executable is in the list and enabled
- **Bluetooth not working:**
  - Ensure Bluetooth is enabled in System Settings on both devices
  - Check System Settings > Privacy & Security > Bluetooth on Mac
  - Restart the Mac server and check terminal output for Bluetooth state
- **Permissions not working:**
  - macOS may need to be restarted after granting permissions
  - Try running the server from Terminal to see permission prompts
  - Check System Settings > Privacy & Security for all required permissions

