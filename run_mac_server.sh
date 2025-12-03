#!/bin/bash

# Run script for Mac Mouse Server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_PATH="$SCRIPT_DIR/MacMouseServer/.build/release/MacMouseServer"

if [ ! -f "$SERVER_PATH" ]; then
    echo "Building server..."
    cd "$SCRIPT_DIR"
    ./build_mac_server.sh
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

if pgrep -f "MacMouseServer" > /dev/null; then
    echo "⚠ Server already running"
    read -p "Kill and restart? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pkill -f "MacMouseServer"
        sleep 1
    else
        exit 0
    fi
fi

exec "$SERVER_PATH"

