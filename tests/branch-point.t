#!/bin/sh
#
# Branch point resolution: explicit commit-ish, recorded value, merge base -
# and the cases that must stop rather than degrade.
#
# `_branch-point` prints "<source> <commit>"; see the resolution order in DESIGN.md.

set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------ no record: the merge base ---

new_repo mb >/dev/null
git -C "$AT_TMP/mb" switch -q -c feature
write_commit mb a 'a' 'feat(a): add a'

want=$(sha mb master)
is "$(at mb _branch-point)" "merge-base $want" 'falls back to the merge base'

# ------------------------------------------------------- explicit commit-ish ---

new_repo ex >/dev/null
write_commit ex b 'b' 'second'
git -C "$AT_TMP/ex" switch -q -c feature
write_commit ex c 'c' 'third'

want=$(sha ex 'master~1')
is "$(at ex _branch-point master~1)" "explicit $want" 'an explicit commit-ish wins'

at_out ex _branch-point nope-not-a-ref >/dev/null
is "$AT_RC" '1' 'an unresolvable commit-ish is fatal'
contains "$AT_OUT" 'nope-not-a-ref' 'and names what it could not resolve'

# ------------------------------------------------------------ recorded value ---

new_repo rec >/dev/null
git -C "$AT_TMP/rec" switch -q -c feature
write_commit rec a 'a' 'first'
recorded=$(sha rec HEAD)
write_commit rec b 'b' 'second'
git -C "$AT_TMP/rec" config branch.feature.atbase "$recorded"

is "$(at rec _branch-point)" "recorded $recorded" 'a recorded branch point is used'

# a recorded value that is no longer an ancestor is stale: stop, do not fall back.
# a rebase rewrites the branch's own commits, which is how a record goes stale.
new_repo stale >/dev/null
git -C "$AT_TMP/stale" switch -q -c feature
write_commit stale a 'a' 'first'
write_commit stale b 'b' 'second'
git -C "$AT_TMP/stale" config branch.feature.atbase "$(sha stale 'HEAD~1')"
git -C "$AT_TMP/stale" switch -q master
write_commit stale z 'z' 'moves master on'
git -C "$AT_TMP/stale" switch -q feature
git -C "$AT_TMP/stale" rebase -q master >/dev/null 2>&1

at_out stale _branch-point >/dev/null
is "$AT_RC" '1' 'a stale recorded branch point is fatal'
contains "$AT_OUT" 'stale' 'and says the record is stale'

# ------------------------------------------ pending value after --continue ---

# a record pointing at an object that does not exist at all, with nothing parked
new_repo pend >/dev/null
git -C "$AT_TMP/pend" switch -q -c feature
write_commit pend c 'c' 'third'
git -C "$AT_TMP/pend" config branch.feature.atbase 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'

at_out pend _branch-point >/dev/null
is "$AT_RC" '1' 'an unresolvable recorded value with no pending value is fatal'

# what a rebase finished by hand leaves behind: the record no longer resolves,
# but the value dr parked before starting is a real ancestor - promote it.
new_repo prom >/dev/null
git -C "$AT_TMP/prom" switch -q -c feature
write_commit prom a 'a' 'first'
promoted=$(sha prom HEAD)
write_commit prom b 'b' 'second'
git -C "$AT_TMP/prom" config branch.feature.atbase 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'
git -C "$AT_TMP/prom" config branch.feature.atbasepending "$promoted"

is "$(at prom _branch-point)" "promoted $promoted" 'a usable pending value is promoted'
is "$(config prom branch.feature.atbase)" "$promoted" 'promotion rewrites the record'
is "$(config prom branch.feature.atbasepending)" '' 'promotion clears the pending value'

# ------------------------------------------------ unrelated histories ---

# two roots with nothing in common: there is no range to infer, and guessing one
# would produce a diff of everything
new_repo unrelated >/dev/null
git -C "$AT_TMP/unrelated" switch -q --orphan other-root
write_commit unrelated theirs 'theirs' 'feat: a separate history'

at_out unrelated _branch-point >/dev/null
is "$AT_RC" '1' 'unrelated histories are fatal'
contains "$AT_OUT" 'atbase' 'and the message names the way out'

# naming the branch point makes it workable again
git -C "$AT_TMP/unrelated" config branch.other-root.atbase "$(sha unrelated HEAD)"
is "$(at unrelated _branch-point)" "recorded $(sha unrelated HEAD)" 'a recorded branch point answers regardless'

t_done
