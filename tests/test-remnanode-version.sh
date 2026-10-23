#!/usr/bin/env bash
# Run the real version parser and menu against old/new container layouts.
. "$(cd "$(dirname "$0")" && pwd)/lib/harness.sh"
SUITE_NAME="remnanode-version"
NODE_SCRIPT="${1:-$REPO_ROOT/remnanode.sh}"

if ! command -v node >/dev/null 2>&1; then
    echo "SKIP: $SUITE_NAME needs Node.js on the test host"
    exit 0
fi

load_node_function() {
    local code
    code=$(awk -v name="$1" '
        $0 == name "() {" { inside = 1 }
        inside { print }
        inside && $0 == "}" { exit }
    ' "$NODE_SCRIPT")
    [ -n "$code" ] || { echo "Missing function: $1" >&2; exit 1; }
    eval "$code"
}

load_node_function get_remnanode_version
load_node_function get_container_xray_version
load_node_function get_current_xray_core_version
load_node_function main_menu
load_node_function status_command

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/app/dist"
APP_NAME="custom-node"
export APP_DIR="$SANDBOX"
export LOG_DIR="$SANDBOX/logs"
XRAY_FILE="$SANDBOX/xray"
export NODE_IP="192.0.2.1"
export SCRIPT_VERSION="test"
CONTAINER_RUNNING=true
EXTERNAL_XRAY=false

# Only Docker is replaced. Parsing runs in a real Node.js process, and the
# fixture directory represents the container's configured working directory.
docker() {
    [ "$CONTAINER_RUNNING" = true ] || return 1
    [ "$1" = exec ] && [ "$2" = "$APP_NAME" ] || return 1
    shift 2
    case "$1" in
        node|awk|sed|echo) (cd "$SANDBOX/app" && command "$@") ;;
        xray) echo 'Xray 26.7.28 (Xray, Penetrates Everything.)' ;;
        *) return 1 ;;
    esac
}

clear() { :; }
ensure_latest_script() { :; }
check_running_as_root() { :; }
detect_compose() { :; }
is_remnanode_installed() { return 0; }
is_remnanode_up() { return 0; }
is_xray_mounted() { [ "$EXTERNAL_XRAY" = true ]; }
get_env_variable() { echo 3000; }
top() { echo 'Cpu(s): 2.3 us'; }
free() { echo 'Mem: 3.8Gi 1.5Gi'; }

show_menu() {
    (main_menu <<< '0') | sed $'s/\033\\[[0-9;]*[A-Za-z]//g'
}

echo "== $SUITE_NAME =="

cat > "$SANDBOX/app/package.json" <<'JSON'
{
  "name": "@remnawave/node",
  "version": "3.4.2"
}
JSON
it "older images still report the node package version"
out=$(get_remnanode_version); rc=$?
assert_eq "$out" '3.4.2'
it "a detected version returns success"
assert_success "$rc"

printf '%s\n' '{"name":"@remnawave/node","version":"2.8.0"}' > "$SANDBOX/app/package.json"
it "compact package JSON does not return the package name as its version"
assert_eq "$(get_remnanode_version)" '2.8.0'

rm "$SANDBOX/app/package.json"
# The banner form emitted by the official 3.4.3 SWC build.
printf '%s\n' 'renderBox("Remnawave Node v".concat("3.4.3"), []);' > "$SANDBOX/app/dist/main.js"
it "bundled images report their embedded version without package.json"
out=$(get_remnanode_version); rc=$?
assert_eq "$out" '3.4.3'
it "bundled version detection returns success"
assert_success "$rc"

printf '%s\n' 'renderBox("Remnawave Node v3.4.4-beta.1+local", []);' > "$SANDBOX/app/dist/main.js"
it "a literal bundled banner preserves prerelease and build suffixes"
assert_eq "$(get_remnanode_version)" '3.4.4-beta.1+local'

printf '%s\n' '{"version":"unknown"}' > "$SANDBOX/app/package.json"
printf '%s\n' 'renderBox("Remnawave Node v".concat("3.4.3"), []);' > "$SANDBOX/app/dist/main.js"
it "invalid package metadata falls back to the bundled version"
assert_eq "$(get_remnanode_version)" '3.4.3'
rm "$SANDBOX/app/package.json"

it "the real menu shows the node version alongside built-in Xray"
out=$(show_menu)
assert_contains "$out" '✅ v3.4.3'
it "the built-in core keeps its own version"
assert_contains "$out" '26.7.28 (built-in)'

cat > "$XRAY_FILE" <<'XRAY'
#!/usr/bin/env bash
echo 'Xray 26.10.21 (Xray, Penetrates Everything.)'
XRAY
chmod +x "$XRAY_FILE"
EXTERNAL_XRAY=true
out=$(show_menu)
it "mounting a custom Xray leaves the displayed node version intact"
assert_contains "$out" '✅ v3.4.3'
it "the mounted core shows its separate external version"
assert_contains "$out" '26.10.21 (external)'

it "the status command also reports the bundled node version"
out=$(status_command)
assert_contains "$out" 'v3.4.3'

rm "$SANDBOX/app/dist/main.js"
out=$(get_remnanode_version); rc=$?
it "missing metadata returns failure"
assert_rc "$rc" 1
it "a failed lookup leaves fallback text to its caller"
assert_eq "$out" ''

out=$(show_menu)
it "missing versions show the unknown state in the real menu"
assert_contains "$out" '❓ version unknown'
it "unknown is never displayed as a successful version"
assert_not_contains "$out" '✅ vunknown'
it "unknown appears only once in the menu"
assert_eq "$(printf '%s\n' "$out" | grep -o unknown | wc -l | tr -d ' ')" 1

CONTAINER_RUNNING=false
out=$(get_remnanode_version); rc=$?
it "an unavailable container returns failure"
assert_rc "$rc" 1
it "an unavailable container emits no duplicate fallback"
assert_eq "$out" ''

finish_suite
