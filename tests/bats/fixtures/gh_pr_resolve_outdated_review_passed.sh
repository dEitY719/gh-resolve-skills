#!/usr/bin/env bash
# tests/bats/fixtures/gh_pr_resolve_outdated_review_passed.sh
# Runs the shipped Step 5 drop, skills/outdated/lib/remove-review-passed.sh,
# exactly as skills/outdated/references/verdict-label-removal.sh.md calls it.
# No mirror: the test exercises the file the skill ships.
#
# Usage: resolve_outdated_step5_drop <pr> <repo> <host>
resolve_outdated_step5_drop() {
    bash "$REPO_ROOT/skills/outdated/lib/remove-review-passed.sh" outdated "$@"
}
