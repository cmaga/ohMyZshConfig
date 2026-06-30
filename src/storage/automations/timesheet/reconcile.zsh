#!/usr/bin/env zsh
# Square the just-ended Sun-Sat week's Harvest hours to the weekly target (40h).
# Run AFTER the week's days are filled (run.zsh fills via the standup skill first).
#
#   - Manual days (>= 8h): rounded UP to the nearest .25 and locked (never redistributed).
#   - Auto days (< 8h): hours distributed to make the week hit the target, weighted by
#     each day's note length with deterministic per-day jitter, capped at 7.75h. If every
#     auto day hits the cap and the week still falls short, the longest-note day absorbs
#     the remainder (and may exceed 7.75h).
#
# Idempotent: auto days always stay < 8, manual >= 8, so the split is stable; the jitter
# is derived from the date, so re-runs converge to the same numbers. Never submits.
#
# Usage: reconcile.zsh [START END]   (default: the just-ended Sun-Sat week)

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
source "${SCRIPT_DIR}/harvest-lib.zsh"

TOML=$(resolve_toml)
PROJECT_NAME=$(_toml_string project_name "$TOML")
TASK_NAME=$(_toml_string task_name "$TOML")
TARGET=$(_toml_int weekly_target "$TOML"); TARGET=${TARGET:-40}

if [[ -n "${1:-}" && -n "${2:-}" ]]; then
    START="$1"; END="$2"
else
    read START END <<<"$(prev_week_range)"
fi

require_credentials || exit 1
resolve_project_task "$PROJECT_NAME" "$TASK_NAME" || exit 1

log() { print -- "[$(date '+%Y-%m-%d %H:%M:%S')] reconcile: $*"; }
log "week ${START}..${END}, target ${TARGET}h"

body=$(harvest_api GET "/time_entries?from=${START}&to=${END}") || { echo "reconcile: fetch failed" >&2; exit 1; }

# date|id|hours|notelen|is_locked for our project/task
entries=$(print -r -- "$body" | jq -r --argjson p "$PROJECT_ID" --argjson t "$TASK_ID" \
    '.time_entries[] | select(.project.id == $p and .task.id == $t) | "\(.spent_date)|\(.id)|\(.hours)|\(.notes|length)|\(.is_locked)"')

if [[ -z "$entries" ]]; then
    log "no entries in range; nothing to reconcile"
    exit 0
fi

# --- partition: manual (>=8) locked+rounded, auto (<8) to be distributed ---
locked_sum=0
typeset -a AUTO_IN   # "id notelen datenum" per auto day
while IFS='|' read -r d id hrs nlen locked; do
    [[ -z "$id" ]] && continue
    if [[ "$locked" == "true" ]]; then
        # Submitted/approved day: immutable. Count its hours toward the target and never PATCH it.
        log "locked $d ${hrs}h (skipped)"
        locked_sum=$(( locked_sum + hrs ))
        continue
    fi
    if (( hrs >= 8 )); then
        rounded=$(round_up_quarter "$hrs")
        if (( rounded != hrs )); then
            harvest_api PATCH "/time_entries/${id}" "$(jq -n --argjson h "$rounded" '{hours:$h}')" >/dev/null \
                && log "manual $d $hrs -> ${rounded}h (rounded)"
        else
            log "manual $d ${hrs}h (locked)"
        fi
        locked_sum=$(( locked_sum + rounded ))
    else
        AUTO_IN+=("$id $nlen ${d//-/}")
    fi
done <<<"$entries"

if (( ${#AUTO_IN} == 0 )); then
    log "no auto days; locked total ${locked_sum}h (target ${TARGET})"
    exit 0
fi

# remaining hours for auto days, in quarter-hour units
remaining=$(( TARGET - locked_sum ))
RQ=$(awk -v r="$remaining" 'BEGIN{ printf "%d", r*4 + 0.5 }')
CAP=31   # 7.75h
FLOOR=20 # 5h — keeps auto days believable; dropped automatically if the target is too low
ndays=${#AUTO_IN}

if (( RQ <= 0 )); then
    log "locked days already meet/exceed target (${locked_sum}h); leaving ${ndays} auto day(s) unchanged"
    exit 0
fi
if (( RQ > CAP * ndays )); then
    log "cap-bound: ${remaining}h across ${ndays} auto day(s) exceeds 7.75h each; overflow goes to the longest-note day"
fi

# --- distribute RQ quarters across auto days, weighted by notelen + per-day jitter ---
dist=$(print -l -- "${AUTO_IN[@]}" | awk -v RQ="$RQ" -v CAP="$CAP" -v FLOOR="$FLOOR" '
    { id[NR]=$1; w[NR]=$2; dn[NR]=$3; n=NR }
    END {
        # drop the floor if the target is too low to honor it across all days
        fl = (RQ >= FLOOR*n) ? FLOOR : 0
        total=0
        for (i=1;i<=n;i++) { jf=0.85+((dn[i]%31)/100.0); ww[i]=(w[i]<1?1:w[i])*jf; total+=ww[i] }
        sumq=0
        for (i=1;i<=n;i++) { q[i]=int(RQ*ww[i]/total+0.5); if(q[i]>CAP)q[i]=CAP; if(q[i]<fl)q[i]=fl; sumq+=q[i] }
        guard=0
        while (sumq!=RQ && guard<1000000) {
            guard++
            if (sumq<RQ) {
                best=-1; bw=-1
                for (i=1;i<=n;i++) if (q[i]<CAP && ww[i]>bw) { bw=ww[i]; best=i }
                if (best<0) break
                q[best]++; sumq++
            } else {
                best=-1; bw=1e18
                for (i=1;i<=n;i++) if (q[i]>fl && ww[i]<bw) { bw=ww[i]; best=i }
                if (best<0) break
                q[best]--; sumq--
            }
        }
        # cap-saturation fallback: every auto day pegged at the cap and still short,
        # so pour the remainder into the longest-note day (it may exceed the cap).
        if (sumq < RQ) {
            best=-1; bw=-1
            for (i=1;i<=n;i++) if (w[i]>bw) { bw=w[i]; best=i }
            if (best>=0) { q[best]+=RQ-sumq; sumq=RQ }
        }
        for (i=1;i<=n;i++) printf "%s %d\n", id[i], q[i]
        printf "SUMQ %d\n", sumq
    }')

# --- apply ---
applied=0
while read -r id q; do
    [[ "$id" == "SUMQ" ]] && { final_q="$q"; continue; }
    hours=$(awk -v q="$q" 'BEGIN{ printf "%.2f", q/4 }')
    if harvest_api PATCH "/time_entries/${id}" "$(jq -n --argjson h "$hours" '{hours:$h}')" >/dev/null; then
        applied=$(( applied + 1 ))
    else
        log "ERROR patching entry ${id}"
    fi
done <<<"$dist"

final_hours=$(awk -v q="${final_q:-0}" 'BEGIN{ printf "%.2f", q/4 }')
week_total=$(awk -v a="$final_hours" -v l="$locked_sum" 'BEGIN{ printf "%.2f", a+l }')
log "distributed ${final_hours}h across ${applied} auto day(s); week total ${week_total}h (target ${TARGET})"
