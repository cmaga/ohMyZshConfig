#!/usr/bin/env zsh
# The kitchen skill's deterministic half: the order book, the user's queue, and
# the scheduler pass that keeps work moving. Sessions read and write order state
# only through this script, so the format lives in one place.
#
# State lives in ~/.claude-artifacts/workflows/kitchen/<slug>/ (user lifecycle):
#   line.json          project path, ready JQL, capacity, models
#   orders/<KEY>.json  one order per ticket
#   catches.tsv        date key taster class note source
#   promoted.tsv       class ticket date
#   log/               one log per session the scheduler starts
#   notices.tsv        date text: vault and teardown events for the catch-up
#
# Usage: a KEY may be an epic's key, for the order building it; a value written
# @/absolute/path is read from that file.
#   kitchen [status]                         what happened since the user last looked, then what waits on them
#   kitchen review KEY|NUMBER [--line]       open the order's build session in this terminal to review its PR; --line prints the command instead
#   kitchen signoff KEY ANSWER...            the user's answer at the pass; the work becomes an order on the next pass
#   kitchen order get KEY                    print the order
#   kitchen order new KEY [field=value...]   create an order in the current project
#   kitchen order set KEY field=value...     update fields
#   kitchen order claim KEY                  mark the order as worked by this session; refused while another holds it
#   kitchen order withdraw KEY QUESTION      a decided premise proved impossible: back to the pass with the question
#   kitchen order base KEY|-                 the branch the order's work starts from and merges into; - for this repo's
#   kitchen order hold KEY REASON            intake tries the ticket again after followup_hours, as for an open blocker
#   kitchen order pr KEY URL                 record the PR and hand it to the scheduler
#   kitchen order verify KEY                 hand the PR to the scheduler for a verdict from a session that did not write it
#   kitchen order verdict KEY WORD NOTES     record PASS, PASS+NOTES, or FAIL for the change checked out here
#   kitchen order gated KEY                  record the change the quality gate passed; run in the order's worktree
#   kitchen order approve KEY COMMIT         record the change the user approved; it holds while the change stays the same
#   kitchen order close KEY                  mark the order done and move its ticket with transitions.merged
#   kitchen order list [STATUS]              every order, or those with that status
#   kitchen order transcript KEY             path of the order's last session transcript
#   kitchen decide KEY "decision: why" EVIDENCE      log a call made without the user, with what backs it
#   kitchen catch KEY|- TASTER CLASS NOTE [--chef]   log a review finding; prints promote, or climb TICKET, when due
#   kitchen classes [TASTER]                 catch classes this project has seen
#   kitchen promoted CLASS TICKET            record a promotion
#   kitchen sample KEY                       what the PR needs before it merges: rebase, regate, fix, verify, review, or no
#   kitchen line add PATH JQL | list | set SLUG field=value... | pause SLUG | resume SLUG | rm SLUG
#   kitchen prune [--dry-run]                remove the worktrees of closed orders
#   kitchen tick [--dry-run]                 one scheduler pass over every project

set -uo pipefail
setopt extendedglob
zmodload zsh/datetime
zmodload -F zsh/stat b:zstat

BOOK="${KITCHEN_BOOK:-$HOME/.claude-artifacts/workflows/kitchen}"
ALIASES="${KITCHEN_ALIASES:-${ZSH:-$HOME/.oh-my-zsh}/custom/aliases.zsh}"
VAULT_GIT="$HOME/.claude/skills/capture-documentation/scripts/vault-git.sh"
MAX_RETRIES=3
LIMIT_WAIT=1800
KILL_AFTER=300
PROBATION=5
DEFAULT_MINUTES='{"serve":45,"cook":360,"follow":120,"verify":90}'
# A session with no side effect this long is stuck: no order update, no commit or reset in its worktree.
DEFAULT_STALL='{"cook":60,"follow":45,"verify":45}'
# A change to these paths loosens or moves a check, so the user reviews it.
CHECK_PATHS='(^|/)(\.github/workflows/|\.gitlab-ci\.yml$|bitbucket-pipelines\.yml$|\.circleci/|\.pre-commit-config\.yaml$|\.husky/|\.eslintrc|eslint\.config\.|tsconfig[^/]*\.json$|\.prettierrc|biome\.jsonc?$|\.?ruff\.toml$|mypy\.ini$|\.golangci|pyproject\.toml$|setup\.cfg$|\.flake8$|tox\.ini$|pytest\.ini$|(jest|vitest)\.config\.|\.claude/kitchen/house\.md$|\.claude/skills/verify[-/])'
# A mistake under these paths is costly: a lower-case word at a word start, or Capitalized inside camelCase, never inside a longer word (author).
RISK_WORDS='auth|authn|authz|authentication|authorization|oauth|billing|payments?|migrations?|migrate|secrets?|security|crypto|permissions?'
RISK_PATHS="(^|[^A-Za-z])($RISK_WORDS)([^a-z]|\$)|(${(C)RISK_WORDS}|OAuth)([^a-z]|\$)|(^|/)alembic/versions/"
# An added line matching this skips or silences a check.
SKIP_LINES='(eslint-disable|@ts-ignore|@ts-expect-error|@ts-nocheck|#[[:space:]]*type:[[:space:]]*ignore|#[[:space:]]*noqa|nolint|pragma: no cover|\.skip\(|(^|[^[:alnum:]_])x(it|describe)\(|@pytest\.mark\.(skip|xfail)|@Disabled|@Ignore|t\.Skip\()'

# Fields stored as JSON; every other field is a string.
typeset -A JSON_FIELDS=(after 1 signoff 1 review 1 sample 1 retries 1 retry_after 1 pid 1 followed 1 station 1 done_when 1 steps 1 decisions 1 started 1 handled 1 handed 1 verify 1 verify_fails 1 verified_at 1 touched 1 stop_at 1 left 1)

die() { print -u2 -- "kitchen: $*"; exit 1; }
now_iso() { strftime '%Y-%m-%dT%H:%M:%S' $EPOCHSECONDS; }
today() { strftime '%Y-%m-%d' $EPOCHSECONDS; }
log() { print -- "[$(now_iso)] $*"; }

# --- order book -------------------------------------------------------------

text_of() { # VALUE: sets REPLY to the value, or to the contents of the file an @/absolute/path names
  REPLY=$1
  [[ $1 == @/* && -f ${1#@} ]] && REPLY=$(<${1#@})
  return 0
}

order_file() { # KEY: path of its order, or of the order building that epic; empty when there is none
  local -a f=( $BOOK/*/orders/$1.json(N) ) all
  if (( ! $#f )); then
    all=( $BOOK/*/orders/*.json(N) )
    (( $#all )) && f=( ${(f)"$(jq -r --arg k $1 'select(.epic == $k) | input_filename' $all)"} )
  fi
  (( $#f )) && print -- $f[1]
}

need_order() { # KEY: path of its order, or die
  local f=$(order_file $1)
  [[ -n $f ]] || die "no order $1"
  print -- $f
}

orders_json() { # SLUG: every order in the line as one JSON array
  local -a f=( $BOOK/$1/orders/*.json(N) )
  if (( $#f )); then jq -s . $f; else print '[]'; fi
}

jq_write() { # FILE FILTER [jq args...]: rewrite a JSON file atomically
  local file=$1 filter=$2; shift 2
  local tmp="$file.tmp.$$"
  if jq "$@" "$filter" $file > $tmp; then mv $tmp $file; else rm -f $tmp; die "could not update $file"; fi
}

slug_here() { # the line whose project holds the current directory
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || die "not in a git checkout"
  local root=${common:h} f
  for f in $BOOK/*/line.json(N); do
    [[ $(jq -r .project $f) == $root ]] && { print -- ${f:h:t}; return; }
  done
  # project rules in git mean /kitchen open ran on another machine; the scheduler stays there
  git -C $root ls-files --error-unmatch .claude/kitchen/house.md >/dev/null 2>&1 || die "no line for $root; run /kitchen open there"
  local slug; slug=$(line_write $root '' true) || exit 1
  print -u2 -- "kitchen: registered $root as $slug on this machine, paused, from its committed project rules"
  print -- $slug
}

base_of() { # PROJECT: its base branch
  local b=$(jq -r '.baseBranch // empty' $1/.claude/skills/jira/config.json 2>/dev/null)
  print -- ${b:-main}
}

order_base() { # ORDER-FILE: the order's own base (a catering milestone's spec branch), else its project's
  local b=$(jq -r '.base // empty' $1)
  [[ -n $b ]] && print -- $b || base_of $(jq -r .project ${1:h:h}/line.json)
}

order_set() { # KEY field=value...
  local f; f=$(need_order $1) || exit 1
  shift
  local -a args=()
  local filter='.updated = $t | .touched = $e' kv field i=0
  for kv in "$@"; do
    [[ $kv == *=* ]] || die "expected field=value, got: $kv"
    field=${kv%%=*}
    text_of "${kv#*=}"
    if (( ${+JSON_FIELDS[$field]} )); then args+=(--argjson v$i "$REPLY"); else args+=(--arg v$i "$REPLY"); fi
    args+=(--arg k$i $field)
    filter+=" | .[\$k$i] = \$v$i"
    i=$(( i + 1 ))
  done
  jq_write $f "$filter" --arg t "$(now_iso)" --argjson e $EPOCHSECONDS "${args[@]}"
}

order_new() { # SLUG KEY [field=value...]
  local slug=$1 key=$2; shift 2
  [[ -f $BOOK/$slug/line.json ]] || die "no line $slug"
  [[ -z $(order_file $key) ]] || die "order $key already exists"
  mkdir -p $BOOK/$slug/orders
  jq -n --arg k $key --arg t "$(now_iso)" \
    '{key:$k, status:"new", recipe:null, signoff:false, review:false, sample:false,
      retries:0, retry_after:0, pid:0, phase:null, station:[], done_when:[], decisions:[], created:$t, updated:$t}' \
    > $BOOK/$slug/orders/$key.json
  (( $# )) && order_set $key "$@"
  return 0
}

decide() { # KEY DECISION EVIDENCE: a call made without the user, with what backs it
  local f; f=$(need_order $1) || exit 1
  local d e
  text_of "${2:?decision}"; d=$REPLY
  text_of "${3:?evidence}"; e=$REPLY
  jq_write $f '.decisions = ((.decisions // []) + [{at: $t, what: $d, evidence: $e}]) | .updated = $t' \
    --arg t "$(now_iso)" --arg d "$d" --arg e "$e"
}

proc_table() { # one ps snapshot into PROC_PARENT, PROC_NAME and PROC_ARGS by pid; all empty where ps cannot list processes
  typeset -gA PROC_PARENT=() PROC_NAME=() PROC_ARGS=()
  local l; local -a w
  for l in ${(f)"$(ps -A -o pid=,ppid=,args= 2>/dev/null)"}; do
    w=( ${=l} )
    (( $#w >= 3 )) && PROC_PARENT[$w[1]]=$w[2] PROC_NAME[$w[1]]=${w[3]:t} PROC_ARGS[$w[1]]="${w[3,-1]}"
  done
  return 0
}

claim() { # KEY: mark the order as worked by the Claude session this runs in
  local f; f=$(need_order $1) || exit 1
  local st=$(jq -r .status $f) pid=$(jq -r .pid $f) p=$PPID own=0
  local -a chain=()
  proc_table
  while (( p > 1 )) && [[ -n ${PROC_PARENT[$p]:-} ]]; do chain+=($p); p=$PROC_PARENT[$p]; done
  # a fired session holds the order while its claude lives, as reap judges it
  local sid=$(jq -r '.session // ""' $f)
  if (( pid > 0 )) && ! kill -0 $pid 2>/dev/null && [[ $(jq -r .phase $f) != session && -n $sid ]]; then
    pid=${${(k)PROC_ARGS[(R)*--(session-id|resume) $sid*]}[1]:-0}
  fi
  if (( pid > 0 )) && kill -0 $pid 2>/dev/null; then
    if (( ${chain[(Ie)$pid]} )); then
      [[ $(jq -r .phase $f) != session || $st == cooking ]] && { print -- ok; return 0; }
    else
      die "$1 is being worked by another session (pid $pid)"
    fi
  fi
  # a new order is claimed only by a session the user started, which runs intake itself
  case $st in
    new|ready|at-the-pass|cooking|pr-open) ;;
    86) die "$1 was dropped: $(jq -r '.reason // "no reason recorded"' $f). kitchen.zsh signoff $1 @<file> brings it back" ;;
    serving) die "$1 is in intake; it can be worked once intake finishes" ;;
    *) die "$1 is $st" ;;
  esac
  for p in $chain; do [[ $PROC_NAME[$p] == claude ]] && { own=$p; break; }; done
  if (( ! own )); then
    (( $#PROC_PARENT )) && die "cannot find this session's claude process; run /kitchen cook from a Claude Code session"
    print -u2 -- "kitchen: cannot list processes here; the scheduler will not see this session end"
  fi
  # the first session to work an order is the one kitchen review opens later
  local -a mine=()
  [[ -z $(jq -r '.builder // ""' $f) && -n ${CLAUDE_CODE_SESSION_ID:-} ]] && mine=(builder=$CLAUDE_CODE_SESSION_ID)
  order_set $1 status=cooking phase=session pid=$own started=$EPOCHSECONDS "claimed_from=$st" $mine
  print -- ok
}

close_order() { # KEY: mark the order done and move its ticket (catering's epic) with transitions.merged
  local f; f=$(need_order $1) || exit 1
  local project=$(jq -r .project ${f:h:h}/line.json) ticket=$(jq -r '.epic // .key' $f)
  local merged=$(jq -r '.transitions.merged // empty' $project/.claude/skills/jira/config.json 2>/dev/null)
  local pr=$(jq -r '.pr // empty' $f)
  if [[ -n $merged ]] && ! ( cd $project && jira issue move $ticket "$merged" --comment "Merged: ${pr:-investigation answered}" < /dev/null >/dev/null 2>&1 ); then
    notice ${f:h:h} "could not move $ticket to $merged"
  fi
  # a delivered catering order's spec branch has nothing left that the base lacks
  [[ $(jq -r .recipe $f) == catering && -n $(git -C $project ls-remote --heads origin spec/$ticket 2>/dev/null) ]] &&
    git -C $project push -q origin --delete spec/$ticket >/dev/null 2>&1
  order_set $1 status=done
}

order_list() { # [STATUS]: every order in every line, or those with that status
  local line
  for line in $BOOK/*/line.json(N); do
    orders_json ${line:h:t} | jq -r --arg s ${line:h:t} --arg st "${1:-}" \
      '.[] | select($st == "" or .status == $st) | "\($s)\t\(.key)\t\(.status)\t\(.reason // .summary // "")"'
  done
}

transcript() { # KEY: path of the order's last session transcript
  local f; f=$(need_order $1) || exit 1
  local sid=$(jq -r '(.last_session | select(. != "")) // .session // empty' $f)
  [[ -n $sid && $sid != - ]] || die "$1 has no recorded session"
  local -a t=( $HOME/.claude*/projects/*/$sid.jsonl(N) )
  (( $#t )) || die "no transcript for session $sid"
  print -- $t[1]
}

# --- the user's queue ---------------------------------------------------------

status() { # what happened since the user last looked, then what waits on them
  ( slug_here ) >/dev/null 2>&1
  local since=$(cat $BOOK/.last-look 2>/dev/null || print '0000') line slug dir book
  for line in $BOOK/*/line.json(N); do
    slug=${line:h:t} dir=${line:h}
    print -- "$slug$([[ $(jq -r '.paused // false' $line) == true ]] && print ' (paused)')"
    book=$(orders_json $slug)
    jq -r --arg s "$since" '
      ( map(select(.updated >= $s)) as $new
        | ( $new | map(select(.status == "done" and .pr)) | .[] | "  merged    \(.key)  \(.summary // "")" ),
          ( $new | map(select(.status == "86")) | .[] | "  dropped   \(.key)  \(.reason // "")" ) ),
      ( .[] | .key as $k | (.decisions // [])[] | select(.at >= $s)
        | "  decided   \($k)  \(.what)\(if .evidence then "  (\(.evidence))" else "" end)" )' <<< $book
    [[ -f $dir/promoted.tsv ]] && awk -F'\t' -v s="${since[1,10]}" '$3 >= s {print "  promoted  " $1 " -> " $2}' $dir/promoted.tsv
    [[ -f $dir/notices.tsv ]] && awk -F'\t' -v s="$since" '$1 >= s {print "  notice    " $2}' $dir/notices.tsv
    jq -r --arg d "$(today)" '
      ( map(select(.status == "at-the-pass")) | sort_by(.updated)[]
        | "  AT PASS   \(.key)\(if .recipe == "catering" then "  [catering]" else "" end)  \(.question // .summary // "")" ),
      ( (map(select(.status == "86")) | map(.key)) as $gone | map(select(.status == "ready"))[]
        | ((.after // []) - ((.after // []) - $gone)) as $by | select($by | length > 0)
        | "  BLOCKED   \(.key)  waits on dropped \($by | join(", "))" ),
      ( map(select(.status == "pr-open" and .review)) | sort_by(.updated)[]
        | "  REVIEW    \(.key)\(if .recipe == "catering" then "  [catering]" else "" end)  \(.pr)\(if .review_why then "  (\(.review_why))" else "" end)\(if .builder then "  kitchen review \(.key)" else "" end)" ),
      "  now: \(map(select(.status == "cooking")) | length) cooking, \(map(select(.status == "ready")) | length) ready, \(map(select(.status == "done" and (.updated | startswith($d)))) | length) done today, \(map(select(.status == "86")) | length) dropped"' <<< $book
  done
  mkdir -p $BOOK && now_iso > $BOOK/.last-look
}

review() { # KEY|NUMBER: resume the order's build session here, by id, which finds it from any folder
  local -a f=( $BOOK/*/orders/$1.json(N) $BOOK/*/orders/*-$1.json(N) )
  f=( ${(u)f} )
  local -a keys=( ${f:t:r} )
  (( $#f )) || die "no order $1"
  (( $#f == 1 )) || die "$1 matches ${(j:, :)keys}; give the full key"
  local key=${f[1]:t:r} b=$(jq -r '.builder // ""' $f[1]) project=$(jq -r .project ${f[1]:h:h}/line.json)
  [[ -n $b ]] || die "$key has no build session on record; open it with /resume from $project/.claude/worktrees/$key"
  if [[ ${2:-} == --line ]]; then print -r -- "cd ${(q)project} && oc --resume $b"; return; fi
  cd $project && source $ALIASES && oc --resume $b
}

signoff() { # KEY [answer...]
  local f; f=$(need_order $1) || exit 1
  local key=$1; shift
  local st=$(jq -r .status $f)
  [[ $st == (at-the-pass|86) ]] || die "$key is $st, not waiting on you"
  local recipe=$(jq -r .recipe $f) next=ready
  [[ $recipe == catering ]] && die "$key is catering: run /kitchen cook $key in a session"
  # an order intake never finished goes back to intake
  [[ $recipe == null ]] && next=new
  # bringing back an order whose PR you closed starts it over with a new PR
  local -a extra=()
  [[ $(jq -r '.reason // ""' $f) == 'PR closed without merging'* ]] && extra=(pr=)
  order_set $key status=$next "answer=$*" question= retries=0 retry_after=0 $extra
}

# --- lines --------------------------------------------------------------------

line_add() { # PATH JQL
  local common
  text_of "${2:?JQL}"
  # a worktree registers its main checkout, the one slug_here matches
  common=$(git -C $1 rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || die "$1 is not a git checkout"
  line_write ${common:h} "$REPLY" false
}

line_write() { # PROJECT JQL PAUSED: create the project's line, or set the JQL of the one it has; prints its slug
  local project=$1 jql=$2 slug=${1:t}
  if [[ -f $BOOK/$slug/line.json && $(jq -r .project $BOOK/$slug/line.json) != $project ]]; then
    slug=${project:h:t}-${project:t}
  fi
  mkdir -p $BOOK/$slug/orders $BOOK/$slug/log
  local f=$BOOK/$slug/line.json
  if [[ -f $f ]]; then
    jq_write $f '.jql = $q' --arg q "$jql"
  else
    jq -n --arg p $project --arg q "$jql" --argjson paused $3 \
      '{project:$p, jql:$q, max_cooking:2, rail_depth:3, models:{serve:"sonnet", cook:""}, followup_hours:6, paused:$paused}' > $f
  fi
  print -- $slug
}

line_cmd() {
  local f
  case ${1:-list} in
    add) shift; line_add "$@" ;;
    list) for f in $BOOK/*/line.json(N); do jq -r --arg s ${f:h:t} '"\($s)\t\(.project)\t\(if .paused then "paused" else "on" end)\t\(.jql)"' $f; done ;;
    set)
      f=$BOOK/${2:?slug}/line.json; [[ -f $f ]] || die "no line $2"
      local kv
      for kv in "${@:3}"; do
        [[ $kv == *=* ]] || die "expected field=value, got: $kv"
        if [[ -n ${kv#*=} ]] && jq . <<< "${kv#*=}" >/dev/null 2>&1; then jq_write $f '.[$k] = $v' --arg k ${kv%%=*} --argjson v "${kv#*=}"
        else jq_write $f '.[$k] = $v' --arg k ${kv%%=*} --arg v "${kv#*=}"; fi
      done ;;
    pause|resume)
      f=$BOOK/${2:?slug}/line.json; [[ -f $f ]] || die "no line $2"
      jq_write $f '.paused = $p' --argjson p $([[ $1 == pause ]] && print true || print false) ;;
    rm) [[ -d $BOOK/${2:?slug} ]] || die "no line $2"; rm -rf $BOOK/$2 ;;
    *) die "line add|list|set|pause|resume|rm" ;;
  esac
}

# --- catches and promotion ------------------------------------------------------

catch_cmd() { # KEY|- TASTER CLASS NOTE [--chef]
  local key=$1 taster=$2 cls=$3 note=$4 src=line dir
  text_of "$note"; note=$REPLY
  [[ ${5:-} == --chef ]] && src=chef
  if [[ $key == - ]]; then
    local slug; slug=$(slug_here) || exit 1
    dir=$BOOK/$slug
  else
    local f; f=$(need_order $key) || exit 1
    dir=${f:h:h}
  fi
  print -r -- "$(today)	$key	$taster	$cls	${note//	/ }	$src" >> $dir/catches.tsv
  local n=$(awk -F'\t' -v c=$cls '$4 == c' $dir/catches.tsv | wc -l | tr -d ' ')
  local ticket=$(awk -F'\t' -v c=$cls '$1 == c {t = $2} END {print t}' $dir/promoted.tsv 2>/dev/null)
  print -- "count=$n"
  local due=
  if [[ -n $ticket ]]; then
    # a slip past an enforcement that shipped means it did not take
    local tf=$(order_file $ticket)
    [[ -n $tf && $(jq -r .status $tf) == done ]] && due="climb $ticket"
  elif [[ $src == chef ]] || (( n >= 2 )); then
    due=promote
  fi
  if [[ -n $due ]]; then
    awk -F'\t' -v c=$cls '$4 == c' $dir/catches.tsv
    print -- $due
  fi
}

promoted() { # CLASS TICKET
  local f; f=$(need_order $2) || exit 1
  print -r -- "$1	$2	$(today)" >> ${f:h:h}/promoted.tsv
}

classes() { # [TASTER]: catch classes this project has seen; none when it is not registered
  local slug; slug=$(slug_here 2>/dev/null) || return 0
  [[ -f $BOOK/$slug/catches.tsv ]] || return 0
  awk -F'\t' -v t="${1:-}" 't == "" || $3 == t {print $4}' $BOOK/$slug/catches.tsv | sort -u
}

patch_id() { # BASE [REF]: the id of REF's change (default HEAD) against origin/BASE, blind to context and line numbers
  git diff -U0 origin/$1...${2:-HEAD} | git patch-id --stable | cut -d' ' -f1
}

risk() { # BASE: why this checkout's change needs the user's eyes, one reason per line
  local files=$(git diff --name-only origin/$1...HEAD) extra
  extra=$(git show origin/$1:.claude/kitchen/house.md 2>/dev/null \
    | awk '/^## /{on = ($0 == "## Always review")} on && /^- `/ {sub(/^- `/, ""); sub(/`.*/, ""); print}' | paste -sd'|' -)
  {
    print -r -- $files | LC_ALL=C grep -E "$CHECK_PATHS" | sed 's/^/changes a check: /'
    print -r -- $files | LC_ALL=C grep -E "$RISK_PATHS" | sed 's/^/risky area: /'
    [[ -n $extra ]] && print -r -- $files | grep -E "$extra" | sed 's/^/project rule: /'
    git diff --name-only --diff-filter=D origin/$1...HEAD | grep -iE '(^|/)(tests?|specs?|__tests__)/|[._-](test|spec)\.' | sed 's/^/deletes a test: /'
    git diff -U0 origin/$1...HEAD | grep -E '^\+[^+]' | grep -E "$SKIP_LINES" | sed 's/^+[[:space:]]*/silences a check: /'
  } | head -5
}

sample() { # KEY: what this PR needs before it merges, run from its worktree: rebase, regate, review, or no
  local f; f=$(need_order $1) || exit 1
  local line=${f:h:h}/line.json base moved now
  base=$(order_base $f)
  git fetch -q origin $base 2>/dev/null
  local mb=$(git merge-base HEAD origin/$base)
  if [[ $mb != $(git rev-parse origin/$base) ]]; then
    # the base moved: a file both sides changed, or a changed check, means what would land was never tested
    moved=$(git diff --name-only $mb origin/$base)
    if [[ -n $(comm -12 <(print -r -- $moved | sort) <(git diff --name-only $mb HEAD | sort)) ]] || print -r -- $moved | LC_ALL=C grep -qE "$CHECK_PATHS"; then
      print -- rebase; return 0
    fi
  fi
  now=$(patch_id $base)
  [[ $now == $(jq -r '.gated // "none"' $f) ]] || { print -- regate; return 0; }
  # a verdict holds while the change is the one it checked; only a session that did not write the change gives one
  if [[ $now == $(jq -r '.verdict_patch // "none"' $f) ]]; then
    [[ $(jq -r '.verdict // ""' $f) == FAIL ]] && { print -- fix; return 0; }
  else
    print -- verify; return 0
  fi
  local -a why=( ${(f)"$(risk $base)"} )
  local merged=$(jq -s 'map(select(.status == "done" and .pr)) | length' ${f:h}/*.json) prob=$(jq -r ".probation // $PROBATION" $line)
  (( merged < prob )) && why+=("probation: $merged of $prob merged")
  if (( $#why )); then
    order_set $1 review=true "review_why=${(j:; :)why}"
  elif [[ $(jq -r .review $f) != true ]]; then
    local others=$(jq -rs --arg d "$(today)" --arg k $(jq -r .key $f) \
      'map(select(.key != $k and .review and ((.pr_opened // "") == $d))) | length' ${f:h}/*.json)
    (( others == 0 )) || { print -- no; return 0; }
    order_set $1 review=true sample=true "review_why=today's review sample"
  fi
  # the user's approval holds while the change is the one they approved
  if [[ $now == $(jq -r '.approved // "none"' $f) ]]; then print -- no; else print -- review; fi
}

order_cmd() {
  local f base
  case ${1:-} in
    get) f=$(need_order ${2:?KEY}) || exit 1; cat $f ;;
    new) shift; local slug; slug=$(slug_here) || exit 1; order_new $slug "$@" ;;
    set) shift; order_set "$@" ;;
    claim) claim ${2:?KEY} ;;
    withdraw) order_set ${2:?KEY} status=at-the-pass signoff=true "question=${3:?question}" ;;
    base) if [[ ${2:?KEY} == - ]]; then base_of "$(git rev-parse --show-toplevel)"; else f=$(need_order $2) || exit 1; order_base $f; fi ;;
    hold) f=$(need_order ${2:?KEY}) || exit 1
        local hours=$(jq -r '.followup_hours // 6' ${f:h:h}/line.json)
        order_set $2 status=new "reason=${3:?reason}" retry_after=$(( EPOCHSECONDS + hours * 3600 )) ;;
    pr) f=$(need_order ${2:?KEY}) || exit 1
        [[ $(jq -r .status $f) == 86 ]] && die "$2 was dropped"
        local opened=$(jq -r --arg u "${3:?url}" 'if .pr == $u then (.pr_opened // "") else "" end' $f)
        local state seen=()
        state=$(pr_state $(jq -r .project ${f:h:h}/line.json) $3)
        [[ $state == *$'\t'* ]] && seen=("pr_seen=${state#*$'\t'}")
        order_set $2 "pr=$3" status=pr-open "pr_opened=${opened:-$(today)}" handed=$EPOCHSECONDS "${seen[@]}" ;;
    gated) f=$(need_order ${2:?KEY}) || exit 1; base=$(order_base $f)
        order_set $2 "gated=$(patch_id $base)" "gated_head=$(git rev-parse HEAD)" "gated_base=$(git merge-base HEAD origin/$base)" ;;
    approve) f=$(need_order ${2:?KEY}) || exit 1; base=$(order_base $f)
        order_set $2 "approved=$(patch_id $base ${3:?commit})" ;;
    verify) f=$(need_order ${2:?KEY}) || exit 1
        [[ -n $(jq -r '.pr // ""' $f) ]] || die "$2 has no PR; run kitchen.zsh order pr first"
        order_set $2 status=pr-open verify=true handed=$EPOCHSECONDS ;;
    verdict) f=$(need_order ${2:?KEY}) || exit 1
        [[ ${3:-} == (PASS|PASS+NOTES|FAIL) ]] || die "verdict is PASS, PASS+NOTES, or FAIL"
        base=$(order_base $f)
        git fetch -q origin $base 2>/dev/null
        local fails=$(jq -r '.verify_fails // 0' $f)
        [[ $3 == FAIL ]] && fails=$(( fails + 1 ))
        # pr_seen and followed clear so the scheduler wakes a session to act on the verdict
        order_set $2 "verdict=$3" "verdict_notes=${4:?notes}" "verdict_patch=$(patch_id $base)" "verdict_head=$(git rev-parse HEAD)" \
          verify=false verify_fails=$fails verified_at=$EPOCHSECONDS pr_seen= followed=0
        print -- "verdict=$3 fails=$fails" ;;
    close) close_order ${2:?KEY} ;;
    list) order_list ${2:-} ;;
    transcript) transcript ${2:?KEY} ;;
    *) die "order get|new|set|claim|withdraw|base|hold|pr|verify|verdict|gated|approve|close|list|transcript" ;;
  esac
}

# --- worktrees ------------------------------------------------------------------

notice() { # DIR TEXT: a line for the user's next catch-up
  print -r -- "$(now_iso)	${2//	/ }" >> $1/notices.tsv
}

land_worktree() { # PROJECT WORKTREE DRY DIR MERGED BASE: remove a closed order's worktree; else say why it stays
  local project=$1 wt=$2 dry=$3 dir=$4 merged=$5 base=$6 l
  local branch=$(git -C $wt branch --show-current 2>/dev/null)
  if [[ -z $branch ]]; then print -- "  kept ${wt:t}: detached or broken"; return 1; fi
  if [[ -n $(git -C $wt status --porcelain 2>/dev/null) ]]; then print -- "  kept ${wt:t}: uncommitted changes"; return 1; fi
  if [[ -z $merged ]]; then
    # a dropped order's work stays while its branch changes anything the base lacks
    git -C $project fetch -q origin $base 2>/dev/null
    if ! git -C $project diff --quiet origin/$base...$branch 2>/dev/null; then
      print -- "  kept ${wt:t}: dropped with changes not in $base"
      return 1
    fi
  fi
  if [[ -n $dry ]]; then print -- "  would remove ${wt:t} ($branch)"; return 0; fi
  if [[ -f $wt/.claude-artifacts/teardown.sh ]] && ! ( cd $wt && bash .claude-artifacts/teardown.sh < /dev/null ) >> $dir/log/teardown.log 2>&1; then
    notice $dir "teardown failed in ${wt:t}; see $dir/log/teardown.log"
  fi
  # the vault branch can only tell it landed while the code branch still exists
  if [[ -f $VAULT_GIT ]]; then
    bash $VAULT_GIT sync $project < /dev/null 2>&1 | while IFS= read -r l; do [[ $l == vault:* ]] && notice $dir "$l"; done
  fi
  git -C $project worktree remove --force $wt >/dev/null 2>&1
  git -C $project branch -D $branch >/dev/null 2>&1
  [[ -n $(git -C $project ls-remote --heads origin $branch 2>/dev/null) ]] && git -C $project push -q origin --delete $branch >/dev/null 2>&1
  print -- "  removed ${wt:t} ($branch)"
}

land_order() { # PROJECT DIR KEY EPIC STATUS DRY: remove the worktrees of a closed order
  local project=$1 dir=$2 key=$3 epic=$4 merged= wt
  [[ $5 == done ]] && merged=1
  mkdir -p $dir/log
  for wt in $project/.claude/worktrees/$key(N/); do
    land_worktree $project $wt "$6" $dir "$merged" $(order_base $dir/orders/$key.json)
  done
  # a verify session's checkout is detached and holds nothing of its own
  wt=$project/.claude/worktrees/verify-$key
  if [[ -d $wt ]]; then
    if [[ -n $6 ]]; then print -- "  would remove ${wt:t}"
    else git -C $project worktree remove --force $wt >/dev/null 2>&1 && print -- "  removed ${wt:t}"; fi
  fi
  return 0
}

prune() { # [--dry-run]: remove the worktrees of every closed order no session holds
  local dry=${1:-} line slug project key epic st US=$'\x1f'
  for line in $BOOK/*/line.json(N); do
    slug=${line:h:t}
    print -- $slug
    project=$(jq -r .project $line)
    orders_json $slug | jq -r --arg us $US '.[] | select((.status == "done" or .status == "86") and .pid == 0) | [.key, (.epic // .key), .status] | join($us)' |
      while IFS=$US read -r key epic st; do
        [[ -d $project/.claude/worktrees/$key || -d $project/.claude/worktrees/verify-$key ]] || continue
        land_order $project ${line:h} $key $epic $st "$dry" < /dev/null
      done
    [[ -n $dry ]] || today > ${line:h}/.pruned
  done
}

# --- the scheduler --------------------------------------------------------------

new_uuid() { # sets REPLY to a random version-4 UUID, made without a process
  printf -v REPLY '%04x%04x-%04x-4%03x-%04x-%04x%04x%04x' $RANDOM $RANDOM $RANDOM $(( RANDOM & 0xfff )) \
    $(( (RANDOM & 0x3fff) | 0x8000 )) $RANDOM $RANDOM $RANDOM
}

fire() { # SLUG KEY PHASE STATUS DRY: start a headless session for an order
  local slug=$1 key=$2 phase=$3 st=$4 dry=$5 dir=$BOOK/$1
  local mode=$phase cmd=$phase
  [[ $phase == follow ]] && mode=cook cmd=cook
  [[ $phase == verify ]] && cmd='taste verify'
  if [[ -n $dry ]]; then print -- "$slug: would $phase $key"; return; fi
  local of=$(order_file $key)
  (( $(jq -r '.pid // 0' $of) == 0 )) || return 0  # a session claimed it since this pass read the book
  local project=$(jq -r .project $dir/line.json)
  # a retry after a tool error or a stall runs on the model stopped() picked
  local model=$(jq -r '.model // ""' $of)
  [[ -n $model ]] || model=$(jq -r --arg m $mode '.models[$m] // ""' $dir/line.json)
  local logf=$dir/log/$key.$phase.$(strftime '%Y%m%d-%H%M%S' $EPOCHSECONDS).log
  local -a extra=()
  [[ -n $model ]] && extra=(--model $model)
  mkdir -p $dir/log
  new_uuid; local sid=$REPLY
  # a follow-up resumes the order's build session, so the order stays one conversation the user opens by its key
  local -a sess=(--session-id $sid) builder=() bt=()
  if [[ $phase == follow ]]; then
    local b=$(jq -r '.builder // ""' $of)
    [[ -n $b && $(jq -r '.retry_cause // ""' $of) != context ]] && bt=( $HOME/.claude*/projects/*/$b.jsonl(N) )
    (( $#bt )) && sid=$b sess=(--resume $b)
  fi
  if [[ $phase == (cook|follow) && $sess[1] == --session-id ]]; then sess+=(--name $key) builder=(builder=$sid); fi
  # the goal keeps the session going until it leaves the mark reap() reads as finished
  local met
  case $phase in
    serve) met="kitchen.zsh order get $key prints a status other than serving" ;;
    cook) met="kitchen.zsh order get $key prints a status other than cooking" ;;
    follow) met="the session ran kitchen.zsh order pr, order verify, or order close for $key" ;;
    verify) met="kitchen.zsh order verdict $key printed a verdict" ;;
  esac
  # print mode stops background agents 10 minutes after the main loop goes idle; reap() is the limit instead
  ( cd $project && source $ALIASES && CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0 oc -p "/goal Run /kitchen $cmd $key and follow it to its end. The goal is met when $met, or when its claim of $key was refused." $sess $extra < /dev/null ) > $logf 2>&1 &!
  order_set $key status=$st pid=$! phase=$phase "log=$logf" "session=$sid" started=$EPOCHSECONDS stop_cause= stop_at=0 $builder
  log "$slug: $phase $key"
}

pr_state() { # PROJECT URL: "<OPEN|MERGED|CLOSED>\t<updated>|<approvals>", UNSUPPORTED for a host it cannot read, empty when the read failed
  case $2 in
    https://github.com/*)
      ( cd $1 && gh pr view $2 --json state,updatedAt,reviewDecision --jq '[.state, .updatedAt + "|" + (.reviewDecision // "")] | @tsv' < /dev/null 2>/dev/null ) ;;
    https://bitbucket.org/*)
      local ws=${${2#https://bitbucket.org/}%%/*} id=${${2##*/pull-requests/}%%/*}
      ( cd $1 && bb pr get $id -o json --profile $ws < /dev/null 2>/dev/null ) \
        | jq -r '[(if .state == "DECLINED" or .state == "SUPERSEDED" then "CLOSED" else .state end),
                  ((.updated_on // "") + "|" + ([.participants[]? | select(.approved) | .user.uuid // .user.account_id // ""] | sort | join(",")))] | @tsv' 2>/dev/null ;;
    *) print -- UNSUPPORTED ;;
  esac
}

kill_tree() { # PID SIGNAL: signal a process and everything under it, from one ps snapshot
  proc_table
  local -a tree=($1); local i=1 c
  while (( i <= $#tree )); do
    for c in ${(k)PROC_PARENT[(R)$tree[i]]}; do tree+=($c); done
    (( i++ ))
  done
  kill -$2 $tree 2>/dev/null
}

stop_cause() { # LOG: why a session ended early, read from the end of its log
  [[ -f $1 ]] || { print -- unknown; return; }
  local -a lines=( "${(@f)$(<$1)}" )
  lines=( "${(@)lines[$(( $#lines > 40 ? $#lines - 39 : 1 )),-1]}" )
  local l
  # a limit stop is never counted as a retry, so only the CLI's own line names one, never a session's words
  for l in ${(L)lines}; do
    [[ $l == (api\ error:\ (429|529)|usage\ limit\ reached|claude\ ai\ usage\ limit\ reached)* ]] && { print -- limit; return; }
  done
  case ${(L)${(F)lines}} in
    *(prompt\ is\ too\ long|context\ window|context\ length|maximum\ context|too\ many\ tokens)*) print -- context ;;
    *(econnreset|etimedout|socket\ hang\ up|fetch\ failed|network\ error|connection\ (reset|refused|error))*) print -- connection ;;
    *(api\ error|internal\ server\ error|invalid_request_error|tool_use)*) print -- tool ;;
    *) print -- unknown ;;
  esac
}

stopped() { # SLUG KEY PHASE LOG SESSION: a session ended without moving its order on; retry by cause
  local key=$2 phase=$3 logf=$4 back=ready f=$(order_file $2)
  [[ $phase == serve ]] && back=new
  [[ $phase == (follow|verify) ]] && back=pr-open
  [[ ${5:--} != - ]] && order_set $key "last_session=$5"
  local cause=$(stop_cause $logf)
  if [[ $cause == limit ]]; then
    order_set $key status=$back retry_after=$(( EPOCHSECONDS + LIMIT_WAIT ))
    # the limit holds for every session the line would start, so the whole line waits
    jq_write $BOOK/$1/line.json '.retry_after = $r' --argjson r $(( EPOCHSECONDS + LIMIT_WAIT ))
    log "$1: $key hit a usage limit; retrying after $(strftime '%H:%M' $(( EPOCHSECONDS + LIMIT_WAIT )))"
    return
  fi
  # the scheduler stopped a stuck session itself; that outranks what the log says
  [[ $(jq -r '.stop_cause // ""' $f) == stuck* ]] && cause=stuck
  # context: the next session keeps its own context small; connection: the same again;
  # a tool error or a stall: another model
  local -a extra=()
  if [[ $cause == (tool|stuck) ]]; then
    local mode=cook cur=$(jq -r '.model // ""' $f)
    [[ $phase == (serve|verify) ]] && mode=$phase
    [[ -n $cur ]] || cur=$(jq -r --arg m $mode '.models[$m] // ""' $BOOK/$1/line.json)
    if [[ $cur == sonnet* ]]; then extra=(model=opus); else extra=(model=sonnet); fi
  fi
  local n=$(( $(jq -r .retries $f) + 1 ))
  if (( n >= MAX_RETRIES )); then
    order_set $key status=86 retries=$n retry_cause=$cause \
      "reason=parked: the $phase session stopped $n times without finishing, the last for $cause; kitchen.zsh order transcript $key shows it"
    log "$1: $key stopped $n times; parked"
  else
    order_set $key status=$back retries=$n retry_cause=$cause $extra
    log "$1: $key $phase session stopped ($cause); retry $n${extra:+ on ${extra[1]#model=}}"
  fi
}

progress() { # PROJECT KEY TOUCHED STARTED: when the session last left a side effect: an order update, or a commit or reset in its worktree
  local -a m
  REPLY=$(( $3 > $4 ? $3 : $4 ))
  [[ -f $1/.git/worktrees/$2/logs/HEAD ]] && zstat -A m +mtime $1/.git/worktrees/$2/logs/HEAD 2>/dev/null && (( m[1] > REPLY )) && REPLY=$m[1]
  return 0
}

reap() { # SLUG: settle every session that ended since the last pass; stop one past its time limit or stuck
  local slug=$1 line=$BOOK/$1/line.json
  local lim=$(jq -c --argjson d "$DEFAULT_MINUTES" '$d + (.max_minutes // {})' $line)
  local stall=$(jq -c --argjson d "$DEFAULT_STALL" '$d + (.stall_minutes // {})' $line)
  local project=$(jq -r .project $line)
  local key st pid phase logf pr recipe started sid from limit handed sig alive p touched stopat stallmin verified why
  local -a live
  proc_table
  orders_json $slug | jq -r --arg us $'\x1f' --argjson lim "$lim" --argjson stall "$stall" '.[] | select(.pid > 0)
      | [.key, .status, (.pid|tostring), (.phase // "-"), (.log // "-"), (if (.pr // "") == "" then "-" else .pr end),
         (.recipe // "-"), ((.started // 0)|tostring), (.session // "-"), (.claimed_from // "-"),
         (($lim[.phase // ""] // 0)|tostring), ((.handed // 0)|tostring), ((.touched // 0)|tostring),
         ((.stop_at // 0)|tostring), (($stall[.phase // ""] // 0)|tostring), ((.verified_at // 0)|tostring)] | join($us)' |
  while IFS=$'\x1f' read -r key st pid phase logf pr recipe started sid from limit handed touched stopat stallmin verified; do
    # a fired session lives while its claude does, even after the subshell that started it is gone
    live=(); alive=0
    kill -0 $pid 2>/dev/null && live=($pid)
    [[ $phase != session && $sid != - ]] && live+=( ${(k)PROC_ARGS[(R)*--(session-id|resume) $sid*]} )
    (( $#live )) && alive=1
    if (( alive )); then
      # a session the user started holds the order only while it is cooking
      [[ $phase == session && $st == cooking ]] && continue
      if [[ $phase != session ]]; then
        why=
        if [[ $st == 86 ]]; then
          # a dropped order's session stops now, before it opens or merges the PR
          (( stopat > 0 && EPOCHSECONDS - stopat <= KILL_AFTER )) && continue
          sig=TERM; (( stopat > 0 )) && sig=KILL
        elif (( started > 0 && limit > 0 && EPOCHSECONDS - started > limit * 60 )); then
          sig=TERM; (( EPOCHSECONDS - started > limit * 60 + KILL_AFTER )) && sig=KILL
          why="ran past $limit minutes"
        elif (( stopat > 0 )); then
          # told to stop on an earlier pass and still running
          (( EPOCHSECONDS - stopat > KILL_AFTER )) || continue
          sig=KILL why="still running after TERM"
        else
          # judged by its side effects, never by what it says: no order update and no commit is no progress
          progress $project $key $touched $started
          (( stallmin > 0 && EPOCHSECONDS - REPLY > stallmin * 60 )) || continue
          sig=TERM why="no progress in $stallmin minutes"
        fi
        for p in $live; do kill_tree $p $sig; done
        if [[ $st == 86 ]]; then
          (( stopat > 0 )) || order_set $key stop_at=$EPOCHSECONDS
          log "$slug: $key was dropped; sent $sig to its $phase session"
        else
          (( stopat > 0 )) || order_set $key "stop_cause=stuck: $why" stop_at=$EPOCHSECONDS
          log "$slug: $key $phase session $why; sent $sig"
        fi
        continue  # settled on the pass that finds it dead
      fi
    fi
    case $phase:$st in
      serve:serving|cook:cooking) order_set $key pid=0; stopped $slug $key $phase $logf $sid ;;
      follow:pr-open)
        # a follow-up that never recorded the PR again did not finish
        order_set $key pid=0
        if (( handed < started )); then stopped $slug $key $phase $logf $sid
        else order_set $key retries=0 last_session= retry_cause= model=; fi ;;
      verify:pr-open)
        # a verify session that never recorded a verdict did not finish
        order_set $key pid=0
        if (( verified < started )); then stopped $slug $key $phase $logf $sid
        else order_set $key retries=0 last_session= retry_cause= model=; fi ;;
      session:cooking)
        if [[ $recipe == catering ]]; then
          order_set $key pid=0 status=at-the-pass signoff=true \
            "question=The catering session ended. Run /kitchen cook $key in a session to carry on."
        # a session that ended before intake finished leaves the ticket to intake
        elif [[ $recipe == - ]]; then order_set $key pid=0 status=new
        elif [[ $from == at-the-pass ]]; then order_set $key pid=0 status=at-the-pass
        # the user resumed the order's session to review its PR and left without handing it back
        elif [[ $from == pr-open ]]; then order_set $key pid=0 status=pr-open
        else order_set $key pid=0 status=ready; fi ;;
      *) order_set $key pid=0 retries=0 last_session= retry_cause= model= ;;
    esac
    [[ $pr != - && $phase != verify ]] && order_set $key followed=$EPOCHSECONDS
  done
}

finish() { # SLUG KEY: the PR merged; close the order and clear its worktrees
  close_order $2
  local key epic st
  local f=$(need_order $2) project=$(jq -r .project $BOOK/$1/line.json)
  IFS=$'\x1f' read -r key epic st <<< "$(jq -r '[.key, (.epic // .key), .status] | join("\u001f")' $f)"
  land_order $project $BOOK/$1 $key $epic $st "" >/dev/null
  log "$1: $2 merged and closed"
}

follow_prs() { # SLUG DRY: close merged PRs; wake the order's session when a PR changed
  local slug=$1 dry=$2 line=$BOOK/$1/line.json
  local project=$(jq -r .project $line) hours=$(jq -r .followup_hours $line)
  local key pr seen followed recipe spec verify state st upd
  orders_json $slug | jq -r --arg us $'\x1f' '.[] | select(.status == "pr-open" and .pid == 0 and (.pr // "") != "")
      | [.key, .pr, (if (.pr_seen // "") == "" then "-" else .pr_seen end), ((.followed // 0)|tostring),
         (.recipe // "-"), (if (.spec // "") == "" then "-" else .spec end), (.verify // false | tostring)] | join($us)' |
  while IFS=$'\x1f' read -r key pr seen followed recipe spec verify; do
    state=$(pr_state $project $pr)
    if [[ -z $state ]]; then log "$slug: could not read $pr; trying again next pass"; continue; fi
    st=${state%%$'\t'*} upd=${state#*$'\t'}
    case $st in
      MERGED)
        if [[ -n $dry ]]; then print -- "$slug: would close $key"
        elif [[ $recipe == catering && $spec == - ]]; then
          # a merged spec is planned into milestone orders with the user in a session
          order_set $key status=at-the-pass signoff=true \
            "question=The spec merged. Run /kitchen cook $key in a session to plan its milestones."
        else finish $slug $key; fi ;;
      CLOSED) [[ -n $dry ]] || order_set $key status=86 "reason=PR closed without merging: $pr" ;;
      OPEN)
        # catering's spec and final PRs are worked with the user, never by a follow-up; only a verdict runs
        [[ $recipe == catering && $verify != true ]] && continue
        # a change waiting for its verdict gets a session that did not write it
        if [[ $verify == true ]]; then fire $slug $key verify pr-open "$dry"
        elif [[ $upd != $seen ]]; then fire $slug $key follow pr-open "$dry"; fi ;;
      UNSUPPORTED)
        # a host the scheduler cannot read: look in on a timer; the session closes the order when it sees the merge
        [[ $recipe == catering && $verify != true ]] && continue
        if [[ $verify == true ]]; then fire $slug $key verify pr-open "$dry"
        elif (( EPOCHSECONDS - followed > hours * 3600 )); then fire $slug $key follow pr-open "$dry"; fi ;;
    esac
  done
}

serve_next() { # SLUG DRY: keep the ready queue stocked, one intake at a time
  local slug=$1 dry=$2 dir=$BOOK/$1 book=$(orders_json $1)
  local serving ready depth=$(jq -r .rail_depth $dir/line.json)
  read -r serving ready <<< "$(jq -r '[(map(select(.status == "serving"))|length), (map(select(.status == "ready"))|length)] | @tsv' <<< $book)"
  (( serving == 0 && ready < depth )) || return 0
  # a ticket whose intake stopped short goes first
  local key=$(jq -r --argjson now $EPOCHSECONDS 'map(select(.status == "new" and .retry_after <= $now)) | sort_by(.created) | .[0].key // empty' <<< $book)
  if [[ -z $key ]]; then
    local project=$(jq -r .project $dir/line.json) jql=$(jq -r .jql $dir/line.json) k
    # order_new refuses a key any line holds, so skip those, not only this line's
    typeset -A known=()
    local -a all=( $BOOK/*/orders/*.json(N) )
    (( $#all )) && for k in ${(f)"$(jq -r '.key, (.epic // empty)' $all)"}; do known[$k]=1; done
    for k in ${(f)"$(cd $project && jira issue list -q "$jql" --order-by rank --reverse --plain --no-headers --columns key 2>>$dir/log/jira.log)"}; do
      k=${k//[[:space:]]/}
      [[ -n $k && -z ${known[$k]:-} ]] && { key=$k; break; }
    done
    [[ -n $key ]] || return 0
    [[ -n $dry ]] || order_new $slug $key
  fi
  fire $slug $key serve serving "$dry"
}

cook_next() { # SLUG DRY: start ready orders whose files are free, up to max_cooking
  local slug=$1 dry=$2 dir=$BOOK/$1 book=$(orders_json $1) key
  local max=$(jq -r .max_cooking $dir/line.json)
  local busy=$(jq -r 'map(select(.pid > 0 and .phase != "serve")) | length' <<< $book)
  (( busy < max )) || return 0
  # catering is specced and planned with the user, so only its close starts here; an order waits until every
  # order in its after list is done; each pick claims its files for the next
  for key in ${(f)"$(jq -r --argjson now $EPOCHSECONDS --argjson free $(( max - busy )) '
    def overlaps($a; $b): ($a | startswith($b)) or ($b | startswith($a));
    (map(select(.status == "done")) | map(.key)) as $done
    | reduce (map(select(.status == "ready" and (.recipe != "catering" or .stage == "close") and .retry_after <= $now
        and (((.after // []) - $done) | length) == 0)) | sort_by(.created))[] as $o
      ({hot: (map(select(.status == "cooking")) | map(.station[]?)), keys: []};
       if (.keys | length) < $free and ([.hot[] as $h | $o.station[]? as $s | overlaps($h; $s)] | any | not)
       then .hot += [$o.station[]?] | .keys += [$o.key] else . end)
    | .keys[]' <<< $book)"}; do
    fire $slug $key cook cooking "$dry"
  done
}

tick() { # [--dry-run]: one scheduler pass over every line
  local dry=${1:-} line slug
  mkdir -p $BOOK
  if ! mkdir $BOOK/.tick.lock 2>/dev/null; then
    # a lock older than 15 minutes belongs to a pass that died
    [[ -n $(find $BOOK/.tick.lock -maxdepth 0 -mmin +15 2>/dev/null) ]] || return 0
    rm -rf $BOOK/.tick.lock; mkdir $BOOK/.tick.lock
  fi
  trap "rmdir $BOOK/.tick.lock 2>/dev/null" EXIT
  for line in $BOOK/*/line.json(N); do
    slug=${line:h:t}
    [[ $(jq -r '.paused // false' $line) == true ]] && continue
    [[ -d $(jq -r .project $line) ]] || { log "$slug: project is gone"; continue; }
    [[ -n $dry ]] || reap $slug
    (( $(jq -r '.retry_after // 0' $line) > EPOCHSECONDS )) && continue  # waiting out a usage limit
    follow_prs $slug "$dry"
    serve_next $slug "$dry"
    cook_next $slug "$dry"
  done
  # once a day, clear worktrees whose branch landed
  if [[ -z $dry ]]; then
    local stale=0
    for line in $BOOK/*/line.json(N); do [[ $(cat ${line:h}/.pruned 2>/dev/null) == $(today) ]] || stale=1; done
    (( stale )) && prune | while read -r l; do [[ $l == *removed* ]] && log "prune:$l"; done
  fi
  return 0
}

case ${1:-status} in
  status) status ;;
  review) shift; review "$@" ;;
  signoff) shift; signoff "$@" ;;
  line) shift; line_cmd "$@" ;;
  order) shift; order_cmd "$@" ;;
  decide) shift; decide "$@" ;;
  catch) shift; catch_cmd "$@" ;;
  classes) shift; classes "$@" ;;
  promoted) shift; promoted "$@" ;;
  sample) shift; sample "$@" ;;
  prune) shift; prune "$@" ;;
  tick) shift; tick "$@" ;;
  help) sed -n '/^# Usage:/,/^$/p' $0 ;;
  *) sed -n '/^# Usage:/,/^$/p' $0; exit 1 ;;
esac
