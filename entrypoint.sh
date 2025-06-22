#!/bin/bash

# entrypoint.sh - OpenMoHAA dedicated server entrypoint

set -e

# Default values
GAME_PORT=${GAME_PORT:-12203}
GAMESPY_PORT=${GAMESPY_PORT:-12300}

# Function to handle shutdown
cleanup() {
    echo "Shutting down OpenMoHAA server..."
    if [ -n "$SERVER_PID" ]; then
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    exit 0
}

# Trap signals
trap cleanup SIGTERM SIGINT

# Ensure game directory exists and has proper permissions
mkdir -p /usr/local/share/mohaa/main
mkdir -p /usr/local/share/mohaa/home/main

# Check if server binary exists and is executable
if [ ! -x "/usr/local/games/openmohaa/lib/openmohaa/omohaaded" ]; then
    echo "Error: OpenMoHAA server binary not found or not executable"
    exit 1
fi

# Check architecture compatibility
if ! /usr/local/games/openmohaa/lib/openmohaa/omohaaded --version >/dev/null 2>&1; then
    echo "Error: Binary architecture mismatch. Please ensure you're using the correct image for your platform."
    echo "Current architecture: $(uname -m)"
    echo "Binary info:"
    file /usr/local/games/openmohaa/lib/openmohaa/omohaaded || true
    exit 1
fi

echo "Starting OpenMoHAA server..."
echo "Game port: $GAME_PORT"
echo "GameSpy port: $GAMESPY_PORT"
echo "Architecture: $(uname -m)"

# Change to game directory
cd /usr/local/share/mohaa

# Start the server with provided arguments
/usr/local/games/openmohaa/lib/openmohaa/omohaaded \
    +set net_port "$GAME_PORT" \
    +set sv_gamespy_port "$GAMESPY_PORT" \
    "$@" &

SERVER_PID=$!

# Wait for the server process
wait $SERVER_PID
