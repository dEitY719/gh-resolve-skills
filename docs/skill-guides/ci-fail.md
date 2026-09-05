# gh-resolve:ci-fail — visual guide

**한 줄 요약** — 빨간 required check 를 읽어 원인을 로컬에서 고치고, CI 가 돌린
바로 그 명령으로 재검증한 뒤 fast-forward push 하고 `CI fail` 라벨을 떼어낸
**그린 CI 상태의 PR** 을 산출물로 남긴다.

## 언제 쓰나

GitHub 이 머지 버튼을 회색으로 만드는 세 가지 이유 중 **required check 실패**
하나만 담당한다.

| 상황 | 쓸 스킬 |
|------|---------|
| required check 가 빨갛다 | **`ci-fail`** (이 스킬) |
| "This branch has conflicts that must be resolved" | `gh-resolve:conflict` |
| head 가 base 보다 뒤처졌고 충돌은 없다 | `gh-resolve:outdated` |

### 쓰지 않는 경우

- **rebase 가 필요한 상황.** 이 스킬은 rebase 를 하지 않고 force push 도 하지
  않는다. base 동기화는 `outdated`, 충돌 해소는 `conflict` 의 몫이다.
- **실패 원인을 모르는 채 재시도만 하고 싶을 때.** blind retry 는 금지다.
  로그에서 원인을 특정하지 못하면 로그를 그대로 보여주고 멈춘다.
- **repo 의 default branch 위에 있을 때.** 무조건 거부한다.

## 호출 형식

```
/gh-resolve:ci-fail [pr-number] [remote] [--wait <seconds>] [--label-variant <s>]
```

| 인자 / 옵션 | 기본값 | 설명 |
|-------------|--------|------|
| `pr-number` | 현재 브랜치에서 자동 탐지 | 생략 시 `gh pr view` 로 찾는다. PR 이 없으면 중단 |
| `remote` | `origin` | 이 remote 의 URL 에서 `TARGET_HOST` + `TARGET_REPO` 를 바인딩한다 |
| `--wait <seconds>` | off (opt-in) | push 후 CI 가 그린이 될 때까지 30 초 간격 폴링. 타임아웃은 `[WARN]` 후 진행 |
| `--label-variant <s>` | `CI fail` | 라벨 표기가 다른 repo 용 오버라이드. 정규화 실패 시 fail-fast |
| `-h` / `--help` / `help` | — | `references/help.md` 를 그대로 출력하고 종료. API 호출 없음 |

## 동작 단계

| Step | 하는 일 | 멈추는 조건 |
|------|---------|-------------|
| 1 | 인자 파싱, `TARGET_HOST`/`TARGET_REPO` 바인딩, PR 상태 `OPEN` 확인, `BACKUP_SHA` 기록 | default branch · 더티 트리 · 진행 중인 rebase |
| 2 | main 의 동일 workflow 가 inherited red 인지 pre-check → required check 중 `FAILURE` 만 추림 | 전부 그린이면 `[OK] no failing checks — nothing to resolve.` |
| 3 | 실패 workflow 의 최신 `RUN_ID` 로 `gh run view --log-failed`, 근본 원인 특정 | 원인 특정 실패 시 로그 노출 후 중단 |
| 4 | 원인 파일 수정 후 **CI 와 동일한** lint/test 명령 로컬 재실행 | 여전히 빨가면 `[FAIL] local checks failed — fix before push` (push 하지 않음) |
| 5 | `fix(ci): <summary> (#<PR>)` 로 인라인 커밋 + fast-forward push | push 거부 시 divergence 노출 후 중단 (**라벨은 그대로 둔다**) |
| 6 | `--wait` 가 있을 때만 CI 그린 폴링 | 타임아웃 → `[WARN]` 후 다음 단계 |
| 7 | REST DELETE 로 `CI fail` 라벨 제거 + ai-metrics 코멘트 | Step 5 push 가 실패했다면 **이 단계는 실행되지 않는다** |

## 주의사항 / 제약

- **force push 를 절대 하지 않는다.** `--force` 도 `--force-with-lease` 도 쓰지
  않는다. fast-forward push 전용이다. 히스토리를 다시 쓰는 것은 형제 스킬 둘의 일이다.
- **로컬 검증이 빨간 상태로는 push 하지 않는다.** CI 무한 루프 방지 가드다.
- **라벨 제거는 항상 마지막 mutation 이다.** push 가 실패하면 라벨이 남아
  리뷰어가 여전히 빨간 상태를 본다.
- 없는 라벨을 자동 생성하지 않는다 (404 는 soft-fail).
- auto-stash 하지 않는다. 실행 전 워킹 트리가 깨끗해야 한다.
- `review-passed` / `review-blocked` 를 추가하지도, `review-blocked` 를 제거하지도
  않는다 (dEitY719/dotfiles#1563).
- 모든 `gh` 호출은 `GH_HOST=` 로 호스트 고정된다 (dEitY719/dotfiles#1403). 이걸 빠뜨리면 GHES
  repo 요청이 `github.com` 으로 나간다.
