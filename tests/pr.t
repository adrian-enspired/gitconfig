#!/bin/sh
#
# PR title and body. Both are built from git; the model only writes the prose
# sections of the body, and the body still assembles without it.

set -u
. "$(dirname "$0")/lib.sh"

# ---------------------------------------------------------------- title ---

new_repo t >/dev/null

is "$(at t _pr-title AT-12345.add-stripe-listing)" '[AT-12345] Add Stripe Listing' \
    'the key goes in brackets, the slug becomes Title Case'
is "$(at t _pr-title MAD-16743-stripe-list)" '[MAD-16743] Stripe List' \
    'the older dash form is recognised too'
is "$(at t _pr-title just-a-slug)" 'Just A Slug' \
    'a branch with no ticket still gets a title'

# ----------------------------------------------------------------- body ---

mkdir -p "$AT_TMP/bin"
cat >"$AT_TMP/bin/fake-model" <<EOF
#!/bin/sh
cat >"$AT_TMP/pr-prompt"
printf '## Why\n\nbecause the listing was missing\n\n## What\n\n- adds the listing\n'
EOF
chmod +x "$AT_TMP/bin/fake-model"

new_repo b >/dev/null
git -C "$AT_TMP/b" switch -q -c AT-77.stripe-list
write_commit b one 'one' 'feat(stripe): list saved methods'
git -C "$AT_TMP/b" config at.llm.command "$AT_TMP/bin/fake-model"
git -C "$AT_TMP/b" config at.linear.workspace nexcess

body=$(at b _pr-body)
contains "$body" '**Ticket:** [AT-77](https://linear.app/nexcess/issue/AT-77)' 'the ticket is linked'
contains "$body" 'because the listing was missing' 'the model wrote the prose'
contains "$(cat "$AT_TMP/pr-prompt" 2>/dev/null)" 'Commits on this branch' 'the prompt reached the model'
contains "$body" '## Test plan' 'the test plan section is there'
contains "$body" 'issue: AT-77' 'the issue trailer is there'

# without the model the sections are stubbed, not missing
body=$(at b _pr-body skip)
contains "$body" '## Why' 'a skipped model still leaves the headings'
contains "$body" '_todo._' 'stubbed out for the author to fill in'

# an ignored key links wherever its own tracker lives, if that is configured
new_repo lg >/dev/null
git -C "$AT_TMP/lg" switch -q -c MAD-16743.stripe-list
write_commit lg one 'one' 'feat(stripe): a key from another tracker'
git -C "$AT_TMP/lg" config at.ticket.ignored-prefixes 'MAD-'
git -C "$AT_TMP/lg" config at.ticket.ignored-url 'https://example.atlassian.net/browse/%s'
git -C "$AT_TMP/lg" config at.linear.workspace nexcess
body=$(at lg _pr-body skip)
contains "$body" 'example.atlassian.net/browse/MAD-16743' 'an ignored key links to its own tracker'
case $body in
    *linear.app*) not_ok 'and never to linear' ;;
    *)            ok 'and never to linear' ;;
esac

# with no url configured it is named but not linked somewhere wrong
git -C "$AT_TMP/lg" config --unset at.ticket.ignored-url
body=$(at lg _pr-body skip)
contains "$body" '**Ticket:** MAD-16743' 'without a url the key is bare'

# keys come from the commit trailers, most-referenced first
new_repo tr >/dev/null
git -C "$AT_TMP/tr" switch -q -c AT-1.thing
printf 'a\n' >"$AT_TMP/tr/a"
git -C "$AT_TMP/tr" add a
git -C "$AT_TMP/tr" commit -q -m 'feat(a): one' --trailer 'issue: AT-2'
body=$(at tr _pr-body skip)
contains "$body" 'issue: AT-2' 'a trailer key is carried into the body'

# the co-author trailer is copied from the commits, never invented
new_repo ca >/dev/null
git -C "$AT_TMP/ca" switch -q -c AT-3.thing
printf 'a\n' >"$AT_TMP/ca/a"
git -C "$AT_TMP/ca" add a
git -C "$AT_TMP/ca" commit -q -m 'feat(a): one' --trailer 'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>'
body=$(at ca _pr-body skip)
contains "$body" 'Co-Authored-By: Claude Opus 5' 'a co-author trailer is carried over'

new_repo nc >/dev/null
git -C "$AT_TMP/nc" switch -q -c AT-4.thing
write_commit nc a 'a' 'feat(a): one'
body=$(at nc _pr-body skip)
case $body in
    *Co-Authored*) not_ok 'no co-author is invented' ;;
    *)             ok 'no co-author is invented' ;;
esac

t_done
