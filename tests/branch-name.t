#!/bin/sh
#
# Branch naming: the argument forms, slug cleanup, and where a slug comes from
# when the caller does not give one.
#
# Linear and the model are stubbed by putting fakes ahead of the real commands on
# PATH, so nothing here talks to a network or a model.

set -u
. "$(dirname "$0")/lib.sh"

new_repo names >/dev/null
git -C "$AT_TMP/names" config at.ticket.prefix AT

# ------------------------------------------------------- argument forms ---

is "$(at names _branch-name 12345 my-slug)" 'AT-12345.my-slug' 'bare number takes the configured prefix'
is "$(at names _branch-name AT-12345 my-slug)" 'AT-12345.my-slug' 'a key plus a slug'
is "$(at names _branch-name at-12345 my-slug)" 'AT-12345.my-slug' 'a lowercase key is uppercased'
is "$(at names _branch-name AT-12345.my-slug)" 'AT-12345.my-slug' 'a complete branch name is used as-is'
is "$(at names _branch-name my-slug)" 'my-slug' 'a slug alone has no ticket'
is "$(at names _branch-name 2fa-support)" '2fa-support' 'a slug starting with a digit is still a slug'

# ------------------------------------------------------------- slugs ---

is "$(at names _branch-name AT-1 'Stripe: list saved payment methods!')" \
    'AT-1.stripe-list-saved-payment-methods' 'punctuation and case are cleaned up'
is "$(at names _branch-name AT-1 'a-very-long-slug-that-keeps-going-and-going-and-going')" \
    'AT-1.a-very-long-slug-that-keeps-going-and' 'a long slug is cut at a word boundary'
long=$(at names _branch-name AT-1 'a-very-long-slug-that-keeps-going-and-going-and-going' | cut -d. -f2)
if [ ${#long} -le 40 ]; then ok 'and stays within 40 characters'; else not_ok 'and stays within 40 characters' "$long"; fi

# ------------------------------------------ the slug comes from the ticket ---

mkdir -p "$AT_TMP/bin"
cat >"$AT_TMP/bin/curl" <<'EOF'
#!/bin/sh
cat >/dev/null
printf '{"data":{"issue":{"identifier":"AT-77","title":"Add Stripe listing"}}}\n'
EOF
chmod +x "$AT_TMP/bin/curl"
git -C "$AT_TMP/names" config at.linear.apikey 'test-key'

PATH="$AT_TMP/bin:$PATH" is "$(PATH="$AT_TMP/bin:$PATH" at names _branch-name AT-77)" \
    'AT-77.add-stripe-listing' 'a short ticket title becomes the slug'

# a long title goes to the model; the model is a stub that shortens it
cat >"$AT_TMP/bin/curl" <<'EOF'
#!/bin/sh
cat >/dev/null
printf '{"data":{"issue":{"identifier":"AT-78","title":"Allow admins to schedule a rebuild for a maintenance window"}}}\n'
EOF
cat >"$AT_TMP/bin/fake-model" <<EOF
#!/bin/sh
cat >"$AT_TMP/slug-prompt"
printf '\`\`\`\nschedule-rebuild-window\n\`\`\`\n'
EOF
chmod +x "$AT_TMP/bin/fake-model"
git -C "$AT_TMP/names" config at.llm.command "$AT_TMP/bin/fake-model"

is "$(PATH="$AT_TMP/bin:$PATH" at names _branch-name AT-78)" 'AT-78.schedule-rebuild-window' \
    'a long title is shortened by the model, fences stripped'
contains "$(cat "$AT_TMP/slug-prompt" 2>/dev/null)" 'Ticket title' 'the prompt reached the model'

# with no model, the first four words are kept
git -C "$AT_TMP/names" config --unset at.llm.command
is "$(PATH="$AT_TMP/bin:$PATH" at names _branch-name AT-78 2>/dev/null)" \
    'AT-78.allow-admins-to-schedule' 'without a model the first four words are kept'

# --------------------------------------------------- ignored prefixes ---

# nothing is ignored until the config says so: an unconfigured MAD- key is just
# another key, looked up like any other
cat >"$AT_TMP/bin/curl" <<'EOF'
#!/bin/sh
cat >/dev/null
printf '{"data":{"issue":{"identifier":"MAD-16743","title":"Stripe list"}}}\n'
EOF
is "$(PATH="$AT_TMP/bin:$PATH" at names _branch-name MAD-16743)" 'MAD-16743.stripe-list' \
    'an unconfigured prefix is looked up like any other'

git -C "$AT_TMP/names" config at.ticket.ignored-prefixes 'MAD- MADRR- NXERR-'

at_out names _branch-name MAD-16743 >/dev/null
is "$AT_RC" '1' 'an ignored key is never looked up'
contains "$AT_OUT" 'MAD-16743' 'and it asks for a slug by name'

is "$(at names _branch-name MAD-16743 stripe-list)" 'MAD-16743.stripe-list' \
    'an ignored key with a slug is fine'

# the separators and the trailing dash are both optional, and case does not matter
git -C "$AT_TMP/names" config at.ticket.ignored-prefixes 'mad,nxerr'
at_out names _branch-name MAD-16743 >/dev/null
is "$AT_RC" '1' 'commas, no dash and lowercase all work'

# a prefix that is not listed is still linear's
git -C "$AT_TMP/names" config at.ticket.ignored-prefixes 'OLD-'
is "$(PATH="$AT_TMP/bin:$PATH" at names _branch-name MAD-16743)" 'MAD-16743.stripe-list' \
    'an unlisted prefix is unaffected'

t_done
