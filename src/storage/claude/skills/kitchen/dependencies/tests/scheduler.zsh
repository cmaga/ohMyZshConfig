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
cp $HERE/stubs/ticket.zsh $HOME/.claude/skills/ticket-provider/dependencies/scripts/
cp $HERE/stubs/vault-git.sh $HOME/.claude/skills/capture-documentation/scripts/

# one seeded origin, copied per case
git init -q --bare $SB/tmpl.git
git clone -q $SB/tmpl.git $SB/seed 2>/dev/null
mkdir -p $SB/seed/src $SB/seed/tests $SB/seed/.claude/kitchen
print one > $SB/seed/app.txt
print one > $SB/seed/src/a.txt
print one > $SB/seed/tests/foo_test.py
print -r -- $'# House rules\n\n## Always review\n- `^secrets/`: credentials\n\n## Review when\n- the change moves money' > $SB/seed/.claude/kitchen/house.md
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
  export TICKET_LOG=$CASE/ticket.log VAULT_LOG=$CASE/vault.log
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

mkline() { # [field=value...]
  k line add $PROJ > /dev/null
  k line set proj probation=0 "$@"
  today_str > $BOOKDIR/.pruned
}
mkorder() { k order new "$1" status=ready recipe=feature "${@:2}" }
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
  eq "$(ord A phase)" session phase
  eq "$(ord A pid)" $CLAIMER pid
  eq "$(ord A claimed_from)" ready claimed_from
  eq "$(ord A builder)" sess-A builder
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

sample_says_no_when_another_review_already_waits_today() {
  clean_change
  mkorder B status=pr-open review=true pr_opened=$(today_str) > /dev/null
  sample; eq "$OUT" no output
}

sample_picks_the_first_clean_pr_of_the_day_for_review() {
  clean_change
  sample
  eq "$OUT" review output
  eq "$(ord A sample)" true sample
  eq "$(ord A review_why)" "today's review sample" reason
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

a_decision_is_logged_with_its_evidence_and_status_shows_it_once() {
  mkline; mkorder A > /dev/null
  k decide A 'chose X: because Y' 'f.py:1' > /dev/null
  eq "$(ord A decisions | jq -r '.[0].what + "|" + .[0].evidence')" 'chose X: because Y|f.py:1' 'logged'
  jqedit A '.decisions[].at = "2000-01-01T00:00:00"'
  OUT=$(k status 2>&1)
  has "$OUT" '  decided   A  chose X: because Y  (f.py:1)' 'first look'
  k decide A 'chose Z: because W' 'g.py:2' > /dev/null
  OUT=$(k status 2>&1)
  has "$OUT" 'chose Z: because W' 'new decision'
  lacks "$OUT" 'chose X' 'seen decision'
}

status_never_repeats_what_it_showed_even_from_the_same_second() {
  mkline
  mkorder A status=86 reason=nope > /dev/null
  k decide A 'chose X: because Y' 'f.py:1' > /dev/null
  k promoted some-class T-1 > /dev/null
  OUT=$(k status 2>&1)
  has "$OUT" '  dropped   A  nope' 'first look shows the drop'
  has "$OUT" 'chose X' 'first look shows the decision'
  has "$OUT" '  promoted  some-class -> T-1' 'first look shows the promotion'
  local look=$(<$KITCHEN_BOOK/.last-look)
  jqedit A '.updated = $l | .decisions[0].at = $l' --arg l $look
  OUT=$(k status 2>&1)
  lacks "$OUT" '  dropped   A' 'an event stamped with the look itself is not repeated'
  lacks "$OUT" 'chose X' 'nor its decision'
  lacks "$OUT" '  promoted' 'a promotion shows once, not all day'
}

status_shows_only_what_is_new_and_marks_it_seen() {
  mkline
  mkorder A status=done pr=$(prurl 1) summary=shipped > /dev/null
  mkorder B status=86 reason=nope > /dev/null
  mkorder Q status=review-queue question='which way?' > /dev/null
  OUT=$(k status 2>&1)
  has "$OUT" '  merged    A  shipped' 'merged'
  has "$OUT" '  dropped   B  nope' 'dropped'
  has "$OUT" '  QUEUED    Q  which way?' 'queued'
  isyes "[[ -f $KITCHEN_BOOK/.last-look ]]" 'look recorded'
  jqedit A '.updated = "2000-01-01T00:00:00"'; jqedit B '.updated = "2000-01-01T00:00:00"'
  mkorder C status=86 reason=late > /dev/null
  OUT=$(k status 2>&1)
  has "$OUT" '  dropped   C  late' 'new drop'
  lacks "$OUT" '  merged    A' 'seen merge'
  lacks "$OUT" '  dropped   B' 'seen drop'
  has "$OUT" '  QUEUED    Q' 'what waits on the user stays'
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

# --- hold, prune, dry run ---------------------------------------------------------

a_held_ticket_is_tried_again_after_followup_hours() {
  mkline followup_hours=2; mkorder A > /dev/null
  k order hold A 'waiting on X' > /dev/null
  eq "$(ord A status)" new status
  eq "$(ord A reason)" 'waiting on X' reason
  local due=$(ord A retry_after)
  isyes "(( due > EPOCHSECONDS + 7100 && due < EPOCHSECONDS + 7300 ))" 'retry_after is two hours out'
  tick --dry-run
  lacks "$OUT" 'would serve A' 'held'
  jqedit A '.retry_after = 0'
  tick --dry-run
  has "$OUT" 'proj: would serve A' 'tried again'
}

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
