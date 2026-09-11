#!/usr/bin/env bash
#
###########################################################################
# 1Password helpers for direnv configuration.
#
# VERSION:
#    1.1.0
#
# HOMEPAGE:
#     https://github.com/tmatilai/direnv-1password
#
# INSTALL:
#     Copy this to `~/.config/direnv/lib/1password.sh` or download with
#     `source_url` command in the direnv configuration.
#     See the homepage for details.
#
# LICENCE:
#     MIT licence - Copyright (c) 2022-2025 Teemu Matilainen and contributors
#
###########################################################################

# Read environment variable values from 1Password.
from_op() {
    local OP_VARIABLES=()
    local OP_FILES=()
    local OP_OPTIONS=()
    local OVERWRITE_ENVVARS=1
    local SIGNIN=0
    local VERBOSE=0
    local GHA_MASKING=1
    [[ ${GITHUB_ACTIONS:-} == "true" ]] || GHA_MASKING=0
    local VALID_VAR_NAME_REGEX='[A-Za-z_][A-Za-z0-9_]*'

    if ! has op; then
        log_error "1Password CLI 'op' not found"
        return 1
    fi

    case "$(op --version)" in
        1.*)
            log_error "1Password CLI v1 is no longer supported. Please upgrade to 1password CLI v2. See https://developer.1password.com/docs/cli/upgrade/"
            return 1
            ;;
    esac

    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-overwrite)
                OVERWRITE_ENVVARS=0
                shift
                ;;
            --signin)
                SIGNIN=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --no-gha-masking)
                GHA_MASKING=0
                shift
                ;;
            --account)
                if [[ $# -lt 2 ]]; then
                    log_error "from_op: --account requires an argument"
                    return 1
                fi
                OP_OPTIONS+=(--account "$2")
                shift 2
                ;;
            --*)
                log_error "from_op: Unknown option: $1"
                return 1
                ;;
            *=*)
                OP_VARIABLES+=("$1")
                shift
                ;;
            *)
                OP_FILES+=("$1")
                watch_file "$1"
                shift
                ;;
        esac
    done

    if [[ -t 0 ]] && [[ ${#OP_VARIABLES[@]} -eq 0 ]] && [[ ${#OP_FILES[@]} -eq 0 ]]; then
        log_error "from_op: No input nor arguments given"
        return 1
    fi

    local OP_INPUT
    OP_INPUT="$(
        # Concatenate variable-args, file-args and stdin.
        printf '%s\n' "${OP_VARIABLES[@]}"
        if [[ ${#OP_FILES[@]} -gt 0 ]]; then
            # Read files if they exist; warn if not.
            for f in "${OP_FILES[@]}"; do
                if [[ -r $f ]]; then
                    cat "$f"
                else
                    log_error "from_op: Cannot read file: $f"
                fi
            done
        fi
        [[ -t 0 ]] || cat
    )"

    if [[ $OVERWRITE_ENVVARS -eq 0 ]]; then
        # Remove variables from OP_INPUT that are already set in the environment.
        OP_INPUT="$(
            printf '%s\n' "$OP_INPUT" | while read -r line; do
                # Skip empty lines and comments
                [[ -z $line || $line =~ ^[[:space:]]*# ]] && continue

                # Validate variable name matches shell identifier rules
                if [[ $line =~ ^[[:space:]]*($VALID_VAR_NAME_REGEX)[[:space:]]*= ]]; then
                    VARIABLE_NAME="${BASH_REMATCH[1]}"
                    # Respect --no-overwrite even if the variable is set to empty.
                    if [[ -z ${!VARIABLE_NAME+x} ]]; then
                        printf '%s\n' "$line"
                    fi
                fi
            done
        )"
    fi

    if [[ -z $OP_INPUT ]]; then
        # There are no environment variables to load from op, no need to run op.
        [[ $VERBOSE -eq 0 ]] || log_status "from_op: No variables to load from 1Password"
        return 0
    fi

    if [[ $SIGNIN -ne 0 ]]; then
        # Opt-in only: without `--signin` none of this runs, and `from_op`
        # behaves exactly as it did before the option existed. It is done here,
        # after the short-circuit above, so that a load with nothing to fetch
        # still spends no subprocess on 1Password.
        local SIGNIN_OPTIONS=()
        [[ $VERBOSE -eq 0 ]] || SIGNIN_OPTIONS+=(--verbose)
        from_op_signin ${SIGNIN_OPTIONS[@]+"${SIGNIN_OPTIONS[@]}"} ${OP_OPTIONS[@]+"${OP_OPTIONS[@]}"} || return 1
    fi

    [[ $VERBOSE -eq 0 ]] || log_status "from_op: Loading variables from 1Password"

    # Run op inject first to catch and report errors before eval.
    local injected
    if ! injected="$(printf '%s\n' "$OP_INPUT" | op inject "${OP_OPTIONS[@]}")"; then
        log_error "from_op: 1Password injection failed"
        return 1
    fi

    if [[ $GHA_MASKING -ne 0 ]]; then
        # Mask secret values in GitHub Actions logs.
        # See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#using-workflow-commands-to-access-toolkit-functions
        printf '%s\n' "$injected" \
            | while read -r line; do
                value="${line#*=}"
                [[ -z $value ]] || echo "::add-mask::${value}"
            done
    fi

    eval "$(direnv dotenv bash <(
        printf '%s\n' "$injected" \
            | while read -r line; do
                # Skip empty lines
                [[ -z $line ]] && continue

                key="${line%%=*}"
                value="${line#*=}"

                # Validate key is a valid shell identifier
                if [[ ! $key =~ ^$VALID_VAR_NAME_REGEX$ ]]; then
                    log_error "from_op: Invalid variable name: $key"
                    continue
                fi

                # Quote the value using POSIX single-quote form (${var@Q}).
                # NOTE: do not use `printf %q` here: it emits bash
                # backslash-escapes (e.g. pa\$\$word) which `direnv dotenv`
                # (a godotenv parser, not bash) does not understand and
                # mangles, corrupting values that contain `$`.
                printf '%s=%s\n' "$key" "${value@Q}"
            done
    ))"
}

# Ensure that a usable 1Password session exists.
# Returns 0 when the session is usable, 1 when there is none and it could not be
# established, and 2 when the 1Password CLI is not installed.
from_op_signin() {
    local OP_OPTIONS=()
    local ACCOUNT=""
    local ACCOUNT_SOURCE=""
    local INTERACTIVE=1
    local TIMEOUT=10
    local VERBOSE=0
    local QUIET=0

    while [[ $# -gt 0 ]]; do
        case $1 in
            --account)
                if [[ $# -lt 2 ]]; then
                    log_error "from_op_signin: --account requires an argument"
                    return 1
                fi
                ACCOUNT="$2"
                ACCOUNT_SOURCE="argument"
                OP_OPTIONS+=(--account "$2")
                shift 2
                ;;
            --no-interactive)
                INTERACTIVE=0
                shift
                ;;
            --timeout)
                if [[ $# -lt 2 ]]; then
                    log_error "from_op_signin: --timeout requires an argument"
                    return 1
                fi
                if [[ ! $2 =~ ^[0-9]+$ ]] || [[ $2 -eq 0 ]]; then
                    log_error "from_op_signin: --timeout requires a positive number of seconds: $2"
                    return 1
                fi
                TIMEOUT="$2"
                shift 2
                ;;
            --quiet)
                QUIET=1
                VERBOSE=0
                shift
                ;;
            --verbose)
                VERBOSE=1
                QUIET=0
                shift
                ;;
            --*)
                log_error "from_op_signin: Unknown option: $1"
                return 1
                ;;
            *)
                log_error "from_op_signin: Unexpected argument: $1"
                return 1
                ;;
        esac
    done

    if ! has op; then
        log_error "1Password CLI 'op' not found"
        return 2
    fi

    if [[ -z $ACCOUNT ]]; then
        if [[ -n ${OP_ACCOUNT:-} ]]; then
            ACCOUNT="$OP_ACCOUNT"
            ACCOUNT_SOURCE="environment"
        else
            ACCOUNT="my.1password.com"
            ACCOUNT_SOURCE="default"
            OP_OPTIONS+=(--account "$ACCOUNT")
        fi
    fi

    local STATUS=0
    local OP_ERROR=""
    OP_ERROR="$(_from_op_session_valid "$TIMEOUT" ${OP_OPTIONS[@]+"${OP_OPTIONS[@]}"})" || STATUS=$?

    if [[ $STATUS -eq 0 ]]; then
        [[ $VERBOSE -eq 0 ]] || log_status "from_op_signin: 1Password session is active"
        return 0
    fi

    if [[ $STATUS -eq 124 ]]; then
        # Nothing to add by trying to sign in: that would only wait again.
        [[ $QUIET -ne 0 ]] || log_error "from_op_signin: 1Password did not answer in ${TIMEOUT}s"
        return 1
    fi

    [[ $VERBOSE -eq 0 || -z $OP_ERROR ]] || log_status "from_op_signin: $OP_ERROR"

    if [[ $INTERACTIVE -ne 0 ]]; then
        [[ $VERBOSE -eq 0 ]] || log_status "from_op_signin: Signing in to 1Password"

        # One attempt only, never a retry loop, and always time-boxed. As `op`
        # gets no terminal to prompt on, this can only succeed through the
        # 1Password desktop app integration, which answers without one.
        local SIGNIN_OUTPUT=""
        local SIGNIN_ERROR_FILE=""
        STATUS=0
        if [[ $QUIET -eq 0 ]]; then
            SIGNIN_ERROR_FILE="$(mktemp "${TMPDIR:-/tmp}/from_op_signin.XXXXXX")" || return 1
            SIGNIN_OUTPUT="$(_from_op_run_timeout "$TIMEOUT" op signin ${OP_OPTIONS[@]+"${OP_OPTIONS[@]}"} 2>"$SIGNIN_ERROR_FILE")" || STATUS=$?
            rm -f "$SIGNIN_ERROR_FILE"
        else
            SIGNIN_OUTPUT="$(_from_op_run_timeout "$TIMEOUT" op signin ${OP_OPTIONS[@]+"${OP_OPTIONS[@]}"} 2>/dev/null)" || STATUS=$?
        fi

        if [[ $STATUS -eq 124 ]]; then
            [[ $QUIET -ne 0 ]] || log_error "from_op_signin: 1Password did not answer in ${TIMEOUT}s"
            return 1
        fi

        if [[ $STATUS -eq 0 ]]; then
            eval "$SIGNIN_OUTPUT"
            if OP_ERROR="$(_from_op_session_valid "$TIMEOUT" ${OP_OPTIONS[@]+"${OP_OPTIONS[@]}"})"; then
                [[ $VERBOSE -eq 0 ]] || log_status "from_op_signin: Signed in to 1Password"
                return 0
            fi
        fi
    fi

    if [[ $QUIET -eq 0 ]]; then
        if [[ $ACCOUNT_SOURCE == "environment" ]]; then
            log_error "from_op_signin: No active 1Password session for OP_ACCOUNT ($ACCOUNT). Run 'op signin' with the same account and then 'direnv reload', or pass --account ACCOUNT."
        else
            log_error "from_op_signin: No active 1Password session for $ACCOUNT. Run: eval \"\$(op signin --account $ACCOUNT)\" and then 'direnv reload'"
        fi
    fi
    return 1
}

# Run a command with a timeout, so that `.envrc` evaluation can never hang on
# 1Password. The input is always /dev/null: `op` must not stall on a prompt that
# direnv, which evaluates `.envrc` without a terminal on stdin, can never answer.
# `timeout` is GNU coreutils, `gtimeout` its Homebrew name on macOS. When neither
# is installed the command runs unwrapped, as the timeout is a safety net rather
# than a requirement.
_from_op_run_timeout() {
    local TIMEOUT=$1
    shift

    local TIMEOUT_CMD=""
    if command -v timeout >/dev/null 2>&1; then
        TIMEOUT_CMD="timeout"
    elif command -v gtimeout >/dev/null 2>&1; then
        TIMEOUT_CMD="gtimeout"
    fi

    local STATUS=0
    if [[ -n $TIMEOUT_CMD ]]; then
        # Status 124 means the command was killed on expiry. It is passed on as
        # is: the caller reports it, because the error output of the command
        # itself is captured and a timeout has to be told apart from a plain
        # failure. Without a timeout command 124 can only come from `op` itself,
        # which does not use it.
        "$TIMEOUT_CMD" "$TIMEOUT" "$@" </dev/null || STATUS=$?
    else
        "$@" </dev/null || STATUS=$?
    fi

    return $STATUS
}

# Check whether `op` has a usable session, without prompting.
# A service account token or a Connect host+token authenticate every `op`
# invocation on their own, so there is no session to probe and no reason to spend
# a subprocess on one. Otherwise `op whoami` is the probe: it exits non-zero when
# signed out, and `--format=json` keeps that exit contract stable.
# Error output of `op` is written to stdout for the caller to log if it wants to.
_from_op_session_valid() {
    local TIMEOUT=$1
    shift

    [[ -z ${OP_SERVICE_ACCOUNT_TOKEN:-} ]] || return 0
    [[ -z ${OP_CONNECT_HOST:-} || -z ${OP_CONNECT_TOKEN:-} ]] || return 0

    { _from_op_run_timeout "$TIMEOUT" op whoami --format=json "$@" >/dev/null; } 2>&1
}
