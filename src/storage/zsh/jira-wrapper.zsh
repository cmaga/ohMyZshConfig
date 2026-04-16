# jira(): route each `jira` call to the right jira-cli config for the
# current project, reading the API token from ~/.netrc.
#
# Lookup: walk $PWD ancestors for .claude/skills/jira/.jira-config.yml.
# Read the `server:` field from that yml, strip scheme and trailing
# slash, and look up ~/.netrc for `machine <host>` → `password`.
# Invoke `command jira "$@"` with JIRA_CONFIG_FILE and JIRA_API_TOKEN
# prefixed to the call only — nothing is exported into the shell.
#
# Hard-fails with a specific stderr message if the yml is missing, the
# server field is missing, or the netrc entry is missing. No silent
# fallback — misconfiguration should surface immediately.
#
# Non-underscore function name so Claude Code's shell-snapshot filter
# preserves it for BashTool invocations (see the lazy nvm block in
# ~/.zshrc for the same convention).
jira() {
  local dir=$PWD
  while [[ $dir != / ]]; do
    local cfg="$dir/.claude/skills/jira/.jira-config.yml"
    if [[ -f $cfg ]]; then
      local server
      server=$(awk '/^[[:space:]]*server:/ {
        sub(/^[[:space:]]*server:[[:space:]]*/, "");
        gsub(/[[:space:]"'\'']/, "");
        print; exit
      }' "$cfg")
      server=${server#https://}
      server=${server#http://}
      server=${server%/}

      if [[ -z $server ]]; then
        print -u2 "jira: no server: field in $cfg"
        return 1
      fi

      local token
      token=$(awk -v m="$server" '
        $1 == "machine" && $2 == m { inblock=1; next }
        inblock && $1 == "password" { print $2; exit }
        $1 == "machine" && $2 != m { inblock=0 }
      ' ~/.netrc 2>/dev/null)

      if [[ -z $token ]]; then
        print -u2 "jira: no netrc entry for machine $server (add one to ~/.netrc)"
        return 1
      fi

      JIRA_CONFIG_FILE=$cfg JIRA_API_TOKEN=$token command jira "$@"
      return
    fi
    dir=${dir:h}
  done

  print -u2 "jira: no .claude/skills/jira/.jira-config.yml found in any ancestor of $PWD"
  return 1
}
