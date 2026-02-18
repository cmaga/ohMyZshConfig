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
