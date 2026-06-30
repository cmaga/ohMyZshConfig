# Scope

- Identify what changes are required to implement the chosen solution.
- Identify affected files — search symbols, read neighbors.
- Identify relevant documentation on the affected files and systems.
- Read similar existing implementations for pattern reference. If the established pattern is bad, call it out — do not silently propagate tech debt.
- If the change hinges on a third-party API's behavior or payload, fetch the provider's docs and read the existing integration / verifier code for that API.
- If the change creates or modifies user-facing UI, use the `frontend-design` skill for the visual/design pass and carry its direction into the plan's task cards so workers apply it.
