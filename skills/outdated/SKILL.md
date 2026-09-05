---
name: outdated
description: >-
  Clean-rebase a GitHub PR "out-of-date with the base branch" — no file
  conflicts. Use for /gh-resolve:outdated, "PR base out-of-date",
  "base 변경됐는데 sync". Conflicts → gh-resolve:conflict; CI red →
  gh-resolve:ci-fail.
license: MIT
allowed-tools: Bash, Read
metadata:
  model_recommendation:
    tier: sonnet
    reason: "clean rebase + --force-with-lease push with rejected-push and conflict handoff; not pure read-only, but no deep reasoning"
    claude: prefer
    non_claude: advisory-only
---

# gh-resolve:outdated — Clean Rebase for Out-of-Date PR

## Help

Arg #1 `-h`/`--help`/`help` → read `references/help.md` verbatim, stop.
No API calls.

## Step 1: Parse Args + Preflight

Record `START_TS=$(date +%s)` immediately for Step 5.

Positional `[pr-number] [remote]`, both optional (`remote` defaults to
`origin`). One flag, `[--worktree <path>]`, runs every git command in `<path>`
instead of the current checkout and makes `pr-number` **mandatory** — the caller
(`gh-pr:merge-train`) hands over a detached worktree with no branch to
auto-detect a PR from. Without the flag the behaviour is exactly what it was.

Bind `TARGET_HOST` + `TARGET_REPO` from the remote's URL **before any `gh`
call** (`references/github-target.md`, dEitY719/dotfiles#1403), check `gh` auth, and enforce the
hard preconditions (git repo · not default branch · clean tree · no in-progress
rebase). Arg table, exit codes, and which preconditions `--worktree` mode drops
and why: `references/preflight.md`. Capture `BACKUP_SHA=$(git rev-parse HEAD)`
(in `--worktree` mode, `git -C "<path>" rev-parse HEAD`).

## Step 2: Mergeable Triage

Read `GH_HOST="$TARGET_HOST" gh pr view "$PR_NUMBER" --repo "$TARGET_REPO"
--json mergeable,mergeStateStatus,baseRefName,headRefName,url` and resolve it
via the action matrix in `references/mergeable-triage.md` — only
`MERGEABLE`/`BEHIND` proceeds to Step 3; `CONFLICTING` delegates to
`gh-resolve:conflict` (exit 3), already-clean is a no-op (exit 0 — idempotent,
safe to re-run).

## Step 3: Fetch + Clean Rebase

```bash
git fetch "$REMOTE" "$BASE"
git rebase "$REMOTE/$BASE"
```

In `--worktree` mode both become `git -C "<path>" ...`. Rebase exits non-zero
with conflicts → `git rebase --abort` immediately, print `[FAIL] rebase produced
conflicts — use /gh-resolve:conflict <PR_NUMBER>` + exit 4. Never auto-guess —
hand off to the sister skill.

## Step 4: Push with `--force-with-lease`

Only after `git rebase` exits 0 and the tree is clean:

```bash
git push --force-with-lease "$REMOTE" HEAD
```

Never plain `--force`. Rejected (remote advanced while rebasing) →
`[FAIL] remote advanced — re-fetch and retry` + exit 6. Never silently
re-fetch — surface divergence so the user decides (lost-update risk).
`--worktree` mode needs an explicit refspec instead of a bare `HEAD` (a detached
HEAD names no destination branch): `references/push-and-report.md` → "Push".

A successful push means the reviewed commit is no longer head, so Step 5 must
invalidate the stale `review-passed` verdict. Record whether the push succeeded.

## Step 5: Verify + Report

Re-read `--json mergeable,mergeStateStatus,url` and interpret per
`references/mergeable-triage.md` → "Step 5 verification". Only if Step 4's push
actually succeeded, drop the `review-passed` label per
`references/verdict-label-removal.sh.md` (soft-fail). Never touch
`review-blocked` — this skill holds no evidence the blockers were addressed —
and never *add* either label; `gh-verify:review-all` owns that (dEitY719/dotfiles#1563).

Report banner and the ai-metrics footer (skipped when `GH_DISABLE_AI_METRICS=1`,
dEitY719/dotfiles#399): `references/push-and-report.md` → "Report".

## Constraints

Full constraint list: [references/constraints.md](references/constraints.md)

## Related Skills

Same PR-lifecycle slot, different verb — `gh-resolve:conflict` (rebase that
walks each conflicting file) · `gh-resolve:ci-fail` (read failing CI logs and
fix). Full list: `references/help.md` → "Related skills".
