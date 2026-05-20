# Vault Buckets

| Bucket          | Naming                                              | Purpose                                                                                                                                                                                        |
| --------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `decisions/`    | `ADR-NNN-kebab-name.md`                             | Architectural decisions (NNN = next available, zero-padded to 3 digits)                                                                                                                        |
| `constraints/`  | `constraint-kebab-name.md`                          | Rejection log, tech debt, non-negotiables                                                                                                                                                      |
| `domain/`       | `domain-kebab-name.md`                              | Business rules, ubiquitous language                                                                                                                                                            |
| `architecture/` | `architecture-kebab-name.md`                        | **Top-level / cross-cutting.** Umbrella system docs (deploy pipeline, cloud architecture) and flows that span multiple components (credit deduction end-to-end, job lifecycle, rollback flow). |
| `components/`   | `kebab-name.md`                                     | **One hub per major subsystem** (worker, billing, web-app, generation-engine). Bare kebab-case, no prefix.                                                                                     |
| `policies/`     | `policy-kebab-name.md`                              | Governance documents shared with external reviewers (regulators, vendors, auditors). Lifecycle-driven: each note has `steward` and `review_cadence` in frontmatter.                            |
| `customers/`    | `customer-kebab-name.md` or `persona-kebab-name.md` | ICPs, personas, customer pain                                                                                                                                                                  |
| `plan/`         | `<scope>.md` (e.g. `2026-Q2.md`)                    | Roadmap, strategy                                                                                                                                                                              |
| `research/`     | `research-kebab-name.md`                            | Spike notes, evaluations, experiment writeups                                                                                                                                                  |

## Architecture vs components — the decision rule

Ask: **does this note describe the inside of one subsystem, or how multiple subsystems interact?**

- One subsystem's internals, API surface, or hub-of-links → `components/<name>.md`.
- Two or more subsystems interacting, or an umbrella view of a top-level system → `architecture/architecture-<name>.md`.

If you find yourself wanting to put a note in both, it almost certainly belongs in `architecture/` — and should `[[wikilink]]` to the component hubs it crosses.

## Policy vs architecture — the decision rule

Ask: **is this engineering-facing or governance-facing?**

- Describes how systems are built or how subsystems interact, owned by engineering → `architecture/`.
- Declares organizational controls an external reviewer (regulator, partner, auditor) would expect to see in writing, owned by a steward → `policies/`.

A policy `[[wikilink]]`s to the architecture and ADRs that operationalize it. The policy says *what we commit to*; the architecture and ADRs say *how we built it*.

## Cross-cutting files at the vault root

- `_index.md` — Knowledge Map. Update when adding hub-level notes (new component, new ADR class, major constraint).
- `glossary.md` — ubiquitous language. Update when the note introduces a project-specific term not yet defined.

## Reusable surface

Every in-scope note ends with a `## Reusable surface` section that names the load-bearing reusable symbols the subsystem owns. Claude reads this section to discover existing code before writing new code.

### Bar

List a symbol if either:

- **(a)** It is the canonical home for this concern by design. Intent is the criterion, not call count. A newly extracted utility built to be reused qualifies before it has a second caller.
- **(b)** It bakes in a decision that re-implementing would risk diverging from. Concrete examples in this repo: rounding rule (`formatCurrency`), signature/header/timestamp-drift policy (`verifyWebhook`), bigint-cents vs float storage (`MoneyAmountSchema`), rate-limit window plus which endpoints are billable (`PlaidRateLimitService`).

Do not list generic utilities whose re-implementations would be byte-identical (a plain `chunk(arr, n)`).

### Entry format

One entry per line. Use the exact greppable identifier (PascalCase class/component, camelCase function, schema/type name verbatim). Paths are repo-root-relative. The purpose names the baked-in decision when one exists.

```
- `Symbol` — `path/from/repo/root.ts` — one-line purpose, naming the baked-in decision if any.
```

Example:

```
- `formatCurrency` — `web/src/lib/money.ts` — cents → display string. Banker's rounding, locale-aware symbol position.
```

### Absence case

If the note has no qualifying surface, write the section anyway with an explicit reason:

```
## Reusable surface

None — <reason, e.g. "this note describes a cross-component flow; symbols are owned by [[component-x]]">.
```

"I forgot" and "there genuinely isn't one" must not look the same.

### Scope by bucket

| Bucket          | Required?                                                                                                       |
| --------------- | --------------------------------------------------------------------------------------------------------------- |
| `components/`   | Yes.                                                                                                            |
| `architecture/` | Yes when the note describes a flow that calls into named helpers.                                               |
| `domain/`       | Yes when the rule has a code embodiment (a service, schema, guard).                                             |
| `constraints/`  | Yes when enforced by a specific guard, schema, or extension.                                                    |
| `decisions/`    | No. ADRs are moment-in-time; wikilink to the component instead.                                                 |
| `policies/`     | No. Policies are governance documents; wikilink to the operationalizing architecture / component instead.       |
| `customers/`, `plan/`, `research/` | No.                                                                                          |

### Canonical home

A symbol's `## Reusable surface` entry lives in the single note that owns the file. Other notes wikilink to that note instead of duplicating the entry. Two entries in two places means two-place drift the next time the symbol is renamed.
