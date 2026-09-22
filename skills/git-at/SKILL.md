---
name: git-at
description: Use the git-at commands for git work in repos where they are installed - starting a branch from a ticket, committing, rebasing onto current reality, opening or updating pull requests, moving tickets. Use when doing any git work, or when asked what to run next.
---

# git-at

`git-at` is a set of short git commands: `dk` to branch from a ticket, `c` to commit,
`dr` to rebase onto current reality, `r` to open a pull request. They record state git
does not — where a branch's own work begins, which branch it was stacked on — so
prefer them over raw git for anything they cover.

`git h` lists every command. `git h <command>` prints its full description and flags.
Read those rather than guessing a flag; they are generated from the source, so they are
never out of date.

## First: are you allowed to run git?

```sh
git config --get at.agent.mode
```

`suggest` means **do not run anything that changes state**. Work out what should happen
and print it instead, one command per line:

```
next: git c --all -y -m 'fix(rebuild): stop double-firing on worker restart'
then: git dr && git oof
then: git r -y
```

Anything else - including unset - means act, subject to the rest of this file. A direct
instruction from the user outranks the setting in either direction.

Read-only commands (`git s`, `git h`, `git fb`, `git b`) are fine in both modes.

## Write the text yourself

`git c` and `git r` call a model to write commit messages and PR bodies when you do not
supply one. That model sees the diff and nothing else - not the conversation, not the
reason for the change, not the ticket. You have all of it, so write the text yourself
and pass it in:

```sh
git c --all -y -m 'feat(stripe): list saved payment methods'
git r -y '[AT-12345] Rebuild Window' "$(cat /tmp/pr-body.md)"
```

Match the house style by reading the prompt files first - the same ones the model would
have used, so the output looks the same either way:

```sh
ls "$(git config --get at.llm.rules || echo ~/.config/git/rules)"
```

`commit.md` governs commit messages, `pr.md` PR bodies, `slug.md` branch slugs.

`git r -y --no-summary` assembles a body with the prose sections stubbed, if you would
rather fill a skeleton than write one from scratch.

## Attribute yourself, by name

When you wrote the code, say who you are outright rather than leaning on
`at.commit.coauthor` - that setting names whatever model its owner configured, which
may not be you:

```sh
git c --all -y -m 'feat(stripe): list saved methods' --cc 'Claude Opus 5 <noreply@anthropic.com>'
```

Use your own model name and version. The trailer attributes the **code**: add it when
you wrote or edited the diff, and leave it off when you only drafted the message or ran
the commands for someone else. A false attribution is worse than none.

## Always pass -y

`c` and `r` open an editor without it, and you will hang until something times out.

## The usual shapes

| Intent | Command |
| --- | --- |
| start work on a ticket | `git dk <ticket> <slug>` |
| stack on the current branch | `git uk <ticket> <slug>` |
| checkpoint, no message needed | `git f5` |
| commit for real | `git c --all -y -m '<message>'` |
| fix the last message | `git um -m '<message>'` |
| catch up with the default branch | `git dr` |
| publish a rewritten branch | `git oof` |
| open a pull request | `git r -y '<title>' "<body>"` |
| move a ticket | `git it '<status>'` |
| where am I | `git s` |

Pass the slug yourself on `dk`/`uk`: generating one costs a model call and you already
know what the work is.

## Ask before you do these

- `git bd`, `git bdf` - they delete branches
- `git oof`, `git uff` - they rewrite published history
- `git dr` on a branch someone else is working on
- anything at all while on the default branch

Never pass `-y` to a command that deletes.

## When a command refuses

The messages say what to do. Read them out rather than working around them:

- *"was rewritten since it was last pushed"* → `git oof`, never `git pull`
- *"parent is behind"* → `git dr --restack`, or `--no-restack` to go ahead anyway
- *"branch point recorded ... is stale"* → pass a commit-ish: `git dr <commit-ish>`
- *"github does not see X as a fork of Y"* → the fork relationship is wrong; ask

A refusal is the tool telling you something you did not know. Do not route around it
with raw git.

## More

`docs/` in the git-at repo covers setup, working on a ticket, opening a pull request,
and collaborating on someone else's branch.
