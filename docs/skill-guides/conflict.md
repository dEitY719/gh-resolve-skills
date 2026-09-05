# gh-resolve:conflict — visual guide

**한 줄 요약** — "This branch has conflicts that must be resolved" 경고가 붙은
PR 을 base 위로 rebase 하면서 충돌 파일마다 사용자의 의도를 물어 해소하고,
`--force-with-lease` 로 push 해 **경고가 사라진 mergeable 상태의 PR** 을 남긴다.

## 언제 쓰나

| 상황 | 쓸 스킬 |
|------|---------|
| "branch has conflicts that must be resolved" | **`conflict`** (이 스킬) |
| base 만 뒤처졌고 충돌 파일은 없다 | `gh-resolve:outdated` |
| required check 가 빨갛다 | `gh-resolve:ci-fail` |

GitHub 이 무엇을 문제 삼고 있는지로 고르는 것이지, 내가 무엇을 고치고 싶은지로
고르는 것이 아니다. `mergeable` 이 `CONFLICTING` 일 때가 이 스킬의 자리다.

### 쓰지 않는 경우

- **충돌이 없는 단순 base 뒤처짐.** `outdated` 가 더 싸고 멱등하다.
- **CI 로그를 읽어야 할 때.** 이 스킬은 CI 로그를 읽지 않는다.
- **애매한 hunk 를 알아서 처리해 주길 바랄 때.** 이 스킬은 추측하지 않는다.
  물어보고, 진짜 답을 기다린다.
- **default branch 위에 있을 때.** default branch 를 rebase 하지 않는다.

## 호출 형식

```
/gh-resolve:conflict [pr-number] [remote] [--worktree <path>]
```

| 인자 / 옵션 | 기본값 | 설명 |
|-------------|--------|------|
| `pr-number` | 현재 브랜치에서 자동 탐지 | `--worktree` 를 쓰면 **필수**가 된다 (detached HEAD 에는 탐지할 브랜치가 없다) |
| `remote` | `origin` | 이 remote 의 URL 에서 `TARGET_HOST` + `TARGET_REPO` 를 바인딩한다 |
| `--worktree <path>` | 없음 | 모든 git 명령이 `git -C "<path>" ...` 가 되고 push 는 명시적 refspec 을 쓴다. 경로의 생명주기는 호출자(`gh-pr:merge-train`)가 소유한다 |
| `-h` / `--help` / `help` | — | `references/help.md` 를 그대로 출력하고 종료. API 호출 없음 |

## 동작 단계

| Step | 하는 일 | 멈추는 조건 |
|------|---------|-------------|
| 1 | 인자 파싱, 호스트 바인딩, **mergeable preflight**, 하드 프리컨디션 검사, `BACKUP_SHA` 출력 | 이미 `MERGEABLE` 이면 스킵 · default branch · 진행 중인 rebase/merge/cherry-pick |
| 2 | `git fetch <remote> <base>` 후 `git rebase <remote>/<base>` | — |
| 3 | 충돌 시 커밋 단위 루프: `UU`/`AA`/`DU` 경로 나열 → 파일마다 의도 확인 → `git add` → `git rebase --continue` | 애매한 충돌은 **자동 해소하지 않고 질문** |
| 4 | rebase 가 0 으로 끝나고 트리가 깨끗할 때만 `git push --force-with-lease` | lease 거부 시 upstream 을 노출하고 **중단** (재fetch·재rebase 금지) |
| 5 | `mergeable` 재확인 → `conflict` 라벨 제거 · 보드 카드 `In review` 복귀 · ai-metrics 코멘트 · 낡은 `review-passed` 제거 | 여전히 `CONFLICTING`/`BEHIND` 면 URL 과 어느 쪽이 갈라졌는지 출력하고 루프하지 않음 |

## 주의사항 / 제약

- **merge commit 을 절대 만들지 않는다.** rebase 전용이다.
- **plain `git push --force` 를 절대 쓰지 않는다.** `--force-with-lease` 아니면 중단이다.
- **거부된 lease 를 대신 재시도하지 않는다.** lease 거부는 내가 rebase 하는 동안
  누군가 push 했다는 뜻이다. 갈라진 지점을 보여주고 사용자가 결정하게 한다.
  대신 fetch 해서 다시 rebase 하는 순간 동료의 커밋이 사라진다.
- **애매한 충돌을 자동 해소하지 않는다.** 물어보고 진짜 답을 받는다. 세션의
  auto-approve 설정은 사용자의 답이 아니다.
- Step 5 를 건너뛰지 않는다 — PR 경고를 걷어내는 것이 이 스킬의 존재 이유다.
- push 가 성공하면 리뷰받은 커밋은 더 이상 head 가 아니므로 낡은 `review-passed`
  제거는 **필수**다. 반대로 `review-blocked` 는 추가도 제거도 하지 않는다 (#1563).
- `--worktree` 경로를 만들지도 지우지도 않는다. 호출자가 소유한다.
- 히스토리를 건드리기 전에 항상 `BACKUP_SHA` 를 출력한다.
