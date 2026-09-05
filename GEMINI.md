# gh-resolve — skill index

Three skills for one job: getting a blocked GitHub pull request back to
mergeable. Each lives in this extension's `skills/` directory. They are
explicitly invoked, never ambient: load the one that matches the blocker by
reading its `SKILL.md`, then follow it. Do not load all three.

| Skill | Read | Use when |
|-------|------|----------|
| `ci-fail` | `@./skills/ci-fail/SKILL.md` | Required checks are red. Reads the failing run's logs, fixes the cause locally, re-runs the same command CI ran, fast-forward pushes, then removes the `CI fail` label. |
| `conflict` | `@./skills/conflict/SKILL.md` | GitHub shows "This branch has conflicts that must be resolved". Rebases onto the base and walks each conflicting file with the user. Not for an Obsidian vault conflict — that is `pkm:obsidian-resolve-conflict`, in another repo. |
| `outdated` | `@./skills/outdated/SKILL.md` | The base moved but nothing conflicts. Clean rebase, `--force-with-lease` push, and an exit-code handoff to `conflict` the moment a conflict appears. |

Pick by what GitHub is complaining about, not by what you would like to fix.
`outdated` is the cheap case and refuses to do `conflict`'s job; `conflict`
never reads CI logs; `ci-fail` never rebases.

Each skill's `references/` directory holds the detail it loads on demand.
`SKILL.md` says which file to read and when — do not read `references/` up
front.

## What each skill needs

- `git`, and `gh` authenticated for the host the remote points at. Each skill
  binds `TARGET_HOST` + `TARGET_REPO` from the remote URL **before any `gh`
  call** and prefixes every call with `GH_HOST=` (dEitY719/dotfiles#1403). A GHES
  remote resolves to the wrong server without that prefix, so never drop it.
- A checkout on the PR's head branch — or, for `conflict` and `outdated`, a
  detached scratch worktree passed as `--worktree <path>`. That flag makes the
  PR number mandatory and is normally supplied by `gh-pr:merge-train`, which
  owns the worktree's creation and removal.
- The current branch must not be the repo's default branch. All three refuse.

## Tool mapping for Gemini CLI

The skills speak in actions. On Gemini CLI these resolve to:

- "Read a file" -> `read_file` / `read_many_files`
- "Create a file" / "edit a file" -> `write_file`, `replace`
- "Run a shell command" -> `run_shell_command` (this is how every `git` and `gh`
  call is made)
- "Search file contents" -> `grep_search`
- "Find files by name" -> `glob`
- "Create a todo" -> `write_todos`
- "Ask the user" -> `ask_user`
- "Dispatch a subagent" -> `invoke_agent` with `agent_name: "generalist"`

The full mapping, including every capability gap and its workaround, lives in
the sibling repo: `https://github.com/dEitY719/harness-skills/blob/main/references/gemini-tools.md`.
This repo owns no copy. Read it when a skill names a tool you do not recognise.
On Antigravity read `antigravity-tools.md` in that same directory instead —
`agy` shares `~/.gemini` but not Gemini CLI's tool names.

## Capability gaps on Gemini CLI

- `outdated` hands a `CONFLICTING` PR to `conflict` by exit code, and Gemini has
  no skill-invocation tool. Print the exit code and the follow-up command and
  stop; do not inline the other skill's per-file rebase loop.
- `ci-fail` declares `Edit` / `Write` for the local fix — `replace` and
  `write_file`. Nothing else here is Claude-Code-specific: `git`, `gh`, and the
  lint/test commands all run unchanged under `run_shell_command`. Pass their
  `[OK]` / `[WARN]` / `[FAIL]` lines through verbatim rather than summarising.
- On Antigravity, `ask_user` does not exist — ask in the conversation and wait
  for a real reply before resolving any ambiguous conflict.

## Safety rules

- `conflict` and `outdated` rewrite published history. `--force-with-lease`
  only, never plain `--force`. A rejected lease means someone pushed while you
  rebased: stop, surface the divergence, and let the user decide. Never
  re-fetch and re-rebase on their behalf — that is how you lose their commit.
- `conflict` never auto-resolves an ambiguous hunk and never introduces a merge
  commit. Use `ask_user` and wait for a real answer.
- `ci-fail` fast-forward pushes only — no force of any kind — and must not push
  while the local lint/test run is still red. That is the CI infinite-loop
  guard. It removes the `CI fail` label only after the push succeeds; a failed
  push leaves the label so reviewers still see red.
- None of the three runs on the repo's default branch, and none creates or
  removes a `--worktree` path.
- All three print `BACKUP_SHA` before touching history, so the user can
  `git reset --hard <sha>` without you.
- None of them adds `review-passed` or `review-blocked`, and none removes
  `review-blocked` — no skill here has evidence the blockers were addressed.
  Dropping a stale `review-passed` after a successful force-push is mandatory
  (dEitY719/dotfiles#1563).
