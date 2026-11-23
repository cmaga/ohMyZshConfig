<!--
Catering's functional spec (recipes/catering/spec.md). Written to
<docs>/spec.md in the catering order's worktree, untracked, from the approved
plan. For agents: precise, complete, no persuasion. The ids are permanent and
machine-read (check-plan.mjs, the implementation plan's Coverage): FR-N, NFR-N,
parts C-N (we run) and X-N (outside services), behaviors C-N.M, tests C-N.TM.
FR-N and NFR-N are the plan's ids. An id added later takes the next free
number, in the plan too; a retired one is never reused.
-->

# Spec: <what it builds>

Plan: `<docs>/plan.md`

## Terms

- **<term>:** <its one meaning in this system>

## Functional requirements

- **FR-1:** <the plan's FR-1 as one checkable sentence>.

## Non-functional requirements

- **NFR-1:** <the quality and its measurable bar, such as p95 latency under
  200 ms at 50 requests a second>.

## Parts

```mermaid
<the container diagram: each part a node labeled with its id, each connection
an arrow labeled with what crosses it>
```

### C-1: <a part we run: a web app, server, worker, scheduled job, database>

- **Owns:** <what this part alone is responsible for>
- **Talks to:** <part id>: <what crosses the connection>

**Behavior**

- **C-1.1:** <input, output, error, or edge case, stated so a test could fail
  on it>. Serves FR-<n>.

**Data**

<The shapes it stores or sends: fields, types, nullability, constraints.>

**Tests**

- **C-1.T1:** <the scenario>. Proves C-1.<m>, NFR-<n>.

### X-1: <an outside service>

- **Owns:** <what we rely on it for>
- **Talks to:** <part id>: <what crosses the connection>

## Flows

### <Flow name>

```mermaid
sequenceDiagram
  <one column per part, requests and replies in order>
```

## Records

<What the system stores that it will learn from or be judged by.>

## Starting values

- **<tunable>:** <a concrete value to start from, and what would change it>
