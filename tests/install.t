#!/bin/sh
#
# `install`: what it copies, and when it asks about the agent skill. Everything
# lands under a throwaway HOME, so nothing real is touched.

set -u
. "$(dirname "$0")/lib.sh"

root=$(dirname "$AT")
installer="$root/install"
dest="$AT_TMP/installed"
skilldir="$AT_TMP/skills/git-at"
git config --global at.agent.skilldir "$skilldir"

run_install() { AT_OUT=$(sh "$installer" "$dest" "$@" 2>&1); AT_RC=$?; }

# ------------------------------------------------------------ the copies ---

run_install --no-skill </dev/null
is "$AT_RC" '0' 'install succeeds'
[ -x "$dest/git-at" ] && ok 'git-at is installed, executable' || not_ok 'git-at is installed, executable'
[ -f "$dest/at-aliases.gitconfig" ] && ok 'the alias file is installed' || not_ok 'the alias file is installed'
[ -f "$dest/rules/commit.md" ] && ok 'the prompt files are installed' || not_ok 'the prompt files are installed'

# ---------------------------------------------------------- the skill ---

# first time, with nobody to answer: it asks, and the default is no
rm -rf "$skilldir"
run_install </dev/null
contains "$AT_OUT" 'install the agent skill' 'the first install asks about the skill'
[ -f "$skilldir/SKILL.md" ] && not_ok 'and no answer means no' || ok 'and no answer means no'

# yes installs it
run_install --skill </dev/null
contains "$AT_OUT" 'agent skill installed' 'yes installs it'
[ -f "$skilldir/SKILL.md" ] && ok 'the skill is in place' || not_ok 'the skill is in place'

# already installed and unchanged: no question, and it says so
run_install </dev/null
case $AT_OUT in
    *'install the agent skill'*) not_ok 'an installed skill is not asked about again' ;;
    *)                           ok 'an installed skill is not asked about again' ;;
esac
contains "$AT_OUT" 'already up to date' 'it says the skill is current'

# already installed but stale: updated without asking
printf 'old\n' >"$skilldir/SKILL.md"
run_install </dev/null
contains "$AT_OUT" 'agent skill updated' 'a stale skill is updated without asking'
cmp -s "$root/skills/git-at/SKILL.md" "$skilldir/SKILL.md" &&
    ok 'with the current copy' || not_ok 'with the current copy'

# --no-skill still wins, even when it is installed
printf 'old\n' >"$skilldir/SKILL.md"
run_install --no-skill </dev/null
is "$(cat "$skilldir/SKILL.md")" 'old' '--no-skill leaves an installed skill alone'

t_done
