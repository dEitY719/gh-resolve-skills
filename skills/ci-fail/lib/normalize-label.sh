#!/usr/bin/env sh
# gh-resolve:ci-fail — canonicalize a --label-variant input to "CI fail".
#
# Usage: normalize-label.sh "<input>"
# stdout: canonical label name ("CI fail") on match.
# stderr + exit 1: fail-fast message when the input matches no known variant.
#
# Accepted: case / -,_,/ separator / obvious-typo ("fial") / past-tense
# ("failed") variants of "CI fail". See references/label-normalization.md.
set -eu

input=${1:-}

norm=$(printf '%s' "$input" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | tr -- '-_/' '   ' \
    | tr -s '[:space:]' ' ' \
    | sed -e 's/fial/fail/' -e 's/ed$//')

if [ "$norm" = "ci fail" ]; then
    printf 'CI fail\n'
    exit 0
fi

printf "[FAIL] unknown label-variant '%s' — expected one of the variants below.\n" "$input" >&2
cat >&2 <<'EOF'
Canonical label: CI fail

Accepted variants:
  CI fail, ci fail, CI Fail
  ci-fail, ci_fail, ci/fail (and case variations)
  CI fial (typo), CI failed (past tense)

Pass --label-variant '<variant>' or omit the flag to use 'CI fail'.
EOF
exit 1
