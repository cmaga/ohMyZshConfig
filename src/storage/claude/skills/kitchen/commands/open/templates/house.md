# Project rules

What gets checked on every change in this project. Every rule names what enforces it; a rule with no enforcer does not belong here. Rows are added as catches get promoted, and a row is deleted when a stronger rung makes it redundant.

## Settings

- **Gate:** `<one command that runs tests, lint, and build>`
- **Reach:** touched lines | touched files | neighborhood

## Rules

| Rule | Enforced by | Rung | Catches |
|---|---|---|---|
| <rule> | `check: <command>` or `taster: <name>` | structure, types, lint, test, or rule | <ticket keys> |

## Tasters

A project-defined reviewer is `- <name>: <what it looks for>`.

- tidy
- consistency
- test-honesty
- minimal
- gaming

## Critical

Paths where a mistake loses money, data, or a safety check, one extended regular expression per line, written as - `<regex>`. Work on them runs one effort step higher on every role, review included.

- `<e.g. ^src/orders/>`

## Always review

Paths whose changes always wait for the user's review, one extended regular expression per line, written as - `<regex>`, on top of the built-in ones: CI, lint, type, test-runner, and formatter config, these project rules, the verify skill, deleted tests, silenced checks, and auth, billing, payment, migration, secret, security, crypto, and permission paths.

- `<e.g. ^src/ledger/>`

## Sorting

Rules intake applies before its own judgment when it sets a ticket's flags.

- <e.g. Tickets labelled `design` or carrying a Figma link go to the pass.>
