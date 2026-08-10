# Auto chain

`auto` on a ticket whose spec is already written and approved. Every chunk the spec carves is built, merged, and deployed in its deploy order, and the user is not consulted again until the chain ends.

The spec is the approval artifact. It stands in for Step 3 and for Step 4's research and routing on every chunk it owns — that intent was agreed when the spec was.

## Driver

Your session drives and holds almost nothing: the spec path, the chunk order, each chunk's status and returned report. Keep it that way. Dispatching each chunk is what keeps your own context from compacting halfway through the spec.

1. **Order the chunks** from their `Needs` lines into one deploy order. A cycle, or a `Needs` naming something the spec does not define, halts before anything is built.
2. **Confirm every chunk has a ticket**, filing the missing ones via the `jira` skill. The spec's approval is the go-ahead for these — it is the one place auto files tickets.
3. **Dispatch one agent per chunk**, in order, waiting for each before starting the next:

   > Run the `dev-workflow` skill for `<TICKET>` in auto mode. It is chunk `C-N` of the approved spec at `<absolute path>`; that section is your contract. Skip Step 3 and Step 4's research and routing — the spec settled them. Do Step 4.2's codebase-fit pass against `C-N`, pick the tier, then run from Step 5 to a deployed ticket. Anything `C-N` marks `Awaiting` an earlier chunk's deployment is now answered by that deployment, which is live: read the answer off the running system and record it in the plan as `[ASSUMED: ...]` rather than stopping for the user. Return your exit report.

   An agent that cannot load this skill or enter a worktree halts the chain — say so plainly. There is no fallback where you build the chunk yourself; that is the context the dispatch exists to avoid spending.

## Halting

The first chunk that does not finish stops the chain where it stands. Whatever the `Needs` lines say, later chunks were specified against a system that includes this one, and a half-deployed spec you cannot unwind costs more than a stopped one.

Leave the failed chunk's PR and worktree alone.

## Report

One report at the end, not one per chunk. Each chunk's exit report was written for a reader who was not there — collapse them into a single [exit report](../templates/exit-report.md) for the whole spec: what is live now, which chunk stopped and why, which never started, and every assumption, deferral, and unfixed finding the chunks accumulated along the way.
