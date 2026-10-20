# Starter prompt

Paste into Claude Code, opened in an empty folder on your own computer. Put a copy of `PLAYBOOK.md` and the `skills/hoursleuth` folder in it first (or install the skill; see the [README](../README.md#quick-start)). Replace everything in **[brackets]**.

---

I want to reconstruct my work activity from **[START DATE]** through today, in **[TIME ZONE]**, to find blocks of time I worked and how much was billable to **[CLIENT]**.

Rules: use every connector **read-only**: search, list, read and get only. Never send, post, react, draft, edit, label, create or delete anything. Save that as a standing rule for this project. Only collect my own activity.

Sources: my sent chat messages, my sent email, calendar meetings I accepted, files I own that I saved in the range, and browser history on this computer (it's used only for work **[or: only the profile signed in as WORK ACCOUNT]**). Work from copies of browser history, kept in your scratchpad.

Follow the method in `PLAYBOOK.md`: normalize to `activity_events.csv`, merge into blocks with a **30-minute** gap rule, categorize as billable / admin / personal with a proportional split, and build the HTML report with a draft timesheet using the scripts in `skills/hoursleuth`. Put my settings in `config.json`:

- Weekly allocation: **[N] hours**
- Admin includes: **[HR contacts, IT contacts, onboarding, payroll, training, time-tracking]**
- Personal includes: **[topics to exclude]**
- Client contacts who aren't on chat: **[names and roles]**
- Timesheet themes: **[e.g. deck development, discovery, scheduling]**

Before you finish: open the report and check every section, list parsed email recipients and chat counterparts so I can spot mistakes, flag any odd-hour activity, and tell me which numbers are lower bounds or uncertain.
