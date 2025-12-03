#!/bin/bash

# Run script for Mac Mouse Server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_PATH="$SCRIPT_DIR/MacMouseServer/.build/release/MacMouseServer"

# Check if server exists
if [ ! -f "$SERVER_PATH" ]; then
    echo "✗ Server not found at: $SERVER_PATH"
    echo ""
    echo "Building server first..."
    cd "$SCRIPT_DIR"
    ./build_mac_server.sh

    if [ $? -ne 0 ]; then
        echo "Build failed! Cannot run server."
        exit 1
    fi
fi

# Check if server is already running
if pgrep -f "MacMouseServer" > /dev/null; then
    echo "⚠ Mac Mouse Server is already running!"
    echo "   Kill the existing process first, or use a different terminal."
    echo ""
    read -p "Kill existing server and start new one? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pkill -f "MacMouseServer"
        sleep 1
    else
        exit 0
    fi
fi

echo "Starting Mac Mouse Server..."
echo ""

# Run the server
exec "$SERVER_PATH"

