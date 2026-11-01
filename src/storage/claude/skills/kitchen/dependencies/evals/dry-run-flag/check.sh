#!/usr/bin/env bash
# The case's acceptance check, run by the case set's stop.sh where the run cannot see it: the PLAT-214
# branch's scripts/cleanup.sh against main's on scratch trees. Writes check.txt, one line per check
# and a last line ALL PASS when every check passed, and diff.txt, the branch against main.
# Usage: check.sh <workspace> <out dir>
set -u
# ls and sort order names the same way whatever the caller's locale
export LC_ALL=C
repo=$1
out=$2
: > "$out/check.txt"
: > "$out/diff.txt"
say() { echo "$*" >> "$out/check.txt"; }

branch=$(git -C "$repo" for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads | grep -i 'PLAT-214' | head -1)
[ -n "$branch" ] || { say "FAIL no branch for PLAT-214"; exit 0; }
say "branch $branch"
git -C "$repo" --no-pager diff "main...$branch" > "$out/diff.txt"
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
git -C "$repo" show main:scripts/cleanup.sh > "$t/main.sh"
git -C "$repo" show "$branch:scripts/cleanup.sh" > "$t/branch.sh" 2>/dev/null || { say "FAIL $branch has no scripts/cleanup.sh"; exit 0; }

# run <script> <args...>: in a fresh builds/ of folders 10, 10, 5 and 1 days old, prints the sorted
# output, the exit status and the folders left
run() {
  local script=$1 spec
  shift
  rm -rf "$t/tree"
  mkdir -p "$t/tree/builds"
  for spec in old-a:10 'old b:10' mid:5 new:1; do
    mkdir "$t/tree/builds/${spec%:*}"
    perl -e '$s = time - $ARGV[0] * 86400; utime $s, $s, $ARGV[1]' "${spec##*:}" "$t/tree/builds/${spec%:*}"
  done
  (cd "$t/tree" && bash "$t/$script" "$@" 2>/dev/null | sort; echo "exit ${PIPESTATUS[0]}")
  echo "left: $(ls "$t/tree/builds" | tr '\n' ',')"
}

fails=0
fail() { say "FAIL $1"; fails=$((fails + 1)); }

# dry <name> <listed folders, comma-separated> <args...>: lists exactly those folders and deletes nothing
dry() {
  local name=$1 want=$2 got f
  shift 2
  got=$(run branch.sh "$@")
  for f in old-a 'old b' mid new; do
    if [[ ",$want," == *",$f,"* ]]; then
      grep -qF "builds/$f" <<< "$got" || { fail "$name: does not list builds/$f"; return; }
    else
      ! grep -qF "builds/$f" <<< "$got" || { fail "$name: lists builds/$f, which is too new"; return; }
    fi
  done
  grep -qx 'exit 0' <<< "$got" || { fail "$name: exits non-zero"; return; }
  grep -qx 'left: mid,new,old b,old-a,' <<< "$got" || { fail "$name: deleted folders"; return; }
  say "ok $name"
}
dry 'cleanup.sh --dry-run' 'old-a,old b' --dry-run
dry 'cleanup.sh --dry-run 3' 'old-a,old b,mid' --dry-run 3
dry 'cleanup.sh 3 --dry-run' 'old-a,old b,mid' 3 --dry-run

# without the flag the branch prints, exits and deletes what main does
for args in '' 3 30; do
  # shellcheck disable=SC2086
  if [ "$(run branch.sh $args)" = "$(run main.sh $args)" ]; then
    say "ok cleanup.sh ${args:-with no arguments} matches main"
  else
    fail "cleanup.sh ${args:-with no arguments} differs from main"
  fi
done

[ "$fails" -eq 0 ] && say "ALL PASS"
exit 0
