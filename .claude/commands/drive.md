---
description: Access and manage Google Drive files using rclone
model: sonnet
allowed-tools: Bash, Read, Write
---

# Google Drive Assistant

Access Google Drive via rclone - browse, search, and download files.

## Setup (handle automatically, silently if already configured)

First, check if rclone + gdrive are ready:

```bash
rclone listremotes 2>/dev/null | grep -q "^gdrive:" && echo "READY"
```

**If output is "READY"**: Skip all setup messaging. Just proceed directly to what the user asked for. If they just said "/drive" without a specific request, ask: "What do you want to find in your Drive?"

**If not ready**, then handle setup:

1. Check if rclone is installed: `which rclone`
   - If not found, check if Homebrew exists: `which brew`
   - If brew exists → run `brew install rclone` yourself
   - If no brew → tell user: "rclone needs Homebrew. In Finder, open your workspace folder and double-click `SETUP.command` - it'll install Homebrew and the tools you need. Follow the prompts in the terminal window, then try `/drive` again."

2. Check if the setup script exists. If not, download it:
```bash
mkdir -p ./ops/scripts && curl -sL https://raw.githubusercontent.com/derek-larson14/feed-the-beast/main/ops/scripts/setup-drive.sh -o ./ops/scripts/setup-drive.sh && chmod +x ./ops/scripts/setup-drive.sh
```

3. Tell the user: "Google Drive isn't connected yet. I'll open your browser - just sign in and click Allow."

4. Run: `./ops/scripts/setup-drive.sh`

5. Once complete, proceed with the user's request.

If connection test fails on an existing config, tell user to run `rclone config reconnect gdrive:`.

## Browse & List

```bash
# List top-level folders
rclone lsd gdrive:

# List files in a folder
rclone ls gdrive:path/to/folder

# List with details (size, date)
rclone lsl gdrive:path/to/folder

# Limit depth when exploring
rclone lsd gdrive:Projects --max-depth 2
```

## Search

```bash
# Find files by name (anywhere in Drive)
rclone lsf gdrive: -R | grep -i "search term"

# Find specific file types
rclone lsf gdrive:Documents -R --include "*.pdf"

# Recently modified files (7d is just an example - use any duration: 1d, 2w, 1M, etc.)
rclone lsl gdrive: --min-age 0 --max-age 7d
```

## Download

```bash
# Download a file
rclone copy gdrive:path/to/file.pdf ./local/destination/

# Download a folder
rclone copy gdrive:FolderName ./local/destination/

# Show progress for large downloads
rclone copy gdrive:BigFolder ./local -P

# Only download certain file types
rclone copy gdrive:Documents ./local --include "*.pdf"
```

**Document conversion**: Google Docs download as .docx by default (rclone exports them since native .gdoc files are just pointers). Convert these to markdown unless the user explicitly requests the original format. Google Sheets should export as CSV.

```bash
# Google Docs → .docx → Markdown
rclone copy "gdrive:My Document.docx" /tmp/
pandoc /tmp/"My Document.docx" -o ./destination/my-document.md
rm /tmp/"My Document.docx"

# Google Sheets → CSV (must copy from folder with --include, not direct file path)
rclone copy gdrive:FolderName/ ./destination/ --include "My Spreadsheet*" --drive-export-formats csv
```

**Shared files**: "Shared with me" isn't browsable as a folder, but you can search and download shared files using the `--drive-shared-with-me` flag:

```bash
# Search shared files
rclone lsf --drive-shared-with-me gdrive: | grep -i "search term"

# Download a shared file
rclone copy --drive-shared-with-me "gdrive:Shared Document.docx" ./destination/
```

**Google Slides**: Export as .pptx by default. Convert with pandoc if needed, or leave as-is for presentations.

## Common Patterns

**"What's in my Drive?"**
```bash
rclone lsd gdrive: --max-depth 1
```

**"Find all PDFs in Documents"**
```bash
rclone lsf gdrive:Documents -R --include "*.pdf"
```

**"Download my tax folder"**
```bash
rclone copy gdrive:Taxes/2024 ./downloads/taxes-2024 -P
```

## Path Handling

- Paths are case-sensitive
- Spaces work: `gdrive:My Folder/subfolder`
- Use quotes for special chars: `rclone ls "gdrive:Folder (2024)"`
- Root of Drive is just `gdrive:`

## Multiple Accounts (Optional)

If the user wants to add another Google Drive account:

1. Ask what they want to name it (e.g., "work", "personal", "company")
2. Run the command to add it - this opens the browser automatically:

```bash
rclone config create <name> drive scope drive.readonly
```

3. Tell them: "I'll open your browser - choose the Google account you want to add and allow access."
4. Once done, confirm it worked by listing the new drive.

When the user mentions a specific account (e.g., "work drive", "personal drive"), use the appropriate remote. If unclear which account, ask.

## Upgrading to Full Access

By default, setup grants read-only access (browse, search, download).

If the user wants to upload, edit, or delete files in Drive, tell them:

"Right now I can only read your Drive - browse, search, download. If you want me to upload, edit, or delete files, I can upgrade your access. Just say the word."

If they want to upgrade, run:

```bash
rclone config delete gdrive && ./ops/scripts/setup-drive.sh --full
```

This will open the browser again for re-auth with write permissions.

After upgrade, these commands become available:

```bash
# Upload a file
rclone copy ./local/file.md gdrive:path/to/destination/

# Upload a folder
rclone copy ./local/folder gdrive:DestinationFolder/
```

## Multiple Matches

When a search returns multiple similar files, list them with paths and ask the user to specify which one:

```
Found 3 files matching "draft":
1. Project Proposal [DRAFT].docx (root)
2. Budget Draft.xlsx (Finance/)
3. old/First Draft.docx

Which one do you want?
```

Don't guess - always confirm when ambiguous.

## Response Style

- Be concise - summarize what you find rather than dumping raw output
- For large listings, give counts and highlight what seems relevant
- When downloading, confirm where files landed
- If a path doesn't exist, suggest alternatives based on what you can see
- Don't narrate for the sake of narrating - only when it's useful
