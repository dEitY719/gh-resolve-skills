# gh-resolve:ci-fail — GitHub target binding (dEitY719/dotfiles#1403, dEitY719/dotfiles#1407)

Run this in Step 1, **before any `gh` call**.

## Bind the target

Resolve the host **and** the repo from one and the same remote URL, then export
the host so every sourced helper inherits it:

```bash
REMOTE="${REMOTE:-origin}"
_SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"                                  # tier 1
if [ ! -f "$_SC/functions/gh_host.sh" ]; then
    [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || {                                            # tier 5
        printf '[gh-resolve:ci-fail] no shell-common under %s, and CLAUDE_PLUGIN_ROOT is unset. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
            "$_SC" >&2
        return 1 2>/dev/null || exit 1
    }
    _SC="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"                                # tier 2
fi
unset -f _gh_resolve_host 2>/dev/null || :
[ -f "$_SC/functions/gh_host.sh" ] && . "$_SC/functions/gh_host.sh"
command -v _gh_resolve_host >/dev/null 2>&1 || {                                     # tier 5
    printf '[gh-resolve:ci-fail] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$_SC" >&2
    return 1 2>/dev/null || exit 1
}
export SHELL_COMMON="$_SC"
REMOTE_URL=$(git remote get-url "$REMOTE") || exit 1
TARGET_REPO=$(_gh_parse_owner_repo_url "$REMOTE_URL") || exit 1
TARGET_HOST=$(_gh_host_from_url "$REMOTE_URL") || TARGET_HOST=$(_gh_resolve_host)
export GH_HOST="$TARGET_HOST"
export TARGET_REPO TARGET_HOST
```

- `gh_host.sh` is the SSOT for the URL to host mapping — never copy a regex or a
  domain list into this file.
- `_gh_resolve_host` (setup-mode to host) is the fallback used **only** when
  there is no remote URL to parse.
- An unknown remote stops the run with `git remote -v` — never a silent
  `origin` fallback, which would mask a typo and target the wrong repo.
- Never continue with an empty `TARGET_HOST` — that is exactly the silent
  misroute state of dEitY719/dotfiles#1403.
- The `_SC` lookup order (tier 1 `DOTFILES_ROOT` -> tier 2 `CLAUDE_PLUGIN_ROOT`
  -> tier 5 stop) is the convention in
  [`harness-skills/references/plugin-root.md`](https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md) — the SSOT, not a local
  idiom. **There is no `$PWD` tier.** This skill runs inside the PR checkout
  under review, so `$PWD` is caller-controlled: a hostile PR that adds
  `lib/vendor/shell-common/functions/gh_host.sh` to its own tree would get it
  sourced here (dEitY719/harness-skills#22). An unset `CLAUDE_PLUGIN_ROOT` stops at
  tier 5 instead of constructing a path.
- The `unset -f` / `.` / `command -v` sequence is the proof, not a duplicate
  `[ -f ]`: it shows that *this* load, in *this* shell, defined the function —
  an existence test only says a file is there. The `export` comes after the
  proof, never inside the fallback branch.

## Host targeting rule

Every `gh` call in this skill — SKILL.md and `references/` alike — runs as:

```bash
GH_HOST="$TARGET_HOST" gh <sub-command> ... --repo "$TARGET_REPO"
```

Two sub-commands take no `--repo` flag; only the repo argument changes shape:

- `gh api` — the repo goes into the path:
  `GH_HOST="$TARGET_HOST" gh api "repos/$TARGET_REPO/..."`, never a literal
  `{owner}/{repo}`.
- `gh repo view` — the repo is **positional**:
  `GH_HOST="$TARGET_HOST" gh repo view "$TARGET_REPO" --json ...`. Passing
  `--repo` exits 1 with `unknown flag: --repo` (#10).

## Exception — `gh pr <verb>` with no PR argument

`gh pr view` (and any `gh pr <verb>` taking `[<number> | <url> | <branch>]`)
refuses `--repo` unless a PR argument is given:

```
$ gh pr view --repo <owner>/<repo> --json number
argument required when using the --repo flag
```

So the Step 1 auto-detect — the deliberately number-less `gh pr view` that reads
the PR off the **current branch** — runs with the host prefix only:

```bash
GH_HOST="$TARGET_HOST" gh pr view --json number,...
```

That still pins the server; `gh` then infers the repo from the current
checkout's remotes on that host. Every other call in this skill passes an
explicit `<N>` and therefore keeps `--repo "$TARGET_REPO"`.

## Why

`--repo <owner>/<repo>` carries no host, so a bare `gh` resolves that slug
against gh CLI's own `gh repo set-default` rather than git's `$REMOTE`. On a
dual-host login (github.com + a GHES instance) the two can disagree and `gh`
then hits the wrong server **with no error** — dEitY719/dotfiles#1403 is the case where an OPEN
issue came back as "not found".

This skill also writes: the Step 7 `CI fail` label DELETE and the ai-metrics
comment are the same misroute with a mutation attached, so the host pin is a
correctness requirement, not a nicety.
