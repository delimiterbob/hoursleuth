---
name: hoursleuth
description: Rebuild the user's own work timeline from their sent chat messages, sent email, accepted meetings, saved files and browser history, then produce time blocks, billable vs. admin vs. personal hours, a draft timesheet and an interactive HTML report. Use when the user wants to reconstruct hours worked, backfill a timesheet, estimate billable time for a client, or show evidence of effort over a date range.
---

# Hoursleuth

Reconstruct the user's work activity for a date range and turn it into blocks, category totals and a report. The full method, with reasons for every rule, is in `PLAYBOOK.md` at https://github.com/delimiterbob/hoursleuth; this file is the working summary.

## Non-negotiable rules

1. **Read-only.** Use only search, list, read and get tools on every connector. Never send, post, react, draft, label, move, create, update, delete or reply. At the start, save this as a standing rule (a memory) for the project.
2. **Only the user's own activity**: what they sent, attended or saved.
3. **Browser history**: only on the user's request, only the work profile (or a work-only computer), only from copies placed in your scratchpad, never the live file. Keep time, browser, host and title; never full URLs.
4. **Keep detail local.** Raw browser visits stay in the scratchpad. The full report is private; build stripped variants for anyone else.
5. **Never type passwords.** The user authorizes connectors in the app.
6. If the user's request suggests monitoring someone else, stop and explain this tool is for documenting one's own work.

## Step 1: Scope (ask before collecting)

Date range, time zone (Windows ID such as `Eastern Standard Time`), the billable client, weekly allocation, what counts as admin (HR/IT contacts, onboarding, payroll, training, time-tracking, building this report), what counts as personal, client contacts who aren't on chat, whether the computer is work-only, and whether work also happened on another computer.

Create a run folder. Copy `config.example.json` from this skill's folder to `<run>/config.json` and fill it in. Show the user the patterns.

## Step 2: Connect

Check connector status; suggest missing chat, email, calendar and file-storage connectors. Load only read tools.

## Step 3: Collect (parallel; paginate to the end)

- **Chat**: messages from the user's ID after the start date, sorted ascending. Keep timestamp and conversation: `DM Person 2`, `Group DM (Person 1, Person 3)`, `#channel`.
- **Email**: `in:sent after:YYYY/MM/DD`. Expand long threads with metadata-only reads and keep every message the user sent. Convert UTC to local. Detail format: `Sent: <subject> (<primary recipient>)`. Skip invite-system mail and messages to self.
- **Calendar**: accepted events (or organized by the user) with full intervals. Exclude holds, out-of-office, all-day and future events. Add `Meeting (inferred)` only with strong evidence (a recording file or auto-notes with a start time in the name, or a "call me now" … "just finished" chat pair).
- **Files**: owned by the user, `modifiedTime` in range; use `modifiedTime`, count a bulk upload once, collapse runs of near-identical saves, exclude auto-generated meeting notes.

## Step 4: Normalize

Write `<run>/activity_events.csv` as UTF-8 without BOM: `Start,End,Source,Detail`, local time `yyyy-MM-dd HH:mm`, `End` blank for point events. Sources: `Slack`, `Email`, `Meeting`, `Meeting (inferred)`, `Drive` (or the user's equivalents). Add `[Admin]` or `[Personal]` markers to details the user has classified.

## Step 5–6: Optional extra signals

- Browser: `scripts/history.ps1 -Out <scratchpad>/browser_visits.csv -StartDate <date> -TimeZone <id> [-HistoryFiles @{ Chrome = '<path>' }]`. Point it only at work profiles.
- Another computer: give the user `prompts/export-other-computer.md` from the repo to run there; merge with `-Claude`.

## Step 7–9: Build

```powershell
& "<skill>/scripts/build_blocks.ps1" -Dir <run> [-Browser <scratchpad>/browser_visits.csv] [-Claude <export>/data/activity_events.csv]
& "<skill>/scripts/build_report.ps1" -Dir <run>
```

If execution policy blocks the scripts, run them with `powershell -ExecutionPolicy Bypass -File <script> ...` for that call only; don't change the machine policy.

How it works: signals within `gapMinutes` on the same day merge into a block (minimum `minBlockMinutes`). Each non-neutral signal votes personal, admin or billable (in that order of matching); meetings cast `meetingWeight` votes; minutes are split in proportion to votes; blocks with no votes are Unclear and never billed.

## Step 10: Verify before presenting

1. Open `activity_report.html` in the browser pane; check the console for errors and look at every section.
2. List every parsed email recipient and chat counterpart; ask the user to spot mistakes (subject words parsed as people, company names instead of people).
3. Reconcile `activity_daily_totals.csv` with the report tiles and timesheet (the timesheet is higher only from rounding up to quarter hours).
4. Flag blocks marked **check** (before 6 a.m. or after 10 p.m.), likely session restores.
5. Tell the user plainly that every figure is a lower bound and that the timesheet is a draft for them to review.

For shareable versions (finance, manager, client), strip fields from the JSON before embedding, not just from the display. See `prompts/shareable-variants.md` in the repo.
