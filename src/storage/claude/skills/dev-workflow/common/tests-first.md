# Tests first

Failing tests are what make cheap workers safe: a worker with a red test iterates until it is right. Dispatch `tester-agent` after the edge-case list is settled and before any worker.

## What the tester gets

- The scaffold (already committed)
- The edge-case list, grouped by integration point
- The project's test framework and where its tests live

## What it produces

Integration tests only, one suite per integration point, each exercising a whole endpoint or user flow. Unit tests belong to the workers.

## The gate

Every test must run and fail **for a reason you can name** — on the unimplemented throw, or on the current wrong behavior. A test that errors during import or collection is not a failing test; fix that first. Commit the tests before dispatching workers.

## Ownership after dispatch

Workers may not edit a tester test. A worker that believes one is wrong stops and reports it — the parent decides. A challenged test usually means the edge-case list and the scaffold disagree.
