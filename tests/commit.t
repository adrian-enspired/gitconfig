#!/bin/sh
#
# `c`: message generation, trailers, the quicksave amend, hooks.
#
# The model is a stub that echoes a fixed message and records that it ran, so the
# tests can tell a generated message from a given one.

set -u
. "$(dirname "$0")/lib.sh"

mkdir -p "$AT_TMP/bin"
cat >"$AT_TMP/bin/fake-model" <<EOF
#!/bin/sh
cat >"$AT_TMP/model-was-called"
printf 'feat(billing): add stripe payment method listing\n'
EOF
chmod +x "$AT_TMP/bin/fake-model"

model_ran() { [ -f "$AT_TMP/model-was-called" ]; }
model_reset() { rm -f "$AT_TMP/model-was-called"; }

subject() { git -C "$AT_TMP/$1" log -1 --format='%s'; }
trailers() { git -C "$AT_TMP/$1" log -1 --format='%(trailers:only,valueonly)' | tr -d '\n'; }

setup() {
    new_repo "$1" >/dev/null
    git -C "$AT_TMP/$1" config at.llm.command "$AT_TMP/bin/fake-model"
    git -C "$AT_TMP/$1" switch -q -c "${2:-work}"
}

# --------------------------------------------------- a generated message ---

model_reset
setup gen AT-77.stripe-list
printf 'change\n' >"$AT_TMP/gen/file"
git -C "$AT_TMP/gen" add file

at_out gen c -y >/dev/null
is "$AT_RC" '0' 'c commits'
is "$(subject gen)" 'feat(billing): add stripe payment method listing' 'the model wrote the subject'
if model_ran; then ok 'the model was called'; else not_ok 'the model was called'; fi
# the stub writes its stdin to that file: an empty one means the prompt never
# arrived, which is what a backgrounded job's /dev/null stdin does
contains "$(cat "$AT_TMP/model-was-called" 2>/dev/null)" 'Diffstat' 'the prompt reached the model'
contains "$(trailers gen)" 'AT-77' 'the ticket trailer is added'

# --------------------------------------------------- a message given ---

model_reset
setup given AT-78.thing
printf 'change\n' >"$AT_TMP/given/file"
git -C "$AT_TMP/given" add file

at_out given c -y -m 'fix(thing): by hand' >/dev/null
is "$(subject given)" 'fix(thing): by hand' 'a given message is used'
if model_ran; then not_ok 'the model is not called when a message is given'; else ok 'the model is not called when a message is given'; fi

# --------------------------------------------------- on top of a quicksave ---

model_reset
setup quick AT-79.thing
printf 'change\n' >"$AT_TMP/quick/file"
at_out quick f5 >/dev/null
is "$(subject quick)" 'working' 'f5 leaves a working commit'
before=$(git -C "$AT_TMP/quick" rev-list --count HEAD)

at_out quick c -y >/dev/null
is "$(subject quick)" 'feat(billing): add stripe payment method listing' 'c replaces the working message'
is "$(git -C "$AT_TMP/quick" rev-list --count HEAD)" "$before" 'and amends rather than adding a commit'

# ------------------------------------- trailers the model should not send ---

# models add Co-Authored-By and ticket trailers however firmly the rules say not
# to. One would credit work the model did not do; the other duplicates ours.
model_reset
setup chatty AT-90.thing
cat >"$AT_TMP/bin/chatty-model" <<'MODEL'
#!/bin/sh
cat >/dev/null
printf 'feat(x): a thing\n\nwhy it matters\n\nCo-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>\nissue: AT-999\nSigned-off-by: Someone <s@example.invalid>\n'
MODEL
chmod +x "$AT_TMP/bin/chatty-model"
git -C "$AT_TMP/chatty" config at.llm.command "$AT_TMP/bin/chatty-model"
printf 'change\n' >"$AT_TMP/chatty/file"
git -C "$AT_TMP/chatty" add file

at_out chatty c -y >/dev/null
is "$(subject chatty)" 'feat(x): a thing' 'the message itself survives'
body=$(git -C "$AT_TMP/chatty" log -1 --format='%B')
case $body in
    *Co-Authored*) not_ok 'a model-written co-author trailer is dropped' ;;
    *)             ok 'a model-written co-author trailer is dropped' ;;
esac
case $body in
    *AT-999*) not_ok 'and its invented ticket trailer too' ;;
    *)         ok 'and its invented ticket trailer too' ;;
esac
case $body in
    *Signed-off-by*) not_ok 'and a sign-off it had no business adding' ;;
    *)               ok 'and a sign-off it had no business adding' ;;
esac
contains "$body" 'issue: AT-90' 'while our own ticket trailer stays'
contains "$body" 'why it matters' 'and the body stays'

# --------------------------------------------------- um ---

model_reset
setup amend AT-85.thing
printf 'change\n' >"$AT_TMP/amend/file"
git -C "$AT_TMP/amend" add file
at_out amend c -y -m 'fix(thing): by hand' >/dev/null
printf 'more\n' >>"$AT_TMP/amend/file"

at_out amend um -u >/dev/null
is "$(subject amend)" 'fix(thing): by hand' 'um keeps the message'
if model_ran; then not_ok 'um does not call the model'; else ok 'um does not call the model'; fi

printf 'yet more\n' >>"$AT_TMP/amend/file"
at_out amend um -u --regen -y >/dev/null
is "$(subject amend)" 'feat(billing): add stripe payment method listing' 'um --regen rewrites it'

# --------------------------------------------------- staging flags ---

setup stage AT-80.thing
printf 'tracked\n' >"$AT_TMP/stage/README"
at_out stage c -u -y >/dev/null
is "$AT_RC" '0' 'c -u stages tracked changes'
is "$(git -C "$AT_TMP/stage" status --porcelain)" '' 'nothing is left unstaged'

# --------------------------------------------------- co-author ---

setup cc AT-81.thing
printf 'change\n' >"$AT_TMP/cc/file"
git -C "$AT_TMP/cc" add file
git -C "$AT_TMP/cc" config at.commit.coauthor 'Claude Opus 5 <noreply@anthropic.com>'

at_out cc c -y --cc >/dev/null
contains "$(trailers cc)" 'noreply@anthropic.com' '--cc adds the configured co-author'

setup nocc AT-82.thing
printf 'change\n' >"$AT_TMP/nocc/file"
git -C "$AT_TMP/nocc" add file
at_out nocc c -y --cc >/dev/null
is "$AT_RC" '1' '--cc with nothing configured stops'
contains "$AT_OUT" 'at.commit.coauthor' 'and names the setting'

# an attribution given outright beats the configured one - an agent knows which
# model it is, and the setting may name another
setup ccval AT-86.thing
printf 'change\n' >"$AT_TMP/ccval/file"
git -C "$AT_TMP/ccval" add file
git -C "$AT_TMP/ccval" config at.commit.coauthor 'Someone Else <else@example.invalid>'
at_out ccval c -y --cc 'Claude Opus 5 <noreply@anthropic.com>' >/dev/null
contains "$(trailers ccval)" 'Claude Opus 5' 'an explicit --cc value is used'
case "$(trailers ccval)" in
    *else@example*) not_ok 'and the configured one is not' ;;
    *)              ok 'and the configured one is not' ;;
esac

# our flags are found wherever they appear, not only before git's own
setup ccorder AT-87.thing
printf 'change\n' >"$AT_TMP/ccorder/file"
git -C "$AT_TMP/ccorder" add file
at_out ccorder c -m 'fix(x): by hand' --cc 'Claude Opus 5 <noreply@anthropic.com>' -y >/dev/null
is "$AT_RC" '0' 'flags after -m are still ours'
is "$(subject ccorder)" 'fix(x): by hand' 'the message is untouched'
contains "$(trailers ccorder)" 'Claude Opus 5' 'and --cc still applied'

# a message with a quote in it survives the rebuild
setup quoted AT-88.thing
printf 'change\n' >"$AT_TMP/quoted/file"
git -C "$AT_TMP/quoted" add file
at_out quoted c -y -m "fix(x): it's quoted" >/dev/null
is "$(subject quoted)" "fix(x): it's quoted" 'quoting survives'

# a commit with no --cc must not carry the trailer
setup plain AT-83.thing
printf 'change\n' >"$AT_TMP/plain/file"
git -C "$AT_TMP/plain" add file
git -C "$AT_TMP/plain" config at.commit.coauthor 'Claude Opus 5 <noreply@anthropic.com>'
at_out plain c -y >/dev/null
case "$(trailers plain)" in
    *anthropic*) not_ok 'a generated message alone does not add a co-author' ;;
    *)           ok 'a generated message alone does not add a co-author' ;;
esac

# --------------------------------------------------- hooks ---

setup hook AT-84.thing
mkdir -p "$AT_TMP/hook/.git/hooks"
cat >"$AT_TMP/hook/.git/hooks/pre-commit" <<EOF
#!/bin/sh
printf 'ran\n' >"$AT_TMP/hook-ran"
EOF
chmod +x "$AT_TMP/hook/.git/hooks/pre-commit"
printf 'change\n' >"$AT_TMP/hook/file"
git -C "$AT_TMP/hook" add file

rm -f "$AT_TMP/hook-ran"
at_out hook c -y >/dev/null
if [ -f "$AT_TMP/hook-ran" ]; then not_ok 'hooks are skipped by default'; else ok 'hooks are skipped by default'; fi

printf 'more\n' >"$AT_TMP/hook/file"
git -C "$AT_TMP/hook" add file
at_out hook c -y --verify -m 'chore: with hooks' >/dev/null
if [ -f "$AT_TMP/hook-ran" ]; then ok '--verify runs them'; else not_ok '--verify runs them'; fi

# --------------------------------------------------- no model, no message ---

new_repo bare >/dev/null
git -C "$AT_TMP/bare" switch -q -c work
printf 'change\n' >"$AT_TMP/bare/file"
git -C "$AT_TMP/bare" add file
at_out bare c -y >/dev/null
is "$AT_RC" '1' 'no model and no message stops'
contains "$AT_OUT" 'at.llm.command' 'and names the setting'

t_done
