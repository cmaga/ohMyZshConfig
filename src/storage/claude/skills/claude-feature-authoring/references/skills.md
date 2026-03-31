# Skills and Workflow Commands

A skill is a self-contained package of instructions that Claude loads on demand when a task matches its description. A workflow command is a skill with side effects that only runs when the user explicitly invokes it.

## Capture the Spec

Before handing off to skill-creator, document:

1. What the skill should enable Claude to do
2. When it should trigger (what user phrases or contexts)
3. What the expected output looks like
4. Any dependencies (CLIs, APIs, file types, other skills etc.,)

## Workflow-Specific Constraints

If feature selection determined this is a workflow command (procedures with side effects like deploys, PRs, migrations), include these requirements in the spec:

- Set `disable-model-invocation: true` — user must explicitly invoke via `/command-name`
- Instructions must be numbered sequential steps
- Each step that mutates state must include inline verification (e.g., run tests after each change)
- Name every command that modifies state explicitly — no vague "push and create a PR"

## Handoff

After capturing the spec and applying the universal authoring rules from Phase 4, invoke `/skill-creator` with this information and it will write, test, iterate, optimize the description, and package the skill.
