# Best Practices

## Rules Overview

This project is used to store and apply user configuration across several systems and operating systems that include:

- Pop OS
- Windows 11
- Mac OS

This file details some learned best practices that should be taken as rules to avoid encountering the same problems again in the future.

## Shell Script Escape Sequences

- **Use ANSI-C quoting (`$'...'`) for escape sequences** — this resolves escapes at parse time and works identically across bash and zsh on all platforms.

  ```zsh
  # ✅ Correct
  RED=$'\033[0;31m'
  echo "${RED}error${NC}"

  # ❌ Wrong — prone to double-escaping and inconsistent behavior across shells
  RED='\\033[0;31m'
  echo -e "${RED}error${NC}"
  ```

- **Avoid `echo -e`** — its behavior varies between shells and platforms. With ANSI-C quoting, plain `echo` is sufficient since the escape characters are already embedded in the variable value.
- See `hooks/pre-commit` for a reference implementation.

## Git Pager Handling

- **Always use `--no-pager` for git commands that produce output** - Git commands like `log`, `diff`, `branch -l`, `show` invoke a pager by default, which causes the process to hang waiting for input in automated/headless contexts.

  ```zsh
  # Correct
  git --no-pager branch -l 'feature/*' --format='%(refname:short)'
  git --no-pager log --oneline -10

  # Wrong - will hang in automated contexts
  git branch -l 'feature/*' --format='%(refname:short)'
  git log --oneline -10
  ```

- Commands that don't need `--no-pager`: `git worktree list --porcelain`, `git status --porcelain`, `git commit`, `git push`, `git fetch`

## CLI Command Arguments

- **Always use single-line strings for CLI arguments** - Multi-line strings passed to CLI commands get mangled due to terminal interpretation of newlines and quote handling.

  ```zsh
  # Correct - single line
  cline -y -c "./wt/STAX-218" "Implement STAX-218: E2E tests for generation wizard. Create file: frontend/tests/e2e/generation.spec.ts. Test scenarios: browse catalog, select form, configure generation, submit job, verify progress, download output, verify token balance."

  # Wrong - multi-line string causes parsing issues
  cline -y -c "./wt/STAX-218" "Implement STAX-218: E2E tests
  for generation wizard.

  ## Test Scenarios
  1. Browse form catalog
  2. Select a form"
  ```

- When content must include line breaks in the actual output, use `\n` escape sequences within a single-line string, or pass content via a file instead of inline arguments.

## DO NOT

- Run make deploy or any of the deploy commands. Users must do this manually for system stability.
