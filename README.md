# gh-resolve-skills

Three skills for one job: getting a **blocked GitHub pull request** back to
mergeable. GitHub greys out a merge button for three reasons — red required
checks, a branch with conflicts, and a head that is behind its base — and this
repo has one skill per reason. Packaged as a single plugin named `gh-resolve`,
installable on six coding-agent harnesses.

Unlike its sibling [`harness-skills`](https://github.com/dEitY719/harness-skills),
this repo owns no shared assets — it links out for the
[per-harness tool mappings and the CI workflow](#shared-assets).

## Skills

| Skill | Invoke | What it does |
|-------|--------|--------------|
| `ci-fail` | `/gh-resolve:ci-fail [pr] [remote] [--wait <s>] [--label-variant <s>]` | Reads the failing required checks' logs, identifies the root cause, fixes it locally, re-runs the same lint/test command CI ran, fast-forward pushes, then removes the `CI fail` label. Never blind-retries a job. |
| `conflict` | `/gh-resolve:conflict [pr] [remote] [--worktree <path>]` | Rebases the head onto its base and walks each conflicting file with the user's intent, then pushes with `--force-with-lease` and clears the `conflict` label and board status. |
| `outdated` | `/gh-resolve:outdated [pr] [remote] [--worktree <path>]` | The cheap case: base moved, nothing conflicts. Clean rebase, `--force-with-lease` push, verify. Idempotent — safe to re-run. |

Pick by what GitHub is complaining about, not by what you would rather fix.
`outdated` refuses to do `conflict`'s job and hands off by exit code the moment
a rebase produces a conflict; `conflict` never reads CI logs; `ci-fail` never
rebases and never force-pushes.

Adjacent verbs live elsewhere: creating a PR (`gh:pr`), merging one
(`gh:pr-merge`), reviewing one (`devx:pr-review-all`), and replying to review
comments (`gh:pr-reply`) are all in other repos of this family. This repo starts
when a PR is blocked and stops when it is mergeable again.

## Requirements

| Need | Why |
|------|-----|
| `git` | All three rebase, commit, or push. |
| `gh`, authenticated per host | Every skill binds `TARGET_HOST` + `TARGET_REPO` from the remote URL and prefixes each API call with `GH_HOST=` (#1403), so GitHub Enterprise remotes work — but only if `gh` is logged into that host. |
| A checkout on the PR's head branch | Or a detached scratch worktree passed as `--worktree <path>` (`conflict` / `outdated` only), which makes the PR number mandatory. `gh:pr-merge-train` owns that worktree's lifecycle; these skills never create or remove it. |
| Not the default branch | All three refuse to run on the repo's default branch. |

## Install

### Claude Code

```
/plugin marketplace add dEitY719/gh-resolve-skills
/plugin install gh-resolve@gh-resolve-skills
```

### Codex

```
codex plugin install dEitY719/gh-resolve-skills
```

### Kimi CLI

```
kimi plugin install dEitY719/gh-resolve-skills
```

### Hermes Agent

```
hermes plugins install dEitY719/gh-resolve-skills
```

### OpenCode

See [`.opencode/INSTALL.md`](.opencode/INSTALL.md).

### Gemini CLI / Antigravity

```
gemini extensions install https://github.com/dEitY719/gh-resolve-skills
```

Antigravity (`agy`) shares `~/.gemini`, so it inherits the install.

## Harness support

These skills are `git`, `gh`, and local file edits, so they port well. The only
Claude-Code-specific capabilities they reach for are `AskUserQuestion` (the
conflict resolution loop) and `Skill()` (the `outdated` -> `conflict` handoff).
Every gap and its workaround is documented per harness in
[`harness-skills/references/`](https://github.com/dEitY719/harness-skills/tree/main/references);
read the one file for the harness you are on.

| Skill | Claude Code | Codex | Kimi | Gemini / Antigravity | Hermes | OpenCode |
|-------|:-----------:|:-----:|:----:|:--------------------:|:------:|:--------:|
| `ci-fail` | full | full | full | full | full | full |
| `conflict` | full | full, confirm in chat | full | full (Antigravity: confirm in chat) | full, confirm in chat | full, confirm in chat |
| `outdated` | full | full, manual handoff | full, manual handoff | full, manual handoff | full, manual handoff | full, manual handoff |

*confirm in chat* — `conflict` must stop and ask before resolving an ambiguous
hunk. Kimi (`AskUserQuestion`) and Gemini CLI (`ask_user`) have a structured
question tool; Codex, Hermes, Antigravity, and OpenCode do not, so ask in the
conversation and wait for a real reply. An auto-approve session setting is not
the user's answer.

*manual handoff* — `outdated` delegates a `CONFLICTING` PR to `conflict` by exit
code. Outside Claude Code there is no skill-invocation tool: print the exit code
and the follow-up command and stop. Do not inline the other skill's per-file
rebase loop.

## Shared assets

This repo owns none — deliberately.

- **Per-harness tool mappings** live in
  [`harness-skills/references/`](https://github.com/dEitY719/harness-skills/tree/main/references)
  (`{codex,kimi,gemini,antigravity,hermes,opencode}-tools.md`). That repo is
  their sole owner; the other fourteen `*-skills` repos link there rather than
  carrying copies, so one tool rename is one edit, not fifteen
  (dotfiles #1410 F-5 / NF-2). The only condensed mirror here is
  `.kimi-plugin/plugin.json`'s `skillInstructions`, because Kimi CLI cannot read
  a reference file at load time — it points back to the canonical file.
- **The reusable CI workflow** is
  [`harness-skills/.github/workflows/skill-check.yml`](https://github.com/dEitY719/harness-skills/blob/main/.github/workflows/skill-check.yml)
  (#1410 D-10). See [CI](#ci).

## Layout

Manifests live at the repo root and all point at one flat `skills/` directory:

```
.
├── skills/{ci-fail,conflict,outdated}/
│   ├── SKILL.md
│   ├── references/
│   └── evals/                                    (conflict, outdated)
├── .claude-plugin/{marketplace,plugin}.json      Claude Code
├── .codex-plugin/plugin.json                     Codex
├── .kimi-plugin/plugin.json                      Kimi CLI
├── .hermes-plugin/{plugin.yaml,__init__.py}      Hermes Agent
├── .opencode/plugins/gh-resolve.js + INSTALL.md  OpenCode
├── .agents/plugins/marketplace.json              Antigravity
├── gemini-extension.json + GEMINI.md             Gemini CLI
├── package.json
├── CLAUDE.md · AGENTS.md -> CLAUDE.md
└── LICENSE
```

Only Claude Code understands a nested `plugins/<name>/skills/` layout. The other
five harnesses resolve manifests at the repo root and a skills tree at
`./skills/`, so this repo keeps everything flat. See [`CLAUDE.md`](CLAUDE.md) for
the full rationale and contribution rules.

Skill directory names dropped the `gh-pr-resolve-` prefix they carried in
dotfiles: the plugin name already supplies the namespace, so
`/gh:pr-resolve-conflict` is now `/gh-resolve:conflict` and the old prefix would
only stutter.

The `.kimi-plugin/` manifest is pre-provisioned: Kimi CLI is not installed on the
maintainer's machines yet, and shipping the manifest now costs nothing and saves
a migration later.

## CI

[`.github/workflows/validate.yml`](.github/workflows/validate.yml) calls the
reusable workflow owned by `harness-skills`:

```yaml
jobs:
  validate:
    uses: dEitY719/harness-skills/.github/workflows/skill-check.yml@main
    with:
      plugin-name: gh-resolve
```

It validates manifests, skill frontmatter (the `name:` must be bare and match
the directory), progressive-disclosure line limits, the Codex description
budget, version agreement across all seven manifests, shell scripts, and the
no-emoji rule. There is no local copy to keep in sync; a check added upstream
applies here on the next run.

## Provenance

These skills were extracted from
[`dEitY719/dotfiles`](https://github.com/dEitY719/dotfiles)
(`claude/skills/gh-pr-resolve-{ci-fail,conflict,outdated}`) as a content
snapshot at source commit `b5f7fd1347e56c9a70e9b67ba15e7c5b7f1cf9ac` — no history
rewriting. The dotfiles copies remain in place; they are removed in Phase 4 of
that repo's migration. Behaviour is unchanged from the snapshot: only the
namespace moved, from `gh:pr-resolve-*` to `gh-resolve:*`, and the two oversized
`SKILL.md` files had detail relocated into their own `references/` to fit the
100-line progressive-disclosure limit.

This is Phase 2 of the dotfiles #1410 migration (tracking issue #1660).
`packaging-skills` was Phase 0; `harness-skills` — the sibling that owns the
shared assets this repo links to — and `pkm-skills` were Phase 1.

## License

MIT. See [LICENSE](LICENSE).
