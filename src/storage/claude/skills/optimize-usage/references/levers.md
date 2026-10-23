# Lever inventory

Last updated: 2026-10-04 · Method updated: 2026-10-04

> **Effort is not auditable.** A dispatched agent's record carries its model and never its
> effort (measured: 0 of 61 agent records in one run). So every `*_effort` row below is
> unverifiable after the fact — an effort lever that silently failed to bind would look
> exactly like one that worked. `description` prefixes (dev-workflow Prerequisite 2) are what
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
> Claude limit. Rows 3-11 reuse the row 1-2 ratios. Ratios are not additive points.
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
> per-call `model` opts (rows 7a-7f, 10) cannot, so they pass `sonnet` and the settings
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
> A DeepSeek worker or vault agent runs from any `oc` session: Claude Code loads every tool
> upfront for a DeepSeek model even with tool search on, and DeepSeek accepts deferred tools
> and tool-reference blocks. It rejects the `tool_addition` blocks that announce a
> late-connecting MCP server's tools (422), which the proxy moves into `tools` (probed
> 2026-10-21, 2.1.306).

> **Three accounts.** `personal`, `work` (gsi) and `ms` each have their own limit and their own value on every
> row but 1, 2, 8 and 12, whose native homes they share. Rows 3-6, 9 and 11 bind through
> dev-workflow's dispatch opts and through each account's own agent frontmatter, which deploy
> builds per config dir.

> **Build roles (rows 13a-13h)** are set per account in `dev-workflow/scripts/levels.json`, which
> `milestone-args.py start` reads into each milestone workflow; a running milestone keeps the roles
> it started with. The Levels table in `dev-workflow/common/milestone-build.md` names each role's
> model, so a step edits both. A DeepSeek value dispatches as the agent named for it
> (`agents/deepseek-flash-agent.md`); another DeepSeek model needs its own agent file first.

| # | Lever | Where | Options | Cost (x opus/high, per unit work) | Perf (TB 4.0) | Impact (0-100) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Session model | `/model`, `--model`, `ANTHROPIC_MODEL` (live) | fable<br>opus<br>sonnet[1m]<br>haiku | fable 2.15x<br>opus 1.00x<br>sonnet 0.62x<br>haiku 0.58x | fable 52.0 (58.1)<br>opus 59.6 (65.2)<br>sonnet 63.6 (64.1)<br>haiku 32.8 (36.4) | 100 |
| 2 | Session effort | `/effort` or the `/model` picker (live, hand-set; saves per model under `modelSettings` in user settings — a top-level `effortLevel` there does not reach Opus 5.5, and `max` is never saved), `--effort`, `CLAUDE_CODE_EFFORT_LEVEL` | max<br>xhigh<br>high<br>medium<br>low | max 3.29x<br>xhigh 1.90x<br>high 1.00x<br>medium 0.74x<br>low 0.30x<br>(Opus 5.5) | max 59.6<br>xhigh 59.6<br>others unpublished<br>(Opus 5.5) | 50 |
| 3 | Review model | `model:` frontmatter in `agents/code-review-agent.md`, `plan-review-agent.md`, `qa-planner-agent.md` | fable<br>opus<br>sonnet[1m]<br>haiku | as row 1 (fable 2.15x, opus 1x, sonnet 0.62x, haiku 0.58x) | as row 1 | 60 |
| 4 | Review effort | `effort:` frontmatter in the same review agent files | max<br>xhigh<br>high<br>medium<br>low | as row 2 (max 3.29x / xhigh 1.90x / high 1.00x / medium 0.74x / low 0.30x) | as row 2 | 35 |
| 5 | Worker model | `lever-state.json` `worker_model`, which dev-workflow passes as the `model` opt; `agents/worker-agent.md` `model:`, per account | fable<br>opus<br>deepseek-flash[1m] (proxy)<br>deepseek-v4-pro[1m] (proxy; dominated by flash)<br>sonnet[1m]<br>haiku | Claude models as row 3. deepseek-flash[1m]: 0.15x in DeepSeek dollars, 0 on the Claude limit; `deepseek-v4-pro[1m]` 0.37x and scores below flash on the same index (36 vs 39), so flash dominates it until pro is updated. Fails in a session not launched through `oc`. Always set with `[1m]`: a bare DeepSeek name gets a 200K window (probed 2026-09-27) | Claude as row 1<br>deepseek-flash 26.8 (19.7)<br>deepseek-v4-pro — (14.1) | 30 |
| 6 | Worker effort | `agents/worker-agent.md` `effort:` | max<br>xhigh<br>high<br>medium<br>low | as row 4; bounded by review gates | as row 2 | 10 |
| 7a | Research fan-out model | `lever-state.json` `research_fanout_model` — read by dev-workflow Step 4.1 and ultra's Precedent research for their `agent()` `model` opt | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; read/summarize | as row 1 | 8 |
| 7b | Code fan-out model | `lever-state.json` `code_fanout_model` — read by dev-workflow Step 4.2 for its `agent()` `model` opt | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; task-dependent | as row 1 | 20 |
| 7c | Review fan-out model | `lever-state.json` `review_fanout_model` — read by `agents/code-review-agent.md` for the `model` opt on its finder and disproof subagents | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; detection happens here; a finder's miss is caught by nothing downstream | as row 1 | 45 |
| 7d | Review fan-out effort | `lever-state.json` `review_fanout_effort` — same agents, `effort` opt | inherit (session)<br>max<br>xhigh<br>high<br>medium<br>low | as row 4; disproof is single-claim and near effort-flat; open-ended finding is not | as row 2 | 25 |
| 7e | Parent fan-out model | `lever-state.json` `parent_fanout_model` — read by dev-workflow for the `model` opt on every agent a run dispatches that no other alias covers | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; the largest uncovered surface before this row existed (one measured run: 31 of 62 agents, 46% of output tokens, none of it on a lever) | as row 1 | 40 |
| 7f | Scoping fan-out model | `lever-state.json` `scoping_fanout_model` — read by `agents/scoping-agent.md` for the `model` opt on its subagents | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; read-and-report threads; the judgment stays in the scoping agent | as row 1 | 12 |
| 8 | Vault model | `agents/vault-scribe-agent.md` and `agents/adr-auditor-agent.md` `model:` — one lever for both vault agents | fable<br>opus<br>deepseek-flash[1m] (proxy)<br>sonnet[1m]<br>haiku | as row 3; deepseek-flash[1m] as row 5, 0 on the Claude limit, and fails in a session not launched through `oc` — the vault agents dispatch from any session that writes the vault, not only dev-workflow; occasional dispatch, small share | as row 5 | 15 (est.) |
| 9 | Tester model | `agents/tester-agent.md` `model:` | fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; one dispatch per medium/large ticket | as row 1 | 50 |
| 10 | Escalation model | `lever-state.json` `escalation_model` — read by dev-workflow Step 6 for the `general-purpose` agent that decides an escalation before it reaches the user, and by exit triage, where the same agent folds or escalates each loose end | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; dispatched on escalation and once per run at exit triage when there are loose ends | as row 1 | 55 |
| 11 | Scoping model | `agents/scoping-agent.md` `model:` | fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; one dispatch per ticket at Step 2 | as row 1 | 45 |
| 12 | Advisor model | `advisorModel` in `~/.claude/settings.json` (unset), `/advisor`, `--advisor` (live). Off entirely under `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1` | off<br>fable<br>opus<br>sonnet | Per call, the advisor's rate on the full transcript, uncached; nothing between calls. Must rank at or above the model it advises, or it is not attached: an Opus 5.5 session takes only opus or fable. Subagents inherit it and pass the same check, so DeepSeek agents never get it. Anthropic API only, so it passes the proxy only on Claude routes | as row 1 | 35 (est.) |
| 13a | Build plan role | `dev-workflow/scripts/levels.json` `plan` — the milestone build's scaffold and failing tests | model: opus, fable, sonnet[1m]<br>effort: max, xhigh, high | as rows 1-2 | as rows 1-2 | model 50, effort 30 (est.) |
| 13b | Build decide role | `levels.json` `decide` — the decider, which answers every agent's question with the coordinator's authority | model: opus, fable, sonnet[1m]<br>effort: max, xhigh, high | as rows 1-2 | as rows 1-2 | model 50, effort 30 (est.) |
| 13c | Build review role | `levels.json` `review` — plan approve, review finders and seams, disproof, verify, the hand-back census and the review of its fixes | model: opus, fable, sonnet[1m]<br>effort: max, xhigh, high | as rows 1-2 | as rows 1-2 | model 60, effort 30 (est.) |
| 13d | Build research role | `levels.json` `research` — gather mapping and the sweep | model: opus, sonnet[1m]<br>effort: xhigh, high, medium | as rows 1-2 | as rows 1-2 | model 35, effort 15 (est.) |
| 13e | Build open role | `levels.json` `open` — open and critical tasks, reruns, folds, the bed fix, post-verify and one-off fixes | model: opus, sonnet[1m]<br>effort: xhigh, high, medium | as rows 1-2 | as rows 1-2 | model 40, effort 20 (est.) |
| 13f | Build pinned role | `levels.json` `pinned` — tasks the scaffold and failing tests pin down, and fixes that need no bed run | model: sonnet[1m], deepseek-flash[1m] (proxy), haiku<br>effort: high, medium; none on DeepSeek | Claude as rows 1-2; deepseek-flash as row 5 | as row 5 | model 25, effort 10 (est.) |
| 13g | Build read role | `levels.json` `read` — the sweep's file listing | model: haiku, sonnet[1m] | as row 1 | as row 1 | 5 (est.) |
| 13h | Build critical effort | `levels.json` `critical.effort` — the floor for a critical task's fill, its review finder and disproofs, a fold or verify touching it, and a decider it asks | effort: max, xhigh, high | as row 2 | as row 2 | 40 (est.) |

Impact rationale per lever: [lever-impact.md](lever-impact.md)

Excluded — do not re-add: fast mode, context ceiling, skill frontmatter overrides, alwaysThinkingEnabled (thinking already defaults on across current models), fallbackModel (availability, not cost), CLAUDE_CODE_SUBAGENT_MODEL_FORCE / maxEffortLevel / deniedModels (global overrides and caps on the never-set list in SKILL.md).

Advisor model is row 12 again (2026-10-04): it was dropped 2026-09-17 as disabled, but it was only unset.

Per-card worker models were removed 2026-09-20: every worker runs on row 5. Do not re-add them.
