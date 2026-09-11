#!/usr/bin/env bats

setup() {
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
    export OP_ARGS_LOG="$BATS_TEST_TMPDIR/op-args.log"
    export OP_WHOAMI_LOG="$BATS_TEST_TMPDIR/op-whoami.log"
    export OP_SIGNIN_LOG="$BATS_TEST_TMPDIR/op-signin.log"
    export OP_SESSION_SENTINEL="$BATS_TEST_TMPDIR/op-session"
    export OP_STUB_BIN="$BATS_TEST_TMPDIR/bin"
    export WATCH_FILE_LOG="$BATS_TEST_TMPDIR/watch-file.log"
    : >"$OP_ARGS_LOG"
    : >"$OP_WHOAMI_LOG"
    : >"$OP_SIGNIN_LOG"
    : >"$WATCH_FILE_LOG"
    rm -f "$OP_SESSION_SENTINEL"
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

@test "succeeds silently when a session is already active" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op_signin
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -s "$OP_WHOAMI_LOG" ]
    [ ! -s "$OP_SIGNIN_LOG" ]
}

@test "reports how to sign in with --no-interactive" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
rc=0
from_op_signin --no-interactive || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"exit=1"* ]]
    [[ $output == *'ERROR: from_op_signin: No active 1Password session for my.1password.com.'* ]]
    # shellcheck disable=SC2016 # the hint is a literal, not an expansion
    [[ $output == *'eval "$(op signin --account my.1password.com)"'* ]]
    [[ $(<"$OP_WHOAMI_LOG") == *"--account my.1password.com"* ]]
    [ ! -s "$OP_SIGNIN_LOG" ]
}

@test "signs in when there is no session" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
from_op_signin
printf 'OP_SESSION_test=%s\n' "$OP_SESSION_test"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "OP_SESSION_test=stub-token" ]
    [ "$(wc -l <"$OP_SIGNIN_LOG")" -eq 1 ]
    [[ $(<"$OP_SIGNIN_LOG") == *"--account my.1password.com"* ]]
}

@test "does not retry when the sign-in fails" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
export OP_STUB_SIGNIN_SUCCEEDS=0
rc=0
from_op_signin || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"exit=1"* ]]
    [[ $output == *"ERROR: from_op_signin: No active 1Password session"* ]]
    [[ $output != *"authorization prompt dismissed"* ]]
    [ "$(wc -l <"$OP_SIGNIN_LOG")" -eq 1 ]
}

@test "uses a specific 1Password account" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
from_op_signin --account my.1password.com
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $(<"$OP_WHOAMI_LOG") == *"--account my.1password.com"* ]]
    [[ $(<"$OP_SIGNIN_LOG") == *"--account my.1password.com"* ]]
}

@test "names the account in the sign-in hint when one is given" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
from_op_signin --no-interactive --account my.1password.com || true
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    # shellcheck disable=SC2016 # the hint is a literal, not an expansion
    [[ $output == *'eval "$(op signin --account my.1password.com)"'* ]]
}

@test "uses OP_ACCOUNT instead of the fallback account" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
export OP_STUB_SIGNIN_SUCCEEDS=0
export OP_ACCOUNT=team.1password.com
rc=0
from_op_signin || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"exit=1"* ]]
    [[ $output == *"ERROR: from_op_signin: No active 1Password session for OP_ACCOUNT (team.1password.com)."* ]]
    [[ $output == *"pass --account ACCOUNT"* ]]
    [[ $(<"$OP_WHOAMI_LOG") != *"--account my.1password.com"* ]]
    [[ $(<"$OP_SIGNIN_LOG") != *"--account my.1password.com"* ]]
    [ "$(<"$OP_WHOAMI_LOG")" = "--format=json" ]
    [ -z "$(<"$OP_SIGNIN_LOG")" ]
}

@test "logs the session status and the error of op when verbose" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
from_op_signin --verbose
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"STATUS: from_op_signin: [ERROR] you are not currently signed in"* ]]
    [[ $output == *"STATUS: from_op_signin: Signing in to 1Password"* ]]
    [[ $output == *"STATUS: from_op_signin: Signed in to 1Password"* ]]
}

@test "stays silent about a failure with --quiet" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
export OP_STUB_SIGNIN_SUCCEEDS=0
rc=0
from_op_signin --quiet || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ "$output" = "exit=1" ]
}

@test "accepts a timeout" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
from_op_signin --timeout 5
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ -s "$OP_WHOAMI_LOG" ]
}

@test "gives up when 1Password does not answer within the timeout" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_WHOAMI_DELAY=10
rc=0
from_op_signin --no-interactive --timeout 1 || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"exit=1"* ]]
    [[ $output == *"from_op_signin: 1Password did not answer in 1s"* ]]
}

@test "rejects an invalid timeout" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
rc=0
from_op_signin --timeout soon || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"exit=1"* ]]
    [[ $output == *"ERROR: from_op_signin: --timeout requires a positive number of seconds: soon"* ]]
    [ ! -s "$OP_WHOAMI_LOG" ]
}

@test "checks the session without timeout(1) available" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
PATH=""
rc=0
from_op_signin --no-interactive || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"exit=1"* ]]
    [ -s "$OP_WHOAMI_LOG" ]
}

@test "skips the session check when a service account token is set" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
export OP_SERVICE_ACCOUNT_TOKEN=ops_token
from_op_signin
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -s "$OP_WHOAMI_LOG" ]
    [ ! -s "$OP_SIGNIN_LOG" ]
}

@test "skips the session check when 1Password Connect is configured" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_STUB_SIGNED_IN=0
export OP_CONNECT_HOST=http://localhost:8080
export OP_CONNECT_TOKEN=connect_token
from_op_signin
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -s "$OP_WHOAMI_LOG" ]
}

@test "checks the session when only the Connect host is set" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
export OP_CONNECT_HOST=http://localhost:8080
from_op_signin
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [ -s "$OP_WHOAMI_LOG" ]
}

@test "fails when the 1Password CLI is not installed" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
has() { return 1; }
rc=0
from_op_signin || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"exit=2"* ]]
    [[ $output == *"ERROR: 1Password CLI 'op' not found"* ]]
    [ ! -s "$OP_WHOAMI_LOG" ]
}

@test "fails on an unknown option" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
rc=0
from_op_signin --nope || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"exit=1"* ]]
    [[ $output == *"ERROR: from_op_signin: Unknown option: --nope"* ]]
    [ ! -s "$OP_WHOAMI_LOG" ]
}

@test "fails on an unexpected argument" {
    envrc="$BATS_TEST_TMPDIR/envrc"
    cat >"$envrc" <<'BASH'
rc=0
from_op_signin my.1password.com || rc=$?
printf 'exit=%s\n' "$rc"
BASH

    run_envrc "$envrc"

    [ "$status" -eq 0 ]
    [[ $output == *"exit=1"* ]]
    [[ $output == *"ERROR: from_op_signin: Unexpected argument: my.1password.com"* ]]
}
