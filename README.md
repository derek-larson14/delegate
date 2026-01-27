# Feed the Beast

Text files and slash commands for running your life with Claude Code.

- `/daily` - What should I focus on today?
- `/weekly` - Review the week, plan what's next
- `/voice` - Process voice notes into tasks, ideas, file edits
- `/meeting` - Search meeting notes, extract action items
- `/network` - Who in my network can help with current projects?
- `/calendar` - Check your schedule, find open slots (Mac only)
- `/mail` - Read and search email from any provider (Mac only)
- `/drive` - Browse, search, and download from Google Drive
- `/editors` - Run parallel AI reviewers that use your reference library
- `/push` - Auto-commit and push changes

From ["Feed the Beast: AI eats software."](https://dtlarson.com/feed-the-beast) Learn more at [Delegate with Claude](https://delegatewithclaude.com).

## Setup

1. [Install Claude Code](https://claude.com/claude-code) ($20/month minimum)
2. Download this folder (green button → Download ZIP)
3. Unzip somewhere, rename, or move to where you prefer
4. Open terminal, navigate to folder: `cd path/to/folder`
5. Type `claude` and hit enter
6. Run `/daily` or ask a question to test it works

## Replace the Example Content

The folder has placeholder files:
- `tasks.md` - Your tasks
- `roadmap.md` - Your goals and deadlines
- `CLAUDE.md` - Context about your work
- `network.md` - Your network (optional)
- `voice.md` - Where voice notes land

## Using with Obsidian (Recommended)

1. [Download Obsidian](https://obsidian.md) (free)
2. Open this folder as a vault (File → Open folder as vault)
3. Trust plugins when prompted

The repo includes pre-configured plugins. See [Claude Sidebar](https://github.com/derek-larson14/obsidian-claude-sidebar) to run Claude from Obsidian.

## Customizing

- **Edit commands** - Modify `.claude/commands/*.md` to fit your workflow
- **Add commands** - Create new `.md` files in `.claude/commands/`
- **Update CLAUDE.md** - Add context about your work and file structure

## Updates

Run `/update` to pull the latest commands from GitHub.

---

By [Derek Larson](https://dtlarson.com). MIT License.
