# Terminal startup optimization on macOS

## Summary

Terminal tabs on this Mac were hanging for 30 seconds to 4+ minutes on open. The cause was not any single thing in `.zshrc` — it was macOS's code-signing validation path (`syspolicyd`) being brutally slow on the *cold path*: the first launch of any Developer-ID-signed binary with no cached verdict. Once cached, the same binary launches in ~20 ms. The old `.zshrc` invoked `node --version` during every shell startup, which dragged shell-open latency onto that slow cold path whenever the cache was cold.

The fix is a layered workaround, because the underlying macOS behavior is not user-fixable:

1. Shell startup no longer launches any Developer-ID-signed binary (lazy nvm).
2. `/usr/bin/git` no longer spawns `xcodebuild` (`xcode-select` reconfigured).
3. A boot-scoped prewarm script pays the cold-cache cost in the background for common tools, so interactive commands hit the warm path.

All three are deployed from this repo.

## Symptoms

- A new iTerm tab would appear but block for 30 s – 4+ min before the prompt appeared.
- Behavior was intermittent but strongly correlated with many concurrent Claude Code sessions (12+ running simultaneously).
- `./scripts/bench-startup.zsh --label X --count 20` reported ~1 s median — nowhere near the user-observed hang. That mode runs 20 shells in parallel and they share FS page cache + signing cache, masking the real first-shell cost.
- `./scripts/bench-startup.zsh --sequential --label X --count 8` (introduced during investigation) showed the real cost: first shell 260 s, because each sequential spawn hits the cold path independently.
- Earlier `.zshrc` versions introduced a lazy-nvm loader that broke Claude Code's `Bash` tool with `command not found: _nvm_load` and `FUNCNEST` errors — a symptom of the Claude Code shell-snapshot filter (see below).

## Root causes

Two distinct issues stacked on top of each other. They look like one problem from the outside.

### 1. macOS code-signing cold path is pathologically slow

Every Developer-ID-signed binary launch goes through `syspolicyd` → trust evaluation → kernel AMFI. The first launch of a given code-directory hash (cdhash) that isn't in the kernel trust cache runs full certificate-chain validation. On this machine the cold path reproducibly takes minutes.

Evidence collected during investigation:

| Binary | Type | Cold | Warm |
|---|---|---|---|
| `/bin/true`, `/bin/sh -c exit` | Apple system | 0.001 s | 0.001 s |
| `/usr/bin/jq` | Apple system | 0.00 s | 0.00 s |
| `/opt/homebrew/bin/gh --version` | Developer-ID | **246.57 s** | 0.02 s |
| `/Users/cmagana/.nvm/.../node --version` | Developer-ID | hangs indefinitely | (cached = fast) |

- `sample <pid>` on every hung Dev-ID binary showed 100% of samples in `_dyld_start` with zero CPU — blocked in kernel waiting on AMFI validation, not spinning.
- `ps -o pcpu,etime,stat` confirmed `syspolicyd` (PID 586) pegged at 77% of one core with 530 CPU-minutes accumulated over 6 days of uptime. On a 16-core Mac this is one fully saturated core — `syspolicyd` is effectively single-threaded for validation work.
- `log show --predicate 'process == "syspolicyd"' --last 30s` was dumping **7,730 `Dropping "com.apple.Gatekeeper.PolicyViolation"` events** in 30 s (~258/s). That's the CoreAnalytics pipeline emitting events for a transform that isn't registered on this macOS version (macOS 26.4, build 25E246) — Apple's own analytics config is missing a handler, so events get emitted and dropped in a loop. Not the *cause* of the cold-path slowness, but a signature of `syspolicyd` being in a bad state.
- `curl -sS -m 5 http://ocsp.apple.com/ocsp03-appleca` returned in 92 ms — OCSP responder is healthy and not the cause.
- `profiles status` returned "no configuration profiles installed" — this is a personal machine, not MDM-managed. (Initial assumption that it was MDM-managed was wrong.)

The caching works perfectly: after a single cold validation, the same binary launches in 20 ms forever (until cdhash changes, typically via a binary update or a reboot clearing the kernel trust cache).

So the cost is **once per unique cdhash per boot**, not per launch — but that "once" can be several minutes, and Claude auto-updates daily (new cdhash every day), Homebrew upgrades rotate cdhashes, and reboots drop the whole in-memory cache.

### 2. `.zshrc` dragged the cold path into shell startup

The previous `.zshrc` had two problems that made the cold-path issue user-visible on every terminal open instead of just once-per-binary-per-day:

- **Eager `source /opt/homebrew/opt/nvm/nvm.sh`** in the `darwin*` branch. `nvm.sh` internally runs `node --version` to determine the active version. Every shell spawn → one Dev-ID binary launch. If that binary's cache entry was cold, every shell spawn waited for it.
- **Underscore-prefixed helper functions** (`_nvm_load`, `_lazy_direnv_hook`, `_direnv_export`) were filtered out of Claude Code's per-Bash-tool shell snapshot at `~/.claude/shell-snapshots/snapshot-zsh-*.sh`. The snapshot's function extractor keeps non-underscored function definitions but omits underscore-prefixed ones. Claude's Bash tool sourced a snapshot that referenced `_nvm_load` but did not define it, causing `command not found` on every `npm`/`node`/`nvm` call and eventually a `FUNCNEST` recursion death.

### 3. `/usr/bin/git` silently runs `xcodebuild`

Orthogonal issue discovered during diagnosis. `/usr/bin/git` is a Mach-O shim (`com.apple.dt.xcode_select.tool-shim-public`). When `xcode-select -p` returns `/Applications/Xcode.app/Contents/Developer`, the shim launches `xcodebuild` to resolve the real git path. `xcodebuild` is a Developer-ID-signed behemoth that takes its own cold-path hit. When `xcode-select` points to `/Library/Developer/CommandLineTools`, the shim resolves directly with no `xcodebuild` spawn.

Evidence: `sample <git-pid>` caught git stuck in `xcselect_invoke_xcrun` → `fgetln` → `__read_nocancel`, reading from a pipe to a hung `xcodebuild` child.

## What was changed

All changes live in this repo and deploy via `make deploy-zsh`.

### 1. Lazy nvm with snapshot-safe shims

**File:** `src/storage/zsh/.zshrc` (`darwin*`, `linux*`, and `*)` branches of the `OSTYPE` case).

Replaces the eager `source nvm.sh` with a `nvm_lazy_init` function plus six per-binary shims (`nvm`, `node`, `npm`, `npx`, `pnpm`, `yarn`). All names deliberately omit the underscore prefix so they survive Claude Code's shell-snapshot function filter. The init helper unsets all shims first so `nvm.sh` cannot re-enter them while loading.

Net effect: shell startup runs only Apple-signed binaries plus zsh script reads. No cold-path validation ever hits the terminal-open critical path.

### 2. Non-underscored direnv hook

**File:** `src/storage/zsh/.zshrc`, direnv block.

Renamed `_direnv_export` → `direnv_export` and `_lazy_direnv_hook` → `lazy_direnv_hook`. Behavior unchanged in the interactive shell; now the hook actually fires in Claude Code's Bash tool because the function survives the snapshot filter. Previously, `.envrc` auto-loading silently did not work inside Claude Code sessions.

### 3. `xcode-select` pointed at Command Line Tools

Ran `sudo xcode-select -s /Library/Developer/CommandLineTools`. Not a repo change (it's per-machine state), but needs to be repeated on any new system that defaults to Xcode.app.

Verification: `xcode-select -p` should return `/Library/Developer/CommandLineTools`.

### 4. Boot-scoped cache prewarm

**Files:**
- `src/storage/scripts/prewarm-cache.zsh` — the script. Fires `--version` in parallel for a list of common Developer-ID-signed tools (gh, git, node across nvm versions, rg, jq, fd, bat, pnpm, yarn, tmux, docker, direnv, fzf, helm, kubectl, terraform, aws, python3). Skips missing binaries. No-op on non-macOS.
- `src/storage/zsh/.zshrc` — a small hook near the end (after the `case` block, before the aliases source) that detects first shell after boot via `/tmp/.zshrc-cache-prewarmed` sentinel and launches the script with `&!` (zsh detached background) so the shell doesn't wait on it. `/tmp` is cleared at reboot, so the sentinel naturally scopes to "once per boot."

Net effect: after login, the prewarm script pays the cold-path cost for common tools in the background (can take several minutes). Interactive commands typed afterward all hit the warm path and return instantly.

### 5. Investigation tooling: new bench modes

**File:** `scripts/bench-startup.zsh` (rewritten).

The original `--parallel` mode is kept for backward-compat but flagged as misleading — 20 parallel shells share FS and signing caches, hiding cold cost. New modes added:

- `--sequential --label NAME [--count N]` — runs shells one at a time; reproduces the real user-visible cold-path behavior.
- `--profile [--iterations N]` — uses `zmodload zsh/zprof` via a `ZDOTDIR` wrapper to dump top-N slowest functions during a single startup.
- `--trace` — xtrace with per-line timestamps; summarizes hottest lines.
- `--purge` — modifier: `sudo purge` between runs to drop FS cache. Needs sudo cached.

`--compare` still reads `scripts/bench-results.log` for side-by-side tables.

## How to verify the fix is working

### Quick sanity checks

Open a new terminal. It should appear instantly. `time zsh -i -c exit` should be under 500 ms in steady state (once OMZ and plugins have warmed the FS cache once).

Check `xcode-select`:
```
xcode-select -p
# expected: /Library/Developer/CommandLineTools
```

Check deployed files match source:
```
/usr/bin/diff -q src/storage/zsh/.zshrc ~/.zshrc
/usr/bin/diff -q src/storage/scripts/prewarm-cache.zsh ~/.oh-my-zsh/custom/scripts/prewarm-cache.zsh
# expected: no output (files identical)
```

Confirm prewarm fired at least once since last boot:
```
ls -la /tmp/.zshrc-cache-prewarmed
# expected: file exists, mtime is at-or-after last boot
```

Confirm the prewarm hook is in `~/.zshrc`:
```
grep -c "prewarm-cache" ~/.zshrc
# expected: 2 (one comment reference, one invocation)
```

### Running the bench

Use the sequential mode to get realistic numbers:

```
./scripts/bench-startup.zsh --sequential --label check --count 5
```

Expected steady-state: 0.2 – 0.6 s per shell. If any shell takes more than ~5 s, you are hitting the cold path — something is still on the critical path that shouldn't be, or the prewarm isn't working.

Save a baseline each time you meaningfully change `.zshrc`:

```
./scripts/bench-startup.zsh --sequential --label pre-change --count 5
# ... make changes ...
./scripts/bench-startup.zsh --sequential --label post-change --count 5
./scripts/bench-startup.zsh --compare
```

### Checking that cache is actually populated

Pick a Developer-ID binary in the prewarm list. Time it:

```
/usr/bin/time -p /opt/homebrew/bin/gh --version
```

Expected: `real` time of 0.02 s or so. If it's 10+ seconds or hangs, the prewarm either hasn't run yet (check the sentinel) or the binary isn't in the prewarm list.

### Checking syspolicyd health

If hangs come back, sample syspolicyd state:

```
ps -p $(pgrep syspolicyd) -o pid,pcpu,etime,time
```

If CPU time keeps growing faster than elapsed wall time, it's saturated. Look at the log:

```
log show --last 10s --predicate 'process == "syspolicyd"' --info --style compact | awk 'NR>1 {print $6}' | sort | uniq -c | sort -rn | head
```

If you see thousands of `Dropping` events, the CoreAnalytics drop loop is active — a temporary kickstart will help:

```
sudo launchctl kickstart -k system/com.apple.security.syspolicy
```

(Service label is `com.apple.security.syspolicy`, not `com.apple.syspolicyd`, despite the binary being at `/usr/libexec/syspolicyd`.)

## How to diagnose a regression

If terminals start hanging again:

1. **Is `~/.zshrc` in sync with the repo?** `diff -q src/storage/zsh/.zshrc ~/.zshrc`. If they differ, someone or something edited `~/.zshrc` directly. Redeploy via `make deploy-zsh` or `/bin/cp`.

2. **Did the prewarm sentinel get stuck?** `ls -la /tmp/.zshrc-cache-prewarmed`. If the sentinel exists but mtime is old (before last boot), something is wrong with `/tmp` cleanup. Delete the sentinel and open a new terminal — it will re-fire.

3. **Is the prewarm script actually executable?** `ls -l ~/.oh-my-zsh/custom/scripts/prewarm-cache.zsh`. Needs `+x`.

4. **Is a new binary on the critical path?** Use `--trace` mode to find it:
   ```
   ./scripts/bench-startup.zsh --trace
   ```
   Look for lines that take hundreds of ms or more. If a new Developer-ID-signed tool has been added to `.zshrc`'s startup path, move it to lazy-load or add it to the prewarm list.

5. **Is syspolicyd stuck?** See the log-show command above. Kickstart fixes it short-term; reboot fixes it for longer.

6. **Did a Homebrew/nvm/Claude update invalidate caches?** Every binary update changes the cdhash and forces one cold validation. This is expected. The prewarm script should absorb it on next login, or you can trigger manually:
   ```
   ~/.oh-my-zsh/custom/scripts/prewarm-cache.zsh
   ```
   (Runs in foreground, will take minutes. Run after a round of updates to pre-pay the cost.)

## Reproducing the original bug

To re-experience the hang for future investigation:

1. Revert to eager source of nvm.sh in `src/storage/zsh/.zshrc` (or temporarily comment out `nvm_lazy_init` and uncomment a direct `source`).
2. Reboot — clears kernel trust cache.
3. **Before** opening any new terminal, `rm /tmp/.zshrc-cache-prewarmed` so the prewarm hook won't fire the prewarm script.
4. `./scripts/bench-startup.zsh --sequential --label repro --count 3`.

Shell 1 should take minutes. Shells 2 and 3 should be fast (cached by shell 1's validation). If you want all three slow, reboot between each — or use `--purge` if you have `sudo` cached (drops FS cache but not code-signing cache; may or may not reproduce).

## Known limitations and caveats

- **This works around, but does not fix, the underlying macOS behavior.** `syspolicyd` is single-threaded and its cold path can be arbitrarily slow under load. A future macOS update may fix or worsen it.
- **Prewarm list is static.** If you install a new Dev-ID tool and put it on your startup path, add it to `src/storage/scripts/prewarm-cache.zsh`. Otherwise its first interactive launch each boot will cold-hit.
- **Binary updates invalidate the cache.** Claude auto-updates daily (new cdhash → one cold validation per boot-or-update cycle). Homebrew upgrades do the same per upgraded binary. The prewarm script covers most common tools, so in practice the cost is absorbed in the background, but if a major upgrade lands mid-session, the first call to the upgraded binary will be slow.
- **`/tmp` cleanup is semi-reliable on macOS.** The prewarm sentinel assumes `/tmp` is cleared at reboot. If macOS ever stops doing that, the prewarm won't re-fire on subsequent boots and you'd have stale warm-cache assumptions. Easy to verify: `ls -la /tmp/.zshrc-cache-prewarmed` should show a recent mtime.
- **The direnv fix assumes direnv is installed.** The `.zshrc` block checks `command -v direnv`; no direnv means the hook is skipped entirely. Deploying to a new machine without direnv is safe.
- **The bench script's `--sequential` mode takes time when the cold path is active.** Each shell may take minutes on a truly cold system. Budget accordingly or use `--count 3` instead of 20.
- **macOS version sensitivity.** This investigation was done on macOS 26.4 (build 25E246). The CoreAnalytics drop loop and the "validates validation category policy" messages are specific to modern macOS (Sonoma+). Older macOS may not exhibit the same symptoms.

## File index

Changes introduced by this work, for cross-referencing:

- `src/storage/zsh/.zshrc` — lazy nvm, renamed direnv hooks, prewarm invocation hook.
- `src/storage/scripts/prewarm-cache.zsh` — prewarm script (new).
- `scripts/bench-startup.zsh` — rewritten with sequential/profile/trace/purge/compare modes.
- `scripts/bench-results.log` — historical bench results including the sequential run that first exposed the cold path.
- `docs/terminal-optimization.md` — this document.
