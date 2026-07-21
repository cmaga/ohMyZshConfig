#!/usr/bin/env python3
"""Aggregate benchmark results into an honest lever table.

Metric = total_cost_usd, which is price-weighted token volume == subscription
session-limit draw up to a constant (per-model weights track API prices; the
session limit is price-weighted). It is NOT a bill.

Decomposes each cell into per-turn price (stable) x turn count (noisy), flags
any run whose bound model is not in the requested model's family (the --model
alias trap), and averages each lever's effect across tasks so it generalizes.

Models are referred to by alias (family) wherever possible; BASE_MODEL below
matches any bound ID containing it, so version bumps need no edit here.
"""
import csv, sys, math, statistics as st
from collections import defaultdict

RESULTS = sys.argv[1] if len(sys.argv) > 1 else "results.tsv"
rows = list(csv.DictReader(open(RESULTS), delimiter="\t"))

def short(m):
    return (m.replace("claude-", "").replace("-4-5-20251001", "")
             .replace("-4-8", "").replace("-5", "").replace("-4-6", "46"))

# --- integrity: drop runs where the bound model is outside the requested family.
# Requests may be aliases ("opus") or full IDs; either must appear in the bound ID.
invalid = [r for r in rows if r["model"] not in r["bound_model"]]
valid = [r for r in rows if r["model"] in r["bound_model"]]
if invalid:
    print(f"DROPPED {len(invalid)} run(s) with model mismatch (alias trap):")
    for r in invalid:
        print(f"  requested {short(r['model'])}/{r['effort']} but ran {short(r['bound_model'])}")
    print()

def cv(xs):
    m = st.mean(xs)
    return (st.pstdev(xs) / m) if len(xs) > 1 and m else 0.0

cells = defaultdict(list)
for r in valid:
    cells[(r["task"], r["model"], r["effort"])].append(r)

print("PER-CELL  (metric = limit draw; cost/turn isolates the per-turn price)\n")
hdr = f"{'task':16}{'model':8}{'eff':5}{'n':>3}  {'outcomes':16}{'cost':>9}{'CV':>6}{'turns':>7}{'$/turn':>8}"
print(hdr); print("-" * len(hdr))
for k in sorted(cells):
    rs = cells[k]
    costs = [float(r["cost_usd"]) for r in rs]
    turns = [float(r["turns"]) for r in rs]
    cpt = [c / t for c, t in zip(costs, turns) if t]
    oc = defaultdict(int)
    for r in rs: oc[r["outcome"]] += 1
    ocs = " ".join(f"{v}{k2[0]}" for k2, v in sorted(oc.items()))
    print(f"{k[0]:16}{short(k[1]):8}{k[2]:5}{len(rs):>3}  {ocs:16}"
          f"{st.mean(costs):>9.4f}{cv(costs):>6.0%}{st.mean(turns):>7.1f}{st.mean(cpt):>8.4f}")

# --- lever effects: normalize each cost by that task's baseline, then average across tasks ---
BASE_MODEL = "opus"   # family alias — matches any bound/requested ID containing it
BASE_EFF = "high"

print(f"\nLEVER EFFECT (cost vs {BASE_MODEL}/{BASE_EFF} baseline, averaged across tasks)\n")
tasks = sorted({r["task"] for r in valid})
def cell_mean(task, model, eff):
    rs = cells.get((task, model, eff))
    return st.mean([float(r["cost_usd"]) for r in rs]) if rs else None

def fam_mean(task, alias, eff):
    xs = [float(r["cost_usd"]) for (t, m, e), rs in cells.items() if t == task and alias in m and e == eff for r in rs]
    return st.mean(xs) if xs else None

def report(label, model, eff):
    ratios = []
    for t in tasks:
        base = fam_mean(t, BASE_MODEL, BASE_EFF)
        cur = fam_mean(t, model, eff)
        if base and cur:
            ratios.append(cur / base)
    if not ratios:
        return
    m = st.mean(ratios)
    print(f"  {label:20} {m:5.2f}x baseline  ({100*(m-1):+.0f}%)   [tasks: {', '.join(f'{r:.2f}' for r in ratios)}]")

if not any(fam_mean(t, BASE_MODEL, BASE_EFF) for t in tasks):
    print(f"  no {BASE_MODEL}/{BASE_EFF} baseline rows in this file — lever effects skipped")

# model lever: every model seen at effort=high; effort lever: every effort seen on the baseline family
models_hi = sorted({r["model"] for r in valid if r["effort"] == "high"})
effs_base = sorted({r["effort"] for r in valid if BASE_MODEL in r["model"]})
for mdl in models_hi:
    report(f"model {short(mdl)}/high", mdl, "high")
for eff in effs_base:
    report(f"{BASE_MODEL}/{eff}", BASE_MODEL, eff)

# --- N required, from observed within-cell CV ---
cvs = [cv([float(r["cost_usd"]) for r in rs]) for rs in cells.values() if len(rs) > 1]
if cvs:
    cvm = st.mean(cvs)
    print(f"\nObserved within-cell CV (mean): {cvm:.0%}")
    for eff in (0.25, 0.40):
        print(f"  N to resolve a {eff:.0%} effect: n≈{math.ceil(15.68*cvm**2/eff**2)}/cell")

allc = [float(r["cost_usd"]) for r in rows]
print(f"\nTotal draw this run: ${sum(allc):.2f} across {len(rows)} runs")