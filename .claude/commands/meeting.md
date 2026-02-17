---
description: Search and summarize meeting notes
allowed-tools: Read, Glob, Grep
---

User is asking about a meeting: $ARGUMENTS

Search for relevant meetings in the meetings/ folder by:
1. List files in meetings/ to see available meetings (filenames contain date, attendee name, and topic)
2. Match the user's query against filenames - look for name matches, topic keywords, or date references
3. Read the most relevant file(s) based on the query
4. Answer the user's specific question (next steps, action items, key points, etc.)

Tips for matching:
- "meeting with Chris" -> look for files containing "Chris" in the name
- "last week's call about fundraising" -> match recent dates + "fundraising" topic
- "what did we discuss with Jane" -> find Jane files, summarize discussion

Always cite which meeting file(s) you found the answer in.
