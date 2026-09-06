#!/usr/bin/env sh
# gh-resolve:ci-fail — SKILL.md Step 6: poll `gh pr checks --required` every
# 30s until every required check settles, or timeout.
#
# Usage: wait-for-green.sh "$PR_NUMBER" "$WAIT_SECONDS"
#        wait-for-green.sh --self-test   (fixture check, no `gh` call)
# Requires TARGET_REPO / TARGET_HOST already exported by SKILL.md Step 1
# (references/github-target.md, #1403).
#
# Exit 0: every required check reached a known-good state (anything other
#         than the pending/failed sets below) within the timeout.
# Exit 1: a required check reached a known-bad terminal state (FAILURE,
#         CANCELLED, TIMED_OUT, ACTION_REQUIRED, STARTUP_FAILURE, STALE) —
#         stops polling immediately rather than waiting out the timeout
#         (PR #19 review, agy+codex: CANCELLED/TIMED_OUT were previously
#         silently treated as green) — or the timeout elapsed with checks
#         still IN_PROGRESS/PENDING/QUEUED. Either way prints a [WARN]
#         line; caller proceeds to label removal regardless (see "Why the
#         warn-and-proceed default" in ci-log-analysis.md).
set -eu

# Splits a `gh pr checks --json state` array (stdin) into two counts:
# unsettled (still running) and failed (a known-bad terminal state).
# Anything not in either set (e.g. SUCCESS, NEUTRAL, SKIPPED) is "green".
_classify() {
    jq -r '
        ([.[] | select(.state=="IN_PROGRESS" or .state=="PENDING" or .state=="QUEUED")] | length),
        ([.[] | select(.state=="FAILURE" or .state=="CANCELLED" or .state=="TIMED_OUT" or .state=="ACTION_REQUIRED" or .state=="STARTUP_FAILURE" or .state=="STALE")] | length)
    ' | tr '\n' ' ' | sed 's/ $//'
}

if [ "${1:-}" = "--self-test" ]; then
    check() {
        got=$(printf '%s' "$2" | _classify)
        [ "$got" = "$1" ] || { printf 'FAIL: %s -> got "%s", want "%s"\n' "$3" "$got" "$1" >&2; exit 1; }
    }
    check "0 0" '[{"state":"SUCCESS"}]' "all-success"
    check "1 0" '[{"state":"IN_PROGRESS"}]' "still running"
    check "0 1" '[{"state":"CANCELLED"}]' "cancelled must count as failed, not green"
    check "0 1" '[{"state":"TIMED_OUT"}]' "timed_out must count as failed, not green"
    check "0 1" '[{"state":"FAILURE"},{"state":"SUCCESS"}]' "mixed failure+success"
    check "0 0" '[{"state":"SUCCESS"},{"state":"NEUTRAL"},{"state":"SKIPPED"}]' "non-blocking terminal states are green"
    echo "[OK] wait-for-green.sh --self-test: all classification cases pass"
    exit 0
fi

PR_NUMBER=${1:?PR number required}
WAIT_SECONDS=${2:?wait seconds required}
: "${TARGET_REPO:?TARGET_REPO must be exported by Step 1}"
: "${TARGET_HOST:?TARGET_HOST must be exported by Step 1}"

ELAPSED=0
INTERVAL=30
UNSETTLED=0
FAILED=0

while [ "$ELAPSED" -lt "$WAIT_SECONDS" ]; do
    COUNTS=$(GH_HOST="$TARGET_HOST" gh pr checks "$PR_NUMBER" --repo "$TARGET_REPO" --required \
        --json state | _classify)
    UNSETTLED=${COUNTS%% *}
    FAILED=${COUNTS##* }
    [ "$UNSETTLED" -eq 0 ] && [ "$FAILED" -eq 0 ] && exit 0
    [ "$FAILED" -gt 0 ] && break
    sleep "$INTERVAL"
    ELAPSED=$(( ELAPSED + INTERVAL ))
done

if [ "$FAILED" -gt 0 ]; then
    echo "[WARN] CI has a failed/cancelled required check after ${ELAPSED}s — proceeding to label removal."
else
    echo "[WARN] CI still pending after ${WAIT_SECONDS}s — proceeding to label removal."
fi
exit 1
