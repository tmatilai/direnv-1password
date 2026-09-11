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

    # Build the `op inject` template: one "NAME=reference" line per variable,
    # each followed by a marker line. Values may span multiple lines, so the
    # marker is what tells the output parser where a value ends.
    local marker="# from_op end ${RANDOM}${RANDOM}"
    local keys=()
    local template=""
    local line key
    while IFS= read -r line; do
        # Trim whitespace, skip blank lines and comments.
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z $line || $line == \#* ]] && continue

        if [[ ! $line =~ ^($VALID_VAR_NAME_REGEX)= ]]; then
            log_error "from_op: Invalid variable definition: $line"
            return 1
        fi
        key="${BASH_REMATCH[1]}"

        # Respect --no-overwrite even if the variable is set to empty.
        if [[ $OVERWRITE_ENVVARS -eq 0 && -n ${!key+x} ]]; then
            continue
        fi

        keys+=("$key")
        template+="$line"$'\n'"$marker"$'\n'
    done <<<"$OP_INPUT"

    if [[ ${#keys[@]} -eq 0 ]]; then
        [[ $VERBOSE -eq 0 ]] || log_status "from_op: No variables to load from 1Password"
        return 0
    fi

    [[ $VERBOSE -eq 0 ]] || log_status "from_op: Loading variables from 1Password"

    local injected
    if ! injected="$(printf '%s' "$template" | op inject "${OP_OPTIONS[@]}")"; then
        log_error "from_op: 1Password injection failed"
        return 1
    fi

    # Export each "NAME=value" block. Never log the output: it is secret.
    local i=0 in_value=0 value masked
    while IFS= read -r line; do
        if [[ $line == "$marker" ]]; then
            if [[ $GHA_MASKING -ne 0 && -n $value ]]; then
                # Mask secret values in GitHub Actions logs. Special characters
                # must be URL-encoded, `%` first.
                # See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#masking-a-value-in-a-log
                masked="${value//%/%25}"
                masked="${masked//$'\r'/%0D}"
                masked="${masked//$'\n'/%0A}"
                echo "::add-mask::${masked}"
            fi
            export "${keys[i]}=$value"
            i=$((i + 1))
            in_value=0
        elif [[ $in_value -ne 0 ]]; then
            value+=$'\n'"$line"
        elif [[ $i -lt ${#keys[@]} && $line == "${keys[i]}="* ]]; then
            value="${line#*=}"
            in_value=1
        else
            log_error "from_op: Unexpected output from 'op inject'"
            return 1
        fi
    done <<<"$injected"

    if [[ $i -ne ${#keys[@]} ]]; then
        log_error "from_op: Unexpected output from 'op inject'"
        return 1
    fi
}
