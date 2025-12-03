#!/bin/bash

# Build script for Mac Mouse Server

echo "Building Mac Mouse Server..."
cd MacMouseServer
swift build -c release

if [ $? -eq 0 ]; then
    echo ""
    echo "Build successful!"

    # Embed Info.plist into the executable
    if [ -f "Sources/MacMouseServer/Info.plist" ]; then
        echo "Embedding Info.plist into executable..."
        EXECUTABLE=".build/release/MacMouseServer"
        if [ -f "$EXECUTABLE" ]; then
            # For command-line tools, we need to embed Info.plist in the executable
            # Using PlistBuddy to merge it, or we can use a different approach
            # Copy Info.plist next to executable (macOS will find it for app bundles)
            cp "Sources/MacMouseServer/Info.plist" "$(dirname "$EXECUTABLE")/Info.plist"
            echo "✓ Info.plist copied to build directory"
            echo ""
            echo "⚠ Note: For command-line tools, macOS may not always show permission dialogs."
            echo "   If Local Network permission is not requested, you may need to:"
            echo "   1. Manually enable it in: System Settings > Privacy & Security > Local Network"
            echo "   2. Look for 'Terminal' or 'MacMouseServer' in the list"
            echo "   3. Enable the toggle for your Mac's network"
        fi
    fi

    echo ""
    echo "Run the server with:"
    echo "  ./run_mac_server.sh"
    echo ""
    echo "Or directly:"
    echo "  MacMouseServer/.build/release/MacMouseServer"
    echo ""
    echo "⚠ IMPORTANT PERMISSIONS:"
    echo "  1. Accessibility: System Settings > Privacy & Security > Accessibility"
    echo "     Add this app and enable it (required for mouse control)"
    echo "  2. Bluetooth: macOS will prompt when the server starts"
    echo "  3. Local Network: For command-line tools, permission is often auto-granted"
else
    echo "Build failed!"
    exit 1
fi

