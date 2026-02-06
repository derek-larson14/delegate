#!/bin/bash
# Voice Memos Transcription (no Claude required)
# Transcribes new iPhone voice memos to voice.md
# Runs automatically via launchd - see /voice-memos for setup

set -e

# Get the directory where this script lives, then find vault root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VOICE_MEMOS_DIR="$HOME/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings"
PROCESSED_FILE="$VAULT_ROOT/.voice-memos-processed"
VOICE_MD="$VAULT_ROOT/voice.md"
HEAR_PATH="$HOME/.local/bin/hear"

# Check if hear is installed
if [ ! -f "$HEAR_PATH" ]; then
    echo "Error: hear not installed at $HEAR_PATH"
    echo "Run /voice-memos once manually to install it"
    exit 1
fi

# Check if voice memos directory exists
if [ ! -d "$VOICE_MEMOS_DIR" ]; then
    echo "Error: Voice Memos directory not found"
    echo "Make sure Voice Memos are synced via iCloud"
    exit 1
fi

# Trigger iCloud sync by opening Voice Memos app in background
# iCloud "optimizes" storage and won't download files until the app requests them
echo "Triggering iCloud sync..."
open -g "/System/Applications/VoiceMemos.app"
sleep 10

# Close Voice Memos quietly
osascript -e 'tell application "VoiceMemos" to quit' 2>/dev/null || true

# Create processed file if it doesn't exist
touch "$PROCESSED_FILE"

# Find new memos (not in processed list)
new_count=0
while IFS= read -r -d '' memo; do
    filename=$(basename "$memo")

    # Skip if already processed
    if grep -Fxq "$filename" "$PROCESSED_FILE"; then
        continue
    fi

    echo "Transcribing: $filename"

    # Get creation date from filename (format: YYYYMMDD HHMMSS-*.m4a)
    # Extract and format as "Jan 15 at 9:42 AM"
    date_part=$(echo "$filename" | grep -oE '^[0-9]{8} [0-9]{6}' || echo "")
    if [ -n "$date_part" ]; then
        year="${date_part:0:4}"
        month="${date_part:4:2}"
        day="${date_part:6:2}"
        hour="${date_part:9:2}"
        minute="${date_part:11:2}"
        created=$(date -j -f "%Y%m%d%H%M" "${year}${month}${day}${hour}${minute}" "+%b %d at %-I:%M %p" 2>/dev/null || echo "$date_part")
    else
        created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$memo")
    fi

    # Transcribe using on-device recognition (-d) to avoid network hangs
    transcript=$("$HEAR_PATH" -d -i "$memo" 2>/dev/null || echo "[transcription failed]")

    # Append to voice.md
    {
        echo ""
        echo "$created"
        echo "$transcript"
        echo ""
        echo "---"
    } >> "$VOICE_MD"

    # Mark as processed
    echo "$filename" >> "$PROCESSED_FILE"

    ((new_count++))
done < <(find "$VOICE_MEMOS_DIR" -name "*.m4a" -print0 2>/dev/null)

if [ $new_count -gt 0 ]; then
    echo "Transcribed $new_count new memo(s)"
else
    echo "No new memos to transcribe"
fi
