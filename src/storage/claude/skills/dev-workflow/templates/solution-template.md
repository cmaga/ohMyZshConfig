# Solution template

The user is the technical lead. They make the final call. Your job is to present the recommended solution and any considered alternatives so they can steer.

This is the highest-leverage point in the workflow. Verbose or hard-to-skim output gets rubber-stamped. Be concise, plain, and skip code references — file-by-file detail lives in `plan.md`.

## Format

```markdown
- **The problem** — what the user can't do today. One sentence.
- **Recommended approach** — what we'd build, 2-3 sentences. Names patterns and integration points, not files.
- **Alternatives considered** — viable options ruled out, each with a one-line "why not". Up to 3. Omit the bullet entirely if none.
- **Notes** — judgment calls, open questions, risks, scope creep to flag. This is where the user actually steers.

Reply with `go` to proceed with the recommended approach.
```

## During iteration

If the user pushes back and the conversation continues, append this footer to every reply. The user may step away and lose the thread; the footer puts the current state back at their cursor.

```markdown
- **Confidence:** 1-10
- **Problem:** 1-2 sentences, updated if the framing has shifted
- **Current recommendation:** 1-2 sentences, evolves as the conversation refines the choice
```
