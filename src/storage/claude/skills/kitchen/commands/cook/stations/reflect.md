# Reflect

Mine the current session for durable learnings with three parallel reviewers, then route each one: a kitchen defect to a PR, a project nuance to auto memory.

Run it when the user says "reflect". Skip when the session is trivial, off-topic, or already covered by a skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, find this session's transcript in `~/.claude/projects/<slug>/`, where the slug is the workspace path with each `/` and `.` changed to `-`. Read only this workspace's folder. Other folders hold unrelated private sessions.

```bash
ls -t ~/.claude/projects/<slug>/*.jsonl ~/.claude/projects/<slug>/*/subagents/*.jsonl 2>/dev/null | head -10
```

That covers sessions (`<session>.jsonl`) and their subagents (`<session>/subagents/<agent>.jsonl`). The newest `.jsonl` directly in the folder is usually the current session. Confirm it by finding the session's opening user prompt in it. If none matches, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

One message, three `Agent` calls. Each takes its role from [SKILL.md](../../../SKILL.md#subagents), and none edits files. Reviewers look up the tickets, chat threads, and traces the transcript references, so give them a `general-purpose` agent, never `Explore`.

| Lens | Role | Prompt template |
|---|---|---|
| Judgment | judgment | [judgment-reviewer.md](reflect/judgment-reviewer.md) |
| Tooling | other family | [tooling-reviewer.md](reflect/tooling-reviewer.md) |
| Divergent | judgment | [divergent-reviewer.md](reflect/divergent-reviewer.md) |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in their final report.

## 3. Synthesize

One `Agent` call in the judgment role, `general-purpose`, since it spot-verifies citations through MCP tools. Pass [synthesizer.md](reflect/synthesizer.md) verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the [Encode Lessons in Structure](../../../dependencies/principles/encode-lessons-in-structure.md) principle.

## 5. Route

Present the synthesizer's full Accepted / Rejected / Backlog output when the user is here. Then route every Accepted and Backlog row by what it targets:

- **The kitchen skill itself.** A wrong step, a missing rule, a broken script, or a gap that cost the run time is a kitchen defect. Fix it per [SKILL.md](../../../SKILL.md#defects-and-lessons). The PR is where the user approves the change. A Backlog row for the kitchen goes into the same PR as the mechanism it suggests.
- **A project nuance**, something about this project that caused confusion, delay, or difficulty. Write it to auto memory as a lesson for the user's next memory review, which decides what it becomes: a project hook, rule, or skill, a global change, a kitchen change, or nothing. Never commit it, or anything else from memory, into the project yourself.
- **Any other skill.** Write it to auto memory under `## Skill: <name>`, per the memory-use rule, for the same review.

Never edit a plugin's cached copy under `~/.claude/plugins/`.

Follow each kitchen row's Routing exactly:

- Trivial edit (a one-line bullet, a tightened sentence, a stale fact corrected): make it directly.
- Substantive edit (a new section, a new pattern table, more than about 10 lines): write it with the `claude-feature-authoring` skill, and prove the change with the [eval](../recipes/eval.md) recipe when it changes how agents behave.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): tune it with the `claude-feature-authoring` skill.
- `new skill via claude-feature-authoring: <kebab-name>`: it is not a kitchen defect. Write it to auto memory for the review. Do not invent the shape ad hoc.

Run `make lint` in ohMyZshConfig on the PR's branch before you open it.

## 6. Summarize for the user

Short list, no preamble:

- PRs opened: `<url>`. What changed, one line each.
- Memory entries written: `<memory file>`. One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
