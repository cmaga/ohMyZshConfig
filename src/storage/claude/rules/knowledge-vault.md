# Knowledge Vault

A Graphify-style vault lives at `~/dev/vault/` (its own git repo).
Repo-to-vault mapping is `~/dev/vault/projects.json`.

## Layout

    ~/dev/vault/
      projects.json                         repo-basename → vault-path
      companies/<company>/<project>/        per-project notes
      companies/personal/<repo>/            personal-project notes
      brain/{patterns,principles,tools}/    cross-project knowledge
      graphify-out/GRAPH_REPORT.md          graph-topology analysis
      graphify-out/wiki/                    navigable wiki

## Session-start orientation

If the current repo has an entry in `projects.json`, the `vault-orient.sh`
SessionStart hook has already injected that project's `_index.md` into your
context — look for a `=== Knowledge Vault: <repo> ===` header. `_index.md`
is the project's entry point: a Knowledge Map wikilinking to documented
Decisions, Architecture, Domain, Customers, Constraints, Plan, and Active
Research.

If no such header appears, the current repo is not in the vault. Work
without orientation — do not invent vault paths.

## When to dig deeper

Before a change that could **reverse a documented Decision, rework
documented Architecture, or violate a documented Constraint**: follow the
relevant wikilink, read the note, and surface the conflict to the user
before proceeding.

## Cross-project questions

For "what does the vault as a whole know about X?" consult
`~/dev/vault/graphify-out/GRAPH_REPORT.md` (topology, communities,
surprising connections) or `~/dev/vault/graphify-out/wiki/`. These are
build artifacts — the vault rebuilds them in the background on commit, so
they may lag by a commit or two. If freshness matters, read the markdown
under `companies/` or `brain/` directly.

## Adding knowledge

Invoke the `capture` skill. It writes the note to the right vault path,
commits to the vault, and the post-commit hook triggers a graph rebuild.
