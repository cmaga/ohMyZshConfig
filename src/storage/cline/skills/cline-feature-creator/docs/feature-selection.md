# Feature Selection Guide

Use this decision table to recommend the right Cline feature type based on user intent.

| Need                | Feature      | Token Cost                        | Activation                        |
| ------------------- | ------------ | --------------------------------- | --------------------------------- |
| Behavioral guidance | Rule         | Always loaded (~50 tokens)        | Automatic (always or conditional) |
| Domain expertise    | Skill        | On-demand (metadata: ~100 tokens) | Triggered by description match    |
| Task automation     | Workflow     | On-demand                         | User invokes with `/name.md`      |
| Quality enforcement | Hook         | Zero (runs as script)             | Automatic on events               |
| File exclusion      | .clineignore | Negative (helps save tokens)      | Always active                     |

## Special Considerations

Generally, you want to suggest the simplest, cheapest, and most deterministic option available.
For example, a lot of times a workflow can be just a regular zsh script. Or a simple workflow and zsh combination
for ease of use. The simpler, the feature, the easier it is to use and maintain.

## Combination Patterns

Sometimes the right answer is multiple features working together:

### Rule + Hook (Define + Enforce)

When you want both guidance and hard enforcement:

- **Rule**: Tells Cline the convention (soft guidance)
- **Hook**: Blocks violations programmatically (hard enforcement)

### Workflow + Hook (Automate + Gate)

When a workflow needs quality checks:

- **Workflow**: The step-by-step process
- **Hook**: Automatic validation at key moments during the workflow

## Quick Reference

| Need                | Feature      | Token Cost                        | Activation                        |
| ------------------- | ------------ | --------------------------------- | --------------------------------- |
| Behavioral guidance | Rule         | Always loaded (~50 tokens)        | Automatic (always or conditional) |
| Domain expertise    | Skill        | On-demand (metadata: ~100 tokens) | Triggered by description match    |
| Task automation     | Workflow     | On-demand                         | User invokes with `/name.md`      |
| Quality enforcement | Hook         | Zero (runs as script)             | Automatic on events               |
| File exclusion      | .clineignore | Zero                              | Always active                     |
