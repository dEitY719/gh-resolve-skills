# Step 1 — args, repo resolution, and hard preconditions

Positional args: `[pr-number] [remote]`, both optional. One flag:
`[--worktree <path>]`.

- `remote` — default `origin`; missing → `git remote -v` + exit 2. Bind
  `TARGET_HOST` + `TARGET_REPO` from that one remote URL **before any `gh`
  call**, per `references/github-target.md` (dEitY719/dotfiles#1403).
- `pr-number` — if omitted, auto-detect via `GH_HOST="$TARGET_HOST" gh pr view
  --json number,headRefName,baseRefName,url,mergeable,mergeStateStatus` on the
  current branch. No PR → `[FAIL] no PR for current branch — pass PR#
  explicitly` + exit 2. `--repo` is deliberately omitted **on this one call**:
  `gh` requires an explicit PR argument whenever `--repo` is set (`argument
  required when using the --repo flag`), which would defeat the branch
  detection. The `GH_HOST=` prefix still pins the server and `gh` infers the
  repo from the current checkout's remotes on that host — see
  `references/github-target.md` → "Exception". Every later `gh pr view <N>`
  passes a positional and keeps `--repo "$TARGET_REPO"`.
- `gh` not authenticated → `[FAIL] gh CLI not authenticated — run gh
  auth login` + exit 5.

**Hard preconditions** (any fail → stop):

- inside a git repo
- current branch ≠ repo default (`[FAIL] cannot run on default branch` + exit 2)
- clean working tree (no auto-stash)
- no in-progress rebase / merge / cherry-pick

The default-branch check in full (#10) — the repo is **positional**, and a
failed lookup is itself a refusal:

```bash
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if ! DEFAULT=$(GH_HOST="$TARGET_HOST" gh repo view "$TARGET_REPO" \
        --json defaultBranchRef -q .defaultBranchRef.name) || [ -z "$DEFAULT" ]; then
    echo "[FAIL] could not resolve the default branch of $TARGET_REPO"
    exit 2
fi
if [ "$CURRENT" = "$DEFAULT" ]; then
    echo "[FAIL] cannot run on default branch ($DEFAULT)"
    exit 2
fi
```

`gh repo view` has no `--repo` flag; passing one exits 1 and used to leave
`DEFAULT` empty, so `[ "main" = "" ]` waved the one branch this skill must
never `--force-with-lease` straight through. Same refusal in
`gh-resolve:conflict` and `gh-resolve:ci-fail`; grep `#10` before changing it.
In `--worktree` mode compare the PR's `headRefName` instead of `CURRENT` — the
lookup and its refusal are unchanged.

Capture `BACKUP_SHA=$(git rev-parse HEAD)` and print it for
`git reset --hard <sha>` recovery.

## `--worktree <path>` mode

`gh-pr:merge-train` cannot check the PR's head branch out here: `gh-flow:issue`
opened that PR from its own worktree, which still holds the branch. It passes a
**detached scratch worktree** it created and will destroy instead, and this
skill just operates inside it.

- `pr-number` becomes **mandatory**. Auto-detect is unavailable — a detached
  worktree has no current branch, so `gh pr view` has nothing to resolve a PR
  from. Missing → `[FAIL] --worktree requires an explicit PR number` + exit 2.
- Every git command in this skill runs as `git -C "<path>" ...` — preconditions,
  fetch, rebase, push, status. No `cd`; the session's own checkout is never
  touched, which is half the point of the flag.
- `BACKUP_SHA=$(git -C "<path>" rev-parse HEAD)`.
- **Skip** the clean-working-tree and current-branch-≠-default checks as
  written. A worktree created seconds ago by `git worktree add --detach` is
  clean by construction, and `--abbrev-ref HEAD` answers `HEAD` because it is
  detached — neither check can return anything else. The default-branch
  *refusal* is not dropped, it retargets: compare the PR's `headRefName` (what
  the push refspec writes to) against the repo default and stop on a match.
- Keep the git-repo and no-in-progress-operation checks, scoped with
  `-C "<path>"` — a stale scratch worktree left by an interrupted run can
  still be handed over.
- This skill never creates or removes `<path>`. The caller owns it.
