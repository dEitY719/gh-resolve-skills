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
# Part 2 then RUNS the shared block at tier 5, which is what keeps the trio
# from being identically wrong: the byte-identity check above is happy with
# three copies of a defect (dEitY719/gh-resolve-skills#24). The two slices are
# independent on purpose — this file never cuts the block at
# `export SHELL_COMMON=`, the anchor that silently truncated gh-pr-skills
# PR #49's extractor once that line moved above the load and then reported the
# truncation as a tier-5 failure. The fence is the only boundary used here.
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

printf 'ok    %s copies share one byte-identical contract (%s shared lines)\n' \
    "${#SKILLS[@]}" "$(printf '%s\n' "$ref" | wc -l | tr -d ' ')"

# --- Part 2: the shared block, run --------------------------------------
# harness-skills/references/plugin-root.md is the SSOT. Two things it fixed
# after this trio was written are asserted by BEHAVIOUR here, because Part 1 is
# happy with three copies of the same defect (dEitY719/gh-resolve-skills#24):
#   #36  the proof compares command -v's OUTPUT to the bare name, so a PATH
#        executable, an alias or an inherited function that merely owns the
#        name cannot pass it;
#   #37  export SHELL_COMMON sits before the load AND is undone when the proof
#        fails, so a tree that did not load is never left exported.
# One copy is enough: Part 1 already proved the three are the same bytes.
#
# Reaching the proof at all takes a plugin root that HOLDS a gh_host.sh, since
# an absent one stops at the earlier tier-5 arm. So the fixture is a root whose
# helper loads and defines nothing — the case #36 is about.
TMP="$(mktemp -d)"
EMPTY_HOME="$(mktemp -d)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$TMP" "$EMPTY_HOME" "$SANDBOX"' EXIT

# The whole first fence, cut at the fence markers and nowhere else.
awk '/^```bash$/ { b = 1; next } b && /^```$/ { exit } b' \
    "skills/${SKILLS[0]}/references/github-target.md" > "$TMP/block.sh"
[ -s "$TMP/block.sh" ] || fail "no bash fence in skills/${SKILLS[0]}/references/github-target.md"
# The cut must reach the end of the binding. An extractor anchored on
# `export SHELL_COMMON=` truncated silently once #37 moved that line above the
# load, and then reported the truncation as a tier-5 failure (gh-pr-skills
# PR #49). This file anchors on the fence alone; the assertion is the receipt.
grep -q '^export TARGET_REPO TARGET_HOST$' "$TMP/block.sh" \
    || fail "the extracted block is truncated: it does not reach 'export TARGET_REPO TARGET_HOST'"

EMPTY_ROOT="$TMP/empty-root"
mkdir -p "$EMPTY_ROOT/lib/vendor/shell-common/functions"
: > "$EMPTY_ROOT/lib/vendor/shell-common/functions/gh_host.sh"
mkdir -p "$TMP/fakebin"
printf '#!/bin/sh\n:\n' > "$TMP/fakebin/_gh_resolve_host"
chmod +x "$TMP/fakebin/_gh_resolve_host"

rc=0
chk() { # chk <label> <got> <want>
    if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"
    else printf 'FAIL  %s: got [%s] want [%s]\n' "$1" "$2" "$3"; rc=1; fi
}

# Run the block in a child shell and read back BOTH what it returned and
# whether it left SHELL_COMMON behind. The readback is an EXIT trap because
# the block `exit`s on every tier-5 arm, which would otherwise skip a trailing
# printf and make a leak indistinguishable from a clean stop.
RC=0; LEAK=''
probe() { # probe <shell> <plugin-root-or-empty> [pre-code] [extra-PATH]
    rm -f "$TMP/leak"
    # `&& RC=0 || RC=$?`, not a bare `RC=$?`: this file runs under `set -e`,
    # and a stopping block is the expected result of most cases below.
    ( cd "$SANDBOX" && env -u CLAUDE_PLUGIN_ROOT -u SHELL_COMMON -u DOTFILES_ROOT \
        HOME="$EMPTY_HOME" PATH="${4:+$4:}$PATH" \
        ${2:+CLAUDE_PLUGIN_ROOT="$2"} \
        "$1" -c "trap 'printf %s \"\${SHELL_COMMON:-unset}\" > \"\$2\"' EXIT
${3:-:}
. \"\$1\"" _ "$TMP/block.sh" "$TMP/leak" >/dev/null 2>&1 ) && RC=0 || RC=$?
    LEAK="$(cat "$TMP/leak" 2>/dev/null || :)"
}

for sh in sh bash zsh dash; do
    command -v "$sh" >/dev/null 2>&1 || { printf 'skip  %s not installed\n' "$sh"; continue; }

    # Tier 5 with nothing on disk: these three skills hard-fail (unlike the
    # soft-fail verify skills), so an unresolvable root stops the run.
    probe "$sh" ''
    chk "$sh: tier 5 stops"                      "$([ "$RC" -ne 0 ] && echo stopped || echo continued)" stopped
    chk "$sh: tier 5 exports nothing"            "$LEAK" unset

    # A helper that loads and defines nothing: the proof must reject it, and
    # #37's unset is what keeps the pre-load export from surviving that.
    probe "$sh" "$EMPTY_ROOT"
    chk "$sh: a helper defining nothing fails the proof" \
        "$([ "$RC" -ne 0 ] && echo stopped || echo continued)" stopped
    chk "$sh: a failed load leaves SHELL_COMMON unset" "$LEAK" unset

    # #36's three impostors. Each passes `command -v <fn> >/dev/null 2>&1`;
    # none prints the bare name, so none may pass the equality proof. A leak
    # here means the proof let an impostor through and the run continued.
    probe "$sh" "$EMPTY_ROOT" '' "$TMP/fakebin"
    chk "$sh: a PATH executable named _gh_resolve_host fails the proof" "$LEAK" unset
    probe "$sh" "$EMPTY_ROOT" "alias _gh_resolve_host='echo impostor'"
    chk "$sh: an alias owning _gh_resolve_host fails the proof"         "$LEAK" unset
    probe "$sh" "$EMPTY_ROOT" '_gh_resolve_host() { :; }'
    chk "$sh: an inherited _gh_resolve_host fails the proof"            "$LEAK" unset
done

# Ordering is not observable from outside — both the old and the new form end
# with SHELL_COMMON unset on a clean tier-5 stop — so it is asserted on the
# text. Before #37 the export sat after the proof, which reads safer and
# silently broke every vendored helper's own ${SHELL_COMMON:-...} lookup at
# source time.
exp=$(grep -n '^export SHELL_COMMON=' "$TMP/block.sh" | head -n 1 | cut -d: -f1)
load=$(grep -n '^\[ -f .* \] && \. ' "$TMP/block.sh" | head -n 1 | cut -d: -f1)
if [ -n "$exp" ] && [ -n "$load" ] && [ "$exp" -lt "$load" ]; then
    chk "export SHELL_COMMON precedes the load" yes yes
else
    chk "export SHELL_COMMON precedes the load" "export@${exp:-none} load@${load:-none}" "export < load"
fi

[ "$rc" -eq 0 ] || { printf '[FAIL] github-target.md contract\n'; exit 1; }
printf '[OK] github-target.md: one contract, three copies, and it holds when run\n'
