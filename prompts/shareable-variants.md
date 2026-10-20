# Shareable report variants

The full report is private. Use these prompts, in the same folder as a finished run, to build versions for other audiences. Each builds from `report_data.json` but **removes fields from the data before embedding it**, so nothing private can be recovered with "View source".

---

## Finance / HR: timesheet backup

Build `report_finance.html` from `report_data.json` and `skills/hoursleuth/templates/report_template.html`. Keep only: daily billable hours, billable meeting titles and the draft timesheet descriptions. Remove: every chat and email signal, all browser signals, file names, the collaborator chart, the heatmap, the blocks table, and any admin or personal minutes and signals. Strip these from the embedded JSON, not just from the display. Then search the finished HTML for every person's name and every `Browser:`, `Sent:`, `DM` and `#` string, and show me what's left.

## Manager: weekly status

Build `report_manager.html` from `report_data.json`. Keep: weekly hours vs. allocation, hours per day by category, meeting titles, and a short list of deliverables (from file-save signals). Remove: message labels, email subjects, browser data, personal minutes, and the collaborator chart. Strip from the embedded JSON. Then list every string in the finished file that could identify a person other than me.

## Client: what was delivered

Build `report_client.html` from `report_data.json`. Keep: meetings held with **[CLIENT]** (dates and titles) and deliverables produced (file names I approve from a list you show me first). Remove: all hours and percentages, internal and admin activity, internal people's names, browser data, chat and email. Strip from the embedded JSON. Show me the final list of every text string in the file before I send it.
