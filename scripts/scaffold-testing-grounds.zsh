#!/usr/bin/env zsh
#
# scaffold-testing-grounds.zsh - One-shot scaffolding for the hang investigation.
#
# Creates 50 language-named subdirs under testing_grounds/, each with a minimal
# .envrc that exports two dummy env vars. Also creates testing_grounds/heavy/
# with an .envrc that exercises a subshell + external command (to contrast
# against the minimal case). Runs `direnv allow` on every .envrc so subsequent
# shell spawns don't refuse to evaluate them.
#
# Idempotent: safe to re-run. testing_grounds/ is gitignored (see .gitignore).

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
GROUND="$REPO_ROOT/testing_grounds"

typeset -a LANGS
LANGS=(
  python javascript typescript go rust
  java kotlin swift ruby php
  csharp cpp c scala haskell
  elixir erlang clojure lua perl
  r julia dart ocaml fsharp
  nim crystal zig racket scheme
  lisp prolog smalltalk ada fortran
  cobol tcl groovy d v
  bash powershell awk sed html
  css sql graphql solidity webassembly
)

mkdir -p "$GROUND"
mkdir -p "$GROUND/.logs"

print "Scaffolding ${#LANGS} language subdirs under $GROUND"

local lang dir envrc
for lang in "${LANGS[@]}"; do
  dir="$GROUND/$lang"
  envrc="$dir/.envrc"
  mkdir -p "$dir"
  cat > "$envrc" <<EOF
# Minimal probe .envrc for hang investigation.
# Only static exports - zero subshell / network work, so any measured direnv
# cost is the direnv binary itself, not .envrc-specific.
export HANG_PROBE_LANG=$lang
export HANG_PROBE_DIR="\$PWD"
EOF
done

# The "heavy" envrc exercises a subshell + an external command invocation,
# giving us an amplified contrast against the minimal case. Still no network.
mkdir -p "$GROUND/heavy"
cat > "$GROUND/heavy/.envrc" <<'EOF'
# Heavy probe .envrc: one subshell, one external command (date), one PATH_add.
# Represents a more-realistic but still cheap .envrc shape (e.g. activating a
# venv, exporting a tool version). Amplified comparator for scenario #6 in the
# evidence matrix.
export HANG_PROBE_LANG=heavy
export HANG_PROBE_DIR="$PWD"
export HANG_PROBE_TS="$(date +%s)"
PATH_add "$PWD/bin"
EOF
mkdir -p "$GROUND/heavy/bin"

# direnv allow everything so subsequent shell spawns don't get blocked-allow
# warnings (which would skew timing).
print "Running 'direnv allow' on all .envrc files"
local envrc_file
for envrc_file in "$GROUND"/*/.envrc; do
  (cd "${envrc_file:h}" && direnv allow >/dev/null 2>&1) || {
    print -u2 "WARN: direnv allow failed for $envrc_file"
  }
done

print "Done. Subdirs: $(ls -1 "$GROUND" | grep -v '^\.' | wc -l | tr -d ' ')"
print "Sample contents of testing_grounds/python/.envrc:"
cat "$GROUND/python/.envrc" | sed 's/^/  /'
