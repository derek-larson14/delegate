#!/bin/bash
# Check for updates from feed-the-beast repo
# Outputs: CHANGED, NEW, or LOCAL ONLY for each file

set -e

REPO_URL="https://github.com/derek-larson14/feed-the-beast/archive/main.zip"
TMP_ZIP="/tmp/ftb-update.zip"
TMP_DIR="/tmp/ftb-update"
EXTRACTED="$TMP_DIR/feed-the-beast-main"

# Clean up any previous run
rm -rf "$TMP_ZIP" "$TMP_DIR"

# Download and extract
echo "Downloading from feed-the-beast..."
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
        [[ "$name" == "ftb-check-updates.sh" ]] && continue

        if [[ ! -f "$EXTRACTED/ops/scripts/$name" ]]; then
            echo "LOCAL ONLY: $name"
        fi
    done
fi

echo ""
echo "Source files extracted to: $EXTRACTED"
echo "Run cleanup when done: rm -rf $TMP_DIR $TMP_ZIP"
