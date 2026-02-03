#!/bin/bash
# =============================================================================
# Claude Workspace Setup
# =============================================================================
# Run this once after downloading the workspace.
# Double-click this file, or run: ./SETUP.command
#
# This installs CLI tools needed by slash commands:
#   - Homebrew (package manager)
#   - icalBuddy (for /calendar)
#   - rclone (for /drive)
#   - jq (for /messages)
#
# You'll be asked for your Mac password once (for Homebrew).
# Non-admin users: If another account already installed these tools, this
# script will just set up your PATH (no password needed).
# =============================================================================

set -e

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Workspace Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# -----------------------------------------------------------------------------
# OS Detection
# -----------------------------------------------------------------------------
OS="$(uname -s)"

if [[ "$OS" == "Linux" ]]; then
    echo "Detected: Linux"
    echo ""

    # Track what we install
    INSTALLED=()
    SKIPPED=()

    # Install rclone
    echo "[1/2] Checking rclone (for /drive)..."
    if command -v rclone &> /dev/null; then
        SKIPPED+=("rclone")
        echo "      ✓ Already installed"
    else
        echo "      Installing rclone..."
        if curl -s https://rclone.org/install.sh | sudo bash 2>/dev/null; then
            INSTALLED+=("rclone")
            echo "      ✓ rclone installed"
        else
            echo "      ✗ Failed. Install manually: https://rclone.org/install/"
        fi
    fi

    # Install jq
    echo ""
    echo "[2/2] Checking jq (for /messages)..."
    if command -v jq &> /dev/null; then
        SKIPPED+=("jq")
        echo "      ✓ Already installed"
    else
        echo "      Installing jq..."
        if command -v apt &> /dev/null; then
            sudo apt install -y jq 2>/dev/null && INSTALLED+=("jq") && echo "      ✓ jq installed"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y jq 2>/dev/null && INSTALLED+=("jq") && echo "      ✓ jq installed"
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm jq 2>/dev/null && INSTALLED+=("jq") && echo "      ✓ jq installed"
        else
            echo "      ✗ Failed. Install manually: apt/dnf/pacman install jq"
        fi
    fi

    echo ""
    echo "✓ Ready! Run 'claude' to start."
    echo ""
    echo "/messages needs Beeper Desktop: beeper.com/download/linux"
    echo "/calendar, /mail are Mac-only → try rube.app for calendar/email"
    echo ""
    exit 0
fi

if [[ "$OS" == "MINGW"* ]] || [[ "$OS" == "CYGWIN"* ]] || [[ "$OS" == "MSYS"* ]]; then
    echo "Detected: Windows"
    echo "Use SETUP.ps1 instead (right-click → Run with PowerShell)"
    echo ""
    exit 0
fi

# Track what we install
INSTALLED=()
SKIPPED=()
FAILED=()
PATH_FIXED=false

# -----------------------------------------------------------------------------
# Homebrew
# -----------------------------------------------------------------------------
echo "[1/4] Checking Homebrew..."

if command -v brew &> /dev/null; then
    SKIPPED+=("Homebrew (already installed)")
    echo "      ✓ Already installed"
elif [[ -f /opt/homebrew/bin/brew ]]; then
    # Homebrew exists but not in PATH (e.g., non-admin user on shared Mac)
    echo "      Found Homebrew at /opt/homebrew, adding to PATH..."
    eval "$(/opt/homebrew/bin/brew shellenv)"

    # Make it permanent for this user
    if ! grep -q '/opt/homebrew/bin/brew shellenv' ~/.zprofile 2>/dev/null; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        PATH_FIXED=true
    fi

    SKIPPED+=("Homebrew (added to PATH)")
    echo "      ✓ Added to PATH"
elif [[ -f /usr/local/bin/brew ]]; then
    # Intel Mac - Homebrew exists but not in PATH
    echo "      Found Homebrew at /usr/local, adding to PATH..."
    eval "$(/usr/local/bin/brew shellenv)"

    if ! grep -q '/usr/local/bin/brew shellenv' ~/.zprofile 2>/dev/null; then
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        PATH_FIXED=true
    fi

    SKIPPED+=("Homebrew (added to PATH)")
    echo "      ✓ Added to PATH"
else
    echo "      Installing Homebrew (you'll be asked for your password)..."
    echo ""
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to PATH for this session
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
    fi

    if command -v brew &> /dev/null; then
        INSTALLED+=("Homebrew")
        echo "      ✓ Homebrew installed"
    else
        FAILED+=("Homebrew")
        echo "      ✗ Homebrew installation failed"
        echo ""
        echo "Try installing manually: https://brew.sh"
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# icalBuddy (for /calendar)
# -----------------------------------------------------------------------------
echo ""
echo "[2/4] Checking icalBuddy (for /calendar)..."

if command -v icalBuddy &> /dev/null; then
    SKIPPED+=("icalBuddy (already installed)")
    echo "      ✓ Already installed"
else
    echo "      Installing..."
    if brew install ical-buddy 2>/dev/null; then
        INSTALLED+=("icalBuddy")
        echo "      ✓ icalBuddy installed"
    else
        FAILED+=("icalBuddy")
        echo "      ✗ Failed to install icalBuddy"
    fi
fi

# -----------------------------------------------------------------------------
# rclone (for /drive)
# -----------------------------------------------------------------------------
echo ""
echo "[3/4] Checking rclone (for /drive)..."

if command -v rclone &> /dev/null; then
    SKIPPED+=("rclone (already installed)")
    echo "      ✓ Already installed"
else
    echo "      Installing..."
    if brew install rclone 2>/dev/null; then
        INSTALLED+=("rclone")
        echo "      ✓ rclone installed"
    else
        FAILED+=("rclone")
        echo "      ✗ Failed to install rclone"
    fi
fi

# -----------------------------------------------------------------------------
# jq (for /messages)
# -----------------------------------------------------------------------------
echo ""
echo "[4/4] Checking jq (for /messages)..."

if command -v jq &> /dev/null; then
    SKIPPED+=("jq (already installed)")
    echo "      ✓ Already installed"
else
    echo "      Installing..."
    if brew install jq 2>/dev/null; then
        INSTALLED+=("jq")
        echo "      ✓ jq installed"
    else
        FAILED+=("jq")
        echo "      ✗ Failed to install jq"
    fi
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""

if [ ${#INSTALLED[@]} -gt 0 ]; then
    echo "Installed: ${INSTALLED[*]}"
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "Failed: ${FAILED[*]}"
fi

echo ""
echo "✓ Ready! Run 'claude' to start."
echo ""
echo "First use: /calendar, /drive, /mail will prompt for permissions."
echo "/messages needs Beeper Desktop (beeper.com)"
echo ""
