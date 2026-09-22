#!/bin/sh
#
# `b` and `bk` after the collapse: one listing command and one checkout command,
# with `-r <remote>` where there used to be a separate `br`/`bgr`/`bkr`.
#
# `-r` takes a remote by name. There is no "all remotes" any more: it fetched
# from every remote to answer, which is slow and unpredictable.

set -u
. "$(dirname "$0")/lib.sh"

# a repo with a few branches, and a bare remote holding two of its own
new_repo b >/dev/null
for n in feature-one feature-two other; do
    git -C "$AT_TMP/b" branch "$n"
done
git init -q --bare "$AT_TMP/b-remote.git"
git -C "$AT_TMP/b" remote add origin "$AT_TMP/b-remote.git"
git -C "$AT_TMP/b" push -q origin master feature-one

# ------------------------------------------------------------- listing ---

out=$(at b b)
contains "$out" 'feature-one' 'b lists local branches'
contains "$out" 'other' 'all of them'

out=$(at b b feature)
contains "$out" 'feature-two' 'a pattern filters the list'
case $out in
    *other*) not_ok 'and drops what does not match' ;;
    *)       ok 'and drops what does not match' ;;
esac

out=$(at b b -i)
contains "$out" 'feature-one' '-i still lists the branches'
case $out in
    *[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*) ok '-i adds the author date' ;;
    *) not_ok '-i adds the author date' "$out" ;;
esac

# pattern and flags in either order
is "$(at b b feature-one -i | grep -c 'feature-one')" '1' 'pattern and -i combine'

# ------------------------------------------------------------- remotes ---

out=$(at b b -r origin)
contains "$out" 'origin/feature-one' '-r lists that remote branches'
case $out in
    *feature-two*) not_ok 'and not the local-only ones' ;;
    *)             ok 'and not the local-only ones' ;;
esac
case $out in
    *HEAD*) not_ok "the remote's HEAD symref is left out" ;;
    *)      ok "the remote's HEAD symref is left out" ;;
esac

out=$(at b b feature -r origin)
contains "$out" 'origin/feature-one' 'a pattern applies to a remote listing too'

at_out b b -r >/dev/null
is "$AT_RC" '1' '-r without a remote is an error'
contains "$AT_OUT" 'remote' 'and says so'

at_out b b -r nope >/dev/null
is "$AT_RC" '1' 'an unknown remote is an error'

at_out b b one two >/dev/null
is "$AT_RC" '1' 'two patterns is an error'

# ------------------------------------------------------------ checkout ---

new_repo k >/dev/null
git -C "$AT_TMP/k" branch feature-one
git -C "$AT_TMP/k" branch feature-two

at_out k bk feature-two >/dev/null
is "$(git -C "$AT_TMP/k" branch --show-current)" 'feature-two' 'bk checks out a match'

at_out k bk >/dev/null
is "$(git -C "$AT_TMP/k" branch --show-current)" 'master' 'bk with no pattern goes to the default branch'

# an exact name wins over a substring match
git -C "$AT_TMP/k" branch one
at_out k bk one >/dev/null
is "$(git -C "$AT_TMP/k" branch --show-current)" 'one' 'an exact name beats a substring match'

# ------------------------------------------------- checkout from a remote ---

new_repo kr >/dev/null
git init -q --bare "$AT_TMP/kr-remote.git"
git -C "$AT_TMP/kr" remote add origin "$AT_TMP/kr-remote.git"
git -C "$AT_TMP/kr" switch -q -c AT-9.remote-work
write_commit kr remote-file 'work' 'feat: remote work'
git -C "$AT_TMP/kr" push -q origin master AT-9.remote-work
git -C "$AT_TMP/kr" switch -q master
git -C "$AT_TMP/kr" branch -q -D AT-9.remote-work

at_out kr bk remote-work -r origin >/dev/null
is "$AT_RC" '0' 'bk -r checks out a remote branch'
is "$(git -C "$AT_TMP/kr" branch --show-current)" 'r/origin/AT-9.remote-work' 'tracking it locally'
is "$(config kr branch.r/origin/AT-9.remote-work.atbase)" "$(sha kr master)" 'and recording where it started'

at_out kr bk -r origin >/dev/null
is "$AT_RC" '1' 'bk -r needs a pattern'

t_done
