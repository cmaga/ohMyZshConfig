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
| Fan-out model | 10 | Read-and-summarize work every tier is saturated on; output is intermediate and gets consumed by the session model anyway. |
