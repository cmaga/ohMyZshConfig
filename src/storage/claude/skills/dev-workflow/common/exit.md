# Wrap-up

Every tier mode ends here before returning control.

1. Verify behavior via the `verify` skill. If the change alters a shared interface, exercise each consumer flow, not just the changed surface. Skip only if the change has no runtime surface (pure refactor, types/docs, internal library); state the skip reason in chat. If verification needs a browser and the project has no Playwright MCP config — or a drive fails with Chromium's "browser is already in use" profile lock — run the `playwright-mcp-setup` skill first, then continue.
2. Create PR via the `git-provider` skill.
3. Transition ticket to "in review" via the `jira` skill.
4. Run `code-review-agent` against the diff. Pass inline: the tier that ran (small/medium/deep), ticket context, the plan, and the base branch if not `main`. It returns JSON findings tagged CONFIRMED or PLAUSIBLE and never edits files. The tag is confidence, not severity — it gates whether to verify, never whether to fix.
   - Verify every PLAUSIBLE finding that would be serious if true before routing it. Uncertainty is a reason to check, not to defer.
   - Route each real finding by the discovered-issue rule ([SKILL.md](../SKILL.md)): a small fix → apply it, re-run tests, commit as `address code review findings`, push (one pass); a fix that would balloon the ticket → create a follow-up ticket now.
   - Every finding not fixed appears in the exit report with its disposition — the follow-up ticket key, or reported for the user's call. A PR comment is not a disposition; the PR closes and it is orphaned.
5. Render the [Exit report](../templates/exit-report.md) as the final message.
