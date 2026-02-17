---
description: Multi-perspective feedback on writing (parallel execution)
allowed-tools:
  - Read, Grep, Glob
  - TodoWrite
---

I'm working on a piece of writing and want feedback from multiple perspectives.

First, scan these folders and identify all relevant context files:
- `/reference/editors/` - writing craft resources
- `/reference/advice/` - strategic and psychological frameworks
- Root of `/reference/` for anything else useful

For each context file, spin up a general-purpose subagent that reads:
1. The context file
2. My target file

USE OPUS FOR ALL SUBAGENTS

Each agent should create specific recommendations for improving the piece based on their context lens. Quote actual lines when possible.

Launch all agents in parallel.

After all agents return:
1. Pull out the most interesting ideas across the different agents, especially things that feel like they capture my energy
2. synthesize patterns across all feedback. Where do multiple perspectives converge? Where do they conflict?
3. What are the highest-leverage changes?
