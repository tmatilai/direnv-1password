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

    run bash -c '
        set -euo pipefail
        cd "$1"
        source ./tests/stubs.bash
        source ./1password.sh
        source "$2"
    ' bash "$REPO_ROOT" "$envrc"
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
