# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A cross-platform (macOS / Linux / Windows via Git Bash) dotfiles deployment system for Oh-My-Zsh, git, direnv, and Claude Code configuration. It deploys *from* `src/storage/` *into* the user's home directory using a numbered pipeline of zsh scripts driven by a `Makefile`.

This repo previously targeted Cline as the AI assistant — that migration to Claude Code is complete at the system level. Project-level Cline artifacts (`.clinerules/`, `.cline-project/`) are being removed separately.

## Common commands

- `make setup` — full fresh-system bootstrap (permissions → simple deps → company setup → zsh → git → claude → finalize). Idempotent.
- `make deploy` — deploy all configs to an existing system (`deploy-zsh` + `deploy-git` + `deploy-claude` + `finalize`).
- `make deploy-zsh` / `make deploy-git` / `make deploy-claude` — deploy one subsystem. Each is self-contained (install + configure).
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

Installs zsh → `chsh` to zsh → installs Oh-My-Zsh → installs/updates every plugin listed in `plugins.txt` (format: `username/repo`, one per line, `#` for comments) → copies `src/storage/zsh/.zshrc` → `~/.zshrc`, `aliases.zsh` → `$OMZ_DIR/custom/aliases.zsh`, `src/storage/scripts/*` → `$OMZ_DIR/custom/scripts/`, `src/storage/direnv/direnv.toml` → `~/.config/direnv/direnv.toml`.

Adding plugins: append to `plugins.txt`, then `plugins=(…)` array in `src/storage/zsh/.zshrc`, then `make deploy-zsh`.

### Claude Code deployment (`06-deploy-claude.zsh`)

Installs `@anthropic-ai/claude-code` via npm (skipped on Windows), then deploys from `src/storage/claude/` to `~/.claude/`:

- `CLAUDE.md` → `~/.claude/CLAUDE.md` (this is the **global** CLAUDE.md for all projects — separate from the repo-root one you're reading now).
- `rules/*.md` → `~/.claude/rules/`.
- `skills/<name>/` → `~/.claude/skills/<name>/` via `rsync --exclude=dependencies/repos/ --exclude=artifacts/` (with a manual `find | cp` fallback). After copying, if `<skill>/dependencies/scripts/update-repo.zsh` exists, it runs to clone/update repo dependencies.
- `agents/*.md` → `~/.claude/agents/`.
- `hooks.json` is **merged** into `~/.claude/settings.json` via `jq -s '.[0] * {"hooks": .[1].hooks}'` (requires `jq`). Empty `hooks` is skipped.

Skills have a conventional structure: `SKILL.md` (required), optional `dependencies/` (templates/docs/scripts, with `repos/` gitignored and fetched at deploy time), optional `modes/`, `evals/`, `human/`, `artifacts/` (runtime-only, gitignored except `.gitkeep`).

### Platform handling in `.zshrc`

`src/storage/zsh/.zshrc` has a `case "$OSTYPE"` block with branches for `darwin*`, `linux*`, and `msys*|cygwin*|mingw*`. The Windows branch does nvm-windows PATH wiring (via `cygpath`) and auto-starts/loads `ssh-agent` from `~/.ssh/agent.env`. macOS/Linux rely on system keychain. A lazy direnv hook (`chpwd_functions`) runs with a 5s perl-alarm timeout so a hung direnv can't block the shell.

Machine-specific overrides (intentional): `~/.zshrc.local` and `~/.zshrc.$(hostname)` are sourced at the end if present — do not overwrite them.

## Conventions

- **ANSI-C quoting for color codes**: `RED=$'\033[0;31m'`, not `RED='\033[0;31m'` + `echo -e`. `echo -e` behavior differs across shells. See `src/deployment/lib/common.zsh` for the canonical definitions.
- **Always pass `--no-pager` as a top-level git option** (before the subcommand): `git --no-pager log …`. `git log --no-pager` errors. CLI commands that would invoke a pager will hang the session.
- Pass single-line strings to CLI commands — multi-line quoted strings get mangled through terminal/shell parsing.
- Deploy scripts must remain idempotent. When adding a step, check current state first and no-op if already applied.
- Scripts that are meant to be executed need their exec bit set; `make lint` and `make setup` fix this, but new scripts should be created with `chmod +x`.

## Code exploration

This repo is indexed for jCodemunch-MCP (repo id: `local/ohMyZshConfig-7dbefa5a`). Prefer `search_symbols` / `get_file_outline` / `get_file_content` over raw file reads for navigation.
