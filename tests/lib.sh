# shellcheck shell=sh
#
# Helpers for the .t files. Sourced by each one; never run directly.
#
# Every fixture repo is built from scratch in $AT_TMP, so tests never touch a real
# repository and never read the user's git config (the runner points HOME and the
# config env vars at the temp tree).

: "${AT:?tests must be run through tests/run}"
: "${AT_TMP:?tests must be run through tests/run}"

T_PASS=0
T_FAIL=0
T_NAME=${0##*/}

ok() {
    T_PASS=$((T_PASS + 1))
    printf 'ok %s - %s\n' "$((T_PASS + T_FAIL))" "$1"
}

not_ok() {
    T_FAIL=$((T_FAIL + 1))
    printf 'not ok %s - %s\n' "$((T_PASS + T_FAIL))" "$1"
    [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/    /'
    return 0
}

is() {  # $1: got  $2: want  $3: name
    if [ "$1" = "$2" ]; then
        ok "$3"
    else
        not_ok "$3" "got:  $1
want: $2"
    fi
}

contains() {  # $1: haystack  $2: needle  $3: name
    case "$1" in
        *"$2"*) ok "$3" ;;
        *)      not_ok "$3" "got:      $1
contains: $2" ;;
    esac
}

t_done() {
    printf '# %s: %s passed, %s failed\n' "$T_NAME" "$T_PASS" "$T_FAIL"
    [ "$T_FAIL" -eq 0 ]
}

# ------------------------------------------------------------------ fixtures ---

# a repo with one commit on the default branch, and nothing else
#   $1: name (becomes a directory under $AT_TMP)
# shell functions share one scope, so these locals carry a prefix the .t files
# are not going to reach for
new_repo() {
    _nr="$AT_TMP/$1"
    mkdir -p "$_nr" || return 1
    git -C "$_nr" init -q -b master
    git -C "$_nr" config user.name 'git-at tests'
    git -C "$_nr" config user.email 'tests@example.invalid'
    git -C "$_nr" config commit.gpgsign false
    write_commit "$1" README 'initial' 'initial'
    printf '%s\n' "$_nr"
}

# add or change a file and commit it
#   $1: repo  $2: file  $3: content  $4: subject
write_commit() {
    printf '%s\n' "$3" >"$AT_TMP/$1/$2"
    git -C "$AT_TMP/$1" add "$2"
    git -C "$AT_TMP/$1" commit -qm "$4"
}

# squash-merge a branch into the current one, the way the team's PRs land
#   $1: repo  $2: branch
squash_merge() {
    git -C "$AT_TMP/$1" merge -q --squash "$2" >/dev/null
    git -C "$AT_TMP/$1" commit -qm "squashed: $2"
}

# run git-at inside a fixture repo
#   $1: repo  rest: arguments
at() {
    _at_r=$1; shift
    (cd "$AT_TMP/$_at_r" && sh "$AT" "$@")
}

# run git-at, capturing stdout+stderr; exit status lands in $AT_RC
#   $1: repo  rest: arguments
at_out() {
    _at_r=$1; shift
    AT_OUT=$( (cd "$AT_TMP/$_at_r" && sh "$AT" "$@") 2>&1 )
    # shellcheck disable=SC2034  # AT_RC and AT_OUT are read by the .t files
    AT_RC=$?
    printf '%s' "$AT_OUT"
    return 0
}

sha() { git -C "$AT_TMP/$1" rev-parse "$2"; }

config() { git -C "$AT_TMP/$1" config "$2" 2>/dev/null || printf ''; }
