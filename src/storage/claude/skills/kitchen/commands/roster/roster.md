# Model and effort levers

Set which model and effort each type of work runs on, so the user gets the best work their Claude limits allow without being blocked by them. Each type's model, each type's effort, and each session-wide setting is a lever.

## Routing

- Invoked with no context → **Show mode** (below). A bare `roster` asks to see the config, never says a limit was hit.
- User says a limit is tight, or asks to optimize usage → **Default mode** (below).
- Invoked with other context (a new model, a pricing change, a workload shift, a hunch to evaluate) → [Freeform mode](modes/freeform.md)
- User says to refresh or update the levers → [refresh-levers](modes/refresh-levers.md)

## Rules

- Config edits go to the source repo `~/dev/personal/ohMyZshConfig/src/storage/claude/` — never to `~/.claude/`, which deploy clobbers. Live-only settings are edited in `~/.claude/settings.json` or per session.
- Never set `CLAUDE_CODE_SUBAGENT_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` or `CLAUDE_CODE_EFFORT_LEVEL`, and keep `availableModels`/`enforceAvailableModels`/`deniedModels`/`maxEffortLevel` unset — blunt global overrides and caps that silently clobber the model/effort levers.
- DeepSeek models are options only for the types bound through an agent's frontmatter (code and other family). They resolve only through the local claude-proxy (sessions launched with `oc`), and the proxy's `DEEPSEEK_MODELS` allowlist is the option list.
- Change nothing until the user approves it, and verify every change once it is applied, whatever the mode.

## Types

The kitchen dispatches every role on one type ([SKILL.md](../../SKILL.md#subagents), whose table maps each role to its type): judgment, review, code, critical code, research, other family, or general. A step on a type moves every role mapped to it, so name those roles at the gate. A new role joins a type in that table; it never gets a lever of its own.

## Lever state

[lever-state.json](lever-state.json) (deployed to `~/.claude/skills/kitchen/commands/roster/`) records every lever's position. `types` holds each type's `model` and `effort`, bound by the file: the kitchen reads it at runtime, and on mismatch the file wins. `levers` holds the session-wide settings (`kind: runtime`), bound by native config (settings.json or the session); the file only mirrors declared intent, so every change to one edits both in the same approved change, and on mismatch native wins. Surface drift, never reconcile silently. This command is the only writer.

Each Claude account has its own limit and its own lever set: `accounts` names `personal`, `work` (gsi), `ms` and `amazon`, and the config dirs that sign in as each. `amazon` is Bedrock: it shares `~/.claude` with `personal` and is told apart by its `env` (`CLAUDE_CODE_USE_BEDROCK=1`), which wins over a config-dir match alone. A type's model and effort are keyed by account; a session-wide lever's plain `value` is shared, so a step on it moves every account — say so at the gate. Consumers read the file through [scripts/levers.py](scripts/levers.py), which resolves the session's account. A type with `agents` binds through those agents' frontmatter. The source frontmatter carries personal's value; deploy gives every other account's config dir its own copy of each agent whose values differ ([scripts/account-agents.py](scripts/account-agents.py)), so a step on one account never moves the other. `inherit` and DeepSeek values pass no dispatch opt and bind through that frontmatter alone.

## Show Mode

Change nothing. Run `levers.py <account>` for every account and reply with:

1. One table: a row per type with the roles SKILL.md maps to it, then a row per session-wide lever, and a column per account, with values that differ between accounts in bold.
2. Native drift: compare each runtime lever and each type with `agents` against its native home (`settings.json`, deployed agent frontmatter) and name every mismatch. Never reconcile it.
3. What the user can do next: step a lever, move a role to another type, refresh the levers, or tune usage.

## Amazon

`amazon` has no limit and no bill the user tracks, but waste still counts: spend and wall-clock time. Step a lever up only when the benchmarks in [levers.md](references/levers.md) show a gain worth its cost and its slowdown; at a tie, take the cheaper option. Default mode does not apply to it. DeepSeek (no `oc` proxy) and the advisor (Anthropic API only) are off.

## Default Mode

Tune only the account the user names ("personal", "work" or "ms"; `amazon` is tuned per [Amazon](#amazon)). When they name none, tune each, one at a time: the account that hit its limit first runs every step through Apply before the next starts.

1. **Find the gap.** Ask at what point in the window the limit hit (e.g. hour 2.5 of the 5-hour session window). Gap = how far over sustainable the burn is (burn = window / hit-hour; gap = 1 - 1/burn): hit at 2.5/5 means burning 2x the budget, a 50% gap. An account that did not hit has room instead: ask its peak `/usage` percentage in a heavy window, u; room = 1 - u.
2. **Target half the gap.** Limits are hit on the heaviest sessions only, so average sessions don't need the full cut — aim for gap/2 (2.5/5 → find 25% savings). Re-run this mode if the limit gets hit again; iterate rather than over-cut. Room works the same way: target the cost rise that closes half of it, (1-u)/(2u) — a 60% peak allows about 33% more.
3. **Spread the cut wide and shallow.** Read the current lever positions first — start from `python3 ~/.claude/skills/kitchen/commands/roster/scripts/levers.py <account>`, then verify native config matches (agent frontmatter, settings.json) — steps already taken set each lever's depth. Then walk levers by ascending impact ([lever-impact.md](references/lever-impact.md)), taking first steps across levers before second steps anywhere: each additional step down the same lever counts as progressively more expensive — roughly impact x steps already taken. Documented exceptions override the rule of thumb (session effort max→xhigh→high is near-free; code fable→sonnet is evidence-flat; a code step onto or between DeepSeek models costs no Claude limit, so judge it on quality alone). Stop when the stepped levers plausibly cover the target — cost figures are per-position ratios ([levers.md](references/levers.md)), not additive points, so state the projection as an estimate; if all shallow steps together clearly fall short, say so and present the deep steps as the explicit tradeoff rather than taking them silently. An account with room steps up by the same walk reversed: levers by descending impact, first steps across levers before second steps anywhere.
4. **Present and gate.** The step stack, projected total vs target, performance cost per step, residual if any. Wait for approval.
5. **Apply.** Config steps: edit the source repo, `lever-state.json` included, and ask the user to commit; deploying with uncommitted work breaks sessions running from it. Once they have, run `make deploy-claude` and verify with `python3 ~/.claude/skills/kitchen/commands/roster/scripts/levers.py <account>` for a type and `grep -E '^(model|effort):'` on a deployed agent file; for a DeepSeek model, also `curl -sf http://localhost:4000/health`. Live steps: apply or hand off.
