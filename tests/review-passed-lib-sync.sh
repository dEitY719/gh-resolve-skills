#!/bin/sh
# Drift guard for the three copies of lib/remove-review-passed.sh
# (dEitY719/gh-resolve-skills#28, #32). ci-fail, conflict and outdated each ship
# their own copy so each skill's lib/ resolves relative to its own base directory; the
# copies must stay byte-identical, and each copy's --self-test must pass.
#
# Run: sh tests/review-passed-lib-sync.sh
set -eu

cd -- "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

A=skills/conflict/lib/remove-review-passed.sh
B=skills/outdated/lib/remove-review-passed.sh
C=skills/ci-fail/lib/remove-review-passed.sh

for f in "$B" "$C"; do
    cmp -s "$A" "$f" || { printf 'FAIL: %s and %s differ\n' "$A" "$f" >&2; exit 1; }
done
for f in "$A" "$B" "$C"; do
    bash "$f" --self-test || { printf 'FAIL: %s --self-test\n' "$f" >&2; exit 1; }
done
echo "ok    remove-review-passed.sh copies identical, all self-tests pass"
