# Feed the Beast

Text files and slash commands for running operations with AI.

- `/daily` - What should I focus on today?
- `/weekly` - Review the week, plan what's next
- `/voice` - Process voice notes into tasks, ideas, file edits
- `/meeting` - Search meeting notes, extract action items
- `/network` - Who in my network can help with current projects?
- `/outreach` - Draft outreach messages
- `/editors` - Run parallel AI reviewers that use your reference library
- `/push` - Auto-commit and push changes

From ["Feed the Beast: AI eats software"](https://dtlarson.com/feed-the-beast). Learn more at [Delegate with Claude](https://delegatewithclaude.com).

## Setup

1. [Install Claude Code](https://claude.com/claude-code) ($20/month minimum)
2. Download this folder (green button → Download ZIP)
3. Unzip somewhere, rename to `operations` (or whatever you'd like)
4. Open terminal, navigate to folder: `cd path/to/folder`
5. Type `claude` and hit enter
6. Run `/daily` or ask a question to test it works

## Replace the Example Content

The folder has placeholder files:
- `tasks.md` - Your tasks
- `roadmap.md` - Your goals and deadlines
- `CLAUDE.md` - Context about your work
- `outreach.md` - People you're reaching out to
- `network.md` - Your network (optional)
- `voice.md` - Where voice notes land (see below)

## Voice Notes

You can dictate your thoughts into `voice.md` before they disappear, without worrying about where to put them in your documents. 

Then, run `/voice` later and Claude routes the ideas into the right files.

I use [Wispr Flow](https://wisprflow.ai/) on desktop and Apple's dictation feature on iOS, but any dictation tool works. 

## Meeting Notes

Sync your meeting notes to the `meetings/` folder and search them with `/meeting`.

**With Granola (recommended):**
1. In Obsidian: Settings → Community Plugins → Browse → "Granola Sync"
2. Install and enable
3. Set folder path to `meetings/`
4. Your Granola notes sync automatically

**Manual:** Drop any meeting notes as markdown files in `meetings/`. Name them descriptively (e.g., `2024-12-10-sarah-roadmap.md`).

Then ask:
```
/meeting what were the action items from my call with Sarah?
```

## Network Search

Add people to `network.md`:
```markdown
## Jane Smith
VP Engineering @ TechStartup Inc
jane@techstartup.com
Notes: Building AI dev tools, looking for design talent
```

Run `/network` to find who can help with current projects.

## Using with Obsidian (Recommended)

The repo includes pre-configured Obsidian plugins for a better experience:

**Pre-loaded plugins:**
- **Terminal Launcher** - Quick launch terminal in your vault folder
- **Show .claude Folder** - Makes `.claude/` visible in Obsidian's file explorer
- **Task Archiver** - Automatically archive completed tasks

**Setup:**
1. [Download Obsidian](https://obsidian.md) (free)
2. Open this folder as a vault in Obsidian (File → Open folder as vault)
3. When prompted about community plugins, click "Trust author and enable plugins"
4. The plugins are now active - you can launch terminal, see .claude folder, and use task archiving

The `.obsidian/` folder contains only the plugin files and the community-plugins list. Everything else (themes, hotkeys, layouts) uses Obsidian defaults so you can customize however you want.

**Or use Cursor** - AI code editor that plays nice with Claude Code

## Customizing

1. **Change Commands** - Edit commands to ask what matters to you
2. **Add commands** - Create new `.md` files in `.claude/commands/`
3. **Adjust paths** - Update file references if you organize differently
4. **Update `CLAUDE.md`** - include context about file structure, and your work


## File Structure

```
feed-the-beast/
├── .claude/commands/      # Slash commands
├── .obsidian/            # Pre-configured Obsidian plugins
│   ├── plugins/          # Plugin files (terminal, .claude visibility, task archiving)
│   └── community-plugins.json
├── meetings/             # Meeting notes (Granola sync or manual)
├── tasks.md               # Your tasks
├── roadmap.md            # Goals and deadlines
├── outreach.md           # Outreach tracking
├── network.md            # Your network (optional)
├── voice.md              # Voice notes inbox
├── CLAUDE.md             # Context for Claude
└── logs/                 # Review logs
```

## For Developers

- **MCP Integration**: Hook up calendar, Slack, email, Notion, etc. See [MCP docs](https://docs.claude.com/en/docs/claude-code/mcp).
- **Automate**: [Schedule commands](https://docs.anthropic.com/en/docs/claude-code/github-actions), chain workflows, pull from APIs
- **Extend**: This is just text files and prompts. Build whatever you need.

---

By Derek Larson. From ["Feed the Beast: AI eats software"](https://dtlarson.com/feed-the-beast).

MIT License.
