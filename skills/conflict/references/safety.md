# gh-resolve:conflict — Safety Nets

## Backup SHA

Always captured before `git rebase`:

```bash
BACKUP_SHA=$(git rev-parse HEAD)
```

Printed up front so the user can paste it into a recovery command:

```
backup SHA: <sha>
  undo everything :  git reset --hard <sha>
  inspect history :  git reflog
```

`git reflog` is always a fallback — every rebase step is tracked there
for ~90 days by default, so even `reset --hard` mistakes are usually
recoverable.

## Auto-stash

Triggered only when preflight detects a non-empty working tree
(`git status --porcelain` prints any line). In `--worktree` mode that trigger
can never fire *for a freshly created scratch worktree this round* — the
caller (`gh:pr-merge-train`) just ran `git worktree add`, and nothing has
written to it yet — so the whole stash flow is skipped, and the final
report's `Stash:` line is omitted. This is distinct from a worktree the
caller is *reusing* after an interrupted prior round (a crashed process, or
one this skill itself left conflicted at a stop point below) — that tree can
absolutely be dirty or mid-rebase, which is exactly what the in-progress
operation guard right below exists to catch. "Clean by construction" is a
claim about the fresh-add case only, never about an arbitrary `<path>`.

1. Announce before running:

    ```
    Working tree is dirty. Auto-stashing:
      git stash push -u -m "gh-resolve:conflict auto-stash <timestamp>"
    ```

2. Stash:

    ```bash
    STASH_MSG="gh-resolve:conflict auto-stash $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    git stash push -u -m "$STASH_MSG"
    STASH_REF=$(git rev-parse -q --verify refs/stash)
    ```

3. Proceed with fetch + rebase.

4. After a successful push (or on clean abort), pop:

    ```bash
    git stash pop "$STASH_REF" 2>/dev/null || \
      echo "stash preserved — resolve and then: git stash pop $STASH_REF"
    ```

5. If `pop` itself conflicts, stop and print the stash ref. Never drop
   the stash automatically.

## In-progress operation guard

Always resolve marker paths through `git rev-parse --git-path`. In a git
worktree the actual paths are under `.git/worktrees/<wt>/`, and hardcoded
`.git/<name>` checks silently miss the marker.

In `--worktree` mode this guard still runs — a scratch worktree abandoned
mid-rebase by an interrupted run is exactly what it catches — with every `git`
below taking `-C "<path>"`.

```bash
for name in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
    marker=$(git rev-parse --git-path "$name")
    if [ -e "$marker" ]; then
        echo "in-progress operation detected: $marker"
        echo "finish or abort it first:"
        echo "  git rebase --continue / --abort"
        echo "  git merge --continue / --abort"
        echo "  git cherry-pick --continue / --abort"
        exit 1
    fi
done
```

## `--force-with-lease` vs `--force`

`--force-with-lease` refuses the push if the remote ref has moved since
you last fetched. That protects against:

- a reviewer pushing a fix directly to your branch while you rebased,
- an automation bot (dependabot, renovate) rebasing on top of you,
- another machine of yours pushing from the same branch.

Plain `--force` blows past all of that. This skill refuses to use it.

If `--force-with-lease` rejects the push, the upstream moved. Show:

```
Push rejected by --force-with-lease: upstream has new commits you haven't seen.
  git fetch <remote>
  git log --oneline HEAD..<remote>/<branch>
Decide whether to merge those in or discard them, then re-run this skill.
```

## Never run on the default branch

This block is the SSOT for the refusal. `gh-resolve:ci-fail` and
`gh-resolve:outdated` state the same precondition and resolve `DEFAULT` the
same way; if this call ever changes, change it there too.

```bash
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if ! DEFAULT=$(GH_HOST="$TARGET_HOST" gh repo view "$TARGET_REPO" \
        --json defaultBranchRef -q .defaultBranchRef.name) || [ -z "$DEFAULT" ]; then
    echo "refuse: could not resolve the default branch of $TARGET_REPO."
    echo "the guard fails closed — fix the gh call or the Step 1 target binding."
    exit 1
fi
if [ "$CURRENT" = "$DEFAULT" ]; then
    echo "refuse: currently on the default branch ($DEFAULT)."
    echo "check out the PR's head branch first."
    exit 1
fi
```

**`$TARGET_REPO` is positional here, not `--repo` (#10).** `gh repo view` is the
one sub-command in this skill that takes the repository as an argument and has
no `--repo` flag — `--repo "$TARGET_REPO"`, copied from the neighbouring
`gh pr view` calls, exits 1 with `unknown flag: --repo` on every invocation.
`references/github-target.md` names it alongside `gh api` as an exception to the
flag rule; read that before adding another `gh` call to this skill.

**The first `if` is the fix; do not reduce it to an emptiness test (#10).**
Before it existed the guard could not fire in the one case it exists for: the
failed lookup left `DEFAULT` empty, `[ "main" = "" ]` was false, and the run
continued to Step 4's `git push --force-with-lease "$REMOTE" HEAD` —
force-pushing the default branch with a perfectly satisfied lease. Any failure
of the lookup, for any reason, must stop the run rather than fall through.

`! DEFAULT=$(...)` is the **exit status**; `[ -z "$DEFAULT" ]` is the string.
Both are needed, and the status is the load-bearing half. An emptiness test
alone happens to work for `gh repo view`, which writes its error to stderr and
leaves stdout empty, but it fails open for a command that prints on failure —
`gh api`, the tempting alternative here, skips `--jq` on an HTTP error and
echoes the raw response body to **stdout**, so
`DEFAULT=$(gh api "repos/$TARGET_REPO" --jq .default_branch)` on a 404 is
`{"message":"Not Found",...}`: non-empty, never equal to any branch name, and
straight through. Leaning on what a command happens to leave on stdout when it
fails is the same class of assumption that made this guard inert.

Write the status check in the `if` rather than as a trailing `|| DEFAULT=""`.
Both are correct — the `||` form consumes the status exactly the same way — but
two independent reviewers read the trailing form as *discarding* the status
(PR #11), and a safety guard that reads as unsafe gets "corrected" back into a
hole. The explicit form cannot be misread.

The default branch should never be force-pushed by this skill. If the
PR's head IS the default branch (cross-fork PR where the head came from
a fork), that's out of scope — tell the user and stop.

In `--worktree` mode `git -C "<path>" rev-parse --abbrev-ref HEAD` answers
`HEAD` — the worktree is detached and has no branch to compare. The guard is
not dropped, it moves to the thing that is actually at risk: substitute
`HEAD_REF` (the PR's `headRefName`, which the push refspec targets) for
`CURRENT` and refuse on a match. Only the compared value changes — the
`DEFAULT` lookup and its unresolved-refusal `if` run unchanged, so a failed
lookup stops the worktree path too.

## Recovery cheat-sheet (for the final report)

```
If something went wrong:
  git rebase --abort                 # during rebase
  git reset --hard <BACKUP_SHA>      # after rebase, before push
  git reflog                          # rummage for any lost ref
  git stash list                      # auto-stash survives even if pop fails
```
