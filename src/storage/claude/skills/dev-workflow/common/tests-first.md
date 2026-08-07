# Tests first

Failing tests are what make cheap workers safe. Not supervision — ground truth. A worker with nothing to fail against produces plausible code; a worker with a red test iterates until it is right.

Dispatch `tester-agent` after the failure-mode list is settled and before any worker.

## What the tester gets

- The scaffold (already committed)
- The failure-mode list, grouped by integration point
- The project's test framework and where its tests live

## What it produces

Integration tests only — real tests in the project's framework, each exercising a whole endpoint or user flow. One suite per integration point.

Unit tests belong to the workers. The tester never writes them: they bind to internals the scaffold does not specify, so writing them now means inventing.

## The gate

Every test must run and fail on the unimplemented throw. A test that errors during import or collection is not a failing test — the scaffold is incomplete, fix it before continuing.

Commit the tests before dispatching workers.

## Ownership after dispatch

Workers may not edit a tester test. A worker that believes a test is wrong stops and reports it — the parent decides, never the worker.

Treat a challenged test as a signal worth reading. It usually means the failure-mode list and the scaffold disagree.
