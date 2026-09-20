# The chain

A ticket whose spec is approved. Every component the spec carves is built and merged onto one integration branch, in waves. `manual` changes nothing here — the spec is the approval. Two things reach the user: the goal they paste to start, and a change of strategy or direction.

This Driver is the whole run; only Step 1's first item ran before it. The chain never merges to the base branch and never deploys: it ends with the whole spec on an integration branch the user runs, tests, and merges.

`<SPEC-TICKET>` is the ultra ticket; its description carries the spec's path, which resolves in the main checkout. `<COMPONENT-TICKET>` is one component's ticket.

Three roles: **you are the parent**, one per spec. A **manager** is the agent you dispatch per component — it runs this skill for its own ticket. You address managers; what they spawn is theirs.

## Driver

Hold almost nothing: the spec path, the wave plan, each component's status and returned report. **Dispatch every verification read** — parent-side reading fills the context, compacts, and the next brief carries figures nobody re-measured. The integration branch and the tracker are the record; your context is a cache. A chain that lost its session is resumed by running this Driver again on the same ticket.

File your own skill lessons as they happen, and each one a manager sends you as it lands — per [lesson format](../../memory-review/lesson-format.md).

Once step 2 has the waves, seed the task tracker with one item per wave, `Integrate wave N` after each, and `Hand back`.

1. **Run the main-checkout gate once, here** (Prerequisite 4 in [SKILL.md](../SKILL.md)).

2. **Derive the waves.** Topologically sort the `needs` edges of the dispatch graph — the first `yaml` fence in the spec; nothing outside it is a node. Wave 1 is every component with no edges; a component joins the first wave by which everything it needs is merged. An edge naming an undefined component, or a cycle, is a spec defect: say which edge and stop — nothing has been created yet.
   - Every `needs` empty, or no graph at all: sort the tracker's blocks graph over the component tickets instead; halt only when neither exists. **Say which source you used in every brief.**
   - Cut the waves over the tree the work lands in — a restructure works in the *source* tree, which a spec of destinations may not mention. If answering *what can run in parallel now* takes a measurement, the wave plan is broken.
   - An unowned source directory carries one deep lease per wave. A **deep** lease restructures it; a **shallow** lease only follows moves through it. Two deep leases collide; shallow merges first and deep rebases onto it. Name every lease in the brief.
   - A wave is as wide as the sort makes it. Split one only if managers visibly queue.
   - A component marked `exclusive: true` is a wave of one, run first in its wave's place; two of them are two waves, in spec order.
   - **Then read each component's status off the repo, never memory.** An existing `spec/<SPEC-TICKET>` branch means a resumed chain. A component is **merged** if `git diff spec/<SPEC-TICKET> <branch>` is empty over the paths it touched, **in flight** if it has a branch or worktree with work not in, **unstarted** otherwise. **Do not test ancestry** — a squash, amend, or rebase makes `merge-base --is-ancestor` say no for landed work. Where branch and ticket disagree, the branch wins; move the ticket.

3. **Hand the user the goal, and wait for it.** Nothing has been created yet. Draft it per [unattended runs](../SKILL.md#unattended-runs):

       /goal every component of <SPEC-TICKET> merged into spec/<SPEC-TICKET> with the full suite green on that branch

   Say in the same message that `CLAUDE_CODE_GOAL_CHECKIN_MINUTES=10` is worth setting for a run this long.

   **Then arm the out-of-process wake-up** — the one run that does. A usage limit clears the goal silently and nothing else restarts the chain. Set a periodic check, cadence longer than a wave, that re-dispatches if nothing is live. **Record its id in the scratchpad** — [hand-back](#hand-back) takes it down. After any interruption, ask the user to re-arm the goal.

4. **File the spec's tickets, under an epic.** Create the epic first, named for the spec and linked to the ultra ticket — never convert the ultra ticket into one. File one child per `## C-N:` section, plus one per **Post-deploy** item and per hole the spec left as a ticket, each naming its section. **Read the epic's children and the ultra ticket's links first** and match to `C-N` ids — top up, never duplicate. An **Open question** still in a component's section is a spec defect: settle it per [escalation](#escalation) before its wave opens; only one that goes to the user withholds that wave — run the waves before it.

5. **Take the integration branch and a worktree on it.** Local, never pushed until [hand-back](#hand-back). Cut only if step 2 found none:

       git branch spec/<SPEC-TICKET>            # only when it does not already exist
       git worktree add <path> spec/<SPEC-TICKET>

   This is the one working tree you own — the assembled spec, what the user tests at the end. **Do not enter it — drive it by path and `git -C`.** Entering pins the session to one tree and this Driver needs reach across the repo.

6. **Run each wave**: dispatch its components in parallel, wait for all, integrate one at a time, then open the next. File the wave's lessons before opening the next. **Waiting is work you do, not a turn you end** — draft the next wave's briefs, recompute the collision set, fold reports into the record. Hand back only for a question the spec cannot answer, or when the chain is finished. Skip a component step 2 found merged. Dispatch waits for the previous wave — managers branch from the integration branch and need the work in it.

## Dispatching a wave

Spawn one `general-purpose` agent per component in one message, `model` opt omitted. Each prompt is the [manager brief](../templates/manager-brief.md), filled in. **Fill every section, including the ones that are empty** — `none` is a statement; an absent section is an order nobody gave.

**Compute the collision set; never guess it:**

    comm -12 <(git diff --name-only <BASE> <branchA> | sort) \
             <(git diff --name-only <BASE> <branchB> | sort)

Run it at dispatch and every time a manager reports; send each manager the current do-not-touch set.

A finished component is a branch, a green suite on it, and a passed review gate — or a blocker it names. Anything else ended its turn early: send it back with `SendMessage` naming what is missing; if that fails, replace per [escalation](#escalation). **Expect early returns** — managers return believing their workers are still running.

A manager reports by returning; messages carry skill lessons only. Every dispatch prompt says: end the turn and return the question as your report; never park waiting.

A manager that cannot load this skill or create its worktree halts the chain. Never build the component yourself.

## Integrating a wave

Components build in parallel and integrate one at a time. Serial integration is the backstop for collisions the set above missed: textual ones surface as rebase conflicts, semantic ones as a red suite, while the manager is still alive.

**You touch one working tree — your own.** Never a component's: a rebase belongs to whoever owns the tree, and conflicts are resolved by resuming that manager.

Once every component in the wave has returned, in wave order:

1. **Resume its manager**: rebase onto `spec/<SPEC-TICKET>` and run the full suite. Nothing to fetch or push — the ref is local and shared.
2. **Check it against its acceptance list** — [done-when](done-when.md), before the merge. Green and reviewed does not mean the contract holds.
3. **Green** — merge in your own worktree (a fast-forward), run the full suite there yourself, then transition the ticket to done via the `jira` skill.
4. **Conflict, red, or an acceptance line that fails** — send back what failed and resume. **Three non-green returns**, counting step 1's rebase, and the chain halts on it. A question only the user can answer costs no round and pauses the chain per [escalation](#escalation); a red suite alongside it waits with it.

Leave every component's worktree and branch standing until [hand-back](#hand-back) — the resume path needs them.

**A failure in an already-merged sibling's tests is a contract disagreement.** The rebasing component never edits a test it did not write: it reports which assumption it breaks and what it believes correct. Read the test yourself, decide from the spec; where the spec is silent, resume the sibling's manager for its side before going to the user. **The manager that owns a test edits it** — resume that one, integrate that as its own step, then send the rebasing component back.

**A defect found in one component is a shape to check in every sibling of its wave, in the same turn** — delegated to each sibling's own manager.

No reviewer sees cross-component interaction; a green suite after rebase is the bar. Nothing here has seen CI — running the suite after every merge is what lets a CI failure at hand-back name its component.

## Escalation

The chain parent answers what the spec answers. A manager held one section; you hold the whole document and every sibling's report. Resume the manager with `SendMessage` in preference to replacing it. Answering costs a round.

- **Replace instead of resume when the manager's context is spent.** Its branch is the handoff artifact, not the transcript. Say so in the report.
- **If the resume itself fails, replace — not a halt.** Fresh manager, same ticket: original prompt, your answer, the report it replaces. Two failed resumes is the cap. Note the restart.
- **A deferral is not a question.** The bar is proof the work cannot be done, naming the blocker: *a thing that must happen first is a plan; a thing that cannot happen is a blocker.* A routing label a component writes against its own section is a deferral — reject on sight.
- **Decide it yourself first.** Only what genuinely needs it goes to the escalation agent in [SKILL.md](../SKILL.md#what-stops-attended). A decision may amend the spec: write it into the spec in your worktree and send it to every manager it touches. Only a change of strategy or direction goes to the user. A review gate's `escalate` takes the same route.

**Asking pauses the chain; it does not end it.** Let the wave's siblings finish and integrate, then ask — the question, the section it overturns, what it blocks — and stop the turn. When they answer, carry on from where the wave stopped; ask them to re-arm the goal if the pause was long.

## Halting

For a component that cannot finish, never for a question. Let its wave's siblings finish and integrate; the next wave does not open, whatever its `Needs` say. A component withheld before its wave opened (step 4) means nothing in that wave is built.

A halt is not [hand-back](#hand-back): no PR. **Cancel the wake-up from Driver step 3.** Leave everything standing and report in prose — which component stopped, on what, which waves never started, what is left — not the exit report. Give the user your worktree's absolute path.

## Hand-back

When the last wave integrates:

1. **Read the whole spec against the finished branch. Dispatch this reading** — it is the largest read in the run. Three checks only this scale can make:
   - **Census the components** from the dispatch graph and ask the branch whether each is there — not whether a manager reported it. Note where each ticket disagrees with the branch; step 7 acts on it.
   - **Re-run any acceptance evidence that was stored rather than executed.** A stamp older than the tip is not a pass.
   - **Test the premise the spec opens with.** The problem the spec was written to kill belongs to no component's acceptance list.

   [done-when](done-when.md)'s hygiene binds every check here.
2. **Classify every deviation before repairing any.** **Improvement** — keep the code, repair the spec. **Regression** — fix the code. **Missing** — a gap the size of a component is not repaired here; name it, say what closing it takes, leave the call to the user.
3. **Plan the regressions, then fix them yourself.** Write the list first — it is what the report owes. **No implementation subagents past this line.**
4. **Run the review gate** over your fixes, up to the five-round backstop in [SKILL.md](../SKILL.md). Then the full suite in your worktree, and step 1's checks again against the repaired branch.
5. **Retire the planning artifacts**, in order — never on a [halt](#halting):
   - Dispatch `vault-scribe-agent` to write one vault note per `## C-N:` section, from the **final** spec.
   - Attach the spec file to the ultra ticket via the `jira` skill.
   - Delete the spec from the repo on this branch.
6. **Push the branch and open the one PR** — `git push -u origin spec/<SPEC-TICKET>`, then the `git-provider` skill. Red checks are reported, not fixed.
7. **Move every component ticket to match the branch** — the branch is the truth.
8. Run [cleanup](cleanup.md) for every merged component. Your own integration worktree stays.
9. **Hand over your worktree, and cancel the wake-up** by the id recorded at Driver step 3. Give the user the worktree's absolute path and the command that starts the app.
10. **Report.** One [exit report](../templates/exit-report.md) for the whole spec: what the user can do, what to test, which component stopped or never started, every deviation with its verdict, every red CI check. Assumptions, deferrals, and unfixed findings collapse into one [loose-end tracker](exit.md#the-loose-end-tracker); the three-task cap applies.
