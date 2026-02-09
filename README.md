# Feed the Beast

Text files and slash commands for running your life with Claude Code.

- `/morning` - What to focus on today
- `/weekly` - Review the week, plan what's next
- `/voice` - Process voice notes into tasks, ideas, file edits
- `/setup-transcription` - Set up voice transcription (Mac only)
- `/meeting` - Ask questions about your meeting notes
- `/messages` - Search messages across WhatsApp, iMessage, Slack, etc.
- `/calendar` - Check schedule, find open time (Mac only)
- `/mail` - Read and search email (Mac only)
- `/drive` - Browse, search, download from Google Drive
- `/editors` - Multiple AI reviewers critique your writing in parallel
- `/delegate` - Hand off tasks to Claude
- `/push` - Auto-commit and push changes

From ["Feed the Beast: AI eats software."](https://dtlarson.com/feed-the-beast) Learn more at [Delegate with Claude](https://delegatewithclaude.com).

## Setup

1. [Install Claude Code](https://claude.com/claude-code) ($20/month minimum)
2. Download this folder (green button → Download ZIP)
3. Unzip somewhere, rename, or move to where you prefer
4. **Mac users:** Double-click `SETUP.command` to install tools for calendar, mail, and messages. Follow the prompts.
5. Open terminal, navigate to folder: `cd path/to/folder`
6. Type `claude` and hit enter
7. Run `/morning` or ask a question to test it works

## Replace the Example Content

The folder has placeholder files:
- `tasks.md` - Your tasks
- `roadmap.md` - Your goals and deadlines
- `CLAUDE.md` - Context about your work
- `voice.md` - Where voice notes land

## Using with Obsidian (Recommended)

Obsidian pairs well with Claude Code because they both work on local files.

1. [Download Obsidian](https://obsidian.md) (free)
2. Open this folder as a vault (File → Open folder as vault)
3. Trust plugins when prompted

Your workspace comes pre-configured with plugins. Install [Claude Sidebar](https://github.com/derek-larson14/obsidian-claude-sidebar) to run Claude directly from Obsidian.

## Platform Notes

Most commands work on Mac, Windows, and Linux. A few are Mac-only:
- `/calendar` - Uses Mac Calendar app
- `/mail` - Uses Mac Mail app
- `/setup-transcription` - Uses Apple Speech Recognition

Windows/Linux: Connect these via [Rube](https://rube.sh) instead.

## Customizing

- **Edit commands** - Modify `.claude/commands/*.md` to fit your workflow
- **Add commands** - Create new `.md` files in `.claude/commands/`
- **Update CLAUDE.md** - Add context about your work and file structure

## Updates

Run `/update` to pull the latest commands from GitHub.

---

By [Derek Larson](https://dtlarson.com). MIT License.
