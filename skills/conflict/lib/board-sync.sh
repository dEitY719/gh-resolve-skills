#!/usr/bin/env sh
# gh-resolve:conflict — SKILL.md Step 5: return the PR's board card to
# `In review` after a clean rebase. Caller gates this on
# `mergeable == MERGEABLE` (references/board-sync.md) — this script does not
# re-check it. Lifecycle rationale: dEitY719/dotfiles#591.
#
# Usage: board-sync.sh "$PR_NUMBER" "$TARGET_REPO"
#        board-sync.sh --self-test   (fixture check, no real `gh`/network)
# Requires TARGET_HOST already exported as GH_HOST by SKILL.md Step 1
# (references/github-target.md, dEitY719/dotfiles#1403) — the sourced helper
# inherits it for its own `gh` calls.
#
# Helper lookup, two tiers (dEitY719/dotfiles#724, PR #8 review):
#   1. ${SHELL_COMMON:-$HOME/dotfiles/shell-common}/functions/gh_project_status.sh
#   2. ${CLAUDE_PLUGIN_ROOT}/lib/vendor/shell-common/functions/gh_project_status.sh
#      (only when CLAUDE_PLUGIN_ROOT is non-empty — Claude-Code-only var;
#      other harnesses must export it themselves to reach the vendor copy)
# Neither resolves, or the file sourced but `_gh_project_status_sync` is
# still undefined (partial-source regression) → [WARN], never a silent no-op.
#
# Exit 0 always (soft-fail): prints [OK]/[WARN].
set -eu

if [ "${1:-}" = "--self-test" ]; then
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    # Case 1: no dotfiles checkout, no CLAUDE_PLUGIN_ROOT -> unavailable warning.
    OUT=$(HOME="$TMP/empty" SHELL_COMMON='' CLAUDE_PLUGIN_ROOT='' sh "$0" 1 owner/repo)
    case "$OUT" in
        "[WARN] board sync helper unavailable"*) ;;
        *) echo "FAIL: case1 expected unavailable warning, got: $OUT" >&2; exit 1 ;;
    esac

    # Case 2: tier-2 vendor copy present and functional -> [OK].
    mkdir -p "$TMP/plugin/lib/vendor/shell-common/functions"
    cat > "$TMP/plugin/lib/vendor/shell-common/functions/gh_project_status.sh" <<'EOF'
_gh_project_status_sync() { return 0; }
EOF
    OUT=$(HOME="$TMP/empty" SHELL_COMMON='' CLAUDE_PLUGIN_ROOT="$TMP/plugin" sh "$0" 1 owner/repo)
    case "$OUT" in
        "[OK] PR 카드"*) ;;
        *) echo "FAIL: case2 expected OK on tier-2 hit, got: $OUT" >&2; exit 1 ;;
    esac

    # Case 3: helper sourced but function undefined (partial-source regression) -> [WARN].
    cat > "$TMP/plugin/lib/vendor/shell-common/functions/gh_project_status.sh" <<'EOF'
# intentionally does not define _gh_project_status_sync
EOF
    OUT=$(HOME="$TMP/empty" SHELL_COMMON='' CLAUDE_PLUGIN_ROOT="$TMP/plugin" sh "$0" 1 owner/repo 2>/dev/null)
    case "$OUT" in
        "[WARN] 보드 sync 실패"*) ;;
        *) echo "FAIL: case3 expected WARN on undefined function, got: $OUT" >&2; exit 1 ;;
    esac

    echo "[OK] board-sync.sh --self-test: all three resolution paths pass"
    exit 0
fi

PR_NUMBER=${1:?PR number required}
TARGET_REPO=${2:?TARGET_REPO required}

_HELPER="${SHELL_COMMON:-$HOME/dotfiles/shell-common}/functions/gh_project_status.sh"
if [ ! -f "$_HELPER" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    _HELPER="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common/functions/gh_project_status.sh"
    export SHELL_COMMON="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"
fi

if [ -r "$_HELPER" ]; then
    . "$_HELPER"
    if ! command -v _gh_project_status_sync >/dev/null 2>&1; then
        printf '[gh-resolve:conflict] %s sourced but _gh_project_status_sync undefined — board sync skipped (dEitY719/dotfiles#724).\n' \
            "$_HELPER" >&2
        echo "[WARN] 보드 sync 실패 — 카드 수동 이동 필요할 수 있음"
    elif _gh_project_status_sync pr "$PR_NUMBER" "In review" \
            --only-from "In progress,Changes requested" \
            --repo "$TARGET_REPO"; then
        echo "[OK] PR 카드 \`In review\` 로 복귀됨"
    else
        echo "[WARN] 보드 sync 실패 — 카드 수동 이동 필요할 수 있음"
    fi
else
    echo "[WARN] board sync helper unavailable — card not moved"
fi
