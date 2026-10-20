# Responsible use

Hoursleuth reads email, chat, calendars, files and browser history. That's powerful, so it comes with rules.

## Who it's for

**Individuals documenting their own work.** Freelancers and consultants recovering billable hours, employees showing the effort behind a deliverable, anyone who forgot to fill in a timesheet.

**Not for monitoring other people.** Don't use it to reconstruct someone else's activity, and don't use it as an employer to track staff. Depending on where you are, monitoring employees' communications or browsing can require notice, consent or a legal basis, and doing it covertly can be unlawful. This project doesn't support that use.

## Before your first run

- **Check your employer's and your client's policies.** Many organizations restrict connecting work email, chat or files to AI tools, or limit which tools are approved. If you're not sure, ask first.
- **Check your billing rules.** Some professions and contracts (law, government work, some audits) have strict rules on how time is recorded. A timeline rebuilt after the fact is an *estimate supported by evidence*, not a record kept as you worked. If you bill from it, be ready to say how it was produced.
- **Use your own device and accounts.** Read browser history only on your own computer, only the profile you use for work, and only from a copy.

## While running

- **Read-only, always.** Tell Claude to use only search, list, read and get tools, and to save that as a standing rule. It must never send, post, react, draft, label, move, delete or reply. See [PLAYBOOK.md §2](PLAYBOOK.md#2-ground-rules-privacy-and-read-only-access).
- **Only your activity.** Messages you sent, meetings you accepted, files you saved. Not what other people did.
- **Keep detail local.** Browser history copies and raw visit lists go in a temp folder. Message text isn't needed: a conversation name and a short label are enough.
- **No passwords.** You authorize connectors yourself in the app. Nothing in the process needs Claude to type a password.

## The results

- **They're lower bounds.** Time spent thinking, reading on paper, on calls that left no trace, or away from a computer isn't counted. Say so whenever you present the numbers.
- **They're evidence, not proof.** Patterns and votes can be wrong. Review every block before billing it; the report marks odd-hour blocks and anything it couldn't categorize.
- **Review before you submit.** The timesheet is a *draft*. You're responsible for what you enter.

## Sharing

- **The full report is private.** It contains message labels, file names, browser hosts and colleagues' names. Don't email it, upload it or attach it.
- **Share a variant.** Build a stripped-down version for each audience (finance, manager, client), removing fields from the data before it's embedded, not just hiding them. See [PLAYBOOK.md §16](PLAYBOOK.md#16-shareable-variants).
- **Don't post real data.** When opening an issue or pull request here, use fictional data only.

## No warranty

This is a method and some example scripts, provided as is (see [LICENSE](LICENSE)). It isn't legal, HR or accounting advice.
