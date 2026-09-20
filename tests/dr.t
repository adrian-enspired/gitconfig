#!/bin/sh
#
# `dr`: rebase onto the parent branch when there is one, onto the default branch
# otherwise, skipping work that has already landed rather than replaying it.
#
# No remotes here, so `ds` skips the sync; these fixtures are about what `dr`
# rebases onto and what it records.

set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------- no parent: default branch ---

new_repo plain >/dev/null
git -C "$AT_TMP/plain" switch -q -c feature
write_commit plain a 'a' 'feat: own work'
git -C "$AT_TMP/plain" switch -q master
write_commit plain m 'm' 'chore: master moves on'
git -C "$AT_TMP/plain" switch -q feature

at_out plain dr >/dev/null
is "$AT_RC" '0' 'rebases onto the default branch'
is "$(sha plain 'feature~1')" "$(sha plain master)" 'the branch now sits on master'
is "$(config plain branch.feature.atbase)" "$(sha plain master)" 'and records the new branch point'
is "$(config plain branch.feature.atbasepending)" '' 'the pending value is cleared'

# ---------------------------------------------- a squashed parent, unrecorded ---

# the incident this whole design exists for: parent squash-merged, child cut from
# it, no recorded branch point, so the merge base wants to replay the parent's work
new_repo sq >/dev/null
git -C "$AT_TMP/sq" switch -q -c parent
write_commit sq p1 'one' 'feat(p): parent work'
git -C "$AT_TMP/sq" switch -q -c child
write_commit sq c1 'mine' 'feat(c): own work'
git -C "$AT_TMP/sq" switch -q master
squash_merge sq parent
git -C "$AT_TMP/sq" branch -q -D parent
git -C "$AT_TMP/sq" switch -q child

at_out sq dr >/dev/null
is "$AT_RC" '0' 'the landed work is skipped, not replayed'
contains "$AT_OUT" 'already on master' 'and it says what it skipped'
is "$(git -C "$AT_TMP/sq" rev-list --count 'master..child')" '1' "only the child's own commit is replayed"
is "$(sha sq 'child~1')" "$(sha sq master)" 'which now sits on master'

# ------------------------------------------- the branch's own work, part landed ---

# two commits on a branch; the first was merged upstream on its own. Rebasing
# should carry the second onto master and leave the first behind.
new_repo part >/dev/null
git -C "$AT_TMP/part" switch -q -c work
write_commit part a 'a' 'feat: first, merged already'
write_commit part b 'b' 'feat: second, still mine'
git -C "$AT_TMP/part" config branch.work.atbase "$(sha part master)"
git -C "$AT_TMP/part" switch -q master
git -C "$AT_TMP/part" merge -q --squash 'work~1' >/dev/null
git -C "$AT_TMP/part" commit -qm 'squashed: the first commit'
git -C "$AT_TMP/part" switch -q work

at_out part dr >/dev/null
is "$AT_RC" '0' 'a partly-landed branch rebases'
is "$(git -C "$AT_TMP/part" rev-list --count 'master..work')" '1' 'replaying only what has not landed'
is "$(git -C "$AT_TMP/part" log -1 --format='%s')" 'feat: second, still mine' 'the right commit survives'
is "$(sha part 'work~1')" "$(sha part master)" 'sitting on master'

# a branch whose work has all landed has nothing left to replay
new_repo done >/dev/null
git -C "$AT_TMP/done" switch -q -c finished
write_commit done x 'x' 'feat: all of it'
git -C "$AT_TMP/done" switch -q master
squash_merge done finished
git -C "$AT_TMP/done" switch -q finished

at_out done dr >/dev/null
is "$AT_RC" '0' 'a fully landed branch is not an error'
contains "$AT_OUT" 'nothing to replay' 'it just says there is nothing to do'

# ------------------------------------------------------ a live parent: restack ---

new_repo stack >/dev/null
git -C "$AT_TMP/stack" switch -q -c parent
write_commit stack p1 'one' 'feat(p): parent work'
git -C "$AT_TMP/stack" switch -q -c child
git -C "$AT_TMP/stack" config branch.child.atparent parent
git -C "$AT_TMP/stack" config branch.child.atbase "$(sha stack parent)"
write_commit stack c1 'mine' 'feat(c): own work'
git -C "$AT_TMP/stack" switch -q parent
write_commit stack p2 'two' 'feat(p): more parent work'
git -C "$AT_TMP/stack" switch -q child

at_out stack dr >/dev/null
is "$AT_RC" '0' 'restacks onto the parent'
is "$(sha stack 'child~1')" "$(sha stack parent)" 'the child now sits on the parent tip'
is "$(git -C "$AT_TMP/stack" rev-list --count 'parent..child')" '1' 'only the child own commits were replayed'
is "$(config stack branch.child.atbase)" "$(sha stack parent)" 'the branch point follows the parent'
is "$(config stack branch.child.atparent)" 'parent' 'the parent is still recorded'

# ------------------------------------------------- a parent that has landed ---

new_repo landed >/dev/null
git -C "$AT_TMP/landed" switch -q -c parent
write_commit landed p1 'one' 'feat(p): parent work'
git -C "$AT_TMP/landed" switch -q -c child
git -C "$AT_TMP/landed" config branch.child.atparent parent
git -C "$AT_TMP/landed" config branch.child.atbase "$(sha landed parent)"
write_commit landed c1 'mine' 'feat(c): own work'
git -C "$AT_TMP/landed" switch -q master
squash_merge landed parent
git -C "$AT_TMP/landed" branch -q -D parent
git -C "$AT_TMP/landed" switch -q child

at_out landed dr >/dev/null
is "$AT_RC" '0' 'a landed parent moves the branch to the default branch'
is "$(sha landed 'child~1')" "$(sha landed master)" 'the child now sits on master'
is "$(config landed branch.child.atparent)" '' 'the parent record is cleared'

# --------------------------------------- a parent that is gone, and unlanded ---

new_repo lost >/dev/null
git -C "$AT_TMP/lost" switch -q -c parent
write_commit lost p1 'one' 'feat(p): parent work'
git -C "$AT_TMP/lost" switch -q -c child
git -C "$AT_TMP/lost" config branch.child.atparent parent
git -C "$AT_TMP/lost" config branch.child.atbase "$(sha lost parent)"
write_commit lost c1 'mine' 'feat(c): own work'
git -C "$AT_TMP/lost" branch -q -D parent

at_out lost dr >/dev/null
is "$AT_RC" '1' 'a parent that is gone and has not landed is fatal'
contains "$AT_OUT" 'parent' 'and names the parent'

# ------------------------------------------------------- a stale parent ---

# parent is behind the default branch, so restacking onto it leaves the child
# behind too: stop and make the user choose.
mk_stale() {
    new_repo "$1" >/dev/null
    git -C "$AT_TMP/$1" switch -q -c parent
    write_commit "$1" p1 'one' 'feat(p): parent work'
    git -C "$AT_TMP/$1" switch -q -c child
    git -C "$AT_TMP/$1" config branch.child.atparent parent
    git -C "$AT_TMP/$1" config branch.child.atbase "$(sha "$1" parent)"
    write_commit "$1" c1 'mine' 'feat(c): own work'
    git -C "$AT_TMP/$1" switch -q master
    write_commit "$1" m 'm' 'chore: master moves on'
    git -C "$AT_TMP/$1" switch -q child
}

mk_stale stale1
at_out stale1 dr >/dev/null
is "$AT_RC" '1' 'a stale parent stops without a flag'
contains "$AT_OUT" '--restack' 'and names the flags'

mk_stale stale2
at_out stale2 dr --no-restack >/dev/null
is "$AT_RC" '0' '--no-restack proceeds onto the stale parent'
is "$(sha stale2 'child~1')" "$(sha stale2 parent)" 'the child sits on the stale parent'

mk_stale stale3
at_out stale3 dr --restack >/dev/null
is "$AT_RC" '0' '--restack rebases the ancestors first'
is "$(sha stale3 'parent~1')" "$(sha stale3 master)" 'the parent now sits on master'
is "$(sha stale3 'child~1')" "$(sha stale3 parent)" 'and the child on the parent'
is "$(git -C "$AT_TMP/stale3" branch --show-current)" 'child' 'and it leaves you where you started'

# ------------------------------------------------------------ a dirty tree ---

new_repo dirty >/dev/null
git -C "$AT_TMP/dirty" switch -q -c feature
write_commit dirty a 'a' 'feat: own work'
printf 'uncommitted\n' >"$AT_TMP/dirty/a"

at_out dirty dr >/dev/null
is "$AT_RC" '1' 'a dirty tree stops the rebase'

t_done
