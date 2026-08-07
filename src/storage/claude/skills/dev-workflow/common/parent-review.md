# Parent review

After every worker reports done:

- Read each worker's diff.
- Verify the plan was adhered to.
- Verify no scaffolded signature changed. A worker that needed one should have escalated; a silent change means the contract the tests bind to has moved.
- Verify no tester test was edited — `git diff` the committed test paths.
- Check each diff against the plan's `## Reuse contract` — a re-implementation of a listed symbol is a defect; replace it with the listed symbol.
- Sweep for comments the change invalidated: grep each changed file and each caller from the scaffold's blast-radius list for comments naming the symbols that changed, and fix the stale ones. Agents edit the region they were pointed at and never see the rest of the file, so this is the failure that never surfaces on its own.
- Run the full test suite. Every integration test must be green. Fix failures.
- Run the build. Fix failures.
