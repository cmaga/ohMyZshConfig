# Small Tier

Trivial changes. The parent session implements in one pass. No subagents, no plan file.

## Critical Rules

- The ticket description is the plan. Do not over-investigate.
- No subagents. Parent does the work.
- Under 10 minutes from entry to PR.

## Process

1. Read the ticket acceptance criteria.
2. Identify the file(s) named or implied by the ticket. Confirm they exist.
3. Implement the change directly.
4. Run the project's linter and type checker on modified files. Fix issues.
5. If the ticket implies a test, run it. Fix failures.
6. Route to the shared exit in [../SKILL.md](../SKILL.md).
