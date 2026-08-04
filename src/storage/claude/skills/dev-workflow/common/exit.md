# Wrap-up

Every tier mode ends here before returning control.

1. Verify behavior via the `verify` skill. If the change alters a shared interface, exercise each consumer flow, not just the changed surface. Skip only if the change has no runtime surface (pure refactor, types/docs, internal library); state the skip reason in chat. If verification needs a browser and the project has no Playwright MCP config — or a drive fails with Chromium's "browser is already in use" profile lock — run the `playwright-mcp-setup` skill first, then continue.
2. Create PR via the `git-provider` skill.
3. Transition ticket to "in review" via the `jira` skill.
4. Review gate — run `code-review-agent`, fix what it finds, and repeat until it returns `"gate": "pass"`. First round, pass inline: whatever explains why the change was made (the spec if one exists, else the plan, else the ticket title and description), the ticket, and the base branch if not `main`. Later rounds, pass last round's findings, what was done about each, and which commits contain the fixes — it re-checks those instead of re-reviewing the whole diff. It returns JSON: a `gate` verdict and findings of four kinds — bugs (tagged CONFIRMED or PLAUSIBLE), design problems, quality problems, and tech debt. It never edits files. Only bugs block the gate. The tag means confidence, not severity — it decides whether you verify first, never whether it gets fixed.
   - Before acting on a PLAUSIBLE bug that would be serious if true, verify it yourself. Uncertainty is a reason to check, not to skip.
   - **Read the whole path before editing.** A finding names a symptom and a line; the defect is often neither. Locate it yourself, then read every function on that path end to end — the writer sitting below the reader you are adding, the second consumer of the condition you are narrowing, every caller that reaches the early return you are inserting. Edit from that reading, never by pattern-replacing text you have not read.
   - Apply review fixes yourself; never dispatch a worker for one. The reading that prevents the next regression does not survive the handoff.
   - Route each real bug by the discovered-issue rule ([SKILL.md](../SKILL.md)): a small fix → apply it, re-run tests, commit as `address code review findings`, push; too big for this ticket → carry it into the exit report as a proposed ticket, searching Jira first per the discovered-issue rule. A proposal counts as handled for the gate; do not file it to unblock yourself. A recurring finding lists example locations only — sweep the diff for the remaining occurrences when applying the fix.
   - Design findings are opinions for the user: never auto-fix them; list each in the exit report for the user's decision.
   - Quality findings: apply the ones that are small and provably behavior-preserving (delete dead code, fix a misleading name) in the same fix pass; list the rest in the exit report.
   - Tech debt findings become exit-report lines proposing a ticket, with the search result that shows none already exists.
   - Stop the loop when the gate passes, after three failed rounds, or when a fix breaks something already fixed — then put whatever is still open in the exit report instead of looping forever.
   - Every finding not fixed appears in the exit report with its disposition — an existing ticket's key, or a proposed one for the user's call. A PR comment is not a disposition; the PR closes and it is orphaned.
5. Render the [Exit report](../templates/exit-report.md) as the final message.
