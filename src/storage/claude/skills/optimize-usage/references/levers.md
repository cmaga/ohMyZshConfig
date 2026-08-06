# Lever inventory

Last updated: 2026-08-04 · Method updated: 2026-07-21

> Cost column: rows 1-2 are measured benchmark ratios — per-unit-work cost vs the
> opus/high baseline (2026-08-04 run: 105 runs, N=5/cell, all pass, mean CV 18%,
> which resolves ~40% effects; figures within ~25% of 1.0x are directional).
> Rows 3-8 are per-token price-ratio estimates (fable 2x opus, sonnet 0.6x, haiku
> 0.2x), tagged est. pending an agent-frontmatter benchmark runner. Ratios are not
> additive points. Aliases currently bind: opus=Opus 5, sonnet=Sonnet 5,
> haiku=Haiku 4.5, fable=Fable 5.

| # | Lever | Where | Options | Cost (x opus/high, per unit work) | Impact (0-100) |
| --- | --- | --- | --- | --- | --- |
| 1 | Session model | `/model`, `--model`, `ANTHROPIC_MODEL` (live) | fable<br>opus<br>sonnet<br>haiku | fable 2.08x<br>opus 1.00x<br>sonnet 0.86x (directional)<br>haiku 0.18x | 100 |
| 2 | Session effort | settings.json, `--effort`, `CLAUDE_CODE_EFFORT_LEVEL` (live) | max<br>xhigh<br>high<br>medium<br>low | max 1.22x<br>xhigh 1.11x (directional)<br>high 1.00x<br>medium unmeasured<br>low 0.74x<br>(measured on opus; session runs fable) | 50 |
| 3 | Review model | `model:` frontmatter in `agents/code-review-agent.md`, `plan-review-agent.md`, `qa-planner-agent.md`, `security-expert-agent.md` | fable<br>opus<br>sonnet<br>haiku | est. — price ratios (fable 2x, opus 1x, sonnet 0.6x, haiku 0.2x); measured swaps run shallower than price (sonnet 0.86x at session) | 60 |
| 4 | Review effort | `effort:` frontmatter in the same review agent files | max<br>xhigh<br>high<br>medium<br>low | est. — effort measured shallow at session (max 1.22x / high 1.00x / low 0.74x) | 35 |
| 5 | Worker model | `agents/worker-agent.md` `model:` | fable<br>opus<br>sonnet<br>haiku | est. — price ratios as row 3; currently sonnet, no recorded quality drop | 25 |
| 6 | Worker effort | `agents/worker-agent.md` `effort:` | max<br>xhigh<br>high<br>medium<br>low | est. — shallow per session effort data; bounded by review gates | 10 |
| 7a | Research fan-out model | `lever-state.json` `research_fanout_model` — read by dev-workflow Step 3.1 for its `agent()` `model` opt | inherit (session)<br>fable<br>opus<br>sonnet<br>haiku | est. — read/summarize; sonnet ~price-ratio cheap, safe | 8 |
| 7b | Code fan-out model | `lever-state.json` `code_fanout_model` — read by dev-workflow Step 3.2 for its `agent()` `model` opt | inherit (session)<br>fable<br>opus<br>sonnet<br>haiku | est. — task-dependent; sonnet may save less than price implies | 20 |
| 7c | Review fan-out model | `lever-state.json` `review_fanout_model` — read by `agents/code-review-agent.md` for the `model` opt on its finder and disproof subagents | inherit (session)<br>fable<br>opus<br>sonnet<br>haiku | est. — detection happens here; a finder's miss is caught by nothing downstream | 45 |
| 7d | Review fan-out effort | `lever-state.json` `review_fanout_effort` — same agents, `effort` opt | inherit (session)<br>max<br>xhigh<br>high<br>medium<br>low | est. — disproof is single-claim and near effort-flat; open-ended finding is not | 25 |
| 8 | Vault-scribe model | `agents/vault-scribe-agent.md` `model:` | fable<br>opus<br>sonnet<br>haiku | est. — occasional dispatch, small share | 15 (est.) |

Impact rationale per lever: [lever-impact.md](lever-impact.md)

Excluded — do not re-add: fast mode, advisor model, context ceiling, deep-tier dispatch, per-card model, skill frontmatter overrides, alwaysThinkingEnabled (thinking already defaults on across current models), fallbackModel (availability, not cost).
