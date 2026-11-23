#!/usr/bin/env zsh
# The kitchen's Brazil workspace type. A project is a team's parent Brazil workspace: no version set, packages
# checked out into src/ as orders need them. An order works in `brazil worktree` <ws>/worktrees/<name>, pinned to the
# order's version_set, each package on its own base from the order's packages ({"<Package>": "<base>"}). The core
# finds this file from the line's `workspace` field and calls
#
#     brazil.zsh VERB PROJECT [ARG...]      rows and paths on stdout; a message on stderr and exit 1 on failure
#
# A repo row is label US dir US base (US = $'\x1f'): the package, its git working copy, the branch it merges into.
set -uo pipefail
setopt extendedglob

US=$'\x1f'
LOCK=
LOCK_STALE_MINUTES=15
typeset -A BASE

die() { print -u2 -- "brazil: $*"; exit 1; }
warn() { print -u2 -- "brazil: $*"; }

unlock() { [[ -n $LOCK ]] && rmdir $LOCK 2>/dev/null; LOCK=; }
trap unlock EXIT

lock() {
  local l=$1/.kitchen-brazil.lock
  until mkdir $l 2>/dev/null; do
    [[ -d $l ]] || die "cannot lock $1"
    [[ -n $(find $l -maxdepth 0 -mmin +$LOCK_STALE_MINUTES 2>/dev/null) ]] && rmdir $l 2>/dev/null
    sleep 1
  done
  LOCK=$l
}

valid_name() {
  [[ $1 == [A-Za-z0-9][A-Za-z0-9._-]# ]] || die "bad worktree name [$1]"
}

order_key() {
  local k=$(jq -r '.key // ""' $1)
  valid_name $k
  print -r -- $k
}

order_vs() {
  local v=$(jq -r '.version_set // ""' $1)
  [[ $v == [A-Za-z0-9][A-Za-z0-9_.-]#/[A-Za-z0-9][A-Za-z0-9_.-]# ]] || die "the order needs version_set=<Group>/<Name>, not [$v]"
  print -r -- $v
}

read_bases() {
  local l
  for l in ${(f)"$(jq -r '(.packages // {}) | to_entries[] | "\(.key)\t\(.value)"' $1)"}; do
    [[ $l == [A-Za-z0-9][A-Za-z0-9._-]#$'\t'[A-Za-z0-9][A-Za-z0-9._/-]# ]] || die "the order's packages maps each package name to a branch, not [$l]"
    BASE[${l%%$'\t'*}]=${l#*$'\t'}
  done
}

wt_of() { # PROJECT NAME: the directory of worktree NAME
  print -r -- $1/worktrees/$2
}

rows() {
  local wt=$(wt_of $1 $3) key=$(jq -r .key $2) d p; local -a lacks=()
  [[ -d $wt/src ]] || die "no worktree $3; kitchen.zsh workspace enter $key"
  read_bases $2
  for p in ${(ok)BASE}; do [[ -e $wt/src/$p/.git ]] || lacks+=($p); done
  (( $#lacks )) && die "worktree $3 lacks ${(j:, :)lacks}, which the order's packages list: kitchen.zsh workspace enter $key${${3:#$key}:+ $3} adds them"
  for d in $wt/src/*(/N); do
    [[ -e $d/.git ]] || continue
    [[ -n ${BASE[${d:t}]:-} ]] || die "${d:t} is in worktree $3 but not in the order's packages: kitchen.zsh order set $key packages=@<file>"
    print -r -- "${d:t}$US$d$US$BASE[${d:t}]"
  done
}

is_root() { # DIR: a workspace, which `brazil ws create` leaves as a lone packageInfo, and not one of its worktrees
  [[ -f $1/packageInfo ]] && ! grep -qE '^[[:space:]]*worktree[[:space:]]*=[[:space:]]*"?true' $1/packageInfo
}

aligned_base() { # DIR BRANCH: the base enter last put the branch on, recorded as its kitchenbase; empty before the first
  git -C $1 config branch.$2.kitchenbase
}

fresh() { # DIR BRANCH: brazil made the branch and nothing has moved it or changed its tree since
  (( $(git -C $1 reflog show --format=%h refs/heads/$2 | wc -l) == 1 )) && [[ -z $(git -C $1 status --porcelain) ]]
}

no_work_past() { # DIR BRANCH BASE: a clean tree, and git counts no commit on the branch past origin/BASE
  local n
  [[ -z $(git -C $1 status --porcelain) ]] && n=$(git -C $1 rev-list --count origin/$3..refs/heads/$2 2>/dev/null) && (( n == 0 ))
}

align() { # DIR BASE BRANCH: put the branch on its base unless it holds work: brazil starts it at the parent checkout's HEAD, and the order's base can change
  local d=$1 base=$2 br=$3 was
  git -C $d branch -q --set-upstream-to=origin/$base $br || die "could not make ${d:t}'s $br track origin/$base"
  was=$(aligned_base $d $br)
  [[ $was == $base ]] && return 0
  if { [[ -z $was ]] && fresh $d $br } || { [[ -n $was ]] && no_work_past $d $br $was }; then
    git -C $d reset -q --hard origin/$base || die "could not move ${d:t} onto origin/$base"
  else
    warn "${d:t}: $br holds work, so it stays where it is instead of moving onto origin/$base"
  fi
  git -C $d config branch.$br.kitchenbase $base
}

verb_root() { # PATH: the project root PATH lies in, even from inside one of its worktrees; exit 1 when it lies in none
  local d=${1:A}
  while [[ $d != / ]] && ! is_root $d; do d=${d:h}; done
  [[ $d != / ]] || die "$1 is in no Brazil workspace"
  print -r -- $d
}

verb_path() { # PROJECT NAME: the directory worktree NAME has, whether or not it exists
  valid_name $2
  wt_of $1 $2
}

verb_repos() { # PROJECT ORDER-FILE DIR: one repo row per package of the worktree DIR lies in, else of the order's own; exit 1 unless the worktree holds exactly the order's packages
  local name d=${3:A} all=$(wt_of $1 '')
  name=$(order_key $2) || exit 1
  [[ $d == $all?* ]] && name=${${d#$all}%%/*}
  rows $1 $2 $name
}

verb_remove() { # PROJECT NAME: delete worktree NAME and its branches, without questions; when brazil cannot, it stays
  valid_name $2
  [[ -e $(wt_of $1 $2) ]] || return 0
  lock $1
  brazil worktree delete --workspace $1 --name $2 --force > /dev/null || die "brazil could not delete worktree $2, so it stays"
}

verb_bases() { # PROJECT ORDER-FILE: one package<TAB>base row per package of the order
  local p
  read_bases $2
  for p in ${(ok)BASE}; do printf '%s\t%s\n' $p $BASE[$p]; done
}

verb_enter() { # PROJECT ORDER-FILE [NAME]: make worktree NAME (the order's key by default) match the order, creating or repairing it; print its path
  local key name vs wt pkg d pinned tip; local -a add
  key=$(order_key $2) || exit 1
  name=${3:-$key}; valid_name $name
  vs=$(order_vs $2) || exit 1
  read_bases $2
  (( $#BASE )) || die "order $key has no packages: kitchen.zsh order set $key packages=@<file>"
  wt=$(wt_of $1 $name)
  lock $1
  for pkg in ${(ok)BASE}; do [[ -e $wt/src/$pkg/.git ]] || add+=(-p $pkg); done
  if [[ -e $wt ]]; then
    pinned=$(sed -n 's/^[[:space:]]*versionSet[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' $wt/packageInfo 2>/dev/null | head -1)
    [[ $pinned == $vs ]] || die "worktree $name is pinned to [$pinned]; the order says $vs"
    if (( $#add )); then brazil worktree use --workspace $1 --name $name $add >&2 || die "brazil could not add ${(j:, :)${add:#-p}} to worktree $name"; fi
  else
    brazil worktree create --workspace $1 --name $name --versionSet $vs $add >&2 || die "brazil could not create worktree $name"
  fi
  unlock
  for pkg in ${(ok)BASE}; do
    d=$wt/src/$pkg
    [[ -e $d/.git ]] || die "worktree $name lacks package $pkg"
    git -C $d fetch -q origin $BASE[$pkg] 2>/dev/null || die "$pkg has no branch $BASE[$pkg] on origin: fix the order's packages"
    if [[ $name == $key ]]; then
      align $d $BASE[$pkg] $key
    else
      tip=$(git -C $d rev-parse -q --verify "refs/heads/$key^{commit}") || die "$pkg has no branch $key: kitchen.zsh workspace enter $key first"
      git -C $d checkout -q -f --detach $tip || die "could not check out $key in $d"
    fi
  done
  print -r -- $wt
}

verb_check() { # PROJECT ORDER-FILE [NAME]: one status row per package; exit 1 when a package does not track its base
  local key name out row pkg d base up p def bad=; local -a st
  key=$(order_key $2) || exit 1
  name=${3:-$key}; valid_name $name
  out=$(rows $1 $2 $name) || exit 1
  for row in ${(f)out}; do
    IFS=$US read -r pkg d base <<< $row
    up=$(git -C $d rev-parse -q --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || up=nothing
    st=( ${(f)"$(git -C $d status --porcelain)"} )
    printf '%s\t%s\ttracks %s\t%s ahead\t%s dirty\n' $pkg $base $up "$(git -C $d rev-list --count origin/$base..HEAD 2>/dev/null)" $#st
    [[ $up == origin/$base ]] || { warn "$pkg tracks $up, not origin/$base: kitchen.zsh workspace enter $key sets it"; bad=1; }
    (( $#st == 1 )) && [[ $st[1] == ' M package-lock.json' ]] && warn "$pkg: only package-lock.json changed, as brazil-build leaves it: git -C $d restore package-lock.json"
    p=$1/src/$pkg
    def=$(git -C $p symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
    [[ -n $(git -C $p status --porcelain 2>/dev/null) ]] && warn "the parent checkout $p has uncommitted changes; an order never edits it"
    [[ -n $def && $(git -C $p branch --show-current 2>/dev/null) != ${def#origin/} ]] && warn "the parent checkout $p is off ${def#origin/}; an order never switches it"
  done
  [[ -z $bad ]]
}

case ${1:-} in
  root|path|repos|remove|bases|enter|check) verb=$1; shift; verb_$verb "$@" ;;
  *) die "usage: brazil.zsh root PATH | path|repos|remove|bases|enter|check PROJECT ..." ;;
esac
