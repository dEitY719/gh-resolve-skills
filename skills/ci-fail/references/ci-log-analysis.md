# gh-resolve:ci-fail — CI Log Analysis

Detail companion for SKILL.md Steps 2, 3, and 6.

## Step 2 — Fetch failing checks

### Pre-check (is `main` red?)

PR 회귀 fix 에 들어가기 전에 main 자체가 적색인지 먼저 확인한다.
dEitY719/dotfiles#755 의 28건 bats fail 처럼 PR 입장에선 inherited red — PR 차원의
fix 가 원천적으로 불가능한 케이스를 30분 분석 후에야 깨닫는 회귀를 막는다.

#### 1초 점검 명령

```bash
# 같은 워크플로의 main 최신 3 runs
GH_HOST="$TARGET_HOST" gh run list --repo "$TARGET_REPO" \
    --branch main \
    --workflow "$WORKFLOW_NAME" \
    --limit 3 \
    --json databaseId,conclusion,headSha,updatedAt
```

#### 판정 기준 — "same step as main"

같은 step 에서 fail 했다고 보려면 두 조건을 모두 만족해야 한다:

1. main 최신 3 runs 중 **2 개 이상** `conclusion == "failure"` (또는
   `"timed_out"`).
2. main 의 실패 run 과 PR run 이 **동일 job + 동일 step name** 에서
   터진다 — `GH_HOST="$TARGET_HOST" gh run view <main-run-id> --repo "$TARGET_REPO" --log-failed` 와
   같은 형태의 `<pr-run-id>` 조회 결과의 첫 `##[error]` /
   `Error:` 라인 (또는 첫 non-zero exit 의 step header) 이 일치하는지
   2초 비교.

두 조건 모두 참 → inherited red. 아래 메시지로 종료 — 라벨은 떼지 않는다
(CI 가 실제로 PR 회귀 없음을 증명하지 못한 상태):

```
[STOP] main 자체가 red — 이 PR 만의 회귀가 아니다 (같은 workflow, 같은 step).
  main 복구를 먼저 진행하거나, GH_PR_RESOLVE_CI_SKIP_MAIN_CHECK=1 로 강제 진행하세요.
```

#### False-positive — main 의 transient red

다음 케이스는 inherited red 가 **아니므로** pre-check 통과로 처리하고
통상 절차 진행:

- main 최신 3 runs 가 `failure / success / success` 처럼 1회만 fail
  이고 직후 run 이 다시 green — flaky / transient. 회복됨.
- main 의 실패 run 과 PR run 의 fail step name 이 다름 — 같은 적색이
  아니라 PR 만의 새 회귀.
- main 의 fail 이 24h 이상 지난 단발 — 최신 2 run 이 green 이면 무시.

#### Skip 조건

`GH_PR_RESOLVE_CI_SKIP_MAIN_CHECK=1` 가 set 이면 pre-check 를 건너뛴다 —
사용자가 의도적으로 main red 상태에서 PR fix 를 강제 진행하려는 경우
(e.g., main 회복 PR 자체의 CI 디버깅).

```bash
GH_HOST="$TARGET_HOST" gh pr checks "$PR_NUMBER" --repo "$TARGET_REPO" --required \
    --json name,state,workflow,link \
    --jq '[.[] | select(.state=="FAILURE")]'
```

### Filter rules

- `--required` — only required checks count. Non-required can stay red
  without blocking re-Approve, so this skill ignores them by default.
- `state == FAILURE` — explicit. `CANCELLED` and `TIMED_OUT` are
  treated separately (see in-progress carveout).
- Empty result → `[OK] no failing checks — nothing to resolve.` Exit
  success.

### In-progress carveout

If any check is `IN_PROGRESS` or `PENDING` when this skill runs, the
"all green" signal is unreliable. Print a 1-line warning and continue:

```
[WARN] <N> required checks still in progress — treating as green for now.
       If they go red after push, re-run /gh-resolve:ci-fail.
```

This is intentional — we'd rather get a fix queued than block on
flaky CI scheduling.

## Step 3 — Log triage

`HEAD_REF` is already bound in SKILL.md Step 1 (from the initial
`gh pr view --json number,state,headRefName` call) — reuse it,
do not re-fetch.

Fetch the recent run list **once** for the branch, then jq-filter
per failing workflow inside the loop:

```bash
# Pre-fetch once: most recent run for each workflow on this branch.
RUNS_JSON=$(GH_HOST="$TARGET_HOST" gh run list --repo "$TARGET_REPO" \
    --branch "$HEAD_REF" --limit 50 \
    --json databaseId,workflowName,headSha)

# In the per-failing-workflow loop:
for WF_NAME in $FAILING_WORKFLOWS; do
    RUN_ID=$(printf '%s' "$RUNS_JSON" \
        | jq -r --arg n "$WF_NAME" \
            '[.[] | select(.workflowName==$n)] | .[0].databaseId')
    GH_HOST="$TARGET_HOST" gh run view "$RUN_ID" --repo "$TARGET_REPO" --log-failed
done
```

One `gh run list` call instead of N. Cuts network/process overhead
when several workflows fail at once. Both `gh run list` and `gh run view`
take `--repo`, and both are host-pinned with `GH_HOST="$TARGET_HOST"` — never
rely on cwd-based repo detection (dEitY719/dotfiles#1403 /
dEitY719/dotfiles#1407, `references/github-target.md`).

Walk the log tail (last ~80 lines is usually enough; full log only if the
failure is upstream of a cascade) and read the reported file/line/assertion —
a current model does not need a lookup table to turn a lint, type-check, test,
build, or format-check error into a fix location.

### Heuristic for "no identifiable fix"

If the log shows:

- a Docker pull failure (`unauthorized: authentication required`),
- a network timeout (`dial tcp ... i/o timeout`),
- an OOM kill (`exit code 137`),
- a flaky test that passes locally,

→ surface the log to the user and **stop**. These are not code defects;
re-running the workflow is the right move, and this skill refuses to
push an unrelated commit just to trigger a re-run.

## Step 6 — `--wait` polling loop

Run `lib/wait-for-green.sh "$PR_NUMBER" "$WAIT_SECONDS"` (path relative to
this skill's base directory; requires `TARGET_REPO`/`TARGET_HOST` already
exported per `references/github-target.md`) instead of transcribing the
30s-interval poll loop by hand. Exit 0 = green within the timeout; exit 1 =
still pending/failing, after printing its own `[WARN] CI still pending
after <N>s — proceeding to label removal.` line — proceed to Step 7 either
way.

### Why the warn-and-proceed default

The user opted in to `--wait`, so they accept the race condition that
the label might come off while CI is still going. The alternative
(refusing to remove the label on timeout) would defeat the purpose of
the skill, which is to unblock reviewer re-approval.

If they want strict "only on green", they can omit `--wait` and run
the skill twice: once to push, once after CI is confirmed green to
remove the label (Step 5 push will no-op the second time since the
fix is already pushed).
