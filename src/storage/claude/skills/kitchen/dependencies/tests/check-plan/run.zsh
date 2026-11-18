#!/usr/bin/env zsh
# Runs check-plan.mjs over the fixtures: the passing pair is silent, each failing
# fixture names its rule's problem, and the multi-phase format is unchanged.
set -u
here="${0:A:h}"
script="$here/../../../commands/cook/scripts/check-plan.mjs"
failures=0

check() {
	print -u2 -- "FAIL: $1"
	failures=$((failures + 1))
}

out="$(node "$script" "$here/plan.md" "$here/spec.md" 2>&1)"
rc=$?
[[ $rc -eq 0 && -z "$out" ]] || check "passing pair: rc=$rc output=$out"

# plan | spec | message the check must print
cases=(
	"fixtures/rule1-no-proof.md|spec.md|Deployment 2 lacks a \"- **Proof:**\" line"
	"fixtures/rule2-skeleton-name.md|spec.md|Deployment 1 Phase 1 is not named Skeleton"
	"fixtures/rule3-no-work.md|spec.md|D1.P2.T2 lacks a \"- **Work:**\" line"
	"fixtures/rule4-same-phase.md|spec.md|D1.P2.T2 depends on D1.P2.T1, in its own phase or a later one"
	"fixtures/rule5-shared-dir.md|spec.md|D1.P2.T1 and D1.P2.T2 share a file in one phase"
	"fixtures/rule6-producer-consumer.md|spec.md|D1.P2.T1 produces DEC-1, which D1.P2.T2 consumes in the same phase"
	"fixtures/rule7-no-fan-out.md|spec.md|Deployment 1 Phase 2 holds 2 tasks and has no \"- **Fan-out:**\" line"
	"fixtures/rule8-unlisted-dec.md|spec.md|D1.P2.T2 cites DEC-9, which is not listed under Decisions"
	"fixtures/rule9-unknown-table-task.md|spec.md|row names task \"D9.P1.T1\", which does not exist"
	"plan.md|fixtures/rule10-spec.md|spec id FR-2 is missing from the Coverage table"
)
for entry in $cases; do
	parts=("${(@s:|:)entry}")
	out="$(node "$script" "$here/$parts[1]" "$here/$parts[2]" 2>&1)"
	rc=$?
	want=$parts[3] name=$parts[1]
	[[ $rc -ne 0 && "$out" == *"$want"* ]] || check "$name: rc=$rc want [$want] got [$out]"
done

# The multi-phase path must print what it printed before the implementation checks existed.
legacy="$(mktemp -d)"
trap 'rm -rf "${legacy:?}"' EXIT
cat > "$legacy/plan.md" <<'PLAN'
# Demo plan

Short intro.

## How to read this

Nothing here.

## Program checklist

### File the tickets

- [ ] Nothing.

## Close the program

- [ ] Done: now.
PLAN
git -C "$here" show HEAD:src/storage/claude/skills/kitchen/commands/cook/scripts/check-plan.mjs > "$legacy/old.mjs"
old="$(node "$legacy/old.mjs" "$legacy/plan.md" 2>&1 | sed "s#$legacy/#X/#")"
new="$(node "$script" "$legacy/plan.md" 2>&1 | sed "s#$legacy/#X/#")"
[[ -n "$old" && "$old" == "$new" ]] || check "multi-phase output changed"$'\n'"old: $old"$'\n'"new: $new"

(( failures == 0 )) && print "check-plan: all passed" || { print -u2 "check-plan: $failures failed"; exit 1; }
