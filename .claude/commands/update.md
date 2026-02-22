---
description: Pull latest commands and scripts from GitHub
model: sonnet
allowed-tools: Bash, Read
---

# Update Commands

Download the latest commands and scripts from the delegate repo.

## Steps

### 0. Detect OS

```bash
uname -s 2>/dev/null || echo "Windows"
```

If the output contains "MINGW", "CYGWIN", "MSYS", or "Windows", this is a **Windows** environment. Use PowerShell (.ps1) scripts and `$env:TEMP` paths throughout. Otherwise, use bash (.sh) scripts and `/tmp/` paths (existing behavior).

### 1. Run the update checker

**macOS/Linux:**

If `ops/scripts/check-updates.sh` exists, run it:
```bash
ops/scripts/check-updates.sh
```

If it doesn't exist, bootstrap it first:
```bash
mkdir -p ops/scripts && curl -sL https://raw.githubusercontent.com/derek-larson14/delegate/main/ops/scripts/check-updates.sh -o ops/scripts/check-updates.sh && chmod +x ops/scripts/check-updates.sh && ops/scripts/check-updates.sh
```

**Windows:**

If `ops/scripts/check-updates.ps1` exists, run it:
```bash
powershell.exe -ExecutionPolicy Bypass -File ops/scripts/check-updates.ps1
```

If it doesn't exist, bootstrap it first:
```bash
powershell.exe -ExecutionPolicy Bypass -Command "New-Item -ItemType Directory -Path ops/scripts -Force | Out-Null; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/derek-larson14/delegate/main/ops/scripts/check-updates.ps1' -OutFile 'ops/scripts/check-updates.ps1' -UseBasicParsing; & './ops/scripts/check-updates.ps1'"
```

If the script says "Everything is up to date" — you're done, skip to cleanup.

If no CHANGED/NEW/LOCAL ONLY items appear, everything is up to date - skip to cleanup.

**LOCAL ONLY** items exist locally but not upstream - either custom local files or deleted from repo. Mention these in the summary.

### 2. Review command changes

**For CHANGED files**: Show the diff to understand what changed.

macOS/Linux:
```bash
diff -u ".claude/commands/<name>" "/tmp/delegate-update/delegate-main/.claude/commands/<name>"
```

Windows — use the extracted path under `$env:TEMP`:
```bash
powershell.exe -Command "Compare-Object (Get-Content '.claude/commands/<name>') (Get-Content (Join-Path $env:TEMP 'delegate-update/delegate-main/.claude/commands/<name>'))"
```

Describe what's different in meaningful terms - not "line 45 changed" but "added a section on troubleshooting calendar permissions" or "updated the search syntax examples." Then copy the file:

macOS/Linux:
```bash
cp /tmp/delegate-update/delegate-main/.claude/commands/<name> .claude/commands/<name>
```

Windows:
```bash
powershell.exe -Command "Copy-Item (Join-Path $env:TEMP 'delegate-update/delegate-main/.claude/commands/<name>') '.claude/commands/<name>' -Force"
```

**For NEW files**: Read the new command file, explain what it does in plain terms (e.g., "/drive lets you browse and download files from Google Drive"), then copy it.

### 3. Review setup files

If SETUP.command (or SETUP.ps1 on Windows) shows as NEW or CHANGED:

macOS/Linux:
```bash
cp /tmp/delegate-update/delegate-main/SETUP.command ./SETUP.command
chmod +x SETUP.command
```

Windows:
```bash
powershell.exe -Command "Copy-Item (Join-Path $env:TEMP 'delegate-update/delegate-main/SETUP.ps1') './SETUP.ps1' -Force"
```

Explain: "Added SETUP.command - double-click it in Finder to install Homebrew and tools for calendar, mail, and messaging commands." (On Windows: "Updated SETUP.ps1 - right-click and Run with PowerShell to install rclone and jq.")

### 4. Review script changes

For CHANGED scripts, show the diff:

macOS/Linux:
```bash
diff -u "ops/scripts/<name>.sh" "/tmp/delegate-update/delegate-main/ops/scripts/<name>.sh"
```

Windows:
```bash
powershell.exe -Command "Compare-Object (Get-Content 'ops/scripts/<name>') (Get-Content (Join-Path $env:TEMP 'delegate-update/delegate-main/ops/scripts/<name>'))"
```

Then copy:

macOS/Linux:
```bash
mkdir -p ops/scripts
cp /tmp/delegate-update/delegate-main/ops/scripts/<name>.sh ops/scripts/
chmod +x ops/scripts/<name>.sh
```

Windows:
```bash
powershell.exe -Command "New-Item -ItemType Directory -Path ops/scripts -Force | Out-Null; Copy-Item (Join-Path $env:TEMP 'delegate-update/delegate-main/ops/scripts/<name>') 'ops/scripts/<name>' -Force"
```

For NEW scripts, describe what the script does, then copy it.

### 5. Update manifest

Copy the remote manifest to update local version tracking:

macOS/Linux:
```bash
cp /tmp/delegate-update/delegate-main/manifest.json ./manifest.json
```

Windows:
```bash
powershell.exe -Command "Copy-Item (Join-Path $env:TEMP 'delegate-update/delegate-main/manifest.json') './manifest.json' -Force"
```

### 6. Cleanup

macOS/Linux:
```bash
rm -rf /tmp/delegate-update /tmp/delegate-update.zip
```

Windows:
```bash
powershell.exe -Command "Remove-Item (Join-Path $env:TEMP 'delegate-update'),(Join-Path $env:TEMP 'delegate-update.zip') -Recurse -Force -ErrorAction SilentlyContinue"
```

### 7. Summary

End with a meaningful summary:
- Previous version → new version (from manifest.json)
- What new commands were added and what they do
- What changed in existing commands (the actual improvements, not just file names)
- "Scripts updated" if applicable

Keep it useful, not just a list of filenames.

## Notes

- Skip `update.md` itself (the script already does this)
- Always use `cp` to copy files - never use Write tool (risks writing stale/cached content)
- Describe changes in terms of what's useful to the user, not technical diff output
