# Refresh levers

Keeps the lever table complete and current. Run on request or after a Freeform pass that changed the landscape.

1. **Models and pricing.** Fetch the current catalog via the `claude-api` skill. Update the Options columns (add new models, drop retired ones) and re-price at current per-token rates.
2. **Benchmarks.** Look up the latest published model and effort benchmarks; update the impact numbers and rationale in [lever-impact.md](../references/lever-impact.md) if the evidence moved.
3. **Re-measure** the draw mix from the cost tracker per [cost-queries.md](../references/cost-queries.md), recompute the pt-of-draw cost columns, and write the dated baseline artifact. If the tracker is down or its history is shorter than the measurement window, fall back to [log-analysis.md](../references/log-analysis.md).
4. **New levers only.** Diff the repo config surface (`agents/*.md` frontmatter, dev-workflow dispatch files, `settings.json`) against the table; one `claude-code-guide` query catches newly added settings keys or env vars. Surface only levers that are genuinely new — never re-recommend anything on the exclusion list in levers.md.
5. **Update the table**: rows, options, cost and impact figures, and the `Last updated` date. Show the user the levers.md diff before writing — the table drives every future recommendation.
