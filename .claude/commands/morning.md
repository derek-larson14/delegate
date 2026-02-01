---
description: Morning brief - what matters today
allowed-tools: Bash, Read, Glob, Grep
---

# Morning

Prepare a morning brief. Be direct and concise.

## Check What's Available

```bash
# Calendar (Mac)
which icalBuddy >/dev/null 2>&1 && echo "CALENDAR_OK" || echo "NO_CALENDAR"

# Mail (Mac)
[ -x ./ops/scripts/mail-cli.sh ] && echo "MAIL_OK" || echo "NO_MAIL"
```

## Gather Context

**Always read:**
- `tasks.md` - what's active, what's next
- `roadmap.md` - upcoming deadlines

**If calendar available:**
```bash
icalBuddy -f -eep notes -nc eventsToday 2>/dev/null
```

**If mail available:**
```bash
./ops/scripts/mail-cli.sh list 20 2>/dev/null
```
Focus on: flagged/urgent emails, emails from people mentioned in tasks.

**Recent activity:**
- Check `logs/` for recent reviews
- Git log for what changed recently

## What to Surface

1. **State of things** - What got done, what's in motion, patterns worth noting

2. **Today's focus** - One or two things that matter most. Not a task list - the priority.

3. **Blockers** - Anything stuck, anything being avoided, decisions needed

4. **People** - Who to reach out to, follow up with, or prepare for (from calendar)

## Style

- Brutally honest, not cheerful
- Surface what might be missing or avoided
- If something should be cut or delegated, say so
- Have a point of view, don't just summarize