---
description: Process delegation.md — review Claude's task queue, propose actions, execute with confirmation
model: sonnet
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, AskUserQuestion
---

# Delegation Queue Processor

This command is how you and Claude build a working relationship. It's not a one-off task runner — it's a regular rhythm where Claude reviews what's on the plate, proposes what to take on, and gets to work.

## Phase 1: Understand the Landscape

Read `delegation.md` (Claude's task queue — the primary input). Then read `tasks.md` and `roadmap.md` for context on what the user is focused on. Scan linked files or project folders if tasks reference them. Process items from top to bottom. Finish all context-gathering before proposing anything.

If `delegation.md` is empty or doesn't exist, let the user know and suggest they add tasks.

## Phase 2: Propose a Plan

For each task in the queue, classify it:

**Claude should handle:** Research, code/scripts, file organization, data analysis, setup, prototyping, list generation, summarization, refactoring, exploration.

**User should handle:** Decisions, relationship messages, outreach, pricing, strategy, writing first drafts, anything that requires their judgment or voice.

Present a clear plan using AskUserQuestion:

```
Here's what I found in your delegation queue:

## I'll take these on:
- [task] — [what I plan to do]
- [task] — [what I plan to do]

## These need you:
- [task] — [why: needs your decision / voice / judgment]

## Questions before I start:
- [anything ambiguous]

Should I proceed? (Or tell me to adjust.)
```

Wait for confirmation before executing. Don't assume — get the go-ahead.

**YOLO mode:** If the user says "YOLO" or "just do it," skip confirmation and execute everything Claude can handle autonomously. Report results at the end instead of asking permission upfront.

## Phase 3: Execute

Work through confirmed tasks. For each one:
- Do the actual work (don't leave "figure out X" as output — do the figuring)
- Mark completed items in delegation.md: `- [x] task description — what was done`
- If a task mixes research + decision, complete the research and frame the decision clearly for the user

For tasks that need the user: add context that helps them act, but don't create busywork.

## Phase 4: Report

```
## Completed
- [x] [task] — [what was done, where output lives]

## Needs You
- [ ] [task] — [context added, ready for your call]

## Questions
- [Anything that came up during execution]
```

## Guardrails

- Never send messages on behalf of the user
- Never delete files without asking
- Never commit/push without review
- If something doesn't make sense, say so — don't just execute blindly
- When in doubt, ask
