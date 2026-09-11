has() {
    [[ $1 == op ]]
}

watch_file() {
    printf '%s\n' "$1" >>"${WATCH_FILE_LOG:?}"
}

log_error() {
    printf 'ERROR: %s\n' "$*" >&2
}

log_status() {
    printf 'STATUS: %s\n' "$*" >&2
}

direnv() {
    if [[ $1 == dotenv && $2 == bash ]]; then
        # Delegate to the real direnv binary so tests exercise its actual
        # dotenv (godotenv) parser. Using `cat` here would bypass parsing and
        # let bash's own `eval` interpret the output, hiding quoting bugs such
        # as `printf %q` backslash-escapes that direnv does not understand.
        command direnv dotenv bash "${3:-/dev/stdin}"
        return
    fi

    printf 'unexpected direnv invocation: %s\n' "$*" >&2
    return 1
}

dotenv_if_exists() {
    :
}

op() {
    if [[ $1 == --version ]]; then
        printf '2.30.0\n'
        return 0
    fi

    if [[ $1 == whoami ]]; then
        shift
        printf '%s\n' "$*" >>"${OP_WHOAMI_LOG:?}"

        # Only used by the timeout tests, and only when set to a non-zero value.
        [[ ${OP_STUB_WHOAMI_DELAY:-0} == 0 ]] || sleep "$OP_STUB_WHOAMI_DELAY"

        # The sign-in branch below records a successful sign-in in a file, as it
        # can not export anything back into the shell that called it.
        if [[ ${OP_STUB_SIGNED_IN:-1} == 1 || -f ${OP_SESSION_SENTINEL:?} ]]; then
            printf '{"url":"my.1password.com","user_uuid":"stub","account_uuid":"stub"}\n'
            return 0
        fi

        printf "[ERROR] you are not currently signed in. Please run 'op signin --help' for instructions\n" >&2
        return 1
    fi

    if [[ $1 == signin ]]; then
        shift
        printf '%s\n' "$*" >>"${OP_SIGNIN_LOG:?}"

        if [[ ${OP_STUB_SIGNIN_SUCCEEDS:-1} != 1 ]]; then
            printf '[ERROR] authorization prompt dismissed, please try again\n' >&2
            return 1
        fi

        : >"${OP_SESSION_SENTINEL:?}"
        printf 'export OP_SESSION_test="stub-token"\n'
        return 0
    fi

    if [[ $1 != inject ]]; then
        printf 'unexpected op invocation: %s\n' "$*" >&2
        return 1
    fi

    shift
    printf '%s\n' "$*" >>"${OP_ARGS_LOG:?}"

    while IFS= read -r line; do
        [[ -z $line || $line =~ ^[[:space:]]*# ]] && continue

        key=${line%%=*}
        reference=${line#*=}

        case $reference in
            op://vault/item/field)
                value=single-secret
                ;;
            op://vault/first/field)
                value=first-secret
                ;;
            op://vault/other/field)
                value=other-secret
                ;;
            op://vault/file/field)
                value=file-secret
                ;;
            op://vault/dollar/field)
                value=pa\$\$word\$with\$dollars
                ;;
            *)
                value="value-for-${reference}"
                ;;
        esac

        printf '%s=%s\n' "$key" "$value"
    done
}

# `timeout` execs its command and therefore can not see shell functions, so the
# `op` stub has to exist as a real executable as well. The shim re-enters this
# file and calls the function above, so that direct calls and `timeout op ...`
# share one stub. Putting it first on PATH also shadows any real `op` installed
# on the machine, which the test suite must never invoke.
_stubs_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
if [[ ! -x ${OP_STUB_BIN:?}/op ]]; then
    mkdir -p "$OP_STUB_BIN"
    {
        printf '%s\n' '#!/usr/bin/env bash'
        printf 'source %q\n' "$_stubs_file"
        printf '%s\n' 'op "$@"'
    } >"$OP_STUB_BIN/op"
    chmod +x "$OP_STUB_BIN/op"
fi
unset _stubs_file

case ":$PATH:" in
    *":$OP_STUB_BIN:"*) ;;
    *)
        PATH="$OP_STUB_BIN:$PATH"
        export PATH
        ;;
esac
