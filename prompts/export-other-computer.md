# Export activity from another computer

Use this when some of the work happened on another machine. Paste it into Claude Code **on that machine**, then copy the resulting folder to the main computer and pass it to `build_blocks.ps1 -Claude <folder>\data\activity_events.csv`.

Replace everything in **[brackets]**.

---

I need an export of my own work activity on this computer from **[START DATE]** to **[END DATE]**, in **[TIME ZONE]**, to merge into a timeline built on another machine. Work read-only: don't change, move or delete anything outside the export folder.

1. **Claude Code conversation logs.** Read the JSONL files under `~/.claude/projects/` for conversations in the date range about **[PROJECT OR CLIENT]**. Every entry has a timestamp.
   - Number each message I typed (`message_no`) and give it a short category from its content, using these categories: **[e.g. Client A engagement, Admin: onboarding, Admin: this report, Personal]**. Put admin categories in square brackets, like `[Admin: onboarding]`, so they match my patterns.
   - Write `export/data/activity_events.csv` with one row per log entry: `timestamp_local` (format `yyyy-MM-ddTHH:mm:ss`, local time), `window_start` (the 15-minute window it falls in), `entry` (user, assistant, tool call or tool result), `topic_message_no` (the message it belongs to) and `category`.
   - Write `export/data/messages.csv`: `message_no, date, time, category, first_200_characters`. Remove anything that looks like a password, key or token from the text.
2. **Browser history (only if a profile here is signed in with my work account [WORK ACCOUNT]).** Run `history.ps1` from the hoursleuth skill against that profile only, writing to `export/data/browser_visits.csv`. If no profile uses the work account, say so and skip it.
3. Summarize: date range covered, number of entries, number of messages per category, and anything that looked odd.
