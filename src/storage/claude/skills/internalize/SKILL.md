---
name: internalize
description: Guided deep-reading of code the user did not write, until they understand it line by line. Use when the user says "internalize" a ticket, PR, branch, or module, asks to study or truly understand AI-written code, or wants to pay down comprehension debt.
---

# Internalize

The user reads and annotates code until they understand it. You are the lookup service and the checker — never the explainer. AI-written code is only as good as the depth at which a human checks it, and once a session ends the user is the only one who still carries the system in their head. This skill makes that carrying real.

## Rules that shape every step

- Never explain code under study before the user has read it and told you what they think it does. Explaining first destroys the learning; correcting their attempt creates it.
- External references are the opposite: library APIs, language semantics, framework behavior — answer immediately and completely, the way documentation would. That is the part of the old read-and-google process worth automating.
- The user's written comments are the unit of progress. No comments, no progress.

## Workflow

1. **Scope and brief.** The user names a ticket, PR, branch, or module. Gather: the ticket via the `jira` skill, the PR and its description via the `git-provider` skill, related tickets, and vault notes for the touched components. Deliver a short briefing: why this change exists, what it is supposed to do, what constrained it — the context a colleague would give before a walkthrough. Say nothing about how the code works.
2. **Build the reading map.** Lay out the code as cohesive units in the order execution flows — entry points first, helpers when the flow reaches them. For each unit: the file paths and one line on its place in the whole. A table of contents, not a summary. Save it alongside the ledger so a later session can resume.
3. **The user reads and annotates.** One unit at a time, at their pace. They write comments in the code, in their own words, explaining sections to themselves — exactly as they would have before AI. While they read: answer external lookups directly; for questions about the code under study, ask what they think first, then confirm or correct. Never rush them and never offer to summarize what remains.
4. **Verify each finished unit.** Read every comment they wrote and check it against what the code actually does. A wrong or fuzzy comment is a caught misconception: show the code path that contradicts it and let them rewrite the comment themselves. The unit is done when every annotation is accurate.
5. **Route what the reading uncovers.** The user finds bugs this way that no automated pass caught. Small fix → apply it, run tests, commit. Bigger → follow-up ticket via the `jira` skill. Never let a discovery evaporate as conversation.
6. **Distill.** Keep the comments that will help the next reader; delete scaffolding the user no longer needs. Commit the surviving annotations on a branch and open a small PR titled `internalize: annotate <scope>` via the `git-provider` skill. If the understanding deserves a vault note, dispatch `vault-scribe-agent` with the user's verified annotations as the content brief — their words, checked against the code, are the best documentation this system will get.
7. **Update the ledger.** Record per unit: read, annotated, verified, date. The ledger lives in the knowledge vault (all writes via `vault-scribe-agent`); in a project without a vault, keep it at `.claude-artifacts/skills/internalize/ledger.md` (project scope, gitignored — append `.claude-artifacts/` to `$(git rev-parse --git-common-dir)/info/exclude` on first write). Units not yet verified stay listed as open debt — making the unread remainder visible is the point.

## Sessions are small on purpose

One sitting can cover one unit. Resume from the ledger and reading map next time. Two units verified beats five pushed through tired — a wrong mental model recorded confidently is worse than an open ledger entry.
