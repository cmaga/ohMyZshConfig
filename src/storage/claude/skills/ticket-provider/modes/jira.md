# Jira

jira-cli (ankitpokhrel) behind the `~/.local/bin/jira` shim. The shim walks up from the current directory for `.claude/ticket-provider/jira-cli.yml` and reads the token from `~/.netrc`; it refuses rather than fall back to jira-cli's default config, which points at whichever instance was set up last. `ticket.zsh` runs every jira command from the main checkout, so the walk always finds it.

## Config

`.claude/ticket-provider/config.json`, shaped like [config.jira.json](../dependencies/templates/config.jira.json):

| Field | Meaning |
| --- | --- |
| `ready` | JQL with no ORDER BY; `ticket.zsh ready` orders by rank |
| `moments.*` | The **transition** name that reaches each status, never the status name: `jira issue move` matches transitions only, and an "In Progress" transition can land on "Implementation" |
| `jira.server` | `https://<host>` |
| `jira.email` | Login email |
| `jira.installationType` | `cloud` or `server` |
| `jira.projectKey` | The project key |
| `jira.labels` | Labels added to every ticket filed; may be empty |

Beside it, `jira-cli.yml` is jira-cli's own config. The token lives only in `~/.netrc`.

## Setup

Trigger: "set up jira", or the ticket-provider setup in a Jira project. Claude writes every file itself; never run `jira init` (the shim refuses every call until `jira-cli.yml` exists) and never ask the user to paste commands.

1. **Install:** `command -v jira || brew install jira-cli`; `command -v jq || brew install jq`.
2. **Discover silently, in parallel:** Atlassian hosts in `~/.netrc` (`awk '/^machine .*atlassian\.net/ {print $2}' ~/.netrc`), sibling configs (`find ~/dev -maxdepth 6 -path '*/.claude/ticket-provider/jira-cli.yml'`), and `git config user.email`. Extract a host's login and token with exactly this recipe:

   ```bash
   awk -v host="$HOST" '$1=="machine" {f=($2==host)?1:0; next} f && $1=="login" {print "login=" $2} f && $1=="password" {print "password=" $2}' ~/.netrc
   ```

   Validate it: `curl -s -o /dev/null -w "%{http_code}" -u "$EMAIL:$TOKEN" "https://$HOST/rest/api/3/myself"`. 401 means no token.
3. **Ask once**, in plain text, for only what discovery could not answer: the project key, and the host only when discovery found several or none.
4. **Derive every project value from the API**, never from a sibling (a sibling is a shape template only):

   ```bash
   curl -s -u "$EMAIL:$TOKEN" "https://$HOST/rest/api/3/project/$KEY" | jq -r .style                 # project.type: next-gen or classic
   curl -s -u "$EMAIL:$TOKEN" "https://$HOST/rest/agile/1.0/board?projectKeyOrId=$KEY" | jq '.values[0] | {id, name, type}'
   curl -s -u "$EMAIL:$TOKEN" "https://$HOST/rest/api/3/issue/createmeta/$KEY/issuetypes" | jq -r '.issueTypes[] | "\(.id) \(.name) \(.subtask)"'
   curl -s -u "$EMAIL:$TOKEN" "https://$HOST/rest/api/3/myself" | jq -r .displayName                # me
   ```

   For a `classic` project also derive `epic.name` and `epic.link` from `/rest/api/3/field` (`Epic Name`, `Epic Link`); a `next-gen` project omits the `epic:` block.
5. **Moments:** list the statuses (`/rest/api/3/project/$KEY/statuses`) and ask, for each moment, the status a ticket leaves and the one it reaches (for example `start`: To Do to In Progress). Find a ticket in the status it leaves (`ticket.zsh raw issue list -q 'status = "<from>"' --plain --no-headers --columns key --paginate 1`), read its transitions (`/rest/api/3/issue/$ISSUE/transitions`), and store the name of the one that reaches the target. With no ticket in that status, ask the user for the transition's name.
6. **Ready queue:** find the board the user works from instead of asking for it: read up to 10 of the tickets the commit log names, and write the project and the label, component, or board they share as JQL, never inventing a label for kitchen; ask only when they share none. Show the user that JQL and the first five keys `ticket.zsh ready 5` returns.
7. **Write** `config.json` and `jira-cli.yml`, and add `.claude/ticket-provider/` to `$(git rev-parse --git-common-dir)/info/exclude`.
8. **Token**, only when step 2 found none or it 401'd: the user creates one at https://id.atlassian.com/manage-profile/security/api-tokens; append `machine <bare-host>` / `login` / `password` to `~/.netrc` and `chmod 600 ~/.netrc`.
9. **Verify:** run the detection battery below; setup is done when all five pass.

## Raw commands

`ticket.zsh raw ...` runs `jira` with this project's config. Every write (`issue create`, `issue edit`, `issue comment add`, `issue worklog add`, `epic create`) needs all three of these, or it can hang a session for hours:

- `--no-input`, or jira-cli prompts and blocks.
- Stdin redirected: `< body.md`, else `< /dev/null`. jira-cli reads stdin to its end whenever it is not a terminal.
- Bash `timeout: 60000`. A healthy write takes under a second; never retry one without the two above.

Remove a label with the `=` form: `--label=-old --label new`. With a space, `-old` parses as a flag and the command hangs even with `--no-input`.

jira-cli has no `--no-pager`; use `--plain` and `--no-headers` for parseable output. Flag support differs per command (from `--help` on jira-cli 1.7.0):

| Flag | `issue list` | `issue view` | `issue create` | `issue edit` | `issue move` | `issue comment add` | `epic add` |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| `--plain` | Yes | Yes | No | No | No | No | No |
| `--no-headers` | Yes | No | No | No | No | No | No |
| `--raw` | Yes | Yes | Yes | No | No | No | No |
| `--no-input` | No | No | Yes | Yes | No | Yes | No |

Re-parent an existing issue with `raw epic add EPIC KEY`. The full reference is [jira-cli-reference.md](../dependencies/docs/jira-cli-reference.md).

## When a command fails

- **Missing prerequisite** (`jira: command not found`, config not found, HTTP 401, a hang despite the rules above): run the detection battery, then setup.
- **Field rejected** (`Field 'customfield_10014' cannot be set`): the values are wrong, not missing. Check battery item 5 and fix `jira-cli.yml`; never rerun setup and never work around it with raw REST.
- **Transition rejected** (`invalid transition state "<name>"`): the moment's transition does not leave the ticket's current status. Show the user the states the error lists, write the one they pick into `moments`, and rerun.

Anything else: report the API's error verbatim and stop.

### Detection battery

Only for setup verification and failure triage, from the main checkout. `HOST` is `jira.server` without its scheme and `KEY` is `jira.projectKey`, both from `config.json`:

1. `command -v jira`
2. `.claude/ticket-provider/config.json` exists
3. `.claude/ticket-provider/jira-cli.yml` exists
4. `~/.netrc` has a `machine` entry for the bare host of `jira-cli.yml`'s `server:`
5. `project.type` in `jira-cli.yml` equals `curl -s -n "https://$HOST/rest/api/3/project/$KEY" | jq -r .style`; a mismatch makes jira-cli send epic fields the project rejects
