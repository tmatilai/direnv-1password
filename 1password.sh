#!/usr/bin/env bash
#
###########################################################################
# 1Password helpers for direnv configuration.
#
# VERSION:
#    0.1.0
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
    local VERBOSE=0
    local VALID_VAR_NAME_REGEX='^[A-Za-z_][A-Za-z0-9_]*$'

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
            --verbose)
                VERBOSE=1
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
                if [[ $line =~ ^($VALID_VAR_NAME_REGEX)= ]]; then
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

    [[ $VERBOSE -eq 0 ]] || log_status "from_op: Loading variables from 1Password"

    # Run op inject first to catch and report errors before eval.
    local injected
    if ! injected="$(printf '%s\n' "$OP_INPUT" | op inject "${OP_OPTIONS[@]}")"; then
        log_error "from_op: 1Password injection failed"
        return 1
    fi

    eval "$(direnv dotenv bash <(
        printf '%s\n' "$injected" \
            | while read -r line; do
                # Skip empty lines
                [[ -z $line ]] && continue

                key="${line%%=*}"
                value="${line#*=}"

                # Validate key is a valid shell identifier
                if [[ ! $key =~ $VALID_VAR_NAME_REGEX ]]; then
                    log_error "from_op: Invalid variable name: $key"
                    continue
                fi

                # Quote the value
                printf '%s=%q\n' "$key" "$value"
            done
    ))"
}
