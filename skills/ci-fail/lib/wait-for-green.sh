#!/usr/bin/env sh
# gh-resolve:ci-fail — SKILL.md Step 6: poll `gh pr checks --required` every
# 30s until green or timeout.
#
# Usage: wait-for-green.sh "$PR_NUMBER" "$WAIT_SECONDS"
# Requires TARGET_REPO / TARGET_HOST already exported by SKILL.md Step 1
# (references/github-target.md, #1403).
#
# Exit 0: required checks were (or became) green within the timeout.
# Exit 1: still pending/failing after the timeout — prints a [WARN] line
#         first; caller proceeds to label removal regardless (see
#         "Why the warn-and-proceed default" in ci-log-analysis.md).
set -eu

PR_NUMBER=${1:?PR number required}
WAIT_SECONDS=${2:?wait seconds required}
: "${TARGET_REPO:?TARGET_REPO must be exported by Step 1}"
: "${TARGET_HOST:?TARGET_HOST must be exported by Step 1}"

ELAPSED=0
INTERVAL=30
PENDING=1

while [ "$ELAPSED" -lt "$WAIT_SECONDS" ]; do
    PENDING=$(GH_HOST="$TARGET_HOST" gh pr checks "$PR_NUMBER" --repo "$TARGET_REPO" --required \
        --json state --jq '[.[] | select(.state=="IN_PROGRESS" or .state=="PENDING" or .state=="FAILURE")] | length')
    [ "$PENDING" -eq 0 ] && break
    sleep "$INTERVAL"
    ELAPSED=$(( ELAPSED + INTERVAL ))
done

if [ "$PENDING" -gt 0 ]; then
    echo "[WARN] CI still pending after ${WAIT_SECONDS}s — proceeding to label removal."
    exit 1
fi

exit 0
