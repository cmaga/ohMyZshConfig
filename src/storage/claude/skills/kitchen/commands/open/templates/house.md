# Project rules

What gets checked on every change in this project. Every rule names what enforces it; a rule with no enforcer does not belong here. Rows are added as catches get promoted, and a row is deleted when a stronger rung makes it redundant.

## Settings

- **Gate:** `<one command that runs tests, lint, and build>`
- **Reach:** touched lines | touched files | neighborhood
- **Mutation:** stryker `<command that runs Stryker in this project>` | off: <reason>

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

Paths whose changes always wait for the user's review, one extended regular expression per line, written as - `<regex>` and what it covers. The lines below are defaults: keep the ones that fit this project and delete the rest. Deleted tests and silenced checks wait for the user whatever this list holds.

- `(^|/)(\.github/workflows/|\.gitlab-ci\.yml$|bitbucket-pipelines\.yml$|\.circleci/)` CI
- `(^|/)(\.pre-commit-config\.yaml$|\.husky/|\.eslintrc|eslint\.config\.|tsconfig[^/]*\.json$|\.prettierrc|biome\.jsonc?$|\.?ruff\.toml$|mypy\.ini$|\.golangci|pyproject\.toml$|setup\.cfg$|\.flake8$|tox\.ini$|pytest\.ini$|(jest|vitest)\.config\.)` lint, type, formatter and test-runner config
- `(^|/)\.claude/kitchen/house\.md$` these project rules
- `(^|/)\.claude/skills/verify[-/]` the verify skill
- `(^|[^A-Za-z])(auth|authn|authz|authentication|authorization|oauth|billing|payments?|migrations?|migrate|secrets?|security|crypto|permissions?)([^a-z]|$)|(Auth|Authn|Authz|Authentication|Authorization|Oauth|OAuth|Billing|Payments?|Migrations?|Migrate|Secrets?|Security|Crypto|Permissions?)([^a-z]|$)|(^|/)alembic/versions/` auth, billing, payment, migration, secret, security, crypto and permission paths
- `<e.g. ^src/ledger/>`

## Review when

Questions the verifying session answers for every change, one per line, written as - <question>. A yes sends the PR to the user with the question and why. Ask here what no path shows, such as what a change costs or whether it changes what a feature is meant to do. This section and `## Always review` stay in the file even when empty: kitchen treats a project missing either as not set up.

- <e.g. Does it raise what the project costs to run?>

## Sorting

Rules intake applies before its own judgment when it sets a ticket's flags.

- <e.g. Tickets labelled `design` or carrying a Figma link go to the review queue.>

## Production

How `/kitchen fire` reaches production in an incident. Optional: what is missing is asked during the incident.

- **Errors:** `<the error tracker and its project>`
- **Logs and metrics:** `<where they live and how to query them>`
- **Data:** `<how to read production data read-only>`
- **Deploys:** `<how a deploy ships and how it is rolled back>`
- **Flags:** `<the feature-flag tool, if any>`
- **Direct pushes:** yes | no, whether the default branch takes them
