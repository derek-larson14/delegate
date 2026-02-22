#!/bin/bash
# Check for updates from delegate repo
# Compares local manifest.json against remote, then shows what changed

set -e

REPO_URL="https://github.com/derek-larson14/delegate/archive/main.zip"
MANIFEST_URL="https://raw.githubusercontent.com/derek-larson14/delegate/main/manifest.json"
TMP_ZIP="/tmp/delegate-update.zip"
TMP_DIR="/tmp/delegate-update"
EXTRACTED="$TMP_DIR/delegate-main"

# Clean up any previous run
rm -rf "$TMP_ZIP" "$TMP_DIR"

# Check local manifest
LOCAL_MANIFEST="manifest.json"
if [[ -f "$LOCAL_MANIFEST" ]]; then
    LOCAL_VERSION=$(grep '"version"' "$LOCAL_MANIFEST" | head -1 | sed 's/.*: *"\(.*\)".*/\1/')
    LOCAL_CMD_VER=$(grep '"commands_version"' "$LOCAL_MANIFEST" | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    LOCAL_SCRIPT_VER=$(grep '"scripts_version"' "$LOCAL_MANIFEST" | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    echo "Local version: $LOCAL_VERSION (commands: $LOCAL_CMD_VER, scripts: $LOCAL_SCRIPT_VER)"
else
    echo "No local manifest.json found — first update will create one."
    LOCAL_VERSION="none"
    LOCAL_CMD_VER=0
    LOCAL_SCRIPT_VER=0
fi

# Fetch remote manifest first (quick check)
echo ""
echo "Checking latest version..."
REMOTE_MANIFEST=$(curl -sL "$MANIFEST_URL" 2>/dev/null || echo "")
if [[ -z "$REMOTE_MANIFEST" ]]; then
    echo "Could not fetch remote manifest. Falling back to full check."
else
    REMOTE_VERSION=$(echo "$REMOTE_MANIFEST" | grep '"version"' | head -1 | sed 's/.*: *"\(.*\)".*/\1/')
    REMOTE_CMD_VER=$(echo "$REMOTE_MANIFEST" | grep '"commands_version"' | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    REMOTE_SCRIPT_VER=$(echo "$REMOTE_MANIFEST" | grep '"scripts_version"' | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    echo "Latest version: $REMOTE_VERSION (commands: $REMOTE_CMD_VER, scripts: $REMOTE_SCRIPT_VER)"

    if [[ "$LOCAL_CMD_VER" == "$REMOTE_CMD_VER" && "$LOCAL_SCRIPT_VER" == "$REMOTE_SCRIPT_VER" ]]; then
        echo ""
        echo "Everything is up to date."
        exit 0
    fi
    echo ""
    echo "Updates available. Downloading..."
fi

# Download and extract
if ! curl -sL "$REPO_URL" -o "$TMP_ZIP"; then
    echo "ERROR: Failed to download. Check your connection."
    exit 1
fi

if ! unzip -oq "$TMP_ZIP" -d "$TMP_DIR"; then
    echo "ERROR: Failed to extract zip."
    exit 1
fi

if [[ ! -d "$EXTRACTED" ]]; then
    echo "ERROR: Expected directory not found after extraction."
    exit 1
fi

echo ""
echo "=== COMMANDS ==="

# Check upstream commands
for f in "$EXTRACTED/.claude/commands"/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    [[ "$name" == "update.md" ]] && continue

    existing=".claude/commands/$name"
    if [[ -f "$existing" ]]; then
        if ! diff -q "$f" "$existing" >/dev/null 2>&1; then
            echo "CHANGED: $name"
        fi
    else
        echo "NEW: $name"
    fi
done

# Check for local-only commands
for f in .claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")
    [[ "$name" == "update.md" ]] && continue

    if [[ ! -f "$EXTRACTED/.claude/commands/$name" ]]; then
        echo "LOCAL ONLY: $name"
    fi
done

echo ""
echo "=== SETUP FILES ==="

# Check for SETUP.command
if [[ -f "$EXTRACTED/SETUP.command" ]]; then
    if [[ -f "SETUP.command" ]]; then
        if ! diff -q "$EXTRACTED/SETUP.command" "SETUP.command" >/dev/null 2>&1; then
            echo "CHANGED: SETUP.command"
        fi
    else
        echo "NEW: SETUP.command"
    fi
fi

echo ""
echo "=== SCRIPTS ==="

# Check upstream scripts
if [[ -d "$EXTRACTED/ops/scripts" ]]; then
    for f in "$EXTRACTED/ops/scripts"/*.sh; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")

        existing="ops/scripts/$name"
        if [[ -f "$existing" ]]; then
            if ! diff -q "$f" "$existing" >/dev/null 2>&1; then
                echo "CHANGED: $name"
            fi
        else
            echo "NEW: $name"
        fi
    done
else
    echo "(no scripts in repo)"
fi

# Check for local-only scripts
if [[ -d "ops/scripts" ]]; then
    for f in ops/scripts/*.sh; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")

        # Skip self
        [[ "$name" == "check-updates.sh" ]] && continue

        if [[ ! -f "$EXTRACTED/ops/scripts/$name" ]]; then
            echo "LOCAL ONLY: $name"
        fi
    done
fi

echo ""
echo "Source files extracted to: $EXTRACTED"
echo "Run cleanup when done: rm -rf $TMP_DIR $TMP_ZIP"
