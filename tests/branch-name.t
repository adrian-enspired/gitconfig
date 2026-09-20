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
git -C "$AT_TMP/names" config at.ticket.prefix COM

# ------------------------------------------------------- argument forms ---

is "$(at names _branch-name 12345 my-slug)" 'COM-12345.my-slug' 'bare number takes the configured prefix'
is "$(at names _branch-name COM-12345 my-slug)" 'COM-12345.my-slug' 'a key plus a slug'
is "$(at names _branch-name com-12345 my-slug)" 'COM-12345.my-slug' 'a lowercase key is uppercased'
is "$(at names _branch-name COM-12345.my-slug)" 'COM-12345.my-slug' 'a complete branch name is used as-is'
is "$(at names _branch-name my-slug)" 'my-slug' 'a slug alone has no ticket'
is "$(at names _branch-name 2fa-support)" '2fa-support' 'a slug starting with a digit is still a slug'

# ------------------------------------------------------------- slugs ---

is "$(at names _branch-name COM-1 'Stripe: list saved payment methods!')" \
    'COM-1.stripe-list-saved-payment-methods' 'punctuation and case are cleaned up'
is "$(at names _branch-name COM-1 'a-very-long-slug-that-keeps-going-and-going-and-going')" \
    'COM-1.a-very-long-slug-that-keeps-going-and' 'a long slug is cut at a word boundary'
long=$(at names _branch-name COM-1 'a-very-long-slug-that-keeps-going-and-going-and-going' | cut -d. -f2)
if [ ${#long} -le 40 ]; then ok 'and stays within 40 characters'; else not_ok 'and stays within 40 characters' "$long"; fi

# ------------------------------------------ the slug comes from the ticket ---

mkdir -p "$AT_TMP/bin"
cat >"$AT_TMP/bin/curl" <<'EOF'
#!/bin/sh
cat >/dev/null
printf '{"data":{"issue":{"identifier":"COM-77","title":"Add Stripe listing"}}}\n'
EOF
chmod +x "$AT_TMP/bin/curl"
git -C "$AT_TMP/names" config at.linear.apikey 'test-key'

PATH="$AT_TMP/bin:$PATH" is "$(PATH="$AT_TMP/bin:$PATH" at names _branch-name COM-77)" \
    'COM-77.add-stripe-listing' 'a short ticket title becomes the slug'

# a long title goes to the model; the model is a stub that shortens it
cat >"$AT_TMP/bin/curl" <<'EOF'
#!/bin/sh
cat >/dev/null
printf '{"data":{"issue":{"identifier":"COM-78","title":"Allow admins to schedule a rebuild for a maintenance window"}}}\n'
EOF
cat >"$AT_TMP/bin/fake-model" <<EOF
#!/bin/sh
cat >"$AT_TMP/slug-prompt"
printf '\`\`\`\nschedule-rebuild-window\n\`\`\`\n'
EOF
chmod +x "$AT_TMP/bin/fake-model"
git -C "$AT_TMP/names" config at.llm.command "$AT_TMP/bin/fake-model"

is "$(PATH="$AT_TMP/bin:$PATH" at names _branch-name COM-78)" 'COM-78.schedule-rebuild-window' \
    'a long title is shortened by the model, fences stripped'
contains "$(cat "$AT_TMP/slug-prompt" 2>/dev/null)" 'Ticket title' 'the prompt reached the model'

# with no model, the first four words are kept
git -C "$AT_TMP/names" config --unset at.llm.command
is "$(PATH="$AT_TMP/bin:$PATH" at names _branch-name COM-78 2>/dev/null)" \
    'COM-78.allow-admins-to-schedule' 'without a model the first four words are kept'

# ------------------------------------------------------- legacy keys ---

at_out names _branch-name MAD-16743 >/dev/null
is "$AT_RC" '1' 'a legacy key cannot have its title fetched'
contains "$AT_OUT" 'MAD-16743' 'and it asks for a slug by name'

is "$(at names _branch-name MAD-16743 stripe-list)" 'MAD-16743.stripe-list' \
    'a legacy key with a slug is fine'

t_done
