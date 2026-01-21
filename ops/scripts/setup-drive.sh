#!/bin/bash
# Simple Google Drive setup for rclone
# Usage: ./setup-drive.sh [--full]
#   --full: Grant full access (upload/delete). Default is read-only.

set -e

# Parse args
SCOPE="drive.readonly"
SCOPE_DESC="read-only"
if [ "$1" = "--full" ]; then
    SCOPE="drive"
    SCOPE_DESC="full"
fi

echo "=== Google Drive Setup ($SCOPE_DESC access) ==="
echo ""

# Check/install rclone
if ! command -v rclone &> /dev/null; then
    echo "Installing rclone..."
    if command -v brew &> /dev/null; then
        brew install rclone
    else
        echo "Error: Please install Homebrew first (https://brew.sh)"
        exit 1
    fi
fi

# Check if already configured
if rclone listremotes 2>/dev/null | grep -q "^gdrive:"; then
    echo "Google Drive is already configured."
    echo "Testing connection..."
    if rclone lsd gdrive: --max-depth 1 &>/dev/null; then
        echo "Connection works."
        rclone lsd gdrive: --max-depth 1
    else
        echo "Connection failed. Run: rclone config reconnect gdrive:"
    fi
    exit 0
fi

echo "Opening browser for Google authentication..."
echo "Sign in and click 'Allow', then come back here."
echo ""

# Get token via browser
TOKEN_OUTPUT=$(rclone authorize "drive" --drive-scope "$SCOPE" 2>&1)

# Extract the token JSON from output
TOKEN=$(echo "$TOKEN_OUTPUT" | grep -A1 "Paste the following into your remote machine" | tail -1 | tr -d ' ')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "" ]; then
    TOKEN=$(echo "$TOKEN_OUTPUT" | grep -o '{.*}' | tail -1)
fi

if [ -z "$TOKEN" ]; then
    echo ""
    echo "Couldn't auto-capture the token."
    echo "Copy the token JSON from above (looks like {\"access_token\":\"...\"})"
    echo ""
    read -p "Paste here: " TOKEN
fi

# Create the remote
echo ""
echo "Configuring..."
rclone config create gdrive drive token "$TOKEN" scope "$SCOPE" --non-interactive

# Test
echo ""
if rclone lsd gdrive: --max-depth 1 &>/dev/null; then
    echo "Success! Google Drive connected ($SCOPE_DESC access)."
    echo ""
    rclone lsd gdrive: --max-depth 1
else
    echo "Something went wrong. Try: rclone config"
fi
