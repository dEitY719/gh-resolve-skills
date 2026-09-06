# Step 5 — 보드 status `In review` 복귀 (soft-fail)

Applies **only when `mergeable == MERGEABLE`**.

`changes-requested` → fix push → 카드가 `In progress` 또는 `Changes requested` 에
머무는 흐름을 자동으로 끊어 리뷰어 큐 (`In review`) 로 되돌린다. 신규 PR
단계의 conflict (카드가 이미 `In review` / `Approved` / `Done`) 는
`--only-from` 가드가 막아 후퇴시키지 않는다. 자세한 lifecycle 근거는 issue dEitY719/dotfiles#591.

Run `lib/board-sync.sh "$PR_NUMBER" "$TARGET_REPO"` (path relative to this
skill's base directory; requires `TARGET_HOST` already exported as `GH_HOST`
by Step 1) instead of transcribing the two-tier helper lookup by hand:

```bash
bash lib/board-sync.sh "$PR_NUMBER" "$TARGET_REPO"
```

Exit 0 always (soft-fail). Prints `[OK]` on a synced card, `[WARN]` when no
helper resolves (a dotfiles-free machine with no `CLAUDE_PLUGIN_ROOT`) or when
the helper sourced but never defined `_gh_project_status_sync`
(dEitY719/dotfiles#724 partial-source regression) — never a silent no-op.
`GH_PROJECT_STATUS_SYNC=0` opt-out and a board with no `Changes requested`
column are absorbed by the helper itself.

See the script header for the exact two-tier lookup order
(`SHELL_COMMON`/dotfiles checkout → `CLAUDE_PLUGIN_ROOT` vendor copy) and
`bash lib/board-sync.sh --self-test` for a fixture check of both tiers plus
the partial-source regression, none of which touch the network.
