# Step 5 — ai-metrics PR comment (soft-fail)

After the report, post a PR comment with ai-metrics (soft-fail — warn on
error, never block). `CONFLICT_FILES` is the count of files that had
`UU`/`AA`/`DU` conflicts in Step 3. When `GH_DISABLE_AI_METRICS=1`,
skip the comment entirely (issue dEitY719/dotfiles#399).

Caller contract: `START_TS`, `PR_NUMBER`, `CONFLICT_FILES`, `TARGET_REPO` and
`TARGET_HOST` must already be exported by Step 1 per
`references/github-target.md` (dEitY719/dotfiles#1403).

The dotfiles original used the emoji footer glyphs here. This repo forbids
emojis anywhere in tracked text (CI enforces it), so the summary line carries
the same three numbers in the plain-text form `gh-resolve:ci-fail` already
uses. Only the rendering changed; the marker pair and the values are the same.

```bash
ELAPSED=$(( ($(date +%s) - START_TS) / 60 ))
HUMAN_H=$(awk -v cf="$CONFLICT_FILES" 'BEGIN { printf "%.2f", cf * 0.5 }')
if [ "${GH_DISABLE_AI_METRICS:-0}" = "1" ]; then
    : # ai-metrics comment skipped via GH_DISABLE_AI_METRICS
else
    GH_HOST="$TARGET_HOST" gh api "repos/$TARGET_REPO/issues/$PR_NUMBER/comments" \
      -X POST \
      -f body="---
<details>
<summary>AI Metrics · tokens=~${TOKENS:-3000} · human_h=~$HUMAN_H · ai_min=~$ELAPSED</summary>

<!-- ai-metrics:gh-resolve-conflict -->
AI Metrics tokens=~${TOKENS:-3000} human_h=~$HUMAN_H ai_min=~$ELAPSED
<!-- /ai-metrics:gh-resolve-conflict -->

</details>
컨플릭트 해결: ~$ELAPSED min · 사람: ~$HUMAN_H h ($CONFLICT_FILES files × 0.5 h)"
fi
```

On failure: `[WARN] ai-metrics comment failed — continuing.`
