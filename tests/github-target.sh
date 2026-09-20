#!/bin/bash
# Drift guard for the three copies of references/github-target.md
# (dEitY719/gh-resolve-skills#18).
#
# ci-fail, conflict and outdated each ship their own copy of the Step 1 target
# binding. The copies are deliberate: the block is pasted into a bare shell
# before CLAUDE_PLUGIN_ROOT is known to be set, so it cannot be replaced by
# `. "$CLAUDE_PLUGIN_ROOT/lib/..."` without breaking the tier-1 DOTFILES_ROOT
# install that has no CLAUDE_PLUGIN_ROOT at all — the copies are the contract,
# and this file is what keeps them one contract instead of three.
#
# Everything above the `## Why it matters here` heading is shared and must be
# byte-identical across the three once each file's own skill name is
# normalised. Everything below it is that skill's own justification and is
# free to differ.
#
# Run: bash tests/github-target.sh
set -euo pipefail

cd -- "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

SKILLS=(ci-fail conflict outdated)
BOUNDARY='## Why it matters here'

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

# Shared region = the file up to (not including) the boundary heading, with
# this skill's own name replaced by a placeholder. The H1 and the two error
# printfs are the only places the name appears above the boundary.
shared_region() {
    local skill="$1" file="$2"
    awk -v b="$BOUNDARY" '$0 == b { exit } { print }' "$file" \
        | sed "s/gh-resolve:${skill}/gh-resolve:<skill>/g"
}

ref=''
ref_skill=''
for skill in "${SKILLS[@]}"; do
    file="skills/${skill}/references/github-target.md"
    [ -f "$file" ] || fail "$file is missing"
    grep -qxF -- "$BOUNDARY" "$file" \
        || fail "$file has no '$BOUNDARY' heading: the shared/per-skill boundary is gone"

    # The per-skill tail must still say something. Without this, a red run
    # could be "fixed" by deleting the skill-specific paragraph.
    tail_text="$(awk -v b="$BOUNDARY" 'f; $0 == b { f = 1 }' "$file" | tr -d '[:space:]')"
    [ -n "$tail_text" ] || fail "$file has an empty '$BOUNDARY' section"

    region="$(shared_region "$skill" "$file")"
    [ -n "$region" ] || fail "$file has an empty shared region"
    case "$region" in
        *gh-resolve:ci-fail*|*gh-resolve:conflict*|*gh-resolve:outdated*)
            fail "$file names a sibling skill above '$BOUNDARY'; the shared region must be skill-neutral" ;;
    esac

    if [ -z "$ref_skill" ]; then
        ref="$region"
        ref_skill="$skill"
    elif [ "$region" != "$ref" ]; then
        printf 'FAIL: shared region of %s drifted from %s:\n' "$skill" "$ref_skill" >&2
        diff <(printf '%s\n' "$ref") <(printf '%s\n' "$region") >&2 || :
        exit 1
    fi
done

printf '[OK] github-target.md: %s copies share one byte-identical contract (%s shared lines)\n' \
    "${#SKILLS[@]}" "$(printf '%s\n' "$ref" | wc -l | tr -d ' ')"
