---
description: Access Mac Mail app - works with any email provider (IMAP, POP3, Exchange, iCloud)
model: sonnet
allowed-tools: Bash, Read
---

# Mac Mail Assistant

Access email via Mac Mail app using AppleScript. Works with ANY email provider configured in Mail.app (iCloud, Gmail, self-hosted IMAP, Exchange, etc).

**Mac only.** If the user is on Windows or Linux, tell them: "/mail uses Mac-only AppleScript. For email access, try [Rube](https://rube.app) which can connect to Gmail, Outlook, and other email services."

## Setup (check in order)

**Step 1: Check if already working**
```bash
./ops/scripts/mail-cli.sh status 2>&1
```
- If shows `MAIL_CONNECTED` with accounts → **ready**. If user just said "/mail" with no specific request, ask: "What email task can I help with?"
- If shows `MAIL_NOT_ACCESSIBLE` → need permission (Step 2)
- If script not found → download it (Step 3)

**Step 2: Grant Automation permission**

Tell the user: "I need permission to access Mail.app."

Go to **System Settings → Privacy & Security → Automation** and enable:
- **Obsidian** (or Terminal) to control **Mail**

macOS will also prompt on first use - click Allow.

**Step 3: Get the script (if missing)**

```bash
mkdir -p ./ops/scripts
curl -sL https://raw.githubusercontent.com/derek-larson14/feed-the-beast/main/ops/scripts/mail-cli.sh -o ./ops/scripts/mail-cli.sh
chmod +x ./ops/scripts/mail-cli.sh
```

## Commands

**List recent emails:**
```bash
./ops/scripts/mail-cli.sh list        # 10 most recent
./ops/scripts/mail-cli.sh list 25     # 25 most recent
```

**Read a specific email:**
```bash
./ops/scripts/mail-cli.sh read <message_id>
```

**Search emails (searches subject and sender):**
```bash
./ops/scripts/mail-cli.sh search "meeting"
./ops/scripts/mail-cli.sh search "john@example.com"
```

**Search by sender:**
```bash
./ops/scripts/mail-cli.sh from "sarah"
```

**Full-text search (includes body - slower):**
```bash
./ops/scripts/mail-cli.sh search-body "project deadline"
```

**List unread emails:**
```bash
./ops/scripts/mail-cli.sh unread
./ops/scripts/mail-cli.sh unread 20   # limit to 20
```

**List folders/mailboxes:**
```bash
./ops/scripts/mail-cli.sh folders
```

**Check status and accounts:**
```bash
./ops/scripts/mail-cli.sh status
```

## Common Patterns

**"Check my email"**
```bash
./ops/scripts/mail-cli.sh list 10
```

**"Any emails from Sarah?"**
```bash
./ops/scripts/mail-cli.sh from "sarah"
```

**"Show me unread emails"**
```bash
./ops/scripts/mail-cli.sh unread
```

**"Find emails about the proposal"**
```bash
./ops/scripts/mail-cli.sh search "proposal"
```

**"What came in today?"**
```bash
./ops/scripts/mail-cli.sh today
```

**"Search for emails mentioning 'quarterly report' anywhere"**
```bash
./ops/scripts/mail-cli.sh search-body "quarterly report"
```

**"Read that first one"**
```bash
./ops/scripts/mail-cli.sh read <id_from_previous_list>
```

## Output Format

**List/Search output:**
```
* 2140 | John <john@example.com> | Meeting tomorrow | Wednesday, January 21, 2026 at 7:01:31 AM
  2141 | Sarah <sarah@example.com> | Re: Project update | Tuesday, January 20, 2026 at 3:15:00 PM
```
- `*` prefix = unread
- Format: `id | from | subject | date`

**Read output:**
```
From: John <john@example.com>
To: me@example.com
Subject: Meeting tomorrow
Date: Wednesday, January 21, 2026 at 7:01:31 AM

Full email content here...
```

## Composing Emails

Default is **read-only**. If user wants to compose/send:

"Right now I can only read your email. I can enable compose mode:

**Read-only (current):** Search and read. Can't modify or send anything.

**Compose enabled:** Opens a compose window in Mail.app - you still click Send manually.

Want me to enable compose?"

If yes:
```bash
./ops/scripts/mail-cli.sh enable-compose
```

Then to compose:
```bash
./ops/scripts/mail-cli.sh compose "recipient@example.com" "Subject line" "Email body here"
```
This opens Mail.app with the draft - user reviews and clicks Send.

To disable:
```bash
./ops/scripts/mail-cli.sh disable-compose
```

## Multiple Accounts

If user has multiple accounts in Mail.app, messages from all enabled accounts appear in the unified inbox.

To see which accounts are configured:
```bash
./ops/scripts/mail-cli.sh status
```

To check which accounts are enabled/disabled, or to enable an account:
- Open Mail.app → Settings → Accounts
- Check the "Enable this account" checkbox

## Troubleshooting

**"No messages found" but account is configured:**
- Account might be disabled in Mail.app (Mail → Settings → Accounts → check "Enable this account")
- Mail.app might not have synced yet - open Mail.app and wait for sync

**"MAIL_NOT_ACCESSIBLE" error:**
- Grant Automation permission: System Settings → Privacy & Security → Automation
- Allow Obsidian/Terminal to control Mail

**Gmail account shows nothing:**
- In Gmail web: Settings → See all settings → Forwarding and POP/IMAP → Enable IMAP
- If using 2FA: create an App Password at myaccount.google.com/apppasswords

**Search is slow:**
- AppleScript searches are slower than Gmail API - this is expected
- For large mailboxes, be patient or use more specific search terms

## Comparison with /gmail

| Feature | /mail (this) | /gmail |
|---------|--------------|--------|
| Providers | Any (iCloud, IMAP, Exchange, etc) | Gmail only |
| Auth | macOS Automation permission | OAuth browser flow |
| Search | Basic substring match | Full Gmail operators |
| Speed | Slower (AppleScript) | Faster (API) |
| Offline | Yes (reads local cache) | No |
| Workspace restrictions | None | May be blocked by admin |

Use `/mail` for non-Gmail accounts or when Gmail OAuth is blocked.
Use `/gmail` for Gmail accounts with full search capabilities.

## Search Tips

- `search` = fast (subject + sender only)
- `search-body` = slow (includes message body, limit results)
- Case-insensitive, substring matching only
- For large mailboxes, use smaller count limits

## Response Style

- Summarize email lists (sender, subject, date) - don't dump raw output
- For searches, highlight relevant results
- For long emails, summarize unless user asks for full content
- If multiple matches, list options and ask which one to read
