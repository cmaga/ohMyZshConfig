# Wrap-up

Every tier mode ends here before returning control.

1. Verify behavior via the `verify` skill. If the change alters a shared interface, exercise each consumer flow, not just the changed surface. Skip only if the change has no runtime surface (pure refactor, types/docs, internal library); state the skip reason in chat.
2. Create PR via the `git-provider` skill.
3. Transition ticket to "in review" via the `jira` skill.
4. Run `code-review-agent` against the diff. Pass inline: the tier that ran (small/medium/deep), ticket context, the plan, and the base branch if not `main`. It returns JSON findings tagged CONFIRMED or PLAUSIBLE and never edits files:
   - CONFIRMED: apply the fix yourself, re-run the tests, commit as `address code review findings`, and push. One pass only.
   - PLAUSIBLE: post each as a PR comment via the `git-provider` skill for triage at merge. Do not fix them.
5. Render the [Exit report](../templates/exit-report.md) as the final message.
