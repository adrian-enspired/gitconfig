# git-at rewrite

The agreed design, settled in a grilling session. Implementation order is at the end.

No backwards compatibility: this is a fresh start. `duk` is dropped.

## Command scope

**Rewritten:** `o` `op` `oof` `up` `uff` · `b` `bk` `bd` `bdf` · `d` `ds` `dk` `dr` `uk` ·
`c` `u` `all` `um` `f5` · `r` `rd` `rr` `urr` · `madd` `t` `s` `h` `ll` `lg`

`b [<pattern>] [-r <remote>] [-i]` replaces `b` `bi` `br` `bri` `bg` `bgi` `bgr` `bgri`, and
`bk [<pattern>] [-r <remote>]` replaces `bk` `bkr` `bkd` - bare `bk` already goes to the
default branch. `-r` requires a remote by name: listing
every remote meant fetching from all of them, which was slow and unpredictable.

**Carried over, dependency fixes only:** the patch commands (`p` `pf` `pb` `pall` `pw` `pl`
`pd`), the diff commands (`fb` `fd` `fk`), the discovery commands (`oh` `oor` `or`).

`fb`, `pf`, `pb` and `pall` compare against the branch point when given no argument, and
against where HEAD diverged from the ref when given one. `fk` and `fd` keep their own meaning -
everything since the default branch - because "what did I change" and "what will land" are
different questions on a stacked branch. `pw` is HEAD-relative and unaffected.

`radd` is renamed `madd` (`m` for remote; `r` means pull request).

## Branch point

A branch point is the commit after which a branch's own work begins. It survives the parent
being squash-merged; a merge base does not.

Resolution order, **with no graceful degradation**:

1. an explicit commit-ish argument
2. `branch.<name>.atbase`, the recorded branch point
3. the merge base with the default branch

Failures that stop the command:

- an explicit commit-ish that does not resolve
- a recorded branch point that is no longer an ancestor of the branch, and no usable pending
  value (see below)

Every run prints which source it used and how many commits it will replay.

### Pending value

`dr` writes the intended new branch point to `branch.<name>.atbasepending` before it starts
the rebase. When resolution finds `atbase` is no longer an ancestor but the pending value is,
the pending value is promoted: that is a rebase the user finished by hand with
`git rebase --continue`. An aborted rebase needs nothing, since `atbase` is still valid.

### Content check

Before replaying, each commit in the replay range is tested against the default branch. Work
already present there is not replayed: the branch point advances past it and `dr` says how much
it skipped. This is what catches a squash-merged parent — git's own patch-id check cannot,
because a squash collapses many commits into one whose patch-id matches none of them.

The same rule covers a branch whose own first commits have landed, which is the ordinary end of
a stack: the remaining commits rebase onto the default branch and the merged ones are left
behind. Landed work appearing *after* unlanded work is not skipped — that is a cherry-pick or a
non-contiguous range, so it is reported and left for the rebase to drop or conflict on. A branch
with nothing left to replay is reported as such rather than rebased into nothing.

Implementation: `git apply --reverse --check` against a temporary index holding the default
branch's tree (`GIT_INDEX_FILE` + `git read-tree`). The working tree is never touched.

The check runs on every resolution path, not only the merge-base one.

### Who records what

| Command | `atparent` | `atbase` |
| --- | --- | --- |
| `dk` | none (parent is the default branch) | default branch tip |
| `uk` | the current branch | the current branch tip |
| `bkr` | the PR base branch via `gh`, when it is not the default branch | merge base with that branch, else with the default branch |
| `dr` | cleared once the parent has landed | new base after a successful rebase |

`git branch -m` and `git branch -D` carry or remove the whole `branch.<name>` section, so
renames and deletions need no cleanup code.

## Stacking

`dr` always syncs the default branch first, requires a clean tree, and returns to the starting
branch whatever happens.

- A live parent: restack onto the parent's tip.
- A parent whose content is in the default branch: rebase onto the default branch, clear
  `atparent`.
- A parent branch that is gone and has not landed: stop. Something was lost.

Ancestors are left alone by default. `--restack` rebases them bottom-up first; `--no-restack`
proceeds onto a stale parent. When the parent is stale and neither flag is given, `dr` stops
and names the branch to run first.

`bd` uses the content check instead of `git branch --merged`, so squash-merged branches are
cleaned up. It deletes with `-D` (`-d` refuses squash-merged branches), which makes the
printed list load-bearing; the confirmation stays.

## Tickets

Linear over `curl` + `jq`. No MCP, no LLM: a tracker call has a fixed shape.

- API key in `at.linear.apikey`, set in the user's own git config. The repo ships the key with
  an empty value.
- Keys whose prefix is listed in `at.ticket.ignored-prefixes` belong to another tracker.
  Recognised, linked and carried in trailers, never looked up or transitioned. The list is
  empty by default, so nothing is ignored until it says so; `at.ticket.ignored-url` is the
  template their links are built from, and without it they are named but not linked.
- Branch names are `<KEY>.<slug>`. `<KEY>-<slug>` is recognised, never produced.

Argument forms for `dk` / `uk`:

| Input | Rule | Result |
| --- | --- | --- |
| `12345` | all digits | `at.ticket.prefix` + generated slug |
| `COM-12345` | matches `KEY-123` | generated slug |
| `12345 my-slug` | two arguments | `COM-12345.my-slug` |
| `COM-12345.my-slug` | contains `.` | used as-is |
| `my-slug` | none of the above | no ticket |

Keys are uppercased, slugs lowercased. An ignored key, or any failure to fetch the title, stops
with a request for an explicit slug.

Slugs: lowercase kebab-case, 40 characters or fewer, taken from the ticket title. Over four
words the model shortens it; with no model, keep the first four words and truncate at a dash.

Status changes come from `at.status.<cmd>`; an empty value means leave the status alone.
Defaults shipped in `gitconfig`: `dk`/`uk` → In Progress, `r`/`rr` → In Review, `rd`/`urr` →
In Progress.

## Tickets: pluggable trackers

Ticketing is Linear-only and wired into the script. Making the tracker a plugin - one
executable per provider under `<install dir>/plugin/`, a versioned verb contract, exit codes
callers can degrade on, and prefix routing so Jira and Linear can be live at once - is designed
in [docs/ticket-plugins.md](docs/ticket-plugins.md). Not built yet; the sections below describe
what exists today.

## LLM assistance

One contract: **prompt on stdin, text on stdout**. `at.llm.command` holds any command meeting
it (`claude -p --model haiku`, `ollama run qwen3:4b`, …), overridable per feature.

Features: commit message, PR body, branch slug. (PR titles come from the branch name and cost
no model call.)

Everything degrades: on timeout or error, warn and fall back to the non-LLM behaviour. macOS
ships no `timeout`, so the timeout is ours to implement (background job plus `kill`). The prompt
reaches the command through a temp file, because POSIX gives a background job `/dev/null` on
stdin before any other redirection - piping it in loses it.

`claude -p` is itself an agent: with its tools, MCP servers and `CLAUDE.md` loaded it will
inspect the repo instead of answering the prompt. The suggested command empties both
(`--allowed-tools "" --setting-sources ""`), which also takes about two seconds off each call.
Output cleanup drops `Co-Authored-By`, `issue:` and `Signed-off-by` lines whatever the rules
say: a model-written attribution would credit work it did not do, and the ticket trailer is
the caller's to add.

Prompts live in `rules/*.md`, path overridable via `at.llm.rules`. Output cleanup — stripping
code fences, preambles and blank edges — is shared code, since small local models add them.

## Commits

- One change → a conventional subject: `<type>(<scope>): description`.
- Several changes → a plain summary subject, with one conventional line per change in the body.
- Scope: one lowercase word (two only if unavoidable), chosen from the vocabulary already in
  `git log`, falling back to the changed paths.
- Types: `feat` `fix` `chore` `docs` `refactor` `test` `perf` `build` `ci`.
- Trailers: `issue: <KEY>` whenever the branch is linked; `Co-Authored-By` only with `--cc`,
  valued from `at.commit.coauthor` (with `--cc "<name> <email>"` overriding it). `--cc` with no
  value configured stops and names the key to set.

`c` flags: `-u` / `--all` (stage first, matching `um`), `-y` (skip the editor), `--verify`
(run hooks; `--no-verify` stays the default). `c` never keeps a `working` message: committing
on top of a quicksave amends it and generates the real message from the full diff.

`um` keeps the existing message by default; `um --regen` regenerates it from the amended diff.

`f5` stays literal: subject `working`, no model, no hooks, amended by successive saves.

## Pull requests

- Title from the branch name: dashes to spaces, Title Case, ticket key in brackets when
  present — `COM-12345.add-stripe-listing` → `[COM-12345] Add Stripe Listing`.
- Body keeps every section of the existing `pr-body`: ticket links, Why, What, Blast radius,
  Reading guide (omitted for a single file), Test plan (points at the ticket), Deploy notes,
  then `issue:` and co-author trailers. The model writes only Why through Reading guide;
  everything else is assembled from git.
- The commit range comes from the **branch point**, not the merge base.
- `-y` skips the editor; `--no-summary` skips the model call and stubs those sections.

Base resolution, for both the repo and where the parent branch is looked for:

1. `--base` when given
2. `upstream`
3. `origin`
4. `gh repo view --json parent,nameWithOwner`
5. `branch.<default>.remote`
6. the first-listed remote

A recorded parent branch becomes the PR base when it exists on the resolved remote.

A PR from origin into upstream only exists if GitHub sees origin as a fork of upstream. When it
does not - two repos that share history locally but were created independently - `gh pr create`
fails after pushing, with GitHub's GraphQL validation errors. git-at asks `gh` first and falls
back to origin with a warning; if `gh` cannot answer, it does not stand in the way.

`oof` / `uff` push with `--force-with-lease --force-if-includes`.

## Help

`h` is generated: the comment above each command is its summary, and commands are grouped by
the section of the script they live in, so the file's organisation is the help's organisation.
Plain-git aliases come from `at-aliases.gitconfig`, grouped by its `# --- family ---` markers,
and documented by what they expand to. `git h <command>` prints the whole comment block, or an
alias's expansion, and `git h <family>` prints one family.

`s` sits with the log commands, `madd` with the push ones, and `i` (the branch's ticket key,
formerly `j`) with discovery. `o` is left out of the index as a second spelling of `op`.

Three families are left out of the index: `diffs` and `patches` are reached for rarely and are
long enough to bury the rest, and `discovery` is machinery the other commands call rather than
anything to run by hand. The index footer names them, and they stay reachable through
`git h diffs`, `git h patches` and `git h discovery`. `_sync-help` checks every command has a summary and an alias, that no
alias points at a command that does not exist, and that every unlisted family still names
something.

## Mechanics

- POSIX sh, running on macOS and Linux, clean under `shellcheck`. BSD/GNU differences in
  `sed`, `stat` and `date` are handled as they are today.
- Tests: a POSIX sh script that builds throwaway repos in a temp directory and asserts
  outcomes, including a squash-merged parent. `_sync-help` runs as part of the suite.
- `h` is generated at runtime by parsing the comment above each `cmd_*`; `_sync-help` checks
  that every command has one.
- `install` copies the directory into `~/.config/git/`.

### Configuration

Every setting lives under `at.*`, every environment variable under `AT_*`.

| Purpose | Setting | Environment |
| --- | --- | --- |
| Ticket prefix | `at.ticket.prefix` | `AT_TPREFIX` |
| Other trackers' prefixes | `at.ticket.ignored-prefixes` | `AT_IGNORED_PREFIXES` |
| Their link template | `at.ticket.ignored-url` | `AT_IGNORED_URL` |
| Linear API key | `at.linear.apikey` | `AT_LINEAR_APIKEY` |
| Linear workspace | `at.linear.workspace` | `AT_LINEAR_WORKSPACE` |
| Linear endpoint | `at.linear.endpoint` | `AT_LINEAR_ENDPOINT` |
| LLM command | `at.llm.command` | `AT_LLM_COMMAND` |
| Per-feature LLM command | `at.llm.<feature>command` | `AT_LLM_<FEATURE>_COMMAND` |
| LLM timeout (seconds) | `at.llm.timeout` | `AT_LLM_TIMEOUT` |
| Rules directory | `at.llm.rules` | `AT_LLM_RULES` |
| Patch directory | `at.patch.dir` | `AT_PATCH_DIR` |
| Commit co-author | `at.commit.coauthor` | `AT_COMMIT_COAUTHOR` |
| Status per command | `at.status.<cmd>` | `AT_STATUS_<CMD>` |

Per-branch state: `branch.<name>.atbase`, `.atparent`, `.atbasepending`.

## Implementation order

1. Test harness, `shellcheck`, `_sync-help` as a test
2. Branch point: resolution, pending value, content check
3. Sync and stacking: `ds` `dk` `uk` `dr` `bkr` `bd`
4. Commit: `c` `u` `all` `um` `f5`
5. Pull requests: `r` `rd` `rr` `urr`
6. The rest: `b*` `madd` `t` `s` `h`, push aliases, carried-over commands
