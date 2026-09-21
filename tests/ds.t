#!/bin/sh
#
# `ds`: sync the default branch. On a fork that means overwriting origin from
# upstream, so anything on origin that upstream does not have gets shown and
# asked about first - losing a commit must take a deliberate answer.

set -u
. "$(dirname "$0")/lib.sh"

# upstream and origin as bare repos, plus a working clone with both remotes
fork() {
    r=$1
    git init -q --bare "$AT_TMP/$r-upstream.git"
    new_repo "$r-seed" >/dev/null
    git -C "$AT_TMP/$r-seed" push -q "$AT_TMP/$r-upstream.git" master
    git clone -q "$AT_TMP/$r-upstream.git" "$AT_TMP/$r-origin.git" --bare
    git clone -q "$AT_TMP/$r-origin.git" "$AT_TMP/$r"
    git -C "$AT_TMP/$r" remote add upstream "$AT_TMP/$r-upstream.git"
    git -C "$AT_TMP/$r" config user.name 'git-at tests'
    git -C "$AT_TMP/$r" config user.email 'tests@example.invalid'
    git -C "$AT_TMP/$r" config commit.gpgsign false
    git -C "$AT_TMP/$r" fetch -q --all
}

# a commit that exists only on origin: the thing a force-sync would destroy
only_on_origin() {
    write_commit "$1" origin-only 'only here' 'feat: only on origin'
    git -C "$AT_TMP/$1" push -q origin master
    git -C "$AT_TMP/$1" reset -q --hard origin/master
}

# ------------------------------------------- upstream moved, origin has not ---

fork ff
write_commit ff-seed upstream-work 'new' 'feat: upstream work'
git -C "$AT_TMP/ff-seed" push -q "$AT_TMP/ff-upstream.git" master

at_out ff ds >/dev/null
is "$AT_RC" '0' 'an ordinary sync succeeds'
contains "$AT_OUT" 'origin/master:' 'it says what happened to origin'
contains "$AT_OUT" 'master:' 'and what happened locally'
git -C "$AT_TMP/ff" fetch -q --all
is "$(git -C "$AT_TMP/ff" rev-parse origin/master)" \
   "$(git -C "$AT_TMP/ff" rev-parse upstream/master)" 'origin is brought up to upstream'

# ------------------------------------------------- origin has its own commit ---

fork div
only_on_origin div
before=$(git -C "$AT_TMP/div" rev-parse origin/master)
write_commit div-seed upstream-work 'new' 'feat: upstream work'
git -C "$AT_TMP/div-seed" push -q "$AT_TMP/div-upstream.git" master

at_out div ds </dev/null >/dev/null
is "$AT_RC" '1' 'a diverged origin stops the sync'
contains "$AT_OUT" 'only on origin' 'and shows what would be lost'
git -C "$AT_TMP/div" fetch -q --all
is "$(git -C "$AT_TMP/div" rev-parse origin/master)" "$before" 'origin is left alone'

# ------------------------------------------------------------- with -y ---

fork yes
only_on_origin yes
write_commit yes-seed upstream-work 'new' 'feat: upstream work'
git -C "$AT_TMP/yes-seed" push -q "$AT_TMP/yes-upstream.git" master

at_out yes ds -y </dev/null >/dev/null
is "$AT_RC" '0' '-y syncs anyway'
git -C "$AT_TMP/yes" fetch -q --all
is "$(git -C "$AT_TMP/yes" rev-parse origin/master)" \
   "$(git -C "$AT_TMP/yes" rev-parse upstream/master)" 'and origin matches upstream again'

# ------------------------------------------------------- no upstream remote ---

fork solo
git -C "$AT_TMP/solo" remote remove upstream
write_commit solo-seed x 'x' 'feat: work'
git -C "$AT_TMP/solo-seed" push -q "$AT_TMP/solo-origin.git" master

at_out solo ds >/dev/null
is "$AT_RC" '0' 'a repo with no upstream just pulls from origin'
contains "$AT_OUT" ' -> ' 'and reports the move'
is "$(git -C "$AT_TMP/solo" rev-parse master)" \
   "$(git -C "$AT_TMP/solo" rev-parse origin/master)" 'and is up to date with origin'

# ------------------------------------------- a clone with no origin at all ---

# cloned straight from the authoritative repo, then renamed: `upstream` is the
# only remote, and it is the one to follow
fork only
git -C "$AT_TMP/only" remote remove origin
git -C "$AT_TMP/only" remote set-url upstream "$AT_TMP/only-origin.git"
write_commit only-seed x 'x' 'feat: upstream work'
git -C "$AT_TMP/only-seed" push -q "$AT_TMP/only-origin.git" master

at_out only ds >/dev/null
is "$AT_RC" '0' 'an upstream-only clone syncs'
contains "$AT_OUT" 'master:' 'and reports the local move'
is "$(git -C "$AT_TMP/only" rev-parse master)" \
   "$(git -C "$AT_TMP/only" rev-parse upstream/master)" 'following upstream'

# ------------------------------------------------------------ no remotes ---

new_repo alone >/dev/null
at_out alone ds >/dev/null
is "$AT_RC" '0' 'no remotes is not an error'
contains "$AT_OUT" 'no remotes' 'it just says so'

# ------------------------------------------------- nothing left to do ---

# the case that used to print nothing at all, which is indistinguishable from
# a command that silently did nothing
at_out ff ds >/dev/null
is "$AT_RC" '0' 'a second sync succeeds'
contains "$AT_OUT" 'already' 'and says there was nothing to do'

# a broken upstream is reported, not swallowed
fork broken
git -C "$AT_TMP/broken" remote set-url upstream "$AT_TMP/does-not-exist.git"
at_out broken ds >/dev/null
contains "$AT_OUT" 'failed' 'a fetch that fails says so'

t_done
