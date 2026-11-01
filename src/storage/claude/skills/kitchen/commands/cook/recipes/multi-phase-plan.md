# Multi-phase plan

Work that spans phases or several PRs, planned as a checklist before any of it is built.

Contents: steps 1 to 7, Verification, Verify skill, the plan skeleton.

**You own the plan, not the code. The plan is a checklist an owner runs box by box and the user audits from the evidence.** The plan is the deliverable. Do not implement.

1. When the change is one or two files with an obvious approach, skip the plan. Say so and stop.
2. Settle open questions by prototype before you write. Run the [prototype](prototype.md) recipe for each. Keep the branch, the SHA, and the screenshots for Appendix A. Take to the user only a product or preference call that no run can settle, with options (the [never block on the human](../../../dependencies/principles/never-block-on-the-human.md) principle, and [SKILL.md](../../../SKILL.md#autonomy) for how).
3. Explore in subagents, each on its role from [SKILL.md](../../../SKILL.md#subagents) (the [guard the context window](../../../dependencies/principles/guard-the-context-window.md) principle). Each returns file pointers, conventions, test commands, and entry points. No inlined dumps.
4. Copy the skeleton below into the plan file and fill every placeholder. Unless the user names a path, write the file to `.claude-artifacts/workflows/kitchen/<slug>-plan.md` in the working tree, after keeping that directory out of git: `F="$(git rev-parse --git-common-dir)/info/exclude"; grep -qxF '.claude-artifacts/' "$F" || echo '.claude-artifacts/' >> "$F"`. Keep every heading and every sub-block in the order shown. One section per PR. One PR is one change with its own evidence (the [sequence verifiable units](../../../dependencies/principles/sequence-verifiable-units.md) principle).
5. Write under the [technical writing](../stations/technical-writing.md) station in full, then the [unslop](../stations/unslop.md) station. The body is one Diátaxis mode, how-to. Appendices hold explanation and reference. Each heading states the task or the finding. No long dashes. No mid-sentence colons.
6. Run `node ~/.claude/skills/kitchen/commands/cook/scripts/check-plan.mjs <plan.md>` and fix every line it prints (the [encode lessons in structure](../../../dependencies/principles/encode-lessons-in-structure.md) principle).
7. Hand back. Post the plan path and the script's output. With an order, the user's answer at the pass was the go: attach the plan to the ticket through the `jira` skill, run the plan's File the tickets boxes, then `kitchen.zsh order close <KEY>`. Each ticket filed meets intake on its own, so a call in it still reaches the user at the pass.

**Verification.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked (the [prove it works](../../../dependencies/principles/prove-it-works.md) principle). That sentence is the verification rule. Every verification block opens with it. The live block is mandatory. Ten lanes at the PR head drive the real surface through the project's verify skill, per the [swarm](../stations/swarm.md) station, on the verify role. Each lane is one box with a concrete scenario, the screenshot it saves, and its pass predicate. One lane is the **Regression lane against trunk.** It runs the same load-bearing scenario on trunk and head. If trunk does not have the feature, the lane records that fact and gates the behavior the diff adds plus the end state the user waits for instead of inventing a trunk result. The perf gate is dual-sided. Trunk and head must both produce the named metric. If trunk lacks the feature, also isolate the work the diff adds and set an absolute budget for that work plus the end-to-end state the user waits for. Do not claim a ratio between unlike scenarios. The perf block names the metric, the interleaved probe, the trunk baseline measured first, and the rule with the number that fails. A PR that changes an interaction is review-gated. The user reviews it with screenshots and a video before merge, so its order carries `review=true`. A PR that changes no interaction writes `**Review gate.** None. <PR id> is not review-gated.` and no boxes under it.

**Verify skill.** Each lane drives the surface through the project's verify skill (`.claude/skills/verify*`), else the `run` skill. Browsers go through Playwright MCP. A PR that touches two surfaces gets lanes on both. A surface the verify skill cannot drive is a risk in Appendix C, and its live block still names how each lane drives it.

````markdown
# <Program> plan

<Under ten lines. What changes, for whom, the rule the program enforces, and the PR ids in order.>

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, a test run, or a SHA. The body is a how-to. The appendices explain and record.

Each PR section becomes one Jira ticket and one order, worked through the kitchen skill's `cook` command. <Which PR ids are review-gated and wait for the user before merge.>

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

## Program checklist

### File the tickets

- [ ] On the go, file one Jira ticket per PR section through the `jira` skill. Its summary is the section's heading, and its description is the section.
- [ ] Link each ticket to every ticket it depends on with an "is blocked by" link, per this dependency graph.
  - [ ] <PR id> and <PR id> are independent and first.
  - [ ] <PR id> after <PR id>.
- [ ] Run `kitchen.zsh order new <KEY>` for each ticket. Intake holds a ticket while an open ticket blocks it and serves it once its blockers are done.
- [ ] Hold the file boundaries. <PR id or class> touches only `<glob>`. Each order's `station` lists them.
- [ ] Hold the review gate. <PR ids> change an interaction. Their orders carry `review=true`, so they wait for the user's review with screenshots and a video before merge.

### PR mechanics, for every PR

- [ ] Each order runs the kitchen skill's `cook` command, which opens its PR per its open a PR recipe.
- [ ] Run the repo's lint and typecheck once before the PR-facing push. Push with hooks on.
- [ ] Hold the quality gate per the kitchen skill's `taste` command before review.
- [ ] Triage every review bot comment skeptically, checking each claim against the code before acting on it.
- [ ] Rebase onto the base branch before the PR opens, and again only when `kitchen.zsh sample <KEY>` prints `rebase`.

### Verdict and merge, for every PR

- [ ] Each ticket's Verify blocks are its order's done-when. The quality gate runs them at the PR head, the live lanes in parallel per the swarm station, by agents that did not write the code.
- [ ] A full set of lanes runs once, at the code-ready head. Another full set runs only for new behavior, a redesign, or a large new diff. A rebase, a merge-conflict resolution, or a minor fix gets a single verifier at the new head, and a wording-only change gets none. Two or more audit lanes, each with its own focus, read the diff and the receipts and distrust the PR body.
- [ ] Block a PR only for a problem a run shows at its head, or a doc line the PR made wrong. A failure on trunk behavior in a lane marked `Regression lane against trunk.` is recorded against trunk and does not block the PR. A new head gets a fresh verdict, except for results that stay valid under the patch-id rule of the kitchen skill's merge recipe.
- [ ] <Who merges. The order merges once its verdict is clean at its head, or waits for the user's approval when review-gated.>

### Boot recipe, for every live lane

Each live lane runs in its own worktree at the PR head. Drive through the project's verify skill.

- [ ] `git fetch origin <head-branch> && git checkout <head SHA>`.
- [ ] <Start the backend and the surface on the lane's own port and data directory, per the verify skill's Launch. Wait for ready.>
- [ ] <Deliver input only through the verify skill's Drive commands. Name the read-only diagnostics.>
- [ ] Save every screenshot to `<scratchpad>/swarm-<pr-id>/worker-<n>/<slug>.png` and return the paths with the report.

## <Task as a verb phrase> (<PR id>)

**Depends on.** <PR id, or None.>

**Files.**

- [ ] Edit `<path>`.
- [ ] Create `<path>`.
- [ ] Delete `<path>`.

**Build.**

- [ ] <One change. Name the symbol and the file.>

**You see.**

- [ ] <One observable result, with the exact log line or screen state.>

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] <Test file and the case it gains.> Run `<command>`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `<verify role model>` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Run <the same load-bearing scenario> at trunk and head. If trunk lacks the feature, record that and gate <the behavior the diff adds plus the end state the user waits for>. Save `<slug>.png`. Pass when <predicate>.
- [ ] Lane 2. <Scenario.> Save `<slug>.png`. Pass when <predicate>.
- [ ] Lane 3. <Scenario.> Save `<slug>.png`. Pass when <predicate>.
- [ ] Lane 4. <Scenario.> Save `<slug>.png`. Pass when <predicate>.
- [ ] Lane 5. <Scenario.> Save `<slug>.png`. Pass when <predicate>.
- [ ] Lane 6. <Scenario.> Save `<slug>.png`. Pass when <predicate>.
- [ ] Lane 7. <Scenario.> Save `<slug>.png`. Pass when <predicate>.
- [ ] Lane 8. <Scenario.> Save `<slug>.png`. Pass when <predicate>.
- [ ] Lane 9. <Scenario.> Save `<slug>.png`. Pass when <predicate>.
- [ ] Lane 10. <Scenario.> Save `<slug>.png`. Pass when <predicate>.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. <What is measured at both trunk and head. If trunk lacks the feature, also name the diff-added work and the end-to-end state the user waits for.>
- [ ] Probe. <The command or procedure, run at trunk and at the head, interleaved. Both sides must produce the metric.>
- [ ] Baseline. Record the trunk <value> first.
- [ ] Rule. <Head against trunk, with the number that fails. If the scenarios differ, add absolute budgets for the diff-added work and the user-visible end state instead of an invalid ratio.>

**Review gate.** The user reviews before merge.

- [ ] Copy lane <n> screenshots into `<media path>/<pr-id>-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of the change on a lane. Save it as `<media path>/<pr-id>-review.mp4`.
- [ ] Attach the screenshots and the video to the PR. Stop at merge-ready. Wait for the user's approval.

**Merge.**

- [ ] A clean verdict at the exact head SHA.
- [ ] Review bot triage done.
- [ ] `kitchen.zsh sample <KEY>` prints `no`.
- [ ] <The order merges through the cook command, or waits for the user's approval when review-gated.>

## Close the program

- [ ] Every box above is checked with its evidence.
- [ ] Reply to the user with what merged, each PR's verdict, and what is left.

## Appendix A. Prototype evidence

<Each open question a prototype answered, with the branch, the SHA, and the artifact links. Each question that stays unproven.>

## Appendix B. Alternatives rejected

<Each approach weighed and why it lost.>

## Appendix C. Risks

<Each risk with the PR it lands in and what the owner watches.>

## Appendix D. Links and reading list

<Docs to read before editing. Which PRs get the how station and the interrogate station. The trail per the show me your work station.>
````

**Reply:** the plan path, the PR ids with their dependencies and the review-gated set, what the prototypes proved and what stays unproven, and the check script's output.
