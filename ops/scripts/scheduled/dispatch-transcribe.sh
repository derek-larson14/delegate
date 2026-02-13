#!/bin/bash
# Dispatch Transcription
# Pulls recordings from Google Drive, appends transcripts to voice.md
# Uses on-device transcriptions (.md companion files) when available, falls back to hear
# Runs on a schedule via launchd — set up by setup-dispatch.sh.
# Config at ~/.dispatch/config (workspace path).

CONFIG_FILE="$HOME/.dispatch/config"
DISPATCH_DIR="$HOME/Sync/dispatch"
DRIVE_AUDIO="gdrive:dispatch/audio"
DRIVE_TRANSCRIPTS="gdrive:dispatch/transcripts"

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

# Find tools (optional — hear only needed as fallback)
HEAR_PATH=$(which hear 2>/dev/null || echo "$HOME/.local/bin/hear")
RCLONE_PATH=$(which rclone 2>/dev/null || echo "$HOME/.local/bin/rclone")

mkdir -p "$DISPATCH_DIR"
touch "$DOWNLOADED_FILE"
touch "$PROCESSED_FILE"

# Step 1: Pull new files from Google Drive
if [ -f "$RCLONE_PATH" ] && "$RCLONE_PATH" listremotes 2>/dev/null | grep -q "^gdrive:"; then
    echo "Checking Google Drive for new recordings..."
    "$RCLONE_PATH" lsf "$DRIVE_AUDIO" --include "*.m4a" 2>/dev/null | while read filename; do
        if ! grep -Fxq "$filename" "$DOWNLOADED_FILE" 2>/dev/null; then
            echo "Downloading: $filename"
            "$RCLONE_PATH" copy "$DRIVE_AUDIO/$filename" "$DISPATCH_DIR/"
            # Pull companion transcript if it exists (on-device or Apps Script)
            md_file="${filename%.m4a}.md"
            "$RCLONE_PATH" copy "$DRIVE_TRANSCRIPTS/$md_file" "$DISPATCH_DIR/" 2>/dev/null || true
            echo "$filename" >> "$DOWNLOADED_FILE"
        fi
    done
else
    echo "rclone not configured — skipping Drive pull"
fi

# Step 2: Process new audio files
new_count=0
while IFS= read -r -d '' memo; do
    filename=$(basename "$memo")

    if grep -Fxq "$filename" "$PROCESSED_FILE"; then
        continue
    fi

    # Check for companion transcript (on-device or Apps Script transcription)
    md_file="$DISPATCH_DIR/${filename%.m4a}.md"

    if [ -f "$md_file" ]; then
        echo "Using transcript: $filename"
        transcript=$(cat "$md_file")
    elif [ -f "$HEAR_PATH" ]; then
        echo "Transcribing with hear: $filename"
        transcript=$("$HEAR_PATH" -d -i "$memo" 2>/dev/null || echo "[transcription failed]")
    else
        echo "Skipping $filename — no transcript and hear not installed"
        continue
    fi

    # Parse date from filename: dispatch_YYYYMMDD_HHMMSS.m4a
    date_part=$(echo "$filename" | grep -oE '[0-9]{8}_[0-9]{6}' || echo "")
    if [ -n "$date_part" ]; then
        created="${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${date_part:9:2}:${date_part:11:2}"
    else
        created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$memo")
    fi

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
    echo "Processed $new_count new memo(s)"
else
    echo "No new memos to process"
fi
