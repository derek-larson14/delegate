#!/bin/bash
# beeper-cli.sh - Access Beeper Desktop API
# Works with all platforms in Beeper (WhatsApp, Telegram, Signal, LinkedIn, etc.)
# Requires: curl, jq

set -e

# Check for jq
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed."
    echo ""
    if command -v brew &>/dev/null; then
        echo "Install with: brew install jq"
    else
        echo "Install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "Then: brew install jq"
    fi
    exit 1
fi

COMMAND="${1:-help}"
shift 2>/dev/null || true

BEEPER_API="http://localhost:23373"
TOKEN_FILE="$HOME/.config/beeper-cli/token"

get_token() {
    if [ -f "$TOKEN_FILE" ]; then
        cat "$TOKEN_FILE"
    else
        echo ""
    fi
}

api() {
    local method="$1" endpoint="$2" data="$3"
    local token=$(get_token)

    if [ -z "$token" ]; then
        echo "ERROR: No token. Run: beeper-cli.sh setup <token>" >&2
        exit 1
    fi

    if [ "$method" = "GET" ]; then
        curl -s --max-time 30 -H "Authorization: Bearer $token" "${BEEPER_API}${endpoint}"
    else
        curl -s --max-time 30 -X "$method" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$data" "${BEEPER_API}${endpoint}"
    fi
}

# URL encode - strip backslashes (zsh escaping) then encode special chars
urlencode() {
    echo "$1" | tr -d '\\' | sed 's/#/%23/g; s/!/%21/g; s/:/%3A/g; s/@/%40/g'
}

# Find the Mac Contacts database with the most records
find_contacts_db() {
    local best_db="" best_count=0
    for db in "$HOME/Library/Application Support/AddressBook/Sources/"*/AddressBook-v22.abcddb; do
        [ -f "$db" ] || continue
        local count=$(sqlite3 "$db" "SELECT COUNT(*) FROM ZABCDRECORD" 2>/dev/null || echo 0)
        if [ "$count" -gt "$best_count" ]; then
            best_count=$count
            best_db="$db"
        fi
    done
    echo "$best_db"
}

CONTACTS_DB=""
init_contacts() {
    [ -n "$CONTACTS_DB" ] && return
    CONTACTS_DB=$(find_contacts_db)
}

# Look up a phone number in Mac Contacts, return name if found
lookup_contact() {
    local input="$1"
    init_contacts
    [ -z "$CONTACTS_DB" ] && echo "$input" && return

    # Check if input looks like a phone number (starts with + or digit, has mostly digits)
    local digits=$(echo "$input" | tr -cd '0-9')
    if [ ${#digits} -lt 7 ]; then
        echo "$input"
        return
    fi

    # Query contacts database - match last 10 digits to handle country code variations
    local last10="${digits: -10}"
    local result=$(sqlite3 "$CONTACTS_DB" "
        SELECT r.ZFIRSTNAME, r.ZLASTNAME, r.ZORGANIZATION
        FROM ZABCDPHONENUMBER p
        JOIN ZABCDRECORD r ON p.ZOWNER = r.Z_PK
        WHERE SUBSTR(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(p.ZFULLNUMBER, '+', ''), '-', ''), ' ', ''), '(', ''), ')', ''), -10) = '$last10'
        LIMIT 1
    " 2>/dev/null)

    if [ -n "$result" ]; then
        local fname=$(echo "$result" | cut -d'|' -f1)
        local lname=$(echo "$result" | cut -d'|' -f2)
        local org=$(echo "$result" | cut -d'|' -f3)
        # Build name: prefer first+last, fall back to org, then original
        if [ -n "$fname" ] || [ -n "$lname" ]; then
            echo "${fname}${fname:+ }${lname}" | sed 's/^ *//;s/ *$//'
        elif [ -n "$org" ]; then
            echo "$org"
        else
            echo "$input"
        fi
    else
        echo "$input"
    fi
}

cmd_status() {
    if ! curl -s --max-time 5 "$BEEPER_API" >/dev/null 2>&1; then
        # Check if Beeper Desktop is installed
        if [ -d "/Applications/Beeper.app" ] || [ -d "$HOME/Applications/Beeper.app" ]; then
            echo "BEEPER_NOT_RUNNING"
            echo ""
            echo "Beeper Desktop is installed but the API isn't enabled."
            echo ""
            echo "Fix:"
            echo "  1. Open Beeper Desktop"
            echo "  2. Go to Settings → Developers"
            echo "  3. Toggle ON 'Beeper Desktop API'"
        else
            echo "BEEPER_NOT_INSTALLED"
            echo ""
            echo "Beeper Desktop is not installed."
            echo ""
            echo "Beeper is a universal chat app that combines WhatsApp, Telegram,"
            echo "Signal, LinkedIn, Discord, Slack, and more into one inbox."
            echo ""
            echo "To install:"
            echo "  1. Go to https://beeper.com"
            echo "  2. Download Beeper Desktop for Mac"
            echo "  3. Sign in and connect your chat accounts"
            echo "  4. Then run this command again to set up the API"
        fi
        exit 1
    fi

    local resp=$(api GET "/v1/accounts" 2>&1)
    if echo "$resp" | grep -qi "unauthorized"; then
        echo "BEEPER_UNAUTHORIZED"
        echo ""
        echo "Fix: Settings → Developers → '+' next to Approved connections → copy token"
        echo "Then: beeper-cli.sh setup <token>"
        exit 1
    fi

    echo "BEEPER_CONNECTED"
    echo ""
    echo "Accounts:"
    echo "$resp" | jq -r '.[] | "  [\(.network)] \(.user.fullName // .user.username // "Unknown")"'
}

cmd_setup() {
    local token="$1"
    if [ -z "$token" ]; then
        echo "Usage: beeper-cli.sh setup <token>"
        exit 1
    fi
    mkdir -p "$(dirname "$TOKEN_FILE")"
    echo "$token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo "Token saved."
    echo ""
    cmd_status
}

cmd_accounts() {
    api GET "/v1/accounts" | jq -r '.[] | "\(.accountID) | \(.network) | \(.user.fullName // .user.username)"'
}

cmd_chats() {
    local limit="${1:-20}"
    init_contacts
    api GET "/v1/chats" | jq -r --argjson n "$limit" '
        .items[:$n][] |
        "\(.id)\t\(.network)\t\(.title[:40])\t\(.unreadCount)"
    ' | while IFS=$'\t' read -r id network title unread; do
        local display_title=$(lookup_contact "$title")
        local suffix=""
        [ "$unread" -gt 0 ] 2>/dev/null && suffix=" [$unread unread]"
        echo "$id | $network | ${display_title}${suffix}"
    done
}

cmd_search_chats() {
    local query="$1" limit="${2:-20}"
    if [ -z "$query" ]; then
        echo "Usage: beeper-cli.sh search-chats <query>"
        exit 1
    fi
    api GET "/v1/chats/search?query=$(urlencode "$query")&limit=$limit" | jq -r '
        .items[] |
        "\(.id) | \(.network) | \(.title[:40])\(if .unreadCount > 0 then " [\(.unreadCount)]" else "" end)"
    '
}

cmd_messages() {
    local chat_id="$1" limit="${2:-20}" cursor="$3"
    if [ -z "$chat_id" ]; then
        echo "Usage: beeper-cli.sh messages <chat_id> [limit] [cursor]"
        echo "  cursor: sortKey from previous results to get older messages"
        exit 1
    fi
    # Cap at 200 messages max
    [ "$limit" -gt 200 ] && limit=200

    local endpoint="/v1/chats/$(urlencode "$chat_id")/messages"
    [ -n "$cursor" ] && endpoint="${endpoint}?cursor=$cursor"

    local response=$(api GET "$endpoint")
    local has_more=$(echo "$response" | jq -r '.hasMore // false')
    local oldest_sort=$(echo "$response" | jq -r '(.items // [])[-1].sortKey // empty')

    echo "$response" | jq -r --argjson n "$limit" '
        (.items // [])[:$n][] |
        "\(.timestamp[:10]) | \(.senderName // "Unknown") | \((.text // "") | gsub("\n"; " "))"
    ' 2>/dev/null

    if [ "$has_more" = "true" ] && [ -n "$oldest_sort" ]; then
        echo ""
        echo "--- More messages available. To see older: messages '<chat_id>' $limit $oldest_sort ---"
    fi
}

cmd_search() {
    local query="$1" limit="${2:-20}"
    if [ -z "$query" ]; then
        echo "Usage: beeper-cli.sh search <query>"
        exit 1
    fi
    api GET "/v1/messages/search?query=$(urlencode "$query")&limit=$limit" | jq -r '
        .items[] as $m |
        (.chats[$m.chatID].title // "Unknown")[:20] as $chat |
        "\($m.timestamp[:10]) | \($chat) | \($m.senderName // "Unknown"): \($m.text[:500] | gsub("\n"; " "))"
    '
}

cmd_search_chat() {
    local chat_id="$1" query="$2" context="${3:-2}"
    if [ -z "$chat_id" ] || [ -z "$query" ]; then
        echo "Usage: beeper-cli.sh search-chat <chat_id> <query> [context]"
        echo "  context: number of messages before/after match (default: 2)"
        exit 1
    fi

    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
    local tmpfile=$(mktemp)
    local cursor=""
    local pages=0
    local max_pages=5  # Search up to ~100 messages back

    # Fetch messages, paginating if needed
    while [ $pages -lt $max_pages ]; do
        local endpoint="/v1/chats/$(urlencode "$chat_id")/messages"
        [ -n "$cursor" ] && endpoint="${endpoint}?cursor=$cursor"

        local response=$(api GET "$endpoint")
        echo "$response" | jq -c '.items[]' >> "$tmpfile"

        local has_more=$(echo "$response" | jq -r '.hasMore')
        cursor=$(echo "$response" | jq -r '.items[-1].sortKey // empty')

        # Check if we found any matches in this page
        local found=$(echo "$response" | jq --arg q "$query_lower" '
            [.items[] | select(.text != null and (.text | ascii_downcase | contains($q)))] | length
        ')
        [ "$found" -gt 0 ] && break
        [ "$has_more" != "true" ] && break

        pages=$((pages + 1))
    done

    # Find match indices and display with context
    local indices=$(jq -s --arg q "$query_lower" '
        to_entries | map(select(.value.text != null and (.value.text | ascii_downcase | contains($q)))) | map(.key) | .[]
    ' "$tmpfile")

    if [ -z "$indices" ]; then
        echo "No matches found for \"$query\""
        rm -f "$tmpfile"
        return
    fi

    local total=$(jq -s 'length' "$tmpfile")

    for idx in $indices; do
        local start=$((idx - context))
        [ $start -lt 0 ] && start=0
        local end=$((idx + context + 1))
        [ $end -gt $total ] && end=$total

        # Show context before
        jq -rs --argjson s $start --argjson e $idx '.[$s:$e][] | "\(.timestamp[:10]) | \(.senderName // "?"): \(.text | gsub("\n"; " "))"' "$tmpfile"

        # Show match (highlighted with >>>)
        jq -rs --argjson i $idx '.[$i] | ">>> \(.timestamp[:10]) | \(.senderName // "?"): \(.text | gsub("\n"; " "))"' "$tmpfile"

        # Show context after
        local after_start=$((idx + 1))
        jq -rs --argjson s $after_start --argjson e $end '.[$s:$e][] | "\(.timestamp[:10]) | \(.senderName // "?"): \(.text | gsub("\n"; " "))"' "$tmpfile"

        echo ""
        echo "---"
        echo ""
    done

    rm -f "$tmpfile"
}

cmd_unread() {
    local limit="${1:-20}"
    init_contacts
    local result=$(api GET "/v1/chats/search?unreadOnly=true&limit=$limit")
    local count=$(echo "$result" | jq -r '.items | length')

    if [ "$count" = "0" ]; then
        echo "No unread chats"
    else
        echo "$result" | jq -r '.items[] | "\(.id)\t\(.network)\t\(.title[:40])\t\(.unreadCount)"' | while IFS=$'\t' read -r id network title unread; do
            local display_title=$(lookup_contact "$title")
            echo "$id | $network | ${display_title} [$unread unread]"
        done
    fi
}

cmd_latest_received() {
    init_contacts
    # Get user's names from accounts to filter out sent messages
    local my_names=$(api GET "/v1/accounts" | jq -r '.[].user | .fullName // .username // empty' | sort -u)
    local my_names_pattern=$(echo "$my_names" | paste -sd'|' -)
    local chat_ids=$(api GET "/v1/chats" | jq -r '.items[:20]? // [] | .[].id')

    local best_timestamp=""
    local best_result=""

    # For each chat, find the most recent message not from me
    for chat_id in $chat_ids; do
        local result=$(api GET "/v1/chats/$(urlencode "$chat_id")/messages" | jq -r --arg names "$my_names_pattern" '
            [(.items // [])[] | select(.senderName != null and (.senderName | test($names) | not))][0] // empty |
            if . then "\(.timestamp)\t\(.senderName)\t\(.text // "" | gsub("\n"; " "))" else empty end
        ' 2>/dev/null)

        if [ -n "$result" ]; then
            local timestamp=$(echo "$result" | cut -f1)
            # Compare timestamps (ISO format sorts lexicographically)
            if [ -z "$best_timestamp" ] || [[ "$timestamp" > "$best_timestamp" ]]; then
                best_timestamp="$timestamp"
                local sender=$(echo "$result" | cut -f2)
                sender=$(lookup_contact "$sender")
                local text=$(echo "$result" | cut -f3-)
                local network=$(api GET "/v1/chats/$(urlencode "$chat_id")" | jq -r '.network // "Unknown"' 2>/dev/null)
                best_result="${timestamp:0:10} | $network | $sender\n\n$text"
            fi
        fi
    done

    if [ -n "$best_result" ]; then
        echo -e "$best_result"
    else
        echo "No recent received messages found"
    fi
}

cmd_search_sender() {
    local query="$1" limit="${2:-10}"
    if [ -z "$query" ]; then
        echo "Usage: beeper-cli.sh search-sender <name> [limit]"
        exit 1
    fi
    init_contacts
    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
    local found=0
    local tmpfile=$(mktemp)

    # Get user's phone numbers to filter out own messages
    local my_phones=$(api GET "/v1/accounts" | jq -r '.[].user.phoneNumber // empty' | tr -d '+' | while read p; do
        # Store last 10 digits for matching
        echo "${p: -10}"
    done | paste -sd'|' -)

    # Get all chats
    local all_chats=$(api GET "/v1/chats" | jq -c '.items[:50]? // []')

    # Strategy 1: Find iMessage chats where the resolved contact name matches
    # (iMessage API returns phone numbers as titles, but we can resolve to names)
    local imsg_chats=$(echo "$all_chats" | jq -r '.[] | select(.network == "iMessage") | "\(.id)\t\(.title)"')

    while IFS=$'\t' read -r chat_id raw_title; do
        [ -z "$chat_id" ] && continue
        # Resolve phone number to contact name
        local resolved_name=$(lookup_contact "$raw_title")
        local resolved_lower=$(echo "$resolved_name" | tr '[:upper:]' '[:lower:]')

        if [[ "$resolved_lower" == *"$query_lower"* ]]; then
            # Found a match - get messages from this chat, excluding our own
            api GET "/v1/chats/$(urlencode "$chat_id")/messages" | jq -r --argjson n "$limit" --arg name "$resolved_name" --arg myphones "$my_phones" '
                # Filter out messages from self (match last 10 digits of phone)
                def is_self: . as $sender | ($sender | gsub("[^0-9]"; "")) | .[-10:] | test($myphones);
                [(.items // [])[] | select(.senderName != null and (.senderName | is_self | not))][:$n][] |
                "\(.timestamp)\t\($name)\t\((.text // "")[:500] | gsub("\n"; " "))"
            ' 2>/dev/null >> "$tmpfile"
        fi
    done <<< "$imsg_chats"

    # Strategy 2: Search by senderName field (works for WhatsApp, Telegram, etc.)
    local other_chat_ids=$(echo "$all_chats" | jq -r '.[] | select(.network != "iMessage") | .id')

    for chat_id in $other_chat_ids; do
        [ -z "$chat_id" ] && continue
        api GET "/v1/chats/$(urlencode "$chat_id")/messages" | jq -r --arg q "$query_lower" --argjson n "$limit" '
            [(.items // [])[] | select(.senderName != null and (.senderName | ascii_downcase | contains($q)))][:$n][] |
            "\(.timestamp)\t\(.senderName)\t\((.text // "")[:500] | gsub("\n"; " "))"
        ' 2>/dev/null >> "$tmpfile"
    done

    # Sort by timestamp desc and display
    if [ -s "$tmpfile" ]; then
        sort -t$'\t' -k1,1r "$tmpfile" | head -n "$limit" | while IFS=$'\t' read -r ts sender text; do
            echo "${ts:0:10} | $sender | $text"
        done
        found=1
    fi

    rm -f "$tmpfile"

    if [ "$found" -eq 0 ]; then
        echo "No messages found from '$query'"
    fi
}

cmd_who_messaged() {
    local days="${1:-7}"
    local cutoff_date=$(date -v-${days}d +%Y-%m-%d 2>/dev/null || date -d "$days days ago" +%Y-%m-%d)
    local my_names=$(api GET "/v1/accounts" | jq -r '.[].user | .fullName // .username // empty' | sort -u)
    local my_names_pattern=$(echo "$my_names" | paste -sd'|' -)
    local chat_ids=$(api GET "/v1/chats" | jq -r '.items[:50]? // [] | .[].id')
    local tmpfile=$(mktemp)

    for chat_id in $chat_ids; do
        api GET "/v1/chats/$(urlencode "$chat_id")/messages" | jq -r --arg names "$my_names_pattern" --arg cutoff "$cutoff_date" '
            [(.items // [])[] | select(.senderName != null and (.senderName | test($names) | not) and (.timestamp[:10] >= $cutoff))][:5][] |
            "\(.timestamp)\t\(.senderName)"
        ' 2>/dev/null >> "$tmpfile"
    done

    # Dedupe by sender, keeping most recent timestamp, then sort by date desc
    local results=$(sort -t$'\t' -k1,1r "$tmpfile" | awk -F'\t' '!seen[$2]++ {print substr($1,1,10) " | " $2}')
    rm -f "$tmpfile"

    if [ -n "$results" ]; then
        echo "$results"
    else
        echo "No messages received in the last $days days"
    fi
}

cmd_needs_response() {
    local days="${1:-7}"
    local cutoff_date=$(date -v-${days}d +%Y-%m-%d 2>/dev/null || date -d "$days days ago" +%Y-%m-%d)
    local my_names=$(api GET "/v1/accounts" | jq -r '.[].user | .fullName // .username // empty' | sort -u)
    local my_names_pattern=$(echo "$my_names" | paste -sd'|' -)
    local chats=$(api GET "/v1/chats" | jq -r '.items[:30]? // [] | .[] | "\(.id)\t\(.network)\t\(.title[:30])"')
    local found=0

    while IFS=$'\t' read -r chat_id network title; do
        [ -z "$chat_id" ] && continue
        local last_msg=$(api GET "/v1/chats/$(urlencode "$chat_id")/messages" | jq -r --arg names "$my_names_pattern" --arg cutoff "$cutoff_date" '
            (.items // [])[0] |
            if . and .senderName != null and (.senderName | test($names) | not) and (.timestamp[:10] >= $cutoff) then
                "\(.timestamp[:10])\t\(.senderName)\t\((.text // "")[:100] | gsub("\n"; " "))"
            else
                empty
            end
        ' 2>/dev/null)
        if [ -n "$last_msg" ]; then
            local date=$(echo "$last_msg" | cut -f1)
            local sender=$(echo "$last_msg" | cut -f2)
            local preview=$(echo "$last_msg" | cut -f3-)
            echo "$date | $network | $sender"
            echo "  $preview"
            echo ""
            found=$((found + 1))
        fi
    done <<< "$chats"

    if [ "$found" -eq 0 ]; then
        echo "All caught up - no pending responses in the last $days days"
    fi
}

cmd_conversation() {
    local query="$1" limit="${2:-30}"
    if [ -z "$query" ]; then
        echo "Usage: beeper-cli.sh conversation <name> [limit]"
        echo "  Shows full conversation thread with a person (both sides)"
        exit 1
    fi
    init_contacts
    local query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
    local found_chat=""
    local found_name=""

    # Get all chats
    local all_chats=$(api GET "/v1/chats" | jq -c '.items[:50]? // []')

    # Strategy 1: Check iMessage chats (resolve phone to contact name)
    local imsg_chats=$(echo "$all_chats" | jq -r '.[] | select(.network == "iMessage") | "\(.id)\t\(.title)"')

    while IFS=$'\t' read -r chat_id raw_title; do
        [ -z "$chat_id" ] && continue
        local resolved_name=$(lookup_contact "$raw_title")
        local resolved_lower=$(echo "$resolved_name" | tr '[:upper:]' '[:lower:]')

        if [[ "$resolved_lower" == *"$query_lower"* ]]; then
            found_chat="$chat_id"
            found_name="$resolved_name"
            break
        fi
    done <<< "$imsg_chats"

    # Strategy 2: Check other platforms by chat title
    if [ -z "$found_chat" ]; then
        local other_chats=$(echo "$all_chats" | jq -r '.[] | select(.network != "iMessage") | "\(.id)\t\(.title)"')

        while IFS=$'\t' read -r chat_id title; do
            [ -z "$chat_id" ] && continue
            local title_lower=$(echo "$title" | tr '[:upper:]' '[:lower:]')

            if [[ "$title_lower" == *"$query_lower"* ]]; then
                found_chat="$chat_id"
                found_name="$title"
                break
            fi
        done <<< "$other_chats"
    fi

    # Strategy 3: Search by senderName in messages (for WhatsApp/LinkedIn where title may not match)
    if [ -z "$found_chat" ]; then
        local other_chat_ids=$(echo "$all_chats" | jq -r '.[] | select(.network != "iMessage") | .id')

        for chat_id in $other_chat_ids; do
            [ -z "$chat_id" ] && continue
            local sender_match=$(api GET "/v1/chats/$(urlencode "$chat_id")/messages" | jq -r --arg q "$query_lower" '
                [(.items // [])[] | select(.senderName != null and (.senderName | ascii_downcase | contains($q)))][0].senderName // empty
            ' 2>/dev/null)

            if [ -n "$sender_match" ]; then
                found_chat="$chat_id"
                found_name="$sender_match"
                break
            fi
        done
    fi

    if [ -z "$found_chat" ]; then
        echo "No conversation found for '$query'"
        exit 1
    fi

    echo "=== Conversation with $found_name ==="
    echo ""

    # Get messages and display with resolved sender names
    local response=$(api GET "/v1/chats/$(urlencode "$found_chat")/messages")
    local has_more=$(echo "$response" | jq -r '.hasMore // false')
    local oldest_sort=$(echo "$response" | jq -r '(.items // [])[-1].sortKey // empty')

    echo "$response" | jq -r --argjson n "$limit" '
        (.items // [])[:$n][] |
        "\(.timestamp[:10])\t\(.senderName // "Unknown")\t\((.text // "") | gsub("\n"; " "))"
    ' 2>/dev/null | while IFS=$'\t' read -r date sender text; do
        local display_sender=$(lookup_contact "$sender")
        echo "$date | $display_sender | $text"
    done

    if [ "$has_more" = "true" ] && [ -n "$oldest_sort" ]; then
        echo ""
        echo "--- More messages available. Use: messages '$found_chat' $limit $oldest_sort ---"
    fi
}

cmd_send() {
    local chat_id="$1" text="$2"
    if [ -z "$chat_id" ] || [ -z "$text" ]; then
        echo "Usage: beeper-cli.sh send <chat_id> <message>"
        exit 1
    fi
    if [ ! -f "$HOME/.config/beeper-cli/send-enabled" ]; then
        echo "Send disabled. Run: beeper-cli.sh enable-send"
        exit 1
    fi
    api POST "/v1/chats/$(urlencode "$chat_id")/messages" "{\"text\":\"$text\"}" | jq -r '"Sent: \(.pendingMessageID // "ok")"'
}

cmd_enable_send() {
    mkdir -p "$HOME/.config/beeper-cli"
    touch "$HOME/.config/beeper-cli/send-enabled"
    echo "Send enabled."
}

cmd_disable_send() {
    rm -f "$HOME/.config/beeper-cli/send-enabled"
    echo "Send disabled."
}

cmd_help() {
    cat << 'EOF'
beeper-cli.sh - Access Beeper Desktop API

COMMANDS:
  status              Check connection
  setup <token>       Save API token
  accounts            List connected accounts
  chats [n]           List recent chats
  search-chats <q>    Search chats by name
  messages <id> [n] [cursor]  Read messages (cursor for older)
  search <query>      Search all messages
  search-chat <id> <q> [ctx]  Search within a chat with context
  search-sender <name> Find messages from a person
  conversation <name> Full conversation thread (both sides)
  unread              List unread chats
  latest-received     Most recent message received (not sent)
  who-messaged [days] People who messaged you (default: 7 days)
  needs-response [days] Chats awaiting your reply (default: 7 days)
  send <id> <msg>     Send message (needs enable-send)
  enable-send         Allow sending
  disable-send        Read-only mode

SETUP:
  1. Beeper Desktop → Settings → Developers
  2. Toggle ON "Beeper Desktop API"
  3. Click "+" next to "Approved connections"
  4. beeper-cli.sh setup <token>
EOF
}

case "$COMMAND" in
    status) cmd_status ;;
    setup) cmd_setup "$@" ;;
    accounts) cmd_accounts ;;
    chats|list) cmd_chats "$@" ;;
    search-chats) cmd_search_chats "$@" ;;
    messages|msgs) cmd_messages "$@" ;;
    search) cmd_search "$@" ;;
    search-chat) cmd_search_chat "$@" ;;
    search-sender|from) cmd_search_sender "$@" ;;
    conversation|convo|thread) cmd_conversation "$@" ;;
    unread) cmd_unread "$@" ;;
    latest-received|latest) cmd_latest_received ;;
    who-messaged|who) cmd_who_messaged "$@" ;;
    needs-response|pending) cmd_needs_response ;;
    send) cmd_send "$@" ;;
    enable-send) cmd_enable_send ;;
    disable-send) cmd_disable_send ;;
    help|--help|-h) cmd_help ;;
    *) echo "Unknown: $COMMAND"; cmd_help; exit 1 ;;
esac
