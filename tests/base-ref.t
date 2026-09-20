#!/bin/sh
#
# The diff and patch commands compare against the branch point, so on a stacked
# branch they show your own work rather than the parent's as well.
#
# `fk` keeps its own meaning - everything since the default branch - because that
# is a different question from "what did I change".

set -u
. "$(dirname "$0")/lib.sh"

# parent with work, child stacked on it, each with one commit
new_repo st >/dev/null
git -C "$AT_TMP/st" switch -q -c parent
write_commit st parent-file 'parent work' 'feat(p): parent work'
git -C "$AT_TMP/st" switch -q -c child
git -C "$AT_TMP/st" config branch.child.atparent parent
git -C "$AT_TMP/st" config branch.child.atbase "$(sha st parent)"
write_commit st child-file 'child work' 'feat(c): child work'

# ------------------------------------------------------------------ fb ---

out=$(at st fb)
contains "$out" 'child-file' 'fb shows the branch own work'
case $out in
    *parent-file*) not_ok "fb does not show the parent's work" ;;
    *)             ok "fb does not show the parent's work" ;;
esac

# ------------------------------------------------------------------ fk ---

out=$(at st fk)
contains "$out" 'child-file' 'fk shows the branch own work'
contains "$out" 'parent-file' "and the parent's too, being a diff from the default branch"

# an explicit ref still means "since we diverged from that ref"
out=$(at st fb parent)
contains "$out" 'child-file' 'an explicit ref still works'

# ------------------------------------------------------------------ pb ---

AT_PATCH_DIR="$AT_TMP/patches"; export AT_PATCH_DIR
dest=$(at st pb)
if [ -n "$dest" ] && [ -f "$dest" ]; then ok 'pb writes a patch'; else not_ok 'pb writes a patch' "$dest"; fi
body=$(cat "$dest" 2>/dev/null)
contains "$body" 'child-file' 'the patch holds the branch own work'
case $body in
    *parent-file*) not_ok "and not the parent's" ;;
    *)             ok "and not the parent's" ;;
esac

# ------------------------------------------------------------------ pf ---

series=$(at st pf 2>/dev/null)
n=0
for f in "$series"/*; do [ -f "$f" ] && n=$((n + 1)); done
is "$n" '1' 'pf writes one patch per commit on the branch, not on the parent'

# ---------------------------------------------------- an unrecorded branch ---

# no record: the merge base is the fallback, and it is still right here
new_repo mb >/dev/null
git -C "$AT_TMP/mb" switch -q -c feature
write_commit mb mine 'mine' 'feat: own work'
out=$(at mb fb)
contains "$out" 'mine' 'without a record the merge base still answers'

# a stale record is fatal here too: these commands must not quietly show the wrong range
new_repo stale >/dev/null
git -C "$AT_TMP/stale" switch -q -c feature
write_commit stale a 'a' 'feat: one'
write_commit stale b 'b' 'feat: two'
git -C "$AT_TMP/stale" config branch.feature.atbase "$(sha stale 'HEAD~1')"
git -C "$AT_TMP/stale" switch -q master
write_commit stale z 'z' 'chore: master moves'
git -C "$AT_TMP/stale" switch -q feature
git -C "$AT_TMP/stale" rebase -q master >/dev/null 2>&1

at_out stale fb >/dev/null
is "$AT_RC" '1' 'a stale record stops the diff commands too'

t_done
