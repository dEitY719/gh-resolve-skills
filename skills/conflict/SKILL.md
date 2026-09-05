---
name: conflict
description: >-
  Rebase-resolve a GitHub PR's "branch has conflicts" warning. Use for
  /gh-resolve:conflict, "PR conflict 해결", "리베이스로 컨플릭트 풀어".
  Not a clean base sync (gh-resolve:outdated) or a CI fix (gh-resolve:ci-fail).
license: MIT
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
metadata:
  model_recommendation:
    tier: opus
    reason: "rebase + conflict resolution with user-intent reasoning; high-risk --force-with-lease push, deep context tracking required"
    claude: prefer
    non_claude: advisory-only
---

# gh-resolve:conflict — Rebase-based PR Conflict Resolution

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` and
output its content verbatim, then stop. No API calls.

## Step 1: Parse Args + Preflight

Record `START_TS=$(date +%s)` immediately for elapsed-time tracking in Step 5.

Positional args: `[pr-number] [remote]`. Both optional. One flag:
`[--worktree <path>]`.

- `remote` — default `origin`; missing → `git remote -v` and stop. Bind
  `TARGET_HOST` + `TARGET_REPO` from that one remote URL **before any `gh` call** per `references/github-target.md` (dEitY719/dotfiles#1403).
- `pr-number` — if omitted, auto-detect via `GH_HOST="$TARGET_HOST" gh pr view
  --json number,headRefName,baseRefName,url,mergeable` on the current branch.
  No PR for the branch → stop. No `--repo` on this one call — `gh` rejects
  `--repo` without a PR argument; `references/github-target.md` → "Exception".
- `--worktree <path>` — every git command becomes `git -C "<path>" ...` and the
  push takes an explicit refspec; makes `pr-number` **mandatory**. Owned by
  `gh-pr:merge-train`. Details: `references/rebase-flow.md` → "`--worktree` mode".

**Mergeable preflight** — immediately after resolving `PR_NUMBER`, run the
host-pinned `gh pr view --json mergeable` short-circuit per `references/rebase-flow.md`
→ "Mergeable preflight" (`MERGEABLE` → already-clean skip; `UNKNOWN`/other → continue).

**Hard preconditions** (parallel batch; any fail → stop) — inside a git repo ·
current branch ≠ repo default (refuse to rebase `main`) · clean tree OR an
announced auto-stash · no in-progress rebase/merge/cherry-pick. Exact batch,
stop reasons, and the `--worktree` variant (`-C "<path>"` everywhere, auto-stash
never fires): `references/rebase-flow.md` → "Preconditions (parallel batch)" and
`references/safety.md`. Capture and print `BACKUP_SHA=$(git rev-parse HEAD)`.

## Step 2: Fetch + Rebase

Run `git fetch "$REMOTE" "$BASE"` then `git rebase "$REMOTE/$BASE"` (with
`-C "<path>"` in `--worktree` mode). Full rebase mechanics, stash handling, and
abort instructions live in `references/rebase-flow.md`.

## Step 3: Conflict Resolution Loop

If `git rebase` exits non-zero with conflicts, run the per-commit loop in
`references/conflict-handling.md`: list `UU`/`AA`/`DU` paths, print the rebase
context, resolve each file with the user's intent (**never auto-guess** an
ambiguous conflict — ask), `git add`, then `git rebase --continue` and repeat.
That file also carries abort guidance and squash suggestions.

## Step 4: Push with `--force-with-lease`

Only after `git rebase` exits 0 and the working tree is clean, run
`git push --force-with-lease "$REMOTE" HEAD`. In `--worktree` mode that becomes
`git -C "<path>" push --force-with-lease "$REMOTE" HEAD:refs/heads/$HEAD_REF` —
a detached HEAD names no destination branch, so the refspec must be explicit.

Never plain `--force`. If `--force-with-lease` is rejected (someone
pushed while you rebased), stop and surface the upstream per
`references/rebase-flow.md` — do NOT silently re-pull-and-rebase.

A successful push means the reviewed commit is no longer head, so Step 5 must
invalidate the stale `review-passed` verdict. Record whether the push succeeded.

## Step 5: Verify Mergeable + Report

Run `GH_HOST="$TARGET_HOST" gh pr view <N> --repo "$TARGET_REPO" --json mergeable,mergeStateStatus,url,labels`.
`MERGEABLE` + `mergeStateStatus ∈ {CLEAN, UNSTABLE}` → the warning is cleared;
print `references/rebase-flow.md` → "Final report format". Still
`CONFLICTING`/`BEHIND` → print the PR URL, name which side diverged, do not loop.

Then run the four post-verify helpers (each soft-fail) exactly as
`references/step5-helpers.md` specifies: remove the `conflict` label, return the
board card to `In review`, post the ai-metrics comment, and drop the stale
`review-passed` verdict. That last one is gated on Step 4's push rather than on
`mergeable`. Never touch `review-blocked` here (dEitY719/dotfiles#1563).

## Constraints

Full constraint list: [references/constraints.md](references/constraints.md)

## Related Skills

Same PR-lifecycle slot, different verb — `gh-resolve:outdated` (clean rebase, base
moved but nothing conflicts) · `gh-resolve:ci-fail` (read failing CI logs and fix).
