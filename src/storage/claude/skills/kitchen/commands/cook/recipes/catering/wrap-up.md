# Wrap-up

Every deployment merged: the plan, spec, and implementation plan were planning documents, and the system they planned now replaces them with documentation. The scribe has written nothing before this point, so it documents only finished code. It starts in the session that confirmed the last deployment merged ([deployment](deployment.md#after-the-merge)), with the user, and runs without a goal.

1. **Take the branch.** `git fetch origin <base>` (`<base>` is what `kitchen.zsh order base <KEY>` prints) and `git reset --hard origin/<base>`; the untracked documents survive it.
2. **Document the system.**
   - **The vault**, when the project has `docs/project-knowledge/`: dispatch `vault-scribe-agent` from this worktree per the knowledge-vault-use rule, with a brief per part from the final spec: what it owns, what it talks to, its data, and the DECs behind it with what each beat. Brief only claims you confirmed at `file:line` in the merged code.
   - **The project's docs**, per the Docs section of the project rules: write what it requires for this system, where it says they go.
   - When either changed tracked files, run `kitchen.zsh order set <KEY> review=true "review_why=catering: the docs for <EPIC>"`, then open them as one PR per [open a PR](../open-a-pr.md).
3. **Attach the documents** (`<docs>/plan.md`, `spec.md`, `implementation-plan.md`) to the epic through the `ticket-provider` skill, for the record.
4. **Close.** With no PR, `kitchen.zsh order close <KEY>`. With one, the order closes when it merges ([catering](../catering.md)'s `building` rows). Pruning then removes this worktree and the documents in it.
