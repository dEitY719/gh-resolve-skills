#!/usr/bin/env sh
# gh-resolve:outdated — SKILL.md Step 5: post the ai-metrics PR comment
# (soft-fail — warn on error, never block). Skips entirely under
# GH_DISABLE_AI_METRICS=1 (dEitY719/dotfiles#399). This repo forbids emojis in
# tracked text (CI enforces it), so the footer uses the same plain-text form
# `gh-resolve:ci-fail` already prints.
#
# Usage: post-ai-metrics.sh "$PR_NUMBER" "$START_TS"
#        post-ai-metrics.sh --self-test   (fixture check, no real `gh`)
# Requires TARGET_REPO / TARGET_HOST already exported by SKILL.md Step 1
# (references/github-target.md, dEitY719/dotfiles#1403); TOKENS is optional
# (defaults to 3000). human_h is a flat 0.5 — a clean rebase-and-push, unlike
# `gh-resolve:conflict`'s per-file estimate, has no file-count signal to scale
# on (`gh-issue-skills/skills/create/references/metrics-baseline.md` `chore`
# tier).
#
# Exit 0 always (soft-fail).
set -eu

if [ "${1:-}" = "--self-test" ]; then
    # Disabled path: exits 0 with no gh call, even with no other caller var set
    # (GH_DISABLE_AI_METRICS is checked before the required-arg/env reads).
    OUT=$(GH_DISABLE_AI_METRICS=1 sh "$0" 1 "$(date +%s)")
    [ -z "$OUT" ] || { echo "FAIL: expected no output under GH_DISABLE_AI_METRICS=1, got: $OUT" >&2; exit 1; }

    # Enabled path: verify the actual gh invocation via a stub that records
    # its own env + args instead of hitting the network.
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    cat > "$TMP/gh" <<'EOF'
#!/usr/bin/env sh
printf 'GH_HOST=%s ARGS=%s\n' "${GH_HOST:-}" "$*" > "$GH_CALL_LOG"
EOF
    chmod +x "$TMP/gh"
    GH_CALL_LOG="$TMP/call.log"
    export GH_CALL_LOG
    PATH="$TMP:$PATH" TARGET_REPO=o/r TARGET_HOST=ghe.example.com \
        sh "$0" 42 "$(date +%s)" >/dev/null
    CALL=$(cat "$GH_CALL_LOG")
    case "$CALL" in
        "GH_HOST=ghe.example.com ARGS="*"repos/o/r/issues/42/comments"*"-X POST"*) : ;;
        *) echo "FAIL: unexpected gh invocation: $CALL" >&2; exit 1 ;;
    esac

    echo "[OK] post-ai-metrics.sh --self-test: disabled path skips gh, enabled path hits the right endpoint/host"
    exit 0
fi

if [ "${GH_DISABLE_AI_METRICS:-0}" = "1" ]; then
    exit 0
fi

PR_NUMBER=${1:?PR number required}
START_TS=${2:?START_TS required}
: "${TARGET_REPO:?TARGET_REPO must be exported by Step 1}"
: "${TARGET_HOST:?TARGET_HOST must be exported by Step 1}"

ELAPSED=$(( ($(date +%s) - START_TS) / 60 ))
HUMAN_H=0.5
TOKENS=${TOKENS:-3000}

GH_HOST="$TARGET_HOST" gh api "repos/$TARGET_REPO/issues/$PR_NUMBER/comments" \
    -X POST \
    -f body="---
<details>
<summary>AI Metrics · tokens=~$TOKENS · human_h=~$HUMAN_H · ai_min=~$ELAPSED</summary>

<!-- ai-metrics:gh-resolve-outdated -->
AI Metrics tokens=~$TOKENS human_h=~$HUMAN_H ai_min=~$ELAPSED
<!-- /ai-metrics:gh-resolve-outdated -->

</details>
out-of-date 해소: ~$ELAPSED min · 사람: ~$HUMAN_H h" \
    >/dev/null 2>&1 \
  || echo "[WARN] ai-metrics comment failed — continuing."
