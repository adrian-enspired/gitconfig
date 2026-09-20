#!/bin/sh
#
# The content check: is this commit's change already in the default branch?
#
# This is what a squash merge breaks and what git's own patch-id check cannot
# see - a squash collapses many commits into one whose patch-id matches none of
# them. `_landed <commit>` exits 0 when the change is already there.

set -u
. "$(dirname "$0")/lib.sh"

# parent branch, squash-merged into master, with a child cut from it beforehand
new_repo sq >/dev/null
git -C "$AT_TMP/sq" switch -q -c parent
write_commit sq p1 'one' 'feat(p): first'
write_commit sq p2 'two' 'feat(p): second'
p1=$(sha sq 'HEAD~1')
p2=$(sha sq HEAD)
git -C "$AT_TMP/sq" switch -q -c child
write_commit sq c1 'mine' 'feat(c): own work'
c1=$(sha sq HEAD)
git -C "$AT_TMP/sq" switch -q master
squash_merge sq parent

at_out sq _landed "$p1" >/dev/null
is "$AT_RC" '0' "a squashed parent's first commit counts as landed"

at_out sq _landed "$p2" >/dev/null
is "$AT_RC" '0' "a squashed parent's last commit counts as landed"

at_out sq _landed "$c1" >/dev/null
is "$AT_RC" '1' "the child's own commit has not landed"

# a real merge, where the commits themselves are in the default branch's history
new_repo mg >/dev/null
git -C "$AT_TMP/mg" switch -q -c feature
write_commit mg f1 'one' 'feat: merged the ordinary way'
f1=$(sha mg HEAD)
git -C "$AT_TMP/mg" switch -q master
git -C "$AT_TMP/mg" merge -q --no-ff -m 'merge feature' feature

at_out mg _landed "$f1" >/dev/null
is "$AT_RC" '0' 'an ordinary merge counts as landed'

# a root commit has no parent to diff against: not landed, never a false positive
new_repo root >/dev/null
git -C "$AT_TMP/root" switch -q --orphan orphan
write_commit root a 'a' 'unrelated root'
at_out root _landed "$(sha root HEAD)" >/dev/null
is "$AT_RC" '1' 'a root commit is not reported as landed'

# a commit whose file master never saw
new_repo un >/dev/null
git -C "$AT_TMP/un" switch -q -c feature
write_commit un only 'mine' 'feat: unique'
at_out un _landed "$(sha un HEAD)" >/dev/null
is "$AT_RC" '1' 'an unlanded commit is not reported as landed'

t_done
