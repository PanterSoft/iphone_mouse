# Setup Instructions

## Quick Setup

Since manually creating Xcode project files is complex, here's the easiest way to set up the iOS app:

### Option 1: Create Project in Xcode (Recommended)

1. Open Xcode
2. File > New > Project
3. Choose "iOS" > "App"
4. Name it "iPhoneMouse"
5. Choose a location (or use the existing iPhoneMouse folder)
6. Once created, replace the default files with the files in the `iPhoneMouse/` directory:
   - `iPhoneMouseApp.swift`
   - `ContentView.swift`
   - `MotionController.swift`
   - `NetworkManager.swift`
   - `iPhoneMouse.entitlements`
   - `Assets.xcassets` folder

### Option 2: Use the Provided Script

Run the setup script (if you have xcodegen installed):
```bash
./create_xcode_project.sh
```

## Mac Server Setup

The Mac server is already set up correctly:

1. **Build:**
   ```bash
   cd MacMouseServer
   swift build -c release
   ```

2. **Run:**
   ```bash
   .build/release/MacMouseServer
   ```

3. **Grant Accessibility permissions** in System Settings

