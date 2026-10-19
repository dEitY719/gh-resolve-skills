#!/usr/bin/env bash
# tests/bats/fixtures/review_passed_gh_stub.sh
# Shared `gh` stub for the three `review-passed` suites
# (gh_pr_resolve_{ci_fail,conflict,outdated}_review_passed.bats). Installed as
# a real executable on PATH, so it also reaches `gh` calls made by the shipped
# skills/{ci-fail,conflict,outdated}/lib/remove-review-passed.sh in a child bash.
#
# Every call is appended to $GH_LOG as `gh <args> [GH_HOST=<host>]`.
# STUB_MODE picks the label API's behaviour:
#   ok              every call succeeds (label present, DELETE works)
#   absent_blocked  DELETE 404s; the verification GET lists `CI fail` and
#                   `review-blocked` but not `review-passed`
#   fail            DELETE 403s; the verification GET still lists `review-passed`

# Usage: _review_passed_gh_stub_install   (call from setup())
_review_passed_gh_stub_install() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat >"$BATS_TEST_TMPDIR/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf 'gh %s [GH_HOST=%s]\n' "$*" "${GH_HOST-}" >>"$GH_LOG"
case "${STUB_MODE:-ok}:$*" in
    absent_blocked:*"-X DELETE"*)
        printf 'gh: Not Found (HTTP 404)\n' >&2; exit 1 ;;
    absent_blocked:*labels*)
        printf 'CI fail\nreview-blocked\n'; exit 0 ;;
    fail:*"-X DELETE"*)
        printf 'gh: Resource not accessible by integration (HTTP 403)\n' >&2; exit 1 ;;
    fail:*labels*)
        printf 'review-passed\n'; exit 0 ;;
esac
exit 0
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    GH_LOG="$BATS_TEST_TMPDIR/gh.log"
    : >"$GH_LOG"
    export PATH GH_LOG
}
