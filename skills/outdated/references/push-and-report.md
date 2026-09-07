# Step 4 push shapes and the Step 5 report

Extracted from `SKILL.md` when this skill moved into `gh-resolve-skills`
(dEitY719/dotfiles#1660). Read "Push" before running Step 4 in `--worktree` mode, and
"Report" when printing the Step 5 result.

## Push

Only after `git rebase` exits 0 and the tree is clean:

```bash
git push --force-with-lease "$REMOTE" HEAD
```

In `--worktree` mode, use the explicit refspec instead — a detached HEAD has
no branch for `git` to infer a destination from, and a bare `HEAD` would be
refused:

```bash
git -C "<path>" push --force-with-lease "$REMOTE" HEAD:refs/heads/$HEAD_REF
```

`HEAD_REF` is the `headRefName` Step 2 already read.

Never plain `--force`. Rejected (remote advanced while rebasing) →
`[FAIL] remote advanced — re-fetch and retry` + exit 6. Never silently
re-fetch — surface divergence so the user decides (lost-update risk).

A successful push means the reviewed commit is no longer head, so Step 5 must
invalidate the stale `review-passed` verdict. Record whether the push succeeded.

## Report

```
[OK] PR #<N> out-of-date 해소됨 · <new-sha> push 됨.
Next: /gh-pr:reply <N>  # 리뷰어 회신 또는 CI 결과 대기
```

Then post the ai-metrics PR comment (soft-fail — warn on error, never block).
Caller contract: `PR_NUMBER`, `START_TS`, `TARGET_REPO` and `TARGET_HOST` must
already be exported per Step 1 (`references/github-target.md`,
dEitY719/dotfiles#1403). Run `lib/post-ai-metrics.sh "$PR_NUMBER" "$START_TS"`
(path relative to this skill's base directory) instead of transcribing the
comment body by hand:

```bash
lib/post-ai-metrics.sh "$PR_NUMBER" "$START_TS"
```

Skips entirely under `GH_DISABLE_AI_METRICS=1` (dEitY719/dotfiles#399). Exit 0
always. On failure: `[WARN] ai-metrics comment failed — continuing.`
