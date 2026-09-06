# Step 5 — ai-metrics PR comment (soft-fail)

After the report, post a PR comment with ai-metrics (soft-fail — warn on
error, never block). `CONFLICT_FILES` is the count of files that had
`UU`/`AA`/`DU` conflicts in Step 3.

Caller contract: `START_TS`, `PR_NUMBER`, `CONFLICT_FILES`, `TARGET_REPO` and
`TARGET_HOST` must already be exported by Step 1 per
`references/github-target.md` (dEitY719/dotfiles#1403).

Run `lib/post-ai-metrics.sh "$PR_NUMBER" "$START_TS" "$CONFLICT_FILES"` (path
relative to this skill's base directory) instead of transcribing the comment
body by hand:

```bash
bash lib/post-ai-metrics.sh "$PR_NUMBER" "$START_TS" "$CONFLICT_FILES"
```

Skips entirely under `GH_DISABLE_AI_METRICS=1` (issue dEitY719/dotfiles#399). Exit 0
always. On failure: `[WARN] ai-metrics comment failed — continuing.`

The dotfiles original used emoji footer glyphs; this repo forbids emojis
anywhere in tracked text (CI enforces it), so the summary line carries the
same three numbers in the plain-text form `gh-resolve:ci-fail` already uses.
Only the rendering changed — the marker pair and the values are the same.
