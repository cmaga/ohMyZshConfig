# Recommendation presentation

The recommendation is a decision brief, not a research report. The user is approving a direction and a tier — everything they need for that fits in a short message. Detail lives in the architecture artifact and later in `plan.md`; offer it, don't push it.

## Shape

1. **Recommendation** — one bolded line naming the approach
2. **Why** — one or two lines on the problem it solves, in outcomes not mechanisms
3. **How** — at most three bullets, one per major move, each with its expected effect
4. **Tradeoff** — the one or two things this costs
5. **Tier** — the tier and a half-line of why
6. **Artifact link** — if one was rendered
7. **The ask** — approve the approach and tier, or name a different tier; plus `Say "detail" for the evidence.`

Hard cap 15 lines. Past that you are re-litigating research the user did not ask to see.

## Cut these

- Research recap, methodology, or what sources said
- Corrections to numbers or claims you made earlier in the session — carry the corrected value silently
- What adversarial verification killed, changed, or confirmed
- Code symbols, file paths, config keys, endpoint names
- Anything already in the artifact

The killed claims and verification findings still matter — they go into `plan.md`, where the implementer reads them.

Plain language throughout. Same register as the artifact: short sentences for a smart reader who doesn't live in our vocabulary.

If the user says `detail`, expand one topic at a time and stop for their next word. Never volunteer the expansion unasked.
