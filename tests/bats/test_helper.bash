#!/usr/bin/env bash
# tests/bats/test_helper.bash — shared setup for this repo's bats suites.
# Run: BATS_LIB_PATH=<dir with bats-support,bats-assert> bats -r tests/bats

bats_load_library bats-support
bats_load_library bats-assert

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# Temp HOME so no test reads or writes the developer's real config.
# SHELL_COMMON points at the vendored copy so tier 1 of the skills' helper
# lookup never reaches a developer's ~/dotfiles checkout.
setup_isolated_home() {
    TEST_TEMP_HOME="$(mktemp -d)"
    export HOME="$TEST_TEMP_HOME"
    unset CLAUDE_CONFIG_DIR CLAUDE_PLUGIN_ROOT
    export XDG_CONFIG_HOME="$TEST_TEMP_HOME"
    export XDG_CACHE_HOME="$TEST_TEMP_HOME"
    export XDG_DATA_HOME="$TEST_TEMP_HOME"
    export TERM=dumb
    export SHELL_COMMON="$REPO_ROOT/lib/vendor/shell-common"
}

teardown_isolated_home() {
    if [ -n "${TEST_TEMP_HOME:-}" ] && [ -d "$TEST_TEMP_HOME" ]; then
        rm -rf "$TEST_TEMP_HOME"
    fi
}
