# Scope

- Identify what changes are required to implement the chosen solution.
- Identify affected files — search symbols, read neighbors.
- Identify relevant documentation on the affected files and systems.
- Read similar existing implementations for pattern reference. If the established pattern is bad, call it out — do not silently propagate tech debt.
- If the change hinges on a third-party API's behavior or payload, fetch the provider's docs and read the existing integration / verifier code for that API.
- If the change creates or modifies user-facing UI, use the `frontend-design` skill for the visual/design pass and carry its direction into the [scaffold](scaffold.md) so workers inherit it as structure, not as prose.
- The mock-first prototype go/no-go was decided when the solution was presented in Step 4 — do not re-raise it here. If a prototype was built, its approved shape pins the data contract: express that contract in the scaffold's types.

This step ends where [shape](shape.md) begins. Scope is what you learned; shape is what you draw from it.
