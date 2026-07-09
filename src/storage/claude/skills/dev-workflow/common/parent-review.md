# Parent review and tests

After every worker reports done:

- Read each worker's diff.
- Verify the plan was adhered to.
- Check each diff against the plan's `## Reuse contract` — a re-implementation of a listed symbol is a defect; replace it with the listed symbol.
- Write the unit and programmatic tests from the plan's test section.
- Run the test suite. Fix failures.
- Run the build. Fix failures.
