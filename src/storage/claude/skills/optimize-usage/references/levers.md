# Lever inventory

Last updated: 2026-09-30 · Method updated: 2026-09-28

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
> are at high effort; Haiku 4.5 has no effort levels there. DeepSeek figures are its own
> bill at max effort and $0.30/$1.20 rates (off-peak halves it), and draw nothing on the
> Claude limit. Rows 3-11 reuse the row 1-2 ratios. Ratios are not additive points.
> Aliases bound (Claude Code 2.1.283): opus=Opus 5.5 ($4/$20, cache read $0.20; default
> effort medium, and top-level effortLevel does not reach it, so it needs a modelSettings
> key), fable=Fable 5.1, sonnet=Sonnet 5 [1m] via the remap below, haiku=Haiku 4.5;
> deepseek-flash=DeepSeek-V4.1-Flash, deepseek-v4-pro=DeepSeek-V4-Pro-0813.

> **Sonnet is `sonnet[1m]`.** A bare `sonnet` agent under an Opus parent gets the 200k
> window, and Sonnet agents on large inputs died of it. Frontmatter takes the suffix;
> per-call `model` opts (rows 7a-7f, 10) cannot, so they pass `sonnet` and the settings
> remap `ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5[1m]` binds the alias to 1M
> (probed 2026-09-27, 2.1.283). The remap pins the alias to Sonnet 5; re-point it in
> `06-deploy-claude.zsh` when a new Sonnet ships.

| # | Lever | Where | Options | Cost (x opus/high, per unit work) | Impact (0-100) |
| --- | --- | --- | --- | --- | --- |
| 1 | Session model | `/model`, `--model`, `ANTHROPIC_MODEL` (live) | fable<br>opus<br>sonnet[1m]<br>haiku | fable 2.15x<br>opus 1.00x<br>sonnet 0.98x<br>haiku 0.15x | 100 |
| 2 | Session effort | `/effort` or the `/model` picker (live, hand-set; saves per model under `modelSettings` in user settings — a top-level `effortLevel` there does not reach Opus 5.5, and `max` is never saved), `--effort`, `CLAUDE_CODE_EFFORT_LEVEL` | max<br>xhigh<br>high<br>medium<br>low | max 3.29x<br>xhigh 1.90x<br>high 1.00x<br>medium 0.74x<br>low 0.30x<br>(Opus 5.5) | 50 |
| 3 | Review model | `model:` frontmatter in `agents/code-review-agent.md`, `plan-review-agent.md`, `qa-planner-agent.md` | fable<br>opus<br>sonnet[1m]<br>haiku | as row 1 (fable 2.15x, opus 1x, sonnet 0.98x, haiku 0.15x) | 60 |
| 4 | Review effort | `effort:` frontmatter in the same review agent files | max<br>xhigh<br>high<br>medium<br>low | as row 2 (max 3.29x / xhigh 1.90x / high 1.00x / medium 0.74x / low 0.30x) | 35 |
| 5 | Worker model | `agents/worker-agent.md` `model:` — the only place a worker's model is set; dev-workflow never passes one | fable<br>opus<br>deepseek-flash[1m] (proxy)<br>deepseek-v4-pro[1m] (proxy; dominated by flash)<br>sonnet[1m]<br>haiku | Claude models as row 3. deepseek-flash[1m]: 0.15x in DeepSeek dollars, 0 on the Claude limit; `deepseek-v4-pro[1m]` 0.37x and scores below flash on the same index (36 vs 39), so flash dominates it until pro is updated. Fails in a session not launched through `oc`. Always set with `[1m]`: a bare DeepSeek name gets a 200K window (probed 2026-09-27) | 30 |
| 6 | Worker effort | `agents/worker-agent.md` `effort:` | max<br>xhigh<br>high<br>medium<br>low | as row 4; bounded by review gates | 10 |
| 7a | Research fan-out model | `lever-state.json` `research_fanout_model` — read by dev-workflow Step 4.1 and ultra's Precedent research for their `agent()` `model` opt | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; read/summarize | 8 |
| 7b | Code fan-out model | `lever-state.json` `code_fanout_model` — read by dev-workflow Step 4.2 for its `agent()` `model` opt | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; task-dependent | 20 |
| 7c | Review fan-out model | `lever-state.json` `review_fanout_model` — read by `agents/code-review-agent.md` for the `model` opt on its finder and disproof subagents | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; detection happens here; a finder's miss is caught by nothing downstream | 45 |
| 7d | Review fan-out effort | `lever-state.json` `review_fanout_effort` — same agents, `effort` opt | inherit (session)<br>max<br>xhigh<br>high<br>medium<br>low | as row 4; disproof is single-claim and near effort-flat; open-ended finding is not | 25 |
| 7e | Parent fan-out model | `lever-state.json` `parent_fanout_model` — read by dev-workflow for the `model` opt on every agent a run dispatches that no other alias covers | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; the largest uncovered surface before this row existed (one measured run: 31 of 62 agents, 46% of output tokens, none of it on a lever) | 40 |
| 7f | Scoping fan-out model | `lever-state.json` `scoping_fanout_model` — read by `agents/scoping-agent.md` for the `model` opt on its subagents | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; read-and-report threads; the judgment stays in the scoping agent | 12 |
| 8 | Vault model | `agents/vault-scribe-agent.md` and `agents/adr-auditor-agent.md` `model:` — one lever for both vault agents | fable<br>opus<br>deepseek-flash[1m] (proxy)<br>sonnet[1m]<br>haiku | as row 3; deepseek-flash[1m] as row 5, 0 on the Claude limit, and fails in a session not launched through `oc` — the vault agents dispatch from any session that writes the vault, not only dev-workflow; occasional dispatch, small share | 15 (est.) |
| 9 | Tester model | `agents/tester-agent.md` `model:` | fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; one dispatch per medium/large ticket | 50 |
| 10 | Escalation model | `lever-state.json` `escalation_model` — read by dev-workflow Step 6 for the `general-purpose` agent that decides an escalation before it reaches the user, and by exit triage, where the same agent folds or escalates each loose end | inherit (session)<br>fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; dispatched on escalation and once per run at exit triage when there are loose ends | 55 |
| 11 | Scoping model | `agents/scoping-agent.md` `model:` | fable<br>opus<br>sonnet[1m]<br>haiku | as row 3; one dispatch per ticket at Step 2 | 45 |

Impact rationale per lever: [lever-impact.md](lever-impact.md)

Excluded — do not re-add: fast mode, context ceiling, skill frontmatter overrides, alwaysThinkingEnabled (thinking already defaults on across current models), fallbackModel (availability, not cost), CLAUDE_CODE_SUBAGENT_MODEL_FORCE / maxEffortLevel / deniedModels (global overrides and caps on the never-set list in SKILL.md).

Advisor model came off this list (2026-09-17): the `advisor` tool is disabled. Row 10 replaced it.

Per-card worker models were removed 2026-09-20: every worker runs on row 5. Do not re-add them.
