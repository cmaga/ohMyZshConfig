# Drift triage

One open flag from `vault-drift.sh --list` names a note, a claim, and the SHA that moved the code. Walk the steps in order; stop at the first that decides.

1. Vanished symbol. The symbol the claim names is gone from the path. Find where it went: `git log -S<symbol> <sha>~1..<sha>`.
2. Rename or delete. A rename keeps the claim true under the new name. A delete kills the claim: on a decision, route to supersession (skill step 10, move 1); on any other note, edit in place (move 4).
3. Old support vs new support, per claim. Did the old code support the claim, and does the new code? Only old-yes/new-no is drift. Old-no means the note was already wrong and gets its own brief.
4. Omission through the capture bar. The commit adds behaviour the note never mentioned. If it is not non-obvious and worth recording, the flag clears with "omission below the bar".
5. Leave open with a question. The diff does not decide it. Leave the flag open and write the one question that would.

Two outputs, one per flag:

- `bash ~/.claude/skills/capture-documentation/scripts/vault-drift.sh --clear . <ID> "<reason>"` — nothing in the vault changes.
- A scribe brief carrying the SHA, the claim as written, and what the code now shows.
