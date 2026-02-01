---
description: Process voice notes from voice.md and execute actions
---

# Voice Notes Processor

Read voice notes from `/voice.md` and process them.

## Processing Flow

1. **Read voice.md** - If the file doesn't exist or is empty, let the user know.

2. **Parse entries** - Entries are separated by `--` and may start with a timestamp. Text is dictated, so interpret intent rather than literal words.

3. **Classify each entry** as one of:
   - **Task**: Add to `tasks.md`
   - **File edit**: Make changes to a specific file
   - **Idea**: A thought that belongs somewhere - route to the right project folder/file
   - **Ambiguous**: Not clear what action to take

4. **Execute actions**:
   - For tasks: Add to the appropriate section in `tasks.md`
   - For file edits: Make the requested changes
   - For ideas: Find the proper place to route them
   - For ambiguous: Ask for clarification before acting
   - Preserve the user's voice while cleaning up grammar/spelling
   - If something is confusing, check other files for context before routing

5. **Archive processed entries**:
   - Append processed entries to `archive/voice-archive.md` with processing timestamp and note about where you routed them
   - Clear `voice.md` after processing

6. **Report what was done**:
   - List each entry and what action was taken
   - Ask clarifying questions for anything ambiguous

## File Structure

Scan your workspace before routing. Common patterns:
- `tasks.md` - active tasks
- `maybe.md` - future ideas, someday projects
- Project folders - route to relevant project files

When unclear where something goes, check folder names and existing files first.

## Important
- **Capture EVERYTHING coherent** - A single voice note often contains multiple distinct ideas. Don't just grab the main point - extract every sub-idea, detail, and nuance.
- One entry may need to be split across multiple files (e.g., a task + an idea + a project note)
- When in doubt, add it somewhere rather than skip it
- Transcription errors are common - interpret intent, not literal words
- If an entry is just noise/testing, archive without action
