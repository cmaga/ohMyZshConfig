# Scaffold

The design, in a form the user can hold: real code, all structure, no behavior. Written by the parent, not a subagent — the scoping context does not survive a handoff. It survives into the PR.

## What to write

- Type, interface, and schema definitions — complete and real
- Function and method signatures — complete and real
- Module placement: real files, real directories, real imports
- Migration DDL, including the constraints and indexes that enforce something
- Doc comments on the contracts

Every new body is exactly the unimplemented throw, in the language's idiom; [Editing existing code](#editing-existing-code) covers code that already exists.

## Doc comments

The language's ordinary doc comment, at the density this repo already uses: a one-line summary, one short paragraph only when there is a rule the signature cannot carry, then the standard tags. A signature that already says everything gets no comment. If the comments outweigh the declarations, they are wrong.

    /**
     * Finds the bank connection for an institution, creating one if it does not exist yet.
     *
     * Linking the same bank a second time returns the existing connection rather than
     * making a new one, so a customer's transactions are never counted twice.
     *
     * @param institutionId - The bank's id, as given by Plaid.
     * @param accessToken - Token for this link. Replaces the stored one when the connection already exists.
     * @returns The connection, existing or newly created.
     * @throws {InstitutionNotFoundError} If the institution id is not one we support.
     */
    async resolveItem(institutionId: string, accessToken: string): Promise<Item> {
      throw new Error("unimplemented");
    }

## The drift line

**A body is a violation when it contains behavior the tests will check.** Migration DDL and the composition root are structure even inside a function. Before presenting, grep the diff for function bodies and confirm each is the throw or structure.

The four shapes it drifts into: control flow "to show the intent"; the happy path only; constants with invented values; a body returning a closure that contains the throw.

## Done means it runs

The project compiles and the test suite executes — tests must load the scaffold and go red on the throw. Lint is not part of it: when every lint failure comes from an unimplemented body, commit with `--no-verify` and say so in the message. Every later commit runs the hooks.

## Blast radius

When the scaffold changes an existing signature, schema, or shared validator, list every caller at `file:line` with a verdict: survives, or breaks. Each break becomes a tester test and a line on a worker's card. Do not put the list in front of the user; interrupt only when it says something about the design — a caller that cannot be fixed inside this plan, or a count so large the boundary is wrong.

## Partition check

The scaffold must let the work split into disjoint file sets, one per worker. If it cannot, the module boundaries are wrong — say so now.

## Editing existing code

Scaffold whatever the change adds or moves at the interface level, however small. When nothing does — a pure body rewrite — record `## Scaffold: none — no interface changed` in the plan and carry on; the tests bind to the surface that already existed.

Throw only where behavior is changing, whatever the unit: function, method, class or service. Existing code the change merely moves, or extends with a parameter that defaults to today's behavior, keeps its implementation. A new call from code existing tests already run goes on a worker's card, not into the scaffold. A migration never throws: write its DDL or leave its body empty.

If the project has no integration suite, stop and ask the user whether to build one or skip it. Unattended: stand up a minimal harness covering this ticket's integration points and continue.

## Reviewing it (`medium` and `large`)

Unattended: commit and continue; on `large`, the `plan-review-agent` pass runs.

Attended: **leave the scaffold uncommitted until the user has read it** — the editor's source control panel is the file list. Open the worktree in their editor:

    code "$(git rev-parse --show-toplevel)"

If `code` is not on `PATH`, give the absolute path instead. Then say in two lines what the change is and what the scaffold covers, name the files in reading order, and present the four questions:

1. Do these module boundaries match how this will actually change?
2. Where does state live?
3. What do the interfaces promise?
4. What is conspicuously missing?

Commit once their corrections are in — before the tester, before any dispatch.
