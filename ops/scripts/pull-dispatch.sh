#!/bin/bash
# Pull Dispatch recordings from Google Drive and get them into voice.md.
# Two modes:
#   1. If dispatch-transcripts.md exists on Drive (Gemini Apps Script is transcribing),
#      pull that file and extract new entries.
#   2. If not, pull raw .m4a files and transcribe locally with hear.
#
# Called by /voice-memos when source is Google Drive.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DISPATCH_DIR="$HOME/Sync/dispatch"
DRIVE_FOLDER="gdrive:dispatch"
VOICE_MD="$VAULT_ROOT/voice.md"
DOWNLOADED_FILE="$VAULT_ROOT/.dispatch-downloaded"
PROCESSED_FILE="$VAULT_ROOT/.dispatch-processed"
SYNC_FILE="$VAULT_ROOT/.dispatch-sync"

# Find rclone
RCLONE_PATH=$(which rclone 2>/dev/null || echo "$HOME/.local/bin/rclone")
if [ ! -f "$RCLONE_PATH" ]; then
    echo "Error: rclone not installed"
    echo "Run: curl -sL https://raw.githubusercontent.com/derek-larson14/feed-the-beast/main/ops/scripts/setup-dispatch.sh | bash"
    exit 1
fi

# Check rclone is configured
if ! "$RCLONE_PATH" listremotes 2>/dev/null | grep -q "^gdrive:"; then
    echo "Error: Google Drive not connected"
    echo "Run: rclone config create gdrive drive"
    exit 1
fi

# Check if Gemini transcript exists on Drive
has_transcript=false
if "$RCLONE_PATH" lsf "$DRIVE_FOLDER/dispatch-transcripts.md" 2>/dev/null | grep -q "dispatch-transcripts.md"; then
    has_transcript=true
fi

if [ "$has_transcript" = true ]; then
    # ── Mode 1: Pull pre-transcribed file from Drive ──
    echo "Found dispatch-transcripts.md on Drive (Gemini transcription)"

    mkdir -p /tmp/dispatch-sync
    "$RCLONE_PATH" copy "$DRIVE_FOLDER/dispatch-transcripts.md" /tmp/dispatch-sync/

    REMOTE_FILE="/tmp/dispatch-sync/dispatch-transcripts.md"

    if [ ! -f "$REMOTE_FILE" ]; then
        echo "Error: failed to download dispatch-transcripts.md"
        exit 1
    fi

    # Track last synced line count
    if [ ! -f "$SYNC_FILE" ]; then
        echo "0" > "$SYNC_FILE"
    fi

    last_line=$(cat "$SYNC_FILE")
    total_lines=$(wc -l < "$REMOTE_FILE")

    if [ "$total_lines" -gt "$last_line" ]; then
        new_count=$((total_lines - last_line))
        echo "Pulling $new_count new line(s) from transcript..."
        tail -n +"$((last_line + 1))" "$REMOTE_FILE" >> "$VOICE_MD"
        echo "$total_lines" > "$SYNC_FILE"
        echo "Done — new entries added to voice.md"
    else
        echo "No new transcripts since last sync"
    fi

    rm -rf /tmp/dispatch-sync
else
    # ── Mode 2: Pull raw audio, transcribe locally ──
    echo "No transcript file on Drive — pulling audio for local transcription"

    HEAR_PATH=$(which hear 2>/dev/null || echo "$HOME/.local/bin/hear")
    if [ ! -f "$HEAR_PATH" ]; then
        echo "Error: hear not installed at $HEAR_PATH"
        echo "Run /voice-memos once in Claude Code to install it"
        exit 1
    fi

    mkdir -p "$DISPATCH_DIR"
    touch "$DOWNLOADED_FILE"
    touch "$PROCESSED_FILE"

    # Pull new recordings from Drive
    echo "Checking Google Drive for new recordings..."
    "$RCLONE_PATH" lsf "$DRIVE_FOLDER" --include "*.m4a" 2>/dev/null | while read filename; do
        if ! grep -Fxq "$filename" "$DOWNLOADED_FILE" 2>/dev/null; then
            echo "Downloading: $filename"
            "$RCLONE_PATH" copy "$DRIVE_FOLDER/$filename" "$DISPATCH_DIR/"
            echo "$filename" >> "$DOWNLOADED_FILE"
        fi
    done

    # Transcribe new files
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
fi
