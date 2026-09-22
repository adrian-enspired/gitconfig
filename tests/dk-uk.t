#!/bin/sh
#
# `dk` and `uk`: what they name the branch, and what they record about where it
# started. `uk` also decides what happens to uncommitted work.

set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------- dk ---

new_repo dk >/dev/null
git -C "$AT_TMP/dk" config at.ticket.prefix AT
write_commit dk m 'm' 'chore: master work'

at_out dk dk 12345 my-slug >/dev/null
is "$AT_RC" '0' 'dk succeeds'
is "$(git -C "$AT_TMP/dk" branch --show-current)" 'AT-12345.my-slug' 'the branch is named from the ticket'
is "$(config dk branch.AT-12345.my-slug.atbase)" "$(sha dk master)" 'the branch point is the default branch tip'
is "$(config dk branch.AT-12345.my-slug.atparent)" '' 'a branch off the default branch has no parent'

# dk always starts from the default branch, wherever you are standing
git -C "$AT_TMP/dk" switch -q -c somewhere-else
write_commit dk x 'x' 'feat: unrelated'
at_out dk dk AT-2 other >/dev/null
is "$(sha dk HEAD)" "$(sha dk master)" 'dk starts from the default branch, not the current one'

# ------------------------------------------------------------------- uk ---

new_repo uk >/dev/null
git -C "$AT_TMP/uk" switch -q -c parent
write_commit uk p 'p' 'feat(p): parent work'
parent_tip=$(sha uk HEAD)

at_out uk uk AT-3 child >/dev/null
is "$AT_RC" '0' 'uk succeeds'
is "$(git -C "$AT_TMP/uk" branch --show-current)" 'AT-3.child' 'uk names the branch the same way'
is "$(config uk branch.AT-3.child.atparent)" 'parent' 'the branch it came from is recorded as the parent'
is "$(config uk branch.AT-3.child.atbase)" "$parent_tip" 'and the parent tip as the branch point'

# uncommitted work follows you onto the new branch, as a quicksave
new_repo f5 >/dev/null
git -C "$AT_TMP/f5" switch -q -c parent
write_commit f5 p 'p' 'feat(p): parent work'
printf 'in progress\n' >"$AT_TMP/f5/wip"

at_out f5 uk AT-4 child >/dev/null
is "$(git -C "$AT_TMP/f5" log -1 --format='%s')" 'working' 'uk quicksaves what was in the tree'
is "$(git -C "$AT_TMP/f5" status --porcelain)" '' 'leaving a clean tree'
is "$(git -C "$AT_TMP/f5" rev-list --count 'parent..HEAD')" '1' 'the quicksave lands on the new branch'
is "$(config f5 branch.AT-4.child.atbase)" "$(sha f5 parent)" 'the branch point is the parent tip, not the quicksave'

# --no-f5 leaves the work uncommitted
new_repo nof5 >/dev/null
git -C "$AT_TMP/nof5" switch -q -c parent
write_commit nof5 p 'p' 'feat(p): parent work'
printf 'in progress\n' >"$AT_TMP/nof5/wip"

at_out nof5 uk --no-f5 AT-5 child >/dev/null
is "$(git -C "$AT_TMP/nof5" branch --show-current)" 'AT-5.child' '--no-f5 still creates the branch'
contains "$(git -C "$AT_TMP/nof5" status --porcelain)" 'wip' 'and leaves the work uncommitted'

# branching off the default branch with uk records no parent: that is not a stack
new_repo flat >/dev/null
at_out flat uk AT-6 thing >/dev/null
is "$(config flat branch.AT-6.thing.atparent)" '' 'uk from the default branch records no parent'

t_done
