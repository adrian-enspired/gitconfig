#!/bin/sh
#
# `r` end to end, with `gh` stubbed: what it pushes, and what it hands to
# `gh pr create`. The --base argument has to be a branch name - a commit sha
# gets as far as GitHub before failing.

set -u
. "$(dirname "$0")/lib.sh"

mkdir -p "$AT_TMP/bin"
# the stub answers `repo view --json parent` from a file the tests rewrite, which
# is how github's view of the fork relationship is simulated
printf '' >"$AT_TMP/fork-parent"
cat >"$AT_TMP/bin/gh" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$AT_TMP/gh-args"
case "\$1 \${2:-}" in
    'repo view')    cat "$AT_TMP/fork-parent" ;;
    'pr create')    printf 'https://github.com/nx-adrian/gitconfig/pull/1\n' ;;
esac
exit 0
EOF
chmod +x "$AT_TMP/bin/gh"

printf 'nx-adrian/gitconfig\n' >"$AT_TMP/fork-parent"

# a repo whose origin looks like github, so _require_github is satisfied
new_repo pr >/dev/null
git init -q --bare "$AT_TMP/pr-remote.git"
git -C "$AT_TMP/pr" remote add origin "git@github.com:nx-adrian/gitconfig.git"
git -C "$AT_TMP/pr" config remote.origin.pushurl "$AT_TMP/pr-remote.git"
git -C "$AT_TMP/pr" push -q origin master
git -C "$AT_TMP/pr" switch -q -c COM-5.add-listing
write_commit pr one 'one' 'feat(stripe): add the listing'

rm -f "$AT_TMP/gh-args"
AT_OUT=$( (cd "$AT_TMP/pr" && PATH="$AT_TMP/bin:$PATH" GIT_EDITOR=true sh "$AT" r -y --no-summary) 2>&1 )
rc=$?
is "$rc" '0' 'r opens a pull request'

args=$(cat "$AT_TMP/gh-args" 2>/dev/null)
create=$(printf '%s\n' "$args" | grep '^pr create' || true)
contains "$create" '--base master' 'the base is a branch name, not a commit'
contains "$create" '--title [COM-5] Add Listing' 'the title comes from the branch name'
contains "$create" '--body-file' 'the body is passed as a file'

# a stacked branch targets its parent instead
git -C "$AT_TMP/pr" switch -q -c COM-6.on-top
git -C "$AT_TMP/pr" config branch.COM-6.on-top.atparent COM-5.add-listing
git -C "$AT_TMP/pr" config branch.COM-6.on-top.atbase "$(sha pr COM-5.add-listing)"
write_commit pr two 'two' 'feat(stripe): build on it'
git -C "$AT_TMP/pr" push -q origin COM-5.add-listing
git -C "$AT_TMP/pr" fetch -q origin

rm -f "$AT_TMP/gh-args"
(cd "$AT_TMP/pr" && PATH="$AT_TMP/bin:$PATH" GIT_EDITOR=true sh "$AT" r -y --no-summary) >/dev/null 2>&1
create=$(grep '^pr create' "$AT_TMP/gh-args" 2>/dev/null || true)
contains "$create" '--base COM-5.add-listing' 'a stacked branch targets its parent'

# --base wins over everything
rm -f "$AT_TMP/gh-args"
(cd "$AT_TMP/pr" && PATH="$AT_TMP/bin:$PATH" GIT_EDITOR=true sh "$AT" r -y --no-summary --base master) >/dev/null 2>&1
create=$(grep '^pr create' "$AT_TMP/gh-args" 2>/dev/null || true)
contains "$create" '--base master' 'an explicit --base wins'

# ------------------------------------------- a branch rewritten since pushing ---

# after a rebase the remote branch is no longer an ancestor, so the push is
# refused - and git's own hint (pull) would merge the old history back in
git -C "$AT_TMP/pr" switch -q COM-5.add-listing
git -C "$AT_TMP/pr" push -q origin COM-5.add-listing 2>/dev/null
git -C "$AT_TMP/pr" commit -q --amend -m 'feat(stripe): add the listing, reworded'

AT_OUT=$( (cd "$AT_TMP/pr" && PATH="$AT_TMP/bin:$PATH" GIT_EDITOR=true sh "$AT" r -y --no-summary) 2>&1 )
rc=$?
is "$rc" '1' 'a rejected push stops the PR'
contains "$AT_OUT" 'git oof' 'and points at the force push, not a pull'

git -C "$AT_TMP/pr" push -q --force origin COM-5.add-listing 2>/dev/null

# ------------------------------------------------- an upstream that is not ours ---

# two repos that share history locally but are unrelated on github: a PR between
# them cannot exist, and `gh pr create` only says so after pushing
git -C "$AT_TMP/pr" remote add upstream 'git@github.com:someone-else/gitconfig.git'
git -C "$AT_TMP/pr" switch -q COM-5.add-listing

printf '' >"$AT_TMP/fork-parent"          # github: origin is nobody's fork
rm -f "$AT_TMP/gh-args"
AT_OUT=$( (cd "$AT_TMP/pr" && PATH="$AT_TMP/bin:$PATH" GIT_EDITOR=true sh "$AT" r -y --no-summary) 2>&1 )
create=$(grep '^pr create' "$AT_TMP/gh-args" 2>/dev/null || true)
contains "$create" '--repo nx-adrian/gitconfig' 'an unrelated upstream falls back to origin'
contains "$AT_OUT" 'does not see' 'and says why'

# github confirming the fork: upstream is the right target again
printf 'someone-else/gitconfig\n' >"$AT_TMP/fork-parent"
rm -f "$AT_TMP/gh-args"
(cd "$AT_TMP/pr" && PATH="$AT_TMP/bin:$PATH" GIT_EDITOR=true sh "$AT" r -y --no-summary) >/dev/null 2>&1
create=$(grep '^pr create' "$AT_TMP/gh-args" 2>/dev/null || true)
contains "$create" '--repo someone-else/gitconfig' 'a real fork targets upstream'

t_done
