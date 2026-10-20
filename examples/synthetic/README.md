# Synthetic example

Two weeks (plus one day) of **entirely fictional** activity for a consultant working for "Client A", from March 2 to March 16, 2026. No real people, companies or events.

| File | What it is |
|---|---|
| `config.json` | Settings: 30-minute gap, 40-hour weekly allocation (the default), admin/personal patterns, client contacts, timesheet themes. |
| `activity_events.csv` | Input: chat, email, meeting and file signals, including an inferred meeting, some onboarding admin and one personal exchange. |
| `browser_visits.csv` | Input: browser visits, including a 4 a.m. session restore that the report flags with **check**. |
| `activity_blocks.csv` | Output: one row per block, with minutes per category. |
| `activity_daily_totals.csv` | Output: hours per day by category. |
| `report_data.json` | Output: blocks, events and config for the report. |
| `activity_report.html` | Output: the interactive report. Download it and open it in a browser. |
| `screenshot.png` | The top of the report. |

Rebuild from the repo root:

```powershell
.\skills\hoursleuth\scripts\build_blocks.ps1 -Dir examples\synthetic -Browser examples\synthetic\browser_visits.csv
.\skills\hoursleuth\scripts\build_report.ps1 -Dir examples\synthetic
```
