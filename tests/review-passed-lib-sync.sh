#!/bin/sh
# Drift guard for the two copies of lib/remove-review-passed.sh
# (dEitY719/gh-resolve-skills#28). conflict and outdated each ship their own
# copy so each skill's lib/ resolves relative to its own base directory; the
# copies must stay byte-identical, and each copy's --self-test must pass.
#
# Run: sh tests/review-passed-lib-sync.sh
set -eu

cd -- "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

A=skills/conflict/lib/remove-review-passed.sh
B=skills/outdated/lib/remove-review-passed.sh

cmp -s "$A" "$B" || { printf 'FAIL: %s and %s differ\n' "$A" "$B" >&2; exit 1; }
for f in "$A" "$B"; do
    bash "$f" --self-test || { printf 'FAIL: %s --self-test\n' "$f" >&2; exit 1; }
done
echo "ok    remove-review-passed.sh copies identical, both self-tests pass"
