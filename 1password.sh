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
#     MIT licence - Copyright (c) 2022 Teemu Matilainen and contributors
#
###########################################################################

# Usage: from_op [<varname>=<reference>]
#
# Example:
#
#    from_op MY_SECRET=op://vault/item/field
#
#    from_op <<OP
#        FIRST_SECRET=op://vault/item/field
#        OTHER_SECRET=op://...
#    OP
#
# Reads environment variable values from 1Password.
#
from_op() {
    if [[ -t 0 ]] && [[ $# == 0 ]]; then
        log_error "from_op: No input nor arguments given"
        return 1
    fi
    if ! has op; then
        log_error "1Password CLI 'op' not found"
        return 1
    fi

    case "$(op --version)" in
        1.*) __from_op1 ;;
        *) __from_op2 ;;
    esac < <(
        # Concatenate function args and stdin (if any)
        [[ $# == 0 ]] || printf '%s\n' "${@}"
        [[ -t 0 ]] || cat
    )
}

__from_op1() {
    local pattern='^(.*)=op://([^/]*)/([^/]*)/([^/]*)$'
    local skip='^(#|$)'
    while read -r arg; do
        if [[ $arg =~ $skip ]]; then
            continue
        elif [[ ! $arg =~ $pattern ]]; then
            log_error "from_op: Failed to parse the argument: $arg"
            return 1
        fi
        local m=("${BASH_REMATCH[@]}")
        local var="${m[1]}" vault="${m[2]}" item="${m[3]}" field="${m[4]}" secret
        secret="$(op get item --vault="$vault" "$item" --fields="$field" --cache)"
        export "$var=$secret"
    done
}

__from_op2() {
    local var val
    local -a op_sessions

    # Store OP_SESSION_* variables, as `op run` removes them
    for var in "${!OP_SESSION_@}"; do
        eval "val=\$$var"
        op_sessions+=("$var=$val")
    done

    direnv_load op run --env-file /dev/stdin --no-masking -- direnv dump

    for var in "${op_sessions[@]}"; do
        export "${var?}"
    done
}
