#!/usr/bin/env bash
# lint-vault-currency.sh - structural currency checks for the knowledge vault.
#
# Usage: lint-vault-currency.sh VAULT_ROOT [file ...]
#   VAULT_ROOT : the docs/project-knowledge dir (used to resolve [[wikilinks]]).
#   file ...   : specific notes to check; if omitted, audits VAULT_ROOT/decisions/*.md.
#
# Checks are STRUCTURAL only - no prose/NLP heuristics, so no false positives from
# innocent wording. FAIL = a real currency defect (blocks). WARN = hygiene (advisory).
# Exit 1 if any FAIL, else 0.
set -u

ROOT="${1:-}"
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "usage: lint-vault-currency.sh VAULT_ROOT [file ...]" >&2
  exit 2
fi
shift

if [ "$#" -gt 0 ]; then
  FILES="$*"
else
  FILES=$(find "$ROOT" -name '*.md' 2>/dev/null)
fi

# Known note basenames (without .md), for wikilink resolution.
KNOWN=$(find "$ROOT" -name '*.md' -exec basename {} .md \; 2>/dev/null)
SANCTIONED="active proposed revisit superseded deprecated amended open closed"
FAIL=0

note_exists() { printf '%s\n' "$KNOWN" | grep -qxF "$1"; }

for f in $FILES; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  status=$(head -n 15 "$f" | grep -m1 '^status:' | sed 's/^status:[[:space:]]*//; s/[[:space:]]*$//')
  type=$(head -n 15 "$f" | grep -m1 '^type:' | sed 's/^type:[[:space:]]*//; s/[[:space:]]*$//')

  # CHECK 1 (FAIL): a demoted DECISION must carry a "> Status:" banner near the top.
  # The banner convention is decision-scoped; constraints/research signal currency
  # via status + superseded_by (CHECK 2), not a top banner.
  if [ "$type" = "decision" ]; then
    case " superseded deprecated amended " in
      *" $status "*)
        if ! head -n 15 "$f" | grep -q '^> Status:'; then
          echo "FAIL $base: status '$status' but no '> Status:' banner in first 15 lines"
          FAIL=1
        fi
        ;;
    esac
  fi

  # CHECK 2 (FAIL): superseded_by must be a [[wikilink]] that resolves to a real note.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    target=$(printf '%s\n' "$line" | sed -n 's/.*\[\[\([^]|#]*\).*/\1/p')
    if [ -z "$target" ]; then
      echo "FAIL $base: superseded_by is not a [[wikilink]]: ${line#superseded_by:}"
      FAIL=1
    elif ! note_exists "$target"; then
      echo "FAIL $base: superseded_by target does not resolve: [[$target]]"
      FAIL=1
    fi
  done < <(grep '^superseded_by:' "$f")

  # CHECK 3 (WARN): status outside the sanctioned set (catches enum drift early).
  if [ -n "$status" ] && ! printf '%s\n' $SANCTIONED | grep -qxF "$status"; then
    echo "WARN $base: unsanctioned status '$status'"
  fi

  # CHECK 4 (WARN): orphan wikilinks, excluding ticket refs (STAX-/NOV-).
  grep -oE '\[\[[^]]+\]\]' "$f" | sed 's/\[\[//; s/\]\]//; s/|.*//; s/#.*//; s#.*/##' | while IFS= read -r t; do
    [ -z "$t" ] && continue
    printf '%s\n' "$t" | grep -qE '^(STAX|NOV)-[0-9]+$' && continue
    # bare [[ADR-NNN]] short-form resolves to the full-slug ADR-NNN-... file
    case "$t" in
      ADR-[0-9]*) printf '%s\n' "$KNOWN" | grep -qE "^${t}(-|\$)" && continue ;;
    esac
    note_exists "$t" || echo "WARN $base: unresolved wikilink [[$t]]"
  done
done

exit $FAIL
