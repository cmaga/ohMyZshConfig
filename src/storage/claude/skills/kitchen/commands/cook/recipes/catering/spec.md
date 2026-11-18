# Spec

Writes the functional spec from the approved plan: what the system must do, precisely enough for an agent to build and test against. It is written for agents; the user glances at it. It decides nothing the plan left open: such a choice goes to the user, and on their word into both documents.

1. **Map the parts.** The containers the system runs (web app, server, workers or scheduled jobs, databases, model services) and the outside services it depends on, how they talk, and what crosses each connection. A part is something you can point at in production; a module or a piece of work is not, and a large container lists its modules inside its own section.
2. **Write it** from the [spec template](../../templates/spec-template.md) to `<docs>/spec.md`. The functional requirements come from the plan's goals, each traced to one; each non-functional requirement carries a measurable bar. Then the parts with their behaviors (each citing the FR it serves), data, and tests (each citing the behaviors and NFRs it proves), the flows as mermaid sequence diagrams, the records, and a concrete starting value for every tunable.
3. **Check the wiring**, reading it end to end as an agent with no context:
   - Every part in the diagram has a section, and every section a node; every arrow is labeled and appears in the `Talks to` line of a part at one of its ends.
   - Every `Owns` names something no other part claims.
   - Every FR reaches a behavior, and every NFR a test.
   - Nothing undecided survives as a sentence, and nothing is deferred to scale: every part ships, starting from values that work at low volume.
4. **Attack it** with the [interrogate](../../stations/interrogate.md) station, the spec as its scope. A finding that tightens the spec folds in; one that would change the plan's direction goes to the user, one at a time.
5. **Show the user** what it specifies in a few lines, per [catering](../catering.md#talking-to-the-user). On their go, `kitchen.zsh order set <KEY> stage=implementation` and go on per [implementation](implementation.md).
