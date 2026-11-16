# Investigation

A read-only question: how does X work, why was Y built this way, are we sure about Z, should we do X or Y.

**You own the answer. Plan, route, write.**

Investigation requests are read-only. They produce a cited explanation or a recommendation, not a code change. There is no PR and no quality gate.

1. Route through the [how](../stations/how.md) station. For motivation questions, also route through the [why](../stations/why.md) station.
2. Throughput checkpoint stays one line: `throughput checkpoint: n/a, read-only investigation`.
3. Any number you measure to answer it goes through the [benchmark checklist](../stations/benchmark-checklist.md) station first, before you report it. At the least, run each side 5 times and report the median and range, however large the gap.
4. A recommendation between options also says what stays the same under each, and how you checked that, test for test.
5. Produce the how-shaped output (Overview / Key Concepts / How It Works / Where Things Live / Gotchas), or a recommendation with a tradeoffs table if the request is a decision between alternatives.
6. Apply the [unslop](../stations/unslop.md) station to the reply.
7. With an order, post the reply as a comment on the ticket through the `ticket-provider` skill, the answer first, then the evidence. With the user here, give it to them too.
8. File one ticket through the `ticket-provider` skill for each change the answer leads to, naming the change and the recipe that would build it, such as [bug fix](bug-fix.md) or [feature](feature.md), and record each with `kitchen.zsh filed <KEY> <TICKET> <WHY>`. With the user here, ask which to file first. Open no order for them: each enters the line when the user takes it. Then run `kitchen.zsh order close <KEY>`. The investigation ends in its answer and the tickets it files.

No PR, no [follow a PR](follow-a-pr.md), no architect station unless the investigation precedes a code change. If it does, say what the change is in the reply.

**Reply:** the investigation output, each claim cited at the lines that show it, not the enclosing function. For "are we sure?" answers, include your real judgment with reasons. Push back if the premise is wrong (see [SKILL.md](../../../SKILL.md#autonomy)).
