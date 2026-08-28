# Ultra

Produces a spec — an agreed description of how the system should behave — before any code is written. Drafted through co-work with the user in a worktree, and merged on the ultra ticket.

Reserved for the most load-bearing work there is: decisions complex enough that they have to be thought through at the highest level, with no code in the room.

## The process

The spec is written with the user, one question at a time. This is ultra's core mechanic — a large design surface stays tractable only when consumed serially.

Steps 2-8 are a loop. Adversarial review that changes strategy returns to step 2, and the spec is done when a pass produces no strategic change — or after three passes, whichever comes first. The cap is hard: an adversarial fleet will always find something, and past the third pass the findings are polish, not risk reduction.

1. **Identify the premise.** What are we working on, and why now — a system failed, a design needs rethinking, something new is being reasoned about from scratch? Establish the high-level goal before any solution talk; it determines which strategic directions are even available.

2. **Build the solution space.** Start from the user's intuition, then research precedent and established recommendations online. Synthesize, then discuss.
   - **Do not dump text on the user.** A wall of prose is unsortable — they will skim it and agree to something they did not read.
   - Break findings into individual talking points and track them with `TaskCreate`. That list is both the agenda and the resumption state.
   - Work one point at a time. Discuss until the user is satisfied, then stop and wait — they say `next` to advance. Never open the next question unasked.

3. **Map the systems.** Turn the agreed strategy into components — the systems the work divides into, and the edges between them. Draw the map before writing a single contract: the picture is what makes a decomposition arguable, and the contracts fall out of it once the shape is right. Name what each component owns, and check that any two that could build at the same time own disjoint things — that is the whole lever against two managers colliding on the same ground. **Ownership means the directories the work happens in, not only the ones it produces.** For anything that relocates code those are different trees, and it is the source tree that collides: a decomposition drawn over destinations can look perfectly disjoint while both components spend the wave draining the same directory nobody was said to own. Discuss it the way everything else is discussed, one question at a time.

4. **Draft.** Start the document from the [spec template](../templates/spec-template.mockup.html). The map goes in first; each component's contract is written under it.

5. **Fold in only on the user's word.** Nothing enters the document until they say so — this governs the drafting loop; step 8 says what its own findings may fold in unasked. Discussion and drafting are separate acts; drafting early makes the user review prose when they wanted to think.

6. **Probe in the background.** When a question needs real data — a third party's actual API behavior, an existing system's real numbers — dispatch it as a background workflow and keep discussing the next point. Queue the result in the tracker and take it up when it lands.
   - High-level brainstorming is messy. The user will forget things, branch into tangents, and attack whichever piece surfaces in their mind first. That is expected. Guiding them back to the order the system actually flows in is your job, not theirs.

7. **Cohesion pass.** The draft was written piecewise as the conversation progressed. Read it end to end as one artifact and fix what only shows at that scale — contradictions, organization, a term meaning one thing in one section and something else in another. Then check the template's wiring:
   - Every component is buildable alone and closes with its Tests.
   - Every `Needs` matches its section's `data-needs`, names a component the spec defines, and the edges hold no cycle.
   - **At least one component carries `data-needs` at all.** A spec where none does is un-waveable from its own text — the check that every `Needs` matches is silent when there are none of either, and the chain that builds it then hand-derives an ordering from prose without anything saying so. Either give the components their edges or state in the spec that ordering lives in the tracker, so the fallback is a decision rather than a discovery.
   - A grouping carries no component markup: no `id`, no `data-needs`, no `Needs` line.
   - Every `Owns` names something no other component claims.
   - The map's nodes and arrows match the sections and their edges.
   - No component body describes how a thing is built, beyond a named mechanism it deliberately adopts and says what it buys.
   - No component carries an edge it does not need. For each one, name what it cannot do until that component is merged, and drop the edge when you cannot — this is where a spec silently over-serializes.
   - Any component whose work lands across the tree rather than downstream of a sibling carries `data-exclusive="true"`, and no other component does.

8. **Adversarial review.** Edge cases are where systems die, and planning generates assumptions faster than data retires them. This step asks what can actually happen at each strategic piece, and whether the spec accounts for it.
   - **Attack lenses** — one agent per lens, each playing an adversary who profits from the design being wrong. Each finding: a concrete scenario with numbers, why the spec as written does not stop it, and the smallest change that closes it.
   - **Precedent research** — wherever the spec describes a scheme in its own words, hunt the named established equivalent (fan out on `RESEARCH_FANOUT_MODEL`). "Bet so you survive" is Kelly sizing; adopting the named mechanism inherits its literature, its known failure modes, and its parameter guidance.
   - **Verify before reporting.** Check every finding against the document text. Kill the ones the spec already covers and the ones that are speculative rather than reachable. Present only survivors.
   - Each surviving hole becomes a named scenario in its component's **Tests** — that section is what makes the spec testable before a line of code exists.
   - **Route by size.** Minor tightening folds in directly. Anything altering the strategy returns to step 2, remaps if it moves a boundary, and is discussed one finding at a time, each folded in only on the user's word.
   - On the third pass, nothing returns to step 2. Findings that still matter become tickets against the components they touch, and the spec ships.

## Wrap-up

1. Present the spec: what it decided, the components and what each one makes true, and what is still open — counting open questions and post-deploy items separately, since only the first kind is actionable now. Plain language, 5-15 lines, with the absolute path to the document.
2. Create the PR for the spec via the `git-provider` skill.
3. Transition the ultra ticket to "in review" via the `jira` skill, and record the spec's repo path on it — the spec is the deliverable, its PR is now open, and a [chain](spec-run.md) later reads that path off this ticket.
4. Create one ticket per component via the `jira` skill, each linked to the ultra ticket and naming its C-N section rather than copying it. Approving the spec is the user's go-ahead to file these — but search open tickets for each component first and link an existing one instead of duplicating it. A **Post-deploy** item gets its own follow-up ticket, linked to the ultra ticket like the rest, stating the evidence it is waiting on — the spec has to be live before anyone can answer it. Anything living only in the spec is invisible work.
