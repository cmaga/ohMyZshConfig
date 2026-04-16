# Terminal hangs on this Mac — what we tried, current solution, and why

One consolidated record of two separate investigations (2026-04, prior weeks and the 14th-15th) into why terminals on this Mac would hang for 30 seconds to 4+ minutes — sometimes on open, sometimes mid-session, sometimes taking down every open tab at once. Both investigations landed on the same underlying mechanism (macOS `syspolicyd` saturation) from two different upstream causes, and required different fixes. Everything here is installed and deployed via `make deploy-zsh` + `make deploy-claude`.

Round 2 was initially (wrongly) attributed to LLM-generated busy-loop bash and a three-layer defense was built around that diagnosis. On 2026-04-15 the root cause was re-attributed to Cline Kanban's Claude Code hook architecture. The old diagnosis and its Layer 3 `runaway-shell-watchdog` LaunchAgent are gone; Layer 1 and Layer 2 stay as narrow belt-and-suspenders.

---

## TL;DR

Two failure modes, both routing through `syspolicyd`:

1. **Terminal-open hang (cold path)**. A new shell launched a Developer-ID-signed binary (nvm → node) that had no cached verdict. `syspolicyd` does full certificate-chain validation on the first launch of each unique `cdhash` per boot, which on this machine reproducibly takes minutes. Claude auto-updates daily and Homebrew upgrades rotate cdhashes, so "first launch" happened often.
2. **Mid-session multi-minute hang (saturation)**. Cline Kanban's Claude Code harness registered `matcher: "*"` hook entries on every Claude event (PreToolUse, PostToolUse, Stop, SubagentStop, PermissionRequest, UserPromptSubmit, SessionStart, Notification, …). Each hook invocation resolved to `node /Users/…/.nvm/versions/node/v22.18.0/bin/node …kanban hooks ingest …` — a fresh Dev-ID `node` spawn loading Kanban's ~281k-line bundled CLI just to send one IPC message to the Kanban daemon and exit. With N=8 parallel Kanban Claude sessions that baseline alone hit ~25–40 Dev-ID spawns/sec, enough to push `syspolicyd` toward its threshold. A coincident LLM-generated `until grep …; do true; done` bash poll loop tipped it over. Once tipped, `syspolicyd` stays at ~78 % CPU in a self-sustaining feedback loop, SIP blocks `launchctl kickstart`, and reboot is the only recovery.

The fix is a layered workaround for (1) plus stopping Kanban use for (2). Narrow BashTool guardrails (`deny-busy-loops` PreToolUse hook + `BASH_DEFAULT_TIMEOUT_MS`/`MAX`) stay in place as belt-and-suspenders for any future harness with a similar hook-fan-out architecture. None of the underlying macOS behavior is user-fixable.

---

## Round 1 — Terminal-open hang (earlier April 2026)

### Symptoms

- New iTerm tabs would appear but block 30 s – 4+ min before the prompt rendered.
- Intermittent, strongly correlated with many concurrent Claude Code sessions (12+).
- `bench-startup.zsh --parallel` showed ~1 s median — wrong, because 20 parallel shells share FS and signing caches.
- `bench-startup.zsh --sequential` (added during investigation) caught the real cost: shell 1 took 260 s.

### What we measured

| Binary | Signing | Cold | Warm |
|---|---|---|---|
| `/bin/true`, `/usr/bin/jq` | Apple | 0.001 s | 0.001 s |
| `/opt/homebrew/bin/gh --version` | Developer-ID | **246.57 s** | 0.02 s |
| `node --version` via nvm | Developer-ID | hung indefinitely | fast once cached |

- `sample <pid>` on every hung Dev-ID binary: 100 % of samples in `_dyld_start`, 0 % CPU — blocked in kernel waiting on AMFI, not spinning.
- `syspolicyd` was pegged at ~77 % of one core with 530 CPU-minutes over 6 days. The service is effectively single-threaded.
- `log show --predicate 'process == "syspolicyd"'` was emitting ~258/s `Dropping "com.apple.Gatekeeper.PolicyViolation"` events — a CoreAnalytics transform that's unregistered on macOS 26.4, so events get emitted and dropped in a loop. A signature of bad `syspolicyd` state, not the cause.
- OCSP responder healthy (`curl ocsp.apple.com` returned in 92 ms). Not network-related.
- `profiles status`: no configuration profiles. Not MDM-related.

### Root causes

1. **macOS code-signing cold path is pathologically slow.** First launch of each unique cdhash goes through `syspolicyd` → AMFI → certificate-chain validation; this can take minutes. Once cached, same binary launches in ~20 ms forever (until cdhash changes via update, or reboot clears the kernel trust cache).
2. **`.zshrc` dragged that cold path onto the shell-startup critical path.** The old `.zshrc` eagerly sourced `nvm.sh`, which runs `node --version` internally. Every shell open = one Dev-ID binary launch. If that launch hit cold cache, every shell open paid the price.
3. **Claude Code shell-snapshot filter stranded underscore-prefixed helpers.** `~/.claude/shell-snapshots/snapshot-zsh-*.sh` (re-sourced per BashTool call) captures top-level function definitions but filters out underscore-prefixed names. `_nvm_load` / `_direnv_export` / `_lazy_direnv_hook` in the old `.zshrc` were being stranded — snapshot referenced them but didn't define them → `command not found` + `FUNCNEST` recursion death inside Claude Code's Bash tool.
4. **`/usr/bin/git` silently spawning `xcodebuild`.** When `xcode-select -p` returned `/Applications/Xcode.app/Contents/Developer`, the git shim (`com.apple.dt.xcode_select.tool-shim-public`) launched `xcodebuild` to resolve the real git path. `xcodebuild` is a Dev-ID behemoth with its own cold-path cost. `sample` caught git stuck in `xcselect_invoke_xcrun` → hung `xcodebuild` child.

### What was changed — still in place

All repo changes live under `make deploy-zsh`.

- **Lazy nvm with snapshot-safe shims** (`src/storage/zsh/.zshrc`, the `darwin*` / `linux*` / `*)` branches). Replaces eager `source nvm.sh` with a `nvm_lazy_init` function and six per-binary shims (`nvm`, `node`, `npm`, `npx`, `pnpm`, `yarn`). Function names deliberately omit underscore prefix so they survive the Claude Code snapshot filter. Init helper unsets all shims first so `nvm.sh` can't re-enter them while loading.
- **`xcode-select` pointed at Command Line Tools.** `sudo xcode-select -s /Library/Developer/CommandLineTools` — per-machine state, not repo-deployed, needs redoing on any new system that defaults to Xcode.app.
- **Bench tooling rewritten.** `scripts/bench-startup.zsh` gained `--sequential`, `--profile`, `--trace`, `--purge`, `--compare`. The legacy `--parallel` mode is kept for backward compat but labeled as misleading.

### Verification

```bash
xcode-select -p          # expect: /Library/Developer/CommandLineTools
/usr/bin/time -p /opt/homebrew/bin/gh --version  # real ~0.02s
./scripts/bench-startup.zsh --sequential --label check --count 5
# expect steady-state 0.2–0.6 s per shell; 5+ s means cold path hit
```

---

## Round 2 — Mid-session multi-minute hang (2026-04-14, re-attributed 2026-04-15)

### Symptoms

- "All my terminals are hanging for 2+ minutes" — not just new tabs, existing ones too.
- Strongly correlated with Cline Kanban sessions running 8 parallel `claude --dangerously-skip-permissions --continue` tasks.
- "Claude Code takes 4 hours for a simple multi-file change" — because every BashTool call was blocked in `_dyld_start`.

### Initial (wrong) hypothesis

The first pass attributed the saturation to a single LLM-generated `until grep -q …; do true; done` bash poll loop observed under one of the 8 Kanban Claudes. That loop was real — it forked `grep` at ~1000/sec against an output file that would never match — and it *did* contribute fork load to `syspolicyd`. A three-layer defense was built around "prevent and contain runaway bash loops":

- Layer 1: `deny-busy-loops` PreToolUse hook (regex-blocks the known no-yield loop shapes).
- Layer 2: `BASH_DEFAULT_TIMEOUT_MS=300000` / `BASH_MAX_TIMEOUT_MS=3600000` in `~/.claude/settings.json`.
- Layer 3: `runaway-shell-watchdog` user LaunchAgent polling every 30 s, killing BashTool `zsh -c … snapshot-zsh-*` descendants of `claude` older than 5 min.

### Re-attributed root cause

The poll loop was a contributor, not the driver. Inspection of Kanban's bundled CLI on 2026-04-15 revealed a structural issue:

Kanban writes its own `settings.json` that registers hooks on every Claude Code event with `matcher: "*"` — PreToolUse and PostToolUse on every tool call, plus Stop, SubagentStop, PermissionRequest, PostToolUseFailure, UserPromptSubmit, SessionStart, Notification. Each hook resolves to:

```
/Users/cmagana/.nvm/versions/node/v22.18.0/bin/node \
  /Users/cmagana/.npm/_npx/<hash>/node_modules/.bin/kanban \
  hooks ingest --event <event> --source claude
```

That's a fresh Dev-ID `node` spawn from the nvm path, loading Kanban's bundled CLI (~281k lines of JS) just to send one IPC message to the Kanban daemon and exit.

Per tool call = PreToolUse + PostToolUse = 2 spawns minimum; with Stop/Notification/etc. realistically 3–5 spawns per BashTool call. A single active agent making 2 BashTool calls/sec → 6–10 node spawns/sec. Eight parallel Kanban Claudes → 25–40 spawns/sec sustained over hours. Every spawn touches `syspolicyd` (signature revalidation, kernel trust-cache lookup, AMFI entry). At that rate the baseline load alone is enough to push `syspolicyd` toward its feedback-loop threshold; the LLM-emitted `until grep; do true; done` poll on top was the added fork pressure that tipped it.

The earlier investigation caught the poll loop because it showed up as a PID in one hung process tree — an obvious local symptom. It missed Kanban's hooks because they aren't one-shot artifacts; they're the sustained ambient spawn rate of every Kanban-hosted Claude session, invisible in any one `ps` snapshot.

### Why this is a macOS-specific failure mode

On Linux the same hook storm would cost ~100 ms of Node cold-start per spawn. Annoying but not saturating; there is no `syspolicyd`-class single-threaded validator in the kernel path. On macOS, every exec of a non-Apple-signed binary — even one whose cdhash is already cached — touches `syspolicyd`, and sustained high exec rates of Dev-ID binaries push it into a degraded state from which SIP prevents recovery without a reboot.

### What we measured (still true, just recontextualized)

Under a synthetic 50-worker fleet (`scripts/load-gen.zsh` 45 synthetic + 5 real `claude -p`), steady-state startup cost broke down as:

| Scenario | Idle | Loaded |
|---|---|---|
| `$HOME` (no direnv fires) | 89 ms | 288 ms |
| project, direnv disabled | — | 314 ms |
| project, direnv on, minimal .envrc | 123 ms | 717–778 ms |
| `direnv export zsh` in isolation | 31 ms | 94 ms |

Steady-state contributors, ranked:

1. **`compinit` / `compdef` / `compaudit`** dominated at ~2 s cumulative across the top 20 xtrace lines, with ~1156 completion-function iterations. Each iteration costs microseconds idle, tens of ms under load — the fixed per-iteration cost swamps everything else under contention.
2. **Direnv added ~400 ms** under load vs ~32 ms idle (12× amplification). Confirmed causal via a `DIRENV_DISABLE=1` control. About 300 ms of that was the perl-wrapping-direnv shell plumbing, not the direnv binary itself.
3. **The `perl -e 'alarm 5; exec @ARGV' -- direnv export zsh` pattern doesn't actually kill direnv.** Tested with a 2 s alarm against a 20 s `.envrc` sleep: elapsed 20 s, rc 0. Go's runtime swallows SIGALRM. The "5 s kill timeout" claimed in the inline comment and in `CLAUDE.md` was protective only on paper.

None of these explain multi-minute hangs on their own. They explain amplified per-shell cost under load; the multi-minute hangs are `syspolicyd` saturation downstream of sustained Dev-ID fork pressure, of which Kanban's hook fan-out was the dominant source.

At 17:01 on 2026-04-14 a routine `./scripts/load-gen.zsh --reset` hung. Sampling PID 22600:

```
sample 22600 5
  4025 _dyld_start  (in dyld) + 0  — 100 % of samples, 0 % CPU
syspolicyd: PID 483  %CPU 77.8  ELAPSED 2h02m  CPU_TIME 40m00s
```

Exact `_dyld_start` pattern from Round 1, but `syspolicyd` had gone from 0.0–1.2 % CPU during the bench to 77.8 % two hours later with no new input. Killing the `until grep; do true; done` poller did not drop `syspolicyd` CPU (0→12 s CPU in 15 s wall even after `kill`). Zero input was needed to sustain the bad state. `sudo launchctl kickstart -k system/com.apple.security.syspolicy` → "Operation not permitted while SIP is engaged." Reboot cleared it.

### What was changed — still in place

**Primary mitigation: stopped using Cline Kanban on this machine (2026-04-15).** Any Claude Code harness that (a) registers hooks with `matcher: "*"` on PreToolUse/PostToolUse and (b) resolves them to fresh Node spawns from a nvm-style path is structurally incompatible with macOS exec-rate constraints at multi-agent scale. The real fix belongs upstream — a long-lived daemon + unix-domain socket, or a statically compiled tiny shim, instead of cold-starting Node per event. Tracking as an issue against `cline/kanban` is the right path for anyone running into this.

**Retained as narrow belt-and-suspenders** (both deployed via `make deploy-claude`):

- **`deny-busy-loops` PreToolUse hook** (`src/storage/claude/hooks/deny-busy-loops.sh`). Runs before every BashTool call. Regex-matches the command string for known runaway shapes: `do true; done` / `do :; done`, C-style `for ((;;))`, sleep-less `while true|until false`. Exit 2 blocks with a stderr message; Claude Code surfaces the message as a tool-use error so the model can try a different approach. Narrow regexes → near-zero false-positive rate. Registered in `src/storage/claude/hooks.json` under matcher `Bash`; the deploy script substitutes `$HOME` → absolute path at merge time so we don't depend on shell expansion by Claude Code. This hook was useful at least once (the 2026-04-14 incident's `until grep; do true; done` poll was a real, confirmed LLM output shape) and remains cheap to keep.
- **BashTool timeouts in `settings.json`.** Per [GH#5615](https://github.com/anthropics/claude-code/issues/5615), only `settings.json` `env.BASH_DEFAULT_TIMEOUT_MS` / `BASH_MAX_TIMEOUT_MS` actually bound BashTool calls — shell-env and wrapper timeouts are ignored because Claude Code manages the timeout internally. Values set:
  - `BASH_DEFAULT_TIMEOUT_MS=600000` (10 min) — default kill for any single BashTool call. Previously 5 min; relaxed to 10 min after the root cause was re-attributed, since fork-storm loops are not the primary threat and the tighter value was false-positiving on long-running builds.
  - `BASH_MAX_TIMEOUT_MS=3600000` (60 min) — hard ceiling even if the model requests longer.

**jq merge correctness fix** (unchanged from before). The previous `jq -s '.[0] * {"hooks": .[1].hooks}'` in `06-deploy-claude.zsh` was object-recursive but array-replacing, so any manual `PreToolUse` entry the user hand-added to `~/.claude/settings.json` got wiped on every deploy. Replaced with a concat-plus-dedupe jq expression that unions per-event arrays and deduplicates by exact JSON stringification. Repo-managed entries stay authoritative; manual entries survive re-deploy; two back-to-back deploys produce the same file.

### What was removed

- **`runaway-shell-watchdog` LaunchAgent** (`src/storage/claude/hooks/runaway-shell-watchdog.sh` + the plist generation in `06-deploy-claude.zsh`). Designed to catch orphaned `zsh -c … snapshot-zsh-*` descendants of `claude` older than 5 min — a threat shape tied to the now-discredited "runaway bash loops are the driver" framing. It added macOS surface area (a user LaunchAgent polling every 30 s, walking descendant trees of every `claude` PID) for a threat that wasn't the real one. `BASH_MAX_TIMEOUT_MS=3600000` already bounds any individual BashTool call; relying on Claude Code to honor its own timeout is a reasonable floor.
- **`scripts/test-hang-defense.zsh`**. The verification harness was built around the three-layer framing (including a ~6-min Layer-3 live-kill test). Without Layer 3 and without the "runaway loops are the driver" narrative, it no longer describes a meaningful defense posture.
- The deploy script (`06-deploy-claude.zsh`) now **unloads and removes any pre-existing** `com.cmagana.runaway-shell-watchdog.plist` and deployed `runaway-shell-watchdog.sh` on macOS, so `make deploy-claude` is the clean-up path on machines that had the old defense installed.

### Verification

```bash
# deny-busy-loops hook blocks / permits correctly
echo '{"tool_name":"Bash","tool_input":{"command":"until grep -q x y; do true; done"}}' \
  | ~/.claude/hooks/deny-busy-loops.sh; echo rc=$?       # rc=2 + deny msg
echo '{"tool_name":"Bash","tool_input":{"command":"until grep -q x y; do sleep 1; done"}}' \
  | ~/.claude/hooks/deny-busy-loops.sh; echo rc=$?       # rc=0, no output

# Settings.json has the expected shape
jq '.hooks.PreToolUse, .env' ~/.claude/settings.json
# expect: deny-busy-loops entry; BASH_DEFAULT_TIMEOUT_MS=600000, BASH_MAX_TIMEOUT_MS=3600000

# Legacy watchdog fully gone
launchctl list | grep runaway-shell-watchdog || echo "none (expected)"
ls ~/Library/LaunchAgents/com.cmagana.runaway-shell-watchdog.plist 2>/dev/null \
  || echo "gone (expected)"
ls ~/.claude/hooks/runaway-shell-watchdog.sh 2>/dev/null || echo "gone (expected)"

# Idempotency — two deploys, no growth
make deploy-claude && make deploy-claude
jq '.hooks.PreToolUse | length' ~/.claude/settings.json   # 1

# Manual-hook preservation
jq '.hooks.PreToolUse += [{"matcher":"Read","hooks":[{"type":"command","command":"/bin/true"}]}]' \
  ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
make deploy-claude
jq '[.hooks.PreToolUse[].matcher] | sort' ~/.claude/settings.json   # ["Bash","Read"]
```

### Community references

- [anthropics/claude-code#3981](https://github.com/anthropics/claude-code/issues/3981)
- [anthropics/claude-code#5615](https://github.com/anthropics/claude-code/issues/5615)
- [anthropics/claude-code#21048](https://github.com/anthropics/claude-code/issues/21048)
- [anthropics/claude-code#23181](https://github.com/anthropics/claude-code/issues/23181)
- [Apple Developer Forums — syspolicyd high CPU](https://developer.apple.com/forums/thread/121869)

---

## Recovery — if `syspolicyd` saturates again

SIP prevents user-space recovery on macOS 26.4 and later. `launchctl kickstart` returns "Operation not permitted." Reboot is the only reliable path.

Before rebooting, snapshot state for future investigation:

```bash
ps -p $(pgrep syspolicyd) -o pid,pcpu,etime,time
sample $(pgrep syspolicyd) 10 > /tmp/syspolicyd-sample.txt
log show --last 60s --predicate 'process == "syspolicyd"' --style compact > /tmp/syspolicyd-log.txt
ps auxf | grep -E '(claude|zsh -c|node.*kanban|node.*hooks)' > /tmp/claude-process-tree.txt
```

If the snapshot shows any third-party Claude Code harness registering hooks that resolve to Node spawns (check `jq '.hooks' ~/.claude/settings.json` and any harness-specific `settings.json` under the harness's config dir), suspect Kanban-class architecture and strip or matcher-narrow those hook registrations before re-enabling the harness.

---

## Known limits and things to watch

- **macOS behavior is not user-fixable.** `syspolicyd` is single-threaded and can stay in the bad state indefinitely with no input. The retained guardrails reduce probability of entering it; they don't fix the macOS bug.
- **Kanban-class hook architecture is the class threat, not the instance.** Any Claude Code harness that registers `matcher: "*"` hooks resolving to per-event Node spawns from a nvm-style path will reproduce this failure mode under multi-agent load. Before installing a new harness, inspect the `settings.json` it generates. Prefer harnesses whose hook commands are `/bin/bash` one-liners talking to a long-lived daemon (via curl + `--unix-socket`, named pipe, or similar), not fresh Node spawns.
- **The deny-busy-loops pattern library is narrow.** A model-generated shape that isn't in the list slips through. If you observe a new shape, extend `deny-busy-loops.sh`.
- **Binary updates invalidate the signing cache.** Claude auto-updates daily; Homebrew upgrades rotate cdhashes. With healthy `syspolicyd`, cold-path validation is ~10-20 ms (measured 2026-04-15 with healthy syspolicyd, 12h uptime, no Kanban). The multi-second cold-path costs originally measured were artifacts of already-saturated `syspolicyd`, not intrinsic signing cost.
- **Report upstream.** Anthropic should ship sane default BashTool timeouts out of the box (see the GH issues above). Kanban should replace its per-event Node-spawn hooks with a UDS daemon or statically compiled shim. The retained guardrails here are a user-side stopgap until those land.

---

## File index — the artifacts that remain

```
src/storage/zsh/.zshrc                         # lazy nvm shims
src/storage/claude/hooks/deny-busy-loops.sh    # narrow PreToolUse guard
src/storage/claude/hooks.json                  # PreToolUse registration
src/deployment/06-deploy-claude.zsh            # deploys hooks/, merges env + timeouts, cleans up legacy watchdog, jq concat-dedupe merge
scripts/bench-startup.zsh                      # sequential/profile/trace/purge/compare bench modes
scripts/bench-results.log                      # historical bench runs
```
