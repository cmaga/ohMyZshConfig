# Reflect

Mine the current session for durable learnings with three parallel reviewers, then route each one: a kitchen finding per the kitchen's Defects and lessons, a project nuance to auto memory.

Run it when the user says "reflect". Skip when the session is trivial, off-topic, or already covered by a skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, find this session's transcript in `~/.claude/projects/<slug>/`, where the slug is the workspace path with each `/` and `.` changed to `-`. Read only this workspace's folder. Other folders hold unrelated private sessions.

```bash
ls -t ~/.claude/projects/<slug>/*.jsonl ~/.claude/projects/<slug>/*/subagents/*.jsonl 2>/dev/null | head -10
```

That covers sessions (`<session>.jsonl`) and their subagents (`<session>/subagents/<agent>.jsonl`). The newest `.jsonl` directly in the folder is usually the current session. Confirm it by finding the session's opening user prompt in it. If none matches, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

One message, three `Agent` calls. Each takes its role from [SKILL.md](../../SKILL.md#subagents), and none edits files. Reviewers look up the tickets, chat threads, and traces the transcript references, so give them a `general-purpose` agent, never `Explore`.

| Lens | Role | Prompt template |
|---|---|---|
| Judgment | judgment | [judgment-reviewer.md](judgment-reviewer.md) |
| Tooling | other family | [tooling-reviewer.md](tooling-reviewer.md) |
| Divergent | judgment | [divergent-reviewer.md](divergent-reviewer.md) |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in their final report.

## 3. Synthesize

One `Agent` call in the judgment role, `general-purpose`, since it spot-verifies citations through MCP tools. Pass [synthesizer.md](synthesizer.md) verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the [Encode Lessons in Structure](../../dependencies/principles/encode-lessons-in-structure.md) principle.

## 5. Route

Present the synthesizer's full Accepted / Rejected / Backlog output. Fix each kitchen row that names something broken first, per [Defects and lessons](../../SKILL.md#defects-and-lessons), picked or not. Then let the user pick the other kitchen rows to fix now. Make each picked edit with the `claude-feature-authoring` skill in `~/dev/personal/ohMyZshConfig`, only under `src/storage/claude/`, and leave it uncommitted and undeployed for the user's review; then mark the lessons it addresses per the memory-use rule. Route every remaining Accepted and Backlog row per Defects and lessons, a row about another skill per the memory-use rule, and a `new skill` row as a `project` memory per the memory-use rule.

## 6. Summarize for the user

Short list, no preamble:

- Edits left for review: each file, what changed, one line each.
- Fixes committed: the commit subject. What changed, one line each.
- Memory entries written: `<memory file>`. One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
