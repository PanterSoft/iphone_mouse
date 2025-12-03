#!/bin/bash

# Build script for Mac Mouse Server

echo "Building Mac Mouse Server..."
cd MacMouseServer
swift build -c release

if [ $? -eq 0 ]; then
    echo "✓ Build successful"

    if [ -f "Sources/MacMouseServer/Info.plist" ]; then
        EXECUTABLE=".build/release/MacMouseServer"
        if [ -f "$EXECUTABLE" ]; then
            cp "Sources/MacMouseServer/Info.plist" "$(dirname "$EXECUTABLE")/Info.plist"
        fi
    fi

    echo "Run: ./run_mac_server.sh"
else
    echo "✗ Build failed"
    exit 1
fi

