#!/bin/sh
#
# `cf`: fork a repo and clone the fork, leaving `upstream` theirs and `origin`
# yours. `gh` is stubbed - it makes a checkout the way the real one would, so
# the test is about what git-at does with the result.

set -u
. "$(dirname "$0")/lib.sh"

mkdir -p "$AT_TMP/bin"
cat >"$AT_TMP/bin/gh" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$AT_TMP/gh-args"
case "\$1 \$2" in
    'repo fork')
        name=\$(printf '%s' "\$3" | sed 's#.*/##')
        git init -q -b master "\$name"
        git -C "\$name" remote add origin "git@github.com:me/\$name.git"
        # the real gh adds upstream too, unless \$AT_TEST_NO_UPSTREAM says otherwise
        [ -n "\${AT_TEST_NO_UPSTREAM:-}" ] ||
            git -C "\$name" remote add upstream "git@github.com:them/\$name.git"
        ;;
    'repo view')
        case "\$*" in
            *sshUrl*) printf 'git@github.com:them/thing.git\n' ;;
            *)        printf 'them/thing\n' ;;
        esac
        ;;
esac
exit 0
EOF
chmod +x "$AT_TMP/bin/gh"

mkdir -p "$AT_TMP/work"
cf() { AT_OUT=$( (cd "$AT_TMP/work" && PATH="$AT_TMP/bin:$PATH" sh "$AT" cf "$@") 2>&1 ); AT_RC=$?; }

# ------------------------------------------------------------ the usual ---

rm -rf "$AT_TMP/work"/* "$AT_TMP/gh-args"
cf them/thing
is "$AT_RC" '0' 'cf clones'
contains "$(cat "$AT_TMP/gh-args")" 'repo fork them/thing --clone' 'through gh repo fork --clone'
contains "$AT_OUT" 'cloned into ./thing' 'and says where it landed'
contains "$AT_OUT" 'upstream  git@github.com:them/thing.git' 'upstream is the authoritative repo'
contains "$AT_OUT" 'origin    git@github.com:me/thing.git' 'origin is the fork'

# extra arguments go to gh untouched
rm -rf "$AT_TMP/work"/* "$AT_TMP/gh-args"
cf them/thing --fork-name mine
contains "$(cat "$AT_TMP/gh-args")" '--fork-name mine' 'extra options reach gh'

# ------------------------------------------------- when gh leaves it out ---

rm -rf "$AT_TMP/work"/* "$AT_TMP/gh-args"
AT_OUT=$( (cd "$AT_TMP/work" && PATH="$AT_TMP/bin:$PATH" AT_TEST_NO_UPSTREAM=1 sh "$AT" cf them/thing) 2>&1 )
is "$?" '0' 'a checkout with no upstream still succeeds'
contains "$AT_OUT" "added the missing 'upstream' remote" 'and the remote is added'
is "$(git -C "$AT_TMP/work/thing" remote get-url upstream)" 'git@github.com:them/thing.git' \
    'pointing at the authoritative repo'

# --------------------------------------------------------------- usage ---

cf
is "$AT_RC" '1' 'no repository is a usage error'
contains "$AT_OUT" 'usage' 'with usage'

t_done
