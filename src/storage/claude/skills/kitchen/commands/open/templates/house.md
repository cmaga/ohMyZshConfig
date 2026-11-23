# House rules

## Project conventions

What every change in this project follows, including the industry practices that apply to it. Each convention ends with what enforces it: a script listed at the bottom of this section, `review: project` for the project reviewer, which reads every convention so tagged, `review: <check>` for one of kitchen's general checks, or `my review` when its PR waits for me. "as in" names a file to copy.

### <topic>

- <convention>, as in `<file to copy>`. `<script name>`, `review: project`, `review: <check>`, or `my review`

### Enforcement scripts

| Name | Command |
|---|---|
| `<script name>` | `<command>` |

## Kitchen setup

How kitchen works this project.

- **Gate:** `<one command that runs every enforcement script above and the project's other checks, fastest first, stopping at the first failure>`
- **Reach:** touched lines | touched files | neighborhood, how far reviewers may tidy.
- **Mutation:** stryker `<command that runs Stryker in this project>` | off: <reason>

### Critical paths

<What makes a path critical in this project: where a mistake loses money or data, exposes it, or weakens a check that guards it.>

**Extra effort:** code on the path is written by the critical-code agent, and every other agent on it runs one effort step higher, reviews included. **Waits for me:** a PR that touches the path waits for my review, unless its order named the path at intake. Deleted tests and silenced checks always wait.

| Path | What it is | Extra effort | Waits for me |
|---|---|---|---|
| `(^\|/)(\.github/workflows/\|\.gitlab-ci\.yml$\|bitbucket-pipelines\.yml$\|\.circleci/)` | CI | no | yes |
| `(^\|/)(\.pre-commit-config\.yaml$\|\.husky/\|\.eslintrc\|eslint\.config\.\|tsconfig[^/]*\.json$\|\.prettierrc\|biome\.jsonc?$\|\.?ruff\.toml$\|mypy\.ini$\|\.golangci\|pyproject\.toml$\|setup\.cfg$\|\.flake8$\|tox\.ini$\|pytest\.ini$\|(jest\|vitest)\.config\.)` | lint, type, formatter and test-runner config | no | yes |
| `(^\|/)\.claude/kitchen/house\.md$` | these project rules | no | yes |
| `(^\|/)\.claude/skills/verify[-/]` | the verify skill | no | yes |
| `(^\|[^A-Za-z])(auth\|authn\|authz\|authentication\|authorization\|oauth\|billing\|payments?\|migrations?\|migrate\|secrets?\|security\|crypto\|permissions?)([^a-z]\|$)\|(Auth\|Authn\|Authz\|Authentication\|Authorization\|Oauth\|OAuth\|Billing\|Payments?\|Migrations?\|Migrate\|Secrets?\|Security\|Crypto\|Permissions?)([^a-z]\|$)\|(^\|/)alembic/versions/` | auth, billing, payment, migration, secret, security, crypto and permission paths | no | yes |
| `<e.g. ^src/ledger/>` | <what it is> | yes | yes |

### Questions that hold a PR

The final review answers each for every change; a yes holds the PR for my review.

- <e.g. Does it raise what the project costs to run?>

### Intake defaults

- <e.g. Tickets labelled `design` or carrying a Figma link are manual.>

### Docs

- <e.g. Public API changes: the reference under `docs/api/`>

### Production

- **Errors:** `<the error tracker and its project>`
- **Logs and metrics:** `<where they live and how to query them>`
- **Data:** `<how to read production data read-only>`
- **Deploys:** `<how a deploy ships and how it is rolled back, or the skill that does it>`
- **Flags:** `<the feature-flag tool, if any>`
- **Direct pushes:** yes | no, whether the default branch takes them
