#!/usr/bin/env bats
# tests/bats/gh_pr_resolve_outdated_review_passed.bats
# outdated Step 5: after a successful --force-with-lease push, drop the stale
# `review-passed` label (dEitY719/dotfiles#1563). Runs the shipped
# skills/outdated/lib/remove-review-passed.sh through
# fixtures/gh_pr_resolve_outdated_review_passed.sh, against a PATH `gh` stub.
#
# Moved from dEitY719/dotfiles tests/bats/skills/ (dEitY719/dotfiles#2200).
# The dotfiles suite tested a patch-id "keep" reconcile
# (_gh_pr_resolve_outdated_reconcile_review_passed, dotfiles #1698/#1700/#1704).
# The shipped skill never adopted it: it drops unconditionally. Those reconcile
# tests stay in dotfiles next to that helper; this file pins the shipped drop.

load 'test_helper'

setup() {
    setup_isolated_home
    # shellcheck source=fixtures/review_passed_gh_stub.sh
    source "$REPO_ROOT/tests/bats/fixtures/review_passed_gh_stub.sh"
    _review_passed_gh_stub_install
    # shellcheck source=fixtures/gh_pr_resolve_outdated_review_passed.sh
    source "$REPO_ROOT/tests/bats/fixtures/gh_pr_resolve_outdated_review_passed.sh"
}

teardown() {
    teardown_isolated_home
}

@test "outdated Step 5: drops review-passed, pinned to the target host" {
    run resolve_outdated_step5_drop 99 acme/widget ghe.example.com
    assert_success
    assert_output --partial '[OK] `review-passed` 무효화됨'
    run cat "$GH_LOG"
    assert_output --partial 'api -X DELETE repos/acme/widget/issues/99/labels/review-passed [GH_HOST=ghe.example.com]'
}

@test "outdated Step 5: an absent label is OK, and review-blocked is never touched" {
    STUB_MODE=absent_blocked
    export STUB_MODE
    run resolve_outdated_step5_drop 99 acme/widget github.com
    assert_success
    assert_output --partial '[OK]'
    run cat "$GH_LOG"
    refute_output --partial 'labels/review-blocked'
    refute_output --partial 'add-label'
    refute_output --partial 'POST'
}

@test "outdated Step 5: a genuine delete failure warns and still exits 0" {
    STUB_MODE=fail
    export STUB_MODE
    run resolve_outdated_step5_drop 99 acme/widget github.com
    assert_success
    assert_output --partial '[WARN] `review-passed` 제거 실패'
}

@test "outdated Step 5: no shell-common and no CLAUDE_PLUGIN_ROOT stops at tier 5 with exit 0" {
    SHELL_COMMON="$BATS_TEST_TMPDIR/nowhere"
    export SHELL_COMMON
    run resolve_outdated_step5_drop 99 acme/widget github.com
    assert_success
    assert_output --partial '[gh-resolve:outdated] no shell-common'
    run cat "$GH_LOG"
    assert_output ''
}

@test "outdated Step 5: the reference doc calls the shipped lib with this skill's name" {
    run grep -qF 'lib/remove-review-passed.sh outdated "$PR_NUMBER" "$TARGET_REPO" "$TARGET_HOST"' \
        "$REPO_ROOT/skills/outdated/references/verdict-label-removal.sh.md"
    assert_success
}
