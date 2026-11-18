<!--
Catering's implementation plan (recipes/catering/implementation.md). Written to
<docs>/implementation-plan.md in the catering order's worktree, untracked.
Deployment sessions read it by its markup, and
`node ~/.claude/skills/kitchen/commands/cook/scripts/check-plan.mjs <this file> [<docs>/spec.md]`
fails it when:
- a deployment lacks its Forced by, Proof, Touches, or Recipe line;
- Phase 1 of a deployment is not "Skeleton" with exactly one task;
- a task lacks its Depends on, Files, Consumes, Produces, Decisions, or Work line;
- a task depends on one in its own phase or a later one;
- two tasks in one phase share a file, or a path and a directory holding it;
- one task in a phase produces a DEC that another in the same phase consumes;
- a phase of more than one task has no Fan-out line, or holds more than three;
- a DEC is cited but not listed, or a table names a task that does not exist;
- given the spec, an FR, NFR, behavior, or test id is missing from Coverage.
Ids: DEC-N for decisions, D<n>.P<n>.T<n> for tasks. Prose inside a section is free.
-->

# <EPIC>: implementation plan

Plan: `<docs>/plan.md` · Spec: `<docs>/spec.md`

## Decisions

<!-- Every call an agent would otherwise make alone, in the order the build
meets them. One that fixes a shared interface states the contract itself. -->

- **DEC-1:** <the call>. Why: <reason>. Beat: <what it was chosen over>. Settled by: <you | the code at `file:line` | the spec's C-N.M>.
  - **Contract:** `<signature>`: <data shape, errors, what it guarantees>

## Coverage

<!-- One row per FR, NFR, behavior, and test in the spec. -->

| Spec item | Task |
| --------- | ---- |
| FR-1      | D1.P2.T1 |

## Checks today's code performs

<!-- From the gather. Every one keeps a fate on purpose. -->

| Check | Where | Fate (moved / adapted / retired: why) | Task |
| ----- | ----- | ------------------------------------- | ---- |

## Behavior in code the build deletes or rewrites

<!-- From the gather's sweep, one row per behavior. Omit the section when the
build deletes and rewrites nothing. -->

| Behavior | Where | Fate (moved / adapted / retired: why) | Task |
| -------- | ----- | ------------------------------------- | ---- |

## Deployment 1: <what goes live>

- **Forced by:** <coexistence | data first | outside the repo>: <the concrete reason> | none: the only deployment
- **Proof:** `<one check that fails before this deployment and passes after, on what ships>`
- **Touches:** <part ids, such as C-1, C-3, X-1>
- **Recipe:** <feature | refactor | bug-fix | perf>

### Phase 1: Skeleton

#### D1.P1.T1: <the skeleton>

- **Depends on:** none
- **Files:** `<path>`, `<test path>`
- **Consumes:** none
- **Produces:** DEC-1
- **Decisions:** DEC-1
- **Work:** <the modules, types, signatures and stubs with their behavior stated, the pattern later tasks copy, and the locked tests>

### Phase 2: <name>

- **Fan-out:** <only when the phase holds more than one task: why its tasks share no file, no interface a DEC fixes that both write, and no producer and consumer pair>

#### D1.P2.T1: <task>

- **Depends on:** D1.P1.T1
- **Files:** `<path>`
- **Consumes:** DEC-1
- **Produces:** none
- **Decisions:** DEC-1
- **Work:** <moves / adapts / new, from the gather; new code quotes the spec sentence that forces it>

<!-- Repeat phases and deployments. A deployment after the first starts only
once the one before it is live. -->
