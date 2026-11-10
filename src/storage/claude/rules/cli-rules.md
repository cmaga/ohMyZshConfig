# CLI Usage Rules

- Never let a CLI command drop into an interactive pager — it blocks the session until the user manually resolves it. Before running anything that  
  pages by default (git log/diff/show/blame, less-wrapped man output, etc.), disable the pager on the **first** attempt.
- **git:** `--no-pager` is a top-level git option, NOT a subcommand flag. It must come immediately after `git`:
  - Correct: `git --no-pager log -20`
  - Wrong: `git log --no-pager -20` (fails with `fatal: unrecognized argument: --no-pager`)
- For other tools, use the equivalent flag (e.g. `| cat`, `PAGER=cat`, `--no-pager`, `-P`) appropriate to that CLI.
- **Write shell commands Claude Code can verify before they run.** It asks the user about any it cannot, which stalls an unattended session:
  - Give `rm` literal paths or `"${VAR:?}"`, never `$(...)` output.
  - Keep `rm` out of any command that runs a `bash -c` or `zsh -c` script; put the script in a file.
  - Background with `run_in_background`, not `&`.
