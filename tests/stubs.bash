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
    printf 'unexpected direnv invocation: %s\n' "$*" >&2
    return 1
}

dotenv_if_exists() {
    :
}

# Mimics `op inject`: replaces secret references, passes all other text
# through verbatim.
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

    local line reference value
    while IFS= read -r line; do
        while [[ $line =~ op://[^[:space:]]+ ]]; do
            reference=${BASH_REMATCH[0]}
            case $reference in
                op://vault/item/field) value=single-secret ;;
                op://vault/first/field) value=first-secret ;;
                op://vault/other/field) value=other-secret ;;
                op://vault/file/field) value=file-secret ;;
                op://vault/dollar/field) value=pa\$\$word\$with\$dollars ;;
                op://vault/quotes/field) value=$'it\'s "quoted" \\back\\slash `cmd`' ;;
                op://vault/empty/field) value= ;;
                op://vault/spaces/field) value=$' \tpadded secret \t' ;;
                op://vault/percent/field) value=$'100%\r\n' ;;
                op://vault/multiline/field) value=$'-----BEGIN KEY-----\nline1\n\nOTHER_SECRET=not-a-var\n-----END KEY-----\n' ;;
                *) value="value-for-${reference}" ;;
            esac
            line=${line/"$reference"/$value}
        done
        printf '%s\n' "$line"
    done
}
