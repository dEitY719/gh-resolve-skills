# gh-resolve-skills — Contributor Guidelines

This file is the AI context document for this repo. `AGENTS.md` is a symlink to
it, so Claude Code, Codex, Gemini CLI, and every other harness read the same
text. Edit `CLAUDE.md`; never replace the symlink with a second copy.

## What this repo is

A single-plugin skill marketplace. The plugin is named `gh-resolve` and it owns
exactly one axis of the PR lifecycle: **blocked-state recovery**. GitHub greys
out a merge button for three reasons, and there is one skill per reason.

| Skill | Blocker | Role |
|-------|---------|------|
| `ci-fail` | Required checks are red | Reads the failing run's logs, identifies the root cause, fixes it locally, re-runs the same command CI ran, fast-forward pushes, then removes the `CI fail` label. |
| `conflict` | "This branch has conflicts that must be resolved" | Rebases the head onto its base and walks each conflicting file with the user's intent, then pushes with `--force-with-lease`. |
| `outdated` | Head is behind the base, nothing conflicts | Clean rebase plus a `--force-with-lease` push. Hands off to `conflict` by exit code the moment a conflict appears. |

The three are deliberately not one skill. Each has a different failure mode, a
different push policy (`ci-fail` fast-forwards; the other two rewrite published
history), and a different stopping rule. Merging them would blur the one thing
that keeps them safe: knowing which blocker you are actually looking at.

Adjacent verbs stay out. Creating a PR (`gh-pr:create`), merging one (`gh-pr:merge`),
reviewing one (`gh-verify:review-all`), and replying to review comments
(`gh-pr:reply`) all live in other repos of this family. This repo starts when a
PR is blocked and stops when it is mergeable again.

The skills were extracted from `dEitY719/dotfiles`
(`claude/skills/gh-pr-resolve-{ci-fail,conflict,outdated}`) as a content
snapshot at source commit `b5f7fd1347e56c9a70e9b67ba15e7c5b7f1cf9ac` — no history
rewriting. The dotfiles copies were removed in Phase 4 of that repo's migration
plan (dEitY719/dotfiles#1410 NF-1 / NF-3), so that path no longer resolves there.
This is Phase 2 of dEitY719/dotfiles#1410 (tracking issue dEitY719/dotfiles#1660);
`packaging-skills` was Phase 0, and `harness-skills` and `pkm-skills` were
Phase 1.

The `gh-pr-resolve-` prefix was stripped on the way in. The plugin name already
supplies the namespace at invocation time, so `/gh:pr-resolve-conflict` became
`/gh-resolve:conflict` (dEitY719/dotfiles#1410 §4, issue
dEitY719/dotfiles#1660 F-2). Do not reintroduce the prefix, and do not
reintroduce the old dash-form aliases.

## Layout: root manifests, one flat `skills/`

This repo deliberately does **not** use the nested `plugins/<name>/skills/`
"mono" layout. Every harness manifest sits at the repo root and points at a
single flat `./skills/` directory:

```
.claude-plugin/{marketplace,plugin}.json   Claude Code
.codex-plugin/plugin.json                  Codex
.kimi-plugin/plugin.json                   Kimi CLI
.hermes-plugin/{plugin.yaml,__init__.py}   Hermes Agent
.opencode/plugins/gh-resolve.js            OpenCode
.agents/plugins/marketplace.json           Antigravity
gemini-extension.json + GEMINI.md          Gemini CLI
skills/<name>/SKILL.md                     the skills themselves
```

Only Claude Code understands the nested mono layout. The other five harnesses
resolve manifests at the repo root and a skills tree at `./skills/`, so nesting
would silently cut this plugin down to Claude-Code-only. **Do not move the
manifests under a `plugins/` directory.** CI fails if `plugins/` exists at all.

The OpenCode entry point's filename is load-bearing: it must be
`.opencode/plugins/<plugin-name>.js`, so `gh-resolve.js`. `package.json`'s
`main` points at the same path.

## Shared assets live elsewhere — link, never copy

This repo owns none. Both belong to `dEitY719/harness-skills`:

**1. Per-harness tool mappings** (`references/*-tools.md` there, dEitY719/dotfiles#1410
F-5). Do not create a `references/` directory at this repo's root — the only
`references/` here are the per-skill ones under `skills/<name>/`. If a doc here
needs a mapping, link to
`https://github.com/dEitY719/harness-skills/blob/main/references/<harness>-tools.md`.
One tool rename must stay one edit, not fifteen (NF-2). The single sanctioned
mirror is the condensed summary inside `.kimi-plugin/plugin.json`'s
`skillInstructions`, because Kimi CLI cannot read a reference file at load time;
keep it short and keep it pointing upstream.

**2. The reusable CI workflow** (`.github/workflows/skill-check.yml` there,
D-10). This repo's `validate.yml` calls it with `plugin-name: gh-resolve` and
nothing else. Do not fork it into a standalone workflow — a check added upstream
should apply here on the next run, which is the whole point.

## Rules for changing skills

- **Skill directory name is the identity.** `skills/<name>/` must match the
  `name:` field in that skill's `SKILL.md` frontmatter, and that field is the
  **bare** name (`conflict`), never namespaced (`gh-resolve:conflict`). CI fails
  on a `:` in the name and on any mismatch with the directory. The harness
  supplies the `gh-resolve:` prefix at invocation time.
- **Invocation form in prose is namespaced.** Body text referring to a skill in
  this repo as a command writes `/gh-resolve:conflict`.
- **Cross-repo references keep their own namespace.** `gh-pr:merge`, `gh-pr:create`,
  `gh-pr:commit`, `gh-pr:reply`, `gh-pr:merge-train`, `gh-flow:issue`, and
  `gh-verify:review-all` live in other repos of this family.
  Leave them exactly as written; only siblings inside `skills/` take the
  `gh-resolve:` prefix.
- **Progressive disclosure.** `SKILL.md` stays at or under 100 lines (CI
  enforces it) and names which `references/` file to read and when. Detail lives
  in `references/`. Do not inline a reference file back into `SKILL.md` — all
  three are within a line or two of the limit. When a step grows, move prose
  out; never delete a safety rule to buy lines.
- **Description budget.** CI sums every skill description and fails past 5,440
  characters — Codex's context budget — with a per-description cap of 1,024.
  Keep new descriptions tight, and keep the "not this, that" disambiguation:
  the three skills sit in the same lifecycle slot and are told apart only by
  which blocker they name.
- **Honour each skill's safety contract.** These are acceptance criteria, not
  advice, and every one of them is load-bearing:
  - `conflict` and `outdated` push with `--force-with-lease` and **never** plain
    `--force`. A rejected lease means someone pushed while you rebased: stop,
    surface the divergence, let the user decide. Never re-fetch and re-rebase on
    their behalf — that is how a colleague's commit disappears.
  - `conflict` never auto-resolves an ambiguous hunk and never introduces a
    merge commit. Ask, and wait for a real answer.
  - `outdated` never resolves a conflict itself. It aborts the rebase and hands
    off to `conflict` with a documented exit code.
  - `ci-fail` fast-forward pushes only — no force of any kind — and must not
    push while local lint/test is still red (the CI infinite-loop guard). It
    removes the `CI fail` label only after the push succeeds, so a failed push
    leaves the label and reviewers still see red. It never blind-retries a job.
  - None of the three runs on the repo's default branch. None creates or removes
    a `--worktree` path; the caller owns that lifecycle.
  - All three print `BACKUP_SHA` before touching history.
  - None adds `review-passed` / `review-blocked`, and none removes
    `review-blocked` — no skill here has evidence the blockers were addressed.
    Dropping a stale `review-passed` after a successful force-push is mandatory
    (dEitY719/dotfiles#1563).
- **Host pinning is not optional.** Every skill binds `TARGET_HOST` +
  `TARGET_REPO` from the remote URL before any `gh` call and prefixes each call
  with `GH_HOST=` (dEitY719/dotfiles#1403). Dropping the prefix sends a GHES repo's request to
  `github.com`. The one documented exception is the branch-detecting
  `gh pr view` with no PR argument, which cannot take `--repo`.

## Version bumps

The version appears in seven manifests: `.claude-plugin/marketplace.json`
(`plugins[0].version`), `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
`.kimi-plugin/plugin.json`, `.hermes-plugin/plugin.yaml`,
`gemini-extension.json`, and `package.json`. CI checks that they agree — bump
all of them together. Versioning is independent per repo (dEitY719/dotfiles#1410 D-9); this repo
does not move in lockstep with its siblings.

## No emojis

Anywhere in this repo. Token efficiency, and CI rejects them (it flags any
codepoint at or above `U+1F000`, plus `U+FE0F`).
