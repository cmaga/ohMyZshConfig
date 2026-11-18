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
export HOME=$SB/home
export PATH=$SB/bin:$PATH
export GIT_CONFIG_GLOBAL=$SB/gitconfig GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=harness GIT_AUTHOR_EMAIL=harness@example.invalid
export GIT_COMMITTER_NAME=harness GIT_COMMITTER_EMAIL=harness@example.invalid
export KITCHEN_ALIASES=$SB/bin/aliases.zsh KITCHEN_SCRIPT=$KITCHEN FORBIDDEN_LOG=$SB/forbidden.log

mkdir -p $SB/bin $HOME/.claude/skills/ticket-provider/dependencies/scripts $HOME/.claude/skills/capture-documentation/scripts
print -r -- $'[init]\n\tdefaultBranch = main' > $SB/gitconfig
cp $HERE/stubs/{gh,lsof,aliases.zsh} $SB/bin/
for t in claude jira bb curl; do cp $HERE/stubs/forbidden $SB/bin/$t; done
# recording fakes: code logs its arguments; open logs its link and whether the handed-off session's process was already gone
print -r -- $'#!/bin/sh\nprintf "%s\\n" "$*" >> "$CODE_LOG"' > $SB/bin/code
print -r -- $'#!/bin/sh\nif kill -0 "$(cat "$VICTIM_FILE")" 2>/dev/null; then s=alive; else s=gone; fi\nprintf "%s %s\\n" "$*" "$s" >> "$OPEN_LOG"' > $SB/bin/open
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
print -r -- $'# House rules\n\n## Always review\n- `^secrets/`: credentials\n\n## Review when\n- the change moves money\n\n## Docs\n- docs live in docs/' > $SB/seed/.claude/kitchen/house.md
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
wait_open() { local i; for i in {1..300}; do [[ -s $OPEN_LOG ]] && return 0; nap; done; return 1 }

mkline() { # [field=value...]
  k line add $PROJ > /dev/null
  k line set proj guided_after=0 auto_after=0 "$@"
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
  isyes "jq -e '(has(\"rail_depth\") or (.models | has(\"serve\"))) | not' $BOOKDIR/line.json > /dev/null" 'no rail depth or serve model in line.json'
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

sample_says_verify_when_no_verdict_covers_this_change() {
  sampled; wtcommit A src/a.txt two; gated
  sample; eq "$OUT" verify output
}

sample_says_review_for_a_path_under_always_review() {
  sampled; wtcommit A secrets/key.txt x; gated; verdict PASS
  sample
  eq "$OUT" review output
  eq "$(ord A review)" true review
  has "$(ord A review_why)" 'project rule: secrets/key.txt' reason
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

sample_leaves_an_always_review_path_inside_the_orders_station_to_intake() {
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

status_lists_ready_manual_then_guided_orders_with_when_they_were_approved() {
  mkline
  mkorder G mode=guided > /dev/null; mkorder M1 mode=manual > /dev/null; mkorder A > /dev/null
  OUT=$(k status 2>&1)
  local -a rows=( ${(M)${(f)OUT}:#  READY *} )
  eq $#rows 2 'auto orders are not listed'
  has $rows[1] 'READY     M1  manual  approved 20' 'manual first'
  has $rows[2] 'READY     G  guided  approved 20' 'then guided'
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
  OUT=$(k order new X mode=guided 2>&1); RC=$?
  eq $RC 1 'exit code'
  has "$OUT" 'guided is locked: 0 of 5 merged manual orders (guided_after)' 'unmet threshold'
  k order new X > /dev/null
  OUT=$(k order set X mode=auto 2>&1); RC=$?
  eq $RC 1 'auto refused'
  has "$OUT" 'auto is locked: guided is locked: 0 of 5 merged manual orders (guided_after)' 'auto waits on guided'
  OUT=$(k order set X mode=sideways 2>&1); RC=$?
  eq $RC 1 'unknown mode refused'
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

share_counts_manual_orders_made_ready_in_the_last_two_weeks() {
  mkline
  mkorder A mode=manual > /dev/null; mkorder B mode=manual > /dev/null; mkorder C > /dev/null
  mkorder D mode=manual > /dev/null; jqedit D '.ready_at = "2000-01-01T00:00:00"'
  k order new N > /dev/null
  OUT=$(k share 2>&1)
  has "$OUT" 'manual 2 of 3 orders made ready since' 'two of the three recent ready orders are manual'
}

orders_merged_before_modes_existed_unlock_nothing() {
  k line add $PROJ > /dev/null
  local i
  for i in 1 2 3 4 5 6; do k order new L$i status=done pr=$(prurl $i) > /dev/null; jqedit L$i 'del(.mode)'; done
  eq "$(k modes)" manual 'six merges with no mode leave the project manual-only'
}

merged_manual_orders_unlock_guided_and_merged_guided_orders_unlock_auto() {
  k line add $PROJ > /dev/null
  local i
  for i in 1 2 3 4; do k order new M$i status=done earned=true pr=$(prurl $i) > /dev/null; done
  k order new open1 status=pr-open pr=$(prurl 9) > /dev/null
  eq "$(k modes)" manual '4 merged manual orders'
  k order new M5 status=done earned=true pr=$(prurl 5) > /dev/null
  eq "$(k modes)" $'manual\nguided' '5 merged manual orders'
  k line set proj auto_after=2 > /dev/null
  k order new G1 status=done earned=true pr=$(prurl 6) mode=guided > /dev/null
  eq "$(k modes)" $'manual\nguided' 'one of two merged guided orders'
  OUT=$(k order set open1 mode=auto 2>&1); RC=$?
  eq $RC 1 'auto still locked'
  has "$OUT" 'auto is locked: 1 of 2 merged guided orders (auto_after)' 'unmet threshold'
  k order new G2 status=done earned=true pr=$(prurl 7) mode=guided > /dev/null
  eq "$(k modes)" $'manual\nguided\nauto' 'two merged guided orders'
  k order set open1 mode=auto > /dev/null
  eq "$(ord open1 mode)" auto 'auto accepted'
}

an_unstamped_or_unearned_merge_counts_toward_no_unlock() {
  k line add $PROJ > /dev/null
  local i
  for i in 1 2 3 4 5 6; do k order new G$i status=done pr=$(prurl $i) > /dev/null; jqedit G$i '.mode = "guided"'; done
  eq "$(k modes)" manual 'six merged guided orders with no stamp and no manual merge'
  k order new X > /dev/null
  OUT=$(k order set X mode=auto 2>&1); RC=$?
  eq $RC 1 'auto refused'
  has "$OUT" 'auto is locked: guided is locked: 0 of 5 merged manual orders (guided_after)' 'names the lower lock'
  for i in 1 2 3 4 5; do k order new M$i status=done earned=true pr=$(prurl 1$i) > /dev/null; done
  eq "$(k modes)" $'manual\nguided' 'five earned manual orders, guided orders unstamped'
  for i in 1 2 3 4 5; do jqedit G$i '.earned = false'; done
  eq "$(k modes)" $'manual\nguided' 'five unearned guided orders'
  for i in 1 2 3 4 5; do jqedit G$i '.earned = true'; done
  eq "$(k modes)" $'manual\nguided\nauto' 'five earned manual and five earned guided orders'
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
  k order new C recipe=catering > /dev/null
  k order close C > /dev/null
  eq "$(ord C earned)" false 'a catering order earns nothing'
}

order_next_prints_the_oldest_ready_order_of_a_mode_by_when_it_became_ready() {
  mkline
  k order new LATE recipe=feature mode=manual > /dev/null
  mkorder EARLY mode=manual > /dev/null
  mkorder G mode=guided > /dev/null
  mkorder A > /dev/null
  nap 5
  k order set LATE status=ready > /dev/null
  isyes "[[ $(ord LATE ready_at) > $(ord EARLY ready_at) ]]" 'stamped when it became ready, not when created'
  local stamp=$(ord EARLY ready_at)
  k order set EARLY status=ready > /dev/null
  eq "$(ord EARLY ready_at)" $stamp 'stamped once'
  eq "$(k order next manual)" EARLY 'manual'
  eq "$(k order next guided)" G 'guided'
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

handoff_ends_the_session_then_opens_its_conversation_in_the_worktree_window() {
  mkline; mkorder A mode=manual > /dev/null; mkwt A
  victim; local v=$(<$VICTIM_FILE)
  OUT=$( export CLAUDE_PID=$v CLAUDE_CODE_SESSION_ID=sess-9; k handoff A 2>&1 ); RC=$?
  eq $RC 0 'exit code'
  eq "$(<$CODE_LOG)" "-n $(wt A)" 'code opens the worktree in a new window'
  isyes "alive $v" 'the session is not ended before the command returns'
  wait_open
  isyes "! alive $v" 'the session received TERM'
  eq "$(<$OPEN_LOG)" 'vscode://anthropic.claude-code/open?session=sess-9 gone' 'the link opened after the session exited'
  kill $v 2>/dev/null
}

handoff_prints_the_link_instead_of_opening_it_off_macos() {
  mkline; mkorder A mode=manual > /dev/null; mkwt A
  victim; local v=$(<$VICTIM_FILE)
  print -r -- $'#!/bin/sh\necho Linux' > $SB/bin/uname; chmod +x $SB/bin/uname
  OUT=$( export CLAUDE_PID=$v CLAUDE_CODE_SESSION_ID=sess-9; k handoff A 2>&1 ); RC=$?
  rm -f $SB/bin/uname
  eq $RC 0 'exit code'
  has "$OUT" 'vscode://anthropic.claude-code/open?session=sess-9' 'link printed'
  nap 300
  isyes "[[ ! -f $OPEN_LOG ]]" 'open is not called'
  kill $v 2>/dev/null
}

handoff_refuses_an_order_that_is_not_manual_and_missing_session_variables() {
  mkline; mkorder A mode=guided > /dev/null; mkorder M mode=manual > /dev/null; mkwt A; mkwt M
  victim; local v=$(<$VICTIM_FILE)
  OUT=$( export CLAUDE_PID=$v CLAUDE_CODE_SESSION_ID=sess-9; k handoff A 2>&1 ); RC=$?
  eq $RC 1 'guided exit code'
  has "$OUT" 'A is not a manual order' 'guided message'
  OUT=$( unset CLAUDE_PID; export CLAUDE_CODE_SESSION_ID=sess-9; k handoff M 2>&1 ); RC=$?
  eq $RC 1 'unset CLAUDE_PID exit code'
  has "$OUT" 'CLAUDE_PID and CLAUDE_CODE_SESSION_ID must be set' 'message'
  OUT=$( export CLAUDE_PID=$v; unset CLAUDE_CODE_SESSION_ID; k handoff M 2>&1 ); RC=$?
  eq $RC 1 'unset session id exit code'
  isyes "[[ ! -f $CODE_LOG && ! -f $OPEN_LOG ]]" 'nothing opened'
  isyes "alive $v" 'the session was not touched'
  kill $v 2>/dev/null
}

# --- catering deployments ---------------------------------------------------------

a_project_whose_rules_lack_docs_is_not_set_up() {
  mkline; mode hang; mkorder A > /dev/null
  OUT=$(k house 2>&1); RC=$?
  eq $RC 0 'a project with all three sections'
  git clone -q $CASE/origin.git $CASE/other 2>/dev/null
  print -r -- $'# House rules\n\n## Always review\n- `^secrets/`: credentials\n\n## Review when\n- the change moves money' > $CASE/other/.claude/kitchen/house.md
  git -C $CASE/other commit -q -am 'drop docs'
  git -C $CASE/other push -q origin main 2>/dev/null
  git -C $PROJ fetch -q origin
  OUT=$(k house 2>&1); RC=$?
  eq $RC 1 'exit code without docs'
  has "$OUT" 'not set up' 'verdict'
  has "$OUT" '## Docs' 'names the missing section'
  tick; nap 20
  eq $(ncalls) 0 'no new work'
  has "$OUT" 'not set up, so no new work' 'scheduler says why'
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
  eq "$([[ -f $FORBIDDEN_LOG ]] && <$FORBIDDEN_LOG)" '' 'calls to claude, jira, bb or curl'
}

# --- runner -----------------------------------------------------------------------

CASES=( ${(f)"$(sed -n '/^# --- claims/,/^# --- runner/s/^\([a-z_0-9]*\)() {.*/\1/p' $0)"} )
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
