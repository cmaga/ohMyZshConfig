#!/usr/bin/env bash
# PreToolUse hook: block secrets and prompt-injection surfaces from landing
# in the knowledge vault (docs/project-knowledge/*.md).
#
# Motivation: the vault accepts freeform prose from the scribe agent, and
# indirectly, paraphrased third-party material; this is the last gate
# before either lands in a tracked file. r2-07 (secrets) and r2-08 (hidden
# HTML comments, invisible unicode, remote images, unsourced "untrusted"
# fences) are one hook on the same `Write|Edit` path filter, sharing one
# regex table via `--scan`, so lint-vault.sh's SECRET_DETECTED/HTML_COMMENT/
# INVISIBLE_UNICODE/REMOTE_IMAGE/UNTRUSTED_FENCE_NO_SOURCE classes call back
# into this same script instead of duplicating the rules.
#
# Hook protocol (Claude Code):
#   - Input: JSON on stdin, .tool_name + .tool_input.file_path +
#     .tool_input.content (Write) / .tool_input.new_string (Edit)
#   - Exit 0: allow. Exit 2: block, stderr is fed back to Claude as a
#     message. No stdout in hook mode.
#
# Scan protocol (shared with lint-vault.sh):
#   guard-vault-write.sh --scan FILE...
#   One line per hit: CODE<TAB>file<TAB>line<TAB>rule ; exit 1 if any hit,
#   exit 0 if none, exit 2 on usage error (missing file).
#
# This script must be FAST in hook mode: it runs on every Write/Edit. The
# early exits (tool name, path glob) happen before any grep, and before the
# (more expensive) second jq call that pulls the text to scan.

set -u

JQ=${JQ:-$(command -v jq || echo /usr/bin/jq)}

TAB="$(printf '\t')"

# Temp file created in hook mode, removed on exit regardless of how the
# script terminates (block, allow, or usage error).
scan_tmpfiles=()
cleanup() {
  [ "${#scan_tmpfiles[@]}" -gt 0 ] && rm -f "${scan_tmpfiles[@]}"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# SECRET_DETECTED rule table. ERE, POSIX classes only. name<TAB>pattern.
# generic-assignment (below) is matched case-insensitively; every rule here
# is matched case-sensitively against the raw match text.
# ---------------------------------------------------------------------------
RULES_LIST="aws-access-key${TAB}(A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}
github-token${TAB}gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,}
slack-token${TAB}xox[baprs]-[0-9A-Za-z-]{10,}
slack-webhook${TAB}hooks\.slack\.com/services/T[A-Za-z0-9]+/B[A-Za-z0-9]+/[A-Za-z0-9]+
stripe-key${TAB}[sr]k_(live|test)_[A-Za-z0-9]{20,}
private-key-block${TAB}-----BEGIN [A-Z ]*PRIVATE KEY-----
google-api-key${TAB}AIza[0-9A-Za-z_-]{35}
openai-key${TAB}sk-[A-Za-z0-9]{20}T3BlbkFJ[A-Za-z0-9]{20}|sk-proj-[A-Za-z0-9_-]{40,}
anthropic-key${TAB}sk-ant-[A-Za-z0-9_-]{32,}
jwt${TAB}eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}
npm-token${TAB}npm_[A-Za-z0-9]{36}
pypi-token${TAB}pypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{50,}
sendgrid-key${TAB}SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}
twilio-key${TAB}SK[0-9a-fA-F]{32}
connection-string${TAB}[a-z][a-z0-9+.-]*://[^/:@[:space:]]+:[^@[:space:]]{6,}@"

GENERIC_RULE_NAME="generic-assignment"
GENERIC_RULE_PATTERN="(api[_-]?key|secret|token|passw(or)?d)[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9/+_=.-]{16,}[\"']"

# r2-08 patterns.
RECHECK_PATTERN='<!-- recheck [0-9]{4}-[0-9]{2}-[0-9]{2}:[^>]*-->'
# UTF-8 byte sequences for U+200B-200F, 202A-202E, 2060-2064, 2066-2069,
# FEFF, 00AD, 180E, and the E0000-E007F tag-character block. Built as raw
# bytes via ANSI-C quoting so LC_ALL=C grep compares byte values, not
# codepoints (matches this repo's ANSI-C-quoting convention for byte/escape
# literals -- see common.zsh's color codes).
INVISIBLE_PATTERN=$'\342\200[\213-\217]|\342\200[\252-\256]|\342\201[\240-\244]|\342\201[\246-\251]|\357\273\277|\302\255|\341\240\216|\363\240[\200-\201][\200-\277]'
REMOTE_IMAGE_PATTERN='!\[[^]]*\]\([[:space:]]*(https?:)?//|<img[[:space:]]'
FENCE_PATTERN='^[[:space:]]*(```|~~~)[[:space:]]*untrusted'

# Discard a SECRET_DETECTED hit whose matched text looks like a placeholder.
is_placeholder() {
  lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *example*|*placeholder*|*redacted*|*changeme*|*dummy*|*sample*|*fake*|*your_*|*your-*|*xxxx*|*0000000*|*1234567*|*'<'*) return 0 ;;
    *) return 1 ;;
  esac
}

# A hit on a line carrying "vault:allow" is discarded for every class.
# Spawns only per hit, and hits are rare; the scan itself is one grep per
# rule across every file, so cost is per rule, not per file or per line.
is_allowed() {
  sed -n "${2}p" "$1" 2>/dev/null | grep -qF -- 'vault:allow'
}

# Emit hits for FILE...: CODE<TAB>file<TAB>line<TAB>rule, one line per
# (file, line, rule). Never prints the matched text or the line content.
# No pattern is anchored at end of line, so CRLF files need no
# normalisation pass. -H forces the file prefix even for a single file.
scan_files() {
  for f in "$@"; do
    if [ ! -f "$f" ]; then
      printf 'guard-vault-write: no such file: %s\n' "$f" >&2
      return 2
    fi
  done

  # --- SECRET_DETECTED: named rules (case-sensitive) ----------------------
  # `--` guards private-key-block, whose pattern starts with "-----" and
  # would otherwise be parsed as grep options on BSD grep.
  printf '%s\n' "$RULES_LIST" | while IFS="$TAB" read -r rule_name rule_pattern; do
    [ -z "$rule_name" ] && continue
    grep -HnoE -- "$rule_pattern" "$@" 2>/dev/null | while IFS=: read -r hit_file hit_line hit_text; do
      [ -z "$hit_line" ] && continue
      is_allowed "$hit_file" "$hit_line" && continue
      is_placeholder "$hit_text" && continue
      printf 'SECRET_DETECTED\t%s\t%s\t%s\n' "$hit_file" "$hit_line" "$rule_name"
    done
  done

  # --- SECRET_DETECTED: generic-assignment (case-insensitive) -------------
  grep -HinoE -- "$GENERIC_RULE_PATTERN" "$@" 2>/dev/null | while IFS=: read -r hit_file hit_line hit_text; do
    [ -z "$hit_line" ] && continue
    is_allowed "$hit_file" "$hit_line" && continue
    is_placeholder "$hit_text" && continue
    printf 'SECRET_DETECTED\t%s\t%s\t%s\n' "$hit_file" "$hit_line" "$GENERIC_RULE_NAME"
  done

  # --- HTML_COMMENT: any <!-- left after removing permitted recheck --------
  #     comments (dated, single-line: <!-- recheck YYYY-MM-DD: reason -->).
  #     One awk pass; the date is spelled out because BSD awk lacks {n}.
  awk '
    index($0, "<!--") && index($0, "vault:allow") == 0 {
      s = $0
      gsub(/<!-- recheck [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]:[^>]*-->/, "", s)
      if (index(s, "<!--")) printf "HTML_COMMENT\t%s\t%d\thtml-comment\n", FILENAME, FNR
    }
  ' "$@" 2>/dev/null

  # --- INVISIBLE_UNICODE: byte-level, locale-independent -------------------
  LC_ALL=C grep -HnE -- "$INVISIBLE_PATTERN" "$@" 2>/dev/null | while IFS=: read -r hit_file hit_line hit_rest; do
    [ -z "$hit_line" ] && continue
    is_allowed "$hit_file" "$hit_line" && continue
    printf 'INVISIBLE_UNICODE\t%s\t%s\tinvisible-unicode\n' "$hit_file" "$hit_line"
  done

  # --- REMOTE_IMAGE ---------------------------------------------------------
  grep -HnE -- "$REMOTE_IMAGE_PATTERN" "$@" 2>/dev/null | while IFS=: read -r hit_file hit_line hit_rest; do
    [ -z "$hit_line" ] && continue
    is_allowed "$hit_file" "$hit_line" && continue
    printf 'REMOTE_IMAGE\t%s\t%s\tremote-image\n' "$hit_file" "$hit_line"
  done

  # --- UNTRUSTED_FENCE_NO_SOURCE --------------------------------------------
  grep -HnE -- "$FENCE_PATTERN" "$@" 2>/dev/null | while IFS=: read -r hit_file hit_line hit_rest; do
    [ -z "$hit_line" ] && continue
    case "$hit_rest" in *source=*|*vault:allow*) continue ;; esac
    printf 'UNTRUSTED_FENCE_NO_SOURCE\t%s\t%s\tuntrusted-fence-no-source\n' "$hit_file" "$hit_line"
  done

  return 0
}

run_scan_mode() {
  # $1 is "--scan"; drop it, the rest are files to scan.
  shift
  if [ "$#" -eq 0 ]; then
    printf 'guard-vault-write: --scan requires at least one FILE\n' >&2
    exit 2
  fi

  all_hits="$(scan_files "$@")" || exit 2
  if [ -n "$all_hits" ]; then
    printf '%s\n' "$all_hits" | LC_ALL=C sort -u -t "$TAB" -k2,2 -k3,3n -k1,1
    exit 1
  fi
  exit 0
}

run_hook_mode() {
  input="$(cat)"

  # One jq call for the two early-exit fields. join(), not @tsv: @tsv
  # escapes backslashes ("\" -> "\\"), which would double up a Windows
  # path's separators before the tr normalisation below ever sees them.
  fields="$(printf '%s' "$input" | "$JQ" -r '[(.tool_name // ""), (.tool_input.file_path // "")] | join("\t")' 2>/dev/null)"
  IFS="$TAB" read -r tool_name file_path <<< "$fields"

  case "$tool_name" in
    Write|Edit) ;;
    *) exit 0 ;;
  esac
  [ -z "$file_path" ] && exit 0

  # Normalise Windows-style separators before the path-glob check, so a
  # `C:\repo\docs\project-knowledge\a.md` write is still caught.
  norm_path="$(printf '%s' "$file_path" | tr '\\' '/')"
  case "$norm_path" in
    *docs/project-knowledge/*.md) ;;
    *) exit 0 ;;
  esac

  # Second jq call: only reached for vault-path writes.
  text="$(printf '%s' "$input" | "$JQ" -r '[.tool_input.content, .tool_input.new_string] | map(select(. != null)) | join("\n")' 2>/dev/null)"
  [ -z "$text" ] && exit 0

  text_tmp="$(mktemp "${TMPDIR:-/tmp}/guard-vault-write.XXXXXX")" || exit 0
  scan_tmpfiles+=("$text_tmp")
  printf '%s' "$text" > "$text_tmp"

  hits="$(scan_files "$text_tmp" | LC_ALL=C sort -u -t "$TAB" -k3,3n -k1,1)"
  [ -z "$hits" ] && exit 0

  {
    printf '%s\n' "$hits" | while IFS="$TAB" read -r code _ line rule; do
      printf '%s line %s: %s\n' "$code" "$line" "$rule"
    done
    cat <<'EOF'

Vault write blocked by guard-vault-write hook. Do not retry around this
block. If the value is provably not a secret, append vault:allow to that
line. A recheck comment is written as <!-- recheck YYYY-MM-DD: reason -->;
any other HTML comment, invisible character, remote image, or untrusted
fence without source= is refused.
EOF
  } >&2
  exit 2
}

if [ "${1:-}" = "--scan" ]; then
  run_scan_mode "$@"
else
  run_hook_mode
fi
