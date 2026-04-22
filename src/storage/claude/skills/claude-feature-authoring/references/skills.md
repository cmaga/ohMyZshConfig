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

- Decide `disable-model-invocation` by whether mutations are gated, not by the mere presence of side effects:
  - Unguarded — skill mutates state without user review → `true`; require slash invocation via `/command-name`
  - Gated — workflow has an explicit user-approval step before any mutation → `false` is fine; the gate is the safety, not the invocation mode
- Instructions must be numbered sequential steps
- Each step that mutates state must include inline verification (e.g., run tests after each change)
- Name every command that modifies state explicitly — no vague "push and create a PR"

## Artifact Lifecycle

Any feature that writes files — skills, workflow commands, hooks, subagents — must declare at what point of a project/session/worktree lifecycle its artifacts are allowed to exist. Pick the narrowest scope that outlives the need.

| Lifecycle | Path                                        | Dies when            | Example                |
| --------- | ------------------------------------------- | -------------------- | ---------------------- |
| Worktree  | `<worktree>/.claude-artifacts/<feature>/…`  | Worktree removed     | Implementation plan    |
| Project   | `<main-repo>/.claude-artifacts/<feature>/…` | Manual / project end | Long-lived cache       |
| User      | `~/.claude-artifacts/<feature>/…`           | Explicit user action | Cross-project prefs    |
| Ephemeral | Session context only, never on disk         | Session ends         | Scratch state          |

Rules:

- Never write runtime artifacts under `.claude/` or `~/.claude/` — those paths are reserved for Claude configuration and trigger permission prompts.
- Project-scoped artifacts must be gitignored. Append `.claude-artifacts/` to `$(git rev-parse --git-common-dir)/info/exclude` at feature entry — idempotent, untracked, shared across worktrees.
- Cleanup is the responsibility of whoever invalidates the lifecycle. Worktree teardown removes worktree-scoped artifacts for free; project- and user-scoped artifacts need explicit cleanup commands.
- Declare the chosen lifecycle explicitly in the feature's SKILL.md (or equivalent) so future readers know without guessing.

## Handoff

After capturing the spec and applying the universal authoring rules from Phase 4, invoke `/skill-creator` with this information and it will write, test, iterate, optimize the description, and package the skill.
