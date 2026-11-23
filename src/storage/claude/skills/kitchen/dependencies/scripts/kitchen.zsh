#!/usr/bin/env zsh
# The kitchen skill's deterministic half: the order book, the user's queue, and
# the scheduler pass that keeps work moving. Sessions read and write order state
# only through this script, so the format lives in one place.
#
# State lives in ~/.claude-artifacts/workflows/kitchen/<slug>/ (user lifecycle):
#   line.json          project path, capacity, and the unlock thresholds co-write_after, guided_after and auto_after
#   orders/<KEY>.json  one order per ticket
#   catches.tsv        date key taster class note source
#   promoted.tsv       class ticket time
#   due.tsv            class due count: each class the catch-up lists until a promotion answers it
#   log/               one log per session the scheduler starts
#   notices.tsv        date text: vault and teardown events for the catch-up
#
# Usage: a KEY may be an epic's key, for the order building it; a value written
# @/absolute/path is read from that file.
#   kitchen [status]                         this project: what waits on the user, what is ready to start, what happened since the last look
#   kitchen review KEY|NUMBER [--line]       open the order's build session in this terminal to review its PR; --line prints the command instead
#   kitchen signoff KEY ANSWER...            bring a dropped order back
#   kitchen modes                            the modes this project has unlocked
#   kitchen overrides                        this project's orders that carry a mode_override, oldest first
#   kitchen share                            how many of this project's orders made ready in the last 14 days are manual or co-write
#   kitchen calls                            how many calls the user made at the chef's table in this project's last 20 orders that had one, and how many changed the recommendation
#   kitchen handoff KEY                      open a manual order's worktree in a new VS Code window
#   kitchen stage KEY                        open a catering deployment's PR as staged changes in a review worktree in VS Code
#   kitchen filed KEY TICKET WHY             record a follow-up ticket filed for the order
#   kitchen order get KEY                    print the order
#   kitchen order new KEY [field=value...]   create an order in the current project
#   kitchen order set KEY field=value...     update fields
#   kitchen order claim KEY                  mark the order as worked by this session; refused while another holds it; an auto order becomes guided, except at the skeleton or calls stage
#   kitchen order next MODE                  key of the project's oldest ready order of that mode (manual, co-write or guided)
#   kitchen order base KEY|-                 the branch the order's work starts from and merges into; - for this repo's
#   kitchen order pr KEY URL                 record the PR and hand it to the scheduler
#   kitchen order verify KEY                 hand the PR to the scheduler for a verdict from a session that did not write it
#   kitchen order verdict KEY WORD NOTES [REASON...]  record PASS, PASS+NOTES, or FAIL for the change checked out here; each REASON is a Questions that hold a PR question that holds
#   kitchen order gated KEY                  record the change the quality gate passed; run in the order's worktree
#   kitchen order approve KEY COMMIT         record the change the user approved; it holds while the change stays the same; on a workspace line COMMIT is HEAD
#   kitchen order close KEY                  mark the order done and move its ticket with the merged moment
#   kitchen order list [STATUS]              this project's orders, or those with that status
#   kitchen order transcript KEY [--conversation]  path of the order's last session transcript; --conversation prints only what the user and the session said
#   kitchen decide KEY "decision: why" EVIDENCE [--chef kept|changed]  log a call made without the user, with what backs it; --chef logs one the user made, and whether they kept the recommendation
#   kitchen catch KEY|- TASTER CLASS NOTE [--chef]   log a review finding; prints promote, or climb TICKET, when due
#   kitchen classes [TASTER]                 catch classes this project has seen
#   kitchen promoted CLASS TICKET|-          record what answers a due promotion; - leaves it until its next catch
#   kitchen sample KEY                       what the PR needs before it merges: rebase, regate, fix, verify, review, or no
#   kitchen line add PATH [--workspace TYPE] | list | set SLUG field=value... | pause SLUG | resume SLUG | rm SLUG
#   kitchen workspace [VERB KEY [ARG...]]    the path of the line's workspace type doc, or its VERB run for the order KEY
#   kitchen each KEY [--changed] -- CMD...   run CMD from the top of each repo the order works in, $BASE in it that repo's base; --changed skips a repo with no commit past its base
#   kitchen house [PATH]                     whether the project is set up: its project rules hold the review and docs sections
#   kitchen rules [PATH]                     print the project rules: the base branch's copy when it holds one, else the main checkout's file
#   kitchen prune [--dry-run]                remove the worktrees of closed orders
#   kitchen tick [--dry-run]                 one scheduler pass over every project; it starts only auto orders

set -uo pipefail
setopt extendedglob
zmodload zsh/datetime
zmodload -F zsh/stat b:zstat

BOOK="${KITCHEN_BOOK:-$HOME/.claude-artifacts/workflows/kitchen}"
ALIASES="${KITCHEN_ALIASES:-${ZSH:-$HOME/.oh-my-zsh}/custom/aliases.zsh}"
VAULT_GIT="$HOME/.claude/skills/capture-documentation/scripts/vault-git.sh"
TICKET="$HOME/.claude/skills/ticket-provider/dependencies/scripts/ticket.zsh"
WS_DIR="${KITCHEN_WORKSPACES:-${0:A:h:h:h}/workspaces}"
MAX_RETRIES=3
LIMIT_WAIT=1800
KILL_AFTER=300
typeset -A UNLOCK_AFTER=(co-write 2 guided 3 auto 5)
DEFAULT_MINUTES='{"cook":360,"follow":120,"verify":90}'
# A session with no side effect this long is stuck: no order update, no commit or reset in its worktree.
DEFAULT_STALL='{"cook":60,"follow":45,"verify":45}'
# A change to these paths moves a check, so a base that changed one leaves a branch untested until it rebases.
CHECK_PATHS='(^|/)(\.github/workflows/|\.gitlab-ci\.yml$|bitbucket-pipelines\.yml$|\.circleci/|\.pre-commit-config\.yaml$|\.husky/|\.eslintrc|eslint\.config\.|tsconfig[^/]*\.json$|\.prettierrc|biome\.jsonc?$|\.?ruff\.toml$|mypy\.ini$|\.golangci|pyproject\.toml$|setup\.cfg$|\.flake8$|tox\.ini$|pytest\.ini$|(jest|vitest)\.config\.|\.claude/kitchen/house\.md$|\.claude/skills/verify[-/])'
# Every project's rules hold all three, empty or not: the paths that always wait for the user, the questions a verifier answers, and where the project's docs go and what a change must update.
REVIEW_SECTIONS=('### Critical paths' '### Questions that hold a PR' '### Docs')
# An added line matching this skips or silences a check.
SKIP_LINES='(eslint-disable|@ts-ignore|@ts-expect-error|@ts-nocheck|#[[:space:]]*type:[[:space:]]*ignore|#[[:space:]]*noqa|nolint|pragma: no cover|\.skip\(|(^|[^[:alnum:]_])x(it|describe)\(|@pytest\.mark\.(skip|xfail)|@Disabled|@Ignore|t\.Skip\()'

# Fields stored as JSON; every other field is a string.
typeset -A JSON_FIELDS=(earned 1 after 1 review 1 filed 1 retries 1 retry_after 1 pid 1 followed 1 station 1 done_when 1 steps 1 decisions 1 started 1 handled 1 handed 1 verify 1 verify_fails 1 verified_at 1 touched 1 stop_at 1 packages 1)

die() { print -u2 -- "kitchen: $*"; exit 1; }
# Microseconds, so the catch-up can tell an event after the last look from one in the same second.
now_iso() { local r=$EPOCHREALTIME s; strftime -s s '%Y-%m-%dT%H:%M:%S' ${r%.*}; print -- "$s.${${r#*.}[1,6]}"; }
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

ws_type() {
  jq -r '.workspace // ""' $1/line.json
}

ws_file() { # TYPE EXT: the path of the workspace type's file with that extension; dies when the type is not installed
  [[ $1 == [A-Za-z0-9_-]## && -f $WS_DIR/$1/$1.$2 ]] || die "workspace type [$1] is not installed: no $WS_DIR/$1/$1.$2"
  print -- $WS_DIR/$1/$1.$2
}

ws_run() { # LINE-DIR VERB [ARG...]: the line's workspace type runs VERB for the line's project
  local s; s=$(ws_file "$(ws_type $1)" zsh) || exit 1
  zsh $s $2 $(jq -r .project $1/line.json) "${@:3}"
}

slug_here() { # the line whose project holds the current directory
  local root f
  root=$(project_root) || exit 1
  for f in $BOOK/*/line.json(N); do
    [[ $(jq -r .project $f) == $root ]] && { print -- ${f:h:t}; return; }
  done
  # project rules in git mean /kitchen open ran on another machine; the scheduler stays there
  git -C $root ls-files --error-unmatch .claude/kitchen/house.md >/dev/null 2>&1 || die "no line for $root; run /kitchen open there"
  local slug; slug=$(line_write $root true) || exit 1
  print -u2 -- "kitchen: registered $root as $slug on this machine, paused, from its committed project rules"
  print -- $slug
}

base_of() { # PROJECT: its base branch, from its git-provider config, else the host's default (git-provider's config table)
  local b=$(jq -r '.baseBranch // empty' $1/.claude/git-provider/config.json 2>/dev/null)
  [[ -z $b && $(git -C $1 remote get-url origin 2>/dev/null) == *git.amazon.com* ]] && b=mainline
  print -- ${b:-main}
}

project_root() { # [DIR]: the project DIR lies in, the current directory by default: its workspace line's, else the main checkout of its repo, even from a worktree
  local d=${${1:-$PWD}:A} common p
  local -a lines=( $BOOK/*/line.json(N) )
  (( $#lines )) && for p in ${(f)"$(jq -r 'select((.workspace // "") != "") | .project' $lines)"}; do
    [[ $d/ == "$p"/* ]] && { print -- $p; return; }
  done
  common=$(git -C $d rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || die "not in a git checkout"
  print -- ${common:h}
}

house_rules() { # PROJECT [BASE]: the project rules; a copy on the base branch wins, so a branch cannot loosen committed rules
  git -C $1 show origin/${2:-$(base_of $1)}:.claude/kitchen/house.md 2>/dev/null || cat $1/.claude/kitchen/house.md 2>/dev/null
}

house_rows() { # RULES: each row of the Critical paths table, as path, extra effort, waits for me, and its cell count, split by \x1f; a \| in a cell reads as |
  print -r -- $1 | awk '
    /^#/{on = ($0 == "### Critical paths"); next}
    on && /^\|/ && !/^\|[ :|-]*$/ && !/^\|[[:space:]]*Path[[:space:]]*\|/ {
      line = $0; gsub(/\\\|/, "\001", line)
      n = split(line, c, "|") - 2
      for (i = 2; i <= 5; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", c[i]); gsub(/\001/, "|", c[i]) }
      print c[2] "\037" c[4] "\037" c[5] "\037" n
    }'
}

row_problem() { # REGEX-CELL EFFORT REVIEW CELLS: why kitchen cannot read a Critical paths row; nothing when it can
  local re=$1 rx=${${1#\`}%\`}
  if (( $4 != 4 )); then print -r -- "a path row has $4 cells, not 4 (write each | inside a regex as \\|): $re"
  elif [[ $re != \`*\` ]]; then print -r -- "a path row's regex is not in backticks: $re"
  elif [[ -z $rx ]]; then print -r -- "a path row's regex is empty, which would match every path"
  elif [[ $rx == \<* ]]; then print -r -- "a path row is still the template's example; fill or delete it: $re"
  elif [[ $2 != (yes|no) || $3 != (yes|no) ]]; then print -r -- "a path row's Extra effort and Waits for me each take yes or no: $re"
  else print -n | grep -E -- $rx 2>/dev/null; (( $? == 2 )) && print -r -- "a path row's regex is not an extended regular expression: $re"
  fi
}

review_paths() { # RULES: the readable path rows' regexes whose Waits for me says yes, joined into one alternation
  local re effort review n
  house_rows $1 | while IFS=$'\x1f' read -r re effort review n; do
    [[ -z $(row_problem "$re" "$effort" "$review" "$n") && $review == yes ]] && print -r -- ${${re#\`}%\`}
  done | paste -sd'|' -
}

house_problems() { # RULES: what keeps project rules from counting as set up, one per line; nothing when they do
  local s re effort review n
  for s in $REVIEW_SECTIONS; do print -r -- $1 | grep -qxF -- $s || print -- "lack $s"; done
  house_rows $1 | while IFS=$'\x1f' read -r re effort review n; do row_problem "$re" "$effort" "$review" "$n"; done
}

house_missing() { # PROJECT: what keeps its project rules from counting as set up, one per line; nothing when they do
  house_problems "$(house_rules $1)"
}

house_cmd() { # [PATH]: exits 0 when the project is set up; else says what keeps its rules from it
  local root=${1:-$(project_root)} missing
  missing=$(house_missing $root)
  [[ -z $missing ]] && { print -- "set up"; return 0; }
  local -a probs=( ${(f)missing} ) lacks=( ${${(M)${(f)missing}:#lack *}#lack } )
  probs=( ${probs:#lack *} )
  (( $#lacks )) && probs=( "lack ${(j:, :)lacks}" $probs )
  print -r -- "not set up: the project rules (origin/$(base_of $root) or $root/.claude/kitchen/house.md) ${(j:; :)probs}; run /kitchen open"
  return 1
}

order_base() { # ORDER-FILE: the order's own base, else its project's
  local b=$(jq -r '.base // empty' $1)
  [[ -z $b && -n $(ws_type ${1:h:h}) ]] && die "a workspace line has a base per package: kitchen.zsh workspace bases ${1:t:r}"
  [[ -n $b ]] && print -- $b || base_of $(jq -r .project ${1:h:h}/line.json)
}

lock_reason() { # DIR MODE: why the project has not unlocked MODE; nothing when it has
  local need=${2}_after prev merged=0
  case $2 in
    manual) return 0 ;;
    co-write) prev=manual ;;
    guided) prev=co-write ;;
    auto) prev=guided ;;
    *) print -- "$2 is not a mode"; return 0 ;;
  esac
  local below=$(lock_reason $1 $prev)
  [[ -z $below ]] || { print -- "$2 is locked: $below"; return 0; }
  local after=$(jq -r --arg k $need --argjson d $UNLOCK_AFTER[$2] '.[$k] // $d' $1/line.json)
  local -a f=( $1/orders/*.json(N) )
  # an order merged before modes existed, or while its mode was locked, is not earned and counts toward nothing
  (( $#f )) && merged=$(jq -s --arg m $prev 'map(select(.status == "done" and (.pr // "") != "" and .mode == $m and .earned == true)) | length' $f)
  (( merged >= after )) || print -- "$2 is locked: $merged of $after merged $prev orders ($need)"
}

NO_CODE_RECIPES=(investigation prototype eval runtime-forensics trace-forensics multi-phase-plan)
GUIDED_ONLY_RECIPES=(enforce change-a-skill)

check_mode() { # DIR MODE [RECIPE]: die unless MODE is one the project has unlocked and the recipe allows
  [[ $2 == (manual|co-write|guided|auto) ]] || die "mode is manual, co-write, guided, or auto, not $2"
  (( ${GUIDED_ONLY_RECIPES[(Ie)${3:-}]} )) && { [[ $2 == guided ]] || die "$3 runs only guided"; return 0; }
  # the lock builds trust in code the line writes, so a recipe that ships none may always run guided
  [[ $2 == guided && -n ${3:-} ]] && (( ${NO_CODE_RECIPES[(Ie)$3]} )) && return 0
  local why=$(lock_reason $1 $2)
  [[ -z $why ]] || die $why
}

share() { # this project's practice share, for intake's practice pick: manual and co-write orders among those made ready in the last 14 days
  local slug; slug=$(slug_here) || exit 1
  local since=$(strftime '%Y-%m-%dT%H:%M:%S' $(( EPOCHSECONDS - 14 * 86400 )))
  orders_json $slug | jq -r --arg s "$since" 'map(select((.ready_at // "") > $s)) | "manual or co-write \(map(select(.mode == "manual" or .mode == "co-write")) | length) of \(length) orders made ready since \($s[0:10])"'
}

modes() { # the modes the current project has unlocked
  local slug; slug=$(slug_here) || exit 1
  local m
  for m in manual co-write guided auto; do [[ -z $(lock_reason $BOOK/$slug $m) ]] && print -- $m; done
  return 0
}

check_kv() { # DIR field=value [RECIPE]: die when order_set would refuse it; sets REPLY to the value
  [[ $2 == *=* ]] || die "expected field=value, got: $2"
  local field=${2%%=*}
  text_of "${2#*=}"
  # a session the user resumes turns an auto order guided whatever the project has unlocked
  [[ $field == mode && -z ${MODE_FORCE:-} ]] && check_mode $1 $REPLY ${3:-}
  if (( ${+JSON_FIELDS[$field]} )); then
    jq -n --argjson v "$REPLY" '$v' >/dev/null 2>&1 || die "$field takes JSON, got: $REPLY"
  fi
  return 0
}

order_set() { # KEY field=value...
  local f; f=$(need_order $1) || exit 1
  shift
  local -a args=()
  local filter='.updated = $t | .touched = $e' kv field i=0 recipe=$(jq -r '.recipe // ""' $f) recipe_given= mode_given=
  for kv in "$@"; do
    [[ $kv == recipe=* ]] && recipe=${kv#recipe=} recipe_given=1
    [[ $kv == mode=* ]] && mode_given=1
  done
  # a recipe that allows only some modes holds the mode the order keeps
  [[ -n $recipe_given && -z $mode_given && -z ${MODE_FORCE:-} ]] && check_mode ${f:h:h} $(jq -r '.mode // "manual"' $f) $recipe
  for kv in "$@"; do
    check_kv ${f:h:h} $kv $recipe
    field=${kv%%=*}
    [[ $field == status && $REPLY == ready ]] && filter+=' | .ready_at = (.ready_at // $t)'
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
  # a refused field must not leave a half-made order that blocks the retry
  local kv recipe= mode_given=
  for kv in "$@"; do
    [[ $kv == recipe=* ]] && recipe=${kv#recipe=}
    [[ $kv == mode=* ]] && mode_given=1
  done
  [[ -n $recipe && -z $mode_given ]] && check_mode $BOOK/$slug manual $recipe
  for kv in "$@"; do check_kv $BOOK/$slug $kv $recipe; done
  mkdir -p $BOOK/$slug/orders
  jq -n --arg k $key --arg t "$(now_iso)" \
    '{key:$k, status:"new", mode:"manual", recipe:null, review:false,
      retries:0, retry_after:0, pid:0, phase:null, station:[], done_when:[], decisions:[], created:$t, updated:$t}' \
    > $BOOK/$slug/orders/$key.json
  (( $# )) && order_set $key "$@"
  return 0
}

decide() { # KEY DECISION EVIDENCE [--chef kept|changed]: a call made without the user, with what backs it; --chef logs a call the user made at the chef's table, and whether they kept the recommendation
  local f; f=$(need_order $1) || exit 1
  local d e took=
  text_of "${2:?decision}"; d=$REPLY
  text_of "${3:?evidence}"; e=$REPLY
  if [[ ${4:-} == --chef ]]; then
    [[ ${5:-} == (kept|changed) ]] || die "--chef takes kept or changed"
    took=$5
  fi
  jq_write $f '.decisions = ((.decisions // []) + [{at: $t, what: $d, evidence: $e} + (if $took == "" then {} else {by: "chef", took: $took} end)]) | .updated = $t' \
    --arg t "$(now_iso)" --arg d "$d" --arg e "$e" --arg took "$took"
}

calls() { # the user's calls at the chef's table in this project's last 20 orders that had one, and how many changed the recommendation
  local slug; slug=$(slug_here) || exit 1
  orders_json $slug | jq -r '[.[] | select(any((.decisions // [])[]; .by == "chef"))] | sort_by(.updated) | reverse | .[0:20] as $o
    | [$o[] | .decisions[] | select(.by == "chef")] as $c
    | "calls \($c | length) in \($o | length) orders, changed \($c | map(select(.took == "changed")) | length)"'
}

proc_table() { # one ps snapshot into PROC_PARENT, PROC_NAME and PROC_ARGS by pid; all empty where ps cannot list processes
  typeset -gA PROC_PARENT=() PROC_NAME=() PROC_ARGS=()
  local l; local -a w
  for l in ${(f)"$(ps -A -o pid= -o ppid= -o args= 2>/dev/null)"}; do
    w=( ${=l} )
    (( $#w >= 3 )) && PROC_PARENT[$w[1]]=$w[2] PROC_NAME[$w[1]]=${w[3]:t} PROC_ARGS[$w[1]]="${w[3,-1]}"
  done
  return 0
}

user_held() { # ORDER-FILE: true when a session the user started holds the order: not an auto order's cook session, nor a follow-up or verify; a skeleton, or an order held for the user's calls, is always the user's
  jq -r '((.mode // "manual") != "auto" or .stage == "skeleton" or .stage == "calls") and .phase == "cook"' $1
}

claim() { # KEY: mark the order as worked by the Claude session this runs in
  local f; f=$(need_order $1) || exit 1
  local st=$(jq -r .status $f) pid=$(jq -r .pid $f) p=$PPID own=0
  local -a chain=()
  proc_table
  while (( p > 1 )) && [[ -n ${PROC_PARENT[$p]:-} ]]; do chain+=($p); p=$PROC_PARENT[$p]; done
  # a fired session holds the order while its claude lives, as reap judges it
  local sid=$(jq -r '.session // ""' $f) user=$(user_held $f)
  if (( pid > 0 )) && ! kill -0 $pid 2>/dev/null && [[ $user != true && -n $sid ]]; then
    pid=${${(k)PROC_ARGS[(R)*--(session-id|resume) $sid*]}[1]:-0}
  fi
  if (( pid > 0 )) && kill -0 $pid 2>/dev/null; then
    if (( ${chain[(Ie)$pid]} )); then
      [[ $user != true || $st == cooking ]] && { print -- ok; return 0; }
    else
      die "$1 is being worked by another session (pid $pid)"
    fi
  fi
  # a new order is claimed only by a session the user started, which runs intake itself
  case $st in
    new|ready|cooking|pr-open) ;;
    86) die "$1 was dropped: $(jq -r '.reason // "no reason recorded"' $f). kitchen.zsh signoff $1 @<file> brings it back" ;;
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
  # a skeleton, or an order held for the user's calls, is the user's whatever its mode, and the order keeps its mode for the build
  [[ $(jq -r '.mode // ""' $f) == auto && $(jq -r '.stage // ""' $f) != (skeleton|calls) ]] && mine+=(mode=guided)
  MODE_FORCE=1 order_set $1 status=cooking phase=cook pid=$own started=$EPOCHSECONDS "claimed_from=$st" $mine
  print -- ok
}

close_order() { # KEY: mark the order done and move its ticket (catering's epic) with the merged moment
  local f; f=$(need_order $1) || exit 1
  local project=$(jq -r .project ${f:h:h}/line.json) ticket=$(jq -r '.epic // .key' $f)
  local pr=$(jq -r '.pr // empty' $f)
  if ! ( cd $project && $TICKET move $ticket merged "Merged: ${pr:-investigation answered}" < /dev/null >/dev/null 2>>${f:h:h}/log/ticket.log ); then
    notice ${f:h:h} "could not move $ticket with the merged moment; see log/ticket.log"
  fi
  # a catering order's mode is only the default, so its docs PR unlocks nothing
  local earned=true
  [[ $(jq -r .recipe $f) == catering || -n $(lock_reason ${f:h:h} $(jq -r '.mode // "manual"' $f)) ]] && earned=false
  order_set $1 status=done earned=$earned
}

order_list() { # [STATUS]: every order of the current project, or those with that status
  local slug; slug=$(slug_here 2>/dev/null) || die "no registered project here; run /kitchen open in a project's checkout"
  orders_json $slug | jq -r --arg s $slug --arg st "${1:-}" \
    '.[] | select($st == "" or .status == $st) | "\($s)\t\(.key)\t\(.status)\t\(.reason // .summary // "")"'
}

overrides() { # the current project's orders that carry a mode_override, oldest first
  local slug; slug=$(slug_here 2>/dev/null) || die "no registered project here; run /kitchen open in a project's checkout"
  orders_json $slug | jq -r 'map(select((.mode_override // "") != "")) | sort_by(.created)[] | "\(.key)  \(.mode_override | gsub("\\s*\n\\s*"; " "))"'
}

transcript() { # KEY [--conversation]: path of the order's last session transcript, or only what the user and the session said in it
  [[ -z ${2:-} || $2 == --conversation ]] || die "order transcript KEY [--conversation]"
  local f; f=$(need_order $1) || exit 1
  local sid=$(jq -r '(.last_session | select(. != "")) // .session // empty' $f)
  [[ -n $sid && $sid != - ]] || die "$1 has no recorded session"
  local -a t=( $HOME/.claude*/projects/*/$sid.jsonl(N) )
  (( $#t )) || die "no transcript for session $sid"
  [[ -n ${2:-} ]] || { print -- $t[1]; return }
  jq -r '
    def said: if type == "string" then .
      elif type == "array" and all(.[]; .type? != "tool_result") then [.[] | select(.type? == "text") | .text] | join("\n")
      else "" end;
    select((.type == "user" or .type == "assistant") and (.isMeta | not) and (.isCompactSummary | not) and (.isSidechain | not))
    | .type as $who
    | (.message.content | said | gsub("<system-reminder>[\\s\\S]*?</system-reminder>"; "")) as $t
    | (if ($t | test("<command-name>"))
       then ([$t | capture("<command-name>(?<n>[^<]*)</command-name>").n][0]) + " " + ([$t | capture("<command-args>(?<a>[\\s\\S]*?)</command-args>").a][0] // "")
       else $t end
       | gsub("\\A\\s+|\\s+\\z"; "")) as $say
    | select($say != "" and ($say | startswith("<task-notification") | not))
    | "### \(if $who == "user" then "user" else "session" end)\n\($say)\n"' $t[1]
}

# --- the user's queue ---------------------------------------------------------

status() { # this project: what waits on the user, what is ready to start, what happened since the last look
  local slug; slug=$(slug_here 2>/dev/null) || die "no registered project here; run /kitchen open in a project's checkout"
  local dir=$BOOK/$slug line=$BOOK/$slug/line.json
  # the look starts before the reads, so an event during them shows again rather than never
  local since=$(cat $dir/.last-look 2>/dev/null || print '0000') look=$(now_iso) book=$(orders_json $slug)
  print -- "$slug$([[ $(jq -r '.paused // false' $line) == true ]] && print ' (paused)')$([[ -n $(house_missing $(jq -r .project $line)) ]] && print '  NOT SET UP: run /kitchen open')"
  [[ -s $dir/due.tsv ]] && awk -F'\t' -v D=$dir/due.tsv '
    FILENAME == D { due[$1] = $2; cnt[$1] = $3; at[++n] = $1; next }
    ($4 in due) { seen[$4] = seen[$4] "\n      " $1 "  " $2 "  " $5 }
    END { for (i = 1; i <= n; i++) { c = at[i]
      print "  PROMOTE   " c "  " (due[c] == "promote" ? cnt[c] " catches" : "back after " substr(due[c], 7)) ", nothing checks it yet" seen[c] } }' $dir/due.tsv $dir/catches.tsv
  jq -r --arg s "$since" '
    ( (map(select(.status == "86")) | map(.key)) as $gone | map(select(.status == "ready"))[]
      | ((.after // []) - ((.after // []) - $gone)) as $by | select($by | length > 0)
      | "  BLOCKED   \(.key)  waits on dropped \($by | join(", "))" ),
    ( map(select(.status == "pr-open" and (.review or .mode == "manual"))) | sort_by(.updated)[]
      | "  REVIEW    \(.key)\(if .recipe == "catering" then "  [catering]" else "" end)  \(.pr)\(if .review_why then "  (\(.review_why))" else "" end)\(if .builder then "  kitchen review \(.key)" else "" end)\(if .catering then "  kitchen stage \(.key)" else "" end)" ),
    ( (map(select(.status == "done")) | map(.key)) as $done
      | map(select(.status == "ready" and (((.after // []) - $done) | length) == 0)) as $ready
      | ("calls", "skeleton", "manual", "co-write", "guided") as $m
      | $ready | map(select(if $m == "calls" or $m == "skeleton" then .stage == $m else .stage != "skeleton" and .stage != "calls" and (.mode // "manual") == $m end)) | sort_by(.ready_at // .created)[]
      | "  READY     \(.key)  \($m)\(if .catering then "  [\(.catering)]" else "" end)  approved \((.ready_at // .created)[0:16])\(if .recipe == "catering" then "  [catering]" else "" end)  \(.question // .summary // "")" ),
    ( map(select(.updated > $s)) as $new
      | ( $new | map(select(.status == "done" and .pr))[]
          | "  merged    \(.key)  \(.summary // "")",
            ( select((.review // false) | not) | (.decisions // [])[] | select(.by != "chef") | "    decided   \(.what)\(if .evidence then "  (\(.evidence))" else "" end)" ) ),
        ( $new | map(select(.status == "86"))[] | "  dropped   \(.key)  \(.reason // "")" ),
        ( .[] | .key as $k | (.filed // [])[] | select(.at > $s) | "  filed     \($k)  \(.ticket)  \(.why)" ) )' <<< $book
  [[ -f $dir/promoted.tsv ]] && awk -F'\t' -v s="$since" '$3 > s {print "  promoted  " $1 " -> " $2}' $dir/promoted.tsv
  [[ -f $dir/notices.tsv ]] && awk -F'\t' -v s="$since" '$1 > s {print "  notice    " $2}' $dir/notices.tsv
  jq -r --arg d "$(today)" '"  now: \(map(select(.status == "cooking")) | length) cooking, \(map(select(.status == "ready")) | length) ready, \(map(select(.status == "done" and (.updated | startswith($d)))) | length) done today, \(map(select(.status == "86")) | length) dropped"' <<< $book
  print -- $look > $dir/.last-look
}

review() { # KEY|NUMBER: resume the order's build session here, by id, which finds it from any folder
  local -a f=( $BOOK/*/orders/$1.json(N) $BOOK/*/orders/*-$1.json(N) )
  f=( ${(u)f} )
  local -a keys=( ${f:t:r} )
  (( $#f )) || die "no order $1"
  (( $#f == 1 )) || die "$1 matches ${(j:, :)keys}; give the full key"
  local key=${f[1]:t:r} b=$(jq -r '.builder // ""' $f[1]) project=$(jq -r .project ${f[1]:h:h}/line.json)
  [[ -n $b ]] || die "$key has no build session on record; open it with /resume from $(wt_dir ${f[1]:h:h} $key)"
  if [[ ${2:-} == --line ]]; then print -r -- "cd ${(q)project} && oc --resume $b"; return; fi
  cd $project && source $ALIASES && oc --resume $b
}

signoff() { # KEY [answer...]: bring a dropped order back
  local f; f=$(need_order $1) || exit 1
  local key=$1; shift
  local st=$(jq -r .status $f)
  [[ $st == 86 ]] || die "$key is $st, not dropped"
  local recipe=$(jq -r .recipe $f) next=ready
  [[ $recipe == catering ]] && die "$key is catering: run /kitchen cook $key in a session"
  # an order intake never finished goes back to intake
  [[ $recipe == null ]] && next=new
  # bringing back an order whose PR you closed starts it over with a new PR
  local -a extra=()
  [[ $(jq -r '.reason // ""' $f) == 'PR closed without merging'* ]] && extra=(pr=)
  order_set $key status=$next "answer=$*" retries=0 retry_after=0 $extra
}

# --- lines --------------------------------------------------------------------

line_add() { # PATH [--workspace TYPE]: register the project PATH lies in, refusing one that nests with another line's; prints its slug
  local root type= s f p
  if [[ ${2:-} == --workspace ]]; then
    type=${3:?TYPE}
    s=$(ws_file $type zsh) || exit 1
    root=$(zsh $s root ${1:?PATH}) || die "$1 is not in a $type workspace"
    # house_rules would read the enclosing repository's branches instead of the project's own file
    git -C $root rev-parse --git-dir >/dev/null 2>&1 && die "$root is inside a git repository"
    for f in $BOOK/*/line.json(N); do
      p=$(jq -r .project $f)
      [[ $p != $root && ( $p/ == $root/* || $root/ == $p/* ) ]] && die "$root and $p, the project of line ${f:h:t}, lie one inside the other"
    done
  else
    root=$(project_root ${1:?PATH} 2>/dev/null) || die "$1 is not a git checkout"
    for f in $BOOK/*/line.json(N); do
      [[ -n $(ws_type ${f:h}) && $(jq -r .project $f) == $root ]] && die "$1 lies in $root, the project of workspace line ${f:h:t}, so it is never a line of its own"
    done
  fi
  ( cd $root && $TICKET provider >/dev/null ) || die "no ticket-provider config for $root; run the ticket-provider skill's setup there"
  line_write $root false $type
}

line_write() {
  local project=$1 slug=${1:t}
  if [[ -f $BOOK/$slug/line.json && $(jq -r .project $BOOK/$slug/line.json) != $project ]]; then
    slug=${project:h:t}-${project:t}
  fi
  mkdir -p $BOOK/$slug/orders $BOOK/$slug/log
  local f=$BOOK/$slug/line.json
  [[ -f $f ]] || jq -n --arg p $project --argjson paused $2 --arg w "${3:-}" \
    '{project:$p, max_cooking:2, followup_hours:6, paused:$paused} + (if $w == "" then {} else {workspace:$w} end)' > $f
  print -- $slug
}

line_cmd() {
  local f
  case ${1:-list} in
    add) shift; line_add "$@" ;;
    list) for f in $BOOK/*/line.json(N); do jq -r --arg s ${f:h:t} '"\($s)\t\(.project)\t\(if .paused then "paused" else "on" end)"' $f; done ;;
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

workspace_cmd() { # [VERB KEY [ARG...]]: the path of the line's workspace type doc, or its VERB run for the order KEY
  local dir f
  if (( $# )); then
    f=$(need_order ${2:?KEY}) || exit 1
    dir=${f:h:h}
  else
    local slug; slug=$(slug_here) || exit 1
    dir=$BOOK/$slug
  fi
  local t=$(ws_type $dir)
  [[ -n $t ]] || { (( $# )) && die "${dir:t} names no workspace type"; return 0; }
  (( $# )) || { ws_file $t md; return; }
  ws_run $dir $1 $f "${@:3}"
}

each_cmd() { # KEY [--changed] -- CMD...: run CMD from the top of each repo the order works in, BASE set to that repo's base and $BASE or ${BASE} in CMD replaced by it; a line with no workspace type runs it once, its output and exit untouched; else each run is headed with its repo and the worst exit wins
  local f; f=$(need_order ${1:?KEY}) || exit 1
  local dir=${f:h:h} changed= rows row label rdir base rc worst=0
  shift
  [[ ${1:-} == --changed ]] && { changed=1; shift; }
  [[ ${1:-} == -- && $# -gt 1 ]] || die "usage: each KEY [--changed] -- CMD..."
  shift
  if [[ -z $(ws_type $dir) ]]; then
    rdir=$(git rev-parse --show-toplevel 2>/dev/null) || die "not in a git checkout"
    base=$(order_base $f)
    base_args $base "$@"
    cd $rdir && BASE=$base "${reply[@]}"
    return
  fi
  rows=$(ws_run $dir repos $f $PWD) || exit 1
  for row in ${(f)rows}; do
    IFS=$'\x1f' read -r label rdir base <<< $row
    [[ -n $changed ]] && unchanged $rdir $base && continue
    print -r -- "== $label"
    base_args $base "$@"
    ( cd $rdir && BASE=$base "${reply[@]}" ); rc=$?
    (( rc > worst )) && worst=$rc
  done
  return $worst
}

base_args() { # BASE ARG...: sets reply to the ARGs with each $BASE and ${BASE} replaced by BASE; a longer name such as $BASEDIR stays
  local b=$1; shift
  reply=( "${@//\$\{BASE\}/$b}" )
  reply=( "${reply[@]//(#m)\$BASE[[:IDENT:]]#/${${MATCH:#\$BASE}:-$b}}" )
}

unchanged() { # DIR BASE: true only when git counts no commit past origin/BASE in the repo at DIR; a base it cannot read counts as changed
  local n
  n=$(git -C $1 rev-list --count origin/$2..HEAD 2>/dev/null) && (( n == 0 ))
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
    undue $dir $cls
    print -r -- "$cls	$due	$n" >> $dir/due.tsv
  fi
}

undue() { # DIR CLASS: the catch-up stops listing the class as due
  [[ -f $1/due.tsv ]] || return 0
  awk -F'\t' -v c=$2 '$1 != c' $1/due.tsv > $1/due.tsv.new && mv $1/due.tsv.new $1/due.tsv
}

promoted() { # CLASS TICKET|-: a cleanup ticket is on the board, not in the book, so the line comes from the order or the current directory
  (( $# == 2 )) || die "usage: promoted CLASS TICKET|-"
  local f=$(order_file $2) dir slug
  if [[ -n $f ]]; then dir=${f:h:h}; else slug=$(slug_here) || exit 1; dir=$BOOK/$slug; fi
  [[ $2 == - ]] || print -r -- "$1	$2	$(now_iso)" >> $dir/promoted.tsv
  undue $dir $1
}

classes() { # [TASTER]: catch classes this project has seen; none when it is not registered
  local slug; slug=$(slug_here 2>/dev/null) || return 0
  [[ -f $BOOK/$slug/catches.tsv ]] || return 0
  awk -F'\t' -v t="${1:-}" 't == "" || $3 == t {print $4}' $BOOK/$slug/catches.tsv | sort -u
}

patch_id() { # BASE [REF]: the id of REF's change (default HEAD) against origin/BASE, blind to context and line numbers
  git diff -U0 origin/$1...${2:-HEAD} | git patch-id --stable | cut -d' ' -f1
}

each_repo() { # ORDER-FILE FN [ARG...]: run FN BASE [ARG...] in each repo the order works in, with REPO_LABEL set to <repo>/ and each output line prefixed with the repo's name; on a line with no type, once here with REPO_LABEL unset
  local dir=${1:h:h} rows row label rdir base rc=0
  if [[ -z $(ws_type $dir) ]]; then $2 $(order_base $1) "${@:3}"; return; fi
  rows=$(ws_run $dir repos $1 $PWD) || return 1
  for row in ${(f)rows}; do
    IFS=$'\x1f' read -r label rdir base <<< $row
    ( cd $rdir && REPO_LABEL=$label/ $2 $base "${@:3}" ) | sed "s|^|$label: |" || rc=1
  done
  return $rc
}

change_id() { # ORDER-FILE [REF]: one id for the order's change; a lone repo's is its patch id and never fails, a workspace line's hashes every repo's and fails when one cannot be read
  if [[ -z $(ws_type ${1:h:h}) ]]; then
    patch_id $(order_base $1) ${2:-}
    return 0
  fi
  local r; r=$(each_repo $1 patch_id ${2:-}) || return 1
  print -r -- $r | git hash-object --stdin
}

head_sha() { git rev-parse HEAD; }
merge_base_sha() { git merge-base HEAD origin/$1; }
fetch_base() { git fetch -q origin $1 2>/dev/null; }

rebase_needed() { # BASE: prints rebase when the base moved under a file this branch changed, or under a check, so what would land was never tested
  fetch_base $1
  local mb=$(merge_base_sha $1) moved
  [[ $mb == $(git rev-parse origin/$1) ]] && return 0
  moved=$(git diff --name-only $mb origin/$1)
  if [[ -n $(comm -12 <(print -r -- $moved | sort) <(git diff --name-only $mb HEAD | sort)) ]] || print -r -- $moved | LC_ALL=C grep -qE "$CHECK_PATHS"; then print -- rebase; fi
}

risk() { # BASE STATION: why this checkout's change needs the user's eyes, one reason per line; STATION is the order's files, one per line, each matched against REPO_LABEL followed by the repo-relative path
  local files=$(git diff --name-only origin/$1...HEAD) extra rules=$(house_rules $(project_root) $1)
  extra=$(review_paths $rules)
  {
    # a row kitchen cannot read may be the one that should hold this change, so it holds every change until fixed
    [[ -n $(house_problems $rules | grep -v '^lack ') ]] && print -- "project rule: a Critical paths row kitchen cannot read; kitchen.zsh house names it"
    # a path the order's station names was weighed at intake
    [[ -n $extra ]] && print -r -- $files | grep -E "$extra" \
      | ST=$2 LB=${REPO_LABEL:-} awk 'BEGIN { n = split(ENVIRON["ST"], s, "\n") } { for (i = 1; i <= n; i++) if (s[i] != "" && index(ENVIRON["LB"] $0, s[i]) == 1) next; print "project rule: " $0 }'
    print -r -- $files | LC_ALL=C grep -E "$CHECK_PATHS" | sed 's/^/changes a check: /'
    git diff --name-only --diff-filter=D origin/$1...HEAD | grep -iE '(^|/)(tests?|specs?|__tests__)/|[._-](test|spec)\.' | sed 's/^/deletes a test: /'
    git diff -U0 origin/$1...HEAD | grep -E '^\+[^+]' | grep -E "$SKIP_LINES" | sed 's/^+[[:space:]]*/silences a check: /'
  } | head -5
}

flag_review() { # KEY REASON...: flag the order for the user's review; a reason it already carries (a call decided alone) stays, each new one joins once
  local f; f=$(need_order $1) || exit 1
  local key=$1 had=$(jq -r 'if .review then .review_why // "" else "" end' $f) r
  shift
  for r in $@; do [[ $had == *"$r"* ]] || had=${had:+$had; }$r; done
  order_set $key review=true "review_why=$had"
}

sample() { # KEY: what this PR needs before it merges, run from its worktree: rebase, regate, fix, verify, review, or no
  local f; f=$(need_order $1) || exit 1
  local now
  # the user merges a manual order's PR, approved or not, so it waits on them whatever the check below finds
  local manual=
  if [[ $(jq -r '.mode // "manual"' $f) == manual ]]; then manual=1; flag_review $1 "manual order: the user merges it"; fi
  [[ -n $(each_repo $f rebase_needed) ]] && { print -- rebase; return 0; }
  now=$(change_id $f) || exit 1
  [[ $now == $(jq -r '.gated // "none"' $f) ]] || { print -- regate; return 0; }
  # a verdict holds while the change is the one it checked; only a session that did not write the change gives one
  if [[ $now == $(jq -r '.verdict_patch // "none"' $f) ]]; then
    [[ $(jq -r '.verdict // ""' $f) == (FAIL|PASS+NOTES) ]] && { print -- fix; return 0; }
  else
    print -- verify; return 0
  fi
  local -a why=( ${(f)"$(each_repo $f risk "$(jq -r '(.station // [])[]' $f)")"} )
  local judged=$(jq -r '.verdict_review // ""' $f)
  [[ -n $judged ]] && why+=("judged: $judged")
  (( $#why )) && flag_review $1 $why
  # the user's approval holds while the change is the one they approved
  if [[ -z $manual && $now == $(jq -r '.approved // "none"' $f) ]]; then print -- no
  elif [[ -n $manual || $(jq -r .review $f) == true ]]; then print -- review
  else print -- no; fi
}

order_next() { # MODE: key of the current project's oldest ready order of that mode, by when it became ready
  [[ $1 == (manual|co-write|guided) ]] || die "next takes manual, co-write, or guided, not $1"
  local slug; slug=$(slug_here) || exit 1
  # the user starts a catering order with take, and an order waits until every order in its after list is done
  local key=$(orders_json $slug | jq -r --arg m $1 '(map(select(.status == "done")) | map(.key)) as $done
    | map(select(.status == "ready" and .pid == 0 and (.mode // "manual") == $m and .recipe != "catering" and (((.after // []) - $done) | length) == 0))
    | sort_by(.ready_at // .created) | .[0].key // empty')
  [[ -n $key ]] || die "no ready $1 order in $slug"
  print -- $key
}

filed() { # KEY TICKET WHY: a follow-up ticket filed for the order
  local f; f=$(need_order $1) || exit 1
  local why; text_of "${3:?why}"; why=$REPLY
  jq_write $f '.filed = ((.filed // []) + [{at: $t, ticket: $k, why: $w}]) | .updated = $t' \
    --arg t "$(now_iso)" --arg k "${2:?TICKET}" --arg w "$why"
}

handoff() { # KEY: open the manual order's worktree in a new VS Code window
  local f; f=$(need_order ${1:?KEY}) || exit 1
  local slug; slug=$(slug_here) || exit 1
  [[ ${f:h:h:t} == $slug ]] || die "$1 is not an order of $slug"
  [[ $(jq -r '.mode // ""' $f) == manual ]] || die "$1 is not a manual order"
  local wt=$(wt_dir ${f:h:h} $1)
  [[ -d $wt ]] || die "no worktree at $wt"
  code -n $wt < /dev/null || die "could not open $wt with code"
  print -- "opened $wt in a new VS Code window"
}

stage() { # KEY: the catering deployment's PR as staged changes in its own review worktree, opened in VS Code
  local f; f=$(need_order ${1:?KEY}) || exit 1
  [[ -n $(jq -r '.catering // ""' $f) ]] || die "$1 is not a catering deployment"
  [[ -z $(ws_type ${f:h:h}) ]] || die "stage does not support a workspace line"
  # the session reviewing it holds the order as cooking, so the recorded PR is the test
  [[ -n $(jq -r '.pr // ""' $f) ]] || die "$1 has no PR to stage"
  local key=$(jq -r .key $f) project=$(jq -r .project ${f:h:h}/line.json) base=$(order_base $f)
  local wt=$project/.claude/worktrees/$key rv=$project/.claude/worktrees/review-$key
  [[ -d $wt ]] || die "no worktree at $wt"
  local head=$(git -C $wt rev-parse HEAD) mb
  git -C $wt fetch -q origin $base 2>/dev/null
  mb=$(git -C $wt merge-base $head origin/$base) || die "no merge base of $key and origin/$base"
  # a second run rebuilds the review from the PR's current head
  [[ -d $rv ]] && { git -C $project worktree remove --force $rv >/dev/null 2>&1 || die "could not remove $rv"; }
  git -C $project worktree add -q --detach $rv $head >/dev/null 2>&1 || die "could not add the review worktree $rv"
  git -C $rv reset -q --soft $mb || die "could not stage the change in $rv"
  code -n $rv < /dev/null || die "could not open $rv with code; the review worktree stays"
  local n=$(git -C $rv diff --cached --name-only | wc -l)
  print -- "staged $key in $rv: ${n// /} files changed"
}

order_cmd() {
  local f id
  case ${1:-} in
    get) f=$(need_order ${2:?KEY}) || exit 1; cat $f ;;
    new) shift; local slug; slug=$(slug_here) || exit 1; order_new $slug "$@" ;;
    set) shift; order_set "$@" ;;
    claim) claim ${2:?KEY} ;;
    next) order_next ${2:?MODE} ;;
    base) if [[ ${2:?KEY} == - ]]; then base_of "$(git rev-parse --show-toplevel)"; else f=$(need_order $2) || exit 1; order_base $f; fi ;;
    pr) f=$(need_order ${2:?KEY}) || exit 1
        [[ $(jq -r .status $f) == 86 ]] && die "$2 was dropped"
        local opened=$(jq -r --arg u "${3:?url}" 'if .pr == $u then (.pr_opened // "") else "" end' $f)
        local state seen=()
        state=$(pr_state $(jq -r .project ${f:h:h}/line.json) $3)
        [[ $state == *$'\t'* ]] && seen=("pr_seen=${state#*$'\t'}")
        order_set $2 "pr=$3" status=pr-open "pr_opened=${opened:-$(today)}" handed=$EPOCHSECONDS "${seen[@]}" ;;
    gated) f=$(need_order ${2:?KEY}) || exit 1; id=$(change_id $f) || exit 1
        order_set $2 "gated=$id" "gated_head=$(each_repo $f head_sha)" "gated_base=$(each_repo $f merge_base_sha)" ;;
    approve) f=$(need_order ${2:?KEY}) || exit 1
        [[ ${3:?commit} == HEAD || -z $(ws_type ${f:h:h}) ]] || die "a workspace line approves only HEAD, each repo's current head: kitchen.zsh order approve $2 HEAD"
        id=$(change_id $f $3) || exit 1
        order_set $2 "approved=$id" ;;
    verify) f=$(need_order ${2:?KEY}) || exit 1
        [[ -n $(jq -r '.pr // ""' $f) ]] || die "$2 has no PR; run kitchen.zsh order pr first"
        order_set $2 status=pr-open verify=true handed=$EPOCHSECONDS ;;
    verdict) f=$(need_order ${2:?KEY}) || exit 1
        [[ ${3:-} == (PASS|PASS+NOTES|FAIL) ]] || die "verdict is PASS, PASS+NOTES, or FAIL"
        each_repo $f fetch_base
        id=$(change_id $f) || exit 1
        local fails=$(jq -r '.verify_fails // 0' $f)
        [[ $3 == (FAIL|PASS+NOTES) ]] && fails=$(( fails + 1 ))
        # pr_seen and followed clear so the scheduler wakes a session to act on the verdict
        order_set $2 "verdict=$3" "verdict_notes=${4:?notes}" "verdict_review=${(j:; :)@[5,-1]}" "verdict_patch=$id" \
          "verdict_head=$(each_repo $f head_sha)" verify=false verify_fails=$fails verified_at=$EPOCHSECONDS pr_seen= followed=0
        print -- "verdict=$3 fails=$fails" ;;
    close) close_order ${2:?KEY} ;;
    list) order_list ${2:-} ;;
    transcript) transcript ${2:?KEY} ${3:-} ;;
    *) die "order get|new|set|claim|next|base|pr|verify|verdict|gated|approve|close|list|transcript" ;;
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
  # a test the run timed out can leave its child looping after the worktree is gone
  reap_orphans $wt
  # the vault branch can only tell it landed while the code branch still exists
  if [[ -f $VAULT_GIT ]]; then
    bash $VAULT_GIT sync $project < /dev/null 2>&1 | while IFS= read -r l; do [[ $l == vault:* ]] && notice $dir "$l"; done
  fi
  git -C $project worktree remove --force $wt >/dev/null 2>&1
  git -C $project branch -D $branch >/dev/null 2>&1
  [[ -n $(git -C $project ls-remote --heads origin $branch 2>/dev/null) ]] && git -C $project push -q origin --delete $branch >/dev/null 2>&1
  print -- "  removed ${wt:t} ($branch)"
}

wt_dir() {
  if [[ -n $(ws_type $1) ]]; then ws_run $1 path $2; else print -- $(jq -r .project $1/line.json)/.claude/worktrees/$2; fi
}

land_ws() { # LINE-DIR KEY MERGED DRY: a workspace line's closed order: each repo's worktree lands as a lone repo's does, then the type removes what is left
  local dir=$1 key=$2 merged=$3 dry=$4 rows= row label wt base common kept= wd=$(wt_dir $1 $2) vd=$(wt_dir $1 verify-$2)
  if [[ -d $wd ]] && ! rows=$(ws_run $dir repos $dir/orders/$key.json $wd); then print -- "  kept $key: its repos could not be listed"; kept=1; fi
  for row in ${(f)rows}; do
    IFS=$'\x1f' read -r label wt base <<< $row
    common=$(git -C $wt rev-parse --path-format=absolute --git-common-dir)
    land_worktree ${common:h} $wt "$dry" $dir "$merged" $base || kept=1
  done
  [[ -d $wd && -z $kept && -z $dry ]] && ws_run $dir remove $key && print -- "  removed $key"
  [[ -d $vd ]] || return 0
  if [[ -n $dry ]]; then print -- "  would remove verify-$key"; else ws_run $dir remove verify-$key && print -- "  removed verify-$key"; fi
}

land_order() { # PROJECT DIR KEY EPIC STATUS DRY: remove the worktrees of a closed order
  local project=$1 dir=$2 key=$3 epic=$4 merged= wt
  [[ $5 == done ]] && merged=1
  mkdir -p $dir/log
  [[ -z $(ws_type $dir) ]] || { land_ws $dir $key "$merged" "$6"; return 0; }
  for wt in $project/.claude/worktrees/$key(N/); do
    land_worktree $project $wt "$6" $dir "$merged" $(order_base $dir/orders/$key.json)
  done
  # a verify or staged review checkout is detached and holds nothing of its own
  for wt in $project/.claude/worktrees/{verify,review}-$key(N/); do
    if [[ -n $6 ]]; then print -- "  would remove ${wt:t}"
    else git -C $project worktree remove --force $wt >/dev/null 2>&1 && print -- "  removed ${wt:t}"; fi
  done
  return 0
}

prune() { # [--dry-run]: remove the worktrees of every closed order no session holds
  local dry=${1:-} line slug project typed key epic st US=$'\x1f'
  for line in $BOOK/*/line.json(N); do
    slug=${line:h:t}
    print -- $slug
    project=$(jq -r .project $line)
    typed=$(ws_type ${line:h})
    orders_json $slug | jq -r --arg us $US '.[] | select((.status == "done" or .status == "86") and .pid == 0) | [.key, (.epic // .key), .status] | join($us)' |
      while IFS=$US read -r key epic st; do
        if [[ -z $typed ]]; then
          [[ -d $project/.claude/worktrees/$key || -d $project/.claude/worktrees/verify-$key || -d $project/.claude/worktrees/review-$key ]] || continue
        else
          [[ -d $(wt_dir ${line:h} $key) || -d $(wt_dir ${line:h} verify-$key) || -d $(wt_dir ${line:h} review-$key) ]] || continue
        fi
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
  local cmd=$phase
  [[ $phase == follow ]] && cmd=cook
  [[ $phase == verify ]] && cmd='taste verify'
  if [[ -n $dry ]]; then print -- "$slug: would $phase $key"; return; fi
  local of=$(order_file $key)
  (( $(jq -r '.pid // 0' $of) == 0 )) || return 0  # a session claimed it since this pass read the book
  local project=$(jq -r .project $dir/line.json)
  # a retry after a tool error or a stall runs on the model stopped() picked; any other session inherits the user's
  local model=$(jq -r '.model // ""' $of)
  local logf=$dir/log/$key.$phase.$(strftime '%Y%m%d-%H%M%S' $EPOCHSECONDS).log
  local -a extra=()
  [[ -n $model ]] && extra=(--model $model)
  mkdir -p $dir/log
  new_uuid; local sid=$REPLY
  # a follow-up resumes the build session of an order the scheduler built; for any other order that session is the user's own conversation
  local -a sess=(--session-id $sid) builder=() bt=()
  local built=$([[ $(jq -r '.mode // ""' $of) == auto ]] && print 1)
  if [[ $phase == follow && -n $built ]]; then
    local b=$(jq -r '.builder // ""' $of)
    [[ -n $b && $(jq -r '.retry_cause // ""' $of) != context ]] && bt=( $HOME/.claude*/projects/*/$b.jsonl(N) )
    (( $#bt )) && sid=$b sess=(--resume $b)
  fi
  if [[ $phase == (cook|follow) && $sess[1] == --session-id ]]; then sess+=(--name $key); [[ -n $built ]] && builder=(builder=$sid); fi
  # the goal keeps the session going until it leaves the mark reap() reads as finished
  local met
  case $phase in
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
    https://code.amazon.com/reviews/CR-*)
      # the CR page's own JSON, read with the Midway cookie, per git-provider's crux mode (Get PR); an expired cookie reads as a failed read
      local cr=${${2#https://code.amazon.com/reviews/}%%/*}
      curl -sfL --max-time 30 --cookie $HOME/.midway/cookie -H 'Accept: application/json' "https://code.amazon.com/reviews/$cr.json" < /dev/null 2>/dev/null \
        | jq -r '.revision.cr_revision | [(if .status == "SHIPPED" then "MERGED" elif (.status | test("DISCARD|CANCEL|CLOSE|ABANDON")) then "CLOSED" else "OPEN" end),
                  ((.last_updated_at // "" | tostring) + "|" + ((.approved_by // []) | sort | join(",")))] | @tsv' 2>/dev/null ;;
    *) print -- UNSUPPORTED ;;
  esac
}

kill_tree() { # SIGNAL PID...: signal each process and everything under it, from one ps snapshot
  proc_table
  local -a tree=(${@:2}); local i=1 c
  (( $#tree )) || return 0
  while (( i <= $#tree )); do
    for c in ${(k)PROC_PARENT[(R)$tree[i]]}; do tree+=($c); done
    (( i++ ))
  done
  kill -$1 $tree 2>/dev/null
}

reap_orphans() { # DIR: kill every orphan working under DIR, and everything under it
  proc_table
  local l pid
  local -a orphans
  for l in ${(f)"$(lsof -d cwd -Fpn 2>/dev/null)"}; do
    case $l in
      p*) pid=${l#p} ;;
      n*) [[ ${PROC_PARENT[$pid]:-} == 1 && ${l#n} == $1(|/*) ]] && orphans+=($pid) ;;
    esac
  done
  kill_tree KILL $orphans
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
    local cur=$(jq -r '.model // ""' $f)
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

reply_mtime() { # FILE: raises REPLY to FILE's mtime when that is later
  local -a m
  [[ -f $1 ]] && zstat -A m +mtime $1 2>/dev/null && (( m[1] > REPLY )) && REPLY=$m[1]
  return 0
}

progress() { # LINE-DIR KEY TOUCHED STARTED: when the session last left a side effect: an order update, or a commit or reset in its worktree, in any repo of it
  local row label rdir base
  REPLY=$(( $3 > $4 ? $3 : $4 ))
  if [[ -z $(ws_type $1) ]]; then
    reply_mtime "$(jq -r .project $1/line.json)"/.git/worktrees/$2/logs/HEAD
    return 0
  fi
  for row in ${(f)"$(ws_run $1 repos $1/orders/$2.json "$(wt_dir $1 $2)" 2>/dev/null)"}; do
    IFS=$'\x1f' read -r label rdir base <<< $row
    reply_mtime "$(git -C $rdir rev-parse --absolute-git-dir 2>/dev/null)"/logs/HEAD
  done
  return 0
}

reap() { # SLUG: settle every session that ended since the last pass; stop one past its time limit or stuck
  local slug=$1 line=$BOOK/$1/line.json
  local lim=$(jq -c --argjson d "$DEFAULT_MINUTES" '$d + (.max_minutes // {})' $line)
  local stall=$(jq -c --argjson d "$DEFAULT_STALL" '$d + (.stall_minutes // {})' $line)
  local key st pid phase user logf pr recipe started sid from limit handed sig alive touched stopat stallmin verified why
  local -a live
  proc_table
  orders_json $slug | jq -r --arg us $'\x1f' --argjson lim "$lim" --argjson stall "$stall" '.[] | select(.pid > 0)
      | [.key, .status, (.pid|tostring), (.phase // "-"), ((((.mode // "manual") != "auto" or .stage == "skeleton" or .stage == "calls") and .phase == "cook")|tostring), (.log // "-"), (if (.pr // "") == "" then "-" else .pr end),
         (.recipe // "-"), ((.started // 0)|tostring), (.session // "-"), (.claimed_from // "-"),
         (($lim[.phase // ""] // 0)|tostring), ((.handed // 0)|tostring), ((.touched // 0)|tostring),
         ((.stop_at // 0)|tostring), (($stall[.phase // ""] // 0)|tostring), ((.verified_at // 0)|tostring)] | join($us)' |
  while IFS=$'\x1f' read -r key st pid phase user logf pr recipe started sid from limit handed touched stopat stallmin verified; do
    # a fired session lives while its claude does, even after the subshell that started it is gone
    live=(); alive=0
    kill -0 $pid 2>/dev/null && live=($pid)
    [[ $user != true && $sid != - ]] && live+=( ${(k)PROC_ARGS[(R)*--(session-id|resume) $sid*]} )
    (( $#live )) && alive=1
    if (( alive )); then
      # a session the user started holds the order only while it is cooking
      [[ $user == true && $st == cooking ]] && continue
      if [[ $user != true ]]; then
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
          progress $BOOK/$slug $key $touched $started
          (( stallmin > 0 && EPOCHSECONDS - REPLY > stallmin * 60 )) || continue
          sig=TERM why="no progress in $stallmin minutes"
        fi
        kill_tree $sig $live
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
    case $user:$phase:$st in
      true:*:cooking)
        if [[ $recipe == catering ]]; then
          order_set $key pid=0 status=ready \
            "question=The catering session ended. Run /kitchen cook $key in a session to carry on."
        # a session that ended before intake finished leaves the ticket to intake
        elif [[ $recipe == - ]]; then order_set $key pid=0 status=new
        # the user resumed the order's session to review its PR and left without handing it back
        elif [[ $from == pr-open ]]; then order_set $key pid=0 status=pr-open
        else order_set $key pid=0 status=ready; fi ;;
      *:cook:cooking) order_set $key pid=0; stopped $slug $key $phase $logf $sid ;;
      *:follow:pr-open)
        # a follow-up that never recorded the PR again did not finish
        order_set $key pid=0
        if (( handed < started )); then stopped $slug $key $phase $logf $sid
        else order_set $key retries=0 last_session= retry_cause= model=; fi ;;
      *:verify:pr-open)
        # a verify session that never recorded a verdict did not finish
        order_set $key pid=0
        if (( verified < started )); then stopped $slug $key $phase $logf $sid
        else order_set $key retries=0 last_session= retry_cause= model=; fi ;;
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
  local key pr seen followed verify state st upd
  orders_json $slug | jq -r --arg us $'\x1f' '.[] | select(.status == "pr-open" and .pid == 0 and (.pr // "") != "")
      | [.key, .pr, (if (.pr_seen // "") == "" then "-" else .pr_seen end), ((.followed // 0)|tostring),
         (.verify // false | tostring)] | join($us)' |
  while IFS=$'\x1f' read -r key pr seen followed verify; do
    state=$(pr_state $project $pr)
    if [[ -z $state ]]; then log "$slug: could not read $pr; trying again next pass"; continue; fi
    st=${state%%$'\t'*} upd=${state#*$'\t'}
    case $st in
      MERGED)
        if [[ -n $dry ]]; then print -- "$slug: would close $key"
        else finish $slug $key; fi ;;
      CLOSED) [[ -n $dry ]] || order_set $key status=86 "reason=PR closed without merging: $pr" ;;
      OPEN)
        # a change waiting for its verdict gets a session that did not write it
        if [[ $verify == true ]]; then fire $slug $key verify pr-open "$dry"
        elif [[ $upd != $seen ]]; then fire $slug $key follow pr-open "$dry"; fi ;;
      UNSUPPORTED)
        # a host the scheduler cannot read: look in on a timer; the session closes the order when it sees the merge
        if [[ $verify == true ]]; then fire $slug $key verify pr-open "$dry"
        elif (( EPOCHSECONDS - followed > hours * 3600 )); then fire $slug $key follow pr-open "$dry"; fi ;;
    esac
  done
}

cook_next() { # SLUG DRY: start ready auto orders whose files are free, up to max_cooking
  local slug=$1 dry=$2 dir=$BOOK/$1 book=$(orders_json $1) key
  local max=$(jq -r .max_cooking $dir/line.json)
  local busy=$(jq -r 'map(select(.pid > 0)) | length' <<< $book)
  (( busy < max )) || return 0
  # a catering order is wrapped up by the user, a skeleton is worked with them, and an order held for their calls waits on their answer, so none starts here; an order
  # waits until every order in its after list is done; each pick claims its files for the next
  for key in ${(f)"$(jq -r --argjson now $EPOCHSECONDS --argjson free $(( max - busy )) '
    def overlaps($a; $b): ($a | startswith($b)) or ($b | startswith($a));
    (map(select(.status == "done")) | map(.key)) as $done
    | reduce (map(select(.status == "ready" and .mode == "auto" and (.recipe != "catering" and .stage != "skeleton" and .stage != "calls") and .retry_after <= $now
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
    [[ -d $(jq -r .project $line) ]] || { log "$slug: project is gone"; continue; }
    # pausing stops new work only: a running session keeps its time limit and stall check
    [[ -n $dry ]] || reap $slug
    [[ $(jq -r '.paused // false' $line) == true ]] && continue
    (( $(jq -r '.retry_after // 0' $line) > EPOCHSECONDS )) && continue  # waiting out a usage limit
    follow_prs $slug "$dry"
    # a project whose rules lack a review section takes no new work until /kitchen open sets it up
    if [[ -n $(house_missing $(jq -r .project $line)) ]]; then
      log "$slug: not set up, so no new work; run /kitchen open there"
      continue
    fi
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
  modes) modes ;;
  overrides) overrides ;;
  share) share ;;
  calls) calls ;;
  handoff) shift; handoff "$@" ;;
  stage) shift; stage "$@" ;;
  filed) shift; filed "$@" ;;
  signoff) shift; signoff "$@" ;;
  line) shift; line_cmd "$@" ;;
  order) shift; order_cmd "$@" ;;
  decide) shift; decide "$@" ;;
  catch) shift; catch_cmd "$@" ;;
  classes) shift; classes "$@" ;;
  promoted) shift; promoted "$@" ;;
  sample) shift; sample "$@" ;;
  house) shift; house_cmd "$@" ;;
  rules) shift; house_rules "${1:-$(project_root)}" ;;
  prune) shift; prune "$@" ;;
  tick) shift; tick "$@" ;;
  workspace) shift; workspace_cmd "$@" ;;
  each) shift; each_cmd "$@" ;;
  help) sed -n '/^# Usage:/,/^$/p' $0 ;;
  *) sed -n '/^# Usage:/,/^$/p' $0; exit 1 ;;
esac
