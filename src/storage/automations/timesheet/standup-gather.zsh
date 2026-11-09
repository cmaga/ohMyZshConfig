#!/usr/bin/env zsh
# The standup skill's view of this machine: what it fills and where its work is.
#
#   standup-gather.zsh config      key: value lines (fill_project, standup_dir,
#                                  extra_activity, repos)
#   standup-gather.zsh commits D   my non-merge commits on day D (YYYY-MM-DD) in
#                                  every repo, as "repo: hash subject"
#
# Repos come from the per-machine config's repo_roots: each root is a repo, or a
# folder holding repos (a Brazil workspace's src/<package>, say) up to 5 levels
# down. exclude_repos (folder names, space-separated) drops repos whose work is
# not the client's, such as dotfiles. Without that config, the single repo_path
# of the standup skill's automation.toml, as before.

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
source "${SCRIPT_PATH:A:h}/harvest-lib.zsh"

LEGACY_TOML="$HOME/.claude/skills/standup/automation.toml"

repos() {
    if ! has_timesheet_config; then
        local repo=$(_toml_string repo_path "$LEGACY_TOML")
        [[ -d "$repo" ]] && print -r -- "$repo"
        return 0
    fi
    local root exclude=" $(ts_string exclude_repos) "
    for root in ${=$(ts_string repo_roots)}; do
        root="${root/#\~/$HOME}"
        [[ -d "$root" ]] || continue
        if [[ -e "$root/.git" ]]; then
            print -r -- "$root"
        else
            find "$root" -maxdepth 5 -name .git -prune -print 2>/dev/null | sed 's|/\.git$||'
        fi
    done | sort -u | while IFS= read -r root; do
        [[ "$exclude" == *" ${root:t} "* ]] || print -r -- "$root"
    done
}

standup_dir() {
    local dir=$(ts_string standup_dir)
    if [[ -z "$dir" ]]; then
        local repo=$(_toml_string repo_path "$LEGACY_TOML")
        dir="$repo/.claude-artifacts/workflows/standup"
    fi
    print -r -- "$dir"
}

case "${1:-}" in
    config)
        print -r -- "fill_project: $(ts_string fill_project)"
        print -r -- "standup_dir: $(standup_dir)"
        print -r -- "extra_activity: $(ts_string extra_activity)"
        print -r -- "repos: $(repos | wc -l | tr -d ' ')"
        ;;
    commits)
        day="${2:-}"
        [[ "$day" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "standup-gather: commits needs a YYYY-MM-DD day" >&2; exit 2; }
        # A git process per repo is unavoidable (no single call spans repos);
        # each repo's own user.email is the author, so per-directory identities hold.
        repos | while IFS= read -r repo; do
            email=$(git -C "$repo" config user.email 2>/dev/null) || continue
            git --no-pager -C "$repo" log --all --since="$day 00:00:00" --until="$day 23:59:59" \
                --author="$email" --no-merges --pretty=format:'%h %s' 2>/dev/null \
                | sed "s|^|${repo:t}: |"
            print
        done | grep -v '^$' || true
        ;;
    *)
        echo "usage: standup-gather.zsh config, or standup-gather.zsh commits YYYY-MM-DD" >&2
        exit 2
        ;;
esac
