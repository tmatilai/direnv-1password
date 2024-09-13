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
    local OP_VARIABLES=()
    local OP_FILES=()
    while [[ $# -gt 0 ]]; do
        case $1 in
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

    if [[ -t 0 ]] && [[ ${#OP_VARIABLES[@]} == 0 ]] && [[ ${#OP_FILES[@]} == 0 ]]; then
        log_error "from_op: No input nor arguments given"
        return 1
    fi

    local OP_INPUT
    OP_INPUT="$(
        # Concatenate variable-args, file-args and stdin.
        printf '%s\n' "${OP_VARIABLES[@]}"
        [[ "${#OP_FILES[@]}" == 0 ]] || cat "${OP_FILES[@]}"
        [[ -t 0 ]] || cat
    )"

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

    eval "$(direnv dotenv bash <(echo "$OP_INPUT" | op inject))"
}
