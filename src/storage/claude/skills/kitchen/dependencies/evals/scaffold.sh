#!/usr/bin/env bash
# The scaffold every case shares, run in the empty workspace by its place-files.sh: the case's files
# as a cloned project set up for the ticket-provider and git-provider skills, the kitchen and ticket-provider where
# their scripts look for them, the
# project registered with the pipeline, and the backlog plus the case's tickets for the stand-in Jira.
# Usage: scaffold.sh <case dir> <repo name>
set -eu
case_dir=$(cd "$1" && pwd)
repo=$2
evals=${case_dir%/*}
kitchen=$(cd "$evals/../skills/kitchen" && pwd)
tickets_skill=$(cd "$evals/../skills/ticket-provider" && pwd)

cp -R "$case_dir/files/." .
mkdir -p .claude/ticket-provider .claude/git-provider
cat > .claude/ticket-provider/config.json <<'JSON'
{
    "provider": "jira",
    "me": "Jordan Lee",
    "ready": "project = PLAT AND status = \"To Do\"",
    "moments": {
        "start": "In Progress",
        "review": "In Review",
        "merged": "Done"
    },
    "jira": {
        "server": "http://northwind.atlassian.test",
        "email": "jordan.lee@northwind.dev",
        "installationType": "cloud",
        "projectKey": "PLAT",
        "labels": []
    }
}
JSON
cat > .claude/git-provider/config.json <<'JSON'
{
    "baseBranch": "main",
    "branchFormat": "{username}/{ticketId}-{description}",
    "commitFormat": "{ticketId}: {message}",
    "prTemplate": "Resolves {ticketId}\n\n## Changes\n- \n\n## Testing\n- "
}
JSON
printf '.claude/worktrees/\n.claude/ticket-provider/\n.claude/git-provider/\n' > .gitignore
git init -q -b main
git add -A
git -c user.name="Priya Natarajan" -c user.email=priya.natarajan@northwind.dev commit -q -m "Initial commit"
git config user.name "Jordan Lee"
git config user.email jordan.lee@northwind.dev
git init -q --bare "$HOME/remotes/$repo.git"
git remote add origin "$HOME/remotes/$repo.git"
git push -q -u origin main 2>/dev/null

mkdir -p "$HOME/.claude/skills"
cp -R "$kitchen" "$HOME/.claude/skills/kitchen"
cp -R "$tickets_skill" "$HOME/.claude/skills/ticket-provider"
zsh "$HOME/.claude/skills/kitchen/dependencies/scripts/kitchen.zsh" line add "$PWD" >/dev/null

mkdir -p "$HOME/.jira-mock"
tickets=$case_dir/tickets.json
[ -f "$tickets" ] || tickets=/dev/null
jq --slurpfile t "$tickets" '.issues += ($t[0] // [])' "$evals/jira/backlog.json" > "$HOME/.jira-mock/issues.json"

# where stop.sh finds the case's check; the folder it writes for the graders stays out of git
printf '%s\n' "$case_dir" > "$HOME/.eval-case"
printf '.eval-results/\n' >> .git/info/exclude
