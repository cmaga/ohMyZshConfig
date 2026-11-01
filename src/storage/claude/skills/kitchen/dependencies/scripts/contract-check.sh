#!/usr/bin/env bash
# Checks the contract on the current branch: the tests a contract commit locked before the code.
#
#   contract-check.sh <base> [--run]
#
# A contract commit carries a Contract-Files trailer. Every commit since <base> that touches a
# contract file must itself be a contract commit, and no contract file may carry uncommitted edits.
# With --run, it also runs each Contract-Run command of the latest contract commit and confirms that
# each of its Contract-Test names printed a pass.
#
# Exit: 0 held, 1 broken, 2 no contract commit since <base>, 3 usage.

set -u

base=${1:-}
run=0
[ "${2:-}" = "--run" ] && run=1
if [ -z "$base" ] || ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "usage: contract-check.sh <base> [--run], where <base> names a commit" >&2
  exit 3
fi
top=$(git rev-parse --show-toplevel) || exit 3
cd "$top" || exit 3

US=$'\037'
RS=$'\036'
history=$(git log --reverse --format='%H%x1f%h%x1f%s%x1f%(trailers:key=Contract-Files,valueonly,separator=%x20)%x1f%(trailers:key=Contract-Run,valueonly,separator=%x1e)%x1f%(trailers:key=Contract-Test,valueonly,separator=%x1e)' "$base..HEAD")

contracts=$(printf '%s\n' "$history" | awk -F"$US" '$4 != ""')
if [ -z "$contracts" ]; then
  echo "no contract commit since $base"
  exit 2
fi

files=()
while IFS= read -r f; do
  [ -n "$f" ] && files+=("$f")
done < <(printf '%s\n' "$contracts" | awk -F"$US" '{ n = split($4, a, " "); for (i = 1; i <= n; i++) if (!(a[i] in seen)) { seen[a[i]] = 1; print a[i] } }')

latest=$(printf '%s\n' "$contracts" | tail -n 1)
echo "contract files: ${#files[@]}; contract commits: $(printf '%s\n' "$contracts" | wc -l | tr -d ' '); latest: $(printf '%s' "$latest" | cut -d"$US" -f2,3 | tr "$US" ' ')"
printf '%s\n' "$history" | awk -F"$US" '$4 != "" && code { print "revised after code: " $2 " " $3 } $4 != "" { locked = 1 } $4 == "" && locked { code = 1 }'

broken=0

shas=$(printf '%s\n' "$contracts" | cut -d"$US" -f1)
outside=$(git log --cc --name-only --format='%x1d%H%x1f%h %s' "$base..HEAD" -- "${files[@]}" | SHAS=$shas awk -F"$US" '
  BEGIN { n = split(ENVIRON["SHAS"], s, "\n"); for (i = 1; i <= n; i++) contract[s[i]] = 1 }
  substr($1, 1, 1) == "\035" { sha = substr($1, 2); what = $2; next }
  NF && !(sha in contract) { print "changed outside a contract commit: " what ": " $0 }')
if [ -n "$outside" ]; then
  printf '%s\n' "$outside"
  broken=1
fi

dirty=$(git status --porcelain -- "${files[@]}")
if [ -n "$dirty" ]; then
  printf '%s\n' "$dirty" | sed 's/^/uncommitted edit to a contract file: /'
  broken=1
fi

if [ "$run" = 1 ]; then
  runs=$(printf '%s' "$latest" | cut -d"$US" -f5)
  tests=$(printf '%s' "$latest" | cut -d"$US" -f6)
  if [ -z "$runs" ]; then
    echo "no Contract-Run on the latest contract commit: the lock was checked, no test was run"
  else
    tmp=${TMPDIR:-/tmp}
    out=$(mktemp "${tmp%/}/contract-run.XXXXXX")
    i=0
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      i=$((i + 1))
      bash -c "$cmd" </dev/null >>"$out" 2>&1
      code=$?
      if [ "$code" != 0 ]; then
        echo "run $i exited $code"
        broken=1
      fi
    done < <(printf '%s\n' "$runs" | tr "$RS" '\n')
    echo "run output: $out"

    esc=$(printf '\033')
    names=$(printf '%s\n' "$tests" | tr "$RS" '\n')
    verdicts=$(LC_ALL=C sed "s/${esc}\[[0-9;]*[A-Za-z]//g" "$out" | NAMES=$names awk '
      BEGIN { k = split(ENVIRON["NAMES"], n, "\n") }
      {
        b = 0
        for (i = 1; i <= k; i++) {
          if (n[i] == "" || !(p = index($0, n[i]))) continue
          if ((p > 1 && substr($0, p - 1, 1) ~ /[A-Za-z0-9_]/) || substr($0, p + length(n[i]), 2) ~ /^([A-Za-z0-9_]| [a-z])/) continue
          if (!b || length(n[i]) > length(n[b])) { b = i; bp = p }
        }
        if (!b) next
        found[b] = 1
        rest = substr($0, 1, bp - 1) substr($0, bp + length(n[b]))
        if (rest ~ /SKIP|[Ss]kipped|TODO|[Tt]odo|XFAIL|[Xx]fail|[Pp]ending|IGNORED|[Ii]gnored/ || index(rest, "↓")) seen[b] = seen[b] "s"
        else if (rest ~ /FAIL|[Ff]ailed|ERROR|[Ee]rror|(^|[^A-Za-z])not ok([^A-Za-z]|$)/ || index(rest, "✗") || index(rest, "✕") || index(rest, "×")) seen[b] = seen[b] "f"
        else if (rest ~ /PASS|[Pp]assed|(^|[^A-Za-z])ok([^A-Za-z]|$)/ || index(rest, "✓") || index(rest, "✔") || index(rest, "√")) seen[b] = seen[b] "p"
      }
      END {
        for (i = 1; i <= k; i++) {
          if (n[i] == "") continue
          if (!found[i]) print "not in the run output: " n[i]
          else if (seen[i] ~ /f/) print "failed: " n[i]
          else if (seen[i] ~ /s/) print "skipped: " n[i]
          else if (seen[i] !~ /p/) print "no pass printed for: " n[i]
        }
      }')
    if [ -n "$verdicts" ]; then
      printf '%s\n' "$verdicts"
      broken=1
    fi
  fi
fi

[ "$broken" = 0 ] && echo "held"
exit "$broken"
