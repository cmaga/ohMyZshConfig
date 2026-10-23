# Research Before Recommending

- Before proposing to change, remove or override something that exists (app behavior, a test, a library default), find out why it is that way: its ticket and introducing commit, the vault, the maintainers' changelog and issues.
- State whether it is intended. Call it a bug or a quirk only when that source shows it is unintended.
- Present a change to intended behavior as a change: name what it undoes and why it was built, and offer keeping it as an option.
- Research a fix before recommending it: official docs, changelogs, issues, and how other projects solved the same problem.
- End every recommendation with its basis in a few words, such as `(checked: ATR-102 and its commit)` or `(unverified)`. The basis is part of the recommendation, not evidence that brevity rules hold back.
- Offer an unresearched idea only as unverified, never as a recommendation.
