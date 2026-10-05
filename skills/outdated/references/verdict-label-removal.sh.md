# Step 5 — `review-passed` 무효화 (soft-fail)

Step 4 의 `git push --force-with-lease` 가 **성공했을 때만** 실행한다. Step 2 의
already-clean no-op(exit 0), `CONFLICTING` 위임(exit 3), 리베이스 충돌 중단
(exit 4), push 거부(exit 6) 경로에서는 head 가 그대로이므로 판정도 그대로
유효하다 — 아무것도 하지 않는다.

규칙의 SSOT 는 `dEitY719/dotfiles` 의
`shell-common/functions/gh_pr_edit_safe.sh`(이 repo 의 벤더 사본은
`lib/vendor/shell-common/functions/gh_pr_edit_safe.sh`) 헤더의
"Verdict-label invalidation — SSOT for issue #1563" 절이다. 요약: `review-passed`
는 **특정 head 커밋 하나**가 리뷰를 통과했다는 주장이다. 깨끗한 리베이스라도
force-push 는 그 커밋을 새 SHA 로 갈아치우므로 주장이 거짓이 된다. PR dEitY719/dotfiles#1529 가
정확히 이 경로로 리뷰된 커밋 위에 force-push 하고도 라벨을 그대로 뒀다.

Caller contract: `PR_NUMBER`, `TARGET_REPO`, `TARGET_HOST` 는 Step 1 이
`references/github-target.md` 대로 이미 export 한 상태여야 한다 (dEitY719/dotfiles#1403).

## `review-blocked` 는 절대 건드리지 않는다

이 스킬은 base 를 따라잡을 뿐, 리뷰어가 제기한 블로커가 처리됐는지에 대한
**증거를 하나도 갖고 있지 않다**. 리베이스 뒤에 `review-blocked` 가 남아 있는
것은 버그가 아니라 안전한 방향이다. `gh-pr:reply` 는 Step 5(코멘트 전원 답변)를
완주하면 이 라벨을 무조건 뗀다(dEitY719/dotfiles#1634) — 하지만 그건 그 스킬이 실제로 리뷰
코멘트에 답변했다는 별도의 증거를 갖고 있기 때문이다. 이 스킬은 그 증거가
없으므로 손대지 않는다.

라벨을 **붙이는** 것도 금지다. `review-passed` / `review-blocked` 의 유일한
발급자는 `gh-verify:review-all` 이다.

## 명령

공유 헬퍼 `_gh_pr_drop_label` 을 쓴다 — REST DELETE 관용구를 스킬마다 복사하지
않기 위한 단일 구현체다. `gh pr edit --remove-label` 이 아닌 이유는 후자가
classic Projects 보드가 붙은 repo 에서 GraphQL deprecation 때문에 **조용히
실패**하기 때문이다 (dEitY719/dotfiles#326 Bug B). 404(라벨이 애초에 없음)는 **경고가 아니라
정상**으로 흡수되므로 사전 확인 분기가 필요 없다. rc 1 일 때만 원문 에러가
넘어온다.

```bash
lib/remove-review-passed.sh outdated "$PR_NUMBER" "$TARGET_REPO" "$TARGET_HOST"
```

경로는 이 스킬의 base directory 기준이다. `lib/remove-review-passed.sh` 가 아래
helper 조회 순서, 3단 증명, `[OK]`/`[WARN]` 한 줄 출력을 그대로 구현하고 항상
exit 0 으로 끝난다 (`--self-test` 로 fixture 검증, 두 스킬 사본은
`tests/review-passed-lib-sync.sh` 가 byte-identical 로 묶는다).

Soft-fail 이다: 실패해도 Step 5 의 검증/보고는 그대로 진행한다. shell-common 을
못 찾은 경우도 마찬가지다 — 스크립트가 tier 5 메시지를 stderr 에 남기고 exit 0
으로 끝난다.

헬퍼 조회 순서(tier 1 `SHELL_COMMON`/dotfiles → tier 2 `CLAUDE_PLUGIN_ROOT` →
tier 5 중단)의 SSOT 는 [`harness-skills/references/plugin-root.md`](https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md) 다.
`$PWD` 단은 없다 — 이 스킬은 리뷰 대상 PR 체크아웃 안에서 돌기 때문에 `$PWD` 는
호출자가 통제하는 경로이고, 악의적인 PR 이 자기 트리에
`lib/vendor/shell-common/functions/gh_pr_edit_safe.sh` 를 넣어두면 그대로
source 된다 (dEitY719/harness-skills#22). `CLAUDE_PLUGIN_ROOT` 가 비어 있으면 경로를
만들지 않고 tier 5 로 멈춘다.

`unset -f` → `.` → `command -v` 3단이 증명이다. 두 번째 `[ -f ]` 를 대신하는
것이 아니라, **이번 로드가 이 셸에서 실제로 함수를 정의했음**을 보인다 — 존재
검사는 파일이 거기 있다는 것만 말한다. `export` 는 그 증명 뒤에 오며 폴백
분기 안에는 절대 두지 않는다 — 빈 값을 이어붙인 `/lib/vendor/...` 를 먼저
export 하던 것이 #8 이 보여준 결함이다.

## 호스트 고정

네 번째 인자 `TARGET_HOST` 가 `GH_HOST` 를 고정한다. 넘기지 않으면 dual-host
로그인에서 `gh` 가 `gh repo set-default` 로 폴백해 **에러 없이 엉뚱한 서버의
라벨을 지운다** (dEitY719/dotfiles#1403 / dEitY719/dotfiles#1407). `gh api` 는 `--repo` 플래그를 받지 않으므로
repo 는 경로에 들어간다 (dEitY719/dotfiles#658) — 헬퍼가 대신 처리한다.
