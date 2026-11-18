#!/usr/bin/env bash
# Exercise the version report through the real selfsteal update command and menu.
# The functions loaded below use the test settings.
# shellcheck disable=SC2034
. "$(cd "$(dirname "$0")" && pwd)/lib/harness.sh"
SUITE_NAME="selfsteal-nginx"
SELFSTEAL_SCRIPT="${1:-$REPO_ROOT/selfsteal.sh}"

eval "$(awk '
    /^(NGINX_VERSION|SCRIPT_VERSION)=/ { print }
    /^(report_nginx_version|check_for_updates|update_command|main_menu)\(\) \{$/ { inside = 1 }
    inside { print }
    inside && $0 == "}" { inside = 0 }
' "$SELFSTEAL_SCRIPT")"

APP_DIR=$(mktemp -d) || exit 1
trap 'rm -rf "$APP_DIR"' EXIT
printf 'services:\n  nginx:\n    image: nginx:1.29.3-alpine\n' > "$APP_DIR/docker-compose.yml"
DOCKER_LOG="$APP_DIR/docker.log"
APP_NAME="selfsteal"
CONTAINER_NAME="nginx-selfsteal"
WEB_SERVER="nginx"
UPDATE_URL="https://example.invalid/selfsteal.sh"
WHITE="" GRAY="" GREEN="" YELLOW="" RED="" CYAN="" BLUE="" NC=""

docker() {
    printf '%s\n' "$*" >> "$DOCKER_LOG"
    case "$*" in
        "exec nginx-selfsteal nginx -v")
            [ -n "$BIN_VERSION" ] || return 1
            printf 'nginx version: nginx/%s\n' "$BIN_VERSION" >&2
            ;;
        "container inspect --format {{.Config.Image}} nginx-selfsteal")
            [ -n "${CONTAINER_IMAGE:-}" ] || return 1
            printf '%s\n' "$CONTAINER_IMAGE"
            ;;
        "compose config --images nginx") printf '%s\n' 'nginx:1.29.3-alpine' ;;
        "compose ps --format {{.State}}") printf '%s\n' 'running' ;;
        *) return 1 ;;
    esac
}

curl() { printf 'SCRIPT_VERSION="%s"\n' "$SCRIPT_VERSION"; }
check_running_as_root() { :; }
check_for_updates_silent() { :; }
clear() { :; }

echo "== $SUITE_NAME =="

it "new installs use the patched stable Alpine image"
assert_eq "$NGINX_VERSION" "1.30.7-alpine"

it "update reports the running binary version even when the script is current"
out=$(BIN_VERSION=1.29.3 update_command)
assert_contains "$out" "NGINX version: 1.29.3"

for version in 1.29.3 1.30.6 1.31.0 1.31.8; do
    it "update warns about nginx2root for NGINX $version"
    assert_contains "$(BIN_VERSION="$version" update_command)" "nginx2root"
done

for version in 1.30.7 1.30.10 1.31.9 1.32.0; do
    it "update accepts patched NGINX $version"
    out=$(BIN_VERSION="$version" update_command)
    assert_contains "$out" "NGINX version: $version"
    it "patched NGINX $version does not produce a security warning"
    assert_not_contains "$out" "nginx2root"
done

it "the menu shows the security warning after restarting a self-updated script"
assert_contains "$(BIN_VERSION=1.29.3 main_menu <<< '0')" "nginx2root"

it "a stopped container shows its image reference when nginx -v is unavailable"
out=$(BIN_VERSION='' CONTAINER_IMAGE=nginx:1.29.3-alpine update_command)
assert_contains "$out" "Container image: nginx:1.29.3-alpine"

it "a missing container shows the configured image reference"
out=$(BIN_VERSION='' update_command)
assert_contains "$out" "Configured image: nginx:1.29.3-alpine"

it "a configured tag is not reported as a verified binary version"
assert_not_contains "$out" "NGINX version: 1.29.3"

it "reporting an outdated version never starts or changes a container"
assert_not_contains "$(cat "$DOCKER_LOG")" "compose up"

it "Caddy script updates do not inspect NGINX"
: > "$DOCKER_LOG"
WEB_SERVER=caddy update_command >/dev/null
assert_eq "$(cat "$DOCKER_LOG")" ""

finish_suite
