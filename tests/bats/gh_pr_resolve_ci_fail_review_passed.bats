#!/usr/bin/env bats
# tests/bats/gh_pr_resolve_ci_fail_review_passed.bats
# ci-fail drops a stale `review-passed` right after the Step 5 push (dotfiles
# #1705, timing #1711), then removes `CI fail` in Step 7.
# Fixture: fixtures/gh_pr_resolve_ci_fail_review_passed.sh. Step 7 runs the
# shipped skills/ci-fail/references/safety.md block; the Step 5 drop runs the
# shipped skills/ci-fail/lib/remove-review-passed.sh (dEitY719/gh-resolve-skills#32).
#
# Smaller than the rebase skills' suites: a CI fix changes file content by
# definition, so there is no keep path, only an unconditional drop. The
# primitive's own semantics (404 verification, percent-encoding) belong to the
# vendored gh_pr_edit_safe.sh; this file pins that the skill reaches it with
# the right label, before Step 7, and never widens to `review-blocked`.
#
# Moved from dEitY719/dotfiles tests/bats/skills/ (dEitY719/dotfiles#2200).

load 'test_helper'

setup() {
    setup_isolated_home
    # shellcheck source=fixtures/review_passed_gh_stub.sh
    source "$REPO_ROOT/tests/bats/fixtures/review_passed_gh_stub.sh"
    _review_passed_gh_stub_install
    # shellcheck source=fixtures/gh_pr_resolve_ci_fail_review_passed.sh
    source "$REPO_ROOT/tests/bats/fixtures/gh_pr_resolve_ci_fail_review_passed.sh"
}

teardown() {
    teardown_isolated_home
}

@test "#1705: a successful CI-fix push drops review-passed from that PR" {
    run resolve_ci_fail_step5_drop_review_passed 99 acme/widget github.com
    assert_success
    run cat "$GH_LOG"
    assert_output --partial 'api -X DELETE repos/acme/widget/issues/99/labels/review-passed'
}

@test "#1705: the drop reports one line" {
    run resolve_ci_fail_step5_drop_review_passed 99 acme/widget github.com
    assert_output --partial '[OK] `review-passed` 라벨 제거됨'
    assert_output --partial 'CI 수정 커밋으로 head 가 바뀌어 이전 판정 무효화'
}

@test "#1705: the drop is pinned to the target host (#1403 / #1407)" {
    resolve_ci_fail_step5_drop_review_passed 99 acme/widget ghe.example.com
    run cat "$GH_LOG"
    assert_output --partial 'labels/review-passed [GH_HOST=ghe.example.com]'
}

@test "#1711: the review-passed drop precedes the CI-fail label removal in the call log" {
    run resolve_ci_fail_step5_through_7 99 acme/widget github.com
    assert_success
    local _rp_line _ci_line
    _rp_line=$(grep -n 'labels/review-passed' "$GH_LOG" | head -1 | cut -d: -f1)
    _ci_line=$(grep -n 'labels/CI%20fail' "$GH_LOG" | head -1 | cut -d: -f1)
    [ -n "$_rp_line" ]
    [ -n "$_ci_line" ]
    [ "$_rp_line" -lt "$_ci_line" ]
}

@test "Step 7: the shipped safety.md block deletes CI fail on the target host" {
    run resolve_ci_fail_step7 99 acme/widget ghe.example.com
    assert_success
    assert_output --partial '[OK] `CI fail` 라벨 제거됨'
    run cat "$GH_LOG"
    assert_output --partial 'api -X DELETE repos/acme/widget/issues/99/labels/CI%20fail [GH_HOST=ghe.example.com]'
    refute_output --partial 'review-passed'
}

@test "#1563: review-blocked is never touched, even when attached to the same PR" {
    STUB_MODE=absent_blocked
    export STUB_MODE
    run resolve_ci_fail_step5_through_7 99 acme/widget github.com
    assert_success
    run cat "$GH_LOG"
    # The skill saw the label in the list...
    assert_output --partial 'api repos/acme/widget/issues/99/labels'
    # ...and still issued no DELETE, POST, or `pr edit` against it.
    refute_output --partial 'labels/review-blocked'
    refute_output --partial 'add-label'
    refute_output --partial 'remove-label'
}

@test "soft-fail: a PR that never earned the label warns about nothing" {
    STUB_MODE=absent_blocked
    export STUB_MODE
    run resolve_ci_fail_step5_through_7 99 acme/widget github.com
    assert_success
    refute_output --partial '[WARN] `review-passed`'
    assert_output --partial '[OK] PR #99 CI 복구 완료'
}

@test "soft-fail: a genuine delete failure warns but the CI-fix report still prints" {
    STUB_MODE=fail
    export STUB_MODE
    run resolve_ci_fail_step5_through_7 99 acme/widget github.com
    assert_success
    assert_output --partial '[WARN] `review-passed` 제거 실패'
    assert_output --partial '[OK] PR #99 CI 복구 완료'
}

@test "doc-guard: the vendored #1563 SSOT lists gh:pr-resolve-ci-fail as a consumer" {
    run grep -qE 'gh:pr-resolve-ci-fail +Step 5' \
        "$REPO_ROOT/lib/vendor/shell-common/lib/gh_pr_edit_safe.sh"
    assert_success
}

@test "drift: the shipped ci-fail skill drops review-passed in Step 5" {
    local _call='lib/remove-review-passed.sh ci-fail "$PR_NUMBER" "$TARGET_REPO" "$TARGET_HOST"'
    run grep -qF "$_call" "$REPO_ROOT/skills/ci-fail/SKILL.md"
    assert_success
    run grep -qF "$_call" "$REPO_ROOT/skills/ci-fail/references/safety.md"
    assert_success
}
