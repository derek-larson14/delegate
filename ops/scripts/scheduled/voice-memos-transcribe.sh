#!/bin/bash
# Voice Memos Transcription (no Claude required)
# Transcribes new iPhone voice memos to voice.md
# Runs automatically via launchd - see /setup-transcription for setup

set -e

# Get the directory where this script lives, then find vault root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

VOICE_MEMOS_DIR="$HOME/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings"
VOICE_DIR="$VAULT_ROOT/.voice"
PROCESSED_FILE="$VOICE_DIR/memos-processed"
VOICE_MD="$VAULT_ROOT/voice.md"

mkdir -p "$VOICE_DIR"
HEAR_PATH="$HOME/.local/bin/hear"

# Check if hear is installed
if [ ! -f "$HEAR_PATH" ]; then
    echo "Error: hear not installed at $HEAR_PATH"
    echo "Run /setup-transcription once manually to install it"
    exit 1
fi

# Check if voice memos directory exists
if [ ! -d "$VOICE_MEMOS_DIR" ]; then
    echo "Error: Voice Memos directory not found"
    echo "Make sure Voice Memos are synced via iCloud"
    exit 1
fi

# Check if we can actually read the directory (TCC / Full Disk Access)
# macOS silently returns empty results when /bin/bash lacks FDA
file_count=$(ls -1 "$VOICE_MEMOS_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [ "$file_count" = "0" ]; then
    echo "ERROR: Voice Memos directory exists but is unreadable (TCC blocked)."
    echo "/bin/bash needs Full Disk Access to read Voice Memos from a scheduled job."
    echo ""
    echo "Fix: System Settings → Privacy & Security → Full Disk Access"
    echo "  Click +, press Cmd+Shift+G, type /bin/bash, add it."
    echo "  Then reload: launchctl unload ~/Library/LaunchAgents/com.voicememos.transcribe.plist"
    echo "  Then:        launchctl load ~/Library/LaunchAgents/com.voicememos.transcribe.plist"
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
        echo "## Memo - $created"
        echo ""
        echo "$transcript"
        echo ""
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
