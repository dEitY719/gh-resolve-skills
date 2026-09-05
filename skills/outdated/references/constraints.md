# gh-resolve:outdated — Constraints

Extracted from `SKILL.md` when this skill moved into `gh-resolve-skills`
(dEitY719/dotfiles#1660). The list is unchanged; only its location moved. Read it
before Step 3 and before the push in Step 4.

- Rebase-only. Never a merge commit.
- `--force-with-lease` only — never plain `--force`.
- Never run on the repo's default branch.
- Never auto-resolve conflicts — delegate to `gh-resolve:conflict` (exit 4).
- Never retry a rejected `--force-with-lease`; never auto-stash (clean tree required).
- Never add `review-passed` / `review-blocked`, and never remove
  `review-blocked` (dEitY719/dotfiles#1563). Removing `review-passed` after a successful push
  is mandatory — a stale verdict on an unreviewed head is the bug this fixes.
- Never create or remove the `--worktree` path. The caller owns its lifecycle.
