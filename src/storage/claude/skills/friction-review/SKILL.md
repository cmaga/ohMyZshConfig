---
name: friction-review
description: Triage the dev-workflow friction log and turn what recurs there into proposed skill edits. Slash-invoked only.
disable-model-invocation: true
---

# Friction review

Runs end; their complaints outlive them. [dev-workflow](../dev-workflow/common/friction.md) writes one file per friction event to `~/.claude-artifacts/workflows/dev-workflow/friction/` as it runs. This reads that pile and decides what, if anything, the skill should change.

Entries are user-lifecycle artifacts and only this skill resolves them: acted-on ones move to `resolved/` beside them, declined ones stay put carrying the decision. Nothing else deletes them.

## Workflow

1. **Read every entry**, including `resolved/` — a defect recurring after it was fixed is the most important thing the pile can tell you. Nothing in the directory means nothing to do: say so and stop.
2. **Group by cause, not by wording.** Two entries naming different files are one group when the same missing sentence produced both. For each group, count sightings and note their spread in time.
3. **Rule each group.**
   - **Defect** — the text is wrong, missing, or contradicts itself elsewhere. Two sightings, or one that names a cost worth the change.
   - **Anecdote** — one sighting, no cost past the moment. Leave it exactly where it is. It resolves by never recurring, and clearing it destroys the evidence its second sighting would need.
   - **Not the skill** — the run misread text that was clear, or the friction was really the code. Resolve it with that reason.
4. **Present the groups before drafting anything**, defects first, one line each: what recurs, how many times, and the change you would make. The user picks. Never draft for a group they did not pick.
5. **Read the surrounding text before writing a word of the fix.** A rule that exists but nobody found is a placement defect, and a second copy of it elsewhere makes the skill worse. Verify the entry's claim against the file as it stands now — entries age, and the sentence may already have changed.
6. **Draft each picked change** through the `claude-feature-authoring` skill, which owns the authoring rules and the source paths. Edits land in `~/dev/personal/ohMyZshConfig/src/storage/claude/skills/dev-workflow/` and never in `~/.claude/`, which the next deploy overwrites.
7. **Show the rendered instruction, not the diff** — the text a future run will read, before and after.
8. **Resolve on approval.** Move each acted-on entry into `resolved/` with `resolved: <commit subject>` added to its frontmatter. A group the user declined stays where it is with `declined: <date>` and one line of why, so the next review does not re-litigate it.
9. **Commit** the skill edits with `make lint` passing. Never deploy — `make deploy-claude` is the user's call.

## Rules

- The pile is evidence, not a backlog. A review that changes nothing is a correct outcome and will be the common one.
- Recurrence is what separates a defect from a bad day. One entry earns a change only when it names what it cost.
- Every change is the smallest edit that would have prevented the entry. A friction log is a machine for accreting rules, and a skill nobody can hold in context is worse than one with a gap in it.
