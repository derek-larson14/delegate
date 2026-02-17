---
description: Process delegation.md — autonomously handle Claude's task queue
model: opus
allowed-tools: Read, Grep, Glob, Edit, Write, AskUserQuestion, WebFetch, WebSearch
---

## Phase 1: Research (complete before acting)

Read `delegation.md` (primary input — Claude's task queue), then `tasks.md`, `roadmap.md`, recent file changes (look at git diff + recent commits to understand the arc of progress and how you can augment / accelerate / pick up slack), and linked files to understand current state. Process items in delegation.md from top to bottom. Finish all context-gathering before categorizing. Don't leave "figure out X" as an output—do the figuring.

If `delegation.md` is empty, say so.

## Phase 2: Categorize and Execute

**Use subagents aggressively.** Independent tasks should run in parallel. Spin up subagents for research, code exploration, data analysis — anything that doesn't depend on another task's output. The goal is throughput: chew through the queue fast.

For each task, separate interleaved concerns. A task mixing research + decision + relationship should become: completed research, clearly framed decision for the user.

**Do autonomously:** Research, code/scripts, file organization, data analysis, setup, prototyping, list generation. Execute, then mark complete in delegation.md using checkbox format (`- [x] task description — what was done, where output lives`). The task-archiver plugin watches delegation.md and auto-archives checked items to `archive/claude-completed.md` with date headers. Avoid creating documentation for the sake of documentation while balancing that with providing context about what changed.

**Expand and connect:** For idea files, cross-reference with what exists — look at implemented content, existing commands, repo structure. Connect scattered ideas. Note what's close to done. Don't produce prose; document what you notice.

**Surface what's actionable:** When something feels ready or nearly complete, ask: "This one seems close — want me to dig in?" Don't assume. Get permission before going deep.

**Working notes:** If a task generates thinking worth keeping, put it in `scratch/YYYY-MM/DD-[slug].md` (current month and day). These are notes and connections, not polished prose.

**Leave for the user:** Decisions, relationship DMs, pricing, strategy, anything voice-dependent. Add context that helps but don't create work.

**Use AskUserQuestion aggressively** — don't defer decisions to the structured output. When you hit a fork (unclear priority, multiple approaches, needs a call), use AskUserQuestion right then. This prevents the output from becoming a wall of deferred questions. Better to interrupt once than to produce an output that has to be re-read three times.

**Link relevant files** — when referencing research, scratch notes, or project files in delegation.md or the output, use Obsidian wiki-link format: `[[filename]]`. This lets the user click through in Obsidian instead of hunting for paths.

Group related tasks that build on each other rather than treating each atomically.

## Phase 3: Structured Output

```
## Open Questions (for you)
- [Ambiguous tasks or judgment calls needed before proceeding]

## Completed
- [x] [task] — [one-line what was done]

## Ready to Dig In (asking permission)
- [ ] [idea/task] — [why it seems close, what I'd do next]

## Blocked / Needs You
- [ ] [task] — [why, with context added]

## Connections Noticed
- [Ideas that relate across files]
- [Things already partially implemented]
- [Patterns worth consolidating]
- [Repeated mentions across voice notes/tasks = importance signal]

## Flagged
- [Tasks sitting 2+ weeks]
- [Recurring patterns worth automating]
```

## Guardrails

Never send anything on behalf of the user. Never commit without review. Never delete files. Preserve original task wording when archiving.

Push back on anything incoherent. If something doesn't make sense, say so.

## Quality Bar

For every item you surface: would a good assistant mention this, or is this a direction your most valuable employee would just take?

## Success Criteria

You glance at the output and know exactly what needs your attention without re-reading everything.
