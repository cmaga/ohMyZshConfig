# Small Tier

Trivial changes. The parent session implements in one pass. No subagents, no plan file.

## Critical Rules

- The ticket description is the plan. Do not over-investigate.
- No subagents. Parent does the work.
- Under 10 minutes from entry to PR.
- Verbalize intent in 1-2 sentences before implementing. No plan file.

## Process

1. Read the ticket acceptance criteria.
2. Identify the file(s) named or implied by the ticket. Confirm they exist.
3. Verbalize intent: one short message naming what you will change, the observable outcome, and what is explicitly out of scope. Proceed unless the user interjects.
4. Implement the change directly.
5. Run the project's linter and type checker on modified files. Fix issues.
6. If the ticket implies a test, run it. Fix failures.
7. Route to the shared exit in [../SKILL.md](../SKILL.md).
