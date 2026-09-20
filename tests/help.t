#!/bin/sh
#
# `h` is generated: the comment above each command is its help, and the alias
# file documents the aliases that are plain git. Neither can drift from the code.

set -u
. "$(dirname "$0")/lib.sh"

new_repo h >/dev/null

index=$(at h h)
contains "$index" 'dr   : rebase the current branch onto its parent' 'a command summary comes from its comment'
contains "$index" 'oof  : git push --force-with-lease' 'a plain-git alias shows what it expands to'
contains "$index" 'detail: git h <command>' 'the footer points at per-command help'

case $index in
    *'"!~/.config/git/git-at'*) not_ok 'delegating aliases are not listed as git commands' ;;
    *)                          ok 'delegating aliases are not listed as git commands' ;;
esac

# ------------------------------------------------------------- grouping ---

# a blank line separates families; paragraph mode gives us one family at a time
family() { at h h | awk -v RS='' -v pat="$1" 'index($0, pat)'; }

prs=$(family 'urr  :')
contains "$prs" 'r    : open a pull request' 'urr is grouped with the pull request commands'
case $prs in
    *'u    : update'*) not_ok 'and not with the u commands' ;;
    *)                 ok 'and not with the u commands' ;;
esac

checkout=$(family 'bk   :')
contains "$checkout" 'dk   :' 'bk is grouped with the other checkout commands'
contains "$checkout" 'uk   :' 'all of them'
case $checkout in
    *'b    : list branches'*) not_ok 'and not with branch listing' ;;
    *)                        ok 'and not with branch listing' ;;
esac

# ------------------------------------------------------------- unlisted ---

# three families are kept out of the index: the diff and patch commands are
# rarely reached for, and discovery is machinery rather than something to run
index=$(at h h)
for hidden in 'fb   :' 'pall :' 'oor  :'; do
    case $index in
        *"$hidden"*) not_ok "the index leaves out $hidden" ;;
        *)           ok "the index leaves out $hidden" ;;
    esac
done
contains "$index" 'more:   git h diffs, git h discovery, git h patches' 'and points at them instead'

patches=$(at h h patches)
contains "$patches" 'p    :' 'git h patches lists the whole family'
contains "$patches" 'pd   :' 'inventory included'
contains "$patches" 'pall :' 'and the producers'

discovery=$(at h h discovery)
contains "$discovery" 'd    :' 'git h discovery lists those'
case $discovery in
    *'o    : git push'*) not_ok 'and not the push commands' ;;
    *)                   ok 'and not the push commands' ;;
esac

diffs=$(at h h diffs)
contains "$diffs" 'fb   :' 'git h diffs lists the diff commands'
contains "$diffs" 'fc   : git diff HEAD' 'including the plain-git ones'

# `o` is hidden as a second spelling of `op`, but still works
case $index in
    *'o    : git push origin'*) not_ok 'the index leaves out the o alias' ;;
    *)                          ok 'the index leaves out the o alias' ;;
esac
contains "$(at h h o)" 'git push origin' 'and git h o still answers'

case $index in
    *'h    : command reference'*) not_ok 'the index leaves out h itself' ;;
    *)                            ok 'the index leaves out h itself' ;;
esac
contains "$(at h h h)" 'command reference' 'and git h h still answers'

# families that moved
logs=$(family 'lg   :')
contains "$logs" 's    :' 's is grouped with the log commands'

remotes=$(family 'madd :')
contains "$remotes" 'op   :' 'madd is grouped with the remote commands'

# a hidden command still has its own help
contains "$(at h h fb)" 'branch point' 'a hidden command still answers git h <command>'

# per-command detail
detail=$(at h h dr)
contains "$detail" '--restack' 'per-command help includes the flags'
contains "$detail" '$1: branch point' 'and the arguments'

is "$(at h h oof)" '  git push --force-with-lease --force-if-includes origin' \
    'a plain-git alias has detail too'

at_out h h nope-not-a-command >/dev/null
is "$AT_RC" '1' 'an unknown command is an error'
contains "$AT_OUT" 'nope-not-a-command' 'and it says which'

t_done
