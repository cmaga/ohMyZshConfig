# Ultra

Produces a spec, an agreed description of the system to build, before any code. Drafted with the user in a worktree, merged on the ultra ticket. Reserved for decisions that must be thought through with no code in the room.

The spec is an architecture document: the real parts of the running system, how they talk, what each must do, and the decisions taken. It is not a build plan. Milestones are planned from it by [the milestone build](milestone-build.md), after it merges.

## The process

The spec is written with the user, one question at a time. Steps 2-8 are a loop: adversarial review that changes strategy returns to step 2; the spec is done when a pass produces no strategic change, or after three passes. The cap is hard.

1. **Identify the premise.** What are we working on, and why now? Establish the goal before any solution talk.

2. **Agree the shape first.** Before any detail, lay out the whole system end to end in a few lines (what comes in, what happens to it, what the user sees, how it improves) and the principles it rests on, and get the user's agreement. Details are refined in the order data flows through that shape, never before it is agreed.

3. **Build the solution space.** Start from the user's intuition, then research precedent online. Synthesize, then discuss.
   - **Do not dump text on the user.** Break findings into talking points tracked with `TaskCreate`; that list is the agenda and the resumption state.
   - One point at a time. Discuss until the user is satisfied, then stop; they say `next`.
   - While the user iterates on a draft or page, make each change, say what changed, and stop. They say when it is done.
   - When the system stores data it will learn from or be judged by, research the data model before drafting it.

4. **Map the running parts.** Name the containers the system runs (web app, server, workers or scheduled jobs, databases, model services) and the outside services it depends on, then how they talk and what crosses each connection. A part is something you can point at in production; a responsibility, module, or piece of work is not a part, and a large container lists its modules inside its own section. Discuss where a new container is warranted, what it costs to run, and where its data lives. Draw the map before writing any section.

5. **Draft.** Copy the [spec template](../templates/spec-template.html) to the project's drafts directory as `<name>-spec.html` and fill it in that order: summary, why, how it works in one paragraph, facts, terms, the container diagram, a sequence diagram for each flow that matters, one section per part, what the system records, key decisions with what each rejected, and what is left for implementation planning. Load `artifact-design` and `artifact-diagramming` first. The HTML file is the only copy: publish that same file with the `Artifact` tool and republish it after every change. Never keep a second copy in another format.

6. **Fold in only on the user's word.** Discussion and drafting are separate acts.

7. **Probe in the background.** When a question needs real data, dispatch it as a background workflow and keep discussing. Queue the result in the tracker. Brainstorming is messy; guiding the user back to the order the system flows in is your job.

8. **Cohesion pass.** Read the page end to end as a reader with no context and fix what only shows at that scale. Then check the template's wiring:
   - The first screen says what is being built and why.
   - Every container in the diagram is a circle with its own section, every outside service a dashed box with its own section, and every section has a node.
   - Every arrow is labeled, passes through no box, and appears in the `Talks to` line of a part at one of its ends; every `Talks to` entry has an arrow.
   - No section is a piece of work or a module; each could be pointed at in production.
   - Every `Owns` names something no other part claims.
   - Every part closes with its tests.
   - Every key decision names what it rejected.
   - No section describes code-level detail, beyond a decision the spec deliberately takes.
   - **Nothing undecided survives as a sentence.** A choice that does not change behavior goes under implementation planning; a value real data must tune gets a concrete starting value under starting values; a gap the size of a part is a part if doable now, a ticket if not.
   - **Nothing is deferred to scale.** Every part ships in the first release and can be exercised by its first users; a capability that only pays off with volume still ships, starting from values that work at low volume.

9. **Adversarial review.**
   - **Attack lenses:** one agent per lens, each an adversary who profits from the design being wrong. Each finding: a concrete scenario with numbers, why the spec does not stop it, the smallest change that closes it.
   - **Precedent research:** wherever the spec describes a scheme in its own words, hunt the named established equivalent (fan out on `RESEARCH_FANOUT_MODEL`).
   - **Verify before reporting.** Kill findings the spec already covers and ones that are speculative.
   - Each surviving hole becomes a named scenario in its part's tests.
   - **Route by size.** Minor tightening folds in directly. Anything altering strategy returns to step 3, one finding at a time, folded in only on the user's word.
   - On the third pass nothing returns to step 3: remaining findings become tickets and the spec ships.

## Wrap-up

1. Present the spec: what it decided, the parts, what is left for implementation planning and after launch, counted separately. Plain language, 5-15 lines. Lead with the Artifact link; give the repo path on its own line. Say that **merging the PR is what starts the build** and files the epic.
2. Create the PR via the `git-provider` skill.
3. Transition the ultra ticket with `transitions.review` via the `jira` skill, and record the spec's repo path on it; the epic carries it on.
4. **File when the spec merges, never before**; a spec under review is still moving. On the merge, in this run or the next run of this ticket: create the epic, named for the spec, carrying its path, linked to this ticket. If this ticket is already an Epic, it is the epic. File no children. Each after-launch item and each hole the spec left as a ticket is a standalone ticket linked to the epic, naming its section. Then move this ticket with `transitions.merged`. [The milestone build](milestone-build.md) runs from the epic.
