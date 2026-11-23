#!/usr/bin/env zsh
# Stub harness for kitchen.zsh: drives the order book and the scheduler pass against fake
# tools inside one temp sandbox. Usage: scheduler.zsh [case...]   (no case names runs all)

setopt extendedglob
zmodload zsh/datetime
zmodload zsh/zselect

HERE=${0:A:h}
KITCHEN=${KITCHEN_UNDER_TEST:-${HERE:h}/scripts/kitchen.zsh}
[[ -f $KITCHEN ]] || { print -u2 -- "no kitchen.zsh at $KITCHEN"; exit 2 }

SB=$(mktemp -d)
SB=${SB:A}

kill_matching() { # PATTERN: kill every process whose command line holds it, and what each started
  local -a pids=( $(pgrep -f -- "$1") )
  (( $#pids )) || return 0
  pkill -KILL -P ${(j:,:)pids} 2>/dev/null
  kill -KILL $pids 2>/dev/null
  return 0
}
cleanup() { kill_matching $SB; rm -rf "${SB:?}" }
trap cleanup EXIT
trap 'exit 130' INT TERM

unset CLAUDE_CODE_SESSION_ID ZSH
export HOME=$SB/home ZDOTDIR=$SB/home
export PATH=$SB/bin:$PATH
export GIT_CONFIG_GLOBAL=$SB/gitconfig GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=harness GIT_AUTHOR_EMAIL=harness@example.invalid
export GIT_COMMITTER_NAME=harness GIT_COMMITTER_EMAIL=harness@example.invalid
export KITCHEN_ALIASES=$SB/bin/aliases.zsh KITCHEN_SCRIPT=$KITCHEN FORBIDDEN_LOG=$SB/forbidden.log

mkdir -p $SB/bin $HOME/.claude/skills/ticket-provider/dependencies/scripts $HOME/.claude/skills/capture-documentation/scripts
print -r -- $'[init]\n\tdefaultBranch = main' > $SB/gitconfig
cp $HERE/stubs/{gh,lsof,aliases.zsh} $SB/bin/
for t in claude jira bb curl; do cp $HERE/stubs/forbidden $SB/bin/$t; done
# recording fakes: code and open log their arguments
print -r -- $'#!/bin/sh\nprintf "%s\\n" "$*" >> "$CODE_LOG"' > $SB/bin/code
print -r -- $'#!/bin/sh\nprintf "%s\\n" "$*" >> "$OPEN_LOG"' > $SB/bin/open
chmod +x $SB/bin/code $SB/bin/open
cp $HERE/stubs/ticket.zsh $HOME/.claude/skills/ticket-provider/dependencies/scripts/
cp $HERE/stubs/vault-git.sh $HOME/.claude/skills/capture-documentation/scripts/

# one seeded origin, copied per case
git init -q --bare $SB/tmpl.git
git clone -q $SB/tmpl.git $SB/seed 2>/dev/null
mkdir -p $SB/seed/src $SB/seed/tests $SB/seed/.claude/kitchen
print one > $SB/seed/app.txt
print one > $SB/seed/src/a.txt
print one > $SB/seed/tests/foo_test.py
print -r -- $'# House rules\n\n### Critical paths\n\n| Path | What it is | Extra effort | Waits for me |\n|---|---|---|---|\n| `^secrets/` | credentials | no | yes |\n| `^(vault\\|keys)/` | escaped alternation | no | yes |\n| `^slow/` | costly but not held | yes | no |\n\n### Questions that hold a PR\n- the change moves money\n\n### Docs\n- docs live in docs/' > $SB/seed/.claude/kitchen/house.md
git -C $SB/seed add -A
git -C $SB/seed commit -q -m seed
git -C $SB/seed push -q origin main 2>/dev/null

# --- harness plumbing -------------------------------------------------------------

typeset -a FAILS
NCASE=0 PASSED=0 FAILED=0 OUT= RC=0 CLAIMER=0

fresh() {
  CASE=$SB/c$(( ++NCASE ))
  mkdir -p $CASE/gh
  cp -R $SB/tmpl.git $CASE/origin.git
  git clone -q $CASE/origin.git $CASE/proj 2>/dev/null
  PROJ=$CASE/proj
  BOOKDIR=$CASE/book/proj
  unset KITCHEN_WORKSPACES
  # a workspace type's tools reach outside the sandbox everywhere but in its own cases, which put its stubs in place
  local t
  for t in ${HERE:h:h}/workspaces/*/tests/stubs/*(N:t); do cp $HERE/stubs/forbidden $SB/bin/$t; done
  export KITCHEN_BOOK=$CASE/book OC_CALLS=$CASE/oc.calls OC_MODE=$CASE/oc.mode GH_STATE=$CASE/gh
  export TICKET_LOG=$CASE/ticket.log VAULT_LOG=$CASE/vault.log CODE_LOG=$CASE/code.log OPEN_LOG=$CASE/open.log VICTIM_FILE=$CASE/victim.pid
}

k() { ( cd $PROJ && zsh $KITCHEN "$@" ) }
kw() { local d=$1; shift; ( cd $d && zsh $KITCHEN "$@" ) }
tick() { OUT=$(cd $PROJ && zsh $KITCHEN tick "${1:-}" $CASE 2>&1) } # the extra argument marks this case's processes for the sweep
nap() { zselect -t ${1:-5} || : }
mode() { print -r -- $1 > $OC_MODE; (( $# > 1 )) && print -r -- $2 >> $OC_MODE; return 0 }
wt() { print -r -- $PROJ/.claude/worktrees/$1 }

ord() { jq -r --arg f $2 '.[$f] | if . == null then "" else tostring end' $BOOKDIR/orders/$1.json }
jqedit() { local f=$BOOKDIR/orders/$1.json; jq "${@:3}" "$2" $f > $f.new && mv $f.new $f }
lineedit() { jq "$1" $BOOKDIR/line.json > $BOOKDIR/line.new && mv $BOOKDIR/line.new $BOOKDIR/line.json }
ncalls() { [[ -f $OC_CALLS ]] && print -- ${$(wc -l < $OC_CALLS)// /} || print 0 }
call() { sed -n "${1}p" $OC_CALLS } # the Nth fake session start: cwd, ceiling, then each argument, tab separated
today_str() { strftime '%Y-%m-%d' $EPOCHSECONDS }

wait_calls() { local i; for i in {1..100}; do (( $(ncalls) >= $1 )) && return 0; nap; done; return 1 }
wait_dead() { # KEY: until the order's session process is gone
  local pid=$(ord $1 pid) i
  (( pid > 0 )) || return 0
  for i in {1..100}; do kill -0 $pid 2>/dev/null || return 0; nap; done
  return 1
}
alive() { kill -0 $1 2>/dev/null }
victim() { ( sleep 60 < /dev/null > /dev/null 2>&1 & print $! > $VICTIM_FILE ) } # a process whose parent is gone, as a terminal session's claude is once its shell reaps it

mkline() { # [field=value...]
  k line add $PROJ > /dev/null
  k line set proj co-write_after=0 guided_after=0 auto_after=0 "$@"
  today_str > $BOOKDIR/.pruned
}
mkorder() { k order new "$1" status=ready recipe=feature mode=auto "${@:2}" }
mkwt() { git -C $PROJ worktree add -q $(wt $1) -b $1 origin/main 2>/dev/null }
wtcommit() { # KEY FILE LINE
  mkdir -p $(wt $1)/${2:h}
  print -r -- $3 >> $(wt $1)/$2
  git -C $(wt $1) add -A
  git -C $(wt $1) commit -q -m "change $2"
}
wtdelete() { git -C $(wt $1) rm -q $2 && git -C $(wt $1) commit -q -m "delete $2" }
advance_base() { # FILE: another clone pushes a commit to main touching FILE
  local o=$CASE/other
  [[ -d $o ]] || git clone -q $CASE/origin.git $o 2>/dev/null
  mkdir -p $o/${1:h}
  print $RANDOM >> $o/$1
  git -C $o add -A
  git -C $o commit -q -m "move $1"
  git -C $o push -q origin main 2>/dev/null
}
prurl() { print -r -- https://github.com/o/r/pull/$1 }
setpr() { printf '%s\t%s|\n' $2 $3 > $GH_STATE/$1 } # N STATE UPDATED
mkpr() { # KEY N: an open order whose PR was last seen at u1
  setpr $2 OPEN u1
  mkorder $1 status=pr-open > /dev/null
  k order pr $1 $(prurl $2) > /dev/null
}
spawn_claimer() { # KEY OUTFILE: a process named claude that runs order claim, then stays alive
  ( export CLAUDE_CODE_SESSION_ID=sess-$1; exec -a claude zsh -c 'zsh "$1" order claim "$2" > "$3" 2>&1; print $? >> "$3"; sleep 100; :' _ $KITCHEN $1 $2 ) &!
  CLAIMER=$!
  local i
  for i in {1..100}; do [[ $(tail -n 1 $2 2>/dev/null) == [0-9]## ]] && return 0; nap; done
  return 1
}
stop_claimer() { pkill -KILL -P $CLAIMER 2>/dev/null; kill -KILL $CLAIMER 2>/dev/null; local i; for i in {1..100}; do alive $CLAIMER || return 0; nap; done }

eq() { [[ $1 == "$2" ]] || FAILS+=("$3: got [$1] want [$2]") }
has() { [[ $1 == *"$2"* ]] || FAILS+=("$3: missing [$2]") }
lacks() { [[ $1 != *"$2"* ]] || FAILS+=("$3: unexpected [$2]") }
isyes() { eval "$1" || FAILS+=("$2") }

sampled() { mkline; mkorder A status=pr-open > /dev/null; mkwt A }
gated() { kw $(wt A) order gated A > /dev/null }
verdict() { kw $(wt A) order verdict A $1 notes > /dev/null }
sample() { OUT=$(kw $(wt A) sample A 2>&1) }
clean_change() { sampled; wtcommit A src/a.txt two; gated; verdict PASS }

# a workspace type named trip that logs every call and fails, so a case can tell whether the core asked any type
tripwire() {
  mkdir -p $SB/trip/trip
  print -r -- $'printf "%s\\n" "$*" >> "$TRIP_LOG"\nexit 1' > $SB/trip/trip/trip.zsh
  export KITCHEN_WORKSPACES=$SB/trip TRIP_LOG=$CASE/trip.log
}
# a project that is a directory of two repos, A merging into main and B into testing, and the line that names its type
fakews() {
  WS=$CASE/ws BOOKDIR=$KITCHEN_BOOK/ws
  mkdir -p $WS/src $WS/worktrees $WS/.claude/kitchen $SB/types/fake; touch $WS/.fakeworkspace
  cp $PROJ/.claude/kitchen/house.md $WS/.claude/kitchen/house.md
  cp -R $CASE/origin.git $CASE/originB.git
  git clone -q $CASE/originB.git $CASE/bseed 2>/dev/null
  git -C $CASE/bseed checkout -q -b testing; print testing > $CASE/bseed/src/b.txt
  git -C $CASE/bseed add -A; git -C $CASE/bseed commit -q -m testing; git -C $CASE/bseed push -q origin testing 2>/dev/null
  git clone -q $CASE/origin.git $WS/src/A 2>/dev/null; git clone -q $CASE/originB.git $WS/src/B 2>/dev/null
  cp $HERE/stubs/ws-fake.zsh $SB/types/fake/fake.zsh; print doc > $SB/types/fake/fake.md
  export KITCHEN_WORKSPACES=$SB/types
  kw $WS line add $WS --workspace fake > /dev/null 2>&1
  kw $WS line set ws co-write_after=0 guided_after=0 auto_after=0 > /dev/null 2>&1
}
wsorder() { kw $WS order new $1 status=ready recipe=feature mode=auto 'packages={"A":"main","B":"testing"}' "${@:2}" > /dev/null 2>&1 }
wswt() { # KEY: the order's worktree, A on main and B on testing, each tracking its base
  local p b
  for p in A B; do
    b=main; [[ $p == B ]] && b=testing
    mkdir -p $WS/worktrees/$1/src
    git -C $WS/src/$p worktree add -q -b $1 $WS/worktrees/$1/src/$p origin/$b 2>/dev/null
    git -C $WS/worktrees/$1/src/$p branch -q --set-upstream-to=origin/$b $1
  done
}
wspkg() { print -r -- $WS/worktrees/$1/src/$2 } # KEY REPO
wscommit() { # KEY REPO FILE LINE
  mkdir -p $(wspkg $1 $2)/${3:h}; print -r -- $4 >> $(wspkg $1 $2)/$3
  git -C $(wspkg $1 $2) add -A; git -C $(wspkg $1 $2) commit -q -m "change $3"
}
wsquiet() { # KEY: no repo of the order's worktree has moved since 2020, by its worktree's reflog or its branch's
  local p
  for p in A B; do
    touch -t 202001010000 $(git -C $(wspkg $1 $p) rev-parse --absolute-git-dir)/logs/HEAD \
      $(git -C $(wspkg $1 $p) rev-parse --path-format=absolute --git-common-dir)/logs/refs/heads/$1
  done
}
mkprobe() { # probe ARG...: prints the directory it ran in, its BASE, and its arguments; exits with the number in ./.exit
  print -r -- $'#!/bin/sh\nprintf \'%s %s %s\\n\' "$PWD" "$BASE" "$*"\n[ -f .exit ] && exit "$(cat .exit)"\nexit 0' > $SB/bin/probe
  chmod +x $SB/bin/probe
}

# --- claims -----------------------------------------------------------------------

claim_is_refused_while_another_live_session_holds_the_order() {
  mkline; mkorder A > /dev/null
  spawn_claimer A $CASE/h1
  OUT=$(k order claim A 2>&1); RC=$?
  eq $RC 1 'exit code'
  has "$OUT" 'being worked by another session' 'refusal'
}

claim_records_the_session() {
  mkline; mkorder A > /dev/null
  spawn_claimer A $CASE/h1
  eq "$(<$CASE/h1)" $'ok\n0' 'claim output'
  eq "$(ord A status)" cooking status
  eq "$(ord A phase)" cook phase
  eq "$(ord A pid)" $CLAIMER pid
  eq "$(ord A claimed_from)" ready claimed_from
  eq "$(ord A builder)" sess-A builder
}

claiming_an_auto_order_from_a_user_session_makes_it_guided_for_good() {
  mkline; mkorder A > /dev/null; mkorder M mode=manual > /dev/null
  spawn_claimer A $CASE/h1
  eq "$(ord A mode)" guided 'auto order claimed by the user'
  stop_claimer
  tick
  eq "$(ord A status)" ready 'released'
  eq "$(ord A mode)" guided 'stays guided'
  spawn_claimer M $CASE/h2
  eq "$(ord M mode)" manual 'a manual order stays manual'
}

claim_is_released_when_the_holder_dies() {
  mkline; mkorder A > /dev/null
  spawn_claimer A $CASE/h1
  stop_claimer
  spawn_claimer A $CASE/h2
  eq "$(<$CASE/h2)" $'ok\n0' 'second claim output'
  eq "$(ord A pid)" $CLAIMER 'pid is the new holder'
}

dead_claim_holder_returns_the_order_to_ready() {
  mkline max_cooking=0; mkorder A > /dev/null
  spawn_claimer A $CASE/h1
  stop_claimer
  tick
  eq "$(ord A status)" ready status
  eq "$(ord A pid)" 0 pid
}

a_user_session_is_never_stopped_by_the_scheduler() {
  mkline 'max_minutes={"cook":1}' 'stall_minutes={"cook":1}'; mkorder A > /dev/null
  spawn_claimer A $CASE/h1
  jqedit A '.started -= 100000 | .touched -= 100000'
  tick
  lacks "$OUT" 'sent' 'no signal'
  isyes "alive $CLAIMER" 'the user session lives'
  eq "$(ord A status)" cooking status
}

claiming_an_auto_deployment_at_its_skeleton_keeps_it_auto() {
  mkline; mkorder A catering=E1 stage=skeleton > /dev/null
  spawn_claimer A $CASE/h1
  eq "$(ord A status)" cooking status
  eq "$(ord A mode)" auto 'a skeleton claim leaves the mode'
}

claiming_an_auto_order_held_for_the_users_calls_keeps_it_auto() {
  mkline; mkorder A stage=calls > /dev/null
  spawn_claimer A $CASE/h1
  eq "$(ord A status)" cooking status
  eq "$(ord A mode)" auto 'a claim at the calls stage leaves the mode'
}

a_users_session_on_an_order_held_for_their_calls_is_never_stopped_by_the_scheduler() {
  mkline 'max_minutes={"cook":1}' 'stall_minutes={"cook":1}'; mkorder A stage=calls > /dev/null
  spawn_claimer A $CASE/h1
  jqedit A '.started -= 100000 | .touched -= 100000'
  tick
  lacks "$OUT" 'sent' 'no signal'
  isyes "alive $CLAIMER" 'the user session lives'
  eq "$(ord A status)" cooking status
}

a_users_skeleton_session_on_an_auto_deployment_is_never_stopped_by_the_scheduler() {
  mkline 'max_minutes={"cook":1}' 'stall_minutes={"cook":1}'; mkorder A catering=E1 stage=skeleton > /dev/null
  spawn_claimer A $CASE/h1
  jqedit A '.started -= 100000 | .touched -= 100000'
  tick
  lacks "$OUT" 'sent' 'no signal'
  isyes "alive $CLAIMER" 'the user session lives'
  eq "$(ord A status)" cooking status
}

# --- fire and reap ----------------------------------------------------------------

scheduler_starts_a_cook_session_for_a_ready_order() {
  mkline; mkorder A > /dev/null; mode hang
  tick; wait_calls 1
  has "$OUT" 'proj: cook A' 'tick output'
  local c=$(call 1)
  has $c $PROJ 'runs in the project'
  has $c '/goal Run /kitchen cook A and follow it to its end' 'goal prompt'
  has $c $'--session-id\t' 'session id'
  has $c $'--name\tA' 'session name'
  has $c $'\t0\t-p' 'bg wait ceiling off'
  eq "$(ord A status)" cooking status
  eq "$(ord A phase)" cook phase
  isyes "(( $(ord A pid) > 0 ))" 'pid recorded'
  eq "$(ord A builder)" "$(ord A session)" 'builder is the session'
}

the_scheduler_starts_only_auto_orders() {
  mkline; mode hang
  mkorder M mode=manual > /dev/null; mkorder G mode=guided > /dev/null; mkorder A > /dev/null
  tick; wait_calls 1; nap 20
  eq $(ncalls) 1 'sessions'
  has "$OUT" 'cook A' 'the auto order starts'
  eq "$(ord M status)" ready 'manual waits'
  eq "$(ord G status)" ready 'guided waits'
}

the_scheduler_neither_reads_the_board_nor_starts_an_intake() {
  mkline; mode hang
  mkorder N status=new > /dev/null
  tick; nap 20
  eq $(ncalls) 0 'no session for a new order'
  eq "$(ord N status)" new 'still new'
  isyes "[[ ! -f $TICKET_LOG ]] || [[ $(<$TICKET_LOG) != *ready* ]]" 'the ready query is never run'
  isyes "jq -e '(has(\"rail_depth\") or has(\"models\")) | not' $BOOKDIR/line.json > /dev/null" 'no rail depth or models in line.json'
}

scheduler_settles_the_order_when_the_session_hands_off_a_pr() {
  mkline; mkorder A > /dev/null; setpr 11 OPEN u1; mode pr $(prurl 11)
  tick; wait_dead A
  tick
  eq "$(ord A status)" pr-open status
  eq "$(ord A pid)" 0 pid
  eq "$(ord A pr)" $(prurl 11) pr
  eq "$(ord A retries)" 0 retries
}

# --- capacity ---------------------------------------------------------------------

never_more_than_max_cooking_sessions_per_project() {
  mkline; mode hang
  mkorder A > /dev/null; mkorder B > /dev/null; mkorder C > /dev/null
  tick; wait_calls 2; nap 20
  eq $(ncalls) 2 'sessions after the first pass'
  tick; nap 20
  eq $(ncalls) 2 'sessions after the second pass'
  eq "$(k order list cooking | wc -l | tr -d ' ')" 2 'cooking orders'
  eq "$(ord C status)" ready 'the third waits'
}

orders_with_overlapping_stations_never_run_at_once() {
  mkline max_cooking=3; mode hang
  mkorder A 'station=["src/a"]' > /dev/null
  mkorder B 'station=["src/a/b"]' > /dev/null
  mkorder C 'station=["lib"]' > /dev/null
  tick; wait_calls 2; nap 20
  eq $(ncalls) 2 'sessions'
  eq "$(ord A status)" cooking A
  eq "$(ord B status)" ready 'B overlaps A'
  eq "$(ord C status)" cooking C
}

# --- after chains -----------------------------------------------------------------

an_order_waits_until_everything_in_its_after_list_is_done() {
  mkline; mode hang
  mkorder B status=pr-open > /dev/null
  mkorder A 'after=["B"]' > /dev/null
  tick; nap 20
  eq $(ncalls) 0 'nothing starts while B is open'
  k order set B status=done > /dev/null
  tick; wait_calls 1
  has "$OUT" 'cook A' 'A starts once B is done'
}

a_ready_order_waiting_on_a_dropped_one_shows_as_blocked() {
  mkline
  mkorder B status=86 reason=dropped > /dev/null
  mkorder A 'after=["B"]' > /dev/null
  OUT=$(k status 2>&1)
  has "$OUT" '  BLOCKED   A  waits on dropped B' 'blocked line'
}

# --- retries ----------------------------------------------------------------------

a_dead_session_returns_the_order_to_the_queue_with_a_retry_count() {
  mkline; mkorder A > /dev/null; mode exit
  tick; wait_dead A
  mode hang
  tick
  has "$OUT" 'cook session stopped (unknown); retry 1' 'retry line'
  eq "$(ord A retries)" 1 retries
  eq "$(ord A retry_cause)" unknown cause
}

three_failures_park_the_order() {
  mkline; mkorder A > /dev/null; mode exit
  tick; wait_dead A
  tick; wait_dead A
  tick; wait_dead A
  tick
  eq "$(ord A status)" 86 status
  eq "$(ord A retries)" 3 retries
  local reason=$(ord A reason)
  eq ${reason[1,7]} 'parked:' 'reason prefix'
  eq $(ncalls) 3 'sessions started'
}

retries_count_per_phase_and_reset_when_a_phase_finishes() {
  mkline; mkorder A > /dev/null; mode exit; setpr 21 OPEN u1
  tick; wait_dead A
  tick; wait_dead A
  mode pr $(prurl 21)
  tick; wait_dead A
  eq "$(ord A retries)" 2 'cook retries before the handoff'
  tick
  eq "$(ord A status)" pr-open 'status after handoff'
  eq "$(ord A retries)" 0 'retries reset by the finished cook phase'
  mode exit
  setpr 21 OPEN u2
  jqedit A '.handed -= 100'
  tick; wait_dead A
  tick
  has "$OUT" 'follow session stopped' 'follow stop'
  eq "$(ord A retries)" 1 'follow phase counts from zero'
  eq "$(ord A status)" pr-open 'not parked'
}

a_context_stop_sets_the_context_cause() {
  mkline; mkorder A > /dev/null; mode say 'Prompt is too long'
  tick; wait_dead A
  mode hang
  tick
  eq "$(ord A retry_cause)" context cause
  eq "$(ord A model)" '' 'no model switch'
}

a_connection_stop_sets_the_connection_cause() {
  mkline; mkorder A > /dev/null; mode say 'Error: ECONNRESET'
  tick; wait_dead A
  mode hang
  tick
  eq "$(ord A retry_cause)" connection cause
  eq "$(ord A model)" '' 'no model switch'
}

a_tool_stop_sets_the_tool_cause_and_alternates_the_model() {
  mkline; mkorder A > /dev/null; mode say 'API Error: 400 invalid_request_error'
  tick; wait_dead A
  tick; wait_calls 2
  lacks "$(call 1)" --model 'the first session inherits the user'"'"'s model'
  eq "$(ord A retry_cause)" tool cause
  eq "$(ord A model)" sonnet 'first switch'
  has "$(call 2)" $'--model\tsonnet' 'retry runs on sonnet'
  wait_dead A
  tick; wait_calls 3
  eq "$(ord A model)" opus 'second switch'
  has "$(call 3)" $'--model\topus' 'retry runs on opus'
}

# --- time limits and stalls ---------------------------------------------------------

past_max_minutes_the_session_gets_term_then_kill_a_pass_later() {
  mkline 'max_minutes={"cook":1}' 'stall_minutes={"cook":0}'; mkorder A > /dev/null; mode stubborn
  tick; wait_calls 1
  local pid=$(ord A pid)
  jqedit A '.started -= 120'
  tick
  has "$OUT" 'ran past 1 minutes; sent TERM' 'term line'
  eq "$(ord A stop_cause)" 'stuck: ran past 1 minutes' stop_cause
  nap 20
  isyes "alive $pid" 'a session ignoring TERM is still running'
  jqedit A '.started -= 400'
  tick
  has "$OUT" 'sent KILL' 'kill line'
  wait_dead A
  isyes "! alive $pid" 'KILL ends it'
  mode hang
  tick
  eq "$(ord A retry_cause)" stuck 'retried as stuck'
  eq "$(ord A retries)" 1 retries
  eq "$(ord A model)" sonnet 'stuck switches model'
}

a_paused_line_starts_nothing_but_still_holds_running_sessions_to_their_limits() {
  mkline 'max_minutes={"cook":1}' 'stall_minutes={"cook":0}'; mkorder A > /dev/null; mode stubborn
  tick; wait_calls 1
  k line pause proj > /dev/null
  mkorder B > /dev/null
  jqedit A '.started -= 120'
  tick
  has "$OUT" 'ran past 1 minutes; sent TERM' 'time limit enforced while paused'
  eq "$(ncalls)" 1 'a paused line starts no new session'
  eq "$(ord B status)" ready 'B waits'
}

a_session_with_no_order_update_and_no_commit_is_stopped_at_stall_minutes() {
  mkline 'stall_minutes={"cook":1}'; mkorder A > /dev/null; mkwt A; mode hang
  tick; wait_calls 1
  jqedit A '.started -= 300 | .touched -= 300'
  touch -t 202001010000 $PROJ/.git/worktrees/A/logs/HEAD
  tick
  has "$OUT" 'no progress in 1 minutes; sent TERM' 'stall line'
  eq "$(ord A stop_cause)" 'stuck: no progress in 1 minutes' stop_cause
}

an_order_update_keeps_a_quiet_session_alive() {
  mkline 'stall_minutes={"cook":1}'; mkorder A > /dev/null; mkwt A; mode hang
  tick; wait_calls 1
  local pid=$(ord A pid)
  jqedit A '.started -= 300 | .touched -= 300'
  touch -t 202001010000 $PROJ/.git/worktrees/A/logs/HEAD
  k order set A step=1 > /dev/null
  tick
  lacks "$OUT" 'sent' 'no signal'
  isyes "alive $pid" 'session still running'
}

a_worktree_commit_keeps_a_quiet_session_alive() {
  mkline 'stall_minutes={"cook":1}'; mkorder A > /dev/null; mkwt A; mode hang
  tick; wait_calls 1
  local pid=$(ord A pid)
  jqedit A '.started -= 300 | .touched -= 300'
  touch -t 202001010000 $PROJ/.git/worktrees/A/logs/HEAD
  wtcommit A src/a.txt work
  tick
  lacks "$OUT" 'sent' 'no signal'
  isyes "alive $pid" 'session still running'
}

# --- usage-limit backoff ------------------------------------------------------------

a_rate_limited_session_holds_the_line_until_the_limit_lifts() {
  mkline; mkorder A > /dev/null; mode say 'API Error: 429 rate limited'
  tick; wait_dead A
  tick
  has "$OUT" 'A hit a usage limit' 'limit line'
  eq "$(ord A status)" ready status
  eq "$(ord A retries)" 0 'a limit is not a retry'
  isyes "(( $(ord A retry_after) > EPOCHSECONDS ))" 'order waits'
  isyes "(( $(jq -r .retry_after $BOOKDIR/line.json) > EPOCHSECONDS ))" 'line waits'
  mkorder B > /dev/null
  tick; nap 20
  eq $(ncalls) 1 'nothing new starts while the line waits'
  lineedit '.retry_after = 0'; jqedit A '.retry_after = 0'
  mode hang
  tick; wait_calls 2
  has "$OUT" 'cook' 'sessions start again'
}

# --- follow-ups -------------------------------------------------------------------

a_pr_whose_last_update_changed_wakes_a_follow_session() {
  mkline; mode hang; mkpr A 7
  setpr 7 OPEN u2
  tick; wait_calls 1
  has "$OUT" 'proj: follow A' 'follow line'
  has "$(call 1)" '/kitchen cook A' 'follow runs the cook command'
  has "$(call 1)" $'--session-id\t' 'fresh session without a transcript'
  eq "$(ord A phase)" follow phase
}

a_follow_session_on_a_guided_order_is_held_to_its_time_limit() {
  mkline 'max_minutes={"follow":1}' 'stall_minutes={"follow":0}'; mode stubborn; mkpr A 7
  k order set A mode=guided phase=cook > /dev/null
  setpr 7 OPEN u2
  tick; wait_calls 1
  eq "$(ord A phase)" follow phase
  jqedit A '.started -= 120'
  tick
  has "$OUT" 'ran past 1 minutes; sent TERM' 'the scheduler holds a follow-up whatever the mode'
}

a_follow_session_resumes_the_builder_session_when_its_transcript_exists() {
  mkline; mode hang; mkpr A 7
  mkdir -p $HOME/.claude/projects/p; touch $HOME/.claude/projects/p/bld-7.jsonl
  k order set A builder=bld-7 > /dev/null
  setpr 7 OPEN u2
  tick; wait_calls 1
  has "$(call 1)" $'--resume\tbld-7' 'resume'
  lacks "$(call 1)" $'--name' 'no new name'
  eq "$(ord A session)" bld-7 session
}

a_follow_session_never_resumes_the_conversation_of_an_order_a_user_claimed() {
  mkline; mode hang; mkpr A 7
  mkdir -p $HOME/.claude/projects/p; touch $HOME/.claude/projects/p/bld-7.jsonl
  k order set A builder=bld-7 mode=guided > /dev/null
  setpr 7 OPEN u2
  tick; wait_calls 1
  has "$(call 1)" $'--session-id\t' 'a fresh session'
  lacks "$(call 1)" '--resume' 'no resume'
  eq "$(ord A builder)" bld-7 'builder stays recorded for kitchen review'
  isyes "[[ $(ord A session) != bld-7 ]]" 'the order runs in the new session'
}

an_unchanged_pr_does_not_wake_a_session() {
  mkline; mode hang; mkpr A 7
  tick; nap 20
  eq $(ncalls) 0 sessions
  eq "$(ord A pid)" 0 pid
}

a_merged_pr_closes_the_order_and_clears_its_worktree() {
  mkline; mkpr A 7; mkwt A
  setpr 7 MERGED u2
  tick
  eq "$(ord A status)" done status
  has "$(<$TICKET_LOG)" "move A merged Merged: $(prurl 7)" 'ticket moved with the merged moment'
  isyes "[[ ! -d $(wt A) ]]" 'worktree removed'
  isyes "[[ -f $VAULT_LOG ]]" 'vault synced before removal'
}

a_closed_pr_drops_the_order() {
  mkline; mkpr A 7
  setpr 7 CLOSED u2
  tick
  eq "$(ord A status)" 86 status
  has "$(ord A reason)" "PR closed without merging: $(prurl 7)" reason
}

# --- verify phase -----------------------------------------------------------------

verify_phase_starts_a_session_that_did_not_write_the_change() {
  mkline; mode hang; mkpr A 3
  k order verify A > /dev/null
  tick; wait_calls 1
  has "$OUT" 'proj: verify A' 'verify line'
  has "$(call 1)" '/kitchen taste verify A' 'verify command'
  eq "$(ord A phase)" verify phase
}

a_verify_session_that_stops_without_a_verdict_is_retried() {
  mkline; mkpr A 3
  k order verify A > /dev/null
  mode exit
  tick; wait_dead A
  mode hang
  tick
  has "$OUT" 'verify session stopped' 'stop line'
  eq "$(ord A retries)" 1 retries
  eq "$(ord A verify)" true 'still waiting for its verdict'
}

a_verdict_wakes_a_follow_session() {
  mkline; mkpr A 3
  k order verify A > /dev/null
  mode verdict
  tick; wait_dead A
  mode hang
  tick; wait_calls 2
  eq "$(ord A verdict)" PASS verdict
  eq "$(ord A verify)" false verify
  has "$OUT" 'proj: follow A' 'follow line'
  eq "$(ord A phase)" follow phase
}

# --- sample -----------------------------------------------------------------------

sample_says_rebase_when_the_base_changed_a_file_the_branch_changed() {
  sampled; wtcommit A src/a.txt two; advance_base src/a.txt
  sample; eq "$OUT" rebase output
}

sample_says_rebase_when_the_base_changed_a_check() {
  sampled; wtcommit A src/a.txt two; advance_base .github/workflows/ci.yml
  sample; eq "$OUT" rebase output
}

sample_says_regate_when_the_change_was_never_gated_even_after_an_unrelated_base_move() {
  sampled; wtcommit A src/a.txt two; advance_base other.txt
  sample; eq "$OUT" regate output
}

sample_says_fix_when_the_verdict_for_this_change_is_fail() {
  sampled; wtcommit A src/a.txt two; gated; verdict FAIL
  sample; eq "$OUT" fix output
}

sample_says_fix_and_counts_a_round_when_the_verdict_has_notes() {
  sampled; wtcommit A src/a.txt two; gated; verdict PASS+NOTES
  sample; eq "$OUT" fix output
  eq "$(ord A verify_fails)" 1 'a notes round counts toward the three-round park'
}

sample_says_verify_when_no_verdict_covers_this_change() {
  sampled; wtcommit A src/a.txt two; gated
  sample; eq "$OUT" verify output
}

sample_says_review_for_a_path_that_waits_for_the_user() {
  sampled; wtcommit A secrets/key.txt x; gated; verdict PASS
  sample
  eq "$OUT" review output
  eq "$(ord A review)" true review
  has "$(ord A review_why)" 'project rule: secrets/key.txt' reason
}

sample_reads_an_escaped_pipe_in_a_path_as_alternation() {
  sampled; wtcommit A keys/k.txt x; gated; verdict PASS
  sample
  eq "$OUT" review output
  has "$(ord A review_why)" 'project rule: keys/k.txt' reason
}

sample_leaves_an_extra_effort_path_that_does_not_wait_to_the_verdict() {
  sampled; wtcommit A slow/s.txt x; gated; verdict PASS
  sample
  eq "$OUT" no output
  eq "$(ord A review)" false review
}

sample_holds_every_change_while_a_path_row_is_unreadable() {
  git clone -q $CASE/origin.git $CASE/other 2>/dev/null
  print -r -- $'# House rules\n\n### Critical paths\n\n| Path | What it is | Extra effort | Waits for me |\n|---|---|---|---|\n| `^secrets/` | credentials | no | yes |\n| `^(a|b)/` | bare pipe | no | yes |\n\n### Questions that hold a PR\n\n### Docs\n- none' > $CASE/other/.claude/kitchen/house.md
  git -C $CASE/other commit -q -am 'bare pipe'
  git -C $CASE/other push -q origin main 2>/dev/null
  git -C $PROJ fetch -q origin
  sampled; wtcommit A secrets/key.txt x; gated; verdict PASS
  sample
  eq "$OUT" review output
  has "$(ord A review_why)" 'project rule: secrets/key.txt' 'the readable row still holds its path'
  has "$(ord A review_why)" 'a Critical paths row kitchen cannot read' 'the unreadable row holds the change'
}

sample_says_review_for_a_deleted_test() {
  sampled; wtdelete A tests/foo_test.py; gated; verdict PASS
  sample
  eq "$OUT" review output
  has "$(ord A review_why)" 'deletes a test: tests/foo_test.py' reason
}

sample_says_review_for_an_added_line_that_silences_a_check() {
  sampled; wtcommit A src/a.txt '// eslint-disable-next-line'; gated; verdict PASS
  sample
  eq "$OUT" review output
  has "$(ord A review_why)" 'silences a check: // eslint-disable-next-line' reason
}

sample_says_review_for_a_changed_check() {
  sampled; wtcommit A .eslintrc.json '{}'; gated; verdict PASS
  sample
  eq "$OUT" review output
  has "$(ord A review_why)" 'changes a check: .eslintrc.json' reason
}

sample_says_review_for_a_review_when_reason_in_the_verdict() {
  sampled; wtcommit A src/a.txt two; gated
  kw $(wt A) order verdict A PASS notes 'the change moves money' > /dev/null
  sample
  eq "$OUT" review output
  has "$(ord A review_why)" 'judged: the change moves money' reason
}

sample_says_review_for_an_order_flagged_at_intake() {
  sampled; k order set A review=true 'review_why=looks and feels' > /dev/null
  wtcommit A src/a.txt two; gated; verdict PASS
  sample
  eq "$OUT" review output
  eq "$(ord A review_why)" 'looks and feels' reason
}

sample_leaves_a_waiting_path_inside_the_orders_station_to_intake() {
  mkline; mkorder A status=pr-open 'station=["secrets/"]' > /dev/null; mkwt A
  wtcommit A secrets/key.txt x; gated; verdict PASS
  sample
  eq "$OUT" no output
  eq "$(ord A review)" false review
}

sample_says_no_for_a_clean_auto_change_whatever_else_waits() {
  clean_change
  mkorder B status=pr-open review=true pr_opened=$(today_str) > /dev/null
  sample
  eq "$OUT" no output
  eq "$(ord A review)" false 'no daily sample'
  eq "$(ord A sample)" '' 'no sample field'
}

sample_says_review_for_a_manual_order_even_after_the_user_approved_it() {
  clean_change
  k order set A mode=manual > /dev/null
  sample
  eq "$OUT" review output
  has "$(ord A review_why)" 'manual order' reason
  kw $(wt A) order approve A HEAD > /dev/null
  sample
  eq "$OUT" review 'approval does not release a manual order'
}

sample_flags_a_manual_order_for_review_even_while_it_reports_fix_or_verify() {
  sampled; k order set A mode=manual > /dev/null
  wtcommit A src/a.txt two; gated
  sample
  eq "$OUT" verify 'no verdict yet'
  eq "$(ord A review)" true 'review set while a verdict is missing'
  has "$(ord A review_why)" 'manual order' 'reason recorded'
  verdict FAIL
  sample
  eq "$OUT" fix 'a failed verdict still prints fix'
  eq "$(ord A review)" true 'review still set'
  eq "$(ord A review_why)" 'manual order: the user merges it' 'reason recorded once'
}

the_users_approval_survives_a_clean_rebase() {
  sampled; wtcommit A secrets/key.txt x; gated; verdict PASS
  kw $(wt A) order approve A HEAD > /dev/null
  sample; eq "$OUT" no 'approved change'
  advance_base other.txt
  git -C $(wt A) fetch -q origin
  git -C $(wt A) rebase -q origin/main
  sample; eq "$OUT" no 'after a clean rebase'
}

the_users_approval_lapses_when_the_patch_changes() {
  sampled; wtcommit A secrets/key.txt x; gated; verdict PASS
  kw $(wt A) order approve A HEAD > /dev/null
  wtcommit A secrets/key.txt y
  sample; eq "$OUT" regate 'changed patch is not the gated one'
  gated; verdict PASS
  sample; eq "$OUT" review 'approval no longer covers it'
}

# --- decisions, status, catches -----------------------------------------------------

a_decision_is_logged_with_its_evidence_and_shown_once_under_a_merge_that_never_waited_for_review() {
  mkline; mkorder A status=done pr=$(prurl 1) summary=shipped > /dev/null
  mkorder R status=done pr=$(prurl 2) summary=reviewed review=true > /dev/null
  k decide A 'chose X: because Y' 'f.py:1' > /dev/null
  k decide R 'chose Z: because W' 'g.py:2' > /dev/null
  eq "$(ord A decisions | jq -r '.[0].what + "|" + .[0].evidence')" 'chose X: because Y|f.py:1' 'logged'
  OUT=$(k status 2>&1)
  has "$OUT" $'  merged    A  shipped\n    decided   chose X: because Y  (f.py:1)' 'the call sits under its merge'
  lacks "$OUT" 'chose Z' 'a merge the user reviewed lists no calls'
  lacks "$OUT" $'\n  decided' 'no standalone decided line'
  OUT=$(k status 2>&1)
  lacks "$OUT" 'chose X' 'shown once'
}

a_call_the_user_made_is_logged_as_theirs_and_left_out_of_the_calls_made_alone() {
  mkline; mkorder A status=done pr=$(prurl 1) summary=shipped > /dev/null
  k decide A 'chose X: because Y' 'f.py:1' > /dev/null
  k decide A 'wire shape: one limit per answer' 'recommended a limit per stop' --chef changed > /dev/null
  k decide A 'partial file: deleted' 'recommended deleting it' --chef kept > /dev/null
  eq "$(ord A decisions | jq -r '.[1].by + "|" + .[1].took')" 'chef|changed' 'the changed call'
  eq "$(ord A decisions | jq -r '.[2].by + "|" + .[2].took')" 'chef|kept' 'the kept call'
  eq "$(ord A decisions | jq -r '.[0] | has("by")')" false 'a call made alone carries no owner'
  eq "$(k calls)" 'calls 2 in 1 orders, changed 1' 'the count'
  OUT=$(k status 2>&1)
  has "$OUT" 'decided   chose X' 'the call made alone is shown'
  lacks "$OUT" 'wire shape' 'the user already made theirs'
  OUT=$(k decide A 'x: y' 'z' --chef maybe 2>&1); RC=$?
  eq $RC 1 'an unknown outcome is refused'
}

status_lists_orders_held_for_the_users_calls_first() {
  mkline
  mkorder G mode=guided > /dev/null
  mkorder S mode=guided catering=E1 stage=skeleton > /dev/null
  mkorder H stage=calls 'question=2 calls wait for you' > /dev/null
  OUT=$(k status 2>&1)
  local -a rows=( ${(M)${(f)OUT}:#  READY *} )
  eq $#rows 3 'ready rows'
  has $rows[1] 'READY     H  calls  approved' 'the held order first, whatever its mode'
  has $rows[1] '2 calls wait for you' 'what waits'
  has $rows[2] 'READY     S  skeleton' 'then the skeleton'
  has $rows[3] 'READY     G  guided' 'then guided'
}

status_never_repeats_what_it_showed_even_from_the_same_second() {
  mkline
  mkorder A status=86 reason=nope > /dev/null
  mkorder B status=done pr=$(prurl 1) summary=shipped > /dev/null
  k decide B 'chose X: because Y' 'f.py:1' > /dev/null
  k promoted some-class T-1 > /dev/null
  k filed A T-9 'cleanup needed' > /dev/null
  OUT=$(k status 2>&1)
  has "$OUT" '  dropped   A  nope' 'first look shows the drop'
  has "$OUT" 'chose X' 'first look shows the decision'
  has "$OUT" '  promoted  some-class -> T-1' 'first look shows the promotion'
  has "$OUT" '  filed     A  T-9  cleanup needed' 'first look shows the filed ticket'
  local look=$(<$BOOKDIR/.last-look)
  jqedit A '.updated = $l | .filed[0].at = $l' --arg l $look
  jqedit B '.updated = $l' --arg l $look
  OUT=$(k status 2>&1)
  lacks "$OUT" '  dropped   A' 'an event stamped with the look itself is not repeated'
  lacks "$OUT" 'chose X' 'nor its decision'
  lacks "$OUT" '  filed' 'nor its filed ticket'
  lacks "$OUT" '  promoted' 'a promotion shows once, not all day'
}

status_shows_only_what_is_new_and_marks_it_seen() {
  mkline
  mkorder A status=done pr=$(prurl 1) summary=shipped > /dev/null
  mkorder B status=86 reason=nope > /dev/null
  mkorder P status=pr-open review=true pr=$(prurl 2) > /dev/null
  OUT=$(k status 2>&1)
  has "$OUT" '  merged    A  shipped' 'merged'
  has "$OUT" '  dropped   B  nope' 'dropped'
  has "$OUT" '  REVIEW    P' 'review'
  isyes "[[ -f $BOOKDIR/.last-look ]]" 'look recorded under the project'
  isyes "[[ ! -f $KITCHEN_BOOK/.last-look ]]" 'no look spanning projects'
  jqedit A '.updated = "2000-01-01T00:00:00"'; jqedit B '.updated = "2000-01-01T00:00:00"'
  mkorder C status=86 reason=late > /dev/null
  OUT=$(k status 2>&1)
  has "$OUT" '  dropped   C  late' 'new drop'
  lacks "$OUT" '  merged    A' 'seen merge'
  lacks "$OUT" '  dropped   B' 'seen drop'
  has "$OUT" '  REVIEW    P' 'what waits on the user stays'
}

a_manual_orders_open_pr_always_shows_as_review_in_status() {
  mkline
  mkorder M mode=manual status=pr-open pr=$(prurl 1) > /dev/null
  mkorder G mode=guided status=pr-open pr=$(prurl 2) > /dev/null
  eq "$(ord M review)" false 'the manual order was never flagged'
  OUT=$(k status 2>&1)
  has "$OUT" '  REVIEW    M' 'manual PR waits on the user'
  lacks "$OUT" '  REVIEW    G' 'a guided PR with no flag does not'
}

status_shows_only_the_current_project_and_stops_outside_one() {
  mkline; mkorder A status=86 reason=mine > /dev/null
  git clone -q $CASE/origin.git $CASE/other 2>/dev/null
  ( cd $CASE/other && zsh $KITCHEN line add $CASE/other > /dev/null && zsh $KITCHEN order new Z status=86 reason=theirs > /dev/null )
  OUT=$(k status 2>&1)
  has "$OUT" '  dropped   A  mine' 'this project'
  lacks "$OUT" 'theirs' 'not the other project'
  lacks "$OUT" 'other' 'no other project header'
  mkdir $CASE/nowhere
  OUT=$(kw $CASE/nowhere status 2>&1); RC=$?
  eq $RC 1 'exit code outside a project'
  has "$OUT" 'no registered project' 'message'
  isyes "[[ ! -f $CASE/book/other/.last-look ]]" 'the other project was not marked seen'
}

order_list_shows_only_the_current_project_and_stops_outside_one() {
  mkline; mkorder A status=86 reason=mine > /dev/null
  git clone -q $CASE/origin.git $CASE/other 2>/dev/null
  ( cd $CASE/other && zsh $KITCHEN line add $CASE/other > /dev/null && zsh $KITCHEN order new Z status=86 reason=theirs > /dev/null )
  OUT=$(k order list 2>&1)
  has "$OUT" $'proj\tA\t86\tmine' 'this project'
  lacks "$OUT" Z 'not the other project'
  mkdir $CASE/nowhere
  OUT=$(kw $CASE/nowhere order list 2>&1); RC=$?
  eq $RC 1 'exit code outside a project'
  has "$OUT" 'no registered project' 'message'
}

status_lists_ready_manual_then_co_write_then_guided_orders_with_when_they_were_approved() {
  mkline
  mkorder G mode=guided > /dev/null; mkorder C mode=co-write > /dev/null; mkorder M1 mode=manual > /dev/null; mkorder A > /dev/null
  OUT=$(k status 2>&1)
  local -a rows=( ${(M)${(f)OUT}:#  READY *} )
  eq $#rows 3 'auto orders are not listed'
  has $rows[1] 'READY     M1  manual  approved 20' 'manual first'
  has $rows[2] 'READY     C  co-write  approved 20' 'then co-write'
  has $rows[3] 'READY     G  guided  approved 20' 'then guided'
  lacks "$OUT" QUEUED 'no queue row'
}

a_class_is_promoted_on_its_second_sighting() {
  mkline; mkorder A > /dev/null
  OUT=$(k catch A taster1 cls1 note1 2>&1)
  eq "$OUT" 'count=1' 'first sighting'
  OUT=$(k catch A taster1 cls1 note2 2>&1)
  has "$OUT" 'count=2' 'count'
  has "$OUT" promote 'promotion due'
  eq "$(<$BOOKDIR/due.tsv)" $'cls1\tpromote\t2' 'due row'
  has "$(k status 2>&1)" '  PROMOTE   cls1  2 catches' 'status lists it'
  eq "$(k classes)" cls1 classes
  k promoted cls1 - > /dev/null
  lacks "$(k status 2>&1)" PROMOTE 'answered promotion'
}

a_class_is_promoted_on_the_users_first_sighting() {
  mkline; mkorder A > /dev/null
  OUT=$(k catch A taster1 cls1 note1 --chef 2>&1)
  has "$OUT" 'count=1' count
  has "$OUT" promote 'promotion due'
}

a_catch_climbs_once_the_promotion_shipped() {
  mkline; mkorder A > /dev/null
  mkorder T9 status=pr-open > /dev/null
  k promoted cls1 T9 > /dev/null
  OUT=$(k catch A taster1 cls1 note1 2>&1)
  lacks "$OUT" climb 'promotion not shipped yet'
  k order set T9 status=done > /dev/null
  OUT=$(k catch A taster1 cls1 note2 2>&1)
  has "$OUT" 'climb T9' 'climb'
}

a_catch_without_an_order_is_recorded_in_the_project() {
  mkline
  OUT=$(k catch - taster1 cls1 note1 2>&1)
  eq "$OUT" 'count=1' count
  has "$(<$BOOKDIR/catches.tsv)" $'\t-\ttaster1\tcls1\tnote1\tline' 'row'
}

# --- modes ------------------------------------------------------------------------

an_order_starts_as_manual() {
  mkline
  k order new X > /dev/null
  eq "$(ord X mode)" manual mode
}

a_project_starts_manual_only_and_refuses_a_locked_mode() {
  k line add $PROJ > /dev/null
  eq "$(k modes)" manual 'unlocked modes'
  OUT=$(k order new X mode=co-write 2>&1); RC=$?
  eq $RC 1 'exit code'
  has "$OUT" 'co-write is locked: 0 of 2 merged manual orders (co-write_after)' 'unmet threshold'
  OUT=$(k order new X mode=guided 2>&1); RC=$?
  eq $RC 1 'guided refused'
  has "$OUT" 'guided is locked: co-write is locked: 0 of 2 merged manual orders (co-write_after)' 'guided waits on co-write'
  k order new X > /dev/null
  OUT=$(k order set X mode=auto 2>&1); RC=$?
  eq $RC 1 'auto refused'
  has "$OUT" 'auto is locked: guided is locked: co-write is locked: 0 of 2 merged manual orders (co-write_after)' 'auto waits on guided'
  OUT=$(k order set X mode=sideways 2>&1); RC=$?
  eq $RC 1 'unknown mode refused'
}

a_recipe_that_ships_no_code_runs_guided_in_a_manual_only_project() {
  k line add $PROJ > /dev/null
  local r
  for r in investigation prototype eval runtime-forensics trace-forensics multi-phase-plan; do
    OUT=$(k order new N-$r recipe=$r mode=guided 2>&1); RC=$?
    eq $RC 0 "$r made guided"
    eq "$(ord N-$r mode)" guided "$r mode"
  done
  k order new S recipe=investigation > /dev/null
  OUT=$(k order set S mode=guided 2>&1); RC=$?
  eq $RC 0 'guided set later on a no-code order'
  OUT=$(k order new A recipe=investigation mode=auto 2>&1); RC=$?
  eq $RC 1 'auto stays locked'
  OUT=$(k order new F recipe=feature mode=guided 2>&1); RC=$?
  eq $RC 1 'a recipe that ships code stays locked'
  k order new G recipe=feature > /dev/null
  OUT=$(k order set G recipe=investigation mode=guided 2>&1); RC=$?
  eq $RC 0 'the recipe set in the same command counts'
}

enforce_and_change_a_skill_run_only_guided() {
  k line add $PROJ > /dev/null
  local r
  for r in enforce change-a-skill; do
    OUT=$(k order new G-$r recipe=$r mode=guided 2>&1); RC=$?
    eq $RC 0 "$r guided in a manual-only project"
    OUT=$(k order new M-$r recipe=$r mode=manual 2>&1); RC=$?
    eq $RC 1 "$r manual refused"
    has "$OUT" "$r runs only guided" "$r refusal names it"
    OUT=$(k order new D-$r recipe=$r 2>&1); RC=$?
    eq $RC 1 "$r with the default manual mode refused"
  done
  mkline
  OUT=$(k order new A recipe=enforce mode=auto 2>&1); RC=$?
  eq $RC 1 'auto refused where auto is unlocked'
  k order new X recipe=feature mode=auto > /dev/null
  OUT=$(k order set X recipe=enforce 2>&1); RC=$?
  eq $RC 1 'a recipe change onto an auto order refused'
  OUT=$(k order set X recipe=enforce mode=guided 2>&1); RC=$?
  eq $RC 0 'a recipe change with mode guided'
}

order_new_validates_before_it_writes_so_a_retry_is_not_blocked() {
  k line add $PROJ > /dev/null
  OUT=$(k order new X mode=guided 2>&1); RC=$?
  eq $RC 1 'locked mode refused'
  isyes "[[ ! -e $BOOKDIR/orders/X.json ]]" 'no stray order'
  OUT=$(k order new X mode=sideways 2>&1); RC=$?
  eq $RC 1 'unknown mode refused'
  isyes "[[ ! -e $BOOKDIR/orders/X.json ]]" 'no stray order for an unknown mode'
  OUT=$(k order new X 'review=maybe' 2>&1); RC=$?
  eq $RC 1 'a JSON field that is not JSON refused'
  OUT=$(k order new X notakv 2>&1); RC=$?
  eq $RC 1 'a bare word refused'
  isyes "[[ ! -e $BOOKDIR/orders/X.json ]]" 'no stray order for a bad field'
  k order new X mode=manual > /dev/null
  eq "$(ord X mode)" manual 'the retry creates the order'
}

share_counts_manual_and_co_write_orders_made_ready_in_the_last_two_weeks() {
  mkline
  mkorder A mode=manual > /dev/null; mkorder B mode=co-write > /dev/null; mkorder C > /dev/null; mkorder G mode=guided > /dev/null
  mkorder D mode=manual > /dev/null; jqedit D '.ready_at = "2000-01-01T00:00:00"'
  k order new N > /dev/null
  OUT=$(k share 2>&1)
  has "$OUT" 'manual or co-write 2 of 4 orders made ready since' 'two of the four recent ready orders are manual or co-write'
}

orders_merged_before_modes_existed_unlock_nothing() {
  k line add $PROJ > /dev/null
  local i
  for i in 1 2 3 4 5 6; do k order new L$i status=done pr=$(prurl $i) > /dev/null; jqedit L$i 'del(.mode)'; done
  eq "$(k modes)" manual 'six merges with no mode leave the project manual-only'
}

two_manual_merges_unlock_co_write_three_co_write_merges_unlock_guided_and_five_guided_merges_unlock_auto() {
  k line add $PROJ > /dev/null
  local i
  k order new M1 status=done earned=true pr=$(prurl 1) > /dev/null
  k order new open1 status=pr-open pr=$(prurl 99) > /dev/null
  eq "$(k modes)" manual '1 merged manual order'
  k order new M2 status=done earned=true pr=$(prurl 2) > /dev/null
  eq "$(k modes)" $'manual\nco-write' '2 merged manual orders'
  for i in 1 2; do k order new C$i status=done earned=true pr=$(prurl 1$i) mode=co-write > /dev/null; done
  eq "$(k modes)" $'manual\nco-write' '2 merged co-write orders'
  OUT=$(k order set open1 mode=guided 2>&1); RC=$?
  eq $RC 1 'guided still locked'
  has "$OUT" 'guided is locked: 2 of 3 merged co-write orders (guided_after)' 'unmet threshold'
  k order new C3 status=done earned=true pr=$(prurl 13) mode=co-write > /dev/null
  eq "$(k modes)" $'manual\nco-write\nguided' '3 merged co-write orders'
  for i in 1 2 3 4; do k order new G$i status=done earned=true pr=$(prurl 2$i) mode=guided > /dev/null; done
  eq "$(k modes)" $'manual\nco-write\nguided' '4 merged guided orders'
  OUT=$(k order set open1 mode=auto 2>&1); RC=$?
  eq $RC 1 'auto still locked'
  has "$OUT" 'auto is locked: 4 of 5 merged guided orders (auto_after)' 'unmet threshold'
  k order new G5 status=done earned=true pr=$(prurl 25) mode=guided > /dev/null
  eq "$(k modes)" $'manual\nco-write\nguided\nauto' '5 merged guided orders'
  k order set open1 mode=auto > /dev/null
  eq "$(ord open1 mode)" auto 'auto accepted'
}

a_threshold_set_on_the_line_replaces_its_default() {
  k line add $PROJ > /dev/null
  k line set proj co-write_after=0 guided_after=1 > /dev/null
  eq "$(k modes)" $'manual\nco-write' 'co-write unlocked with no merge'
  k order new C1 status=done earned=true pr=$(prurl 1) mode=co-write > /dev/null
  eq "$(k modes)" $'manual\nco-write\nguided' 'one merged co-write order unlocks guided'
}

an_unstamped_or_unearned_merge_counts_toward_no_unlock() {
  k line add $PROJ > /dev/null
  local i
  for i in 1 2 3 4 5 6; do k order new G$i status=done pr=$(prurl $i) > /dev/null; jqedit G$i '.mode = "guided"'; done
  eq "$(k modes)" manual 'six merged guided orders with no stamp and no manual merge'
  k order new X > /dev/null
  OUT=$(k order set X mode=auto 2>&1); RC=$?
  eq $RC 1 'auto refused'
  has "$OUT" 'auto is locked: guided is locked: co-write is locked: 0 of 2 merged manual orders (co-write_after)' 'names the lowest lock'
  for i in 1 2; do k order new M$i status=done earned=true pr=$(prurl 1$i) > /dev/null; done
  for i in 1 2 3; do k order new C$i status=done pr=$(prurl 3$i) > /dev/null; jqedit C$i '.mode = "co-write"'; done
  eq "$(k modes)" $'manual\nco-write' 'two earned manual orders, co-write orders unstamped'
  for i in 1 2 3; do jqedit C$i '.earned = true'; done
  eq "$(k modes)" $'manual\nco-write\nguided' 'three earned co-write orders, guided orders unstamped'
  for i in 1 2 3 4 5; do jqedit G$i '.earned = false'; done
  eq "$(k modes)" $'manual\nco-write\nguided' 'five unearned guided orders'
  for i in 1 2 3 4 5; do jqedit G$i '.earned = true'; done
  eq "$(k modes)" $'manual\nco-write\nguided\nauto' 'earned manual, co-write and guided orders'
}

closing_an_order_stamps_whether_its_mode_was_unlocked_then() {
  k line add $PROJ > /dev/null
  k order new A > /dev/null
  k order close A > /dev/null
  eq "$(ord A earned)" true 'manual is always unlocked'
  k order new B > /dev/null
  jqedit B '.mode = "guided"'
  k order close B > /dev/null
  eq "$(ord B earned)" false 'guided closed while locked'
  k order new W > /dev/null
  jqedit W '.mode = "co-write"'
  k order close W > /dev/null
  eq "$(ord W earned)" false 'co-write closed while locked'
  k order new C recipe=catering > /dev/null
  k order close C > /dev/null
  eq "$(ord C earned)" false 'a catering order earns nothing'
}

order_next_prints_the_oldest_ready_order_of_a_mode_by_when_it_became_ready() {
  mkline
  k order new LATE recipe=feature mode=manual > /dev/null
  mkorder EARLY mode=manual > /dev/null
  mkorder G mode=guided > /dev/null
  mkorder C mode=co-write > /dev/null
  mkorder A > /dev/null
  nap 5
  k order set LATE status=ready > /dev/null
  isyes "[[ $(ord LATE ready_at) > $(ord EARLY ready_at) ]]" 'stamped when it became ready, not when created'
  local stamp=$(ord EARLY ready_at)
  k order set EARLY status=ready > /dev/null
  eq "$(ord EARLY ready_at)" $stamp 'stamped once'
  eq "$(k order next manual)" EARLY 'manual'
  eq "$(k order next guided)" G 'guided'
  eq "$(k order next co-write)" C 'co-write'
  k order set EARLY status=cooking > /dev/null
  eq "$(k order next manual)" LATE 'a claimed order is not next'
}

order_next_exits_non_zero_when_nothing_waits_and_refuses_auto() {
  mkline; mkorder A > /dev/null
  OUT=$(k order next manual 2>&1); RC=$?
  eq $RC 1 'exit code'
  has "$OUT" 'no ready manual order' 'message'
  OUT=$(k order next auto 2>&1); RC=$?
  eq $RC 1 'auto refused'
}

# --- mode overrides ---------------------------------------------------------------

overrides_lists_this_projects_orders_with_a_mode_override_oldest_first_and_status_never_shows_them() {
  mkline
  mkorder B > /dev/null; mkorder A > /dev/null; mkorder C > /dev/null
  print -r -- $'kept manual:\nthe user asked' > $CASE/why
  k order set A mode_override=@$CASE/why > /dev/null
  k order set B 'mode_override=guided asked for, manual chosen' > /dev/null
  git clone -q $CASE/origin.git $CASE/other 2>/dev/null
  ( cd $CASE/other && zsh $KITCHEN line add $CASE/other > /dev/null && zsh $KITCHEN order new Z mode_override=theirs > /dev/null )
  eq "$(k overrides)" $'B  guided asked for, manual chosen\nA  kept manual: the user asked' 'one line each, oldest first, this project only'
  OUT=$(k status 2>&1)
  lacks "$OUT" 'kept manual' 'not in status'
  lacks "$OUT" 'decided' 'not among decisions'
}

# --- retired paths ----------------------------------------------------------------

order_withdraw_and_the_review_queue_are_gone() {
  mkline; mkorder A > /dev/null
  OUT=$(k order withdraw A 'which way?' 2>&1); RC=$?
  eq $RC 1 'withdraw exit code'
  eq "$(ord A status)" ready 'nothing moved'
  OUT=$(k signoff A answer 2>&1); RC=$?
  eq $RC 1 'signoff refuses an order that was not dropped'
  has "$OUT" 'A is ready, not dropped' 'message'
}

signoff_brings_back_a_dropped_order() {
  mkline; mkorder A status=86 reason=nope > /dev/null
  k signoff A 'do it after all' > /dev/null
  eq "$(ord A status)" ready status
  eq "$(ord A answer)" 'do it after all' answer
  eq "$(ord A retries)" 0 retries
}

# --- filed tickets ------------------------------------------------------------------

a_filed_follow_up_ticket_is_stored_on_the_order_and_shown_in_status() {
  mkline; mkorder A status=pr-open > /dev/null
  k filed A T-9 'the retry path needs its own change' > /dev/null
  k filed A T-10 'second' > /dev/null
  eq "$(ord A filed | jq -r 'map(.ticket) | join(",")')" T-9,T-10 'stored in order'
  eq "$(ord A filed | jq -r '.[0].why')" 'the retry path needs its own change' why
  OUT=$(k status 2>&1)
  has "$OUT" '  filed     A  T-9  the retry path needs its own change' 'status row'
  has "$OUT" '  filed     A  T-10  second' 'second row'
}

# --- handoff ------------------------------------------------------------------------

handoff_only_opens_the_worktree_in_a_new_window() {
  mkline; mkorder A mode=manual > /dev/null; mkwt A
  victim; local v=$(<$VICTIM_FILE)
  OUT=$( export CLAUDE_PID=$v CLAUDE_CODE_SESSION_ID=sess-9; k handoff A 2>&1 ); RC=$?
  eq $RC 0 'exit code'
  eq "$(<$CODE_LOG)" "-n $(wt A)" 'code opens the worktree in a new window'
  nap 300
  isyes "alive $v" 'the session is not ended'
  isyes "[[ ! -f $OPEN_LOG ]]" 'no link is opened'
  lacks "$OUT" 'vscode://' 'no link is printed'
  kill $v 2>/dev/null
}

handoff_refuses_an_order_that_is_not_manual_or_has_no_worktree() {
  mkline; mkorder A mode=guided > /dev/null; mkorder M mode=manual > /dev/null; mkwt A
  OUT=$(k handoff A 2>&1); RC=$?
  eq $RC 1 'guided exit code'
  has "$OUT" 'A is not a manual order' 'guided message'
  OUT=$(k handoff M 2>&1); RC=$?
  eq $RC 1 'no worktree exit code'
  has "$OUT" 'no worktree at' 'no worktree message'
  isyes "[[ ! -f $CODE_LOG ]]" 'nothing opened'
}

# --- catering deployments ---------------------------------------------------------

a_project_whose_rules_lack_docs_is_not_set_up() {
  mkline; mode hang; mkorder A > /dev/null
  OUT=$(k house 2>&1); RC=$?
  eq $RC 0 'a project with all three sections'
  git clone -q $CASE/origin.git $CASE/other 2>/dev/null
  print -r -- $'# House rules\n\n### Critical paths\n\n| Path | What it is | Extra effort | Waits for me |\n|---|---|---|---|\n| `^secrets/` | credentials | no | yes |\n\n### Questions that hold a PR\n- the change moves money' > $CASE/other/.claude/kitchen/house.md
  git -C $CASE/other commit -q -am 'drop docs'
  git -C $CASE/other push -q origin main 2>/dev/null
  git -C $PROJ fetch -q origin
  OUT=$(k house 2>&1); RC=$?
  eq $RC 1 'exit code without docs'
  has "$OUT" 'not set up' 'verdict'
  has "$OUT" '### Docs' 'names the missing section'
  tick; nap 20
  eq $(ncalls) 0 'no new work'
  has "$OUT" 'not set up, so no new work' 'scheduler says why'
}

a_path_row_with_a_bare_pipe_is_not_set_up() {
  mkline
  git clone -q $CASE/origin.git $CASE/other 2>/dev/null
  print -r -- $'# House rules\n\n### Critical paths\n\n| Path | What it is | Extra effort | Waits for me |\n|---|---|---|---|\n| `^(a|b)/` | bare pipe | no | yes |\n| `^c/` | flag | maybe | yes |\n| `` | empty | no | yes |\n| `<e.g. ^src/ledger/>` | <what it is> | yes | yes |\n\n### Questions that hold a PR\n\n### Docs\n- none' > $CASE/other/.claude/kitchen/house.md
  git -C $CASE/other commit -q -am 'bare pipe'
  git -C $CASE/other push -q origin main 2>/dev/null
  git -C $PROJ fetch -q origin
  OUT=$(k house 2>&1); RC=$?
  eq $RC 1 'exit code'
  has "$OUT" 'a path row has 5 cells, not 4 (write each | inside a regex as \|): `^(a' 'names the unreadable row and the fix'
  has "$OUT" "a path row's Extra effort and Waits for me each take yes or no: \`^c/\`" 'names the bad flag'
  has "$OUT" "a path row's regex is empty" 'names the empty regex'
  has "$OUT" "a path row is still the template's example" 'names the unfilled example'
  lacks "$OUT" 'lack' 'every section is there'
}

the_scheduler_never_starts_a_catering_order() {
  mkline; mode hang
  mkorder C1 recipe=catering stage=plan > /dev/null
  mkorder C2 recipe=catering stage=building > /dev/null
  mkorder C3 recipe=catering > /dev/null
  tick; nap 20
  eq $(ncalls) 0 'sessions'
  eq "$(ord C2 status)" ready 'still ready'
}

the_scheduler_never_starts_an_order_held_for_the_users_calls_until_they_answer() {
  mkline; mode hang
  mkorder H stage=calls 'question=2 calls wait for you' > /dev/null
  tick; nap 20
  eq $(ncalls) 0 'no session while the calls wait'
  k order set H status=ready pid=0 stage= question= > /dev/null
  tick; wait_calls 1
  has "$OUT" 'cook H' 'started once the user answered'
  eq "$(ord H mode)" auto 'still auto'
}

the_scheduler_never_starts_a_deployment_waiting_for_its_skeleton() {
  mkline; mode hang
  mkorder S catering=E1 stage=skeleton > /dev/null
  tick; nap 20
  eq $(ncalls) 0 'no session at the skeleton'
  k order set S stage=build > /dev/null
  tick; wait_calls 1
  has "$OUT" 'cook S' 'started at build'
}

a_merged_pr_on_a_catering_order_closes_it_like_any_other() {
  mkline; mkpr C 7; mkwt C
  k order set C recipe=catering catering=E1 > /dev/null
  setpr 7 MERGED u2
  tick
  eq "$(ord C status)" done status
  eq "$(ord C question)" '' 'no planning question'
  has "$(<$TICKET_LOG)" "move C merged Merged: $(prurl 7)" 'ticket moved'
  isyes "[[ ! -d $(wt C) ]]" 'worktree removed'
}

an_open_pr_on_a_catering_order_gets_follow_ups() {
  mkline; mode hang; mkpr D 8
  k order set D recipe=catering catering=E1 > /dev/null
  setpr 8 OPEN u2
  tick; wait_calls 1
  has "$OUT" 'follow D' 'follow session'
}

order_next_skips_orders_waiting_on_their_after_list_and_catering_orders() {
  mkline
  mkorder B status=pr-open > /dev/null
  mkorder A mode=manual 'after=["B"]' > /dev/null
  mkorder C mode=manual recipe=catering > /dev/null
  mkorder M mode=manual > /dev/null
  eq "$(k order next manual)" M 'neither the waiting order nor the catering one'
  k order set M status=cooking > /dev/null
  OUT=$(k order next manual 2>&1); RC=$?
  eq $RC 1 'nothing else is next'
  k order set B status=done > /dev/null
  eq "$(k order next manual)" A 'once B is done'
}

status_lists_skeleton_deployments_first_and_hides_orders_waiting_on_their_after_list() {
  mkline
  mkorder X status=pr-open > /dev/null
  mkorder G mode=guided > /dev/null
  mkorder M mode=manual > /dev/null
  mkorder D mode=manual catering=E1 stage=build > /dev/null
  mkorder S1 mode=guided catering=E1 stage=skeleton > /dev/null
  mkorder S2 mode=manual catering=E1 stage=skeleton 'after=["X"]' > /dev/null
  mkorder C mode=manual recipe=catering > /dev/null
  mkorder P mode=manual status=pr-open pr=$(prurl 1) catering=E1 > /dev/null
  OUT=$(k status 2>&1)
  local -a rows=( ${(M)${(f)OUT}:#  READY *} )
  eq $#rows 5 'ready rows'
  has $rows[1] 'READY     S1  skeleton  [E1]  approved' 'skeleton first, whatever its mode'
  has $rows[2] 'READY     M  manual  approved' 'manual next'
  has $rows[3] 'READY     D  manual  [E1]  approved' 'a deployment names its catering order'
  has $rows[4] 'READY     C  manual  approved' 'the catering order'
  has $rows[4] '[catering]' 'catering tag'
  has $rows[5] 'READY     G  guided  approved' 'guided last'
  lacks "$OUT" 'S2' 'waits on X'
  has "$OUT" '  REVIEW    P' 'review row'
  has "$OUT" 'kitchen stage P' 'review row names stage'
}

stage_shows_the_prs_change_staged_in_a_review_worktree_and_rebuilds_it() {
  mkline; mkorder D mode=manual status=pr-open pr=$(prurl 1) catering=E1 > /dev/null
  mkwt D; wtcommit D src/a.txt two; wtcommit D new/b.txt x
  advance_base other.txt
  local rv=$(wt review-D)
  OUT=$(k stage D 2>&1); RC=$?
  eq $RC 0 'exit code'
  has "$OUT" "staged D in $rv: 2 files changed" 'summary'
  eq "$(<$CODE_LOG)" "-n $rv" 'code opened the review worktree'
  local mb=$(git -C $PROJ merge-base D origin/main)
  eq "$(git -C $rv diff --cached)" "$(git -C $PROJ diff $mb D)" 'staged diff is the PR change against the merge base'
  eq "$(git -C $rv diff)" '' 'nothing unstaged'
  eq "$(git -C $(wt D) rev-list --count $mb..D)" 2 'the PR branch keeps its commits'
  wtcommit D src/c.txt three
  k order set D status=cooking > /dev/null  # the reviewing session holds the order
  OUT=$(k stage D 2>&1); RC=$?
  eq $RC 0 'second run exit code'
  has "$OUT" '3 files changed' 'rebuilt with the new commit'
  eq "$(git -C $rv diff --cached)" "$(git -C $PROJ diff $mb D)" 'rebuilt diff'
  eq "$(wc -l < $CODE_LOG | tr -d ' ')" 2 'code opened it each time'
}

stage_refuses_an_order_that_is_not_a_catering_deployment() {
  mkline
  mkorder A mode=manual status=pr-open > /dev/null; mkwt A
  mkorder D mode=manual catering=E1 > /dev/null; mkwt D
  OUT=$(k stage A 2>&1); RC=$?
  eq $RC 1 'plain order exit code'
  has "$OUT" 'A is not a catering deployment' 'plain order message'
  OUT=$(k stage D 2>&1); RC=$?
  eq $RC 1 'no PR exit code'
  has "$OUT" 'D has no PR' 'no PR message'
  isyes "[[ ! -f $CODE_LOG && ! -d $(wt review-A) && ! -d $(wt review-D) ]]" 'nothing opened'
}

# --- transcripts ------------------------------------------------------------------

an_order_transcript_conversation_prints_only_what_the_user_and_the_session_said() {
  mkline; mkorder A status=new last_session=s1 > /dev/null
  mkdir -p $HOME/.claude/projects/p
  print -rl -- \
    '{"type":"user","isMeta":true,"message":{"role":"user","content":[{"type":"text","text":"Base directory for this skill: kitchen"}]}}' \
    '{"type":"user","message":{"role":"user","content":"<command-message>kitchen</command-message>\n<command-name>/kitchen</command-name>\n<command-args>take 7</command-args>"}}' \
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"a private thought"},{"type":"text","text":"Reading the ticket."},{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"ls secret-dir"}}]}}' \
    '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"tool output line"}]}}' \
    '{"type":"user","message":{"role":"user","content":"<task-notification>agent done</task-notification>"}}' \
    '{"type":"user","isCompactSummary":true,"message":{"role":"user","content":"This session is being continued"}}' \
    '{"type":"user","isSidechain":true,"message":{"role":"user","content":"a subagent brief"}}' \
    '{"type":"attachment","attachment":{"type":"file","content":"attached file body"}}' \
    '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"scope it deeper<system-reminder>a reminder</system-reminder>"}]}}' \
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Agreed, the fix goes a level down."}]}}' \
    > $HOME/.claude/projects/p/s1.jsonl
  OUT=$(k order transcript A --conversation 2>&1)
  has "$OUT" '/kitchen take 7' 'the take'
  has "$OUT" 'Reading the ticket.' 'a reply'
  has "$OUT" 'scope it deeper' 'a steer'
  has "$OUT" 'Agreed, the fix goes a level down.' 'the last reply'
  local kept
  for kept in 'Base directory' 'a private thought' 'secret-dir' 'tool output line' 'agent done' 'being continued' 'a subagent brief' 'attached file body' 'a reminder' '<command-name>'; do
    lacks "$OUT" $kept "kept $kept"
  done
  eq "$(k order transcript A)" $HOME/.claude/projects/p/s1.jsonl 'with no option it prints the path'
  isyes "! k order transcript A --bogus > /dev/null 2>&1" 'an unknown option refuses'
}

# --- workspace types --------------------------------------------------------------

an_untyped_line_never_calls_a_workspace_type() {
  tripwire
  mkline; mkorder A status=pr-open > /dev/null; mkwt A
  wtcommit A src/a.txt two; wtcommit A secrets/key.txt x
  gated; verdict PASS; sample
  kw $(wt A) order approve A HEAD > /dev/null
  kw $(wt A) each A -- true > /dev/null 2>&1
  k order base A > /dev/null; k rules > /dev/null; k house > /dev/null; k status > /dev/null; k order list > /dev/null
  k order set A status=done > /dev/null; k prune > /dev/null
  tick
  OUT=$(k workspace 2>&1); RC=$?
  eq $RC 0 'workspace on a line with no type'
  eq "$OUT" '' 'prints nothing'
  OUT=$(k workspace enter A 2>&1); RC=$?
  eq $RC 1 'a verb on a line with no type'
  has "$OUT" 'names no workspace type' 'says so'
  isyes "[[ ! -f $TRIP_LOG ]]" 'no workspace type was called by any of it'
}

line_add_without_a_type_is_what_it_was_and_a_type_is_asked_only_when_named() {
  tripwire
  mkdir $CASE/nowhere
  OUT=$(kw $CASE line add $CASE/nowhere 2>&1); RC=$?
  eq $RC 1 'exit code'
  has "$OUT" "$CASE/nowhere is not a git checkout" 'the message it always had'
  isyes "[[ ! -f $TRIP_LOG ]]" 'no type is asked when none is named'
  OUT=$(kw $CASE line add $CASE/nowhere --workspace trip 2>&1); RC=$?
  eq $RC 1 'a named type that does not hold the path'
  has "$OUT" 'is not in a trip workspace' 'refuses'
  eq "$([[ -f $TRIP_LOG ]] && <$TRIP_LOG)" "root $CASE/nowhere" 'and the type was asked exactly that'
}

an_untyped_orders_ids_are_the_plain_git_ones() {
  sampled; wtcommit A src/a.txt two; gated; verdict PASS
  local want=$(git -C $(wt A) diff -U0 origin/main...HEAD | git patch-id --stable | cut -d' ' -f1)
  eq "$(ord A gated)" $want 'gated is the lone repo patch id'
  eq "$(ord A verdict_patch)" $want 'so is the verdict patch'
  eq "$(ord A gated_head)" "$(git -C $(wt A) rev-parse HEAD)" 'gated_head is a bare sha'
  eq "$(ord A verdict_head)" "$(git -C $(wt A) rev-parse HEAD)" 'verdict_head is a bare sha'
  eq "$(ord A gated_base)" "$(git -C $(wt A) merge-base HEAD origin/main)" 'gated_base is a bare sha'
  kw $(wt A) order approve A $(git -C $(wt A) rev-parse HEAD) > /dev/null
  eq "$(ord A approved)" $want 'approved by its commit is the same id'
}

the_core_names_no_installed_workspace_type() {
  local kitchen=${HERE:h:h} t
  for t in $kitchen/workspaces/*(N/:t); do
    eq "$(grep -rliw $t $kitchen --exclude-dir=workspaces --exclude-dir=evals --exclude-dir=__pycache__)" '' "files outside workspaces/ naming $t"
  done
}

a_typed_line_registers_by_name_and_claims_every_directory_under_its_project() {
  fakews
  eq "$(jq -r .workspace $BOOKDIR/line.json 2>&1)" fake 'the line names its type'
  eq "$(kw $WS/src/A line add . --workspace fake 2>&1)" ws 'naming the type from inside a repo finds the same line'
  wsorder A; wswt A
  eq "$(kw $WS order list 2>&1 | cut -f2)" A 'the project root, which is no git checkout, belongs to the line'
  eq "$(kw $WS/worktrees/A/src/B order list 2>&1 | cut -f2)" A 'so does a worktree of a repo under it'
}

workspace_prints_the_type_doc_and_hands_any_verb_to_the_type_with_the_order() {
  fakews; wsorder A
  eq "$(kw $WS workspace 2>&1)" $SB/types/fake/fake.md 'the type doc'
  eq "$(kw $WS workspace echo A x 'y z' 2>&1)" "[$WS][$BOOKDIR/orders/A.json][x][y z]" 'the verb, the project, the order file, then the rest, each its own argument'
}

order_base_refuses_on_a_typed_line() {
  fakews; wsorder A
  OUT=$(kw $WS order base A 2>&1); RC=$?
  eq $RC 1 'there is no single base'
  has "$OUT" 'base per package' 'and says why'
}

a_typed_orders_approval_takes_head_and_refuses_a_commit_of_one_repo() {
  fakews; wsorder A review=true; wswt A
  wscommit A A src/a.txt two; wscommit A B src/b.txt two
  kw $WS order gated A > /dev/null 2>&1; kw $WS order verdict A PASS notes > /dev/null 2>&1
  eq "$(kw $WS sample A 2>&1)" review 'the change waits for the user'
  OUT=$(kw $WS order approve A $(git -C $(wspkg A A) rev-parse HEAD) 2>&1); RC=$?
  eq $RC 1 'a commit is one repo'"'"'s head, so it is refused'
  has "$OUT" HEAD 'with a message saying to approve HEAD'
  eq "$(ord A approved)" '' 'and nothing is recorded'
  kw $WS order approve A HEAD > /dev/null 2>&1
  eq "$(kw $WS sample A 2>&1)" no 'HEAD approves the change as every repo holds it'
}

a_line_is_refused_inside_another_lines_project_and_over_one() {
  fakews
  mkdir -p $CASE/Qteam/src $CASE/Qnew/src; touch $CASE/Qteam/.fakeworkspace $CASE/Qnew/.fakeworkspace
  git clone -q $CASE/origin.git $CASE/Qteam/src/Pkg 2>/dev/null; git clone -q $CASE/origin.git $CASE/Qnew/src/Qlone 2>/dev/null
  kw $CASE/Qteam line add $CASE/Qteam --workspace fake > /dev/null 2>&1
  local inner=$CASE/Qteam/src/Pkg
  OUT=$(kw $inner line add $inner 2>&1); RC=$?
  eq $RC 1 'a line with no type inside a typed line'"'"'s project'
  has "${OUT//$inner}" Qteam 'names the typed line'
  kw $CASE/Qnew/src/Qlone line add $CASE/Qnew/src/Qlone > /dev/null 2>&1
  OUT=$(kw $CASE/Qnew line add $CASE/Qnew --workspace fake 2>&1); RC=$?
  eq $RC 1 'a typed line over another line'"'"'s project'
  has "$OUT" Qlone 'names the line inside it'
  eq "$(ls $KITCHEN_BOOK)" $'Qlone\nQteam\nws' 'neither refused line is registered'
}

ticket_provider_refuses_a_repo_with_no_config_as_well_when_home_is_a_symlink() {
  local real=$CASE/realhome link=$CASE/homelink tz=${HERE:h:h:h}/ticket-provider/dependencies/scripts/ticket.zsh
  mkdir -p $real/.claude/ticket-provider $real/repo
  print -r -- '{"provider":"jira"}' > $real/.claude/ticket-provider/config.json
  ln -s $real $link; git init -q $real/repo
  ( cd $real/repo && HOME=$real zsh $tz provider ) > /dev/null 2>&1; RC=$?
  eq $RC 1 'the user'"'"'s own config is no project'"'"'s'
  OUT=$( cd $link/repo && HOME=$link zsh $tz provider 2>&1 ); RC=$?
  eq $RC 1 'nor when HOME names it through a symlink'
  lacks "$OUT" jira 'whose provider is not read'
}

each_replaces_only_a_whole_base_variable_with_the_base_on_either_kind_of_line() {
  mkprobe; sampled
  local -a args=('$BASEDIR' '$BASE_REF' '${BASE}x' '$BASE' '${BASE}' 'origin/$BASE..HEAD')
  OUT=$(kw $(wt A) each A -- probe "${args[@]}" 2>&1)
  eq "$OUT" "$(wt A) main \$BASEDIR \$BASE_REF mainx main main origin/main..HEAD" 'a line with no type'
  fakews; wsorder W; wswt W
  OUT=$(kw $WS each W -- probe "${args[@]}" 2>&1)
  eq "$OUT" "== A"$'\n'"$(wspkg W A) main \$BASEDIR \$BASE_REF mainx main main origin/main..HEAD"$'\n'"== B"$'\n'"$(wspkg W B) testing \$BASEDIR \$BASE_REF testingx testing testing origin/testing..HEAD" 'a typed line'
}

the_mutation_sweep_takes_the_rules_kitchen_rules_names_over_the_base_branchs_own_copy() {
  mkwt A; wtcommit A src/a.js 'export const f = (a, b) => a + b;'
  print -r -- $'# Team rules\n\n- **Mutation:** stryker `npx stryker run -c team.conf.json`\n\n### Critical paths\n\n### Questions that hold a PR\n\n### Docs' > $CASE/team.md
  local sweep=${KITCHEN:h}/mutation-sweep.py
  OUT=$( cd $(wt A) && KITCHEN_RULES=$CASE/team.md python3 -I $sweep --list --test-cmd true origin/main 2>&1 )
  has "$OUT" 'src/a.js: npx stryker run -c team.conf.json' 'the base branch'"'"'s rules name no Stryker, and the ones KITCHEN_RULES names do'
  lacks "$OUT" 'not swept: src/a.js' 'so the file is swept'
  OUT=$( unset KITCHEN_RULES; cd $(wt A) && python3 -I $sweep --list --test-cmd true origin/main 2>&1 )
  has "$OUT" 'not swept: src/a.js' 'with KITCHEN_RULES unset the base branch'"'"'s copy holds'
}

a_typed_orders_gate_protocol_runs_over_every_repo_against_its_own_base() {
  fakews; wsorder A; wswt A
  wscommit A A src/a.txt two; wscommit A B src/b.txt two
  kw $WS order gated A > /dev/null 2>&1
  eq "$(ord A gated_head)" "A: $(git -C $(wspkg A A) rev-parse HEAD)"$'\n'"B: $(git -C $(wspkg A B) rev-parse HEAD)" 'gated_head: a row per repo'
  eq "$(kw $WS sample A 2>&1)" verify 'no verdict yet, asked from the project root'
  eq "$(kw $(wspkg A B)/src sample A 2>&1)" verify 'the same from inside a repo'
  kw $WS order verdict A PASS notes > /dev/null 2>&1
  eq "$(kw $WS sample A 2>&1)" no 'a verdict covers the change'
  wscommit A B src/b.txt three
  eq "$(kw $WS sample A 2>&1)" regate 'a commit in one repo invalidates the gate'
  kw $WS order gated A > /dev/null 2>&1
  git clone -q $CASE/originB.git $CASE/other 2>/dev/null
  git -C $CASE/other checkout -q testing; print more >> $CASE/other/src/b.txt
  git -C $CASE/other commit -qam move; git -C $CASE/other push -q origin testing 2>/dev/null
  eq "$(kw $WS sample A 2>&1)" rebase "B's base moved under a file B changed"
}

a_rule_path_in_a_repo_waits_for_the_user_unless_the_station_names_it() {
  fakews; wsorder A 'station=["B/secrets/"]'; wswt A
  wscommit A B secrets/key.txt x; wscommit A A src/a.txt two
  kw $WS order gated A > /dev/null 2>&1; kw $WS order verdict A PASS notes > /dev/null 2>&1
  eq "$(kw $WS sample A 2>&1)" no 'the station names it'
  kw $WS order set A 'station=["A/"]' > /dev/null 2>&1
  eq "$(kw $WS sample A 2>&1)" review 'outside the station it waits'
  has "$(ord A review_why)" 'B: project rule: secrets/key.txt' 'the reason names the repo'
}

prune_lands_each_repo_of_a_closed_order_then_its_worktree_and_keeps_a_dirty_repo() {
  fakews; wsorder A; wsorder D; wswt A; wswt D
  print x > $(wspkg D B)/loose.txt
  kw $WS order set A status=done > /dev/null 2>&1; kw $WS order set D status=done > /dev/null 2>&1
  OUT=$(kw $WS prune --dry-run 2>&1)
  has "$OUT" 'would remove A (A)' 'a dry run says what it would do'
  isyes "[[ -d $(wspkg A A) ]]" 'and does not'
  OUT=$(kw $WS prune 2>&1)
  has "$OUT" 'removed A (A)' 'repo A'; has "$OUT" 'removed B (A)' 'repo B'
  has "$OUT" 'kept B: uncommitted changes' 'a dirty repo is kept'
  isyes "[[ ! -e $WS/worktrees/A && -d $(wspkg D B) ]]" 'the clean order is gone and the dirty repo stays'
  eq "$(git -C $WS/src/A branch --list A)" '' 'its branch is gone'
}

a_commit_in_any_repo_is_progress_and_none_in_any_is_a_stall() {
  fakews; mode hang; kw $WS line set ws 'stall_minutes={"cook":1}' > /dev/null 2>&1
  wsorder A; wswt A
  tick; wait_calls 1
  local pid=$(ord A pid)
  jqedit A '.started -= 300 | .touched -= 300'
  wsquiet A; wscommit A A src/a.txt work
  tick
  lacks "$OUT" 'sent' 'a commit in the first repo is progress'
  wsquiet A; wscommit A B src/b.txt work
  tick
  lacks "$OUT" 'sent' 'so is a commit in the second'
  isyes "alive $pid" 'session still running'
  wsquiet A
  tick
  has "$OUT" 'no progress in 1 minutes; sent TERM' 'a commit in neither is a stall'
}

each_on_an_untyped_line_runs_once_from_the_repo_top_and_leaves_output_and_exit_alone() {
  mkprobe; sampled
  print 3 > $(wt A)/.exit
  OUT=$(kw $(wt A)/src each A -- probe 'origin/$BASE' 2>&1); RC=$?
  eq "$OUT" "$(wt A) main origin/main" 'one run from the top of the repo with the order base as BASE, and nothing added'
  eq $RC 3 'the exit code is the command'"'"'s'
}

each_on_a_typed_line_runs_once_per_repo_with_its_base_heads_each_output_and_exits_with_the_worst_code() {
  mkprobe; fakews; wsorder A; wswt A
  print 3 > $(wspkg A A)/.exit; print 1 > $(wspkg A B)/.exit
  OUT=$(kw $WS each A -- probe 'origin/$BASE' 2>&1); RC=$?
  eq "$OUT" "== A"$'\n'"$(wspkg A A) main origin/main"$'\n'"== B"$'\n'"$(wspkg A B) testing origin/testing" 'a headed run from the top of each repo with its own BASE'
  eq $RC 3 'the worst code when the first repo fails worse'
  print 1 > $(wspkg A A)/.exit; print 3 > $(wspkg A B)/.exit
  kw $WS each A -- probe x > /dev/null 2>&1; RC=$?
  eq $RC 3 'the worst code when the last repo fails worse'
}

each_changed_skips_a_repo_with_no_commit_past_its_own_base() {
  mkprobe; fakews; wsorder A; wswt A
  wscommit A A src/a.txt two
  OUT=$(kw $WS each A --changed -- probe x 2>&1); RC=$?
  eq "$OUT" "== A"$'\n'"$(wspkg A A) main x" 'B sits at its base testing, which main lacks, so only A runs'
  eq $RC 0 'exit code'
}

# --- prune, dry run ---------------------------------------------------------------

prune_removes_the_worktree_of_a_closed_order_no_session_holds() {
  mkline
  local k
  for k in C1 H1 O1 D1 D2 U1; do mkorder $k > /dev/null; mkwt $k; done
  k order set C1 status=done > /dev/null
  k order set H1 status=done pid=4242424 > /dev/null
  k order set O1 status=pr-open > /dev/null
  k order set D1 status=86 > /dev/null
  k order set D2 status=86 > /dev/null
  k order set U1 status=done > /dev/null
  wtcommit C1 src/a.txt c; wtcommit D1 src/a.txt d
  print x > $(wt U1)/loose.txt
  OUT=$(k prune 2>&1)
  has "$OUT" 'removed C1 (C1)' 'closed order'
  has "$OUT" 'removed D2 (D2)' 'dropped without changes'
  has "$OUT" 'kept D1: dropped with changes not in main' 'dropped with changes'
  has "$OUT" 'kept U1: uncommitted changes' 'uncommitted'
  isyes "[[ ! -d $(wt C1) && ! -d $(wt D2) ]]" 'removed worktrees are gone'
  isyes "[[ -d $(wt H1) && -d $(wt O1) && -d $(wt D1) && -d $(wt U1) ]]" 'held, open and kept worktrees stay'
  eq "$(git -C $PROJ branch --list C1)" '' 'branch deleted'
  eq "$(<$BOOKDIR/.pruned)" $(today_str) 'prune day recorded'
}

prune_removes_a_closed_orders_review_worktree() {
  mkline
  mkorder C1 > /dev/null; mkorder C2 > /dev/null
  mkwt C1
  git -C $PROJ worktree add -q --detach $(wt review-C1) origin/main 2>/dev/null
  git -C $PROJ worktree add -q --detach $(wt review-C2) origin/main 2>/dev/null
  k order set C1 status=done > /dev/null
  k order set C2 status=done > /dev/null
  OUT=$(k prune 2>&1)
  has "$OUT" 'removed review-C1' 'review beside the order worktree'
  has "$OUT" 'removed review-C2' 'review alone'
  isyes "[[ ! -d $(wt C1) && ! -d $(wt review-C1) && ! -d $(wt review-C2) ]]" 'all gone'
}

prune_runs_the_teardown_of_a_closed_orders_verify_and_review_worktrees() {
  mkline; mkorder C1 > /dev/null
  local n; for n in verify-C1 review-C1; do
    git -C $PROJ worktree add -q --detach $(wt $n) origin/main 2>/dev/null
    mkdir -p $(wt $n)/.claude-artifacts
    print "echo $n >> $BOOKDIR/teardowns" > $(wt $n)/.claude-artifacts/teardown.sh
  done
  k order set C1 status=done > /dev/null
  k prune > /dev/null 2>&1
  eq "$(sort $BOOKDIR/teardowns 2>&1)" $'review-C1\nverify-C1' 'each ran once before its worktree went'
  isyes "[[ ! -d $(wt verify-C1) && ! -d $(wt review-C1) ]]" 'both gone'
}

prune_dry_run_removes_nothing() {
  mkline; mkorder C1 > /dev/null; mkwt C1
  k order set C1 status=done > /dev/null
  rm -f $BOOKDIR/.pruned
  OUT=$(k prune --dry-run 2>&1)
  has "$OUT" 'would remove C1 (C1)' 'plan'
  isyes "[[ -d $(wt C1) ]]" 'worktree stays'
  isyes "[[ ! -f $BOOKDIR/.pruned ]]" 'no prune day recorded'
}

tick_dry_run_prints_the_pass_and_changes_nothing() {
  mkline; mode hang
  mkorder A > /dev/null
  mkpr C 31; setpr 31 OPEN u2
  mkpr M 32; setpr 32 MERGED u2
  rm -f $BOOKDIR/.pruned
  local before=$(jq -S -c . $BOOKDIR/orders/*.json)
  tick --dry-run
  has "$OUT" 'proj: would cook A' 'cook'
  has "$OUT" 'proj: would follow C' 'follow'
  has "$OUT" 'proj: would close M' 'close'
  eq "$(jq -S -c . $BOOKDIR/orders/*.json)" $before 'order book'
  eq $(ncalls) 0 sessions
  isyes "[[ ! -e $KITCHEN_BOOK/.tick.lock && ! -f $BOOKDIR/.pruned ]]" 'no lock, no prune'
}

no_tool_outside_the_sandbox_was_called() {
  eq "$([[ -f $FORBIDDEN_LOG ]] && <$FORBIDDEN_LOG)" '' 'calls to claude, jira, bb, curl, or a workspace type'"'"'s tool outside its own cases'
}

# --- runner -----------------------------------------------------------------------

CASES=( ${(f)"$(sed -n '/^# --- claims/,/^# --- runner/s/^\([a-z_0-9]*\)() {.*/\1/p' $0)"} )
# a workspace type's own cases go before the last case, which checks that the whole run reached no tool outside the sandbox
for x in ${HERE:h:h}/workspaces/*/tests/cases.zsh(N); do source $x; CASES[-1,-2]=( ${(f)"$(sed -n '/^# --- cases/,$s/^\([a-z_0-9]*\)() {.*/\1/p' $x)"} ); done
(( $# )) && CASES=( "$@" )

run_case() {
  FAILS=()
  fresh
  $1
  kill_matching $CASE
  [[ -f $VICTIM_FILE ]] && kill $(<$VICTIM_FILE) 2>/dev/null
  if (( $#FAILS )); then
    local why=${(j:; :)FAILS}
    why=${why//[>|;&\`$'\n']/ }
    print -r -- "FAIL $1: $why"
    FAILED=$(( FAILED + 1 ))
  else
    print -r -- "PASS $1"
    PASSED=$(( PASSED + 1 ))
  fi
}

START=$EPOCHREALTIME
for c in $CASES; do
  (( ${+functions[$c]} )) || { print -r -- "FAIL $c: no such case"; FAILED=$(( FAILED + 1 )); continue }
  run_case $c
done
printf '%d passed, %d failed in %.1fs\n' $PASSED $FAILED $(( EPOCHREALTIME - START ))
(( FAILED == 0 ))
