---
description: Process voice notes from voice.md and execute actions
---

# Voice Notes Processor

Read `/voice.md` and process any new voice entries.

## Processing Flow

1. **Parse entries** - Each entry is separated by `--` and starts with a timestamp

2. **Classify each entry** as one of:
   - **Task**: Add to `tasks.md` (keywords: "add task", "todo", "remind me to", "I need to")
   - **File edit**: Make changes to a specific file (keywords: "update", "change", "edit", "add to [filename]")
   - **Question**: Something to answer or research
   - **Note**: Just capturing a thought, no action needed
   - **Ambiguous**: Not clear what action to take

3. **Execute actions**:
   - For tasks: Add to the appropriate section in `tasks.md`
   - For file edits: Make the requested changes
   - For questions: Provide an answer or note what research is needed
   - For notes: Just acknowledge
   - For ambiguous: Ask for clarification before acting
   - Preserve the user's voice while cleaning up grammar/spelling (text is dictated)
   - If something is confusing, check other files for context before routing

4. **Archive processed entries**:
   - Append processed entries to `archive/voice-archive.md` with processing timestamp
   - Clear `voice.md` after processing

5. **Report what was done**:
   - List each entry and what action was taken
   - Ask clarifying questions for anything ambiguous

## File Structure

Scan your workspace before routing. Common patterns:
- `tasks.md` - active tasks
- `maybe.md` - future ideas, someday projects
- Project folders - route to relevant project files

When unclear where something goes, check folder names and existing files first.

## Important
- Be conservative - when in doubt, ask
- Transcription errors are common - interpret intent, not literal words
- If an entry is just noise/testing, archive without action
