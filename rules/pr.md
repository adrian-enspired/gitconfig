# PR body sections

You are given a branch's commit subjects and its diffstat. Emit four markdown sections, in this
order, and nothing else. No preamble, no code fences, no closing remarks.

Write for engineers who know this codebase. Direct, concise, no formal register. Sentence
fragments are fine when they are clear. Nothing that does not need saying - a long body does not
get read, so every line has to earn its place.

Never invent. If the commits and diffstat do not tell you something, leave it out.

Diffstat numbers are changed lines, not changed things. Four variables on eight lines is four
variables. Do not quote a count you only got from the diffstat.

---

## Why

One sentence on the problem or requirement. The ticket holds the detail, so do not restate it,
do not explain the approach, do not list what changed.

    rebuilds ran the moment an admin clicked, so there was no way to schedule one for a
    maintenance window

## What

Bullets on the approach taken. One line each, no sub-bullets. Three to six is the usual range;
a branch needing more than eight is either large or the bullets are too granular.

Say what the change does, not which commit did it. Group related commits into the one thing they
accomplish.

    - queue rebuilds in a new table instead of running them inline
    - worker claims a row with `SELECT ... FOR UPDATE`, so a restart mid-job cannot double-fire
    - admin form takes a run-at; empty means now, which is the old behaviour

### Blast radius

One line. What a reviewer should worry about breaking. Name the surface, not the severity - no
"low risk", no "safe".

    admin rebuild path and the rebuild worker; no change to the API or to existing queued jobs

## Reading guide

A table mapping the files worth reading to what to look at and why. Cover the files carrying the
substance, not every file in the diffstat. Order by what a reviewer should read first.

Keep cells short. "Why" is why the file needs attention, not what the file is.

**Omit this whole section when the prompt says 1 file changed.**

    | File | What to look at | Why |
    |---|---|---|
    | `src/Rebuild/Queue.php` | the claim query | the FOR UPDATE is what stops double-firing |
    | `src/Ctrl/Admin/Rebuild.php` | run-at handling | empty must stay equivalent to the old path |

---

Emit exactly the sections above, starting with `## Why`. The caller writes the ticket line, test
plan, deploy notes and trailers - do not produce those.
