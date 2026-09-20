# Ultra

Produces a spec — an agreed description of how the system should behave — before any code. Drafted with the user in a worktree, merged on the ultra ticket. Reserved for decisions that must be thought through with no code in the room.

## The process

The spec is written with the user, one question at a time. Steps 2-8 are a loop: adversarial review that changes strategy returns to step 2; the spec is done when a pass produces no strategic change, or after three passes. The cap is hard.

1. **Identify the premise.** What are we working on, and why now? Establish the goal before any solution talk.

2. **Build the solution space.** Start from the user's intuition, then research precedent online. Synthesize, then discuss.
   - **Do not dump text on the user.** Break findings into talking points tracked with `TaskCreate` — that list is the agenda and the resumption state.
   - One point at a time. Discuss until the user is satisfied, then stop — they say `next`.

3. **Map the systems.** Turn the strategy into components and the edges between them. Draw the map before writing a contract. Name what each component owns, and check that any two that could build at the same time own disjoint things. **Ownership means the directories the work happens in, not only the ones it produces** — a relocation collides in the source tree. Discuss one question at a time.

4. **Draft.** Start from the [spec template](../templates/spec-template.md), written to the project's drafts directory as `<name>-spec.md`. Map first, then each component's contract. The markdown is the only authoritative copy; the Artifact in step 7 is a view.

5. **Fold in only on the user's word.** Discussion and drafting are separate acts.

6. **Probe in the background.** When a question needs real data, dispatch it as a background workflow and keep discussing. Queue the result in the tracker. Brainstorming is messy — guiding the user back to the order the system flows in is your job.

7. **Cohesion pass.** Read the draft end to end and fix what only shows at that scale. Then check the template's wiring:
   - Every component is buildable alone and closes with its Tests.
   - Every `Needs` line matches its `needs` in the dispatch graph, names a defined component, and the edges hold no cycle.
   - **The dispatch graph has one entry per `## C-N:` heading and none without one.**
   - **At least one component declares a non-empty `needs`** — else state in the spec that ordering lives in the tracker.
   - A grouping is not a component: no graph entry, no `Needs` line, never `## C-N:`.
   - Every `Owns` names something no other component claims.
   - The map's nodes and arrows match the sections and their edges.
   - No component body describes how a thing is built, beyond a named mechanism it adopts and what it buys.
   - No component carries an edge it does not need — for each, name what it cannot do until that component is merged.
   - A component whose work lands across the tree carries `exclusive: true`; no other does.
   - **Nothing the spec declines to close survives as a sentence.** A named hole is a component if doable now, a ticket if not. A hole with no owner is a defect the spec agreed to in advance.

   **Then publish the view.** Load `artifact-design`, author the document as HTML into the scratchpad as `<name>-spec.html`, publish with the `Artifact` tool; the map as a `mermaid` block. Republish to the same path whenever the markdown changes — never edit the Artifact directly.

8. **Adversarial review.**
   - **Attack lenses** — one agent per lens, each an adversary who profits from the design being wrong. Each finding: a concrete scenario with numbers, why the spec does not stop it, the smallest change that closes it.
   - **Precedent research** — wherever the spec describes a scheme in its own words, hunt the named established equivalent (fan out on `RESEARCH_FANOUT_MODEL`).
   - **Verify before reporting.** Kill findings the spec already covers and ones that are speculative.
   - Each surviving hole becomes a named scenario in its component's **Tests**.
   - **Route by size.** Minor tightening folds in directly. Anything altering strategy returns to step 2, one finding at a time, folded in only on the user's word.
   - On the third pass nothing returns to step 2: remaining findings become tickets and the spec ships.

## Wrap-up

1. Present the spec: what it decided, the components, what is still open — open questions and post-deploy items counted separately. Plain language, 5-15 lines. Lead with the republished Artifact link; give the repo path on its own line. Say that **merging the PR is what starts the build** and files the tickets.
2. Create the PR via the `git-provider` skill.
3. Transition the ultra ticket to "in review" via the `jira` skill, and record the spec's repo path on it — the [chain](spec-run.md) reads it there.
4. **File nothing.** A spec under review is still moving. The [chain](spec-run.md) files every ticket at its Driver step 4, on a merged spec. Say what is coming: the count of component tickets, post-deploy items, and holes left as tickets.
