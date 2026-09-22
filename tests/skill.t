#!/bin/sh
#
# The agent skill names commands and settings. Both drift: a rename here leaves
# an agent running something that no longer exists, and nothing else would catch
# it - the skill is read by a model, not by a shell.

set -u
. "$(dirname "$0")/lib.sh"

root=$(dirname "$AT")
skill="$root/skills/git-at/SKILL.md"
installer="$root/install"

[ -f "$skill" ] || { not_ok 'the skill exists'; t_done; exit; }
ok 'the skill exists'

# frontmatter is what makes it loadable at all
head -1 "$skill" | grep -qx -- '---' && ok 'it opens with frontmatter' || not_ok 'it opens with frontmatter'
grep -qE '^name: ' "$skill" && ok 'with a name' || not_ok 'with a name'
grep -qE '^description: ' "$skill" && ok 'and a description' || not_ok 'and a description'

# every `git <command>` it mentions has to be real. Only backticked ones: prose
# says things like "raw git for anything they cover", which is not a command.
known=$(sed -n 's/^cmd_\([a-z0-9][a-z0-9_]*\)().*/\1/p' "$AT" | tr '_' '-' | sort -u)
known="$known
$(sed -n 's/^[[:space:]]*\([a-z0-9]\{1,5\}\)[[:space:]]*=.*/\1/p' "$root/at-aliases.gitconfig" | sort -u)
pull
config"          # plain git, mentioned deliberately

missing=''
for c in $(grep -oE '`git [a-z0-9-]+' "$skill" | awk '{print $2}' | sort -u); do
    printf '%s\n' "$known" | grep -qx "$c" || missing="${missing}${missing:+ }$c"
done
is "$missing" '' 'every command it names exists'

# every at.* setting it mentions is one the installer lists
listed=$(sed -n 's/^\(at\.[a-z.<>-]*\)|.*/\1/p' "$installer" | sort -u)
unlisted=''
for k in $(grep -oE 'at\.[a-z]+\.[a-z-]+' "$skill" | sort -u); do
    printf '%s\n' "$listed" | grep -qx "$k" || unlisted="${unlisted}${unlisted:+ }$k"
done
is "$unlisted" '' 'every setting it names is a real one'

# the two policies that cost the most when forgotten
contains "$(cat "$skill")" 'at.agent.mode' 'it explains the suggest/act setting'
contains "$(cat "$skill")" '-y' 'and that commands need -y to not hang'

t_done
