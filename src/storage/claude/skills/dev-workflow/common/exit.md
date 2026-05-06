# Wrap-up

Every tier mode ends here before returning control.

1. Create PR via the `git-provider` skill.
2. Transition ticket to "in review" via the `jira` skill.
3. Run `code-review-agent` against the diff. If it returns findings, auto-fix what you can, commit as `address code review findings`, and push. One pass only.
4. Render the [Exit report](../templates/exit-report.md) as the final message.
