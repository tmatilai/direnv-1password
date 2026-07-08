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
