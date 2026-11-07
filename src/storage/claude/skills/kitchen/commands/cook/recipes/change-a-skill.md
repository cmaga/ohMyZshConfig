# Change a skill

Writing or editing a SKILL.md, or any file a skill reads.

**You own the skill's voice.**

1. Use the `claude-feature-authoring` skill. Other sessions edit and commit in the skill's source repository too: run `git status` there before editing, and commit only your own files, by pathspec (`git commit -- <paths>`).
2. Validate the skill: frontmatter has `name` and `description`, referenced files exist, cross-skill links resolve.
3. Test cases if structural, per the [eval](eval.md) recipe. Skip if subjective.
4. Run the [open a PR](open-a-pr.md) recipe.

When in doubt, delete. Keep only prose that changes a decision. Tell it to do the thing and skip the reason. Explain only when the rule is confusing without one. Match tone to scope. Point at structural sources (types, READMEs, config) per the [encode lessons in structure](../../../dependencies/principles/encode-lessons-in-structure.md) principle. Delegate to other skills by path. Don't restate. Propose a new skill for a workflow you keep hitting that no skill captures.

**Reply:** summary of the skill, key design decisions, validation notes.
