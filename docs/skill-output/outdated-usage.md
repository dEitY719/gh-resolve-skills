# outdated 사용 결과

> **한 줄 요약** — blocked PR 번호를 받아 mergeable 판정과 위임 결정을 생성합니다.

```
PR #1667 (dEitY719/dotfiles)  ──▶  /gh-resolve:outdated  ──▶  exit 3 · conflict 로 위임
```

## 1. 실행한 명령

```
/gh-resolve:outdated [pr-number] [remote] [--worktree <path>]   # 범용 형식
/gh-resolve:outdated 1667 origin                                 # 이번 실행
```

실행 시각 2026-09-01T07:44:18Z (UTC). Step 1 preflight 와 Step 2 triage 까지 실제 실행했다.

## 2. 입력

`dEitY719/dotfiles` PR **#1667** — "feat(skills): #1410 Phase 2 — authoring-skills
repo 생성". head `wt/issue-1662/1` → base `main`, 라벨 `docs` `skill` `feat` `test`
`review-passed`.

Step 1 이 바인딩한 값: `TARGET_HOST=github.com`, `TARGET_REPO=dEitY719/dotfiles`,
`BACKUP_SHA=ea3d253fa8413610168efd0db4ab53db8709019e`.

## 3. 결과

Step 2 mergeable triage 실측 출력:

```json
{"mergeable":"UNKNOWN","mergeStateStatus":"UNKNOWN","baseRefName":"main",
 "headRefName":"wt/issue-1662/1","url":"https://github.com/dEitY719/dotfiles/pull/1667"}
```

첫 조회는 `UNKNOWN` 이었다 (GitHub 이 mergeability 를 지연 계산한다). 4 초 간격
재조회 3 회 모두 동일하게 확정:

```
poll 1 @ 07:44:30Z   #1667 mergeable=CONFLICTING state=DIRTY
poll 2 @ 07:44:35Z   #1667 mergeable=CONFLICTING state=DIRTY
poll 3 @ 07:44:41Z   #1667 mergeable=CONFLICTING state=DIRTY
```

action matrix 상 `CONFLICTING` 은 이 스킬의 대상이 아니다 → **exit 3** 으로
`gh-resolve:conflict` 에 위임하고 종료. Step 3~5 (fetch·rebase·push) 는 실행되지
않았다. 이것이 설계된 정상 경로다 — 이 스킬은 충돌을 스스로 풀지 않는다.
