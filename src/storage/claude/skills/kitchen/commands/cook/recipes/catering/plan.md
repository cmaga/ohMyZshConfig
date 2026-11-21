# Plan

Turns the ticket into a plan the user approves: the context and goals agreed, the investigation, the direction, and the plan document, for them or an engineering team to review. Intake already agreed the scope with the user, as the order's `intent`; step 1 starts from it and asks only what is still open.

Keep the documents out of git first: `F="$(git rev-parse --git-common-dir)/info/exclude"; grep -qxF '.claude-artifacts/' "$F" || echo '.claude-artifacts/' >> "$F"`. The documents directory is `<docs>`, the absolute path of `.claude-artifacts/workflows/kitchen/<KEY>/` in this worktree: `kitchen.zsh order set <KEY> stage=plan docs=<docs>`.

1. **Agree the context and goals.** The scope, the goals, what is out of scope (what a reader could reasonably expect it to do, ruled out, and what owns it instead), and the requirements any solution must meet. Ask nothing yet about how to solve it: the user keeps their own lean to themselves until step 3, so it does not anchor the recommendation. Write each agreed point into the plan's Context and scope or Goals and out of scope, from the [plan template](../../templates/plan-template.md) copied to `<docs>/plan.md`.
2. **Investigate**, in the background while step 1 goes on where it can:
   - the [how](../../stations/how.md) station on the code the work touches, and the [why](../../stations/why.md) station where the intent of existing behavior matters;
   - the [look it up](../../../../dependencies/principles/look-it-up.md) principle for how others solved it and current practice for the stack;
   - the [prototype](../prototype.md) recipe for any fork a run can settle.
   Every fact ends confirmed at `file:line`, by a run, or by a cited source.
3. **Recommend, then hear their lean.** Send the recommendation at a high level: the direction, its basis, and each alternative with why it loses. Then ask for their lean. Where the two differ, discuss one point at a time until a direction is agreed. A difference in structure gets competing sketches per the [architect](../../stations/architect.md) station; the agreed direction goes through the [interrogate](../../stations/interrogate.md) station before it is written, and each finding that survives is put to the user.
4. **Write the plan.** Fill every section of `<docs>/plan.md` per the [technical writing](../../stations/technical-writing.md) and [unslop](../../stations/unslop.md) stations: 1 to 3 pages, no schemas or code. Rollout counts the deploys by the rule in [implementation](implementation.md#deployments). A question still open is put to the user now; Open questions is empty when the plan is done.
5. **The user's review**, per [catering](../catering.md#talking-to-the-user). On their go, `kitchen.zsh order set <KEY> stage=spec` and go on per [spec](spec.md).
