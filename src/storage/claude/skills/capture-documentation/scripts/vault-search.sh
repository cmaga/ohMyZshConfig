#!/usr/bin/env bash
# vault-search.sh - rank vault sections by hit count against a pattern (read-only).
# Usage: vault-search.sh VAULT_ROOT "<ERE>" [N]
# Matches are case-insensitive: both the line and the pattern are lowercased before matching
# (tolower($0) ~ re, re = tolower(ERE)), so a character class with an uppercase range (e.g.
# [A-Z]) never matches anything.
# Sections: line 1 through the line before the first "## " heading is section 0 (frontmatter
# included, so an "aliases:" hit surfaces); it is named for its H1 text, or "(top)" if none.
# Each "## " heading starts a new section that runs to the line before the next "## " or EOF.
# Fenced code blocks are scanned like any other text.
# Output: path:start-end<TAB>hits<TAB>bytes<TAB>heading, one line per section with >=1 hit,
# sorted by hits desc, then path, then start asc; top N printed (default 12). A hit in a note
# carrying a "> Status:" line prints that line indented by four spaces beneath the result.
set -u
LC_ALL=C
export LC_ALL

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo 'usage: vault-search.sh VAULT_ROOT "<ERE>" [N]' >&2
  exit 2
fi

ROOT="$1"
PATTERN="$2"
N="${3:-12}"

case "$N" in
  ''|*[!0-9]*)
    echo 'usage: vault-search.sh VAULT_ROOT "<ERE>" [N]  (N must be a positive integer)' >&2
    exit 2
    ;;
esac

if [ ! -d "$ROOT" ]; then
  echo "usage: vault-search.sh VAULT_ROOT \"<ERE>\" [N]  ($ROOT is not a directory)" >&2
  exit 2
fi

# Two awk passes with a real sort between them: the WARN thresholds below only fire for
# sections/notes that survive the top-N cut, so ranking has to happen before formatting.
RESULTS="$(
  find "$ROOT" -name '*.md' -not -path '*/.obsidian/*' -not -path '*/.cache/*' -print0 |
    sort -z |
    xargs -0 awk -v patt="$PATTERN" '
      function emit(s, e, disp,   i, hits, bytes, ln) {
        hits = 0
        bytes = 0
        for (i = s; i <= e; i++) {
          ln = text[i]
          bytes += length(ln) + 1
          if (tolower(ln) ~ re) hits++
        }
        if (hits >= 1) {
          printf "%d\t%s\t%d\t%d\t%d\t%d\t%s\t%s\n", hits, f, s, e, bytes, nb, statusline, disp
        }
      }
      function process(   i, end0, h1, start, heading) {
        nb = 0
        for (i = 1; i <= n; i++) nb += length(text[i]) + 1

        statusline = ""
        for (i = 1; i <= n; i++) {
          if (text[i] ~ /^> Status:/) { statusline = text[i]; break }
        }

        end0 = n
        for (i = 1; i <= n; i++) {
          if (text[i] ~ /^## /) { end0 = i - 1; break }
        }

        h1 = ""
        for (i = 1; i <= end0; i++) {
          if (text[i] ~ /^# /) { h1 = substr(text[i], 3); break }
        }
        if (h1 == "") h1 = "(top)"

        if (end0 >= 1) emit(1, end0, h1)

        start = 0
        heading = ""
        for (i = end0 + 1; i <= n; i++) {
          if (text[i] ~ /^## /) {
            if (start > 0) emit(start, i - 1, "## " heading)
            start = i
            heading = substr(text[i], 4)
          }
        }
        if (start > 0) emit(start, n, "## " heading)
      }
      BEGIN { re = tolower(patt) }
      FNR == 1 {
        if (f != "") process()
        f = FILENAME
        n = 0
      }
      {
        ln = $0
        sub(/\r$/, "", ln)
        n++
        text[n] = ln
      }
      END {
        if (f != "") process()
      }
    ' |
    sort -t "$(printf '\t')" -k1,1nr -k2,2 -k3,3n |
    head -n "$N"
)"

if [ -z "$RESULTS" ]; then
  echo "no hits" >&2
  exit 1
fi

printf '%s\n' "$RESULTS" | awk -F'\t' '
  {
    hits = $1; path = $2; start = $3; end = $4; bytes = $5; nb = $6; statusline = $7; heading = $8
    printf "%s:%s-%s\t%s\t%s\t%s\n", path, start, end, hits, bytes, heading
    if (bytes + 0 > 30720) {
      printf "WARN %s:%s-%s section is %s bytes\n", path, start, end, bytes > "/dev/stderr"
    }
    if (nb + 0 > 102400 && !(path in seen)) {
      printf "WARN %s is %s bytes; read by line range\n", path, nb > "/dev/stderr"
      seen[path] = 1
    }
    if (statusline != "") printf "    %s\n", statusline
  }
'
