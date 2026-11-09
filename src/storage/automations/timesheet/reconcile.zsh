#!/usr/bin/env zsh
# Square the just-ended Sun-Sat week's Harvest hours to the weekly target (40h),
# across every managed project. Run AFTER the week's days are filled.
#
#   - Fixed hours, never changed: locked entries, entries under projects this
#     config does not manage (meetings, holidays), and manual days: any day whose
#     entries total 8h or more (an entry of 8h+ is rounded UP to the next .25).
#   - The rest of the target goes to the auto entries. A project with a weekly
#     cap (<key>_cap) gets its share of the week's activity, up to the cap; the
#     one project without a cap takes what is left. Activity is each day's note
#     length, the only per-day evidence Harvest holds.
#   - Within a project, hours follow each day's activity, and an auto day stays
#     under 8h counting that day's fixed hours, so it never reads as manual. If
#     the days cannot hold a project's hours, its longest-note day takes the rest.
#   - With no uncapped project in the week (say, only capped work), the hours
#     left over are reported, not logged.
#
# Idempotent: the same entries give the same numbers on every run. Never submits.
#
# Usage: reconcile.zsh [START END]   (default: the just-ended Sun-Sat week)

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
source "${SCRIPT_DIR}/harvest-lib.zsh"

TARGET=$(ts_int weekly_target); TARGET=${TARGET:-40}

if [[ -n "${1:-}" && -n "${2:-}" ]]; then
    START="$1"; END="$2"
else
    read START END <<<"$(prev_week_range)"
fi

log() { print -- "[$(date '+%Y-%m-%d %H:%M:%S')] reconcile: $*"; }

require_credentials || exit 1

# Resolve every managed project; "pid:tid key" pairs and "key=cap" caps for awk.
typeset -a PAIRS CAPS
REMAINDER=""
for key in ${=$(project_keys)}; do
    if [[ -z "$(project_name_for "$key")" ]]; then
        log "$key: no Harvest project set in $TIMESHEET_CONFIG, so its entries count as fixed"
        continue
    fi
    resolve_project_task "$(project_name_for "$key")" "$(task_name_for "$key")" || exit 1
    PAIRS+=("$PROJECT_ID:$TASK_ID=$key")
    cap=""
    [[ "$key" != default ]] && cap=$(ts_int "${key}_cap")
    if [[ -n "$cap" ]]; then
        CAPS+=("$key=$cap")
    elif [[ -n "$REMAINDER" ]]; then
        echo "reconcile: '$REMAINDER' and '$key' both have no cap; exactly one project takes the remainder" >&2
        exit 1
    else
        REMAINDER="$key"
    fi
done

log "week ${START}..${END}, target ${TARGET}h, projects: ${(j: :)${PAIRS[@]#*=}}"

body=$(harvest_api GET "/time_entries?from=${START}&to=${END}&per_page=2000") || { echo "reconcile: fetch failed" >&2; exit 1; }

# date|id|key|hours|notelen|is_locked, key "-" for a project this config does not manage
entries=$(print -r -- "$body" | jq -r --arg pairs "${(j:,:)PAIRS}" '
    ($pairs | split(",") | map(split("=") | {key: .[0], value: .[1]}) | from_entries) as $m |
    .time_entries[] |
    "\(.spent_date)|\(.id)|\($m["\(.project.id):\(.task.id)"] // "-")|\(.hours)|\(.notes // "" | length)|\(.is_locked)"')

if [[ -z "$entries" ]]; then
    log "no entries in range; nothing to reconcile"
    exit 0
fi

# Plan the week in one awk pass. Quarter-hour units throughout; 31 = 7.75h.
plan=$(print -r -- "$entries" | awk -F'|' -v TARGET="$TARGET" -v CAPS="${(j:,:)CAPS}" -v RK="$REMAINDER" '
    function qtr(h) { return int(h * 4 + 0.5) }
    function ceilq(h,  q) { q = h * 4; return (q > int(q) + 1e-9) ? int(q) + 1 : int(q) }
    # Spread RQ quarters over key k'"'"'s auto entries by note length, each under its
    # day'"'"'s room (31 minus what the day already holds), with a floor when it fits.
    function spread(k, RQ, fl,   j, m, ix, w, cap, flo, q, tot, sumq, best, bw, g) {
        m = 0
        for (j = 1; j <= n; j++) if (AUTO[j] && K[j] == k) ix[++m] = j
        if (m == 0 || RQ <= 0) return 0
        tot = 0
        for (j = 1; j <= m; j++) {
            w[j] = (NL[ix[j]] < 1) ? 1 : NL[ix[j]]; tot += w[j]
            cap[j] = 31 - USED[D[ix[j]]]; if (cap[j] < 0) cap[j] = 0
        }
        if (RQ < fl * m) fl = 0
        sumq = 0
        for (j = 1; j <= m; j++) {
            flo[j] = (fl < cap[j]) ? fl : cap[j]
            q[j] = int(RQ * w[j] / tot + 0.5)
            if (q[j] > cap[j]) q[j] = cap[j]
            if (q[j] < flo[j]) q[j] = flo[j]
            sumq += q[j]
        }
        for (g = 0; sumq != RQ && g < 100000; g++) {
            best = 0
            if (sumq < RQ) {
                bw = -1; for (j = 1; j <= m; j++) if (q[j] < cap[j] && w[j] > bw) { bw = w[j]; best = j }
                if (!best) break
                q[best]++; sumq++
            } else {
                bw = 1e18; for (j = 1; j <= m; j++) if (q[j] > flo[j] && w[j] < bw) { bw = w[j]; best = j }
                if (!best) break
                q[best]--; sumq--
            }
        }
        if (sumq < RQ) {
            best = 1; for (j = 2; j <= m; j++) if (w[j] > w[best]) best = j
            q[best] += RQ - sumq
            printf "LOG %s: its days cannot hold %.2fh under 8h each; the longest-note day takes the rest\n", k, RQ / 4
            sumq = RQ
        }
        for (j = 1; j <= m; j++) { USED[D[ix[j]]] += q[j]; printf "SET %s %.2f %s %s\n", ID[ix[j]], q[j] / 4, k, D[ix[j]] }
        return sumq
    }
    { n++; D[n] = $1; ID[n] = $2; K[n] = $3; H[n] = $4 + 0; NL[n] = $5 + 0; LK[n] = $6; DAY[$1] += $4 }
    END {
        ncap = split(CAPS, cp, ",")
        for (i = 1; i <= ncap; i++) { split(cp[i], kv, "="); CAPQ[kv[1]] = kv[2] * 4; CORD[i] = kv[1] }
        fixed = 0
        for (i = 1; i <= n; i++) {
            if (LK[i] == "true") {
                fixed += H[i]; USED[D[i]] += qtr(H[i]); printf "LOG locked %s %.2fh %s (kept)\n", D[i], H[i], K[i]
            } else if (K[i] == "-") {
                fixed += H[i]; USED[D[i]] += qtr(H[i]); printf "LOG other  %s %.2fh (another project, kept)\n", D[i], H[i]
            } else if (DAY[D[i]] >= 8) {
                h = H[i]
                if (h >= 8 && ceilq(h) / 4 != h) { h = ceilq(h) / 4; printf "ROUND %s %.2f %s %s\n", ID[i], h, K[i], D[i] }
                else printf "LOG manual %s %.2fh %s (kept)\n", D[i], h, K[i]
                fixed += h; USED[D[i]] += qtr(h)
            } else {
                AUTO[i] = 1; W[K[i]] += (NL[i] < 1) ? 1 : NL[i]; WT += (NL[i] < 1) ? 1 : NL[i]
            }
        }
        avail = qtr(TARGET - fixed)
        if (avail <= 0) { printf "LOG fixed hours (%.2fh) already meet the %sh target; auto days unchanged\n", fixed, TARGET; exit }
        if (WT == 0) { printf "LOG no auto days; %.2fh left for the target, not logged\n", avail / 4; exit }
        given = 0
        for (i = 1; i <= ncap; i++) {
            k = CORD[i]; if (!(k in W)) continue
            t = int(avail * W[k] / WT + 0.5); if (t > CAPQ[k]) t = CAPQ[k]
            given += spread(k, t, 0)
        }
        left = avail - given
        if (RK != "" && (RK in W)) {
            given += spread(RK, left, 20); left = 0
        }
        if (left > 0) printf "LOG %.2fh of the %sh target left unassigned: no %s work this week\n", left / 4, TARGET, (RK == "" ? "uncapped" : RK)
        printf "LOG week total %.2fh (fixed %.2fh, auto %.2fh)\n", fixed + given / 4, fixed, given / 4
    }')

# Apply the plan
rc=0
while read -r verb id hours key day; do
    case "$verb" in
        LOG) log "$id $hours $key $day" ;;
        ROUND|SET)
            if harvest_api PATCH "/time_entries/${id}" "$(jq -n --argjson h "$hours" '{hours:$h}')" >/dev/null; then
                if [[ $verb == ROUND ]]; then log "manual $day ${hours}h $key (rounded up)"; else log "auto   $day ${hours}h $key"; fi
            else
                log "ERROR patching entry ${id}"; rc=1
            fi
            ;;
    esac
done <<<"$plan"
exit "$rc"
