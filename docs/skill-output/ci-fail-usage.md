# ci-fail 사용 결과

> **한 줄 요약** — blocked PR 번호를 받아 required check 판정과 후속 조치를 생성합니다.

```
PR #1670 (dEitY719/dotfiles)  ──▶  /gh-resolve:ci-fail  ──▶  [OK] 실패 체크 없음 — 종료
```

## 1. 실행한 명령

```
/gh-resolve:ci-fail [pr-number] [remote] [--wait <s>] [--label-variant <s>]   # 범용 형식
/gh-resolve:ci-fail 1670 origin                                                # 이번 실행
```

실행 시각 2026-09-01T07:44:18Z (UTC). Step 1 preflight 와 Step 2 까지 실제 실행했다.

## 2. 입력

`dEitY719/dotfiles` PR **#1670** — "feat(skills): setup-skills-ssot 다중 워크스페이스
루트 스캔 (#1410 F-6 조기 도입)". 상태 `OPEN`, head `wt/issue-1652/1` → base `main`.

Step 1 이 remote URL `https://github.com/dEitY719/dotfiles` 에서 바인딩한 값:

```
TARGET_HOST=github.com
TARGET_REPO=dEitY719/dotfiles
BACKUP_SHA=ea3d253fa8413610168efd0db4ab53db8709019e
gh auth: Logged in to github.com account dEitY719
```

## 3. 결과

Step 2 의 required check 조회 실측 출력:

```
Lint (mise)         pass   42s   .../runs/33483290421/job/99777494765
Shell Lint (mise)   pass   38s   .../runs/33483290404/job/99777494609
exit=0
```

`FAILURE` 상태인 required check 0 건 → 스킬은 문서화된 종료 상태
`[OK] no failing checks — nothing to resolve.` 로 멈춘다. Step 3~7 (로그 분석, 로컬
수정, push, 라벨 제거) 은 실행 조건이 성립하지 않아 도달하지 않았다.

부수 실측 — 이 환경의 `gh` 는 2.45.0 이고 `gh pr checks` 에 `--json` 플래그가 없다.
SKILL.md Step 2 가 쓰는 `--json name,state,workflow,link` 는 더 최신 `gh` 를 전제한다.
위 출력은 플래그 없는 기본 형식으로 얻은 것이다.
