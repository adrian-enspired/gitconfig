# Record the branch point instead of deriving it

`dr` and the diff and patch commands used `git merge-base` to find where a branch's own work
begins. That is only correct while the branch's base is still in the default branch's history,
and a squash merge breaks it: the parent's commits exist in the default branch's content but
not as those commit objects, so the merge base falls back to the last genuinely shared commit
and the rebase tries to replay the parent's work as if it were the branch's own. It presents
as `add/add` conflicts in files nobody touched. So git-at now records the branch point in
`branch.<name>.atbase` when a branch is created and updates it after every rebase, alongside
`branch.<name>.atparent` for stacked branches.

## Considered options

- **Pass the cut point by hand** (`dr protostripe`). One line, no state, handles every case —
  but the correct everyday invocation has to take no argument, and the failure is silent until
  the conflicts arrive.
- **Detect the parent from branch refs** (`for-each-ref --merged <branch> --no-merged
  <default>`). Needs no state, but fails once the parent branch is deleted and has to guess
  between candidates.
- **Record the parent branch's name** using git's own upstream tracking. The name is worthless
  once the parent is deleted, which is exactly the case that motivated this.
- **`git rebase --fork-point`.** Reads the upstream's reflog: local-only, expires after 90
  days, absent on a fresh clone.
- **Patch-id detection.** Structural dead end. A squash collapses many commits into one whose
  patch-id matches none of them, so rebase's own already-applied check cannot see it.

## Consequences

- Recorded state can go stale, so it is validated rather than trusted: the recorded commit must
  still be an ancestor of the branch, and an explicit argument always wins. Resolution never
  degrades silently — it stops.
- A rebase the user finishes by hand with `git rebase --continue` would otherwise leave the
  record stale, so `dr` writes the intended value to `branch.<name>.atbasepending` first and
  promotes it when the current record turns out not to be an ancestor.
- Branches created outside git-at, fresh clones and other machines have no record and fall back
  to the merge base. A content check — is this commit's change already in the default branch? —
  guards that path and catches the squash case that started all this.
- `git branch -m` and `-D` carry and remove the whole `branch.<name>` config section, so there
  is no cleanup code to write.
