# Lever inventory

Last updated: 2026-11-18 · Method updated: 2026-10-04

> **Effort is not auditable.** A dispatched agent's record carries its model and never its
> effort (measured: 0 of 61 agent records in one run). So every effort lever below is
> unverifiable after the fact — an effort lever that silently failed to bind would look
> exactly like one that worked. `description` prefixes set by the dispatcher are what
> make a dispatcher and its lever value identifiable at all.

> Cost column: cost per task relative to Opus 5.5 at high effort, from Artificial Analysis
> Intelligence Index v4.3.2 (read 2026-09-28). Cost per task counts the extra turns and
> tokens a model spends, which per-token price misses. Take every ratio from one index
> version, since the figures shift between versions. They are list-price costs on Artificial
> Analysis's tasks, not Claude Code with its cache, so read them as relative. Model ratios
> are at high effort, except Haiku 5.5 (read 2026-10-21): max is the only effort listed, and it is
> priced at the over-100K-prompt rate, since Claude Code agents cross 100K ($0.21 per task x 5,
> against Opus 5.5 max $5.98 / 3.29; 0.12x below 100K). DeepSeek figures are its own
> bill at max effort and $0.30/$1.20 rates (off-peak halves it), and draw nothing on the
> Claude limit. The types reuse the row 1-2 ratios. Ratios are not additive points.
> Aliases bound (Claude Code 2.1.283): opus=Opus 5.5 ($4/$20, cache read $0.20; default
> effort medium, and top-level effortLevel does not reach it, so it needs a modelSettings
> key), fable=Fable 5.1, sonnet=Sonnet 5.5 [1m] via the remap below, haiku=Haiku 5.5 on 2.1.296 ($0.10/$0.50 up to a
> 100K-token prompt, $0.50/$2.50 beyond; default effort medium);
> deepseek-flash=DeepSeek-V4.1-Flash, deepseek-v4-pro=DeepSeek-V4-Pro-0813.

> Perf column: Terminal-Bench 4.0, agentic coding, independently run — Artificial Analysis
> first, Vals.ai (as of 2026-10-01) in parentheses; read 2026-10-04. Neither board states
> effort. Never rank options on the composite Intelligence Index or on vendor-run scores:
> the composite has one coding eval in ten and put deepseek-flash within 15 points of Opus
> 5.5, where coding puts it 33-45 behind. Haiku 5.5 is at max, read 2026-10-21; at medium, its
> default, Artificial Analysis has it at 15.2.

> **Sonnet is `sonnet[1m]`.** A bare `sonnet` agent under an Opus parent gets the 200k
> window, and Sonnet agents on large inputs died of it. Frontmatter takes the suffix;
> per-dispatch `model` opts cannot, so `levers.py` passes `sonnet` and the settings
> remap `ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5[1m]` binds the alias to 1M
> (probed 2026-09-27, 2.1.283). The remap pins the alias to Sonnet 5.5 (re-pointed and
> probed 2026-10-04, 2.1.289); re-point it in `06-deploy-claude.zsh` when a new Sonnet ships.
> Sonnet 5 was 0.98x and (9.6).

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
| 1 | Session model | `/model`, `--model`, `ANTHROPIC_MODEL` (live) | fable<br>opus<br>sonnet[1m]<br>haiku | fable 2.15x<br>opus 1.00x<br>sonnet 0.62x<br>haiku 0.58x | fable 52.0 (58.1)<br>opus 59.6 (65.2)<br>sonnet 63.6 (64.1)<br>haiku 32.8 (36.4) | 100 |
| 2 | Session effort | `/effort` or the `/model` picker (live, hand-set; saves per model under `modelSettings` in user settings — a top-level `effortLevel` there does not reach Opus 5.5, and `max` is never saved), `--effort`, `CLAUDE_CODE_EFFORT_LEVEL` | max<br>xhigh<br>high<br>medium<br>low | max 3.29x<br>xhigh 1.90x<br>high 1.00x<br>medium 0.74x<br>low 0.30x<br>(Opus 5.5) | max 59.6<br>xhigh 59.6<br>others unpublished<br>(Opus 5.5) | 50 |
| 3 | Advisor model | `advisorModel` in `~/.claude/settings.json` (unset), `/advisor`, `--advisor` (live). Off entirely under `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1` | off<br>fable<br>opus<br>sonnet | Per call, the advisor's rate on the full transcript, uncached; nothing between calls. Must rank at or above the model it advises, or it is not attached: an Opus 5.5 session takes only opus or fable. Subagents inherit it and pass the same check, so DeepSeek agents never get it. Anthropic API only, so it passes the proxy only on Claude routes | as row 1 | 35 (est.) |

Types: `lever-state.json` `types`, a model and an effort per account for each; the Subagents table in SKILL.md maps every role to one. Costs and scores are rows 1-2's, and DeepSeek's are under the table.

| Type | Roles | Binds through | Model options | Effort options | Impact (model / effort) |
| --- | --- | --- | --- | --- | --- |
| judgment | judgment, escalation | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 60 / 30 (est.) |
| review | adversary, verify, taste | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 60 / 35 |
| code | code | `worker-agent` frontmatter, built per account | fable<br>opus<br>deepseek-flash[1m] (proxy)<br>deepseek-v4-pro[1m] (proxy; dominated by flash)<br>sonnet[1m]<br>haiku | inherit (session)<br>max<br>xhigh<br>high<br>medium<br>low | 30 / 10 |
| critical code | hardest, contract, code on a `## Critical` path | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 45 / 20 (est.) |
| research | explore | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 8 / 3 (est.) |
| other family | other family | `deepseek-flash-agent` frontmatter, built per account | deepseek-flash[1m] (proxy)<br>deepseek-v4-pro[1m] (proxy) | none | 15 (est.) |
| general | anything else | dispatch opts | fable<br>opus<br>sonnet[1m]<br>haiku | max<br>xhigh<br>high<br>medium<br>low | 40 / 15 (est.) |

DeepSeek: `deepseek-flash[1m]` costs 0.15x in DeepSeek dollars and nothing on the Claude limit; `deepseek-v4-pro[1m]` costs 0.37x and scores below flash on the same index (36 vs 39), so flash dominates it until pro is updated. Perf: flash 26.8 (19.7), pro — (14.1). Both fail in a session not launched through `oc`. Always set them with `[1m]`: a bare DeepSeek name gets a 200K window (probed 2026-09-27).

Impact rationale per lever: [lever-impact.md](lever-impact.md)

Excluded — do not re-add: fast mode, context ceiling, skill frontmatter overrides, alwaysThinkingEnabled (thinking already defaults on across current models), fallbackModel (availability, not cost), the vault agents' `model:` (pinned to opus, 2026-10-28), CLAUDE_CODE_SUBAGENT_MODEL_FORCE / maxEffortLevel / deniedModels (global overrides and caps on the never-set list in roster.md).

Retired, do not re-add: the tester, scoping, and scoping fan-out models (rows 9, 11, 7f; intake traces causes with the how and why stations, and the bug review is the interrogate station), per-card worker models (every worker runs on the code type), the per-role levers (review, worker, escalation, and the research, code, review and parent fan-out levers; replaced by the types 2026-11-18), and the milestone build's rows 13a-13h (catering's deployments are ordinary orders).
