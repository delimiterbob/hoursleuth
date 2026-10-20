# Hoursleuth Playbook

**Rebuild a person's work timeline from the digital traces they already leave behind, then turn it into time blocks, billable hours and a shareable report.**

This guide explains the full process in enough detail to repeat it on any computer, with Claude Code (desktop app or CLI) doing the work. Every example is fictional: "the user" is the person whose time is measured, "the Firm" is their employer, "Client A" is the customer they bill, "Person 1", "Person 2" and so on are colleagues, and "Client Contact 1" and "Client Contact 2" work at Client A.

Read [RESPONSIBLE_USE.md](RESPONSIBLE_USE.md) first.

---

## Contents

1. [What this produces](#1-what-this-produces)
2. [Ground rules: privacy and read-only access](#2-ground-rules-privacy-and-read-only-access)
3. [Prerequisites](#3-prerequisites)
4. [Folder layout](#4-folder-layout)
5. [Step 1: Scope the request](#5-step-1-scope-the-request)
6. [Step 2: Connect the sources](#6-step-2-connect-the-sources)
7. [Step 3: Collect signals from each source](#7-step-3-collect-signals-from-each-source)
8. [Step 4: Normalize into one events file](#8-step-4-normalize-into-one-events-file)
9. [Step 5: Add browser history](#9-step-5-add-browser-history)
10. [Step 6: Add activity from other computers](#10-step-6-add-activity-from-other-computers)
11. [Step 7: Build time blocks](#11-step-7-build-time-blocks)
12. [Step 8: Categorize and split time](#12-step-8-categorize-and-split-time)
13. [Step 9: Build the report](#13-step-9-build-the-report)
14. [Step 10: Verify before sharing](#14-step-10-verify-before-sharing)
15. [Pitfalls and fixes](#15-pitfalls-and-fixes)
16. [Shareable variants](#16-shareable-variants)
17. [Reference scripts](#17-reference-scripts)
18. [Checklist](#18-checklist)

---

## 1. What this produces

| Output | What it is |
|---|---|
| `activity_events.csv` | One row per signal: a sent message, a sent email, a meeting, a saved file. Columns: `Start, End, Source, Detail`. |
| `activity_blocks.csv` | Signals merged into continuous blocks of work, with category and minutes per category. |
| `activity_daily_totals.csv` | Hours per day, billable vs. other. |
| `report_data.json` | Blocks, events and config, used by the report. |
| `activity_report.html` | A single self-contained interactive report: summary tiles, weekly hours vs. allocation, hours per day, daily timeline, hour-of-day heatmap, collaborators, source mix, a draft timesheet with copy buttons, and a filterable table of every block. |

See [examples/synthetic](examples/synthetic) for all five, built from fictional data.

The numbers are **lower bounds**. Thinking, reading and drafting that leave no trace aren't counted. Say this every time you present results.

---

## 2. Ground rules: privacy and read-only access

State these to Claude at the start of every run.

1. **Read-only, always.** Connectors for chat, email, calendar and file storage usually grant write access too, because most users can't set read-only scopes. Claude must use only search, list, read and get tools. Never send, post, react, draft, label, trash, create, update, delete or respond. Ask Claude to save this as a standing rule (a memory) for the project so later sessions follow it.
2. **Only the user's own activity.** Collect what the user sent, attended or saved, not what others did.
3. **The user's own device.** Browser history and local logs are read only with the user's explicit request, from copies, never from the live files.
4. **Keep detail local.** Page titles, message excerpts and file names stay on the user's machine. The full report is for the user; shared versions strip detail (see [Shareable variants](#16-shareable-variants)).
5. **No credentials.** Nothing in this process needs a password typed by Claude. Connectors are authorized by the user in the app.
6. **Confirm business-only devices.** Ask whether the computer is used only for work. If it is, all browser activity can count as work activity. If not, read only the work browser profile, or filter to work domains.

---

## 3. Prerequisites

| Need | Notes |
|---|---|
| Claude Code | Desktop app (Code tab) or CLI, opened in an empty project folder. |
| Connectors | Chat (e.g. Slack), email (e.g. Gmail), calendar (e.g. Google Calendar), file storage (e.g. Google Drive). Add them from the connector directory; the user signs in. |
| Windows + PowerShell 5.1 | The reference scripts are PowerShell so they run on a stock work laptop with no Python or Node. |
| `C:\Windows\System32\winsqlite3.dll` | Ships with Windows 10/11. Used to read browser history (SQLite) without installing anything. |
| Optional: other computers | If work started on another machine, export what you can from it (see [Step 6](#10-step-6-add-activity-from-other-computers)). |

On macOS or Linux the same method works; replace the PowerShell scripts with Python (`sqlite3` is built in) and adjust browser profile paths. A Python port is a welcome contribution.

---

## 4. Folder layout

One folder per run (per person, per period):

```
my-run/
├── config.json                       copy of skills/hoursleuth/config.example.json, edited
├── activity_events.csv               Step 4 (built from connector results)
├── report_data.json                  generated by build_blocks.ps1
├── activity_blocks.csv               generated
├── activity_daily_totals.csv         generated
├── activity_report.html              generated by build_report.ps1
└── <other-computer export>/          optional, Step 6
    └── data/activity_events.csv
```

Browser history copies and the raw browser visit list go in Claude's **scratchpad** (session temp folder) or another temp folder, not the run folder, because they list every page title.

---

## 5. Step 1: Scope the request

Settle these before collecting anything:

| Question | Example |
|---|---|
| Date range | "March 2 through today" |
| Time zone | The user's local zone. Every timestamp gets converted to it. |
| Gap rule | 30 minutes: a pause longer than this ends a block. |
| Output | Spreadsheet (CSV) plus visual report. |
| Billable categories | e.g. "Client A engagement" is billable; firm onboarding/admin is not; personal topics are excluded. |
| Weekly allocation | 40 hours/week by default; set your own (e.g. 20 for a part-time engagement). Shown as a reference line. |
| Devices | Which computers were used, and when work moved between them. |

Record the answers in `config.json` (gap, allocation, category patterns) and in the starter prompt.

---

## 6. Step 2: Connect the sources

In the desktop app, Claude can check what's connected and suggest missing connectors:

1. Call the connector status tool to list connected servers.
2. Search the connector registry for missing ones (e.g. "calendar", "messages").
3. Show the suggestion card; the user clicks **Connect** and signs in.
4. Re-check status. New tools appear as deferred tools; load only the **read** tools by name.

Read tools typically needed:

| Source | Tools |
|---|---|
| Chat | search messages (all channel types), read user profile (to get the user's own ID) |
| Email | search threads, get thread (metadata only) |
| Calendar | list events |
| Files | search files, list recent files |

---

## 7. Step 3: Collect signals from each source

Run independent queries in parallel. Paginate until the source says there are no more results.

### 7.1 Chat (sent messages)

- Get the user's ID from their profile (the search tool description often states it).
- Query: `filters: from:<@USER_ID> after:YYYY-MM-DD`, empty keywords, `sort: timestamp`, `sort_dir: asc`, `include_context: false`, `response_format: concise`, `limit: 20`.
- Follow the pagination cursor to the end. A few weeks of messages can take a dozen pages.
- For each message keep: timestamp and conversation (`DM Person 2`, `Group DM (Person 1, Person 3)`, `#channel`). The message text isn't needed for blocks; keep at most a short label.
- **Note who is not on chat.** External client contacts often only appear in email. Don't count chat mentions of them as contact with them.

### 7.2 Email (sent mail)

- Query: `in:sent after:YYYY/MM/DD`, page size 50, minimal view.
- Search results only show some messages of long threads. For any thread with more messages than were returned, call **get thread** with `METADATA_ONLY` and keep every message where the sender is the user.
- Convert UTC timestamps to local time.
- Record the **primary recipient** at the end of the detail, in parentheses, e.g. `Sent: Re: Kickoff agenda (Client Contact 1)`. The report's collaborator chart parses this.
- Skip calendar-system "sent" mail (invite updates) and messages the user sent to themselves.

### 7.3 Calendar (meetings)

- List events for the range, ordered by start time.
- Keep events where the user's response is `accepted` (or they're the organizer). Use the full start-to-end interval.
- **Exclude:** placeholder holds ("Busy", "blocked"), out-of-office/"Unavailable", all-day events, and anything later than "now".
- **Infer** meetings that never hit the calendar when evidence is strong, and label them `Meeting (inferred)`:
  - a chat thread saying "call me now" followed by a gap and "just finished my chat with…"
  - a call recording file whose name embeds a start time (e.g. `GMT2026MMDD-HHMMSS_Recording`)
  - auto-generated meeting notes whose title embeds a start time

### 7.4 Files (saves and uploads)

- Search with `modifiedTime >= 'START' and modifiedTime < 'END' and owner = 'me'`, paging until empty; also list recent files ordered by "last modified by me".
- Use `modifiedTime` as the activity time. **For uploaded files, this is the file's original save time on the user's computer**, which is usually closer to when the work happened than the upload time. Count a bulk upload once, at its `createdTime`.
- **Exclude** auto-generated notes (e.g. AI meeting notes) and system folders; the meeting itself already covers that time.
- Collapse runs of near-identical saves (e.g. a dozen PDFs exported within 20 minutes) into one or two events.

---

## 8. Step 4: Normalize into one events file

All sources go into `activity_events.csv`:

```csv
Start,End,Source,Detail
2026-03-03 13:19,,Slack,DM Person 2
2026-03-03 13:27,,Email,Sent: Re: Kickoff agenda (Client Contact 1)
2026-03-03 14:00,2026-03-03 15:00,Meeting,Client A steering deck review
2026-03-03 16:38,,Drive,Discovery questionnaire saved
2026-03-05 13:32,2026-03-05 13:50,Meeting (inferred),Chat call with Person 2
```

Rules:

- `Start` / `End` are local time, `yyyy-MM-dd HH:mm`. `End` is blank for point events.
- `Source` is one of `Slack`, `Email`, `Meeting`, `Meeting (inferred)`, `Drive` (rename to fit your tools; the report handles any source name, and treats any source starting with `Meeting` as a meeting).
- `Detail` is short and descriptive. Put the counterpart in parentheses at the end for email. Avoid anything you wouldn't want in the user's own report.
- Tag topics you've decided on with markers the category patterns match, e.g. `[Admin]` or `[Personal]`.
- Write the file as UTF-8 **without** a byte-order mark, so other tools read it cleanly.

---

## 9. Step 5: Add browser history

Browser history is the richest signal on a work laptop. Chrome and Edge store it in a SQLite file named `History`:

| Browser | Path |
|---|---|
| Chrome | `%LOCALAPPDATA%\Google\Chrome\User Data\<Profile>\History` |
| Edge | `%LOCALAPPDATA%\Microsoft\Edge\User Data\<Profile>\History` |
| Firefox | `%APPDATA%\Mozilla\Firefox\Profiles\<profile>\places.sqlite` (different schema; not covered by the script) |

Procedure ([`history.ps1`](skills/hoursleuth/scripts/history.ps1)):

1. Find profiles and pick the ones with recent writes. Each profile's `Preferences` file shows which account is signed in; on a computer that's also used personally, read only the profile signed in with the work account.
2. **Copy** each `History` file to the scratchpad. Never open the live file.
3. Query `visits JOIN urls` for the date range. Chromium's `visit_time` is **microseconds since 1601-01-01 UTC**.
4. **Drop background noise:** transition core types `3` (auto subframe) and `8` (reload), i.e. `(transition & 255) NOT IN (3,8)`. Without this, tabs that refresh themselves (mail, calendar) fill every gap.
5. Keep only time, browser, host and title. Don't keep full URLs.
6. When feeding blocks, collapse to **one signal per (minute, host)** so a redirect chain counts once.
7. Treat general productivity hosts (mail, calendar, docs, chat, AI assistants) as **neutral** for categorization: they show activity but not which project it was for.

Watch for visits at odd hours that are really session restores (several tabs reopening within seconds at 4 a.m.). Flag them for the user rather than deleting them; the report marks blocks before 6 a.m. or after 10 p.m. with **check**.

---

## 10. Step 6: Add activity from other computers

If the user started on another machine:

- **Browser:** run the extractor there, but only on a profile signed in with the work account. If no profile uses it, record that and move on.
- **Claude Code conversation logs:** each conversation is a JSONL file under `~/.claude/projects/<folder-slug>/<session-id>.jsonl`, with a timestamp on every entry. Use [prompts/export-other-computer.md](prompts/export-other-computer.md) to have Claude on that machine export `activity_events.csv` (`timestamp_local, window_start, entry, topic_message_no, category`) and `messages.csv` (`message_no, date, time, category, first_200_characters`).
- **Other exports:** email or chat from other accounts used for work, or another calendar, can be added the same way as Step 3.

When merging a conversation log (`build_blocks.ps1 -Claude <path>`):

- It's collapsed to **one signal per 5-minute slot per topic**. A busy conversation produces hundreds of entries; without this it outvotes meetings.
- Categories come from the log itself; make sure the category names match your patterns (e.g. include `[Admin` in `adminPattern`).
- Expect its standalone total to differ from the merged total. Standalone reports often count fixed 15-minute windows; merged, the conversation overlaps meetings and chat, and overlapping time is counted once.

---

## 11. Step 7: Build time blocks

Algorithm (in [`build_blocks.ps1`](skills/hoursleuth/scripts/build_blocks.ps1)):

1. Sort all events by start, then end.
2. Walk the list. If the next event starts within **30 minutes** (`gapMinutes`) of the current block's end **and on the same day**, extend the block (end = max of ends). Otherwise close the block and start a new one.
3. Block duration = end − start, with a **5-minute floor** (`minBlockMinutes`) so a single message isn't zero minutes.
4. Meetings contribute their full interval, so a 60-minute meeting with no other signals is still a 60-minute block.

Why 30 minutes: shorter gaps split real work sessions at every coffee refill; longer gaps glue a morning and an afternoon together over lunch.

---

## 12. Step 8: Categorize and split time

Each block needs to know how much of it was billable:

1. **Voting.** Every non-neutral signal in the block votes for one category, using the regular expressions in `config.json`, matched against its `Detail`:
   - `personalPattern`: personal topics the user wants excluded. Checked first.
   - `adminPattern`: firm onboarding, HR, payroll, IT setup, training, the time-tracking tool, and building these reports.
   - everything else that isn't neutral votes for the **billable** category.
   - `neutralPattern`: general productivity hosts (see Step 5) don't vote.
2. **Meetings weigh more.** Each meeting casts `meetingWeight` (default 10) votes. Otherwise a one-hour client meeting can be outvoted by eight HR chat messages sent during it.
3. **Proportional split.** The block's minutes are divided across categories in proportion to the votes. A 224-minute block with 17 billable, 1 admin and 14 personal votes gives about 119 / 7 / 98 minutes.
4. **Label.** The block keeps a label for color and filtering: the majority category, plus "(some X)" for minority categories.
5. **No votes → Unclear.** Shown separately; never billed automatically.

> **Lesson learned:** assigning a whole block to its majority category looks simpler but overstates the majority. Use the proportional split for every total; keep the majority label for display only.

Show the patterns to the user. Names of colleagues, HR staff and client contacts usually decide the category, so these lists are specific to each person.

---

## 13. Step 9: Build the report

[`report_template.html`](skills/hoursleuth/templates/report_template.html) is a static HTML page with a `/*DATA*/` placeholder. [`build_report.ps1`](skills/hoursleuth/scripts/build_report.ps1) replaces the placeholder with `report_data.json`, producing one self-contained file that works offline, can be emailed to yourself, and prints to PDF.

### Sections

| Section | What it answers | Notes |
|---|---|---|
| Summary tiles | Total active time, billable time and %, busiest day, meetings, signals, longest block | Big numbers, no chart. |
| Weekly hours vs. allocation | Is the user over or under their weekly allocation? | Horizontal stacked bars per Mon–Sun week, dashed reference line, "(partial)" on incomplete weeks. |
| Hours per day | How did time split by category each day? | Stacked columns from the proportional minutes. |
| Daily timeline | When did each block happen? | One row per day, bars positioned by clock time, hover for meetings and activity. |
| When you work | What hours of the day are busiest? | Day × hour heatmap of signal counts, single-hue sequential ramp. |
| Who you worked with | Which people and channels? | Horizontal bars split into chat vs. email; client contacts not on chat are labeled "email only". |
| Where the signals came from | Which sources drove each day? | Stacked columns by source. |
| Draft timesheet | What to enter in the time-tracking tool | Billable hours per day rounded **up** to the quarter hour; description drafted from that day's billable meetings plus keyword themes; Copy button per row. |
| All activity blocks | The evidence | Filter chips by category; each row expands to every underlying signal. |
| How this was built | Method, sources, exclusions | Always included; also states that numbers are lower bounds. |

### Design rules

- One axis per chart; no dual axes.
- Categorical colors in a fixed order (billable first), never re-assigned when filters change; at most 3–4 categories plus a neutral gray "Unclear".
- Thin marks, small rounded corners, a 2px gap between stacked segments, recessive gridlines.
- A legend on every multi-series chart, so identity never depends on color alone.
- Hover tooltips on every mark; a table view for everything.
- Light and dark themes (follows the OS, plus a toggle button).
- Charts sized to their container width so text stays legible.
- Print stylesheet hides buttons and keeps cards from splitting across pages.

### Timesheet descriptions

Built from billable meetings that day plus themes (`timesheetThemes` in `config.json`) matched against the day's billable signals, for example:

| Theme | Matched by |
|---|---|
| deck / slide development | deck, slides, presentation |
| engagement documentation | RAID, stakeholder, questionnaire, tracker, discovery, RACI |
| client access & provisioning | client IT contact names, access, VPN |
| client coordination & scheduling | client sponsor name, schedule, sessions |
| scope / SOW review | SOW, scope |
| team coordination | team channel names, teammate names |

Signals from personal or admin topics are excluded, so they never leak into a billable description.

---

## 14. Step 10: Verify before sharing

1. **Open the report** in a browser (the desktop app's browser pane works for local files). Check the console for errors, then look at each section: labels clipped, overlapping text, empty charts.
2. **Spot-check attribution.** List every email by parsed recipient and every chat counterpart. Look for impossible "people" (e.g. a word like "signed" parsed from a subject) and for events attributed to a company name instead of a person.
3. **Reconcile totals.** Daily totals in the CSV, the report tiles and the timesheet should agree (the timesheet is higher only because of rounding up).
4. **Ask the user** about anything ambiguous: odd-hour browser visits, holds that might be real work, and whether report-building counts as admin.

---

## 15. Pitfalls and fixes

| Pitfall | Symptom | Fix |
|---|---|---|
| Connectors have write access | Risk of sending or editing by mistake | State the read-only rule up front; save it as a memory; load only read tools. |
| Long email threads | Search shows 5 of 11 messages | `get thread` with `METADATA_ONLY` for every long thread. |
| UTC vs. local time | Emails and file saves land 4–5 hours off | Convert every UTC timestamp; calendar results usually already carry a zone. Use a time zone ID, not a fixed offset, so daylight saving is handled. |
| Uploaded files | Upload time ≠ work time | Use the file's `modifiedTime` (original save time); count a bulk upload once. |
| Auto-generated notes | Duplicates meeting time | Exclude them; the calendar event covers it. |
| Background tab refreshes | Browser fills every gap | Drop transition types 3 and 8; collapse to one signal per minute per host. |
| Session restore | Visits at 4 a.m. | Flag to the user; don't silently delete. |
| Locked browser file | Copy or open fails | Copy first; if copying fails, ask the user to close the browser. |
| Majority labeling | Personal time counted as billable | Proportional split of minutes by votes. |
| Chatty conversation logs | One source outvotes a meeting | One signal per 5-minute slot; meetings weigh 10. |
| Client contacts not on chat | Chart implies chat with them | Split collaborator bars by channel; label client contacts; note "email only". |
| Parsing recipients from text | "signed" or a company name shows up as a person | Always end email details with `(Recipient)`; skip messages to self; review the parsed list. |
| No Python/Node on the work laptop | Scripts can't run | PowerShell + `winsqlite3.dll` via `Add-Type`; no installs. |
| Chart text too small | Fixed-width SVG scaled down | Size each SVG to its container's `clientWidth`. |
| Work started on another computer | Missing days | Import that machine's conversation log and any work-profile browser history (Step 6). |

---

## 16. Shareable variants

The full report contains message labels, file names, browser hosts and colleagues' names. Keep it private. Build derived versions per audience:

| Audience | Include | Exclude |
|---|---|---|
| Finance / HR (timesheet backup) | Daily billable hours, meeting titles, timesheet description | Chat and email content, browser data, collaborator chart, personal category |
| Manager (weekly status) | Hours vs. allocation, key meetings, deliverables | Message labels, browser data, admin detail |
| Client | Meetings held, deliverables produced | Hours breakdown, internal and admin activity, internal names |

Make each variant a separate template that reads the same data, and **strip fields from the JSON before embedding**, not just in the display: anything embedded in the HTML can be read with "View source". [prompts/shareable-variants.md](prompts/shareable-variants.md) has a prompt for this.

---

## 17. Reference scripts

All in [`skills/hoursleuth/`](skills/hoursleuth). Settings live in `config.json`; the scripts shouldn't need editing.

| File | Purpose | Usage |
|---|---|---|
| `scripts/history.ps1` | Copies Chromium `History` files and extracts visits (time, browser, host, title). | `.\history.ps1 -Out <scratch>\browser_visits.csv -StartDate 2026-03-02 -TimeZone 'Eastern Standard Time'` |
| `scripts/build_blocks.ps1` | Merges events (+ optional browser and conversation-log signals) into blocks, splits categories, writes the CSVs and `report_data.json`. | `.\build_blocks.ps1 -Dir <run> [-Browser <csv>] [-Claude <export csv>]` |
| `scripts/build_report.ps1` | Embeds `report_data.json` into the template. | `.\build_report.ps1 -Dir <run>` |
| `templates/report_template.html` | The report: plain HTML, inline SVG and vanilla JavaScript; no libraries, no network. | — |
| `config.example.json` | Gap rule, allocation, category patterns, client contacts, timesheet themes. | Copy to `<run>\config.json` and edit. |

`config.json` fields:

| Field | Meaning |
|---|---|
| `gapMinutes` | Pause that ends a block (default 30). |
| `minBlockMinutes` | Minimum block length (default 5). |
| `meetingWeight` | Votes per meeting (default 10). |
| `weeklyAllocationHours` | Dashed reference line on the weekly chart (default 40); 0 hides it. |
| `billableLabel` | Shown in legends, e.g. "Billable (Client A)". |
| `adminPattern`, `personalPattern`, `neutralPattern` | Regular expressions matched case-insensitively against each signal's `Detail`. In JSON, escape backslashes (`\\[Admin`). |
| `clientContacts` | Name → display label, used to mark client contacts in the collaborator chart. |
| `timesheetThemes` | `{ label, pattern }` pairs used to draft timesheet descriptions. |

If PowerShell refuses to run the scripts, run them for the current session only with `powershell -ExecutionPolicy Bypass -File <script> ...` rather than changing the machine-wide policy.

---

## 18. Checklist

- [ ] Read-only rule stated and saved as a memory
- [ ] Date range, time zone, gap rule, categories, allocation agreed and in `config.json`
- [ ] Connectors connected; only read tools loaded
- [ ] Chat: all pages collected, user ID filter
- [ ] Email: long threads expanded with metadata-only reads; UTC converted
- [ ] Calendar: accepted only; holds and future events excluded; inferred meetings labeled
- [ ] Files: owner = me; auto-notes excluded; bulk uploads collapsed
- [ ] Browser: copies only; reloads/subframes dropped; per-minute-per-host; odd hours flagged
- [ ] Other computers: conversation logs and work-profile browser history merged
- [ ] Blocks built; proportional category split
- [ ] Report built, opened, every section checked, no console errors
- [ ] Recipients and counterparts reviewed for parsing errors
- [ ] Private report kept private; shareable variants stripped of detail
