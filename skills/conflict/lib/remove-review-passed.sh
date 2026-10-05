#!/usr/bin/env bash
# gh-resolve:{conflict,outdated} — Step 5: drop the stale `review-passed`
# label after a SUCCESSFUL `git push --force-with-lease`. The caller gates on
# the push; this script does not re-check it. Rationale (dEitY719/dotfiles#1563,
# #1529): references/verdict-label-removal.sh.md of the calling skill.
#
# Usage: remove-review-passed.sh <conflict|outdated> "$PR_NUMBER" "$TARGET_REPO" "$TARGET_HOST"
#        remove-review-passed.sh --self-test   (fixture check, no real `gh`)
#
# Byte-identical copies live in skills/conflict/lib/ and skills/outdated/lib/;
# tests/review-passed-lib-sync.sh fails the build when they drift.
#
# Only ever removes `review-passed`. Never touches `review-blocked`, never
# adds any verdict label — `gh-verify:review-all` owns those.
#
# Exit 0 always (soft-fail). One result line: [OK] on removal or when the
# label was verifiably absent, [WARN] when the removal failed. A missing
# shell-common prints its tier-5 message to stderr and also exits 0.

if [ "${1:-}" = "--self-test" ]; then
    _self=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    cat > "$TMP/gh" <<'EOF'
#!/usr/bin/env sh
echo "$*" >> "$MOCK_GH_LOG"
case "$*" in
    *"-X DELETE"*) exit "${MOCK_DELETE_RC:-0}" ;;
esac
[ "${MOCK_GET_RC:-0}" -eq 0 ] || exit "$MOCK_GET_RC"
printf '%s\n' "${MOCK_LABELS:-}"
EOF
    chmod +x "$TMP/gh"
    _vendor="$(dirname -- "$_self")/../../../lib/vendor/shell-common"

    _run() { # <case> <expected prefix> ; env MOCK_* set by caller
        : > "$TMP/log"
        OUT=$(MOCK_GH_LOG="$TMP/log" SHELL_COMMON="$_vendor" PATH="$TMP:$PATH" \
            bash "$_self" outdated 1 owner/repo github.com 2>/dev/null)
        RC=$?
        case "$OUT" in
            "$2"*) ;;
            *) echo "FAIL ($1): expected $2, got: $OUT" >&2; exit 1 ;;
        esac
        [ "$RC" -eq 0 ] || { echo "FAIL ($1): exit $RC, expected 0" >&2; exit 1; }
        grep -q "DELETE repos/owner/repo/issues/1/labels/review-passed" "$TMP/log" ||
            { echo "FAIL ($1): no DELETE of review-passed issued" >&2; exit 1; }
        ! grep -q "review-blocked" "$TMP/log" ||
            { echo "FAIL ($1): touched review-blocked" >&2; exit 1; }
    }

    MOCK_DELETE_RC=0 _run "label present" "[OK]"
    MOCK_DELETE_RC=1 MOCK_GET_RC=0 MOCK_LABELS=bug _run "label absent" "[OK]"
    MOCK_DELETE_RC=1 MOCK_GET_RC=1 _run "gh failure" "[WARN]"

    echo "[OK] remove-review-passed.sh --self-test: present/absent/failure branches print correctly"
    exit 0
fi

SKILL="${1:-}"
PR_NUMBER="${2:-}"
TARGET_REPO="${3:-}"
TARGET_HOST="${4:-}"

# Helper lookup: tier 1 SHELL_COMMON/dotfiles -> tier 2 CLAUDE_PLUGIN_ROOT ->
# tier 5 stop. No $PWD tier: this runs inside the PR checkout under review
# (dEitY719/harness-skills#22).
_SC="${SHELL_COMMON:-$HOME/dotfiles/shell-common}"                                   # tier 1
if [ ! -f "$_SC/functions/gh_pr_edit_safe.sh" ]; then
    [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || {                                            # tier 5
        printf '[gh-resolve:%s] no shell-common under %s, and CLAUDE_PLUGIN_ROOT is unset. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
            "$SKILL" "$_SC" >&2
        exit 0
    }
    _SC="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"                                # tier 2
fi
unset -f _gh_pr_drop_label 2>/dev/null || :
# shellcheck source=/dev/null
[ -f "$_SC/functions/gh_pr_edit_safe.sh" ] && . "$_SC/functions/gh_pr_edit_safe.sh"
command -v _gh_pr_drop_label >/dev/null 2>&1 || {                                    # tier 5
    printf '[gh-resolve:%s] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$SKILL" "$_SC" >&2
    exit 0
}
export SHELL_COMMON="$_SC"

if _vl_err=$(_gh_pr_drop_label "$PR_NUMBER" review-passed \
        "$TARGET_REPO" "$TARGET_HOST" 2>&1); then
    echo "[OK] \`review-passed\` 무효화됨 — force-push 로 head 가 바뀌어 이전 판정은 만료"
else
    echo "[WARN] \`review-passed\` 제거 실패 — 리뷰되지 않은 커밋에 판정이 남아 있다: ${_vl_err}"
fi
exit 0
