# Exit report

Maintain plain language. No internal vocabulary (`O-1`, "the controller", "the spec"), no template labels, no diff-stat banner.

Five beats, in order:

- **What this fixes** — the problem in the user's language, with one concrete example if it helps it land. If a non-engineer couldn't follow it, rewrite.
- **How it's fixed** — the mechanism, 1–3 sentences. Name a thing only when naming it is the clearest way to say what changed. No file roll-call, no per-outcome checklist.
- **Deviations from plan** — if any. Omit the heading if none.
- **How it was verified** — concrete evidence of the visible outcome beyond tests and build: rendered PDFs/images/screens read with the Read tool, UI flows driven end-to-end, scripts whose output you inspected. Default assumption: you can verify everything yourself except look-and-feel. Omit if tests and build are sufficient on their own.
- **What only you can verify** — look-and-feel only: visual taste, UX feel, copy. If `code-review-agent` flagged a user decision (scope cut, bundled commit), surface it here too. Omit the heading if none.

Build, tests, and a clean review pass are preconditions for being here. Do not list them. If something failed, fix it before exiting — that's not a report, it's a deviation.

End with `Run cleanup <TICKET> after merge.` then the PR URL on its own line.

### Exit report example

> **What this fixes:** Authenticated users could change other users' data by passing someone else's id in the URL (`/users/SOMEONE_ELSE/preferences`). Now they can only change their own.
>
> **How it's fixed:** Routes read identity from the authenticated session instead of the URL. The per-route ownership guard and the path parameter it policed are both gone. Frontend callers updated to match.
>
> **How it was verified:** Drove the login → settings-update flow against the dev server end-to-end; the unauthorized-id case now 403s where it previously succeeded.
>
> Run `cleanup KRAT-188` after merge.
>
> https://github.com/example/repo/pull/123
