# Ultra

Produces a spec — an agreed description of how the system should behave — before anything is planned or built. Runs in the worktree and ends with that spec merged on the ultra ticket.

## The document

Lives in the project's drafts directory (`docs/drafts/` unless the project uses another), with a companion `execution-notes.md` beside it.

- **Opens with context and principles.** Why this spec exists, and the non-negotiables every later section traces back to. After a failure these are the lessons the failure taught; greenfield, they are the invariants the system must hold.
- **One section per flow or subsystem**, in whatever structure the user asks for. Structure is theirs — offer one, reorganize on request without arguing for the original.
- **Every premise carries its falsifier** — the observation that would prove it wrong. "We sell to casual flow" is a belief; "if our fills at a price lose while the public tape's trades at that price win, the premise is dead" is a spec.
- **State behavior so it could be tested.** A claim no test could contradict is not a specification.
- **Unresolved things stay unresolved**, marked `[NEEDS CLARIFICATION]` with what specifically is undecided. A named open question is a deliverable; a silent assumption is a defect.

## Altitude

The spec describes what the system does and why, never how it is built.

Test: a sentence naming a file, class, function, library, or ticket key belongs elsewhere. Move it to `execution-notes.md` — along with build order, work breakdown, parked/resolved markers, and absorbed-ticket mapping. Nothing is deleted; it stops living in the spec, and it seeds the implementation plan.

## The co-write loop

The spec is written with the user, one question at a time. This is ultra's core mechanic — a large design surface stays tractable only when consumed serially.

1. Track every open question via `TaskCreate` as it surfaces. The list is both the agenda and the resumption state.
2. Work one question at a time. Discuss until the user is satisfied, then stop and wait — they say `next` to advance. Never open the next question unasked.
3. **Nothing enters the document until the user says to fold it in.** Discussion and drafting are separate acts; drafting early makes the user review prose when they wanted to think.
4. When a question needs real data — a third party's actual API behavior, an existing system's real numbers — dispatch the probe as a background workflow and keep discussing the next question. Fold the result in when it lands.
5. Resuming after a break or in a new session: re-read the document and the open-question list. They are the state; do not reconstruct it from conversation memory.

## Adversarial gate

Run it per section as sections settle, and once over the whole document before wrap-up. Holes found after the document is cohesive are holes found late.

- **Attack lenses** — one agent per lens, each playing an adversary who profits from the design being wrong. Each finding: a concrete scenario with numbers, why the spec as written does not stop it, and the smallest change that closes it.
- **Precedent research** — for each mechanism the spec invents, hunt the named established equivalent (fan out on `RESEARCH_FANOUT_MODEL`). "Bet so you survive" is Kelly sizing; adopting the named mechanism inherits its literature, its known failure modes, and its parameter guidance.
- **Verify before reporting.** Check every finding against the document text. Kill the ones the spec already covers and the ones that are speculative rather than reachable. Present only survivors.
- Each surviving hole becomes a named scenario in the spec's test section — that section is what makes the spec testable before a line of code exists.

## Cohesion pass

Before wrap-up, read the document end to end as one artifact rather than the sum of the sessions that produced it.

- Every section traces to a principle from the opening.
- Nothing violating the altitude test survives.
- Terms mean one thing throughout; the same concept is not named two ways.
- **Deploy order is settled and stated** — what must ship before what, and which pieces cannot survive being half-deployed. It is spec-level because it describes the system's behavior in intermediate states, and it orders the follow-on tickets.

## Wrap-up

Ultra does not run [Exit](exit.md) — there is no code to verify or review.

1. Present the spec: what it decided, what stayed `[NEEDS CLARIFICATION]`, and the deploy order. Plain language, 5-15 lines, with the absolute path to the document.
2. Dispatch `vault-scribe-agent` to write the durable note from the spec's content, so the vault note lands in the same PR.
3. Create the PR via the `git-provider` skill. `execution-notes.md` stays in the drafts directory until the last follow-on ticket closes.
4. Transition the ultra ticket via the `jira` skill.
5. Decomposition checkpoint — see Ultra in [SKILL.md](../SKILL.md).
