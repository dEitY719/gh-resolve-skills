# conflict 사용 결과

> **한 줄 요약** — blocked PR 번호를 받아 충돌 판정과 rebase 대상 확정을 생성합니다.

```
PR #1669 (dEitY719/dotfiles)  ──▶  /gh-resolve:conflict  ──▶  CONFLICTING 확정 · rebase 대상
```

## 1. 실행한 명령

```
/gh-resolve:conflict [pr-number] [remote] [--worktree <path>]   # 범용 형식
/gh-resolve:conflict 1669 origin                                 # 이번 실행
```

실행 시각 2026-09-01T07:44:18Z (UTC). Step 1 preflight (mergeable preflight 포함)
까지 실제 실행했다.

## 2. 입력

`dEitY719/dotfiles` PR **#1669** — "feat(skills): #1410 Phase 2 — session-skills
repo 생성". head `wt/issue-1661/1` → base `main`, 라벨 `docs` `skill` `feat` `test`
`review-passed`.

## 3. 결과

Step 1 mergeable preflight 실측 출력:

```json
{"number":1669,"mergeable":"CONFLICTING","mergeStateStatus":"DIRTY",
 "baseRefName":"main","headRefName":"wt/issue-1661/1",
 "url":"https://github.com/dEitY719/dotfiles/pull/1669"}
```

`MERGEABLE` 이 아니므로 already-clean 단축 종료에 걸리지 않고 Step 2 로 진행하는
경로가 확정됐다. 하드 프리컨디션 실측:

```
current branch = main
default branch = main        <- 일치: "refuse to rebase default branch" 가드 발동
BACKUP_SHA     = ea3d253fa8413610168efd0db4ab53db8709019e
```

로컬 체크아웃(`~/para/project/my-share/dotfiles`)이 default branch 위에 있어
Step 1 프리컨디션에서 정지했다. Step 2~5 (fetch·rebase·충돌 해소 루프·
`--force-with-lease` push) 는 **미실행** — published history 를 다시 쓰는 작업이라
이번 문서화 작업의 승인 범위 밖이다. 위 값은 모두 실제 조회 결과다.
