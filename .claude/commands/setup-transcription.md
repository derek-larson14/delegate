---
description: Set up automatic transcription — iPhone Voice Memos or Google Drive (Dispatch)
model: sonnet
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Voice Transcription

Transcribe voice recordings and add them to voice.md. Supports two sources: iPhone Voice Memos (via iCloud) and Google Drive (via Dispatch app).

## Step 1: Determine source

Check if source is already configured:
```bash
mkdir -p .voice && ([ -f .voice/source ] && cat .voice/source || echo "NOT_SET")
```

**If "NOT_SET"**, use AskUserQuestion:

"Where are your voice recordings?"

Options:
- "Voice Memos (iPhone → iCloud → Mac)"
- "Google Drive (Dispatch app)"

Save their choice:
```bash
echo "voicememos" > .voice/source   # or "drive"
```

---

## Source: Voice Memos (iCloud)

### Setup Checks (run silently, only message user if action needed)

#### 1. Check `hear` tool

```bash
which hear &>/dev/null && echo "READY"
```

**If not ready**, install it:
```bash
curl -sL https://sveinbjorn.org/files/software/hear.zip -o /tmp/hear.zip && \
unzip -o /tmp/hear.zip -d /tmp/hear && \
mkdir -p ~/.local/bin && \
cp /tmp/hear/hear-*/hear ~/.local/bin/ && \
chmod +x ~/.local/bin/hear && \
rm -rf /tmp/hear /tmp/hear.zip
```

Verify: `~/.local/bin/hear --version`

If `which hear` still fails after install, tell user: "Restart your terminal or add ~/.local/bin to your PATH."

#### 2. Check Full Disk Access

Voice Memos are stored in a protected location. Check access:

```bash
ls "$HOME/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings" &>/dev/null && echo "ACCESS OK" || echo "NO ACCESS"
```

**If "NO ACCESS"**, tell user:

"Obsidian (or Terminal) needs Full Disk Access to read Voice Memos. Quick fix:

1. Open System Settings → Privacy & Security → Full Disk Access
2. Click the + button, find Obsidian (or Terminal) in Applications, add it
3. Restart Obsidian (or Terminal)
4. Run /voice-memos again"

Then stop - don't proceed until they fix this.

#### 3. Check Speech Recognition permission

```bash
osascript -l JavaScript -e '
ObjC.import("Speech");
var status = $.SFSpeechRecognizer.authorizationStatus;
status;
'
```

- Status `0` = Not determined (need to request)
- Status `1` = Denied
- Status `2` = Restricted
- Status `3` = Authorized

**If status is 0 (not determined)**, trigger the permission prompt:
```bash
osascript -l JavaScript -e '
ObjC.import("Speech");
$.SFSpeechRecognizer.requestAuthorization(function(s) {});
'
```

Tell user: "A permission dialog should appear - please approve Speech Recognition access."

Wait a few seconds, then re-check the status. If now `3`, proceed.

**If status is 1 (denied)**, tell user:

"Speech Recognition permission was denied. To fix:
1. Open System Settings → Privacy & Security → Speech Recognition
2. Find Obsidian and toggle it ON (or click + to add it)
3. Run /voice-memos again"

Then stop.

#### 4. Trigger iCloud download

iCloud "optimizes" storage - voice memos exist in the cloud but aren't downloaded until the app requests them. Open Voice Memos for 10 seconds to trigger download:

```bash
open -g "/System/Applications/VoiceMemos.app"
sleep 10
osascript -e 'tell application "VoiceMemos" to quit' 2>/dev/null || true
```

#### 5. Check iCloud sync

If folder exists but is empty after triggering download, tell user:

"No Voice Memos found. iCloud sync must be enabled for Voice Memos to appear on your Mac. To set this up:

**On iPhone:**
1. Open Settings → [Your Name] → iCloud → Apps Using iCloud → Show All
2. Find Voice Memos and toggle it ON

**On Mac:**
1. Open System Settings → [Your Name] → iCloud → iCloud Drive → Options (or Apps Syncing to iCloud Drive)
2. Make sure Voice Memos is checked

After enabling, record a test memo on your iPhone, wait a minute, then run /voice-memos again."

#### 6. Check scheduled transcription script

Check if the launchd job is set up or previously declined:

```bash
if launchctl list 2>/dev/null | grep -q "com.voicememos.transcribe"; then
    echo "SCHEDULED"
elif [ -f .voice/no-schedule ]; then
    echo "DECLINED"
else
    echo "NOT_SCHEDULED"
fi
```

**If "SCHEDULED" or "DECLINED"**, skip to Processing Flow.

**If "NOT_SCHEDULED"**, offer to set it up:

Ask the user: "Want to set up automatic transcription? It will run every hour (8am–midnight) while your Mac is awake, transcribing new voice memos to voice.md automatically."

Options: "Yes, set it up" / "No, I'll run manually"

**If they say yes**, install the scheduled job:

First, get the vault path:
```bash
pwd
```

Then create the launchd plist:
```bash
VAULT_PATH="$(pwd)"
cat > ~/Library/LaunchAgents/com.voicememos.transcribe.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.voicememos.transcribe</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${VAULT_PATH}/ops/scripts/voice-memos-transcribe.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Hour</key><integer>8</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>13</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>15</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>17</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>19</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>22</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>23</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>0</integer><key>Minute</key><integer>0</integer></dict>
    </array>
    <key>StandardOutPath</key>
    <string>/tmp/voicememos-transcribe.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/voicememos-transcribe.err</string>
</dict>
</plist>
EOF
```

Make the script executable and load the job:
```bash
chmod +x "$VAULT_PATH/ops/scripts/voice-memos-transcribe.sh"
launchctl load ~/Library/LaunchAgents/com.voicememos.transcribe.plist
```

Tell user: "Automatic transcription is now set up. It runs on login and every hour (8am–midnight)."

**If they say no**, create a marker so we don't ask again:
```bash
touch .voice/no-schedule
```

### Processing Flow (Voice Memos)

Once setup checks pass:

#### 1. Detect first run vs. ongoing

Check if `.voice/memos-processed` exists and has content:
```bash
if [ -s .voice/memos-processed ]; then echo "ONGOING"; else echo "FIRST_RUN"; fi
```

#### 2. First Run Flow

If first run, show the user what exists and let them choose scope.

**Get memo count and date range:**
```bash
find "$HOME/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings" -maxdepth 1 -name "*.m4a" -type f | wc -l
```

**Use AskUserQuestion** to present options:

"Found [N] voice memos. How far back do you want to transcribe?"

Options:
- "Last 5 memos"
- "Last week"
- "Last month"
- "All of them"

Based on their choice, determine which memos to process.

**Important**: After processing their chosen scope, mark ALL older memos as processed too (so they don't get asked again).

#### 3. Ongoing Run Flow (not first run)

Find memos not yet processed. For each file, check:
```bash
grep -qxF "filename.m4a" .voice/memos-processed || echo "needs processing"
```

If no new memos, tell user "No new voice memos to process." and stop.

#### 4. Transcribe memos

For each memo to process:
```bash
~/.local/bin/hear -d -i "$filepath"
```

The `-d` flag forces on-device recognition (avoids network hangs).

#### 5. Append to voice.md

Extract timestamp from filename (format: `YYYYMMDD HHMMSS*.m4a`) to get human-readable date.

Format:
```markdown
Jan 15 at 9:42 AM
[transcription text]

---
```

Append to `voice.md`.

#### 6. Mark as processed

```bash
echo "$filename" >> .voice/memos-processed
```

#### 7. Summary

Tell user:
- How many memos transcribed
- Remind them: "Run /voice to route these notes to the right places."

---

## Source: Google Drive (Dispatch)

Run the pull-dispatch script:

```bash
chmod +x ops/scripts/pull-dispatch.sh
./ops/scripts/pull-dispatch.sh
```

This script handles two scenarios automatically:
1. **Gemini transcript exists on Drive** (`dispatch-transcripts.md`): pulls new entries into `voice.md`
2. **Raw audio only on Drive**: downloads `.m4a` files and transcribes locally with `hear`

If it reports errors about rclone not being configured, help the user set it up:
```bash
# Install rclone if needed
curl -sL https://raw.githubusercontent.com/derek-larson14/feed-the-beast/main/ops/scripts/setup-dispatch.sh | bash
```

Or just connect Drive manually:
```bash
rclone config create gdrive drive
```

After the script runs, tell user how many new entries were added and remind them: "Run /voice to route these notes to the right places."

---

## Managing Scheduled Jobs

To check status:
```bash
launchctl list | grep voicememos
```

To view logs:
```bash
cat /tmp/voicememos-transcribe.out
```

To disable:
```bash
launchctl unload ~/Library/LaunchAgents/com.voicememos.transcribe.plist
```

To re-enable:
```bash
launchctl load ~/Library/LaunchAgents/com.voicememos.transcribe.plist
```

## Edge Cases

- **Transcription fails on a file**: Note which file, continue with others, report at end
- **Empty transcription**: Some memos may be too short or unclear - note this, still mark as processed

## Reset

To re-process all voice memos:
```bash
rm .voice/memos-processed
```

To re-process all dispatch recordings:
```bash
rm .voice/dispatch-processed .voice/dispatch-downloaded .voice/dispatch-sync
```

To change source:
```bash
rm .voice/source
```
