#!/usr/bin/env bats

setup() {
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
    export OP_ARGS_LOG="$BATS_TEST_TMPDIR/op-args.log"
    export WATCH_FILE_LOG="$BATS_TEST_TMPDIR/watch-file.log"
    : >"$OP_ARGS_LOG"
    : >"$WATCH_FILE_LOG"
}

run_envrc() {
    local envrc=$1

    # TEST_BASH selects the bash that runs the script under test.
    # shellcheck disable=SC2016
    run "${TEST_BASH:-bash}" -c '
        set -euo pipefail
        # Masking is opt-in per test.
        unset GITHUB_ACTIONS
        cd "$1"
        source ./tests/stubs.bash
        source ./1password.sh
        source "$2"
    ' bash "$REPO_ROOT" "$envrc" </dev/null
}

@test "fetches one secret into the specified environment variable" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "MY_SECRET=single-secret" ]
}

@test "fetches multiple secrets from stdin" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op <<OP
FIRST_SECRET=op://vault/first/field
OTHER_SECRET=op://vault/other/field
OP
printf 'FIRST_SECRET=%s\n' "$FIRST_SECRET"
printf 'OTHER_SECRET=%s\n' "$OTHER_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "FIRST_SECRET=first-secret" ]
    [ "${lines[1]}" = "OTHER_SECRET=other-secret" ]
}

@test "fetches secrets from a stdin heredoc" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op <<stdin
MY_SECRET=op://vault/item/field
stdin
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "MY_SECRET=single-secret" ]
}

@test "fetches secrets from an indented stdin heredoc" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op <<OP
    FIRST_SECRET=op://vault/first/field
    OTHER_SECRET=op://vault/other/field
OP
printf 'FIRST_SECRET=%s\n' "$FIRST_SECRET"
printf 'OTHER_SECRET=%s\n' "$OTHER_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "FIRST_SECRET=first-secret" ]
    [ "${lines[1]}" = "OTHER_SECRET=other-secret" ]
}

@test "preserves dollar signs in secret values" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op MY_SECRET=op://vault/dollar/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    expected=MY_SECRET=pa\$\$word\$with\$dollars
    [ "$output" = "$expected" ]
}

@test "preserves quotes, backslashes and backticks in secret values" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op MY_SECRET=op://vault/quotes/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = $'MY_SECRET=it\'s "quoted" \\back\\slash `cmd`' ]
}

@test "fetches multiple secrets from a file and watches it" {
    secrets_file="$BATS_TEST_TMPDIR/.1password"
    cat >"$secrets_file" <<'BASH'
FILE_SECRET=op://vault/file/field
BASH

    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<BASH
from_op "$secrets_file"
printf 'FILE_SECRET=%s\n' "\$FILE_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "FILE_SECRET=file-secret" ]
    [ "$(<"$WATCH_FILE_LOG")" = "$secrets_file" ]
}

@test "does not overwrite an existing environment variable with --no-overwrite" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
MY_SECRET=from-dotenv
dotenv_if_exists
from_op --no-overwrite MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "MY_SECRET=from-dotenv" ]
    [ ! -s "$OP_ARGS_LOG" ]
}

@test "loads an unset environment variable with --no-overwrite" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
dotenv_if_exists
from_op --no-overwrite MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "MY_SECRET=single-secret" ]
}

@test "loads an indented unset environment variable with --no-overwrite" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
dotenv_if_exists
from_op --no-overwrite <<OP
    MY_SECRET=op://vault/item/field
OP
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "MY_SECRET=single-secret" ]
}

@test "loads a tab-indented unset environment variable with --no-overwrite" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    printf '%s\n' \
        'dotenv_if_exists' \
        'from_op --no-overwrite <<OP' \
        $'\tMY_SECRET=op://vault/item/field' \
        'OP' \
        "printf 'MY_SECRET=%s\\n' \"\$MY_SECRET\"" >"$envrc"

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "MY_SECRET=single-secret" ]
}

@test "uses a specific 1Password account and logs status when verbose" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op --account my.1password.com --verbose MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"STATUS: from_op: Loading variables from 1Password"* ]]
    [[ $output == *"MY_SECRET=single-secret"* ]]
    [ "$(<"$OP_ARGS_LOG")" = "--account my.1password.com" ]
}

@test "masks secret values when running in GitHub Actions" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export GITHUB_ACTIONS=true
from_op MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "::add-mask::single-secret" ]
    [ "${lines[1]}" = "MY_SECRET=single-secret" ]
}

@test "does not mask secret values in GitHub Actions with --no-gha-masking" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export GITHUB_ACTIONS=true
from_op --no-gha-masking MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output != *"::add-mask::"* ]]
    [ "$output" = "MY_SECRET=single-secret" ]
}

@test "preserves multi-line secret values" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op MY_KEY=op://vault/multiline/field
printf '%s' "$MY_KEY" >"$BATS_TEST_TMPDIR/value"
printf 'OTHER_SECRET=%s\n' "${OTHER_SECRET:-unset}"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "OTHER_SECRET=unset" ]
    expected=$'-----BEGIN KEY-----\nline1\n\nOTHER_SECRET=not-a-var\n-----END KEY-----\n'
    [ "$(cat "$BATS_TEST_TMPDIR/value" && printf x)" = "${expected}x" ]
}

@test "preserves leading and trailing whitespace in secret values" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op MY_SECRET=op://vault/spaces/field
printf '[%s]\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = $'[ \tpadded secret \t]' ]
}

@test "ignores whitespace, blank lines and comments in the input" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    printf '%s\n' \
        'from_op <<OP' \
        '' \
        '  # comment' \
        $'\tFIRST_SECRET=op://vault/first/field \t' \
        'OTHER_SECRET=op://vault/other/field' \
        'OP' \
        "printf 'FIRST_SECRET=[%s]\\n' \"\$FIRST_SECRET\"" \
        "printf 'OTHER_SECRET=[%s]\\n' \"\$OTHER_SECRET\"" >"$envrc"

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "FIRST_SECRET=[first-secret]" ]
    [ "${lines[1]}" = "OTHER_SECRET=[other-secret]" ]
}

@test "fails on an invalid variable definition" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op <<OP
MY_SECRET=op://vault/item/field
not a variable
OP
printf 'MY_SECRET=%s\n' "${MY_SECRET:-unset}"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 1 ]
    [ "$output" = "ERROR: from_op: Invalid variable definition: not a variable" ]
    [ ! -s "$OP_ARGS_LOG" ]
}

@test "masks each value once, URL-encoded, in GitHub Actions" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export GITHUB_ACTIONS=true
from_op <<OP
EMPTY=op://vault/empty/field
PERCENT=op://vault/percent/field
MULTI=op://vault/multiline/field
OP
printf 'done\n'
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "::add-mask::100%25%0D%0A" ]
    [ "${lines[1]}" = "::add-mask::-----BEGIN KEY-----%0Aline1%0A%0AOTHER_SECRET=not-a-var%0A-----END KEY-----%0A" ]
    [ "${lines[2]}" = "done" ]
    [ "${#lines[@]}" -eq 3 ]
}

@test "fails without exporting anything on unexpected op output" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
op() { printf 'garbage\n'; }
from_op MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "${MY_SECRET:-unset}"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 1 ]
    [ "$output" = "ERROR: from_op: Unexpected output from 'op inject'" ]
}

@test "ignores stdin when arguments are given" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op MY_SECRET=op://vault/item/field <<OP
OTHER_SECRET=op://vault/other/field
OP
printf 'MY_SECRET=%s\n' "$MY_SECRET"
printf 'OTHER_SECRET=%s\n' "${OTHER_SECRET:-unset}"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "MY_SECRET=single-secret" ]
    [ "${lines[1]}" = "OTHER_SECRET=unset" ]
}

@test "reads stdin in addition to arguments with -" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op MY_SECRET=op://vault/item/field - <<OP
OTHER_SECRET=op://vault/other/field
OP
printf 'MY_SECRET=%s\n' "$MY_SECRET"
printf 'OTHER_SECRET=%s\n' "$OTHER_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "MY_SECRET=single-secret" ]
    [ "${lines[1]}" = "OTHER_SECRET=other-secret" ]
}

@test "warns about an unreadable file and continues" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op missing.1password MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "ERROR: from_op: Cannot read file: missing.1password" ]
    [ "${lines[1]}" = "MY_SECRET=single-secret" ]
    [ "$(<"$WATCH_FILE_LOG")" = "missing.1password" ]
}

@test "fails on an unknown option" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op --bogus MY_SECRET=op://vault/item/field
BASH

    run_envrc "$envrc"

    [ "$status" -eq 1 ]
    [ "$output" = "ERROR: from_op: Unknown option: --bogus" ]
    [ ! -s "$OP_ARGS_LOG" ]
}

@test "fails when --account has no argument" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op MY_SECRET=op://vault/item/field --account
BASH

    run_envrc "$envrc"

    [ "$status" -eq 1 ]
    [ "$output" = "ERROR: from_op: --account requires an argument" ]
    [ ! -s "$OP_ARGS_LOG" ]
}

@test "fails without exporting anything when op inject fails" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
op() { printf 'op: not signed in\n' >&2; return 1; }
from_op MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "${MY_SECRET:-unset}"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 1 ]
    [ "${lines[0]}" = "op: not signed in" ]
    [ "${lines[1]}" = "ERROR: from_op: 1Password injection failed" ]
}

@test "logs when there is nothing to load with --verbose" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
MY_SECRET=from-dotenv
from_op --verbose --no-overwrite MY_SECRET=op://vault/item/field
printf 'MY_SECRET=%s\n' "$MY_SECRET"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "STATUS: from_op: No variables to load from 1Password" ]
    [ "${lines[1]}" = "MY_SECRET=from-dotenv" ]
    [ ! -s "$OP_ARGS_LOG" ]
}

@test "exports variables named like the function's locals" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op VERBOSE=op://vault/first/field line=op://vault/other/field
printf 'VERBOSE=%s\n' "$VERBOSE"
printf 'line=%s\n' "$line"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "VERBOSE=first-secret" ]
    [ "${lines[1]}" = "line=other-secret" ]
}
