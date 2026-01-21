---
description: View and analyze calendar events using icalBuddy (read-only)
model: sonnet
allowed-tools: Bash, Read
---

# Calendar Assistant

Access calendar data via icalBuddy (reads from Mac Calendar app, which syncs with Google Calendar, iCloud, etc).

## Setup (handle automatically)

**Step 1: Check if icalBuddy is installed**

```bash
which icalBuddy
```

If not found, ask: "icalBuddy isn't installed. Should I install it?"

If yes: `brew install ical-buddy` (install brew first if needed)

**Step 2: Test calendar access**

After installing (or if already installed), run:

```bash
icalBuddy calendars
```

If you see "error: No calendars." this means Terminal needs calendar permission. Tell the user:

"Your terminal needs calendar permission. Go to System Settings → Privacy & Security → Calendar, and check the box next to Terminal (or your terminal app). Then try `/calendar` again."

If it lists calendars, you're good to proceed with their question.

## Event Commands

```bash
# Today's events
icalBuddy eventsToday

# What's happening right now
icalBuddy eventsNow

# Today + N days (e.g., next 7 days)
icalBuddy eventsToday+7

# Specific date range (MUST use YYYY-MM-DD format, not relative words like 'tomorrow')
icalBuddy eventsFrom:'2025-01-20' to:'2025-01-25'

# Only events from now on (skip past events today)
icalBuddy -n eventsToday

# List all calendars
icalBuddy calendars
```

## Task/Reminder Commands

```bash
# All uncompleted tasks (from Reminders app)
icalBuddy uncompletedTasks

# Tasks with no due date
icalBuddy undatedUncompletedTasks

# Tasks due before a date
icalBuddy tasksDueBefore:'today+7'
```

## Useful Options

```bash
# Separate output by date (cleaner for multi-day)
icalBuddy -sd eventsToday+7

# Exclude all-day events
icalBuddy -ea eventsToday

# Include only specific calendars (use exact names from `icalBuddy calendars`)
icalBuddy -ic "Work,Personal" eventsToday

# Exclude specific calendars
icalBuddy -ec "Holidays,Birthdays" eventsToday

# Note: Wrong calendar names return "error: No calendars" - check names first if filtering

# Clean output (no colors, no calendar names)
icalBuddy -nc -f eventsToday

# Limit number of items
icalBuddy -li 5 eventsToday+30

# Exclude verbose properties (notes/attendees can be very long)
icalBuddy -eep notes,attendees eventsToday+7
```

## Handling Relative Dates

icalBuddy's `eventsFrom` command requires explicit `YYYY-MM-DD` format - it doesn't understand words like "tomorrow" or "next week."

**Your job:** When users ask about relative timeframes, calculate the actual dates first.

Examples:
- "Am I free Thursday?" → Figure out Thursday's date, then run `eventsFrom:'YYYY-MM-DD' to:'YYYY-MM-DD'`
- "What's next week look like?" → Calculate Monday-Sunday dates for next week
- "Show me last 3 days" → Calculate the date range from 3 days ago to today
- "Anything in the next 2 weeks?" → Use `eventsToday+14` (this syntax works)

Use `date` command if needed to calculate dates:
```bash
# Get date 3 days from now
date -v+3d "+%Y-%m-%d"

# Get last Monday
date -v-monday "+%Y-%m-%d"

# Get next Friday
date -v+friday "+%Y-%m-%d"
```

## Usage Patterns

1. **"What's on my calendar today?"** - `icalBuddy eventsToday`
2. **"What does my week look like?"** - `icalBuddy -sd eventsToday+7`
3. **"Am I free Thursday afternoon?"** - Calculate Thursday's date, use `eventsFrom`, analyze gaps between events
4. **"When could I schedule a 2-hour meeting?"** - Pull the week, identify open slots
5. **"What tasks are due soon?"** - `icalBuddy tasksDueBefore:'today+7'`
6. **"Clean overview of the week"** - `icalBuddy -sd -eep notes,attendees eventsToday+7`

## Important Notes

- **Read-only**: icalBuddy cannot create, modify, or delete events
- **Data source**: Reads from Mac Calendar database (syncs with Google Calendar, iCloud, Outlook if added to Mac Calendar app)

## Response Style

- Be concise - show relevant events, not raw output dumps
- For availability questions, identify gaps and suggest specific times
- For busy weeks, summarize the load before listing everything
