# Step 5 — `conflict` 라벨 제거 (soft-fail)

Applies **only when `mergeable == MERGEABLE`**.

Caller contract: `PR_NUMBER`, `TARGET_REPO`, `TARGET_HOST` 는 Step 1 이
`references/github-target.md` 대로 이미 export 한 상태여야 한다 (dEitY719/dotfiles#1403).

Run `lib/remove-conflict-label.sh "$PR_NUMBER" "$TARGET_REPO" "$TARGET_HOST"`
(path relative to this skill's base directory) instead of transcribing the
REST DELETE by hand:

```bash
bash lib/remove-conflict-label.sh "$PR_NUMBER" "$TARGET_REPO" "$TARGET_HOST"
```

Exit 0 always (soft-fail); prints `[OK]` on removal, `[WARN]` if the DELETE
call itself failed. A 404 (label already absent) is absorbed into the `[OK]`
branch — idempotent for the caller. See the script header for why it uses
REST DELETE instead of `gh pr edit --remove-label` (the latter can
silent-fail on repos with classic Projects attached, dEitY719/dotfiles#326 Bug B).
