# Implementation plan

Turns the spec into deployments of phased tasks, and puts every call an agent would otherwise make alone to the user now, while a correction costs a sentence instead of code. This is the last stage with the user before the deployments are filed. The plan follows the [implementation plan template](../../templates/implementation-plan-template.md), at `<docs>/implementation-plan.md`.

## Deployments

A new deployment starts only when the next change cannot ship until the previous one is live in production:

1. **Old and new must coexist across a deploy.** A schema or API change whose readers and writers deploy separately, or whose clients the project does not deploy, runs expand, migrate, contract.
2. **Data must exist in production first.** A migration or backfill runs on real data before the code that relies on it.
3. **Something outside the repo happens in between**: infrastructure, config, a third-party setup, or a flag turned on once the deploy is checked.

Everything else rides in the earliest deployment it can, so with no such boundary the work is one deployment. Each becomes one ticket, one order, and one PR to the base branch, whatever its size.

## Steps

1. **Gather.** For each part in the spec, dispatch an `Explore` agent in the background, told not to edit files, to map it onto today's code: what moves, what adapts, what is new and the spec sentence that forces it, every check today's code performs there, and what it deletes or rewrites. When the work deletes or rewrites files, one more agent per 15 leaving files lists each behavior in them, claimed by a part or `unclaimed`. Every check and swept behavior gets a fate in the plan's tables; an `unclaimed` behavior is retired only by a spec sentence or the user's word.
2. **Draft the deployments** by the rule above. Each names the rule that forced it and its proof: one check that fails before it and passes after, running what ships (the real entry point, the settings a fresh install gets, data shaped like real use, doubles only at external boundaries).
3. **Walk the decisions with the user, along the data.** Take the spec's flows in the order data moves through the system (what comes in, what happens to it, what is stored, what users see), and follow each one hop by hop through the parts it crosses. At each hop, the calls a worker would otherwise make alone there come up in turn: an interface or data shape, a name or a module's place, error handling, a library, the pattern to copy, an edge case the spec leaves to implementation.
   - **Settle the obvious ones yourself**, from the code, the spec, or the project's conventions, and leave them out of the conversation.
   - **Bring every other call to the user where the flow meets it**, with your recommendation and its basis, so they follow the system as it runs rather than a list. How the walk moves matters more than how each call is put: keep to the flow, and name where in it you are.
   - **Record each call as a `DEC-N`**, numbered in walk order, the settled ones with what settled them. One that fixes a shared interface states the contract itself (signature, data shape, errors).
4. **Draft the phases and tasks**, each citing the DECs it relies on. A call that surfaces only now goes to the user at its place in the flow, as in step 3.
   - **Phase 1 of each deployment is the skeleton**, one task: the modules, the types, the signatures and stubs with their behavior stated, the pattern later tasks copy, and the locked tests for the spec's tests this deployment owes. It produces every contract the later phases build on.
   - **A later task** is small enough for one worker in one session. It moves before it writes: new code only where a spec sentence forces it, quoted in its Work line.
   - **A task goes in the first phase after every task it depends on**, so the phases are layers of the task graph.
   - **One task per phase by default.** A phase holds more only with a Fan-out line naming why its tasks share no file, no interface a DEC fixes that both write, and no producer and consumer pair, and never more than three. Coupled work stays in one task: splitting it is where parallel agents fail.
   - **Coverage** sends every FR, NFR, behavior, and test in the spec to the task that delivers it.
5. **Check it.** Run `node ~/.claude/skills/kitchen/commands/cook/scripts/check-plan.mjs <docs>/implementation-plan.md <docs>/spec.md` and fix every line it prints. Then dispatch a `general-purpose` agent on the judgment role with the spec, the gather's results, and the plan. Ask for: a part's `Owns` or test no task reaches, a task whose Files miss a file it must change, a skeleton missing a contract a later task needs, new code where a move exists, a check or swept behavior with no fate, a proof that runs on test-only settings or doubles the system's own logic, and coupled work split across a fan-out. Fix what it finds.
6. **Show the user the plan**, each deployment and its phases at a glance, per [catering](../catering.md#talking-to-the-user). The deployments are filed from here.
7. **File the epic.** If this ticket is an Epic, it is the epic. Otherwise create one through the `ticket-provider` skill, named for the plan and linked to this ticket, move this ticket with the `merged` moment, and move the epic with the `start` moment. Then `kitchen.zsh order set <KEY> epic=<EPIC>`.
8. **File the deployments**, the first one first. Each starts at its skeleton, which the scheduler never starts, so none runs before the rest exist. For each deployment:
   1. A ticket under the epic through the `ticket-provider` skill: its summary the deployment's title, its description the deployment's section, linked "is blocked by" the deployment before it.
   2. Its fields, each text field written to a file first: `intent` (what goes live, and for whom), `done_when` (the proof, then each coverage row its tasks owe), `station` (every Files path of its tasks, as a JSON array), `after` (the key of the deployment before it, as a JSON array, or `[]`), and `summary` (what the gather found for its parts).
   3. `kitchen.zsh order new <DEPLOYMENT-KEY> status=ready mode=<mode> recipe=<its Recipe> review=true "review_why=catering deployment: you are the last check" catering=<EPIC> docs=<docs> deployment=<n> stage=skeleton intent=@<file> done_when=@<file> station=@<file> after=@<file> summary=@<file>`, where `<mode>` is the first of `auto`, `guided`, and `manual` that `kitchen.zsh modes` lists.
9. **Hand on.** Write every deployment's key to a file as a JSON array, then run `kitchen.zsh order set <KEY> stage=building after=@<file> "question=Every deployment has merged: run /kitchen cook <KEY> to wrap up."` and `kitchen.zsh order set <KEY> status=ready pid=0`. Each deployment starts with its skeleton, worked with the user: offer to start the first now (`take <DEPLOYMENT-KEY>` in this session), and say that `kitchen.zsh status` lists each one once it can start. End your turn.
