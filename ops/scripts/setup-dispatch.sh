#!/bin/bash
# Setup Dispatch Pipeline
# Run from your workspace, or pass the workspace path as an argument.
# Works via curl: bash <(curl -sL URL) ~/path/to/workspace
#
# What it does:
# 1. Installs rclone (no Homebrew, no sudo)
# 2. Connects your Google Drive
# 3. Downloads the transcription script
# 4. Schedules transcription every 2 hours via launchd
#
# After setup, recordings from Dispatch on your phone are
# automatically transcribed and appended to voice.md.

set -e

DISPATCH_HOME="$HOME/.dispatch"
RCLONE_DIR="$HOME/.local/bin"
DISPATCH_DIR="$HOME/Sync/dispatch"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.dispatch.transcribe"
SETUP_URL="https://raw.githubusercontent.com/derek-larson14/feed-the-beast/main/ops/scripts/setup-dispatch.sh"
TRANSCRIBE_URL="https://raw.githubusercontent.com/derek-larson14/feed-the-beast/main/ops/scripts/dispatch-transcribe.sh"

echo "=== Dispatch Pipeline Setup ==="
echo ""

# Detect workspace path
if [ -n "$1" ]; then
    WORKSPACE="$(cd "$1" && pwd)"
elif [ -f "CLAUDE.md" ]; then
    WORKSPACE="$PWD"
else
    echo "[!] Run this from your workspace folder (the one with CLAUDE.md)."
    echo "    cd ~/Downloads/claude-workspace && curl -sL $SETUP_URL | bash"
    exit 1
fi

if [ ! -f "$WORKSPACE/CLAUDE.md" ]; then
    echo "[!] No CLAUDE.md found in $WORKSPACE"
    echo "    Download the workspace first: delegatewithclaude.com/commands"
    exit 1
fi

echo "[ok] Workspace: $WORKSPACE"

# Save config
mkdir -p "$DISPATCH_HOME"
echo "WORKSPACE=$WORKSPACE" > "$DISPATCH_HOME/config"

# Step 1: Find or install rclone
RCLONE_PATH=$(which rclone 2>/dev/null || true)
if [ -n "$RCLONE_PATH" ]; then
    echo "[ok] rclone found at $RCLONE_PATH"
elif [ -f "$RCLONE_DIR/rclone" ]; then
    RCLONE_PATH="$RCLONE_DIR/rclone"
    echo "[ok] rclone found at $RCLONE_PATH"
else
    echo "[*] Installing rclone..."
    mkdir -p "$RCLONE_DIR"

    TMPDIR=$(mktemp -d)
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        RCLONE_ARCH="osx-arm64"
    else
        RCLONE_ARCH="osx-amd64"
    fi

    curl -sL "https://downloads.rclone.org/rclone-current-${RCLONE_ARCH}.zip" -o "$TMPDIR/rclone.zip"
    unzip -q "$TMPDIR/rclone.zip" -d "$TMPDIR"
    cp "$TMPDIR"/rclone-*/rclone "$RCLONE_DIR/rclone"
    chmod +x "$RCLONE_DIR/rclone"
    rm -rf "$TMPDIR"

    RCLONE_PATH="$RCLONE_DIR/rclone"
    echo "[ok] rclone installed to $RCLONE_PATH"
fi

# Step 2: Configure Google Drive remote
if "$RCLONE_PATH" listremotes 2>/dev/null | grep -q "^gdrive:"; then
    echo "[ok] gdrive remote already configured"
else
    echo ""
    echo "[*] Connecting Google Drive..."
    echo "    A browser window will open. Sign in with your Google account."
    echo ""
    "$RCLONE_PATH" config create gdrive drive
    echo ""
    echo "[ok] Google Drive connected"
fi

# Step 3: Test connection
echo ""
echo "[*] Testing Google Drive connection..."
if "$RCLONE_PATH" lsd gdrive: 2>/dev/null | head -3; then
    echo "[ok] Drive connection working"
else
    echo "[!] Could not list Drive contents — check with: $RCLONE_PATH config"
fi

if "$RCLONE_PATH" lsd gdrive:dispatch 2>/dev/null; then
    echo "[ok] dispatch/ folder found on Drive"
else
    echo "[*] dispatch/ folder not on Drive yet — it appears after your first recording"
fi

# Step 4: Create local directories
mkdir -p "$DISPATCH_DIR"
echo "[ok] Local dispatch directory: $DISPATCH_DIR"

# Step 5: Check hear installation
HEAR_PATH=$(which hear 2>/dev/null || echo "$HOME/.local/bin/hear")
if [ -f "$HEAR_PATH" ]; then
    echo "[ok] hear found at $HEAR_PATH"
else
    echo ""
    echo "[!] hear (Apple speech recognition) not installed"
    echo "    Run /voice-memos once in Claude Code — it installs hear for you"
    echo "    The pipeline works once hear is available"
fi

# Step 6: Download transcription script
echo ""
echo "[*] Downloading transcription script..."
curl -sL "$TRANSCRIBE_URL" -o "$DISPATCH_HOME/dispatch-transcribe.sh"
chmod +x "$DISPATCH_HOME/dispatch-transcribe.sh"
echo "[ok] Saved to $DISPATCH_HOME/dispatch-transcribe.sh"

# Step 7: Create and load launchd job
PLIST_PATH="$PLIST_DIR/$PLIST_NAME.plist"

# Unload existing if present
launchctl list "$PLIST_NAME" 2>/dev/null && launchctl unload "$PLIST_PATH" 2>/dev/null || true

mkdir -p "$PLIST_DIR"
cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$DISPATCH_HOME/dispatch-transcribe.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Hour</key><integer>8</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>22</integer><key>Minute</key><integer>0</integer></dict>
    </array>
    <key>StandardOutPath</key>
    <string>$DISPATCH_HOME/transcribe.log</string>
    <key>StandardErrorPath</key>
    <string>$DISPATCH_HOME/transcribe.log</string>
</dict>
</plist>
PLIST

launchctl load "$PLIST_PATH"
echo "[ok] Scheduled transcription every 2 hours (8am–10pm)"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "How it works:"
echo "  1. Record on your phone with Dispatch"
echo "  2. Recordings upload to Google Drive"
echo "  3. Every 2 hours, your Mac pulls and transcribes them"
echo "  4. Transcriptions appear in $WORKSPACE/voice.md"
echo ""
echo "Run /voice in Claude Code to route transcripts to tasks and notes."
