![](https://img.shields.io/badge/sh-POSIX-blue.svg)  ![](https://img.shields.io/badge/license-MIT-orange.svg)

git at it!
==========

A handful of short git commands for the workflow most of us actually use: fork, branch from a ticket, commit as you go, keep up with the default branch, open a pull request.

_git-at_:
- ✓ remembers where a branch's own work begins — so rebases and diffs stay right after a squash merge
- ✓ remembers which branch it was stacked on — so `dr` restacks it, and its PR targets the parent
- ✓ remembers which ticket it belongs to — so commits carry the trailer, and the ticket moves with the work
- ✓ makes LLM integration easy and flexible — any model that takes a prompt on stdin can write your commit messages, PR bodies and branch names, or none, if you'd rather write them yourself

It also comes with an opinionated (but useful) set of git settings, for the parts of this workflow git leaves to configuration.

**This is pre-release.** Commands and settings may still change. Linear is the only ticket backend for now; the plan is to make ticket backends pluggable.

dependencies
------------

POSIX `sh` and `git`.

Everything else is optional, and each one only costs you the commands that need it:
- `gh` for forks and pull requests
- `curl` and `jq` for ticket lookups (Linear, for now)
- a model runner (`claude`, `ollama`, …) for generated text

installation
------------

```sh
git clone git@github.com:adrian-enspired/gitconfig.git && cd gitconfig && ./install
git config --global --add include.path ~/.config/git/at-aliases.gitconfig
```

`./install --help` shows every setting, its current value, and anything missing.

The git settings live in [`gitconfig`](gitconfig). `install` doesn't apply them — they're opinions, so copy the ones you want. [Getting set up](docs/setup.md#the-git-settings-it-assumes) says which ones the workflows lean on.

a quick taste
-------------

```console
$ git cf acme/widgets && cd widgets
cloned into ./widgets
  upstream  git@github.com:acme/widgets.git
  origin    git@github.com:you/widgets.git

$ git dk 12345
origin/master: already level with upstream (1a2b3c4)
master: already up to date with upstream (1a2b3c4)
on AT-12345.schedule-rebuild-window

$ git f5                  # hack, save, hack, save…
[AT-12345.schedule-rebuild-window 9f8e7d6] working
 3 files changed, 61 insertions(+), 4 deletions(-)

$ git c -y
[AT-12345.schedule-rebuild-window 4c3b2a1] feat(rebuild): let admins schedule a rebuild for a maintenance window
 Date: Mon Sep 21 14:02:11 2026 -0400
 3 files changed, 61 insertions(+), 4 deletions(-)

$ git dr                  # master moved while you worked
origin/master: 1a2b3c4 -> 8e9f0a1, from upstream
master: 1a2b3c4 -> 8e9f0a1, from upstream
branch point: recorded 1a2b3c4
replaying 1 commit(s) onto master
Successfully rebased and updated refs/heads/AT-12345.schedule-rebuild-window.
AT-12345.schedule-rebuild-window: 4c3b2a1 -> 2b3c4d5

$ git r -y
opening a PR against master on acme/widgets
Creating pull request for you:AT-12345.schedule-rebuild-window into master in acme/widgets

https://github.com/acme/widgets/pull/42
```

The branch name came from the ticket's title, the commit message from the diff, and the PR title and body from the branch and its commits. Every one of them can be written by hand instead.

`git h` lists the commands; `git h <command>` explains one.

workflows
---------

- [Getting set up](docs/setup.md)
- [Working on a ticket](docs/working-on-a-ticket.md)
- [Opening a pull request](docs/opening-a-pull-request.md)
- [Working with a collaborator](docs/working-with-a-collaborator.md)

using it from an agent
----------------------

`./install` offers to install a skill that teaches coding agents to use these commands — to write their own commit messages and PR bodies rather than handing off to a second model, to attribute themselves correctly, and to suggest commands instead of running them when you'd rather they didn't:

```sh
git config --global at.agent.mode suggest
```

It's a plain markdown file, so any harness that reads one can use it; set `at.agent.skilldir` to put it somewhere other than `~/.claude/skills/git-at`.

tests
-----

```sh
sh tests/run
```

Everything runs against throwaway repos, with `gh`, `curl` and the model stubbed out. [shellcheck](https://www.shellcheck.net/) runs too, when it's installed.

contributing or getting help
----------------------------

Open an issue [on github](https://github.com/adrian-enspired/gitconfig/issues). Feedback is welcomed.
