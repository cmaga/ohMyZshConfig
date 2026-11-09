# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A cross-platform (macOS / Linux / Windows via Git Bash) dotfiles deployment system for Oh-My-Zsh, git, and Claude Code configuration. It deploys *from* `src/storage/` *into* the user's home directory using a numbered pipeline of zsh scripts driven by a `Makefile`.

This repo previously targeted Cline as the AI assistant — that migration to Claude Code is complete at the system level. Project-level Cline artifacts (`.clinerules/`, `.cline-project/`) are being removed separately.

## Common commands

- `make setup` — full fresh-system bootstrap (permissions → simple deps → company setup → zsh → git → claude → finalize). Idempotent.
- `make update` (alias `glc`) — pull, then run only the deploy targets whose files changed since the commit recorded in `.git/deployed-head` (full deploy when there is no record).
- `make deploy` — deploy all configs to an existing system (`deploy-zsh` + `deploy-git` + `deploy-claude` + `finalize`).
- `make deploy-zsh` / `make deploy-git` / `make deploy-claude` — deploy one subsystem. Each is self-contained (install + configure).
- `make amazon-laptop` / `make amazon-desktop` — deploy a work machine's profile (`PROFILE_TARGETS` in `lib/common.zsh`) and record it in `.git/deploy-profile`, after which `make update` deploys only those targets. Both take the full `deploy-zsh` (Oh-My-Zsh, plugins, `.zshrc`, aliases, scripts); the desktop adds `deploy-claude-config`, which deploys Claude config with no CLI install, company accounts or proxy, and `deploy-timesheet`, which deploys only the `timesheet` and `timesheet-fill` automations (`08-deploy-automations.zsh` deploys just the standalone automations it is given by name). Neither runs `deploy-git` or company setup: the private Amazon repo that drives these profiles owns git identities and keeps what Amazon's installers add to `~/.zshrc` in `~/.zshrc.local`. `deploy-zsh-config` (aliases and scripts only, into `~/.config/ohmyzshconfig/` without Oh-My-Zsh) is no longer part of a profile.
- `make lint` — runs `zsh -n` syntax check on all deployed `.zsh` files, fixes missing executable bits, and validates `plugins.txt` format. Pre-commit hook (`hooks/pre-commit`) invokes this; `make setup` wires `core.hooksPath` to `hooks/`.
- `./scripts/bench-startup.zsh --label before` / `--label after` / `--compare` — measure zsh interactive startup time (writes to `scripts/bench-results.log`).

Bootstrap scripts (run *before* `make setup` on a fresh machine) live under `src/deployment/bootstrap/{macos,linux,windows}/` and install the platform prerequisites (git, make, zsh, nvm, Node LTS, pnpm).

## Architecture

### Storage vs deployment split

- `src/storage/` — **what** gets deployed. Treat these as source-of-truth copies of files that end up on the user's system.
- `src/deployment/` — **how** it gets deployed. Numbered scripts (`01`–`07`) indicate phase order.
- A subsystem is "add a new thing I want on every machine" → put the files under `src/storage/<name>/`, write (or extend) a deploy script in `src/deployment/`, add a Makefile target, and wire it into `setup`/`deploy`.

### Deployment pipeline (numbered scripts)

`01-bootstrap.sh` (platform-specific) → `02-simple-deps.zsh` → `03-company-setup.zsh` → `04-deploy-zsh.zsh` → `05-deploy-git.zsh` → `06-deploy-claude.zsh` → `07-finalize.zsh`.

Every deployment script sources `src/deployment/lib/common.zsh` and **must be idempotent** (re-runnable any number of times). Install steps check for existing install first and skip.

### `src/deployment/lib/common.zsh`

Shared library every deploy script sources. Use these instead of reinventing:

- Logging: `log`, `warn`, `error` (exits), `info`, `action`, `print_status <type> <msg>` (types: info/success/error/warning/action/install/download).
- Platform: `detect_os` → `macos|linux|windows|unknown`; `detect_package_manager` → `brew|apt|dnf|yum|pacman|zypper|unknown`.
- Paths: `get_script_dir`, `get_project_root`, `get_storage_dir`, `get_deployment_dir`. Also exports `OMZ_DIR`, `CLAUDE_DIR`, `CLAUDE_SKILLS_DEST`, `CLAUDE_AGENTS_DEST`.
- Utilities: `command_exists <cmd>`; `install_package <pkg>` (dispatches to the right package manager).

### Zsh deployment (`04-deploy-zsh.zsh`)

Installs zsh → `chsh` to zsh → installs Oh-My-Zsh → installs/updates every plugin listed in `plugins.txt` (format: `username/repo`, one per line, `#` for comments; an update resets onto the remote's default branch, both clone and update use `core.autocrlf=false`, and symlinks Git for Windows checked out as text stand-ins are replaced with copies of their targets) → copies `src/storage/zsh/.zshrc` → `~/.zshrc`, `aliases.zsh` → `$OMZ_DIR/custom/aliases.zsh`, `src/storage/scripts/*` → `$OMZ_DIR/custom/scripts/`.

Adding plugins: append to `plugins.txt`, then `plugins=(…)` array in `src/storage/zsh/.zshrc`, then `make deploy-zsh`.

### Claude Code deployment (`06-deploy-claude.zsh`)

Installs the Claude CLI with the native installer (`claude.ai/install.sh`, into `~/.local/bin`; skipped on Windows), then deploys from `src/storage/claude/` to `~/.claude/`:

- `CLAUDE.md` → `~/.claude/CLAUDE.md` (this is the **global** CLAUDE.md for all projects — separate from the repo-root one you're reading now).
- `rules/*.md` → `~/.claude/rules/`.
- `skills/<name>/` → `~/.claude/skills/<name>/` via `rsync --exclude=dependencies/repos/ --exclude=artifacts/` (with a manual `find | cp` fallback). After copying, if `<skill>/dependencies/scripts/update-repo.zsh` exists, it runs to clone/update repo dependencies.
- `agents/*.md` → `~/.claude/agents/`.
- `hooks/*.sh` → `~/.claude/hooks/` with `chmod +x` on each destination.
- `statusline-command.sh` → `~/.claude/statusline-command.sh`; `statusLine` in `~/.claude/settings.json` is set to run it.
- `hooks.json` is **merged** into `~/.claude/settings.json` via a concat-plus-dedupe jq expression (requires `jq`). Per-event hook arrays (`PreToolUse`, `PostToolUse`, etc.) are concatenated and deduplicated by exact JSON stringification, so repo-managed entries stay authoritative but manual additions survive re-deploy. Empty `hooks` is skipped.
- `BASH_DEFAULT_TIMEOUT_MS` (10 min) and `BASH_MAX_TIMEOUT_MS` (60 min) are merged into `~/.claude/settings.json` under `env` so runaway BashTool calls can't run unbounded. A companion `deny-busy-loops` PreToolUse hook blocks known no-yield loop shapes as a narrow safety rail. See `docs/terminal-hangs.md` for the full investigation.
- Temporary: `remove_jcodemunch_mcp` drops the jCodemunch MCP registration that earlier deploys added, from `~/.claude.json` and each company account. Delete it once every machine has deployed past it (see the note on the function).
- Per-company accounts: for each company in `COMPANIES` (`lib/common.zsh`, shared with `03-company-setup.zsh`) it creates `~/.claude-<company>`, links CLAUDE.md, rules, skills, agents, hooks, settings.json, plugins and projects back to `~/.claude`. Only the login and `.claude.json` are per account. `oc` sets `CLAUDE_CONFIG_DIR` to that directory under `~/dev/<company>/`.

Skills have a conventional structure: `SKILL.md` (required), optional `dependencies/` (templates/docs/scripts, with `repos/` gitignored and fetched at deploy time), optional `modes/`, `evals/`, `human/`, `artifacts/` (runtime-only, gitignored except `.gitkeep`).

### The floor plan

Everything under `src/storage/claude/` is organized as a kitchen (design: `docs/kitchen.md`). Every skill, agent, rule, and hook belongs to exactly one area, and an area depends only on areas below it. A new piece gets an area before it gets written.

| Area | Holds | Pieces |
|---|---|---|
| Office | Improving the kitchen itself | `memory-use` rule, `memory-review`, `claude-feature-authoring` |
| Standards | Rules every cook follows everywhere | `CLAUDE.md`, rules `cli-rules`, `code-quality`, `response-length`, `research-before-recommending`; `deny-busy-loops` hook |
| The line | Orders in, PRs out | `kitchen` (server, expo, status, sous chef, the pass, the roster: who cooks on which model) |
| Recipes | One per kind of work, with shared stations and principles (forked from pstack) | `kitchen/commands/cook/recipes/`, `kitchen/commands/cook/stations/`, `kitchen/dependencies/principles/` |
| Techniques | Skills a recipe uses that also stand alone | `frontend-design` |
| Equipment | Connections to outside systems | `jira`, `git-provider`, `playwright-mcp-setup`; `claude-proxy` automation |
| Brigade | Agents | line cook `worker-agent`, `deepseek-flash-agent`; tasters `taster-agent`, `comment-sicko-agent` |
| The house | Per project: house rules, verify skill, and the vault as the restaurant's binder | `capture-documentation`, `vault-scribe-agent`, `adr-auditor-agent`, `knowledge-vault-use` rule, `guard-vault-write` hook |

Outside the kitchen: `skill-eval`, `standup` and the `timesheet` and `timesheet-fill` automations (multi-project Harvest time; what differs per machine, client project names included, lives in `~/.config/harvest/timesheet.toml`, never in this repo: see `harvest-lib.zsh`), the `dashboard-tunnel` automation, the `clear-symdocs-claude-md` hook, and the status line.

### Platform handling in `.zshrc`

`src/storage/zsh/.zshrc` has a `case "$OSTYPE"` block with branches for `darwin*`, `linux*`, and `msys*|cygwin*|mingw*`. The Windows branch does nvm-windows PATH wiring (via `cygpath`) and auto-starts/loads `ssh-agent` from `~/.ssh/agent.env`. macOS/Linux rely on system keychain.

Machine-specific overrides (intentional): `~/.zshrc.local` and `~/.zshrc.$(hostname)` are sourced at the end if present — do not overwrite them.

## Conventions

- **ANSI-C quoting for color codes**: `RED=$'\033[0;31m'`, not `RED='\033[0;31m'` + `echo -e`. `echo -e` behavior differs across shells. See `src/deployment/lib/common.zsh` for the canonical definitions.
- **Always pass `--no-pager` as a top-level git option** (before the subcommand): `git --no-pager log …`. `git log --no-pager` errors. CLI commands that would invoke a pager will hang the session.
- Pass single-line strings to CLI commands — multi-line quoted strings get mangled through terminal/shell parsing.
- **Deploy scripts never delete files.** A retired skill or file stays deployed until the user removes it. Two exceptions: a deployed skill drops files its source no longer has, and a disabled or retired automation is unloaded and its plist, unit and directory removed.
- Deploy scripts must remain idempotent. When adding a step, check current state first and no-op if already applied.
- **Never start a process per item in a loop.** A process start costs ~20ms under Git Bash against ~1ms on macOS/Linux, so a grep per symbol made the vault linter take 15s on an 88-note vault. Batch the work into one awk or git call over every item, and keep loop bodies to builtins. Git for Windows ships GNU grep 3.0, whose `grep -wF` in the C locale also matches inside words (`bc` in `abc`); do word matching in awk instead.
- **Deploy output must be inert if pasted into a shell.** Pasted output once ran line by line and truncated every deployed file through its `name -> path` summary. Print `name: path`, keep `>`, `|`, `;`, `&` and backticks out of printed text, and quiet git commands whose output carries them (diffstats, `-> FETCH_HEAD`).
- Scripts that are meant to be executed need their exec bit set; `make lint` and `make setup` fix this, but new scripts should be created with `chmod +x`.
- **The `find | cp` fallback in `06-deploy-claude.zsh` is the supported copy path.** Never propose installing `rsync`, and never treat its absence as a defect — the pipeline deploys with only what a stock Git Bash, macOS, or Linux shell provides, and depending on an extra binary is the thing being avoided. Fix copy defects inside the fallback.
