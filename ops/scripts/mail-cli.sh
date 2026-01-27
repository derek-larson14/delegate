#!/bin/bash
# mail-cli.sh - Access Mac Mail via AppleScript
# Works with ANY email provider configured in Mac Mail (IMAP, POP3, Exchange, etc.)

set -e

COMMAND="${1:-help}"
shift 2>/dev/null || true

# Parse flags
ACCOUNT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--account)
            ACCOUNT="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

# Remaining args
ARGS=("$@")

# Check if Mail.app is running, start if needed
ensure_mail_running() {
    if ! pgrep -x "Mail" > /dev/null; then
        osascript -e 'tell application "Mail" to activate' 2>/dev/null
        sleep 2
    fi
}

# Sanitize string for AppleScript (escape quotes and backslashes)
sanitize() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Status check
cmd_status() {
    if ! osascript -e 'tell application "Mail" to name of inbox' &>/dev/null; then
        echo "MAIL_NOT_ACCESSIBLE"
        echo ""
        echo "Possible issues:"
        echo "1. Mail.app not configured with any accounts"
        echo "2. Automation permission not granted"
        echo ""
        echo "Fix: System Settings → Privacy & Security → Automation"
        echo "     Enable this app (Terminal/Obsidian) to control Mail"
        exit 1
    fi

    osascript -e 'tell application "Mail"
        set output to "MAIL_CONNECTED" & linefeed & "Accounts:" & linefeed
        repeat with acct in accounts
            set acctName to name of acct
            set acctEmail to email addresses of acct
            set acctEnabled to enabled of acct
            if acctEnabled then
                set statusMark to "[active] "
            else
                set statusMark to "[disabled] "
            end if
            set output to output & "  " & statusMark & acctName & ": " & acctEmail & linefeed
        end repeat
        return output
    end tell'
}

# List mailboxes/folders - fixed to show all levels
cmd_folders() {
    ensure_mail_running

    osascript -e 'tell application "Mail"
        set output to ""

        -- Show unified mailboxes
        set output to output & "=== Unified ===" & linefeed
        set output to output & "  inbox (" & (count of messages of inbox) & " messages)" & linefeed

        -- Show per-account mailboxes
        repeat with acct in accounts
            set acctName to name of acct
            set output to output & "=== " & acctName & " ===" & linefeed

            -- Get mailboxes for this account
            try
                set acctMailboxes to every mailbox of acct
                repeat with mb in acctMailboxes
                    set mbName to name of mb
                    try
                        set mbCount to count of messages of mb
                    on error
                        set mbCount to 0
                    end try
                    set output to output & "  " & mbName & " (" & mbCount & ")" & linefeed
                end repeat
            end try
        end repeat

        return output
    end tell'
}

# List recent emails with account filter support
cmd_list_pretty() {
    local COUNT="${ARGS[0]:-10}"

    ensure_mail_running

    if [ -n "$ACCOUNT" ]; then
        # List from specific account's inbox
        osascript -e "
        tell application \"Mail\"
            set output to \"\"
            set targetAcct to first account whose name is \"$ACCOUNT\"
            set targetMailbox to mailbox \"INBOX\" of targetAcct

            try
                set msgList to messages 1 thru $COUNT of targetMailbox
            on error
                set msgList to every message of targetMailbox
            end try

            repeat with m in msgList
                set msgId to id of m
                set msgFrom to sender of m
                set msgSubject to subject of m
                set msgDate to date received of m
                set readStatus to read status of m

                if readStatus then
                    set statusMark to \"  \"
                else
                    set statusMark to \"* \"
                end if

                set output to output & statusMark & msgId & \" | \" & msgFrom & \" | \" & msgSubject & \" | \" & (msgDate as string) & linefeed
            end repeat
            return output
        end tell
        "
    else
        # List from unified inbox
        osascript -e "
        tell application \"Mail\"
            set output to \"\"
            try
                set msgList to messages 1 thru $COUNT of inbox
            on error
                set msgList to messages of inbox
            end try

            repeat with m in msgList
                set msgId to id of m
                set msgFrom to sender of m
                set msgSubject to subject of m
                set msgDate to date received of m
                set readStatus to read status of m

                if readStatus then
                    set statusMark to \"  \"
                else
                    set statusMark to \"* \"
                end if

                set output to output & statusMark & msgId & \" | \" & msgFrom & \" | \" & msgSubject & \" | \" & (msgDate as string) & linefeed
            end repeat
            return output
        end tell
        "
    fi
}

# Read a specific message - searches all mailboxes
cmd_read() {
    local MSG_ID="${ARGS[0]}"

    if [ -z "$MSG_ID" ]; then
        echo "Usage: mail-cli.sh read <message_id>"
        exit 1
    fi

    ensure_mail_running

    osascript -e "
    tell application \"Mail\"
        -- Search in unified inbox first
        try
            set targetMsg to first message of inbox whose id is $MSG_ID
        on error
            -- Search all mailboxes if not found
            set targetMsg to missing value
            repeat with acct in accounts
                repeat with mb in mailboxes of acct
                    try
                        set targetMsg to first message of mb whose id is $MSG_ID
                        exit repeat
                    end try
                end repeat
                if targetMsg is not missing value then exit repeat
            end repeat
        end try

        if targetMsg is missing value then
            return \"Message not found: $MSG_ID\"
        end if

        set msgFrom to sender of targetMsg
        try
            set msgTo to (address of to recipients of targetMsg) as string
        on error
            set msgTo to \"(unknown)\"
        end try
        set msgSubject to subject of targetMsg
        set msgDate to date received of targetMsg
        set msgContent to content of targetMsg

        return \"From: \" & msgFrom & linefeed & \"To: \" & msgTo & linefeed & \"Subject: \" & msgSubject & linefeed & \"Date: \" & (msgDate as string) & linefeed & linefeed & msgContent
    end tell
    " 2>/dev/null
}

# Search messages - improved with case-insensitive matching
cmd_search() {
    local QUERY="${ARGS[0]}"
    local COUNT="${ARGS[1]:-20}"

    if [ -z "$QUERY" ]; then
        echo "Usage: mail-cli.sh search <query> [count]"
        exit 1
    fi

    ensure_mail_running

    # Escape the query for AppleScript
    local SAFE_QUERY
    SAFE_QUERY=$(sanitize "$QUERY")

    osascript -e "
    tell application \"Mail\"
        set output to \"\"
        set resultCount to 0
        set searchTerm to \"$SAFE_QUERY\"

        -- Search unified inbox
        set allMsgs to messages of inbox

        repeat with m in allMsgs
            if resultCount < $COUNT then
                set msgSubject to subject of m
                set msgFrom to sender of m

                -- Case-insensitive search
                ignoring case
                    if msgSubject contains searchTerm or msgFrom contains searchTerm then
                        set msgId to id of m
                        set msgDate to date received of m
                        set readStatus to read status of m
                        if readStatus then
                            set statusMark to \"  \"
                        else
                            set statusMark to \"* \"
                        end if
                        set output to output & statusMark & msgId & \" | \" & msgFrom & \" | \" & msgSubject & \" | \" & (msgDate as string) & linefeed
                        set resultCount to resultCount + 1
                    end if
                end ignoring
            end if
        end repeat

        if resultCount is 0 then
            return \"No messages found matching: $SAFE_QUERY\"
        end if

        return output
    end tell
    " 2>/dev/null
}

# Search by from address
cmd_search_from() {
    local FROM="${ARGS[0]}"
    local COUNT="${ARGS[1]:-20}"

    if [ -z "$FROM" ]; then
        echo "Usage: mail-cli.sh from <sender> [count]"
        exit 1
    fi

    ensure_mail_running

    local SAFE_FROM
    SAFE_FROM=$(sanitize "$FROM")

    osascript -e "
    tell application \"Mail\"
        set output to \"\"
        set resultCount to 0

        ignoring case
            set matchingMsgs to (messages of inbox whose sender contains \"$SAFE_FROM\")
        end ignoring

        repeat with m in matchingMsgs
            if resultCount < $COUNT then
                set msgId to id of m
                set msgFrom to sender of m
                set msgSubject to subject of m
                set msgDate to date received of m
                set readStatus to read status of m
                if readStatus then
                    set statusMark to \"  \"
                else
                    set statusMark to \"* \"
                end if
                set output to output & statusMark & msgId & \" | \" & msgFrom & \" | \" & msgSubject & \" | \" & (msgDate as string) & linefeed
                set resultCount to resultCount + 1
            end if
        end repeat

        if output is \"\" then
            return \"No messages found from: $SAFE_FROM\"
        end if

        return output
    end tell
    "
}

# Get unread messages
cmd_unread() {
    local COUNT="${ARGS[0]:-20}"

    ensure_mail_running

    osascript -e "
    tell application \"Mail\"
        set output to \"\"
        set resultCount to 0

        set unreadMsgs to (messages of inbox whose read status is false)

        repeat with m in unreadMsgs
            if resultCount < $COUNT then
                set msgId to id of m
                set msgFrom to sender of m
                set msgSubject to subject of m
                set msgDate to date received of m
                set output to output & \"* \" & msgId & \" | \" & msgFrom & \" | \" & msgSubject & \" | \" & (msgDate as string) & linefeed
                set resultCount to resultCount + 1
            end if
        end repeat

        if output is \"\" then
            return \"No unread messages\"
        end if

        return output
    end tell
    "
}

# Full-text search (searches body too - slower)
cmd_search_full() {
    local QUERY="${ARGS[0]}"
    local COUNT="${ARGS[1]:-10}"

    if [ -z "$QUERY" ]; then
        echo "Usage: mail-cli.sh search-body <query> [count]"
        echo "Note: Searches message body - slower than regular search"
        exit 1
    fi

    ensure_mail_running

    local SAFE_QUERY
    SAFE_QUERY=$(sanitize "$QUERY")

    osascript -e "
    tell application \"Mail\"
        set output to \"\"
        set resultCount to 0
        set searchTerm to \"$SAFE_QUERY\"

        set allMsgs to messages of inbox

        repeat with m in allMsgs
            if resultCount < $COUNT then
                set msgSubject to subject of m
                set msgFrom to sender of m
                set msgBody to content of m

                ignoring case
                    if msgSubject contains searchTerm or msgFrom contains searchTerm or msgBody contains searchTerm then
                        set msgId to id of m
                        set msgDate to date received of m
                        set readStatus to read status of m
                        if readStatus then
                            set statusMark to \"  \"
                        else
                            set statusMark to \"* \"
                        end if
                        set output to output & statusMark & msgId & \" | \" & msgFrom & \" | \" & msgSubject & \" | \" & (msgDate as string) & linefeed
                        set resultCount to resultCount + 1
                    end if
                end ignoring
            end if
        end repeat

        if resultCount is 0 then
            return \"No messages found containing: $SAFE_QUERY\"
        end if

        return output
    end tell
    " 2>/dev/null
}

# Get today's messages
cmd_today() {
    local COUNT="${ARGS[0]:-50}"

    ensure_mail_running

    osascript -e "
    tell application \"Mail\"
        set output to \"\"
        set resultCount to 0
        set todayStart to current date
        set time of todayStart to 0

        set allMsgs to messages of inbox

        repeat with m in allMsgs
            if resultCount < $COUNT then
                set msgDate to date received of m
                if msgDate > todayStart then
                    set msgId to id of m
                    set msgFrom to sender of m
                    set msgSubject to subject of m
                    set readStatus to read status of m
                    if readStatus then
                        set statusMark to \"  \"
                    else
                        set statusMark to \"* \"
                    end if
                    set output to output & statusMark & msgId & \" | \" & msgFrom & \" | \" & msgSubject & \" | \" & (msgDate as string) & linefeed
                    set resultCount to resultCount + 1
                end if
            end if
        end repeat

        if output is \"\" then
            return \"No messages received today\"
        end if

        return output
    end tell
    "
}

# Compose email (opens in Mail.app for user to review/send)
cmd_compose() {
    local TO="${ARGS[0]}"
    local SUBJECT="${ARGS[1]}"
    local BODY="${ARGS[2]:-}"

    if [ ! -f "$HOME/.config/mail-cli/full-access" ]; then
        echo "Compose is disabled (read-only mode)."
        echo ""
        echo "To enable, run: mail-cli.sh enable-compose"
        exit 1
    fi

    if [ -z "$TO" ] || [ -z "$SUBJECT" ]; then
        echo "Usage: mail-cli.sh compose <to> <subject> [body]"
        exit 1
    fi

    ensure_mail_running

    local SAFE_SUBJECT SAFE_BODY
    SAFE_SUBJECT=$(sanitize "$SUBJECT")
    SAFE_BODY=$(sanitize "$BODY")

    osascript -e "
    tell application \"Mail\"
        set newMessage to make new outgoing message with properties {subject:\"$SAFE_SUBJECT\", content:\"$SAFE_BODY\", visible:true}
        tell newMessage
            make new to recipient at end of to recipients with properties {address:\"$TO\"}
        end tell
        activate
    end tell
    return \"Compose window opened - review and click Send in Mail.app\"
    "
}

cmd_enable_compose() {
    mkdir -p "$HOME/.config/mail-cli"
    touch "$HOME/.config/mail-cli/full-access"
    echo "Compose enabled. You can now use: mail-cli.sh compose <to> <subject> [body]"
    echo "Note: This opens a compose window - you still click Send manually."
}

cmd_disable_compose() {
    rm -f "$HOME/.config/mail-cli/full-access"
    echo "Compose disabled. Back to read-only mode."
}

# Help
cmd_help() {
    cat << 'EOF'
mail-cli.sh - Access Mac Mail via AppleScript

Works with ANY email provider configured in Mac Mail.

COMMANDS:
  status              Check connection and list accounts
  folders             List all mailboxes/folders with counts
  list [count]        List recent emails (default: 10)
  read <id>           Read a specific message by ID
  search <query>      Search subject and sender (fast)
  search-body <query> Search subject, sender, AND body (slow)
  from <sender>       Search by sender
  unread [count]      List unread messages
  today [count]       List today's messages
  compose <to> <subj> [body]  Open compose window (requires enable-compose)
  enable-compose      Enable compose mode
  disable-compose     Return to read-only

OPTIONS:
  -a, --account <name>   Filter by account name (use with list, search, etc.)

SETUP:
  1. Configure your email account in Mac Mail app
  2. Grant automation permission when prompted
     (System Settings → Privacy & Security → Automation)

EXAMPLES:
  ./mail-cli.sh status
  ./mail-cli.sh list 20
  ./mail-cli.sh list 10 -a iCloud
  ./mail-cli.sh read 12345
  ./mail-cli.sh search "meeting"
  ./mail-cli.sh from "john@example.com"
  ./mail-cli.sh unread
  ./mail-cli.sh today
EOF
}

# Route commands
case "$COMMAND" in
    status)
        cmd_status
        ;;
    folders|mailboxes)
        cmd_folders
        ;;
    list)
        cmd_list_pretty
        ;;
    read)
        cmd_read
        ;;
    search)
        cmd_search
        ;;
    search-body|searchbody|fullsearch)
        cmd_search_full
        ;;
    from)
        cmd_search_from
        ;;
    unread)
        cmd_unread
        ;;
    today)
        cmd_today
        ;;
    compose)
        cmd_compose
        ;;
    enable-compose)
        cmd_enable_compose
        ;;
    disable-compose)
        cmd_disable_compose
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        echo "Unknown command: $COMMAND"
        cmd_help
        exit 1
        ;;
esac
