# Why

Answer "why does X work this way", "why we picked Y", design rationale, regressions, postmortems, and data-backed thresholds: query every evidence source the session can reach in parallel, then return a cited read on decisions and tradeoffs. For runtime behavior, use the [how](how.md) station.

Investigate the motivation and intent behind code. The companion [how](how.md) station answers what the code does and how it works. `why` answers what forces led to its shape.

Every spawn is a `general-purpose` agent told to write nothing, never `Explore`: investigators read whole threads and documents through the session's MCP tools, and the synthesizer spot-checks citations through them. Investigators take the explore role's model and the synthesizer the judgment role's ([SKILL.md](../../../SKILL.md#subagents)).

## Operating posture

Operate as a **careful, cautious, and precise investigator**. Be honest about what you know vs what you're inferring. Read [the epistemics framework](why/epistemics.md) for the full confidence framework and phrasing guide. The synthesizer must follow it.

## Step 1. Understand the target and the question

The **target** is usually a chunk of code, a pattern, a feature, or a named design decision. The **question** is usually a design rationale, a tradeoff, a motivating edge case, an external constraint, dead code, or a broad history sweep.

If the target is vague ("why do we do it this way?" with no clear referent), make your best guess from conversation context (open files, recent edits, what was just discussed). State your interpretation briefly so the user can redirect if you're off, then proceed.

## Step 2. Establish the code anchor

Before spawning investigators, build the seed context inline: file paths and line ranges, key symbols (functions, classes, constants), the last few commits touching the target, PR numbers from merge commits (pattern `(#1234)` in the subject line), and any linked ticket IDs. Run `git --no-pager blame -L <start>,<end> <file>` for last-touch commits, `git --no-pager log --follow -p -- <file>` for full history with patches through renames, `git --no-pager log --oneline -20 -- <file>` for recent commits with PR numbers visible, and `git --no-pager log -1 --format=%B <commit>` to extract PR numbers. Then pull the PR bodies and discussion for any substantive commit through the `git-provider` skill (on GitHub, `gh pr view <number> --json title,body,author,createdAt,mergedAt,labels,closingIssuesReferences,comments,reviews`). This anchor goes to every investigator and to the synthesizer.

## Step 3. Spawn parallel investigators

**Default to the full parallel investigation.** The goal is a complete coverage map, not a minimal one. Document the null, don't skip the search.

### Discovery

Before spawning investigators, list the evidence sources the session can reach: its MCP servers (tools named `mcp__<server>__*`, including deferred ones `ToolSearch` can load) and the skills that reach a source from the command line, such as the `ticket-provider` skill for the ticket tracker or the `sentry-cli` skill for error tracking.

Map each available source to one evidence category:

1. Source control history
2. Issue / ticket tracker
3. Long-form documents
4. Real-time team chat
5. Infrastructure observability
6. Error / exception tracking
7. Product analytics warehouse

Source control is always available through git and the `git-provider` skill. For the other six, classify using the server's name, its instructions, its tool names, and its resource descriptors. If a source could fit more than one category, choose the one matching its primary evidence. Record ambiguous cases in the coverage map.

Spawn one investigator per category that has a matching source, all in a single message so they run concurrently, each owning exactly one tool, MCP server, or skill. Don't ask one agent to cover multiple sources.

Each investigator's prompt is [the investigator prompt](why/investigator-prompt.md) filled in, plus:
- the category playbook `why/sources/<source>.md` for the selected source, adapted from the examples in [the source playbook](why/source-playbook.md)
- [the incident playbook](why/sources/incident-postmortem.md) **if the target code looks defensive** (null checks, retry logic, timeout handling, rate limiting, feature flags, egress guards, OOM handlers)
- the code anchor and the user's original question

### Investigator roster, one per available evidence category

Each category below is uniquely positioned to surface one shape of "why", shown after "Best at". Use it to know what to expect back, to name a gap when a category returns empty, and, only in the rare provably-irrelevant case, to justify a skip.

1. **Source control** (git history, PRs through the `git-provider` skill, code comments, tests). Always spawn, the only guaranteed source. Best at *implementation-time rationale captured during review*.
2. **Issue / ticket tracker** (the project's tracker through the `ticket-provider` skill here; elsewhere Linear, GitHub Issues, Plane, Shortcut). Best at *the product or business forcing function*. Strongest when the why is external to engineering.
3. **Long-form documents** (e.g. Notion, Confluence, Google Docs, Coda). Best at *long-form design rationale*, written out before it becomes code.
4. **Real-time team chat** (e.g. Slack, Discord, Microsoft Teams, Mattermost). Best at *real-time deliberation that never reached a doc*. Especially important when the source control, ticket, and doc paper trail is thin.
5. **Infrastructure observability** (e.g. Datadog, New Relic, Honeycomb, Grafana, Splunk). Best at *infrastructure and runtime reality that motivated the code*. Strongest when the target reacts to an infra signal (timeouts, retries, rate limits, circuit breakers).
6. **Error / exception tracking** (e.g. Sentry, Rollbar, Bugsnag, Airbrake). Best at *the specific exceptions and error trajectories that motivated defensive or corrective code*. Strongest for catch blocks, null guards, type checks, retries, and other defenses.
7. **Product analytics warehouse** (e.g. Databricks, Snowflake, BigQuery, ClickHouse, dbt, Redshift). Best at *product and data reality that shaped the code*. Strongest for flag-gated code, experiment-driven ships, data migrations, and "where did this number come from" questions.

### When to skip an investigator

Only with an **explicit, written justification** that goes in the final Sources Consulted. Two valid reasons:

- **No source is available for that category** in this session. Flag it as a gap, not a choice: "Real-time team chat skipped. No matching MCP available, so the conversational record was not searchable."
- **The source is provably irrelevant**, not just "probably irrelevant." A high bar: "Error / exception tracking skipped. Target is a build-time script with no runtime code path."

If your scope assessment suggests a single-commit trivial target where the PR description already contains the complete answer, you may answer inline **only after** confirming all seven available category searches would be redundant. Say so explicitly. This should be rare.

## Step 4. Synthesize

Spawn one synthesizer. It gets:
1. The investigator findings, including any null results and any categories skipped with justification
2. The code anchor
3. The user's original question
4. The text of [the epistemics framework](why/epistemics.md)
5. [The synthesizer prompt](why/synthesizer-prompt.md), filled in

## Step 5. Present

Present the synthesizer's output. You may lightly edit for clarity or add context from the conversation, but **do not rewrite the confidence language**.

## Output format

The structure is the one in [the synthesizer prompt](why/synthesizer-prompt.md): The Question, The Code in Question, What We Found, What We Can Reasonably Infer, Competing Hypotheses, What We Don't Know, Sources Consulted, Confidence Summary. Adapt as needed, but keep the confidence separation intact, and keep Sources Consulted as one line per investigator, including the ones that returned nothing or were skipped, with the reason.

After Sources Consulted, if the `why` question is a precursor to changing this code, convert the lineage findings into a Preserve / Change / Avoid / Risk constraint set for planning the change.

## Common failure modes to avoid

- **Recency bias**. Assuming the most recent commit is authoritative. The current shape is often the accretion of many earlier decisions. Trace back.
