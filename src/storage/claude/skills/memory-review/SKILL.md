---
name: memory-review
description: Review auto memory and cut it down. Turns recurring skill lessons into proposed skill edits, then proposes moving out, promoting, or deleting other entries that no longer belong. Slash-invoked only; pass a skill name to review just that skill's lessons.
disable-model-invocation: true
---

# Memory review

Memory grows one write at a time and shrinks only here. Sessions file skill lessons under `## Skill: <name>` per [lesson format](lesson-format.md), and everything else by the global `memory-use` rule. This reads every project's memory for skill lessons and the current project's memory for everything else, and proposes what, if anything, leaves it.

Keep is the default. A lesson that keeps working stays, and a review that changes nothing is a correct outcome.

With a skill name as the argument, run Part 1 for that skill only and skip Part 2.

## Part 1: Skill lessons

Run once per distinct `## Skill: <name>` found in any `~/.claude/projects/*/memory/MEMORY.md`, or once for the skill named in the argument. None anywhere means nothing to do in this part: say so.

1. **Collect the skill's lessons from every project.** Auto memory is one directory per repository, so read the `## Skill: <name>` section of every `~/.claude/projects/*/memory/MEMORY.md` and each topic file it lists.
2. **Find the skill's source.** A global skill's source is `~/dev/personal/ohMyZshConfig/src/storage/claude/skills/<name>/`; a project skill's is `.claude/skills/<name>/` in that project's repository — the memory directory's name flattens the repository path, so confirm the path exists. When both exist, the copy the lesson's project defines is the one that run read. A skill with no source there (a plugin or built-in skill) is not actionable here: say so and keep its lessons.
3. **Set aside resolved lessons.** A lesson marked `Resolved:` whose change has shipped — it is in the deployed copy under `~/.claude/skills/<name>/` for a global skill, or on the project's base branch for a project skill — is proposed for deletion in step 6. One with a recurrence dated after the change shipped is a fix that did not take: group it with the rest. Keep one whose change has not shipped.
4. **Group by cause, not by wording.** Two lessons naming different files are one group when the same missing sentence produced both, and the same cause filed in two projects is one group. For each group, count sightings — each lesson's `Date` is one, and every date on its `Recurrences:` line is another — and note their spread in time.
5. **Rule each group.** A lesson marked `Declined:` stays out of the groups unless it has a recurrence dated after the decline.
   - **Defect** — the text is wrong, missing, or contradicts itself elsewhere. Two sightings, or one that names a cost worth the change.
   - **Anecdote** — one sighting, no cost past the moment. Leave it exactly where it is. It resolves by never recurring, and deleting it destroys the evidence its second sighting would need.
   - **Not the skill** — the run misread text that was clear, or the friction was really the code. Propose deleting it, unless its **How to apply** still prevents something.
6. **Present the groups before drafting anything**, defects first, then not-the-skill groups and shipped resolutions, one line each: what recurs, how many times, and the change you would make. The user picks.
7. **Read the surrounding text before writing a word of the fix.** A rule that already exists is a fix that did not take — the most important thing a review can find. A second copy of it elsewhere makes the skill worse; the defect is where the rule sits. Verify the lesson's claim against the file as it stands now — lessons age, and the sentence may already have changed.
8. **Draft each picked change** through the `claude-feature-authoring` skill, which owns the authoring rules. Edits land in the source from step 2.
9. **Show the rendered instruction, not the diff** — the text a future run will read, before and after.
10. **Resolve on approval.** Mark each acted-on lesson `Resolved: <commit subject or worktree path>` instead of deleting it, so it keeps working until the change ships; a later review deletes it at step 3. Delete the picked not-the-skill lessons and shipped resolutions: the topic file, its `MEMORY.md` line, and the section heading once the section is empty. A group the user declined stays where it is, with `Declined: <date>` and one line of why appended to each lesson, so the next review does not re-litigate it.

## Part 2: Everything else

1. **Classify every other entry in the current project's memory** — each `MEMORY.md` line, each line of any index file it links to, and each topic file no index links to — reading the topic file whenever its line does not settle it. Skip entries marked `Declined:` unless a recurrence is dated after the decline.
   - **Belongs elsewhere** — it holds something the `memory-use` rule's What Belongs Where table gives a home: ticket state, what merged, a decision or constraint. A lesson about how Claude works is not this class even when it names a constraint; only a bare fact moves.
   - **Promote** — a lesson with three or more dates on its `Recurrences:` line.
   - **Stale** — contradicted by the code, the tracker, or a newer memory.
   - **Duplicate** — says what another entry already says.
   - **Keep** — everything else, including every lesson still working.
2. **Present the proposals before changing anything**, grouped by class, one line each: the entry, what happens to it, and where it goes. Keep entries are not listed. The user picks. Append `Declined: <date>` and one line of why to each entry they decline.
3. **Apply each picked change.**
   - **Belongs elsewhere:** confirm its home holds it, and put it there first when it does not — the vault per the `knowledge-vault-use` rule, Jira through the `jira` skill. Then delete the entry.
   - **Promote:** draft the rule, skill, hook, or CLAUDE.md text through `claude-feature-authoring` and show the rendered text. Once approved, mark the entry `Resolved: <commit subject or worktree path>`; a later review deletes it once the change ships.
   - **Stale:** name what contradicts it, then correct or delete it.
   - **Duplicate:** fold it into the entry that stays.
4. **Leave `MEMORY.md` consistent:** every line points at a file that exists, and no line points at a deleted one.

## Rules

- Change nothing the user did not pick.
- Edit skill and rule sources in ohMyZshConfig or the project's repository, never their deployed copies under `~/.claude/skills/` or `~/.claude/rules/`, which the next deploy overwrites. Memory edits under `~/.claude/projects/` are this skill's job.
- Commit global config edits in ohMyZshConfig with `make lint` passing. Make project repository edits in a new worktree of that repository and leave them uncommitted; its own merge rules apply, and a dirty main checkout blocks other work. Never deploy — `make deploy-claude` is the user's call.
- Recurrence is what separates a defect from a bad day. One lesson earns a skill change only when it names what it cost.
- Every change is the smallest edit that would have prevented the lesson. Lessons are a machine for accreting rules, and a skill nobody can hold in context is worse than one with a gap in it.
