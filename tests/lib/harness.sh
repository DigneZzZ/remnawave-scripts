#!/usr/bin/env bash
# Test harness for remnawave-scripts.
#
# Loads the production code under test straight out of remnawave.sh (no copies),
# gives every test an isolated sandbox and stubs `docker` / `curl` so the Caddy
# safety net can be exercised without a running proxy.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/remnawave.sh"

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_TEST=""

# --- loading production code -------------------------------------------------

# Blocks are delimited in remnawave.sh by
#   # ===== TESTABLE-BLOCK: <name> =====
#   # ===== END TESTABLE-BLOCK: <name> =====
# Marker matching (rather than brace matching) is required: the Caddyfile
# templates are heredocs full of lines that are a bare "}" in column 0.
extract_block() {
    local name="$1"
    awk -v n="$name" '
        $0 == "# ===== TESTABLE-BLOCK: " n " ====="     { inside = 1; next }
        $0 == "# ===== END TESTABLE-BLOCK: " n " =====" { inside = 0 }
        inside { print }
    ' "$SCRIPT_UNDER_TEST"
}

load_blocks() {
    local name lib
    lib="$(mktemp)"
    for name in "$@"; do
        if ! extract_block "$name" | grep -q '[^[:space:]]'; then
            echo "FATAL: testable block '$name' not found in remnawave.sh" >&2
            exit 1
        fi
        extract_block "$name" >> "$lib"
        echo >> "$lib"
    done
    # shellcheck disable=SC1090
    . "$lib" || { echo "FATAL: failed to source extracted blocks" >&2; exit 1; }
    rm -f "$lib"
}

# --- sandbox -----------------------------------------------------------------

setup_sandbox() {
    SANDBOX="$(mktemp -d)"
    CADDY_DIR="$SANDBOX/caddy"
    mkdir -p "$CADDY_DIR" "$SANDBOX/bin"
    DOCKER_LOG="$SANDBOX/docker.log"
    CURL_LOG="$SANDBOX/curl.log"
    : > "$DOCKER_LOG"
    : > "$CURL_LOG"
    install_stubs
    PATH="$SANDBOX/bin:$PATH"
    export PATH SANDBOX DOCKER_LOG CURL_LOG
    # stub behaviour knobs
    export STUB_CADDY_RUNNING=1
    export STUB_VALIDATE_EXIT=0
    export STUB_RELOAD_EXIT=0
    export STUB_DEAD_DOMAINS=""
    export STUB_DEAD_AFTER_RELOAD=""
}

teardown_sandbox() {
    [ -n "$SANDBOX" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"
}

install_stubs() {
    cat > "$SANDBOX/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$DOCKER_LOG"
case "$1 $2" in
    "ps --format")
        [ "${STUB_CADDY_RUNNING:-1}" = "1" ] && echo "caddy-remnawave"
        exit 0
        ;;
esac
if [ "$1" = "exec" ]; then
    case "$*" in
        *" caddy validate "*)
            if [ "${STUB_VALIDATE_EXIT:-0}" != "0" ]; then
                echo "Error: adapting config using caddyfile: unrecognized directive: bogus_directive" >&2
                exit "$STUB_VALIDATE_EXIT"
            fi
            echo "Valid configuration"
            exit 0
            ;;
        *" caddy reload "*)
            if [ "${STUB_RELOAD_EXIT:-0}" != "0" ]; then
                echo "reload failed" >&2
                exit "$STUB_RELOAD_EXIT"
            fi
            touch "$SANDBOX/.reloaded"
            echo "reloaded" >> "$SANDBOX/reload-count"
            exit 0
            ;;
    esac
fi
exit 0
STUB
    cat > "$SANDBOX/bin/curl" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$CURL_LOG"
domain=""
prev=""
for arg in "$@"; do
    if [ "$prev" = "--resolve" ]; then
        domain="${arg%%:*}"
    fi
    prev="$arg"
done
dead=" ${STUB_DEAD_DOMAINS:-} "
if [ -f "$SANDBOX/.reloaded" ]; then
    dead="$dead ${STUB_DEAD_AFTER_RELOAD:-} "
fi
case "$dead" in
    *" $domain "*) echo "000"; exit 0 ;;
esac
echo "200"
exit 0
STUB
    chmod +x "$SANDBOX/bin/docker" "$SANDBOX/bin/curl"
}

reload_count() {
    [ -f "$SANDBOX/reload-count" ] && wc -l < "$SANDBOX/reload-count" | tr -d ' ' || echo 0
}

# --- assertions --------------------------------------------------------------

it() {
    CURRENT_TEST="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  \033[1;31m✗\033[0m %s\n' "$CURRENT_TEST"
    printf '      %s\n' "$1"
    [ -n "$2" ] && printf '      %s\n' "$2"
    return 0
}

pass() {
    printf '  \033[1;32m✓\033[0m %s\n' "$CURRENT_TEST"
}

assert_eq() {
    if [ "$1" = "$2" ]; then pass; else fail "expected: $2" "actual:   $1"; fi
}

assert_files_identical() {
    if cmp -s "$1" "$2"; then pass; else fail "files differ: $1 vs $2" "$(diff -u "$2" "$1" 2>/dev/null | head -20)"; fi
}

assert_file_exists() {
    if [ -f "$1" ]; then pass; else fail "expected file to exist: $1"; fi
}

assert_file_missing() {
    if [ ! -e "$1" ]; then pass; else fail "expected file NOT to exist: $1"; fi
}

assert_contains() {
    case "$1" in
        *"$2"*) pass ;;
        *) fail "expected to contain: $2" "actual: $(printf '%s' "$1" | head -c 1200)" ;;
    esac
}

assert_not_contains() {
    case "$1" in
        *"$2"*) fail "expected NOT to contain: $2" "actual: $(printf '%s' "$1" | head -c 1200)" ;;
        *) pass ;;
    esac
}

assert_success() {
    if [ "$1" = "0" ]; then pass; else fail "expected exit code 0, got $1"; fi
}

assert_rc() {
    if [ "$1" = "$2" ]; then pass; else fail "expected exit code $2, got $1"; fi
}

finish_suite() {
    echo
    if [ "$TESTS_FAILED" -eq 0 ]; then
        printf '\033[1;32m%s: %d/%d passed\033[0m\n' "$SUITE_NAME" "$TESTS_RUN" "$TESTS_RUN"
        exit 0
    fi
    printf '\033[1;31m%s: %d/%d failed\033[0m\n' "$SUITE_NAME" "$TESTS_FAILED" "$TESTS_RUN"
    exit 1
}
