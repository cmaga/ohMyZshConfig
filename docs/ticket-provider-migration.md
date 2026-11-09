# Migrating a project from the jira skill to ticket-provider

The `jira` skill became the `ticket-provider` skill's jira mode, and its config split by concern. First run `make deploy-zsh deploy-claude`: `deploy-zsh` installs the `jira` shim that looks in the new place, and `deploy-claude` the skills. Deploys never delete files, so remove the retired skill once, by hand: `rm -r ~/.claude/skills/jira`.

Then, in each project that has `.claude/skills/jira/`, from its main checkout:

| Old (`.claude/skills/jira/`) | New |
| --- | --- |
| `.jira-config.yml` | `.claude/ticket-provider/jira-cli.yml`, unchanged |
| `config.json` `server`, `email`, `installationType`, `projectKey`, `labels` | `.claude/ticket-provider/config.json` under `jira` |
| `config.json` `transitions` | `.claude/ticket-provider/config.json` `moments` |
| `config.json` `username` | Dropped; `me` holds the user's display name as Jira shows an assignee |
| `config.json` `baseBranch`, `branchFormat`, `commitFormat` | `.claude/git-provider/config.json` |
| `config.json` `prTemplate` | Dropped; git-provider's `pr-body.md` is the default, and a project that wants its own sets `prTemplate` with `{ticketId}`, `{ticketUrl}`, `{summary}` |
| The kitchen line's `jql` (`kitchen line add PATH JQL`) | `.claude/ticket-provider/config.json` `ready`; `kitchen line add PATH` takes no query |

```bash
set -e
old=.claude/skills/jira
me=$(curl -sf -n "$(jq -r .server $old/config.json)/rest/api/3/myself" | jq -er .displayName) \
  || { echo "could not read your Jira name; check ~/.netrc, then set me by hand"; exit 1; }
jql=$(jq -r --arg p "$PWD" 'select(.project == $p) | .jql // empty' ~/.claude-artifacts/workflows/kitchen/*/line.json 2>/dev/null)
mkdir -p .claude/ticket-provider .claude/git-provider
mv $old/.jira-config.yml .claude/ticket-provider/jira-cli.yml
jq --arg me "$me" --arg jql "$jql" '{provider: "jira", me: $me, ready: $jql, moments: .transitions,
  jira: {server, email, installationType, projectKey, labels}}' $old/config.json > .claude/ticket-provider/config.json
jq '{baseBranch, branchFormat, commitFormat}' $old/config.json > .claude/git-provider/config.json
rm -r $old
printf '%s\n' .claude/ticket-provider/ .claude/git-provider/ >> "$(git rev-parse --git-common-dir)/info/exclude"
~/.claude/skills/ticket-provider/dependencies/scripts/ticket.zsh ready 5
```

The last line proves the move: it prints the first keys of the ready queue. When `ready` came out empty (the project had no kitchen line), write the JQL into it by hand. If `.claude/skills/jira/` was committed, also commit its removal; the new folders stay excluded either way.
