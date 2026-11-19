# Lever inventory

Last updated: 2026-11-18 · Method updated: 2026-11-18

> **Effort is not auditable.** A dispatched agent's record carries its model and never its
> effort (measured: 0 of 61 agent records in one run). So every effort lever below is
> unverifiable after the fact — an effort lever that silently failed to bind would look
> exactly like one that worked. `description` prefixes set by the dispatcher are what
> make a dispatcher and its lever value identifiable at all.

> **`inherit` is the model's effort, not the session's.** Since Claude Code 2.1.317 a
> subagent on a different model from the session runs at that model's saved `modelSettings`
> level or its default. A Sonnet worker under an Opus session at xhigh runs at Sonnet's level.

> Cost: cost per task relative to Opus 5.5 at high effort, from Artificial Analysis
> Intelligence Index v5.0.1 (read 2026-11-18). Cost per task counts the extra turns and
> tokens a model spends, which per-token price misses. Take every ratio from one index
> version, since the figures shift between versions. They are list-price costs on Artificial
> Analysis's tasks, not Claude Code with its cache, so read them as relative. Haiku 5.5 is
> priced at its over-100K-prompt rate (5x its base), since Claude Code agents cross 100K.
> DeepSeek figures are its own bill at max effort and draw nothing on the Claude limit; its
> list prices per 1M are flash $0.30/$1.20 and pro $1.32/$3.96 at peak, halved off-peak.
> Ratios are not additive points.
> Aliases bound (Claude Code 2.1.327): opus=Opus 5.5 ($4/$20, cache read $0.20; default
> effort medium, and top-level effortLevel does not reach it, so it needs a modelSettings
> key), fable=Fable 5.2 ($8/$40, cache read $0.20; default effort medium), sonnet=Sonnet 5.5
> [1m] via the remap below ($2/$10, cache read $0.10), haiku=Haiku 5.5 ($0.10/$0.50 up to a
> 100K-token prompt, $0.50/$2.50 beyond; default effort medium);
> deepseek-flash=DeepSeek-V4.1-Flash-1017, deepseek-v4-pro=DeepSeek-V4-Pro-0813.

> Perf: Terminal-Bench 4.0, agentic coding, independently run — Artificial Analysis at the
> effort named, Vals.ai (as of 2026-11-18, effort not stated) in parentheses; read 2026-11-18.
> Never rank options on the composite Intelligence Index or on vendor-run scores: the
> composite puts Fable 5.2 at high (62) above Opus 5.5 at max (59), where Terminal-Bench
> puts them level at 59.6.

> **Sonnet is `sonnet[1m]`.** A bare `sonnet` agent under an Opus parent gets the 200k
> window, and Sonnet agents on large inputs died of it. Frontmatter takes the suffix;
> per-dispatch `model` opts cannot, so `levers.py` passes `sonnet` and the settings
> remap `ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5-5[1m]` binds the alias to Sonnet 5.5
> with 1M (probed 2026-10-04, 2.1.289); re-point it in `06-deploy-claude.zsh` when a new Sonnet ships.

> **Behind the claude-proxy (`oc`), two defaults change.** Claude Code turns MCP tool search
> off for a non-Anthropic base URL, which put 48k tokens of MCP tool schemas into every
> request, and runs background requests (titles, summaries, web-page digests) on the
> session model instead of Haiku. `oc` in `zsh/aliases.zsh` restores both with
> `ENABLE_TOOL_SEARCH=true` and `ANTHROPIC_DEFAULT_HAIKU_MODEL` (probed 2026-10-12, 2.1.296);
> re-point that Haiku ID when a new Haiku ships, since the `haiku` alias resolves to it.
> A DeepSeek worker runs from any `oc` session: Claude Code loads every tool
> upfront for a DeepSeek model even with tool search on, and DeepSeek accepts deferred tools
> and tool-reference blocks. It rejects the `tool_addition` blocks that announce a
> late-connecting MCP server's tools (422), which the proxy moves into `tools` (probed
> 2026-10-21, 2.1.306).

> **Four accounts.** `personal`, `work` (gsi) and `ms` each have their own limit, and `amazon` (Bedrock, no
> limit) has none; each has its own value on every row but 1, 2 and 3, whose native homes they share. The code and other family types bind through
> each account's own agent frontmatter, which deploy builds per config dir;
> every other type binds through dispatch opts.

| # | Lever | Where | Options | Cost (x opus/high, per unit work) | Perf (TB 4.0) | Impact (0-100) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Session model | `/model`, `--model`, `ANTHROPIC_MODEL` (live) | fable<br>opus<br>sonnet[1m]<br>haiku | at high:<br>fable 2.62x<br>opus 1.00x<br>sonnet 0.47x<br>haiku 0.23x | at high:<br>fable 59.6 (65.2)<br>opus 56.6 (65.2)<br>sonnet 43.9 (64.1)<br>haiku 21.7 (36.4) | 100 |
| 2 | Session effort | `/effort` or the `/model` picker (live, hand-set; saves per model under `modelSettings` in user settings — a top-level `effortLevel` there does not reach Opus 5.5, and `max` is never saved), `--effort`, `CLAUDE_CODE_EFFORT_LEVEL` | max<br>xhigh<br>high<br>medium<br>low | max 2.90x<br>xhigh 1.75x<br>high 1.00x<br>medium 0.71x<br>low 0.28x<br>(Opus 5.5) | max 59.6<br>xhigh 59.6<br>high 56.6<br>medium 52.5<br>low 31.3<br>(Opus 5.5) | 50 |
| 3 | Advisor model | `advisorModel` in `~/.claude/settings.json` (unset), `/advisor`, `--advisor` (live). Off entirely under `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1` | off<br>fable<br>opus<br>sonnet | Per call, the advisor's rate on the full transcript, uncached; nothing between calls. Must rank at or above the model it advises, or it is not attached: an Opus 5.5 session takes only opus or fable. Subagents inherit it and pass the same check, so DeepSeek agents never get it. Anthropic API only, so it passes the proxy only on Claude routes | as row 1 | 35 (est.) |

Types: `lever-state.json` `types`, a model and an effort per account for each; the Subagents table in SKILL.md maps every role to one. A type's cost and score depend on its model and effort together:

| Model (Vals.ai) | max | xhigh | high | medium | low |
| --- | --- | --- | --- | --- | --- |
| fable (65.2) | 7.67x · 59.6 | 4.29x · 61.6 | 2.62x · 59.6 | 1.10x · 55.1 | 0.90x · 54.5 |
| opus (65.2) | 2.90x · 59.6 | 1.75x · 59.6 | 1.00x · 56.6 | 0.71x · 52.5 | 0.28x · 31.3 |
| sonnet[1m] (64.1) | 2.90x · 63.6 | 1.18x · 57.1 | 0.47x · 43.9 | 0.23x · 29.8 | 0.15x · 20.7 |
| haiku (36.4) | 0.59x · 32.8 | 0.36x · 29.3 | 0.23x · 21.7 | 0.13x · 15.2 | 0.06x · 12.6 |
| deepseek-flash[1m] (31.8) | 0.17x · 33.8 | — | — | — | — |
| deepseek-v4-pro[1m] (14.1) | 0.51x · — | — | — | — | — |

Haiku is dominated at high and above: Sonnet at medium or high costs no more and scores higher.

| Type | Roles | Binds through | Model options | Effort options | Impact (model / effort) |
| --- | --- | --- | --- | --- | --- |
| judgment | judgment, escalation | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 60 / 30 (est.) |
| review | adversary, verify, taste | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 60 / 35 |
| code | code | `worker-agent` frontmatter, built per account | fable<br>opus<br>sonnet[1m]<br>haiku<br>deepseek-v4-pro[1m] (proxy; dominated by flash)<br>deepseek-flash[1m] (proxy) | inherit (the model's own)<br>max<br>xhigh<br>high<br>medium<br>low | 30 / 30 |
| critical code | hardest, contract, code on a `## Critical` path | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 45 / 20 (est.) |
| research | explore | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 8 / 3 (est.) |
| other family | other family | `deepseek-flash-agent` frontmatter, built per account | deepseek-v4-pro[1m] (proxy; dominated by flash)<br>deepseek-flash[1m] (proxy) | none | 15 (est.) |
| general | anything else | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 40 / 15 (est.) |

DeepSeek: flash costs DeepSeek dollars and nothing on the Claude limit; pro costs 3x flash and scores below it on the same index (23 vs 33) and on Vals.ai, so flash dominates it until pro is updated. Both fail in a session not launched through `oc`. Always set them with `[1m]`: a bare DeepSeek name gets a 200K window (probed 2026-09-27).

Impact rationale per lever: [lever-impact.md](lever-impact.md)

Excluded — do not re-add: fast mode, context ceiling, skill frontmatter overrides, alwaysThinkingEnabled (thinking already defaults on across current models), fallbackModel (availability, not cost), the vault agents' `model:` (pinned to opus, 2026-10-28), CLAUDE_CODE_SUBAGENT_MODEL_FORCE / maxEffortLevel / deniedModels (global overrides and caps on the never-set list in roster.md), CLAUDE_CODE_SUBAGENT_EFFORT (one effort for every subagent that names none, shared by every account; a type binds its effort through its own opts or frontmatter), the fixed models in skills outside the kitchen (memory-review's blind trial on sonnet, capture-documentation's contradiction judge on haiku, skill-eval's opus/xhigh runs).

Retired, do not re-add: the tester, scoping, and scoping fan-out models (rows 9, 11, 7f; intake traces causes with the how and why stations, and the bug review is the interrogate station), per-card worker models (every worker runs on the code type), the per-role levers (review, worker, escalation, and the research, code, review and parent fan-out levers; replaced by the types 2026-11-18), and the milestone build's rows 13a-13h (catering's deployments are ordinary orders).
