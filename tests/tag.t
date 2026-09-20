#!/bin/sh
#
# `t`: an annotated tag, refused when the name is already taken - here or on any
# remote. Pushing stays `o`'s job.

set -u
. "$(dirname "$0")/lib.sh"

# a repo with two remotes, each a bare repo of its own
new_repo tag >/dev/null
git init -q --bare "$AT_TMP/tag-origin.git"
git init -q --bare "$AT_TMP/tag-upstream.git"
git -C "$AT_TMP/tag" remote add origin "$AT_TMP/tag-origin.git"
git -C "$AT_TMP/tag" remote add upstream "$AT_TMP/tag-upstream.git"
git -C "$AT_TMP/tag" push -q origin master
git -C "$AT_TMP/tag" push -q upstream master

# ------------------------------------------------------------ creating ---

at_out tag t v1.0.0 >/dev/null
is "$AT_RC" '0' 't creates a tag'
is "$(git -C "$AT_TMP/tag" cat-file -t v1.0.0)" 'tag' 'an annotated one, not lightweight'
is "$(git -C "$AT_TMP/tag" tag -l --format='%(contents:subject)' v1.0.0)" 'v1.0.0' \
    'the message defaults to the name'
contains "$AT_OUT" 'tagged v1.0.0' 'it says what it tagged'

at_out tag t v1.1.0 'first real release' >/dev/null
is "$(git -C "$AT_TMP/tag" tag -l --format='%(contents:subject)' v1.1.0)" 'first real release' \
    'a message is used when given'

# it does not push: that is `o`'s job
is "$(git -C "$AT_TMP/tag" ls-remote --tags origin 'refs/tags/v1.0.0')" '' 'the tag is not pushed'

# ------------------------------------------------------- names in use ---

at_out tag t v1.0.0 >/dev/null
is "$AT_RC" '1' 'a name already used here is refused'
contains "$AT_OUT" 'already exists here' 'and says where'

# taken on origin only
git -C "$AT_TMP/tag" tag -a -m 'on origin' v2.0.0
git -C "$AT_TMP/tag" push -q origin v2.0.0
git -C "$AT_TMP/tag" tag -d v2.0.0 >/dev/null

at_out tag t v2.0.0 >/dev/null
is "$AT_RC" '1' 'a name taken on a remote is refused'
contains "$AT_OUT" "on 'origin'" 'naming the remote that has it'

# taken on upstream only: every remote is checked, not just the first
git -C "$AT_TMP/tag" tag -a -m 'on upstream' v3.0.0
git -C "$AT_TMP/tag" push -q upstream v3.0.0
git -C "$AT_TMP/tag" tag -d v3.0.0 >/dev/null

at_out tag t v3.0.0 >/dev/null
is "$AT_RC" '1' 'a name taken on the second remote is refused too'
contains "$AT_OUT" "on 'upstream'" 'naming that one'

# --------------------------------------------------------------- force ---

at_out tag t -f v1.0.0 'replaced' >/dev/null
is "$AT_RC" '0' '-f replaces a tag that exists here'
is "$(git -C "$AT_TMP/tag" tag -l --format='%(contents:subject)' v1.0.0)" 'replaced' 'with the new message'

at_out tag t -f v2.0.0 >/dev/null
is "$AT_RC" '0' '-f tags a name that is taken on a remote'

# ------------------------------------------------- an unreachable remote ---

# a remote that cannot be reached must not stop a tag, but must be mentioned
git -C "$AT_TMP/tag" remote add broken "$AT_TMP/not-a-repo.git"
at_out tag t v4.0.0 >/dev/null
is "$AT_RC" '0' 'an unreachable remote does not stop the tag'
contains "$AT_OUT" 'could not reach' 'though it is reported'

# ---------------------------------------------------------------- usage ---

at_out tag t >/dev/null
is "$AT_RC" '1' 'no name is a usage error'
contains "$AT_OUT" 'usage' 'with usage'

t_done
