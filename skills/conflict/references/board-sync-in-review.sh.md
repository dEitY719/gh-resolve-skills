# Step 5 — 보드 status `In review` 복귀 (soft-fail)

Applies **only when `mergeable == MERGEABLE`**.

`changes-requested` → fix push → 카드가 `In progress` 또는 `Changes requested` 에
머무는 흐름을 자동으로 끊어 리뷰어 큐 (`In review`) 로 되돌린다. 신규 PR
단계의 conflict (카드가 이미 `In review` / `Approved` / `Done`) 는
`--only-from` 가드가 막아 후퇴시키지 않는다. 자세한 lifecycle 근거는 issue dEitY719/dotfiles#591.

```bash
if [ "$MERGEABLE" = "MERGEABLE" ]; then
    # Defense-in-depth (dEitY719/dotfiles#724): the chained-`&&` form below silently no-ops
    # when the helper sources but never defines `_gh_project_status_sync`
    # (interactive-guard regression, partial source). Split into an
    # explicit guard so the failure prints a stderr warning instead of
    # collapsing into the `|| echo [WARN]` branch (which falsely suggests
    # a board sync was attempted).
    _HELPER="${SHELL_COMMON:-$HOME/dotfiles/shell-common}/functions/gh_project_status.sh"
    if [ ! -f "$_HELPER" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
        _HELPER="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common/functions/gh_project_status.sh"
        export SHELL_COMMON="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"
    fi
    if [ -r "$_HELPER" ]; then
        . "$_HELPER"
        if ! command -v _gh_project_status_sync >/dev/null 2>&1; then
            printf '[gh-resolve:conflict] %s sourced but _gh_project_status_sync undefined — board sync skipped (dEitY719/dotfiles#724).\n' \
                "$_HELPER" >&2
        elif _gh_project_status_sync pr "$PR_NUMBER" "In review" \
                --only-from "In progress,Changes requested" \
                --repo "$TARGET_REPO"; then
            echo "[OK] PR 카드 \`In review\` 로 복귀됨"
        else
            echo "[WARN] 보드 sync 실패 — 카드 수동 이동 필요할 수 있음"
        fi
    else
        echo "[WARN] board sync helper unavailable — card not moved"
    fi
fi
```

헬퍼 조회는 2단이다 (#1). dotfiles 체크아웃이 없는 머신에서 Step 1 은
`SHELL_COMMON` 을 vendor 디렉터리로 export 하므로, 이 PR 이
`gh_project_status.sh` 를 vendoring 한 뒤로는 1단(`${SHELL_COMMON:-...}`)이
그 vendor 사본에 그대로 닿는다. 2단이 필요한 경우는 Step 1 이 그 export 를
하지 못한 흐름 — dotfiles 는 있는데 그 안에 이 헬퍼만 없거나, 이 블록을 Step 1
없이 단독으로 복사해 쓴 경우 — 이고, 그때
`lib/vendor/shell-common/functions/gh_project_status.sh` 를 다시 잡는다. 그
vendor 사본까지 없으면 `else` 가 `[WARN]` 을 찍는다 — soft-fail 이되 조용하지는
않게.

2단은 `CLAUDE_PLUGIN_ROOT` 가 **비어 있지 않을 때만** 잡는다 (PR #8 리뷰,
codex/agy): 이 변수는 Claude Code 만 export 하는데 이 플러그인은 Codex /
Gemini CLI / OpenCode 등에도 배포된다. 빈 값을 그대로 이어붙이면 `_HELPER` 가
`/lib/vendor/...` 라는 파일시스템 루트 절대경로가 되고, 더 나쁘게는
`SHELL_COMMON` 까지 그 엉뚱한 경로로 export 되어 이후 모든 helper 조회를
오염시킨다. 가드가 있으면 그 경우 곧장 `else` 의 `[WARN]` 로 떨어진다.

`CLAUDE_PLUGIN_ROOT` 를 export 하지 않는 하네스에서 vendor 사본을 실제로
쓰려면, 이 블록을 실행하기 전에 스킬이 자기 base 디렉터리에서 플러그인
루트를 계산해 `CLAUDE_PLUGIN_ROOT` (또는 `SHELL_COMMON`) 로 넘겨야 한다.
레포 전역의 `${CLAUDE_PLUGIN_ROOT:-}` 조회 지점을 anchor 파일 하나
(`lib/resolve-target.sh` 형태, `$0`/`BASH_SOURCE` self-path 분기)로 모으는
정리는 이 PR 범위 밖의 후속 작업이다.

`--repo "$TARGET_REPO"` 는 Step 1 이 해소한 remote 를 명시로 넘긴다 (dEitY719/dotfiles#1405) —
빼면 헬퍼가 `gh repo view` 로 폴백하는데, 이는 git origin 이 아니라
`gh repo set-default` 가 고른 레포를 답한다. 헬퍼가 내부에서 실행하는 `gh`
호출의 host 는 Step 1 의 `export GH_HOST="$TARGET_HOST"` 를 상속한다
(`references/github-target.md`, dEitY719/dotfiles#1403) — 그 export 없이 이 블록을 복사해 쓰면
dual-host 로그인에서 조용히 다른 서버의 보드를 건드린다.

`GH_PROJECT_STATUS_SYNC=0` opt-out 은 helper 자체가 흡수한다. projectV2
보드가 없는 레포는 helper 가 silent 0 반환. `--only-from` 의 missing column
은 helper 가 silently skip 하므로 `Changes requested` 컬럼 없는 보드와도
호환된다.
