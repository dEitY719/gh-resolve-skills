# gh-resolve:ci-fail — Label Normalization

F-7 SSOT: variant inputs that the operator (or a typo-prone teammate)
might pass via `--label-variant <input>` map to the canonical GitHub label
`CI fail`. Canonical name: `CI fail`. Accepted variants: case, `-`/`_`/`/`
separator, the `fial` typo, and a past-tense `failed` slip; anything else
fails fast (`lib/normalize-label.sh` is the SSOT for the exact rule).

## Lookup

Run `lib/normalize-label.sh "<input>"` (path relative to this skill's base
directory) instead of transcribing the lookup by hand:

```bash
CANONICAL=$(lib/normalize-label.sh "$LABEL_VARIANT_INPUT")
```

stdout `CI fail` + exit 0 on a match; exit 1 + the fail-fast message
(canonical name + accepted-variant list) on stderr otherwise — print that
message verbatim and stop.

## Future: external SSOT yaml

Open Question from issue dEitY719/dotfiles#673: should this table move to
`.gh-pr-labels.yml` at the repo root so AgentToolbox / dotfiles / etc.
can each declare their own label conventions? Defer until a second
repo with different label naming actually appears. KISS — internal
table is fine for v1.
