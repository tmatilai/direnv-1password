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
    # Locals are prefixed so they cannot shadow the variables being exported.
    local _op_variables=()
    local _op_files=()
    local _op_options=()
    local _op_stdin=0
    local _op_overwrite=1
    local _op_verbose=0
    local _op_masking=1
    [[ ${GITHUB_ACTIONS:-} == "true" ]] || _op_masking=0
    local _op_name_regex='[A-Za-z_][A-Za-z0-9_]*'

    if ! has op; then
        log_error "1Password CLI 'op' not found"
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-overwrite)
                _op_overwrite=0
                shift
                ;;
            --verbose)
                _op_verbose=1
                shift
                ;;
            --no-gha-masking)
                _op_masking=0
                shift
                ;;
            --account)
                if [[ $# -lt 2 ]]; then
                    log_error "from_op: --account requires an argument"
                    return 1
                fi
                _op_options+=(--account "$2")
                shift 2
                ;;
            --*)
                log_error "from_op: Unknown option: $1"
                return 1
                ;;
            -)
                _op_stdin=1
                shift
                ;;
            *=*)
                _op_variables+=("$1")
                shift
                ;;
            *)
                _op_files+=("$1")
                watch_file "$1"
                shift
                ;;
        esac
    done

    # Read stdin only when no variable or file arguments are given, or with `-`.
    if [[ ${#_op_variables[@]} -eq 0 && ${#_op_files[@]} -eq 0 ]]; then
        _op_stdin=1
    fi
    if [[ $_op_stdin -ne 0 && -t 0 ]]; then
        log_error "from_op: No input nor arguments given"
        return 1
    fi

    local _op_input _op_file
    _op_input="$(
        printf '%s\n' "${_op_variables[@]}"
        if [[ ${#_op_files[@]} -gt 0 ]]; then
            for _op_file in "${_op_files[@]}"; do
                if [[ -r $_op_file ]]; then
                    cat "$_op_file"
                else
                    log_error "from_op: Cannot read file: $_op_file"
                fi
            done
        fi
        [[ $_op_stdin -eq 0 ]] || cat
    )"

    # Build the `op inject` template: one "NAME=reference" line per variable,
    # each followed by a marker line. Values may span multiple lines, so the
    # marker is what tells the output parser where a value ends.
    local _op_marker="# from_op end ${RANDOM}${RANDOM}"
    local _op_keys=()
    local _op_template=""
    local _op_line _op_key
    while IFS= read -r _op_line; do
        # Trim whitespace, skip blank lines and comments.
        _op_line="${_op_line#"${_op_line%%[![:space:]]*}"}"
        _op_line="${_op_line%"${_op_line##*[![:space:]]}"}"
        [[ -z $_op_line || $_op_line == \#* ]] && continue

        if [[ ! $_op_line =~ ^($_op_name_regex)= ]]; then
            log_error "from_op: Invalid variable definition: $_op_line"
            return 1
        fi
        _op_key="${BASH_REMATCH[1]}"

        # With --no-overwrite, skip variables that are set, even to an empty
        # value. `${var+x}` expands to `x` only if the variable is set.
        if [[ $_op_overwrite -eq 0 && -n ${!_op_key+x} ]]; then
            continue
        fi

        _op_keys+=("$_op_key")
        _op_template+="$_op_line"$'\n'"$_op_marker"$'\n'
    done <<<"$_op_input"

    if [[ ${#_op_keys[@]} -eq 0 ]]; then
        [[ $_op_verbose -eq 0 ]] || log_status "from_op: No variables to load from 1Password"
        return 0
    fi

    [[ $_op_verbose -eq 0 ]] || log_status "from_op: Loading variables from 1Password"

    local _op_injected
    if ! _op_injected="$(printf '%s' "$_op_template" | op inject "${_op_options[@]}")"; then
        log_error "from_op: 1Password injection failed"
        return 1
    fi

    # Export each "NAME=value" block. Never log the output: it is secret.
    local _op_i=0 _op_in_value=0 _op_value _op_masked
    while IFS= read -r _op_line; do
        if [[ $_op_line == "$_op_marker" ]]; then
            if [[ $_op_masking -ne 0 && -n $_op_value ]]; then
                # Mask secret values in GitHub Actions logs. Special characters
                # must be URL-encoded, `%` first.
                # See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#masking-a-value-in-a-log
                _op_masked="${_op_value//%/%25}"
                _op_masked="${_op_masked//$'\r'/%0D}"
                _op_masked="${_op_masked//$'\n'/%0A}"
                echo "::add-mask::${_op_masked}"
            fi
            export "${_op_keys[_op_i]}=$_op_value"
            _op_i=$((_op_i + 1))
            _op_in_value=0
        elif [[ $_op_in_value -ne 0 ]]; then
            _op_value+=$'\n'"$_op_line"
        elif [[ $_op_i -lt ${#_op_keys[@]} && $_op_line == "${_op_keys[_op_i]}="* ]]; then
            _op_value="${_op_line#*=}"
            _op_in_value=1
        else
            log_error "from_op: Unexpected output from 'op inject'"
            return 1
        fi
    done <<<"$_op_injected"

    if [[ $_op_i -ne ${#_op_keys[@]} ]]; then
        log_error "from_op: Unexpected output from 'op inject'"
        return 1
    fi
}
