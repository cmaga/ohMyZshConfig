# Plan presentation

Plans run hundreds of lines. The user already approved the solution during scoping — they don't need it re-pitched. The pre-dispatch chat brief is a confirmation: here's what we agreed on, here's how I'll execute it, last chance to push back.

## Shape

1. **Recap** — one line on the agreed solution
2. **Implementation** — systems and components, not files or code
3. **Callouts** — decisions worth flagging, risks, things out of scope
4. **Plan path** — one-line **absolute** path to `plan.md` inside the worktree, derived as `$(git rev-parse --show-toplevel)/.claude-artifacts/workflows/dev-workflow/plan.md`. The user's IDE CWD is the main repo, not the worktree, so a relative path won't resolve when they click it.
5. **Binary ask** — `go` or push back

Plain language. No `O-1`, no file paths, no code snippets. Aim for 5-15 lines. Past that the brief is doing the plan's job and the user starts rubber-stamping.

If a `[NEEDS CLARIFICATION]` item emerged after planning (e.g., from QA planning or architecture review) and is still unresolved, surface it as one open question above the binary ask.
