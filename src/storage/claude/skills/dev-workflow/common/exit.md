# Wrap-up

Every tier mode ends here before returning control.

1. Verify behavior via the `verify` skill. If the change alters a shared interface, exercise each consumer flow, not just the changed surface. Skip only if the change has no runtime surface (pure refactor, types/docs, internal library); state the skip reason in chat.
2. Create PR via the `git-provider` skill.
3. Transition ticket to "in review" via the `jira` skill.
4. Run `code-review-agent` against the diff. If it returns findings, auto-fix what you can, commit as `address code review findings`, and push. One pass only.
5. Render the [Exit report](../templates/exit-report.md) as the final message.
