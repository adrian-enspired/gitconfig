# Ticket plugins

git-at talks to one tracker, Linear, through functions wired straight into the script.
Jira is coming back, both will be live at once, and GitHub Issues is a plausible third.
This is the design for making the tracker a plugin.

Nothing here is built yet.

## Shape

One executable per provider, in `<install dir>/plugin/`, named for the provider:

```
~/.config/git/
├── git-at
├── rules/
└── plugin/
    ├── linear
    ├── jira
    └── github
```

`at.ticket.provider` names the one to use. git-at runs it as a command and reads its
output; it is never sourced.

**Why a separate process, not a sourced shell file.** Shell functions share one scope.
Three bugs in this repo's first week were exactly that: `_pr_body` clobbering `_pr`'s
`base`, the test harness's `new_repo` clobbering a caller's `r`, and `repo=$(_base_repo)
|| repo=''` swallowing a refusal. A sourced plugin would add a fourth source of it, from
code the user wrote. A process cannot reach into its caller, can be written in any
language, and can be replaced in a test by five lines of shell.

**Why named plugins, not one configured command.** `at.llm.command` works because there
is one operation with one shape. Ticketing has several verbs and per-provider config.
Naming the provider and shipping implementations beats making each user write a
dispatcher. `at.ticket.command` stays available for pointing at something elsewhere.

## The contract

```
<plugin> api                     → the contract version this plugin implements
<plugin> settings                → the config keys it reads, one per line
<plugin> title  <KEY>            → the ticket's title
<plugin> states <KEY>            → the statuses it can move to, one per line
<plugin> move   <KEY> <STATUS>   → moves it; exit status is the whole answer
<plugin> url    <KEY>            → where a human reads it
```

stdout is data. stderr is for diagnostics, which git-at passes through when it decides
to report a failure. Nothing is interactive: a plugin that needs a password fails with
exit 3 rather than prompting.

### Exit codes are the interface

Callers degrade differently per failure, and today they cannot tell these apart - a
missing API key and a typo'd status produce the same warning.

| Exit | Means | What git-at does with it |
| --- | --- | --- |
| 0 | worked | carry on |
| 1 | anything else | warn, carry on |
| 2 | no such ticket, or no such status | `it` stops; `dk` asks for a slug by hand |
| 3 | not configured | `it` names the setting; `c` and `r` stay quiet |
| 4 | tracker unreachable | warn, carry on, everywhere |
| 5 | verb not supported by this provider | warn once, carry on |

Exit 5 is what makes GitHub possible: issues are open or closed, so `move COM-1 "In
Review"` has no meaning there. Silently ignoring it would hide a broken workflow;
refusing outright would make `at.status.*` unusable. Warning once is the honest middle.

### Versioning

`api` prints an integer. git-at knows which versions it can talk to and says so plainly
when a plugin is too old or too new, rather than failing somewhere deep in a verb.

### Settings

`settings` prints the keys the plugin reads, as `key|description`, e.g.

```
at.plugin.linear.apikey|linear personal api key
at.plugin.linear.workspace|workspace slug, for ticket links
```

`install --help` merges that into its own settings table, so a provider's configuration
is discoverable without the installer knowing anything about the provider. Secrets are
masked by the same rule as everywhere else: a key matching `*apikey|*token|*secret|
*password` is reported as present, never printed.

## Configuration

```gitconfig
[at "ticket"]
	provider = linear            # which plugin, by name
	route = MAD:jira             # repeatable: this prefix uses that provider
	route = NXERR:none           # recognised, never acted on
	prefix = COM                 # unchanged: what a bare number means

[at "plugin.linear"]
	apikey =
	workspace =

[at "plugin.jira"]
	base-url =
	email =
	token =
```

Every provider's settings live under `at.plugin.<name>.`, isolated from git-at's own and
from each other. A plugin reads them itself, with `git config`; git-at never learns what
they are. That is what makes adding a provider a drop-in.

Three of today's settings dissolve into this: `at.linear.apikey` and
`at.linear.workspace` move to the plugin, and `at.ticket.ignored-url` disappears -
a provider knows its own `url`.

### `none` is internal, not a plugin

`none` is git-at's own no-op: it recognises keys, links nothing, and refuses every verb
with exit 5. Shipping an executable that does nothing would be a file to install, a
version to keep current and a process to fork, for behaviour git-at can express in four
lines. Today's `at.ticket.ignored-prefixes` becomes `route = MAD:none`, which says the
same thing in the same vocabulary as every other route.

### Routing

`provider` is the default; `route` overrides it per prefix. With one tracker the routing
table is empty and the cost is nothing. With two - the real case, `MAD-*` in Jira and
`COM-*` in Linear - each key goes where it belongs without a special case in the code.

## Boundaries

**git-at owns** key parsing, prefixes, branch naming, slugs, trailers, PR body assembly,
and the decision of *when* to transition a ticket. None of that is provider-specific.

**The plugin owns** its API, its auth, its config namespace, and its own idea of what a
status is.

**One facade.** `_tracker <verb> [args…]` resolves key → provider → executable, runs it,
and maps the exit code. Nothing else in git-at may touch a tracker. Today's call sites -
`_ticket_slug`, `_ticket_move`, `cmd_it`, `_ticket_url`, `_pr_body` - all go through it.

## Where plugins may come from

`<install dir>/plugin/` and nowhere else, unless `at.ticket.command` names an absolute
path outright.

**Never from the repository being worked in.** A `plugin/` directory inside a cloned repo
would mean `git c` executes code that arrived with the clone. Cloning a repo must stay
safe.

## Porting, in order

1. **Facade and contract, Linear still inline.** Tests use a fake plugin. Proves the
   boundary without changing behaviour.
2. **Linear moves to `plugin/linear`.** No behaviour change: the suite should pass
   untouched.
3. **`plugin/jira`.** Transitions need a transition-ID lookup, which exercises `states`
   harder than Linear does.
4. **`plugin/github`, via `gh`.** The fit test: a provider with no arbitrary statuses.
   If it cannot be made to work cleanly, the contract is Linear-shaped and wrong.
5. **Routing replaces `ignored-prefixes`.**

## Testing

The fake plugin is the point. A five-line script that prints a title and exits 0 lets
every ticket-touching command be tested without a network stub.

This closes a gap that stubbing `curl` cannot. `gh repo view --json parent -q
'.parent.nameWithOwner'` shipped and told every fork it was not a fork, because the stub
returned whatever the test told it to and a wrong field name looks identical to a right
one. Per-plugin tests against a live API are the only thing that catches that class, and
they are opt-in: they need credentials and a network, so they stay out of the default
suite.

## What this costs

- **A fork per tracker call.** A few milliseconds against a network call of hundreds. The
  commands that call a tracker do so once or twice: `dk` for a title, `r` for a
  transition, `it` for the move.
- **A contract to keep stable**, versioned so breaking it is visible.
- **Three implementations instead of one**, each with its own API to track.

Worth it because Jira is coming back and both trackers will be live at once. It would not
be worth it for Linear alone.
