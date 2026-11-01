# Enforce

Make the project enforce one kind of slip its reviewers keep catching. Its tickets are titled "Enforce <class>".

A promotion: a kind of slip the quality gate caught twice (or the user caught once) becomes something the project enforces, so no reviewer has to catch it again. This recipe runs the [correct](../stations/correct.md) station on the one class the ticket names.

1. **Read the catches** the ticket lists for its class: what slipped, where, and in which orders. They are the evidence the correct station's search for mistake classes would find, so skip that search.
2. **Pick the highest rung that works**, trying the correct station's levels in order. The PR says why each higher rung did not work. Architecture is new structure other code depends on, so it needs the user's answer at the pass; without one, take the next rung down and say why in the PR. A ticket whose intent says "at least one rung above" an earlier ticket's starts above the rung that ticket used, since that enforcement did not take.
3. **Prove it.** The enforcement fails on each original slip and passes on the base branch. Reconstruct a slip in a scratch commit if it no longer exists. Run the same command locally and in CI. Paste both outputs in the PR.
4. When the pattern already exists across the codebase, fail only on new instances, and say how many old ones remain. An exception to the enforcement sits on the offending line with its reason and an expiry date; the user approves it in review.
5. **Record it** in `.claude/kitchen/house.md`, the project's rule table: add or update the row with the rule, its enforcer, the rung, and the catches. Delete any lower-rung row this one makes redundant.
6. Run the [open a PR](open-a-pr.md) recipe.

**Reply:** the class with its catches, the rung you picked and why each higher rung did not work, and the proof that it fails on a real slip.
