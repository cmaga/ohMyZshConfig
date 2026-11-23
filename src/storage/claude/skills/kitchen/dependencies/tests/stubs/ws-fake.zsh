#!/usr/bin/env zsh
# A workspace type for the seam cases, with no tool behind it: a directory marked .fakeworkspace holds its repos in
# src/, and worktree NAME holds a git worktree of each repo in worktrees/NAME/src/<repo>.
US=$'\x1f'
verb=$1; shift
case $verb in
  root) # PATH
    d=${1:A}
    while [[ $d != / ]]; do [[ -f $d/.fakeworkspace ]] && { print -r -- $d; exit 0; }; d=${d:h}; done
    print -u2 -- "fake: $1 is in no fake workspace"; exit 1 ;;
  path) print -r -- $1/worktrees/$2 ;; # PROJECT NAME
  repos) # PROJECT ORDER-FILE DIR
    name=$(jq -r .key $2) d=${3:A}
    [[ $d == $1/worktrees/* ]] && name=${${d#$1/worktrees/}%%/*}
    [[ -d $1/worktrees/$name/src ]] || { print -u2 -- "fake: no worktree $name"; exit 1; }
    for r in $1/worktrees/$name/src/*(/N); do
      base=$(jq -r --arg p ${r:t} '.packages[$p] // empty' $2)
      [[ -n $base ]] || { print -u2 -- "fake: ${r:t} is in worktree $name but not in the order's packages"; exit 1; }
      print -r -- "${r:t}$US$r$US$base"
    done ;;
  remove) # PROJECT NAME
    for r in $1/worktrees/$2/src/*(/N); do
      git -C $1/src/${r:t} worktree remove --force $r 2>/dev/null
      git -C $1/src/${r:t} branch -D $2 > /dev/null 2>&1
    done
    rm -rf ${1:?}/worktrees/${2:?} ;;
  echo) printf '[%s]' "$@"; print ;; # PROJECT [ARG...]: what the core handed over, each argument bracketed, for the passthrough case
  *) print -u2 -- "fake: no verb $verb"; exit 1 ;;
esac
