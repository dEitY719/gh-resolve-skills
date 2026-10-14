#!/usr/bin/env bash
# tests/bats/fixtures/gh_pr_resolve_conflict_review_passed.sh
# Runs the shipped Step 5 drop, skills/conflict/lib/remove-review-passed.sh,
# exactly as skills/conflict/references/verdict-label-removal.sh.md calls it.
# No mirror: the test exercises the file the skill ships.
#
# Usage: resolve_conflict_step5_drop <pr> <repo> <host>
resolve_conflict_step5_drop() {
    bash "$REPO_ROOT/skills/conflict/lib/remove-review-passed.sh" conflict "$@"
}
