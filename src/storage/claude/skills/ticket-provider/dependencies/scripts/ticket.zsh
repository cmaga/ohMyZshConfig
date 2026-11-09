#!/usr/bin/env zsh
# One interface to a project's ticket tracker. Sessions and scripts reach the
# tracker only through this, so a project changes trackers by changing its
# config, never its callers.
#
# Config: <main checkout>/.claude/ticket-provider/config.json, found from any
# worktree through git's common dir. The provider's own files sit beside it:
# jira-cli.yml for jira, .beads/ for taskei (bdei runs from that directory).
#
# Usage: a BODY is literal text, or @/path/to/file to read it from a file.
#   ticket provider                     print the provider name
#   ticket whoami                       the user's display name, as `holder` prints an assignee (config `me`)
#   ticket get KEY                      the whole ticket: fields, description, every comment
#   ticket holder KEY                   me, none, or the assignee's name
#   ticket ready [N]                    keys of the ready queue in the tracker's order, one per line (default 20)
#   ticket search TEXT [N]              open tickets matching TEXT: key<TAB>status<TAB>title (default 20)
#   ticket claim KEY                    assign to the user and move with the start moment
#   ticket move KEY MOMENT BODY         move with moments.<MOMENT> (start, review, merged), commenting BODY
#   ticket comment KEY BODY             add a comment
#   ticket create TITLE BODY [--parent KEY] [--type TYPE]   file a ticket; prints its key
#   ticket link KEY OTHER               relate two tickets
#   ticket attach KEY FILE              attach a file; exit 3 where the provider has no attachments
#   ticket url KEY                      the ticket's web URL
#   ticket raw ARGS...                  run the provider's CLI with this project's config

set -uo pipefail

die() { print -u2 -- "ticket: $*"; exit 1; }

root=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || die "not in a git repository"
root=${root%/.git}
dir=$root/.claude/ticket-provider
cfg=$dir/config.json
[[ -f $cfg ]] || die "no $cfg; run the ticket-provider skill's setup for this project"
conf() { jq -r "$1 // empty" $cfg; }
provider=$(conf .provider)

# Helpers set REPLY instead of printing, so a die inside them ends the script, not a subshell.
body() { # BODY: REPLY is an absolute path to a file holding it
  if [[ $1 == @* ]]; then
    local p=${1#@}
    [[ -f $p ]] || die "no file $p"
    REPLY=$p
  else
    REPLY=$(mktemp); print -r -- $1 > $REPLY
  fi
}

moment() { # NAME: REPLY is the provider's value for that moment
  REPLY=$(conf ".moments.$1")
  [[ -n $REPLY ]] || die "no moments.$1 in $cfg"
}

holder() { # ASSIGNEE: print none, me, or the assignee
  if [[ -z $1 ]]; then print none
  elif [[ $1 == $(conf .me) ]]; then print me
  else print -- $1; fi
}

# bdei prints a plain array, or {"items": [...]} when it pages
ROWS='(if type == "array" then . else .items end)'

# ---- jira: jira-cli through the ~/.local/bin/jira shim, which finds jira-cli.yml by walking up
jira_() {
  local key=$(conf .jira.projectKey) a f
  local -a labels=(${(f)"$(jq -r '.jira.labels[]? | "-l" + .' $cfg)"})
  cd $root
  case $1 in
    whoami) conf .me ;;
    get) jira issue view $2 --plain --comments 1000 ;;
    holder)
      a=$(jira issue view $2 --raw) || die "cannot read $2"
      holder "$(jq -r '.fields.assignee.displayName // empty' <<< $a)" ;;
    ready) jira issue list -q "$(conf .ready)" --order-by rank --reverse --plain --no-headers --columns key --paginate ${2:-20} | tr -d '[:blank:]' ;;
    search) jira issue list -p $key -q "text ~ \"${2//\"/\\\"}\" AND statusCategory != Done" --plain --no-headers --columns key,status,summary --paginate ${3:-20} ;;
    claim) moment start; jira issue assign $2 $(jira me) && jira issue move $2 "$REPLY" ;;
    move) body $4; f=$REPLY; moment $3; jira issue move $2 "$REPLY" --comment "$(<$f)" ;;
    comment) body $3; jira issue comment add $2 --no-input < $REPLY ;;
    create)
      local title=$2 type=Task; body $3; f=$REPLY; shift 3
      local -a extra=()
      while (( $# )); do case $1 in --parent) extra+=(-P $2); shift 2 ;; --type) type=$2; shift 2 ;; *) die "create: unknown $1" ;; esac; done
      jira issue create -p $key -t $type -s $title $labels $extra --no-input < $f | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | tail -1 ;;
    link) jira issue link $2 $3 Relates ;;
    attach)
      local api=3; [[ $(conf .jira.installationType) == cloud ]] || api=2
      curl -sf -n -X POST -H "X-Atlassian-Token: no-check" -F "file=@$3" "${$(conf .jira.server)%/}/rest/api/$api/issue/$2/attachments" | jq -e '.[0].id' >/dev/null ;;
    url) print -- "${$(conf .jira.server)%/}/browse/$2" ;;
    raw) shift; jira "$@" ;;
    *) die "unknown command $1" ;;
  esac < /dev/null
}

# ---- taskei: bdei, run from the directory holding .beads/ so it finds this project's room
taskei_() {
  [[ -d $dir/.beads ]] || die "no $dir/.beads; run the ticket-provider skill's setup for this project"
  export BEADS_ACTOR=${BEADS_ACTOR:-$USER}
  local a f st
  local -a ready=(${(f)"$(jq -r '.ready.labels[]? | "--label=" + .' $cfg)"})
  [[ $(conf .ready.unassigned) == true ]] && ready+=(--unassigned)
  cd $dir
  case $1 in
    whoami) conf .me ;;
    get) bdei show $2 --json && bdei comments $2 --json ;;
    holder)
      a=$(bdei show $2 --json) || die "cannot read $2"
      holder "$(jq -r '.[0].assignee // empty' <<< $a)" ;;
    ready) bdei ready $ready --max-items ${2:-20} --json | jq -r "${ROWS}[].id" ;;
    search)
      # one status per call, so --limit counts only open work
      for st in open in_progress; do bdei search $2 --status $st --limit ${3:-20} --json | jq -r "${ROWS}[] | [.id, .status, .title] | @tsv"; done ;;
    claim) moment start; bdei update $2 --claim && bdei update $2 --status $REPLY ;;
    move)
      body $4; f=$REPLY; moment $3
      if [[ $REPLY == closed ]]; then bdei close $2 --reason "$(<$f)"
      else bdei update $2 --status $REPLY && bdei comment $2 --file $f; fi ;;
    comment) body $3; bdei comment $2 --file $REPLY ;;
    create)
      local title=$2 type=task; body $3; f=$REPLY; shift 3
      local -a extra=(${(f)"$(jq -r '.taskei.labels[]? | "--labels=" + .' $cfg)"})
      while (( $# )); do case $1 in --parent) extra+=(--parent $2); shift 2 ;; --type) type=${(L)2}; shift 2 ;; *) die "create: unknown $1" ;; esac; done
      bdei create $title --description-file $f -t $type $extra --json | jq -r "${ROWS}[0].id // .id" ;;
    link) bdei link $2 $3 --type relates-to ;;
    attach) print -u2 -- "ticket: taskei has no attachments through bdei; post the content as a comment"; exit 3 ;;
    url) print -- "https://taskei.amazon.dev/tasks/$2" ;;
    raw) shift; bdei "$@" ;;
    *) die "unknown command $1" ;;
  esac < /dev/null
}

(( $# )) || die "usage: ticket <command> [args]; see the header of $0"
[[ $1 == provider ]] && { print -- $provider; exit 0; }
# file arguments are resolved here, before a provider changes directory
args=()
for x in "$@"; do [[ $x == @* ]] && x=@${${x#@}:a}; args+=("$x"); done
[[ $1 == attach && -n ${3:-} ]] && args[3]=${3:a}
case $provider in
  jira) jira_ "${args[@]}" ;;
  taskei) taskei_ "${args[@]}" ;;
  *) die "unknown provider '$provider' in $cfg" ;;
esac
