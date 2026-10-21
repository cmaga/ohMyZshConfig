---
name: optimize-usage
description: Tunes the development workflow for cost and performance optimization.
disable-model-invocation: true
model: fable
effort: max
---

# Optimize Usage

The user relies heavily on LLM tools for software development. Their primary goal is to deliver the highest quality work while avoiding being blocked by session limits. There are settings, or levers, that can be tweaked in order to achieve this balance.

## Routing

- Invoked with no context beyond a limit hit or "optimize my usage" → **Default mode** (below).
- Invoked with context (a new model, a pricing change, a workload shift, a hunch to evaluate) → [Freeform mode](modes/freeform.md)
- User says to refresh or update the levers → [refresh-levers](modes/refresh-levers.md)

## Critical Rules

- Config edits go to the source repo `~/dev/personal/ohMyZshConfig/src/storage/claude/` — never to `~/.claude/`, which deploy clobbers. Live-only settings are edited in `~/.claude/settings.json` or per session.
- Never set `CLAUDE_CODE_SUBAGENT_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` or `CLAUDE_CODE_EFFORT_LEVEL`, and keep `availableModels`/`enforceAvailableModels`/`deniedModels`/`maxEffortLevel` unset — blunt global overrides and caps that silently clobber the model/effort levers.
- DeepSeek models are options for the worker and vault levers only. They resolve only through the local claude-proxy (sessions launched with `oc`), and the proxy's `DEEPSEEK_MODELS` allowlist is the option list.
- Changes must be approved by the user first.
- Verification **MUST** be performed regardless of mode once changes are complete.

## Lever state

[lever-state.json](lever-state.json) (deployed to `~/.claude/skills/optimize-usage/`) records every lever's position. `kind: skill` levers are bound by the file — consumer skills read it at runtime. `kind: runtime` levers are bound by native config (settings.json, agent frontmatter); the file only mirrors declared intent, so every change to one edits both in the same approved change. On mismatch: native wins for runtime levers, the file wins for skill levers — surface drift, never reconcile silently. This skill is the only writer.

Each Claude account has its own limit and its own lever set: `accounts` names `work` and `personal` and the config dirs that sign in as each. A lever whose `value` is keyed by account is set per account; a plain `value` (session model and effort, advisor, vault model) is shared, so a step on it moves both accounts — say so at the gate. Consumers read the file through [scripts/levers.py](scripts/levers.py), which resolves the session's account. A lever with `agents` binds dev-workflow's dispatches of those agents and their frontmatter. The source frontmatter carries personal's value; deploy gives every other account's config dir its own copy of each agent whose values differ ([scripts/account-agents.py](scripts/account-agents.py)), so a step on one account never moves the other. `inherit` and DeepSeek values pass no dispatch opt and bind through that frontmatter alone.

## Default Mode

Tune only the account the user names ("work" or "personal"). When they name neither, tune both, one at a time: the account that hit its limit first runs every step through Apply before the other starts.

1. **Find the gap.** Ask at what point in the window the limit hit (e.g. hour 2.5 of the 5-hour session window). Gap = how far over sustainable the burn is (burn = window / hit-hour; gap = 1 - 1/burn): hit at 2.5/5 means burning 2x the budget, a 50% gap. An account that did not hit has room instead: ask its peak `/usage` percentage in a heavy window, u; room = 1 - u.
2. **Target half the gap.** Limits are hit on the heaviest sessions only, so average sessions don't need the full cut — aim for gap/2 (2.5/5 → find 25% savings). Re-run the skill if the limit gets hit again; iterate rather than over-cut. Room works the same way: target the cost rise that closes half of it, (1-u)/(2u) — a 60% peak allows about 33% more.
3. **Spread the cut wide and shallow.** Read the current lever positions first — start from `python3 ~/.claude/skills/optimize-usage/scripts/levers.py <account>`, then verify native config matches (agent frontmatter, settings.json) — steps already taken set each lever's depth. Then walk levers by ascending impact ([lever-impact.md](references/lever-impact.md)), taking first steps across levers before second steps anywhere: each additional step down the same lever counts as progressively more expensive — roughly impact x steps already taken. Documented exceptions override the rule of thumb (session effort max→xhigh→high is near-free; worker fable→sonnet is evidence-flat; a worker step onto or between DeepSeek models costs no Claude limit, so judge it on quality alone). Stop when the stepped levers plausibly cover the target — cost figures are per-position ratios ([levers.md](references/levers.md)), not additive points, so state the projection as an estimate; if all shallow steps together clearly fall short, say so and present the deep steps as the explicit tradeoff rather than taking them silently. An account with room steps up by the same walk reversed: levers by descending impact, first steps across levers before second steps anywhere.
4. **Present and gate.** The step stack, projected total vs target, performance cost per step, residual if any. Wait for approval.
5. **Apply.** Config steps: edit source repo including `lever-state.json`, `make deploy-claude`, verify with `python3 ~/.claude/skills/optimize-usage/scripts/levers.py <account>` for an account-keyed lever and `grep -E '^(model|effort):'` on a deployed agent file; for a DeepSeek worker, also `curl -sf http://localhost:4000/health`. Live steps: apply or hand off.
