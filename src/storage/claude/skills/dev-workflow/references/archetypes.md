# Model archetypes

Picking an agent configuration is one question: **what is the simplest configuration that solves this correctly?** These archetypes are how that question gets answered out loud, so the user can agree or disagree with the reasoning rather than the model name.

| Model  | Archetype                                                                                  | Relative cost | Trust it with                                                                                                        |
| ------ | ------------------------------------------------------------------------------------------ | ------------- | -------------------------------------------------------------------------------------------------------------------- |
| haiku  | An intern on coffee. Fast, tireless, no judgment.                                          | 1             | Work a test verifies mechanically. It will iterate against a red test as many times as it takes. Cheaply and quickly |
| sonnet | An entry-to-mid level engineer who rushes and does exactly what it was told, nothing more. | 3             | Complete cards. Anything requiring it to notice something unstated will be missed.                                   |
| opus   | A senior engineer.                                                                         | 5             | Judgment, ambiguity, work that spans modules.                                                                        |
| fable  | An outsourced senior. Far more expensive.                                                  | 10            | Use only as an advisor on the most critical, load bearing code paths.                                                |

Costs are per-token price ratios normalized to haiku — the same figures as `optimize-usage`'s lever table expressed against a different baseline. Update both together.

## Applying it

- **The archetype is how you decide and how you explain. It is never what you dispatch.** Every card records a real model id — `haiku`, `sonnet`, `opus`, or `fable` — and that id is what goes in the `model` opt. An archetype name or an alias name never reaches a dispatch call.
- Name the archetype, not the model, when recommending to the user: "this punishes someone who does exactly what they were told and nothing more" is reviewable; "sonnet on the deduplicator" is not.
- Every task card carries a model. Mechanical work with a test behind it defaults to `MECHANICAL_WORKER_MODEL`; work needing judgment defaults to `JUDGMENT_WORKER_MODEL`. Resolve the alias to its model id when you write the card — the card must read `opus`, not `JUDGMENT_WORKER_MODEL`.
- Those two aliases are budget defaults owned by `optimize-usage`. A card may name a stronger model than its default when the task genuinely warrants it; say why on the card. The lever is a default, not a ceiling.
