---
description: Multi-perspective feedback on writing using reference library
---

I'm working on a piece of writing and want feedback from multiple angles.

First, scan `/reference/` and read the file names. Based on what I'm working on, decide which ones are relevant. When in doubt, include it - better to have more perspectives than miss something useful.

Spin up a subagent for each relevant reference file. Each one reads their reference file, then reviews my target file. Ask each: what works, what sucks, what's missing, what should be explored further.

If there's a STYLE.md or CLAUDE.md in the project folder, that gets its own dedicated subagent - don't mix it with the others.

After all agents return: read through their responses, where do they agree, where do they disagree? If everyone thinks something sucks or is great, that's a signal. The tensions are interesting too - if the storytelling agent loves a section but the copywriting agent hates it, that's worth exploring.

When possible, quote specific lines, vs generalizing.
