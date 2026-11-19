<!--
Catering's plan (recipes/catering/plan.md). Written to <docs>/plan.md in the
catering order's worktree, untracked. For the user or an engineering team to
review: 1 to 3 pages, plain language, no schemas or code (they belong in the
spec). Keep every heading; delete each placeholder once filled.
-->

# <What is being built>

<EPIC> · <date>

## Context and scope

<The objective background a reader needs, and what is being built. Facts only;
link out for detail.>

## Goals and out of scope

Goals:

- <What must be true once this ships. Each becomes functional or
  non-functional requirements in the spec.>

Out of scope, and what owns it instead:

- <What a reader could reasonably expect this to do, ruled out, with why and what owns it instead.>

## Direction

- **Your lean:** <what the user leaned toward before the recommendation>
- **Recommended:** <the recommendation, with its basis>
- **Chosen:** <the direction agreed, and why>

## How it works

<An overview first, then the trade-offs behind it.>

```mermaid
<one context diagram: the system, its users, and the outside services it talks to>
```

## Alternatives considered

- **<Alternative>:** <what it was, and why it lost>

## Cross-cutting concerns

<Data, failure behavior, security, observability: only those that apply.>

## Rollout

<How many deploys it takes, what ships in each, and why each must be separate:
old and new coexisting across a deploy, data existing in production first, or
a step outside the repo in between. One deploy unless one of those forces more.>

## Open questions

<Empty before the spec starts.>
