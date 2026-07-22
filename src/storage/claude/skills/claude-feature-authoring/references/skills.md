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

Artifact paths always include a `<type>` segment so provenance is obvious from the directory tree. Valid types: `skills`, `workflows`, `rules`, `hooks`, `agents`. A workflow command writes under `workflows/`, even though it is packaged in the same `skills/` source tree.

| Lifecycle | Path                                                  | Dies when            | Example                |
| --------- | ----------------------------------------------------- | -------------------- | ---------------------- |
| Worktree  | `<worktree>/.claude-artifacts/<type>/<feature>/…`     | Worktree removed     | Implementation plan    |
| Project   | `<main-repo>/.claude-artifacts/<type>/<feature>/…`    | Manual / project end | Long-lived cache       |
| User      | `~/.claude-artifacts/<type>/<feature>/…`              | Explicit user action | Cross-project prefs    |
| Ephemeral | Session context only, never on disk                   | Session ends         | Scratch state          |

Rules:

- Never write runtime artifacts under `.claude/` or `~/.claude/` — those paths are reserved for Claude configuration and trigger permission prompts.
- Project-scoped artifacts must be gitignored. Append `.claude-artifacts/` to `$(git rev-parse --git-common-dir)/info/exclude` at feature entry — idempotent, untracked, shared across worktrees.
- Cleanup is the responsibility of whoever invalidates the lifecycle. Worktree teardown removes worktree-scoped artifacts for free; project- and user-scoped artifacts need explicit cleanup commands.
- Declare the chosen lifecycle and type explicitly in the feature's SKILL.md (or equivalent) so future readers know without guessing.

## Provisioned Resources

Artifacts die with their scope for free. Resources do not — a container, background server, or tunnel started inside a worktree survives `git worktree remove`, because nothing links the two. Unclaimed, they accumulate silently: nothing in a normal workflow ever lists them.

The session that tears down is never the session that provisioned. `cleanup` runs days later, after the PR merges, in a fresh context knowing only that the worktree exists. A "Cleanup" section in your SKILL.md cannot help it — it will never read your skill.

So a skill that starts something must make it recoverable with no context:

1. **Scope the name to the worktree.** Derive it from the directory — `SLUG=$(basename "$PWD" | tr '[:upper:]' '[:lower:]')` — and let the system assign ports (`docker run -P`, read back with `docker port`). Fixed names and fixed ports collide across concurrent worktrees, and the reflex fix is to disable auto-removal. That is how leaks start.
2. **Record the undo at bring-up, never at the end.** Append one command per resource to `<worktree>/.claude-artifacts/teardown.sh`, with names already expanded so the file stands alone.
3. **Keep it tolerant.** No `set -e` — an already-released resource is the expected case, not an error. Nothing unscoped: `docker system prune` and friends reach into live concurrent worktrees.

dev-workflow's `cleanup` runs that file before removing the worktree. That is the whole contract — it needs no knowledge of what your project provisions, and stays a silent no-op where nothing is provisioned.

`teardown.sh` sits at the root of `.claude-artifacts/`, not under `<type>/<feature>/` like the table above. Deliberate: the consumer is generic and must find it without knowing which skill wrote it. Several skills in one worktree just append to the same file.

Verify auto-removal actually reclaims what you think. Measured example: `--rm` does not reclaim `postgres:16`'s anonymous volume on a force-remove, so `docker rm -f` orphans ~50 MB per run where `docker rm -f -v` reclaims it.

## Handoff

After capturing the spec and applying the universal authoring rules from Phase 4, invoke `/skill-creator` with this information and it will write, test, iterate, optimize the description, and package the skill.
