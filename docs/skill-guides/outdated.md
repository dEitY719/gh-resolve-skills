# gh-resolve:outdated — visual guide

**한 줄 요약** — base 는 움직였지만 충돌 파일은 없는 PR 을 클린 rebase 하고
`--force-with-lease` 로 push 해 **base 와 동기화된 mergeable PR** 을 남긴다.
세 스킬 중 가장 싼 경우를 담당하며, 멱등해서 다시 돌려도 안전하다.

## 언제 쓰나

| 상황 | 쓸 스킬 |
|------|---------|
| head 가 base 보다 뒤처짐, 충돌 없음 (`BEHIND`) | **`outdated`** (이 스킬) |
| `CONFLICTING` — 충돌 파일이 있다 | `gh-resolve:conflict` |
| required check 가 빨갛다 | `gh-resolve:ci-fail` |

### 쓰지 않는 경우

- **충돌이 있는 PR.** 이 스킬은 충돌을 직접 풀지 않는다. rebase 가 충돌을
  내면 즉시 `git rebase --abort` 하고 exit 4 로 `conflict` 에 넘긴다.
- **CI 가 빨간 경우.** `ci-fail` 의 몫이다.
- **default branch 위에 있을 때.** 거부한다.

이미 깨끗한 PR 에 돌리면 아무것도 하지 않고 exit 0 으로 끝난다 — 잘못 부른
것이 아니라 설계된 no-op 이다.

## 호출 형식

```
/gh-resolve:outdated [pr-number] [remote] [--worktree <path>]
```

| 인자 / 옵션 | 기본값 | 설명 |
|-------------|--------|------|
| `pr-number` | 현재 브랜치에서 자동 탐지 | `--worktree` 를 쓰면 **필수**가 된다 |
| `remote` | `origin` | 이 remote 의 URL 에서 `TARGET_HOST` + `TARGET_REPO` 를 바인딩한다 |
| `--worktree <path>` | 없음 | 모든 git 명령을 `<path>` 에서 실행하고 push 에 명시적 refspec 을 쓴다. 경로는 호출자(`gh-pr:merge-train`)가 소유 |
| `-h` / `--help` / `help` | — | `references/help.md` 를 그대로 출력하고 종료. API 호출 없음 |

### 종료 코드

| 코드 | 의미 |
|------|------|
| 0 | 성공, 또는 이미 깨끗해서 할 일 없음 (멱등 no-op) |
| 3 | `CONFLICTING` — `gh-resolve:conflict` 로 위임 |
| 4 | rebase 가 충돌을 냄 → abort 후 `conflict` 로 위임 |
| 6 | `--force-with-lease` 거부 — remote 가 앞서 나감 |

## 동작 단계

| Step | 하는 일 | 멈추는 조건 |
|------|---------|-------------|
| 1 | 인자 파싱, 호스트 바인딩, `gh` auth 확인, 하드 프리컨디션, `BACKUP_SHA` 기록 | git repo 아님 · default branch · 더티 트리 · 진행 중인 rebase |
| 2 | `mergeable`/`mergeStateStatus` 를 읽어 action matrix 로 분기 | `MERGEABLE`/`BEHIND` 만 Step 3 진행. `CONFLICTING` → exit 3 |
| 3 | `git fetch <remote> <base>` → `git rebase <remote>/<base>` | 충돌 발생 시 즉시 `--abort` + exit 4 |
| 4 | `git push --force-with-lease <remote> HEAD` | 거부 시 `[FAIL] remote advanced — re-fetch and retry` + exit 6 |
| 5 | `mergeable` 재확인 + 리포트, push 가 성공했을 때만 낡은 `review-passed` 제거 | — |

## 주의사항 / 제약

- **rebase 전용.** merge commit 을 만들지 않는다.
- **`--force-with-lease` 만 쓴다.** plain `--force` 는 절대 금지다.
- **거부된 lease 를 대신 재시도하지 않는다.** 조용히 재fetch 하면 lost-update 가
  난다. 갈라진 사실을 노출하고 사용자가 판단하게 한다.
- **충돌을 스스로 풀지 않는다.** 이것이 `conflict` 와 이 스킬을 갈라놓는 선이고,
  그 선이 두 스킬을 안전하게 유지한다. 형제 스킬의 파일별 루프를 인라인하지 않는다.
- Claude Code 밖에서는 스킬 호출 도구가 없으므로 exit code 와 후속 명령을 출력하고
  멈춘다 (manual handoff).
- auto-stash 하지 않는다. 클린 트리가 전제다.
- `review-passed` / `review-blocked` 를 추가하지 않고 `review-blocked` 를 제거하지도
  않는다. push 성공 후 낡은 `review-passed` 제거만 필수다 (#1563) — 리뷰되지 않은
  head 에 남은 낡은 판정이 바로 이 규칙이 고치는 버그다.
- `--worktree` 경로를 만들지도 지우지도 않는다.
