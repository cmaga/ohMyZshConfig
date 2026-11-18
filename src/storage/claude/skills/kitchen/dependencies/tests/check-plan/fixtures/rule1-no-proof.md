<!-- A passing plan. Comments such as this one are ignored: ## Deployment 9: x -->

# Greeter: implementation plan

Plan: `docs/plan.md` · Spec: `docs/spec.md`

## Decisions

- **DEC-1:** Greetings are plain strings. Why: simplest. Beat: a struct. Settled by: you.
  - **Contract:** `greet(name: string): string`: never throws

## Coverage

| Spec item | Task |
| --------- | ---- |
| FR-1      | D1.P2.T1 |
| NFR-1     | D1.P2.T2 |
| C-1.1     | D1.P2.T1, D2.P2.T1 |
| C-1.T1    | D1.P1.T1 |

## Checks today's code performs

| Check | Where | Fate | Task |
| ----- | ----- | ---- | ---- |
| none empty | `src/a.ts:3` | moved | D1.P2.T1 |
| old guard | `src/a.ts:9` | retired: dead | - |

## Behavior in code the build deletes or rewrites

| Behavior | Where | Fate | Task |
| -------- | ----- | ---- | ---- |
| legacy banner | `src/b.ts:1` | retired: unused | - |

## Deployment 1: greeter lib

- **Forced by:** none: the only reason
- **Proof:** `node test/greet.js`
- **Touches:** C-1
- **Recipe:** feature

### Phase 1: Skeleton

#### D1.P1.T1: the skeleton

- **Depends on:** none
- **Files:** `src/greet.ts`, `test/greet.test.ts`
- **Consumes:** none
- **Produces:** DEC-1
- **Decisions:** DEC-1
- **Work:** Stub greet and lock its tests.

### Phase 2: Behavior

- **Fan-out:** the tasks touch different files and share no interface a DEC fixes.

#### D1.P2.T1: greet

- **Depends on:** D1.P1.T1
- **Files:** `src/a/greet.ts`
- **Consumes:** DEC-1
- **Produces:** none
- **Decisions:** DEC-1
- **Work:** Implement greet.

#### D1.P2.T2: timing

- **Depends on:** D1.P1.T1
- **Files:** `src/b/`
- **Consumes:** DEC-1
- **Produces:** none
- **Decisions:** DEC-1
- **Work:** Keep greet fast.

## Deployment 2: greeter cli

- **Forced by:** data first: the lib ships first
- **Touches:** C-1
- **Recipe:** refactor

### Phase 1: Skeleton

#### D2.P1.T1: the cli skeleton

- **Depends on:** D1.P2.T1
- **Files:** `src/cli.ts`
- **Consumes:** DEC-1
- **Produces:** none
- **Decisions:** DEC-1
- **Work:** Stub the cli.

### Phase 2: Wiring

#### D2.P2.T1: wire

- **Depends on:** D2.P1.T1
- **Files:** `src/cli.ts`
- **Consumes:** none
- **Produces:** none
- **Decisions:** none
- **Work:** Wire the cli.
