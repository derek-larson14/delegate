#!/bin/bash
# Automated voice note processing
# Routes transcribed voice notes to the right places in the workspace
# Runs on schedule via launchd — no human input required

# Find workspace root (parent of ops/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$WORKSPACE"

LAST_RUN=".voice/last-auto-run"

# Check if voice.md has any content at all
if [ ! -s voice.md ]; then
    echo "No voice entries to process"
    exit 0
fi

# Skip if voice.md hasn't been modified since last successful run
# This is format-agnostic — works with any entry style (headers, dates, plain text)
if [ -f "$LAST_RUN" ] && [ ! voice.md -nt "$LAST_RUN" ]; then
    echo "voice.md unchanged since last run"
    exit 0
fi

# Find claude binary
CLAUDE=$(which claude 2>/dev/null || echo "$HOME/.local/bin/claude")
if [ ! -f "$CLAUDE" ]; then
    echo "Claude CLI not found"
    exit 1
fi

OUTPUT=$($CLAUDE -p "/voice" --dangerously-skip-permissions 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "Voice processing failed (exit code $EXIT_CODE)"
    exit 1
fi

# Mark successful run — next time we'll skip unless voice.md is modified again
mkdir -p .voice
touch "$LAST_RUN"

echo "Voice routing complete"
