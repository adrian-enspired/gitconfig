# git-at

Personal git workflow tooling: short commands for branching, syncing, committing, patching,
pull requests, and ticket tracking, with pluggable LLM assistance.

## Language

### Tickets

**Ticket key**:
The identifier of a Linear issue, e.g. `ENG-123`.
_Avoid_: task id, jira id, issue number

**Ignored ticket key**:
A ticket key whose prefix the project has listed as belonging to another tracker. It is
recognised and linked, but never looked up or transitioned.
_Avoid_: legacy key, jira key

**Linked branch**:
A branch whose name begins with a ticket key, separated from its slug by `.`
(canonical) or `-` (recognised, never produced), e.g. `ENG-123.stripe-list`.

### Branches and remotes

**Default branch**:
The branch that origin's `HEAD` points to; the trunk that work is cut from and lands on.
_Avoid_: master, main, trunk

**Origin**:
The remote the user pushes to: their own repo, or their fork.

**Upstream**:
The remote a fork was made from. When it exists the repo is treated as a fork.

**Branch point**:
The commit after which a branch's own work begins. Stays correct after its parent branch is
squash-merged, unlike the merge base.
_Avoid_: fork point, cut point, base

**Tracked branch point**:
A branch point git-at recorded for a branch, rather than one given explicitly or derived from
the merge base.

**Quicksave**:
A throwaway `working` commit that successive saves amend, holding work in progress.

**Merged**:
A branch is merged when its work has landed on the default branch, by any merge type —
including squash, where the branch's commits are not in the default branch's history.

### LLM assistance

**LLM backend**:
The pluggable model provider (e.g. Claude, Ollama) that git-at calls non-interactively for
generated text and ticket lifecycle work.
_Avoid_: AI, agent, model
