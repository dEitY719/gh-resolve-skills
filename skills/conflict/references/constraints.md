# gh-resolve:conflict — Constraints

Extracted from `SKILL.md` when this skill moved into `gh-resolve-skills`
(dEitY719/dotfiles#1660). The list is unchanged; only its location moved. Read it
before Step 2 and before every push.

- Never introduce a merge commit. Rebase-only.
- Never use plain `git push --force`. `--force-with-lease` or stop.
- Never rebase onto the default branch from the default branch.
- Never auto-resolve ambiguous conflicts. Ask the user.
- Never retry a rejected `--force-with-lease` by fetching and re-rebasing on the user's behalf. Surface divergence and stop.
- Never skip Step 5. The whole point is clearing the PR warning.
- Never add `review-passed` / `review-blocked`, and never remove
  `review-blocked` — this skill has no evidence the blockers were addressed
  (dEitY719/dotfiles#1563). Removing `review-passed` after a successful push is mandatory.
- Never create or remove the `--worktree` path. The caller owns its lifecycle.
