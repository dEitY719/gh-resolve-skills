# Step 5 — post-verify helper policy

Extracted from `SKILL.md` when this skill moved into `gh-resolve-skills`
(dEitY719/dotfiles#1660). Read it after the Step 5 `gh pr view` verification, before
touching any label or board card.

Each helper **soft-fails**: a failure prints a `[WARN]` and the run continues.
The first three apply only when `mergeable == MERGEABLE`.

- Remove the `conflict` label per `references/label-removal.md`.
- Return the board status to `In review` per `references/board-sync.md`.
- Post the ai-metrics PR comment per `references/ai-metrics-comment.md` (soft-fail; skip when `GH_DISABLE_AI_METRICS=1`).
- Drop the `review-passed` label per `references/verdict-label-removal.sh.md`.
  **Different gate**: this one keys off Step 4's push, not `mergeable` — a
  force-push replaced the reviewed commit, so the stale verdict must go even
  if the PR still reads `CONFLICTING`. Skip it entirely when the push was
  rejected or never ran. Never touch `review-blocked` here (dEitY719/dotfiles#1563).
