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
#         than the pending/failed sets below) within the timeout — caller
#         continues to Step 7.
# Exit 1: timeout elapsed with checks still IN_PROGRESS/PENDING/QUEUED, never
#         a definite failure — a genuine race the user accepted by passing
#         --wait. Prints `[WARN] ... proceeding to label removal.`; caller
#         proceeds to Step 7 anyway (see "Why the warn-and-proceed default"
#         in ci-log-analysis.md).
# Exit 2: a required check reached a known-bad terminal state (FAILURE,
#         CANCELLED, TIMED_OUT, ACTION_REQUIRED, STARTUP_FAILURE, STALE) —
#         this is not a race, CI is conclusively broken. Stops polling
#         immediately and prints `[FAIL] ...`; caller must NOT run Step 7 —
#         removing the label here would misrepresent broken CI as green
#         (PR #19 review, agy BLOCKER: distinguishing this from exit 1 is
#         what makes "warn-and-proceed" safe to keep for exit 1 at all;
#         previously FAILURE/CANCELLED/TIMED_OUT were silently folded into
#         the same "pending" bucket agy+codex both flagged).
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
    echo "[FAIL] CI has a failed/cancelled required check — this skill will not remove the CI fail label on broken CI. Fix the failure and re-run the skill (not just --wait)."
    exit 2
fi

echo "[WARN] CI still pending after ${WAIT_SECONDS}s — proceeding to label removal."
exit 1
