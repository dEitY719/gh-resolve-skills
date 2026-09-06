#!/usr/bin/env sh
# gh-resolve:conflict — SKILL.md Step 5: remove the stale `conflict` label
# after a clean rebase. Caller gates this on `mergeable == MERGEABLE`
# (references/label-removal.md) — this script does not re-check it.
#
# Usage: remove-conflict-label.sh "$PR_NUMBER" "$TARGET_REPO" "$TARGET_HOST"
#        remove-conflict-label.sh --self-test   (fixture check, no real `gh`)
#
# Uses REST DELETE, not `gh pr edit --remove-label` — the latter can
# silent-fail on repos with classic Projects attached due to GraphQL
# deprecation (dEitY719/dotfiles#326 Bug B). A 404 (label already absent) is
# absorbed as a soft-fail [OK], idempotent for the caller. `gh api` takes no
# `--repo` flag (dEitY719/dotfiles#658) — repo goes in the path.
# `GH_HOST="$TARGET_HOST"` pins the server so dual-host logins can't silently
# hit the wrong one (dEitY719/dotfiles#1403 / #1407).
#
# Exit 0 always (soft-fail): prints [OK] on removal/404, [WARN] otherwise.
set -eu

if [ "${1:-}" = "--self-test" ]; then
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    cat > "$TMP/gh" <<'EOF'
#!/usr/bin/env sh
exit "${MOCK_GH_EXIT:-0}"
EOF
    chmod +x "$TMP/gh"

    OUT=$(MOCK_GH_EXIT=0 PATH="$TMP:$PATH" sh "$0" 1 owner/repo github.com)
    case "$OUT" in
        "[OK]"*) ;;
        *) echo "FAIL: expected [OK] on gh success, got: $OUT" >&2; exit 1 ;;
    esac

    OUT=$(MOCK_GH_EXIT=1 PATH="$TMP:$PATH" sh "$0" 1 owner/repo github.com)
    case "$OUT" in
        "[WARN]"*) ;;
        *) echo "FAIL: expected [WARN] on gh failure, got: $OUT" >&2; exit 1 ;;
    esac

    echo "[OK] remove-conflict-label.sh --self-test: both branches print correctly"
    exit 0
fi

PR_NUMBER=${1:?PR number required}
TARGET_REPO=${2:?TARGET_REPO required}
TARGET_HOST=${3:?TARGET_HOST required}

GH_HOST="$TARGET_HOST" gh api -X DELETE \
    "repos/$TARGET_REPO/issues/$PR_NUMBER/labels/conflict" \
    >/dev/null 2>&1 \
  && echo "[OK] \`conflict\` 라벨 제거됨" \
  || echo "[WARN] \`conflict\` 라벨 제거 실패 — GitHub Actions 가 cover."
