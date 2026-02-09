#!/bin/bash
# Dispatch Transcription
# Pulls recordings from Google Drive, transcribes with Apple speech recognition.
# Runs on a schedule via launchd — set up by setup-dispatch.sh.
# Config at ~/.dispatch/config (workspace path).

CONFIG_FILE="$HOME/.dispatch/config"
DISPATCH_DIR="$HOME/Sync/dispatch"
DRIVE_FOLDER="gdrive:dispatch"

# Load workspace path
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: no config at $CONFIG_FILE"
    echo "Run setup-dispatch.sh first"
    exit 1
fi
source "$CONFIG_FILE"

if [ -z "$WORKSPACE" ] || [ ! -d "$WORKSPACE" ]; then
    echo "Error: workspace not found at $WORKSPACE"
    exit 1
fi

VOICE_DIR="$WORKSPACE/.voice"
DOWNLOADED_FILE="$VOICE_DIR/dispatch-downloaded"
PROCESSED_FILE="$VOICE_DIR/dispatch-processed"
VOICE_MD="$WORKSPACE/voice.md"

mkdir -p "$VOICE_DIR"

# Find hear
HEAR_PATH=$(which hear 2>/dev/null || echo "$HOME/.local/bin/hear")
if [ ! -f "$HEAR_PATH" ]; then
    echo "Error: hear not installed at $HEAR_PATH"
    echo "Run /voice-setup once in Claude Code to install it"
    exit 1
fi

# Find rclone
RCLONE_PATH=$(which rclone 2>/dev/null || echo "$HOME/.local/bin/rclone")

mkdir -p "$DISPATCH_DIR"
touch "$DOWNLOADED_FILE"
touch "$PROCESSED_FILE"

# Step 1: Pull new recordings from Google Drive
if [ -f "$RCLONE_PATH" ] && "$RCLONE_PATH" listremotes 2>/dev/null | grep -q "^gdrive:"; then
    echo "Checking Google Drive for new recordings..."
    "$RCLONE_PATH" lsf "$DRIVE_FOLDER" --include "*.m4a" 2>/dev/null | while read filename; do
        if ! grep -Fxq "$filename" "$DOWNLOADED_FILE" 2>/dev/null; then
            echo "Downloading: $filename"
            "$RCLONE_PATH" copy "$DRIVE_FOLDER/$filename" "$DISPATCH_DIR/"
            echo "$filename" >> "$DOWNLOADED_FILE"
        fi
    done
else
    echo "rclone not configured — skipping Drive pull"
fi

# Step 2: Transcribe new files
new_count=0
while IFS= read -r -d '' memo; do
    filename=$(basename "$memo")

    if grep -Fxq "$filename" "$PROCESSED_FILE"; then
        continue
    fi

    echo "Transcribing: $filename"

    created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$memo")

    transcript=$("$HEAR_PATH" -d -i "$memo" 2>/dev/null || echo "[transcription failed]")

    {
        echo ""
        echo "## Dispatch - $created"
        echo ""
        echo "$transcript"
        echo ""
    } >> "$VOICE_MD"

    echo "$filename" >> "$PROCESSED_FILE"

    ((new_count++))
done < <(find "$DISPATCH_DIR" -name "*.m4a" -print0 2>/dev/null)

if [ $new_count -gt 0 ]; then
    echo "Transcribed $new_count new memo(s)"
else
    echo "No new memos to transcribe"
fi
