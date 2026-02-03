---
description: Access Beeper messages across all platforms (WhatsApp, Telegram, Signal, etc)
model: sonnet
allowed-tools: Bash, Read
---

# Beeper Messages Assistant

Access messages across all your chat platforms via Beeper Desktop API. Works with WhatsApp, Telegram, Signal, Instagram, LinkedIn, Discord, Slack, and more.

## Setup (check in order)

**Step 1: Check if already working**
```bash
./ops/scripts/beeper-cli.sh status 2>&1
```

**If shows `ERROR: jq is required`** → Check if they have Homebrew:
```bash
which brew
```

If brew exists → run `brew install jq` yourself, then re-run status.

If no brew → tell user: "jq needs Homebrew. In Finder, open your workspace folder and double-click `SETUP.command` - it'll install Homebrew and the tools you need. Follow the prompts in the terminal window, then try `/messages` again."

**If shows `BEEPER_CONNECTED`** → Ready. If user just said "/messages" with no specific request, ask: "What can I help you find in your messages?"

**If shows `BEEPER_NOT_INSTALLED`** → Share the script's output with the user. It explains what Beeper is and how to install it.

**If shows `BEEPER_NOT_RUNNING`** → Tell the user:

"Beeper Desktop API needs to be enabled:
1. Open **Beeper Desktop**
2. Go to **Settings → Developers**
3. Toggle ON **'Beeper Desktop API'** at the top
4. (Optional) Enable 'Start on launch' so it stays on

Let me know when that's done."

Then re-run the status check.

**If shows `BEEPER_UNAUTHORIZED` or `ERROR: No token configured`** → Tell the user:

"I need a token to access your messages:
1. In Beeper Desktop: **Settings → Developers**
2. Click **'+'** next to **'Approved connections'**
3. Copy the token it generates
4. **Paste it here** and I'll save it for you"

When they paste the token, save it:
```bash
./ops/scripts/beeper-cli.sh setup <their_token>
```

Then re-run status to confirm it works.

**If script not found** → Download it first:
```bash
mkdir -p ./ops/scripts
curl -sL https://raw.githubusercontent.com/derek-larson14/feed-the-beast/main/ops/scripts/beeper-cli.sh -o ./ops/scripts/beeper-cli.sh
chmod +x ./ops/scripts/beeper-cli.sh
```

## Commands

**Check status and accounts:**
```bash
./ops/scripts/beeper-cli.sh status
```

**List connected accounts:**
```bash
./ops/scripts/beeper-cli.sh accounts
```

**List recent chats:**
```bash
./ops/scripts/beeper-cli.sh chats        # 20 most recent
./ops/scripts/beeper-cli.sh chats 50     # 50 most recent
```

**Search chats by name:**
```bash
./ops/scripts/beeper-cli.sh search-chats "john"
./ops/scripts/beeper-cli.sh search-chats "work team"
```

**List messages in a chat:**
```bash
./ops/scripts/beeper-cli.sh messages '<chat_id>'
./ops/scripts/beeper-cli.sh messages '<chat_id>' 50
./ops/scripts/beeper-cli.sh messages '<chat_id>' 20 <cursor>  # older messages
```
The command shows a cursor at the bottom if more messages exist. Use that cursor value to paginate to older messages. Max 200 messages per request.

**Search messages across all chats:**
```bash
./ops/scripts/beeper-cli.sh search "meeting"
./ops/scripts/beeper-cli.sh search "dinner plans"
```

**Find messages from a specific person:**
```bash
./ops/scripts/beeper-cli.sh search-sender "sarah"
./ops/scripts/beeper-cli.sh search-sender "john" 10
```
Note: Use this instead of search-chats when looking for a person - chat titles on WhatsApp/LinkedIn often show your own name, not theirs.

**Full conversation with someone (both sides):**
```bash
./ops/scripts/beeper-cli.sh conversation "john"
./ops/scripts/beeper-cli.sh conversation "john" 50  # more messages
```
Shows the complete thread - both what they said and what you said. Works across iMessage, WhatsApp, LinkedIn, etc.

**Search within a specific conversation (with context):**
```bash
./ops/scripts/beeper-cli.sh search-chat '<chat_id>' "topic"
./ops/scripts/beeper-cli.sh search-chat '<chat_id>' "project" 3  # 3 msgs context
```
Shows matching messages with surrounding context. Use for "find where X and I talked about Y".

**List chats with unread messages:**
```bash
./ops/scripts/beeper-cli.sh unread
./ops/scripts/beeper-cli.sh unread 10
```

**Most recent message you received:**
```bash
./ops/scripts/beeper-cli.sh latest-received
```

**Who messaged you recently:**
```bash
./ops/scripts/beeper-cli.sh who-messaged        # last 7 days
./ops/scripts/beeper-cli.sh who-messaged 30     # last 30 days
```

**Chats awaiting your reply:**
```bash
./ops/scripts/beeper-cli.sh needs-response      # last 7 days
./ops/scripts/beeper-cli.sh needs-response 14   # last 14 days
```

## Common Patterns

**"Check my messages" / "Any new messages?"**
```bash
./ops/scripts/beeper-cli.sh unread
```

**"What was my most recent message?"**
```bash
./ops/scripts/beeper-cli.sh latest-received
```

**"Any messages from Sarah?" / "What did John say?"**
```bash
./ops/scripts/beeper-cli.sh search-sender "sarah"
```

**"Who's messaged me recently?"**
```bash
./ops/scripts/beeper-cli.sh who-messaged 14
```

**"What do I need to respond to?"**
```bash
./ops/scripts/beeper-cli.sh needs-response
```

**"Find messages about the project"**
```bash
./ops/scripts/beeper-cli.sh search "project"
```

**"Show me my WhatsApp chats"**
```bash
./ops/scripts/beeper-cli.sh chats | grep -i whatsapp
```

**"Read my full conversation with John" / "What have John and I been talking about?"**
```bash
./ops/scripts/beeper-cli.sh conversation "john" 30
```

**"Find where John and I talked about the project"**
```bash
# First find John's chat ID
./ops/scripts/beeper-cli.sh search-sender "john"
# Then search within that conversation
./ops/scripts/beeper-cli.sh search-chat '<chat_id>' "project" 3
```
Shows matches with 3 messages of context before/after.

## Output Format

**Chats output:**
```
!roomid:beeper.com | WhatsApp | John Smith [3 unread]
!another:beeper.com | Telegram | Work Group
```
- Format: `chat_id | network | title [unread count]`

**Messages output:**
```
01/15 14:30 | John | Hey, are we still on for tomorrow?
01/15 14:32 | Me | Yes, 2pm works
```
- Format: `date time | sender | message preview`

**Search output:**
```
01/15 | Work Group | Sarah: The meeting is at 3pm
01/14 | John Smith | John: Let's discuss the project
```
- Format: `date | chat | sender: message preview`

## Sending Messages

Default is **read-only**. If user wants to send messages:

"Right now I can only read your messages. I can enable send mode:

**Read-only (current):** Search and read messages. Can't send anything.

**Send enabled:** Can send messages to any chat. Use with care.

Want me to enable sending?"

If yes:
```bash
./ops/scripts/beeper-cli.sh enable-send
```

Then to send:
```bash
./ops/scripts/beeper-cli.sh send '<chat_id>' "Your message here"
```

To disable:
```bash
./ops/scripts/beeper-cli.sh disable-send
```

## Chat IDs

Chat IDs look like `!NCdzlIaMjZUmvmvyHU:beeper.com` - always get these from the chats or search-chats commands, don't try to construct them.

**Important:** Chat titles on WhatsApp and LinkedIn often show the user's own name, not the other person's. Use `search-sender` to find messages from a specific person rather than `search-chats`.

When a user asks about a specific person:
- **"What did X say?"** → `search-sender "name"` (messages FROM them only)
- **"What have X and I been talking about?"** → `conversation "name"` (full thread, both sides)
- **"Find where X mentioned Y"** → `conversation` to get chat context, then `search-chat` if needed

## Multiple Accounts

Beeper combines all your accounts. Messages from WhatsApp, Telegram, Signal, etc. all appear together.

To see which accounts are connected:
```bash
./ops/scripts/beeper-cli.sh accounts
```

## Security Note

The Beeper Desktop API runs locally on your machine (localhost:23373). The token you configure gives access to all your messages across all platforms. Keep it secure.

## Troubleshooting

**"BEEPER_NOT_INSTALLED" error:**
- Beeper Desktop isn't installed
- User needs to install from https://beeper.com
- After install, they connect their chat accounts (WhatsApp, etc.)
- Then run `/messages` again

**"BEEPER_NOT_RUNNING" error:**
- Beeper is installed but API not enabled
- Open Beeper Desktop
- Go to Settings → Developers
- Toggle ON "Beeper Desktop API" at the top
- Optionally enable "Start on launch" to persist

**"BEEPER_UNAUTHORIZED" error:**
- Token is missing or invalid
- Create a new token in Settings → Developers → Approved connections
- Run: `beeper-cli.sh setup <new_token>`

**API timeout errors:**
- Beeper Desktop might be overwhelmed
- Wait a moment and try again
- Check that Beeper Desktop is responding

**"No messages found" but chat exists:**
- `search` only searches message content, not sender names
- Use `search-sender "name"` to find messages FROM a person
- Searches are literal word matching, not semantic
- Try simpler, single-word queries
- Search is case-insensitive

## Response Style

- Summarize chat lists (network, name, unread count) - don't dump raw output
- For searches, highlight relevant results with context
- For long message threads, summarize unless user asks for full content
- If multiple matches, list options and ask which one to read
- Always show chat IDs when the user might need them for follow-up commands
- Don't narrate for the sake of narrating - only when it's useful
