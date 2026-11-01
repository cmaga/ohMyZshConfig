# Runtime forensics

Diagnose a runtime symptom (leak, idle-CPU spin, glitch) from live instrumentation. The deliverable is a diagnosis, not a fix.

**You own the diagnosis. Instrument the live process, don't theorize from source.** The deliverable is a cited diagnosis, not a fix.

1. Capture the live signal on the matching surface, through the project's verify skill (`.claude/skills/verify-*`), else the `run` skill: a CPU profile for a spinning process, a heap snapshot for a leak, a CDP trace for a visual glitch. A real artifact, not a guess.
2. Reduce the artifact to the smoking gun: the function on the hot path, the retainer chain from the leaked object to a GC root, the loop firing without input. Parse large artifacts in a subagent (the [guard the context window](../../../dependencies/principles/guard-the-context-window.md) principle), and keep the reduced finding in the main thread. Each subagent takes its role from [SKILL.md](../../../SKILL.md#subagents).
3. Prove the mechanism before believing it. Inject instrumentation via CDP eval on the running process, or hotfix the live code without reloading, to confirm the hypothesis cheaply.
4. Map the finding back to source: file, symbol, the line that allocates or schedules.
5. Throughput checkpoint stays one line: `throughput checkpoint: n/a, read-only forensics`.
6. With an order, post the reply as a comment on the ticket through the `jira` skill and run `kitchen.zsh order close <KEY>`.

**Reply:** the signal captured, the reduced finding, how you proved the mechanism, the source location, artifact paths. No fix unless asked. Once the cause is known, recommend the [bug fix](bug-fix.md) or [perf](perf.md) recipe for it.
