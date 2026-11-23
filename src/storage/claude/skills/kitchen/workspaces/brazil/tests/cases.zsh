# The Brazil workspace type's cases. scheduler.zsh sources this file and runs each function below the "# --- cases"
# marker as a case; the helpers above it are not cases. The stubs tests/stubs/brazil and tests/stubs/cr go on PATH.
BZ=${0:A:h}

bzremote() { # PKG: the package's origin, a copy of the case's origin whose default branch is mainline
  cp -R $CASE/origin.git $BRAZIL_REMOTES/$1.git
  git -C $BRAZIL_REMOTES/$1.git branch -m main mainline
  git -C $BRAZIL_REMOTES/$1.git symbolic-ref HEAD refs/heads/mainline
}
bztesting() { # PKG: the package's origin gains a testing branch, then its mainline moves on, so a branch made at mainline is not on testing
  local s=$CASE/seed-$1
  git clone -q $BRAZIL_REMOTES/$1.git $s 2>/dev/null
  git -C $s checkout -q -b testing; print testing > $s/src/b.txt
  git -C $s add -A; git -C $s commit -q -m testing
  git -C $s checkout -q mainline; print mainline > $s/src/m.txt
  git -C $s add -A; git -C $s commit -q -m mainline
  git -C $s push -q origin mainline testing 2>/dev/null
}
# a team workspace as `brazil ws create` leaves it, a packageInfo and no src/, since no package is checked out yet:
# PkgA builds from mainline and PkgB from testing
bzws() {
  WS=$CASE/ws BOOKDIR=$KITCHEN_BOOK/ws
  export BRAZIL_REMOTES=$CASE/remotes CR_LOG=$CASE/cr.log CR_PLAN=$CASE/cr.plan
  mkdir -p $BRAZIL_REMOTES $WS/.claude/kitchen
  print -r -- $'base = {workspace = harness_ws; };\npackages = { };' > $WS/packageInfo
  cp $PROJ/.claude/kitchen/house.md $WS/.claude/kitchen/house.md
  bzremote PkgA; bzremote PkgB; bztesting PkgB
  cp $BZ/stubs/{brazil,cr} $SB/bin/
  kw $WS line add $WS --workspace brazil > /dev/null 2>&1
  kw $WS line set ws co-write_after=0 guided_after=0 auto_after=0 > /dev/null 2>&1
}
bzorder() { # KEY [field=value...]: an auto order on one version set, PkgA on mainline and PkgB on testing
  kw $WS order new $1 status=ready recipe=feature mode=auto version_set=ARCardinalUWC/development \
    'packages={"PkgA":"mainline","PkgB":"testing"}' 'station=["PkgA/src/","PkgB/"]' "${@:2}" > /dev/null 2>&1
}
bzcreate() { # NAME: worktree NAME as brazil makes it, each package's branch at the parent's HEAD tracking the parent's upstream
  brazil worktree create --workspace $WS --name $1 --versionSet ARCardinalUWC/development -p PkgA -p PkgB > /dev/null
}
bzwt() { # NAME: worktree NAME made by brazil, then PkgB moved onto testing and tracking it, as an aligned worktree is
  bzcreate $1
  git -C $(bzpkg $1 PkgB) reset -q --hard origin/testing
  git -C $(bzpkg $1 PkgB) branch -q --set-upstream-to=origin/testing $1
}
bzpkg() { print -r -- $WS/worktrees/$1/src/$2 } # NAME PKG
bzcommit() { # NAME PKG FILE LINE
  mkdir -p $(bzpkg $1 $2)/${3:h}; print -r -- $4 >> $(bzpkg $1 $2)/$3
  git -C $(bzpkg $1 $2) add -A; git -C $(bzpkg $1 $2) commit -q -m "change $3"
}
bztip() { git -C $BRAZIL_REMOTES/$1.git rev-parse $2 } # PKG BRANCH: the branch's tip on origin

# --- cases

line_add_registers_the_workspace_from_a_package_a_worktree_or_a_worktree_package_and_refuses_elsewhere() {
  bzws; bzwt K1
  local d
  for d in $WS $WS/src/PkgA $WS/worktrees/K1 $WS/worktrees/K1/src/PkgB; do
    eq "$(kw $d line add $d --workspace brazil 2>&1)" ws "from ${d#$CASE/}"
  done
  OUT=$(kw $CASE line add $CASE --workspace brazil 2>&1); RC=$?
  eq $RC 1 'a directory in no workspace'
  mkdir -p $CASE/gitws/src; cp $WS/packageInfo $CASE/gitws/; git init -q $CASE/gitws
  OUT=$(kw $CASE/gitws line add $CASE/gitws --workspace brazil 2>&1); RC=$?
  eq $RC 1 'a workspace inside a git repository'
  eq "$(ls $KITCHEN_BOOK 2>/dev/null)" ws 'one line for the workspace, none for the others'
}

a_workspace_fresh_from_brazil_ws_create_registers_before_any_package_is_checked_out() {
  bzws
  eq "$(kw $WS line add $WS --workspace brazil 2>&1)" ws 'line add from a workspace that holds only its packageInfo'
  eq "$(jq -r .workspace $BOOKDIR/line.json 2>&1)" brazil 'registers it as a Brazil line'
}

enter_creates_the_worktree_on_the_orders_version_set_with_each_package_on_its_own_base() {
  bzws; bzorder K1
  eq "$(kw $WS workspace enter K1 2>/dev/null)" $WS/worktrees/K1 'prints the worktree'
  has "$(cat $WS/worktrees/K1/packageInfo 2>&1)" 'versionSet = "ARCardinalUWC/development"' 'pinned to the order'"'"'s version set'
  eq "$(git -C $(bzpkg K1 PkgA) rev-parse HEAD 2>&1)" "$(bztip PkgA mainline)" 'PkgA starts at mainline'
  eq "$(git -C $(bzpkg K1 PkgB) rev-parse HEAD 2>&1)" "$(bztip PkgB testing)" 'PkgB starts at testing, though brazil made its branch at the parent'"'"'s HEAD'
  eq "$(git -C $WS/src/PkgB rev-parse --abbrev-ref HEAD 2>&1) $(git -C $WS/src/PkgB rev-parse HEAD 2>&1)" "mainline $(bztip PkgB mainline)" 'the parent checkout is untouched'
  bzcommit K1 PkgA src/a.txt two; bzcommit K1 PkgB src/b.txt two
  ( cd $WS/worktrees/K1/src 2>/dev/null && cr --all --summary t --no-open ) > /dev/null 2>&1
  eq "$([[ -f $CR_PLAN ]] && <$CR_PLAN)" $'PkgA -> mainline (1)\nPkgB -> testing (1)' 'cr --all plans each package against the upstream enter gave it'
}

enter_again_repairs_a_half_made_worktree_keeps_committed_work_and_adds_a_package_the_order_gained() {
  bzws; bzorder K1; bzcreate K1
  bzcommit K1 PkgA src/a.txt early
  local a=$(git -C $(bzpkg K1 PkgA) rev-parse HEAD)
  OUT=$(kw $WS workspace enter K1 2>&1 > /dev/null)
  eq "$(git -C $(bzpkg K1 PkgB) rev-parse HEAD)" "$(bztip PkgB testing)" 'a worktree brazil made and nothing aligned is put on its base'
  eq "$(git -C $(bzpkg K1 PkgA) rev-parse HEAD)" $a 'a package committed in before any enter keeps its commit'
  has "${(F)${(@M)${(@f)OUT}:#*PkgA*}}" 'holds work' 'and enter warns that it holds work'
  bzcommit K1 PkgB src/b.txt work
  local head=$(git -C $(bzpkg K1 PkgB) rev-parse HEAD)
  kw $WS workspace enter K1 > /dev/null 2>&1
  eq "$(git -C $(bzpkg K1 PkgB) rev-parse HEAD)" $head 'entering again leaves committed work where it is'
  bzremote PkgC; bztesting PkgC
  kw $WS order set K1 'packages={"PkgA":"mainline","PkgB":"testing","PkgC":"testing"}' > /dev/null 2>&1
  kw $WS workspace enter K1 > /dev/null 2>&1
  eq "$(git -C $(bzpkg K1 PkgC) rev-parse --abbrev-ref '@{u}' 2>&1) $(git -C $(bzpkg K1 PkgC) rev-parse HEAD 2>&1)" "origin/testing $(bztip PkgC testing)" 'the package the order gained is added on its base, tracking it'
  eq "$(git -C $(bzpkg K1 PkgA) rev-parse HEAD) $(git -C $(bzpkg K1 PkgB) rev-parse HEAD)" "$a $head" 'and the others stay as they were'
}

enter_again_after_a_base_fix_moves_a_package_the_order_never_changed_onto_its_new_base() {
  bzws; bzorder K1
  kw $WS workspace enter K1 > /dev/null 2>&1
  kw $WS order set K1 'packages={"PkgA":"mainline","PkgB":"mainline"}' > /dev/null 2>&1
  kw $WS workspace enter K1 > /dev/null 2>&1
  eq "$(git -C $(bzpkg K1 PkgB) rev-parse HEAD 2>&1) $(git -C $(bzpkg K1 PkgB) rev-parse --abbrev-ref '@{u}' 2>&1)" "$(bztip PkgB mainline) origin/mainline" 'PkgB sits on its fixed base, tracking it'
  bzcommit K1 PkgA src/a.txt two
  ( cd $WS/worktrees/K1/src 2>/dev/null && cr --all --summary t --no-open ) > /dev/null 2>&1
  eq "$([[ -f $CR_PLAN ]] && <$CR_PLAN)" 'PkgA -> mainline (1)' 'the CR carries only the commit the order made'
}

enter_refuses_a_version_set_the_worktree_is_not_pinned_to_and_a_base_origin_lacks() {
  bzws; bzorder K1; bzwt K1
  kw $WS order set K1 version_set=ARSparrowTconUWC/development > /dev/null 2>&1
  OUT=$(kw $WS workspace enter K1 2>&1); RC=$?
  eq $RC 1 'a pinned worktree is not pinned again'
  has "$OUT" ARCardinalUWC/development 'and says what it is pinned to'
  bzorder K2 'packages={"PkgA":"nosuchbranch"}'
  OUT=$(kw $WS workspace enter K2 2>&1); RC=$?
  eq $RC 1 'a base origin lacks'
  has "$OUT" nosuchbranch 'is named'
}

two_enters_at_once_leave_both_worktrees_whole() {
  bzws; bzorder K1; bzorder K2
  export BRAZIL_STUB_HOLD=2
  kw $WS workspace enter K1 > /dev/null 2>&1 & kw $WS workspace enter K2 > /dev/null 2>&1 & wait
  unset BRAZIL_STUB_HOLD
  local k
  for k in K1 K2; do
    isyes "[[ -e $(bzpkg $k PkgA)/.git ]]" "$k holds PkgA"
    eq "$(git -C $(bzpkg $k PkgB) rev-parse HEAD 2>&1)" "$(bztip PkgB testing)" "$k holds PkgB on its base"
  done
}

the_gate_records_each_package_against_its_own_base_from_anywhere_in_the_workspace() {
  bzws; bzorder K1; bzwt K1
  bzcommit K1 PkgA src/a.txt two; bzcommit K1 PkgB src/b.txt two
  kw $WS order gated K1 > /dev/null 2>&1
  eq "$(ord K1 gated_base)" "PkgA: $(git -C $(bzpkg K1 PkgA) merge-base HEAD origin/mainline)"$'\n'"PkgB: $(git -C $(bzpkg K1 PkgB) merge-base HEAD origin/testing)" 'gated_base: each package against its own base'
  eq "$(kw $WS sample K1 2>&1)" verify 'no verdict yet, asked from the workspace root'
  eq "$(kw $(bzpkg K1 PkgB)/src sample K1 2>&1)" verify 'the same from inside a package'
  kw $WS order verdict K1 PASS notes > /dev/null 2>&1
  eq "$(kw $WS sample K1 2>&1)" no 'a verdict covers the change'
}

the_gate_refuses_a_package_in_the_worktree_that_the_orders_packages_lack() {
  bzws; bzorder K1 'packages={"PkgA":"mainline"}'; bzwt K1
  bzcommit K1 PkgB src/b.txt two
  OUT=$(kw $WS order gated K1 2>&1); RC=$?
  eq $RC 1 'gated refuses'
  has "$OUT" PkgB 'naming the package'
  eq "$(ord K1 gated)" '' 'and records no gate that skips it'
}

each_check_and_the_gate_refuse_a_worktree_that_lacks_a_package_the_order_lists() {
  bzws; bzorder K1
  brazil worktree create --workspace $WS --name K1 --versionSet ARCardinalUWC/development -p PkgA > /dev/null
  OUT=$(kw $WS each K1 -- true 2>&1); RC=$?
  isyes '(( RC ))' 'each exits non-zero'
  has "$OUT" PkgB 'each names the missing package'
  OUT=$(kw $WS workspace check K1 2>&1); RC=$?
  isyes '(( RC ))' 'check exits non-zero'
  has "$OUT" PkgB 'check names it'
  OUT=$(kw $WS order gated K1 2>&1); RC=$?
  isyes '(( RC ))' 'gated exits non-zero'
  has "$OUT" PkgB 'gated names it'
  eq "$(ord K1 gated)" '' 'and records no gate that skips it'
}

the_verify_worktree_holds_the_gated_change_and_a_verdict_from_it_covers_that_change() {
  bzws; bzorder K1; bzwt K1
  bzcommit K1 PkgA src/a.txt two; bzcommit K1 PkgB src/b.txt two
  kw $WS order gated K1 > /dev/null 2>&1
  eq "$(kw $WS workspace enter K1 verify-K1 2>/dev/null)" $WS/worktrees/verify-K1 'the verifier gets a worktree of its own'
  local p
  for p in PkgA PkgB; do
    eq "$(git -C $(bzpkg verify-K1 $p) rev-parse HEAD 2>&1)" "$(git -C $(bzpkg K1 $p) rev-parse HEAD)" "$p at the tip of the order branch"
    eq "$(git -C $(bzpkg verify-K1 $p) branch --show-current 2>&1)" '' "$p detached"
  done
  bzcommit K1 PkgA src/a.txt three
  kw $(bzpkg verify-K1 PkgB) order verdict K1 PASS notes > /dev/null 2>&1
  eq "$(ord K1 verdict)" PASS 'the verdict is recorded'
  eq "$(ord K1 verdict_patch)" "$(ord K1 gated)" 'it covers what the verifier checked out, not the author'"'"'s later commit'
}

check_fails_naming_the_package_that_does_not_track_its_base() {
  bzws; bzorder K1; bzwt K1
  OUT=$(kw $WS workspace check K1 2>/dev/null); RC=$?
  eq $RC 0 'every package tracks its base'
  has "${(F)${(@M)${(@f)OUT}:#PkgB*}}" origin/testing 'the PkgB row says what it tracks'
  git -C $(bzpkg K1 PkgB) branch -q --set-upstream-to=origin/mainline K1
  OUT=$(kw $WS workspace check K1 2>&1 > /dev/null); RC=$?
  eq $RC 1 'a package tracking another branch'
  has "$OUT" PkgB 'is named'
  lacks "$OUT" PkgA 'alone'
}

prune_removes_each_package_the_verify_worktree_and_the_brazil_worktree_and_keeps_a_dirty_package() {
  bzws; bzorder K1; bzorder K2; bzwt K1; bzwt K2
  bzcommit K1 PkgA src/a.txt two
  bzcreate verify-K1
  local p; for p in PkgA PkgB; do git -C $(bzpkg verify-K1 $p) checkout -q --detach K1; done
  print x > $(bzpkg K2 PkgA)/loose.txt
  kw $WS order set K1 status=done > /dev/null 2>&1; kw $WS order set K2 status=done > /dev/null 2>&1
  OUT=$(kw $WS prune 2>&1)
  has "$OUT" 'removed PkgA (K1)' 'package PkgA'; has "$OUT" 'removed PkgB (K1)' 'package PkgB'
  has "$OUT" 'removed verify-K1' 'the verify worktree, which holds the order'"'"'s unpushed commit'
  has "$OUT" 'kept PkgA: uncommitted changes' 'a dirty package is kept'
  isyes "[[ ! -e $WS/worktrees/K1 && ! -e $WS/worktrees/verify-K1 && -d $(bzpkg K2 PkgA) ]]" 'the clean worktrees are gone and the dirty package stays'
  eq "$(git -C $WS/src/PkgA branch --list K1 verify-K1)" '' 'their branches are gone'
  lacks "$(git -C $WS/src/PkgA worktree list)" /worktrees/K1/ 'git no longer lists the order'"'"'s package'
  lacks "$(git -C $WS/src/PkgA worktree list)" /worktrees/verify-K1/ 'nor the verifier'"'"'s'
}

prune_runs_the_teardown_of_each_package_of_the_verify_worktree() {
  bzws; bzorder K1; bzwt K1
  bzcreate verify-K1
  local p; for p in PkgA PkgB; do
    git -C $(bzpkg verify-K1 $p) checkout -q --detach K1
    mkdir -p $(bzpkg verify-K1 $p)/.claude-artifacts
    print "echo $p >> $WS/teardowns" > $(bzpkg verify-K1 $p)/.claude-artifacts/teardown.sh
  done
  kw $WS order set K1 status=done > /dev/null 2>&1
  OUT=$(kw $WS prune 2>&1)
  eq "$(sort $WS/teardowns 2>&1)" $'PkgA\nPkgB' 'each package ran its teardown once'
  has "$OUT" 'removed verify-K1' 'then the verify worktree went'
}

workspace_bases_lists_each_package_of_the_order_with_its_base() {
  bzws; bzorder K1
  eq "$(kw $WS workspace bases K1 2>&1)" $'PkgA\tmainline\nPkgB\ttesting' 'one package<TAB>base row each'
}
