---
description: Process delegation.md — review Claude's task queue, propose actions, execute with confirmation
model: opus
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, AskUserQuestion
---

## Understand the landscape

Read `delegation.md` (Claude's task queue — the primary input). Then read `tasks.md` and `roadmap.md` to understand what the user is focused on. Look at git diff and recent commits to see the arc of recent progress. Scan linked files or project folders if tasks reference them. Process items top to bottom. Finish all context-gathering before doing anything.

If `delegation.md` is empty, say so.

## Do the work

**Use subagents for independent tasks.** If three things don't depend on each other, run them in parallel.

For each task, figure out who should handle it:

**You handle:** Research, code, file organization, data analysis, setup, prototyping, summarization, exploration. If a task references a repo or codebase, go read it. Do the actual work — don't leave "figure out X" or "you should look into Y" as output. If a task says research something, come back with the answer, not a plan to find the answer.

**Leave for the user:** Decisions, relationship messages, outreach, pricing, strategy, writing first drafts — anything that needs their voice or judgment. Add context that makes it easier for them to act, but don't create busywork.

When a task mixes both (research + decision, for example), complete the research and frame the decision clearly.

**Completing tasks:** Mark finished items in delegation.md with `- [x] task — what was done, where output lives`. The task-archiver plugin watches this file and auto-archives checked items to `archive/claude-completed.md` with date headers.

**Working notes:** If a task generates thinking worth keeping, put it in `scratch/YYYY-MM/[slug].md` (current month). These are notes and connections — not polished documents nobody asked for. Avoid creating documentation for the sake of documentation.

**When something could go bigger:** Some tasks, once you dig in, reveal something worth real investment. Flag these — "This one seems close to ready, want me to go deeper?" — but don't assume the answer is yes.

## Quality bar

For every item you surface: would a good assistant mention this, or would your most valuable employee just take this direction on, or is it noise? Act accordingly.

## Report

```
## Completed
- [x] [task] — [what was done]

## Needs You
- [ ] [task] — [context added, ready for your call]

## Connections Noticed
- [Ideas that relate across files]
- [Things already partially implemented]
- [Patterns worth consolidating]

## Questions
- [Anything that came up during execution]
```

The goal: you glance at this and know exactly what needs your attention.

## Guardrails

Never send messages on behalf of the user. Never commit without review. Never delete files.

Push back on anything incoherent. If something doesn't make sense, say so.

**YOLO mode:** If the user says "YOLO" or "just do it," skip confirmation and execute everything autonomously. Report results at the end.
