---
description: Process voice notes from voice.md and execute actions
model: sonnet
allowed-tools: Read, Edit, Glob, Grep, Write, AskUserQuestion
---

# Voice Notes Processor

Read voice notes from `/voice.md` and route them to the right places.

## Processing Flow

### 1. Build context first

Before routing anything, understand the workspace:
- `tasks.md` — current tasks
- `delegation.md` — Claude's task queue
- `roadmap.md` — current priorities
- Scan project folders for existing files to route to

The more context you have, the better you route.

### 2. Read voice.md

If empty or only whitespace, stop. Nothing to do.

If there's a `## Needs context` section at the top, those entries are waiting for clarification. If you can ask the user (AskUserQuestion is available), handle them. If you can't ask (running headless), skip them.

### 3. Parse entries

Entries are separated by `## Vault -`, `## Memo -`, or `## Dispatch -` headers (from transcription scripts), or `--` separators. A single entry often contains multiple distinct ideas — extract them all. Text is dictated — interpret intent, not literal words.

### 4. Classify and route each idea

**User's task** (decisions, outreach, messaging, strategy, writing first drafts) → `tasks.md`

**Claude's task** (research, code, data analysis, file organization, building) → `delegation.md` under Queue

**Idea for a project** → Append to the right file in a project folder

**Ambiguous** → If you can ask the user, ask. Otherwise leave in voice.md under a `## Needs context` section.

### 5. Archive routed entries

Append successfully routed entries (verbatim) to `archive/voice-archive.md` with:
- Processing timestamp
- Where each idea was routed

### 6. Rewrite voice.md

- If there are unclear entries, keep only the `## Needs context` section
- If everything was routed, empty the file

### 7. Report what was done

List each entry and what action was taken. Flag anything that needs follow-up.

## Constraints

- **Preserve voice** — Clean up transcription errors but keep the user's words. No AI summaries.
- **Append-only** — Only append to existing files. Don't modify existing content.
- **No new files** — Route to existing files only.
- **Capture everything** — Extract every sub-idea from each entry.
- **Go deep before routing** — Read more files if you're unsure where something goes.
