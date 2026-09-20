#!/bin/sh
#
# `it`: move a ticket to a status. Linear is stubbed by putting a fake `curl`
# ahead of the real one; the stub answers by what the query asks for.

set -u
. "$(dirname "$0")/lib.sh"

mkdir -p "$AT_TMP/bin"
# the stub records each request and answers the two queries `it` makes: the
# issue with its team's states, then the mutation
cat >"$AT_TMP/bin/curl" <<EOF
#!/bin/sh
body=\$(cat)
printf '%s\n' "\$body" >>"$AT_TMP/linear-requests"
case \$body in
    *issueUpdate*) printf '{"data":{"issueUpdate":{"success":true}}}\n' ;;
    *) printf '{"data":{"issue":{"id":"uuid-1","team":{"states":{"nodes":[{"id":"s1","name":"In Progress"},{"id":"s2","name":"In Review"},{"id":"s3","name":"Done"}]}}}}}\n' ;;
esac
EOF
chmod +x "$AT_TMP/bin/curl"

it() { r=$1; shift; AT_OUT=$( (cd "$AT_TMP/$r" && PATH="$AT_TMP/bin:$PATH" sh "$AT" it "$@") 2>&1 ); AT_RC=$?; }

new_repo it >/dev/null
git -C "$AT_TMP/it" config at.linear.apikey 'test-key'
git -C "$AT_TMP/it" config at.ticket.prefix COM

# ------------------------------------------------------------ moving ---

rm -f "$AT_TMP/linear-requests"
it it COM-12 'In Review'
is "$AT_RC" '0' 'it moves a ticket'
contains "$AT_OUT" 'COM-12 -> In Review' 'and says so'
contains "$(cat "$AT_TMP/linear-requests")" 'issueUpdate' 'the mutation was sent'
contains "$(cat "$AT_TMP/linear-requests")" '"id":"COM-12"' 'for that ticket'

# a bare number takes the configured prefix
rm -f "$AT_TMP/linear-requests"
it it 34 'Done'
is "$AT_RC" '0' 'a bare number works'
contains "$AT_OUT" 'COM-34 -> Done' 'with the configured prefix'

# and a lowercase key is uppercased
it it com-56 'Done'
contains "$AT_OUT" 'COM-56 -> Done' 'a lowercase key is uppercased'

# the status name is matched however it is cased
it it COM-12 'in review'
is "$AT_RC" '0' 'the status is matched case-insensitively'

# ------------------------------------------------- the branch's own ticket ---

git -C "$AT_TMP/it" switch -q -c COM-90.short-form
rm -f "$AT_TMP/linear-requests"
it it 'In Review'
is "$AT_RC" '0' 'one argument moves the branch ticket'
contains "$AT_OUT" 'COM-90 -> In Review' 'reading the key off the branch name'

# on a branch with no ticket there is nothing to infer
git -C "$AT_TMP/it" switch -q -c just-a-slug
it it 'In Review'
is "$AT_RC" '1' 'a branch with no ticket is an error'
contains "$AT_OUT" 'not linked' 'saying so'
contains "$AT_OUT" 'git it <ticket>' 'and showing the two-argument form'
git -C "$AT_TMP/it" switch -q master

# ------------------------------------------------------- what can go wrong ---

it it COM-12 'Shipped'
is "$AT_RC" '1' 'a status the team does not have is an error'
contains "$AT_OUT" "no status 'Shipped'" 'saying so'
contains "$AT_OUT" 'In Review' 'and listing the ones it does have'

it it not-a-ticket 'Done'
is "$AT_RC" '1' 'an argument that is not a ticket is an error'

it it COM-12
is "$AT_RC" '1' 'a missing status is a usage error'
contains "$AT_OUT" 'usage' 'with usage'

# a key belonging to another tracker is not linear's to move
git -C "$AT_TMP/it" config at.ticket.ignored-prefixes 'MAD-'
it it MAD-99 'Done'
is "$AT_RC" '1' 'an ignored key is refused'
contains "$AT_OUT" 'another tracker' 'explaining why'

# no api key is a configuration problem, not a network one
new_repo nokey >/dev/null
git -C "$AT_TMP/nokey" config at.ticket.prefix COM
it nokey COM-1 'Done'
is "$AT_RC" '1' 'no api key is an error'
contains "$AT_OUT" 'at.linear.apikey' 'naming the setting'

t_done
