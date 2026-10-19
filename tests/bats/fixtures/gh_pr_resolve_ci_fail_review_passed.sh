#!/usr/bin/env bash
# tests/bats/fixtures/gh_pr_resolve_ci_fail_review_passed.sh
# ci-fail Steps 5-7 label handling.
#
# Step 7 (`CI fail` label DELETE): fence-extracted at test time from
#   skills/ci-fail/references/safety.md -> "## Step 7 label removal", first
#   ```bash block. The test runs the shipped text, not a copy.
#
# Step 5 `review-passed` drop: runs the shipped
#   skills/ci-fail/lib/remove-review-passed.sh (dEitY719/gh-resolve-skills#32;
#   dotfiles #1705, timing #1711: right after the push, before Step 6 `--wait`).

_CI_FAIL_SAFETY_MD="$REPO_ROOT/skills/ci-fail/references/safety.md"
_CI_FAIL_STEP7_BLOCK=$(awk '
    /^## Step 7 label removal/ { sec = 1; next }
    sec && /^```bash$/ { inb = 1; next }
    inb && /^```$/ { exit }
    inb { print }
' "$_CI_FAIL_SAFETY_MD")

# Usage: resolve_ci_fail_step5_drop_review_passed <pr> <repo> <host>
resolve_ci_fail_step5_drop_review_passed() {
    bash "$REPO_ROOT/skills/ci-fail/lib/remove-review-passed.sh" ci-fail "$@"
}

# Step 7 — runs the shipped safety.md block, then SKILL.md's report line.
# Never touches review-passed (that already ran in Step 5).
#
# Usage: resolve_ci_fail_step7 <pr> <repo> <host>
resolve_ci_fail_step7() {
    # shellcheck disable=SC2034  # read by the eval-ed safety.md block
    local PR_NUMBER="$1" TARGET_REPO="$2" TARGET_HOST="$3"
    [ -n "$_CI_FAIL_STEP7_BLOCK" ] || { echo "Step 7 block not found in $_CI_FAIL_SAFETY_MD" >&2; return 1; }
    eval "$_CI_FAIL_STEP7_BLOCK"
    printf '[OK] PR #%s CI 복구 완료\n' "$PR_NUMBER"
    return 0
}

# Full flow in the skill's order: the Step 5 push already happened (caller's
# job), then the review-passed drop, Step 6 (--wait, a no-op here), Step 7.
#
# Usage: resolve_ci_fail_step5_through_7 <pr> <repo> <host>
resolve_ci_fail_step5_through_7() {
    resolve_ci_fail_step5_drop_review_passed "$@"
    resolve_ci_fail_step7 "$@"
}
