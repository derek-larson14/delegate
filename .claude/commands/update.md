---
description: Pull latest commands and scripts from GitHub
model: sonnet
allowed-tools: Bash, Read
---

# Update Commands

Download the latest commands and scripts from feed-the-beast.

## Steps

### 1. Run the update checker

If `ops/scripts/ftb-check-updates.sh` exists, run it:
```bash
ops/scripts/ftb-check-updates.sh
```

If it doesn't exist, bootstrap it first:
```bash
mkdir -p ops/scripts && curl -sL https://raw.githubusercontent.com/derek-larson14/feed-the-beast/main/ops/scripts/ftb-check-updates.sh -o ops/scripts/ftb-check-updates.sh && chmod +x ops/scripts/ftb-check-updates.sh && ops/scripts/ftb-check-updates.sh
```

If no CHANGED/NEW/LOCAL ONLY items appear, everything is up to date - skip to cleanup.

**LOCAL ONLY** items exist locally but not upstream - either custom local files or deleted from repo. Mention these in the summary.

### 2. Review command changes

**For CHANGED files**: Show the diff to understand what changed:
```bash
diff -u ".claude/commands/<name>" "/tmp/ftb-update/feed-the-beast-main/.claude/commands/<name>"
```

Describe what's different in meaningful terms - not "line 45 changed" but "added a section on troubleshooting calendar permissions" or "updated the search syntax examples." Then copy the file:
```bash
cp /tmp/ftb-update/feed-the-beast-main/.claude/commands/<name> .claude/commands/<name>
```

**For NEW files**: Read the new command file, explain what it does in plain terms (e.g., "/drive lets you browse and download files from Google Drive"), then copy it.

### 3. Review script changes

For CHANGED scripts, show the diff:
```bash
diff -u "ops/scripts/<name>.sh" "/tmp/ftb-update/feed-the-beast-main/ops/scripts/<name>.sh"
```

Describe what changed, then copy:
```bash
mkdir -p ops/scripts
cp /tmp/ftb-update/feed-the-beast-main/ops/scripts/<name>.sh ops/scripts/
chmod +x ops/scripts/<name>.sh
```

For NEW scripts, describe what the script does, then copy it.

### 4. Cleanup

```bash
rm -rf /tmp/ftb-update /tmp/ftb-update.zip
```

### 5. Summary

End with a meaningful summary:
- What new commands were added and what they do
- What changed in existing commands (the actual improvements, not just file names)
- "Scripts updated" if applicable

Keep it useful, not just a list of filenames.

## Notes

- Skip `update.md` itself (the script already does this)
- Always use `cp` to copy files - never use Write tool (risks writing stale/cached content)
- Describe changes in terms of what's useful to the user, not technical diff output
