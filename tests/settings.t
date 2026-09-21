#!/bin/sh
#
# `./install --help` lists every setting. That list is hand-written, so this
# checks it against the settings git-at actually reads.

set -u
. "$(dirname "$0")/lib.sh"

root=$(dirname "$AT")
installer="$root/install"

listed=$(sed -n 's/^\(at\.[a-z.<>-]*\)|.*/\1/p' "$installer" | sort -u)
used=$(grep -oE '_cfg [a-z][a-z.-]+' "$AT" | awk '{print $2}' | sort -u)
used="$used
$(grep -oE "git config --get(-all)? \"?at\.[a-z.-]+" "$AT" | grep -oE 'at\.[a-z.-]+' | sort -u)"

missing=''
for k in $used; do
    printf '%s\n' "$listed" | grep -qx "$k" || missing="${missing}${missing:+ }$k"
done
is "$missing" '' 'every setting git-at reads is listed by the installer'

# and nothing is listed that the script never reads. The per-feature model
# commands are built at runtime (at.llm.${feature}command), so they are named
# here rather than found by grep.
built='at.llm.slugcommand at.llm.commitcommand at.llm.prcommand'
stale=''
for k in $listed; do
    case $k in *'<'*) continue ;; esac
    case " $built " in *" $k "*) continue ;; esac
    printf '%s\n' "$used" | grep -qx "$k" || stale="${stale}${stale:+ }$k"
done
is "$stale" '' 'and nothing is listed that it never reads'

# secrets are reported as present, never printed
new_repo cfg >/dev/null
out=$( (cd "$AT_TMP/cfg" && HOME="$AT_TMP/cfg-home" GIT_CONFIG_GLOBAL="$AT_TMP/cfg-home/.gitconfig" \
        AT_LINEAR_APIKEY='lin_api_supersecretvalue' sh "$installer" --help) 2>&1 )
case $out in
    *supersecretvalue*) not_ok 'an api key is never printed' ;;
    *)                  ok 'an api key is never printed' ;;
esac
contains "$out" 'at.linear.apikey' 'though the setting is still listed'
contains "$out" '<set,' 'as present, with its length'

# ------------------------------------------------------- dependencies ---

# `install` reports what is missing rather than letting a command fail later.
# A PATH holding everything the installer itself needs, but no `gh`:
mkdir -p "$AT_TMP/minbin"
for t in sh git sed cat grep; do
    p=$(command -v "$t") && ln -sf "$p" "$AT_TMP/minbin/$t"
done
out=$( (cd "$AT_TMP/cfg" && PATH="$AT_TMP/minbin" sh "$installer" --help) 2>&1 )
contains "$out" 'Dependencies:' 'the installer reports dependencies'
contains "$out" 'gh     MISSING' 'naming the one that is missing'
contains "$out" 'git    ok' 'and the ones that are not'

out=$( (cd "$AT_TMP/cfg" && sh "$installer" --help) 2>&1 )
contains "$out" 'model' 'the model runner is checked too'

t_done
