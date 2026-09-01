# Installing gh-resolve for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- `git` and the GitHub CLI (`gh`), authenticated against every host you open PRs
  on. All three skills bind `TARGET_HOST` / `TARGET_REPO` from the remote URL and
  prefix each API call with `GH_HOST=`, so a GHES remote works — but only if `gh`
  is logged into that host.
- A checkout of the repo whose PR you are unblocking, on the PR's head branch
  (or a scratch worktree passed with `--worktree`).

## Installation

Add the plugin to the `plugin` array in your `opencode.json` (global or
project-level):

```json
{
  "plugin": ["gh-resolve-skills@git+https://github.com/dEitY719/gh-resolve-skills.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers all three skills.

OpenCode uses its own plugin install. If you also use Claude Code, Codex, or
another harness, install this plugin separately for each one.

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load conflict
```

## Tool mapping

The authoritative OpenCode tool mapping for every `dEitY719/*-skills` repo lives
in the sibling repo `harness-skills`, at
[`references/opencode-tools.md`](https://github.com/dEitY719/harness-skills/blob/main/references/opencode-tools.md).
This repo owns no copy — one tool rename must stay one edit. Read it when a
skill names a tool you do not recognise. Short version:

- "Read a file" -> `read`
- "Create a file" / "edit a file" -> `apply_patch`
- "Run a shell command" -> `bash` (this is how every `git` and `gh` call is made)
- "Search file contents" / "find files by name" -> `grep`, `glob`
- "Create a todo" -> `todowrite`
- "Dispatch a subagent" -> `task` with `subagent_type: "general"` (or
  `"explore"` for read-only exploration)
- "Invoke a skill" -> OpenCode's native `skill` tool

Two gaps matter here:

- OpenCode has no structured question tool. `conflict` must stop and ask before
  resolving an ambiguous hunk: ask in the conversation and wait for a real
  answer. An auto-approve session setting is not the user's answer.
- `outdated` hands a `CONFLICTING` PR off to `conflict` by exit code. Without a
  skill-invocation tool, print the exit code and the follow-up command and stop;
  do not inline the other skill's per-file rebase loop.

## Safety contracts

- `conflict` and `outdated` push with `--force-with-lease`, never plain
  `--force`. A rejected lease means someone else pushed — stop and surface the
  divergence; never re-fetch and re-rebase on the user's behalf.
- `ci-fail` fast-forward pushes only, and refuses to push while local lint/test
  is still red. It removes the `CI fail` label only after the push lands, and
  never blind-retries a failing job.
- No skill here runs on the repo's default branch, and none creates or removes a
  `--worktree` path — the caller owns that lifecycle.
- All three print `BACKUP_SHA` before touching history so you can
  `git reset --hard <sha>`.

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i gh-resolve`
2. Verify the plugin line in your `opencode.json`
3. Make sure you are running a recent version of OpenCode

### Skills not found

1. Use the `skill` tool to list what was discovered
2. Check that the plugin is loading (see above)

### Every `gh` call fails immediately

`gh` is not authenticated for the host the remote points at. Run
`gh auth login --hostname <host>`. The skills fail loudly rather than falling
back to `github.com`.

## Getting Help

Report issues: https://github.com/dEitY719/gh-resolve-skills/issues
