# Commit message

You are given a staged diff, its diffstat, and the scopes this repository already uses. Emit a
commit message and nothing else. No preamble, no code fences, no closing remarks.

Write for engineers who know this codebase. Say why the change exists; the diff already shows
what changed. Never invent a reason the diff does not support.

## One change

A single conventional subject line, and nothing else unless there is a reason worth recording.

    fix(rebuild): stop double-firing when a worker restarts mid-job

- type: one of feat, fix, chore, docs, refactor, test, perf, build, ci
- scope: one lowercase word, two only if unavoidable. Prefer a scope this repository already
  uses; infer one from the changed paths only when none of them fits
- subject: lowercase, no trailing period, 72 characters or fewer
- body: only when the reason is not obvious from the subject. Wrap at 72 characters

## Several changes

When the staged diff carries more than one distinct change, the subject is a plain summary of
the whole - no type, no scope - and the body is one conventional line per change.

    stripe payment methods end to end

    feat(stripe): list saved payment methods
    feat(portal): show the saved methods on the billing page
    test(stripe): cover the listing endpoint

Group related edits into the one change they accomplish. Three to six lines is the usual range;
more than eight means the lines are too granular or the commit is too large.

Emit no trailers. The caller adds the ticket and co-author trailers.
