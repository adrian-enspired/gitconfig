#!/bin/sh
#
# `bd`: delete branches whose work has landed, including squash-merged ones -
# `git branch --merged` never sees those, which is why it uses the content check.

set -u
. "$(dirname "$0")/lib.sh"

# squash-merged, really merged, and unmerged branches side by side
new_repo mix >/dev/null
git -C "$AT_TMP/mix" switch -q -c squashed
write_commit mix s1 'one' 'feat(s): squashed work'
git -C "$AT_TMP/mix" switch -q master
squash_merge mix squashed

git -C "$AT_TMP/mix" switch -q -c merged
write_commit mix m1 'one' 'feat(m): merged work'
git -C "$AT_TMP/mix" switch -q master
git -C "$AT_TMP/mix" merge -q --no-ff -m 'merge merged' merged

git -C "$AT_TMP/mix" switch -q -c open
write_commit mix o1 'one' 'feat(o): still open'
git -C "$AT_TMP/mix" switch -q master

at_out mix bd -y >/dev/null
is "$AT_RC" '0' 'bd succeeds'

branches=$(git -C "$AT_TMP/mix" branch --format='%(refname:short)' | tr '\n' ' ')
contains "$branches" 'open' 'an open branch is kept'
contains "$branches" 'master' 'the default branch is kept'
case $branches in
    *squashed*) not_ok 'a squash-merged branch is deleted' "still there: $branches" ;;
    *)          ok 'a squash-merged branch is deleted' ;;
esac
case $branches in
    *merged*) not_ok 'a merged branch is deleted' "still there: $branches" ;;
    *)        ok 'a merged branch is deleted' ;;
esac

# the branch you are standing on is never deleted, landed or not
new_repo cur >/dev/null
git -C "$AT_TMP/cur" switch -q -c landed
write_commit cur a 'a' 'feat: landed work'
git -C "$AT_TMP/cur" switch -q master
squash_merge cur landed
git -C "$AT_TMP/cur" switch -q landed

at_out cur bd -y >/dev/null
contains "$(git -C "$AT_TMP/cur" branch --format='%(refname:short)' | tr '\n' ' ')" 'landed' \
    'the current branch is kept even when it has landed'

# nothing to do is not an error
new_repo none >/dev/null
git -C "$AT_TMP/none" switch -q -c open
write_commit none a 'a' 'feat: still open'
git -C "$AT_TMP/none" switch -q master

at_out none bd -y >/dev/null
is "$AT_RC" '0' 'nothing to delete is not an error'
contains "$AT_OUT" 'no branches' 'and it says so'

t_done
