# Lever impact

One number per lever, 0-100: how much degrading this lever degrades the final deliverable. Session model = 100 is the anchor — never step it lightly.

| Lever | Impact | Why |
|---|---|---|
| Session model | 100 | Defines the entire solution space — plan, scope, tests, review standards. Every downstream token executes its decisions, so its errors compound through the whole ticket. Nothing gates it. |
| Review model | 60 | The last gate; its misses ship. Strong review is also what makes cheap workers safe — degrading it weakens every other lever's safety argument. |
| Session effort | 50 | Same blast radius as session model, but shallower per step: published data shows max/xhigh/high nearly equivalent, so steps here move quality less than model swaps. |
| Review effort | 35 | Thoroughness is the whole job of review; lower effort trims exactly the double-checking the role exists for. |
| Worker model | 25 | Executes fully specified task cards inside a solved problem, and every diff passes two gates. A month on sonnet showed no recorded quality drop. |
| Worker effort | 10 | Cards are scoped and gated; measured spend barely moves below high, and quality risk is bounded by review. |
| Research fan-out model | 8 | Deep-research fan-out (dev-workflow Step 3.1): read-and-summarize online research every tier is saturated on. Output is intermediate and the parent session model synthesizes it, so a cheap model here is near-free — the safest fan-out to cheapen first. |
| Code fan-out model | 20 | Codebase-fit fan-out (dev-workflow Step 3.2): analyzes real code to claim placement and reuse that shape the plan. A wrong reuse claim is the classic failure that step exists to catch; adversarial verification gates it, but degrade more cautiously than research fan-out. |
| Vault-scribe model | 15 (est.) | Writes knowledge-vault notes. Output is gated — the user approves a content summary before it lands — so errors are catchable, but notes are durable context for future sessions and quality drift compounds quietly. Unbenchmarked estimate (2026-07-21). |
