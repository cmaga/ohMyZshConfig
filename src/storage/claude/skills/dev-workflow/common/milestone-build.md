# Milestone build

An epic whose spec has merged. The spec says what each component owns and how it is proven; the build reaches that end state in milestones, each one a slice that runs. Nothing builds the finished product first.

You are the only coordinator. You run workflows; their agents return to the script, spawn nothing, and message nobody. Two things reach the user: the milestone list to approve, and a change of strategy. `manual` changes nothing here.

The build never merges to the base branch and never deploys. It ends with the whole spec on one integration branch, pushed as one PR.

## Driver

Hold almost nothing: the spec path, the plan path, the current milestone, its workflow run id. The integration branch is the record — a milestone is done when its proof commit is on it. A build that lost its session is resumed by running this Driver again on the same epic.

Seed the task tracker with Gather, Plan, Approve, then one item per milestone once the plan exists, then Hand back.

1. **Main-checkout gate** — Prerequisite 4 in [SKILL.md](../SKILL.md).
2. **Integration branch and worktree.** Local, never pushed until hand-back. Cut only what is absent:

       git branch spec/<EPIC>
       git worktree add "$(git rev-parse --show-toplevel)/.claude/worktrees/spec-<EPIC>" spec/<EPIC>

   This is `<tree>`. Drive it by absolute path and `git -C`; never enter it. Every agent in the build works in this one tree. Proven milestones: `git -C <tree> log --oneline --grep '^\[<EPIC>\] M-'` — resume at the first one missing.
3. **Gather.** Run the Workflow tool with `scriptPath` `~/.claude/skills/dev-workflow/scripts/gather.workflow.js` and args `{spec, tree, components: ["C-1", ...], model: CODE_FANOUT_MODEL}` (omit `model` when the lever is unset). One read-only agent per `## C-N:` section maps it onto today's code: what moves, what adapts, what is new and the spec sentence forcing it, every check today's code performs there, and what it deletes or rewrites. Then a sweep reads every file leaving and lists each behavior in it, claimed by a component or `unclaimed` — the behavior no component's section reaches, which a spec-first reading never finds. A build that deletes nothing has no sweep. Its questions go to [Escalation](#escalation) before planning; one the code or the spec answers you decide, and record it as `[ASSUMED: ...]` at the top of the plan.
4. **Plan the milestones** into `<tree>/.claude-artifacts/workflows/dev-workflow/milestones.md` from the [milestone plan template](../templates/milestone-plan-template.md), after `F="$(git rev-parse --git-common-dir)/info/exclude"; grep -qxF '.claude-artifacts/' "$F" || echo '.claude-artifacts/' >> "$F"`.
   - **M-1 is the thinnest path through the new system that runs end to end.** For a restructure: the new shape starts and serves one real path while the old system still works.
   - Each later milestone adds one capability across whatever components it touches, and ends runnable.
   - Every milestone names its **proof**: one command that fails before the milestone and passes after.
   - **A proof runs what ships.** The real entry point, on the settings a fresh install gets (code defaults and the shipped config templates, never test-only overrides), over data shaped like real use — its ages, volumes, and refresh cadence. Doubles only at external boundaries; a double that re-implements the system's own logic proves the double. Where the project can replay recorded real data, the last milestone of each capability proves on it.
   - **A milestone is cheap enough to throw away whole.** The first one most of all: it is where a wrong plan costs least to find.
   - **Move before writing.** Each task says what it moves, adapts, or writes new, from the gather. New code only where a contract sentence forces it, quoted.
   - Every check today's code performs, and every behavior the sweep found, lands on a task: moved, adapted, or retired with its reason. An `unclaimed` behavior is retired only by a spec sentence or your recorded decision, never by silence.
   - A task is what one worker holds. Batch small changes; never one task per file. Tasks with no `After` edge between them own disjoint files.
   - Every `Owns` line and every Tests scenario lands in exactly one milestone.
5. **Approve.** Dispatch `plan-review-agent` with the spec, the gather results, and the plan. Ask for: an `Owns` line or Tests scenario no milestone reaches, an M-1 that does not run end to end, two parallel tasks sharing a file, new code where a move exists, a check or swept behavior with no fate, a leaving file with no row, a proof that runs on test-only settings or doubles the system's own logic. Fix what it finds. Then present one line per milestone — what becomes runnable, and its proof — marking the ones you recommend pausing after: M-1 always, then any milestone a wrong turn would make expensive to unwind. The user picks the pauses; write each as `Pause: yes` in the plan. Then the two lines that start the build:

       /effort ultracode
       build <EPIC>

   Typing them is the approval. Ultracode keeps workflows opted in across the turns each milestone's result starts. The build takes no `/goal`: a workflow runs until it is done, and its result starts your next turn.

   Then stop. This list is the build's one gate; the user's corrections go into the plan before anything is built.
6. **Build each milestone** in order, per below. File the last milestone's skill lessons before opening the next.
7. [Hand back](#hand-back).

## Building a milestone

1. Record the tip: `git -C <tree> rev-parse HEAD` is `base`.
2. Run the Workflow tool with `scriptPath` `~/.claude/skills/dev-workflow/scripts/milestone.workflow.js` and args `{epic, spec, tree, base, projectBase, milestone, decisions: {}}`. `projectBase` is the project's base branch — the behavior the review compares against. `milestone` is the plan's `M-N` section as data: `{id, title, proof, scaffold, tests, tasks: [{id, title, files, after, card}]}`. The script runs scaffold, failing tests, workers in `After` order, one review, one fold, one verify. It returns on finishing or on the first question.
3. **A returned question** goes to [Escalation](#escalation). Resume with `resumeFromRunId` and the answer under `decisions[<key>]`, the key the result names; agents before it replay from cache and it re-runs.
4. **Check the milestone yourself** — never on an agent's word, under [done-when](done-when.md)'s hygiene. Run its proof, the tests of every changed file, and every earlier milestone's proof. `git -C <tree> grep -n NotImplementedError -- <the milestone's files>` prints nothing.
5. **Findings left after verify.** A bug that loses data, money, or a safety check, or a fix that broke something already passed: resume once with `decisions.fold` naming it. Everything else is a [triage](exit.md#triage) candidate.
6. **Mark it proven:** `git -C <tree> commit --allow-empty -m "[<EPIC>] M-N proven: <proof>"`.
7. **`Pause: yes`** — stop and show the user what now runs: the proof's output, how to try it by hand, and anything step 5 left open. Open the next milestone on their go. Otherwise open it now.

A milestone the plan got wrong — its proof cannot pass without work another milestone owns — is a plan defect: amend the plan, say so in the report, carry on. A change to what the spec says is an escalation.

## Escalation

You answer what the spec answers; you hold the whole document and every result. Decide it yourself first. Unattended, what you cannot decide goes to the escalation agent in [SKILL.md](../SKILL.md#what-stops-attended); only a change of strategy or direction reaches the user. A decision that amends the spec is written into the spec in `<tree>` in the same turn.

**A deferral is not a question.** A thing that must happen first is a plan; a thing that cannot happen is a blocker.

Asking pauses the build: let the running workflow finish, then ask — the question, what it overturns, what it blocks — and stop. When they answer, carry on; after a long pause, ask them to type `build <EPIC>` again.

## Halting

A milestone whose workflow stops twice on the same stage, or whose proof still fails after the extra fold, halts the build. No PR. Report in prose: which milestone stopped and on what, which are proven, what is left, and `<tree>`'s absolute path.

## Hand-back

When the last milestone is proven:

1. **Read the whole spec against the finished branch. Dispatch this reading** — it is the largest read in the run. Three checks only this scale can make:
   - **Census the spec**, not the plan: each `Owns` line and Tests scenario, asked of the branch. Then the plan's table of behavior in code the build deleted or rewrote: each row's fate, asked of the branch.
   - **Re-run any acceptance evidence that was stored rather than executed.** A stamp older than the tip is not a pass.
   - **Test the premise the spec opens with.** The problem the spec was written to kill belongs to no milestone's proof.
2. **Classify every deviation before repairing any.** **Improvement** — keep the code, repair the spec. **Regression** — fix the code. **Missing** — a gap the size of a component is not repaired here; name it, say what closing it takes, leave the call to the user.
3. **List the regressions, then fix them yourself.** No implementation subagents past this line.
4. **Run the [review gate](exit.md) over your fixes**, then the full suite in `<tree>` — the build's one full run, owed whether or not there were fixes — then step 1's checks again.
5. **Retire the planning artifacts:** dispatch `vault-scribe-agent` to write one vault note per `## C-N:` section from the **final** spec; attach the spec to the epic via the `jira` skill; delete the spec from the repo on this branch.
6. **Push and open the one PR:** `git -C <tree> push -u origin spec/<EPIC>`, then the `git-provider` skill. Red checks are reported, not fixed.
7. Move the epic to In Review via the `jira` skill.
8. **Report.** One [exit report](../templates/exit-report.md) for the whole spec: what the user can do, what to test — each milestone's proof is the list — every deviation with its verdict, every red CI check. Give `<tree>`'s absolute path and the command that starts the app. Loose ends collapse into one [loose-end tracker](exit.md#the-loose-end-tracker).

`cleanup <EPIC>` after the PR merges removes `<tree>` and the branch.
