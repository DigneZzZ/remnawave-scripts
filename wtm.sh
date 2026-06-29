#!/usr/bin/env bash
# WARP & Tor Network Setup Script
# This script installs and manages Cloudflare WARP and Tor connections
# VERSION=1.4.0

# NB: this is an interactive, status-returning menu script. We deliberately do
# NOT use `set -e` (errexit): many functions return non-zero as a normal status
# (e.g. "already installed", "no update available"), and aborting on those would
# break the menu loop. We keep `set -E` (errtrace) so the ERR trap below can
# surface genuinely unexpected failures for diagnostics without exiting.
set -E
SCRIPT_VERSION="1.4.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Error handler for debugging (diagnostic only — never exits)
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

error_handler() {
    local exit_code=$1 line=$2 command=$3
    # Skip if exit code is 0
    [[ $exit_code -eq 0 ]] && return
    # Don't warn on commands that legitimately return non-zero as status.
    # Anchored on whole words / known helper prefixes to avoid over-silencing.
    case $command in
        grep*|*\ grep\ *|*\|*grep*) return ;;
        check_*|verify_*|is_*|*systemctl\ is-*) return ;;
    esac
    echo -e "\033[1;31m[ERROR]\033[0m Command failed at line $line: $command (exit code: $exit_code)" >&2
}

# Script URL for updates
SCRIPT_URL="https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/wtm.sh"

# Handle @ prefix for consistency with other scripts
if [ $# -gt 0 ] && [ "$1" = "@" ]; then
    shift  
fi

if [ $# -gt 0 ]; then
    COMMAND="$1"
    shift
fi

# Parse arguments
FORCE_MODE=false
while [[ $# -gt 0 ]]; do  
    key="$1"  
    case $key in  
        --force|-f)  
            FORCE_MODE=true
            shift
        ;;  
        -h|--help)
            COMMAND="help"
            shift
        ;;
        *)
            break
        ;;
    esac
done

# Map the documented --force/-f flag onto the variable the install gates read.
# Without this, `wtm install-warp --force` silently performed a NON-force install.
if [ "$FORCE_MODE" = true ]; then
    export FORCE_INSTALL=true
fi

# Configuration
WARP_CONFIG_FILE="/etc/wireguard/warp.conf"
WARP_ACCOUNT_FILE="/etc/wireguard/wgcf-account.toml"
WARP_XRAY_FILE="/etc/wireguard/warp-xray-outbound.json"
TOR_CONFIG_FILE="/etc/tor/torrc"
WARP_SERVICE="wg-quick@warp"
TOR_SERVICE="tor"
LOG_FILE="/var/log/wtm.log"

# Constant Cloudflare WARP WireGuard peer public key (same for every account).
# Used when emitting a native Xray `wireguard` outbound. Source: official
# Project X WARP guide (xtls.github.io/en/document/level-2/warp.html).
WARP_PEER_PUBLIC_KEY="bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="
WARP_ENDPOINT="engage.cloudflareclient.com:2408"

# ===== DEPENDENCY CHECK =====

check_dependencies() {
    local missing_deps=()
    local deps=(curl wget)
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "\033[1;31m❌ Missing required dependencies: ${missing_deps[*]}\033[0m" >&2
        echo "Please install them first or run install command which will install them automatically."
        return 1
    fi
    return 0
}

# ===== COLOR SETUP =====

setup_colors() {
    if [[ -t 1 ]]; then
        # Terminal supports colors
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        MAGENTA='\033[0;35m'
        CYAN='\033[0;36m'
        WHITE='\033[0;37m'
        BOLD='\033[1m'
        DIM='\033[2m'
        NC='\033[0m' # No Color
    else
        # No colors for non-terminal output
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        MAGENTA=''
        CYAN=''
        WHITE=''
        BOLD=''
        DIM=''
        NC=''
    fi
}

# ===== PORT CHECKING =====

# Print the listening socket line(s) for a port. Prefer ss (iproute2, almost
# always present); fall back to netstat (net-tools) only if ss is missing.
port_listeners() {
    local port=$1
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp 2>/dev/null | grep ":$port "
    else
        netstat -tlnp 2>/dev/null | grep ":$port "
    fi
}

check_port_available() {
    local port=$1
    if [ -n "$(port_listeners "$port")" ]; then
        return 1  # Port is occupied
    fi
    return 0  # Port is free
}

check_tor_ports() {
    local socks_port=9050
    local control_port=9051
    local p

    for p in "$socks_port" "$control_port"; do
        if ! check_port_available "$p"; then
            warn "Port $p is already in use"
            echo -e "\033[38;5;244m   Process using port $p:\033[0m"
            port_listeners "$p" | sed 's/^/   /'
            return 1
        fi
    done

    return 0
}

# Функция для проверки доступности порта (для отображения в меню)
check_port_listening() {
    local port=$1
    local host=${2:-127.0.0.1}

    # Проверяем через ss (предпочтительно) или netstat
    if port_listeners "$port" | grep -q "${host}:${port} "; then
        return 0  # Порт слушается
    fi

    # Fallback: пробуем через bash TCP redirect (если доступно)
    if timeout 1 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        return 0
    fi

    return 1  # Порт недоступен
}

# ===== UTILITY FUNCTIONS =====

print_banner() {
    clear
    echo -e "\033[1;36mWARP & Tor Network Setup v$SCRIPT_VERSION                \033[0m"
    echo
}

ok() {
    echo -e "\033[1;32m✅ $1\033[0m"
}

warn() {
    echo -e "\033[1;33m⚠️  $1\033[0m"
}

error() {
    echo -e "\033[1;31m❌ $1\033[0m"
}

info() {
    echo -e "\033[1;34mℹ️  $1\033[0m"
}

step() {
    echo -e "\033[1;37m🔧 $1\033[0m"
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        error "This script must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
}

error_exit() {
    error "$1"
    exit 1
}

log_action() {
    local message="$1"
    if [[ -w "$(dirname "$LOG_FILE")" ]] || [[ -w "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Open a file in the user's editor, falling back to whatever is installed.
# Avoids hard-coding `nano`, which is not guaranteed on minimal hosts.
edit_file() {
    local file="$1"
    local editor="${EDITOR:-}"
    if [ -z "$editor" ]; then
        editor=$(command -v nano || command -v vim || command -v vi || true)
    fi
    if [ -z "$editor" ]; then
        warn "No text editor found (set \$EDITOR or install nano/vi). File: $file"
        read -p "Press Enter to continue..."
        return 1
    fi
    "$editor" "$file"
}

# ===== USAGE FUNCTION =====

usage() {
    cat <<EOF
Usage: $(basename "$0") [@] <command> [options]

Installation:
    install-warp          Install Cloudflare WARP
    install-tor           Install Tor anonymity network
    install-all           Install both WARP and Tor
    install-warp-force    Force reinstall WARP
    install-tor-force     Force reinstall Tor
    install-all-force     Force reinstall both

Service Control:
    start-warp            Start WARP service
    stop-warp             Stop WARP service
    restart-warp          Restart WARP service
    start-tor             Start Tor service
    stop-tor              Stop Tor service
    restart-tor           Restart Tor service

Monitoring:
    status                Show services status
    test                  Test all connections
    logs <warp|tor>       View service logs
    warp-memory           WARP memory diagnostic
    system-info           Show system information

Uninstallation:
    remove-warp           Uninstall WARP
    remove-tor            Uninstall Tor

Script Management:
    install-script        Install wtm globally
    uninstall-script      Remove global wtm
    self-update           Update to latest version
    check-updates         Check for updates
    version               Show version info

Options:
    --force, -f           Force operation
    --help, -h            Show this help
    --version, -v         Show version

Examples:
    $(basename "$0") install-all
    $(basename "$0") @ install-warp --force
    $(basename "$0") status
    $(basename "$0") test

Interactive mode:
    Run without arguments to enter interactive menu.

EOF
}

# ===== VERSION AND UPDATE FUNCTIONS =====

show_version() {
    echo -e "\033[1;37m🌐 WARP & Tor Manager\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    echo -e "\033[38;5;250mVersion: \033[38;5;15m$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;250mAuthor:  \033[38;5;15mDigneZzZ\033[0m"
    echo -e "\033[38;5;250mGitHub:  \033[38;5;15mhttps://github.com/DigneZzZ/remnawave-scripts\033[0m"
    echo -e "\033[38;5;250mProject: \033[38;5;15mhttps://gig.ovh\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
}

check_for_updates() {
    info "Checking for updates..."
    # Use comment VERSION for grep-based detection (per project standard)
    local remote_script_version
    remote_script_version=$(curl -fsSL "$SCRIPT_URL" 2>/dev/null | grep -m1 "^# VERSION=" | cut -d'=' -f2)

    if [[ -z "$remote_script_version" ]]; then
        warn "Unable to check for updates (no internet connection or invalid URL)"
        return 1
    fi
    
    if [ "$remote_script_version" != "$SCRIPT_VERSION" ]; then
        echo -e "\033[1;33m🆙 New version available: $remote_script_version (current: $SCRIPT_VERSION)\033[0m"
        echo -e "   Update with: \033[1;37mwtm self-update\033[0m"
        return 0
    else
        ok "You are using the latest version ($SCRIPT_VERSION)"
        return 1
    fi
}

# Two-stage validated download+install of the wtm script.
# Never pipe `curl | install /dev/stdin`: without -f, curl returns 0 on HTTP
# 4xx/5xx and `install` happily writes the error body (or a truncated file) to
# the target and reports success — silently bricking the global `wtm`. Instead
# download to a temp file, validate it (shebang + embedded VERSION), install
# from the real file, then re-read the target to confirm the version changed.
# (Same hardening already used by remnanode.sh.)
download_and_install_wtm() {
    local target="/usr/local/bin/wtm"
    local tmp_file
    tmp_file=$(mktemp "${TMPDIR:-/tmp}/wtm.XXXXXX") || {
        error "Failed to create temporary file"
        return 1
    }

    if ! curl -fsSL "$SCRIPT_URL" -o "$tmp_file"; then
        error "Failed to download script from $SCRIPT_URL"
        rm -f "$tmp_file"
        return 1
    fi

    # Validate: must be a shell script (shebang) carrying a VERSION marker
    local new_version
    new_version=$(grep -m1 "^# VERSION=" "$tmp_file" 2>/dev/null | cut -d'=' -f2)
    if [ -z "$new_version" ] || ! head -n1 "$tmp_file" | grep -q '^#!'; then
        error "Downloaded file is not a valid wtm script — aborting update"
        rm -f "$tmp_file"
        return 1
    fi

    if ! install -m 755 "$tmp_file" "$target"; then
        error "Failed to install updated script to $target"
        rm -f "$tmp_file"
        return 1
    fi
    rm -f "$tmp_file"

    # Confirm the version on disk actually changed
    local installed_version
    installed_version=$(grep -m1 "^# VERSION=" "$target" 2>/dev/null | cut -d'=' -f2)
    if [ "$installed_version" != "$new_version" ]; then
        error "Update verification failed (expected v$new_version, got v${installed_version:-unknown})"
        return 1
    fi
    return 0
}

update_wtm_script() {
    info "Updating WARP & Tor Manager script..."
    if download_and_install_wtm; then
        ok "WARP & Tor Manager script updated successfully"
        return 0
    fi
    return 1
}

self_update() {
    if [[ "$(id -u)" != "0" ]]; then
        error "This operation requires root privileges"
        echo "Please run: sudo wtm self-update"
        exit 1
    fi

    local remote_script_version
    remote_script_version=$(curl -fsSL "$SCRIPT_URL" 2>/dev/null | grep -m1 "^# VERSION=" | cut -d'=' -f2)

    if [ -z "$remote_script_version" ]; then
        error_exit "Unable to download update (no internet connection)"
    fi

    if [ "$remote_script_version" = "$SCRIPT_VERSION" ]; then
        ok "You are already using the latest version ($SCRIPT_VERSION)"
        return 0
    fi

    info "Updating from version $SCRIPT_VERSION to $remote_script_version..."

    if update_wtm_script; then
        ok "Successfully updated to version $remote_script_version"
        echo -e "\033[1;36mRestart wtm to use the new version\033[0m"
    else
        error_exit "Failed to update script"
    fi
}

# ===== SYSTEM DETECTION =====

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VERSION=$(lsb_release -sr)
    else
        error_exit "Cannot detect operating system"
    fi
}

detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7"
            ;;
        *)
            error_exit "Unsupported architecture: $ARCH"
            ;;
    esac
}

# ===== PACKAGE MANAGEMENT =====

update_packages() {
    info "Refreshing package metadata..."
    # IMPORTANT: only refresh repository metadata here — do NOT upgrade the whole
    # system. `apt update` already does metadata-only, but on RHEL/Fedora the verb
    # `yum/dnf update` is an alias of `upgrade` and would upgrade EVERY installed
    # package (kernel, glibc, ...) as a side effect of installing WARP/Tor.
    # The correct metadata-only equivalent is `makecache`. A metadata refresh
    # failure is non-fatal: the subsequent `install` will refresh lazily anyway.
    case $OS in
        ubuntu|debian)
            apt update -qq >/dev/null 2>&1 || warn "Package metadata refresh reported an error (continuing)"
            ;;
        centos|rhel|rocky|almalinux)
            yum makecache >/dev/null 2>&1 || warn "Package metadata refresh reported an error (continuing)"
            ;;
        fedora)
            dnf makecache >/dev/null 2>&1 || warn "Package metadata refresh reported an error (continuing)"
            ;;
        *)
            error_exit "Unsupported OS: $OS"
            ;;
    esac
    ok "Package metadata refreshed"
}

install_package() {
    local packages=("$@")
    info "Installing ${packages[*]}..."
    case $OS in
        ubuntu|debian)
            apt install -y "${packages[@]}" >/dev/null 2>&1 || error_exit "Failed to install ${packages[*]}"
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y "${packages[@]}" >/dev/null 2>&1 || error_exit "Failed to install ${packages[*]}"
            ;;
        fedora)
            dnf install -y "${packages[@]}" >/dev/null 2>&1 || error_exit "Failed to install ${packages[*]}"
            ;;
        *)
            error_exit "Unsupported OS: $OS"
            ;;
    esac
    ok "${packages[*]} installed"
}

# ===== DNS MANAGEMENT =====

backup_dns() {
    if [ -f /etc/resolv.conf ] && [ ! -f /etc/resolv.conf.backup ]; then
        cp /etc/resolv.conf /etc/resolv.conf.backup
        ok "DNS configuration backed up"
    fi
}

setup_temporary_dns() {
    info "Setting up temporary DNS for installation..."
    backup_dns
    
    # Check if systemd-resolved is active
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        warn "systemd-resolved is active - configuring through systemd"
        mkdir -p /etc/systemd/resolved.conf.d
        echo -e "[Resolve]\nDNS=1.1.1.1 8.8.8.8\nFallbackDNS=1.0.0.1 8.8.4.4" > /etc/systemd/resolved.conf.d/temp-dns.conf
        systemctl restart systemd-resolved
    else
        echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > /etc/resolv.conf
    fi
    ok "Temporary DNS configured"
}

restore_dns() {
    info "Restoring original DNS configuration..."
    
    if [ -f /etc/systemd/resolved.conf.d/temp-dns.conf ]; then
        rm -f /etc/systemd/resolved.conf.d/temp-dns.conf
        systemctl restart systemd-resolved
    elif [ -f /etc/resolv.conf.backup ]; then
        cp /etc/resolv.conf.backup /etc/resolv.conf
        rm -f /etc/resolv.conf.backup
    fi
    ok "DNS configuration restored"
}

# ===== WARP FUNCTIONS =====

install_warp() {
    step "Installing Cloudflare WARP..."

    # Проверяем, установлен ли уже WARP (если не принудительная установка)
    if [ "${FORCE_INSTALL:-false}" != "true" ] && [ -f "$WARP_CONFIG_FILE" ]; then
        warn "WARP is already installed at $WARP_CONFIG_FILE"
        echo "Use '--force' flag to reinstall: bash $0 install-warp-force"
        return 1
    fi

    # Install WireGuard userspace tools + download helpers
    case $OS in
        ubuntu|debian)
            install_package wireguard-tools curl wget
            ;;
        centos|rhel|rocky|almalinux)
            # EPEL provides wireguard-tools on the Enterprise Linux family
            if ! rpm -q epel-release >/dev/null 2>&1; then
                install_package epel-release
            fi
            install_package wireguard-tools curl wget
            # On EL8 the WireGuard kernel module is NOT in-tree and is not
            # provided by EPEL — wg-quick@warp would fail to bring up the
            # interface. EL9+ ships the module in-kernel, so tools are enough.
            local el_major="${VERSION%%.*}"
            if [ "$el_major" = "8" ]; then
                info "EL8 detected — installing WireGuard kernel module from ELRepo..."
                if ! rpm -q elrepo-release >/dev/null 2>&1; then
                    install_package "https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm" || \
                        warn "Could not install elrepo-release; kmod-wireguard may be unavailable"
                fi
                install_package kmod-wireguard || \
                    warn "Could not install kmod-wireguard — the warp interface may fail to start on EL8"
            fi
            ;;
        fedora)
            install_package wireguard-tools curl wget
            ;;
    esac

    setup_temporary_dns

    # Create temp work directory up-front; download wgcf INTO it (not CWD).
    local WGCF_TEMP_DIR
    WGCF_TEMP_DIR=$(mktemp -d) || error_exit "Failed to create temporary directory"

    # Resolve latest wgcf release version
    info "Downloading wgcf..."
    local WGCF_RELEASE_URL="https://api.github.com/repos/ViRb3/wgcf/releases/latest"
    local WGCF_VERSION
    WGCF_VERSION=$(curl -fsSL "$WGCF_RELEASE_URL" 2>/dev/null | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    if [ -z "$WGCF_VERSION" ]; then
        rm -rf "$WGCF_TEMP_DIR"
        error_exit "Failed to get latest wgcf version (GitHub API unreachable?)"
    fi

    local WGCF_DOWNLOAD_URL="https://github.com/ViRb3/wgcf/releases/download/${WGCF_VERSION}/wgcf_${WGCF_VERSION#v}_linux_${ARCH}"
    local WGCF_BINARY="$WGCF_TEMP_DIR/wgcf"

    # Two-stage download with validation: a partial/empty/HTML download must not
    # become a broken /usr/local/bin/wgcf that fails later at register time.
    if ! curl -fsSL "$WGCF_DOWNLOAD_URL" -o "$WGCF_BINARY"; then
        rm -rf "$WGCF_TEMP_DIR"
        error_exit "Failed to download wgcf from $WGCF_DOWNLOAD_URL"
    fi
    if [ ! -s "$WGCF_BINARY" ]; then
        rm -rf "$WGCF_TEMP_DIR"
        error_exit "Downloaded wgcf binary is empty"
    fi
    chmod +x "$WGCF_BINARY"
    if ! "$WGCF_BINARY" --version >/dev/null 2>&1 && ! "$WGCF_BINARY" help >/dev/null 2>&1; then
        rm -rf "$WGCF_TEMP_DIR"
        error_exit "Downloaded wgcf binary is not executable on this platform"
    fi
    install -m 755 "$WGCF_BINARY" /usr/local/bin/wgcf
    ok "wgcf $WGCF_VERSION installed"

    # Register with Cloudflare WARP. Modern wgcf gates the Terms of Service
    # behind an interactive promptui widget that ignores piped stdin, so the
    # old `yes | wgcf register` no longer works — use --accept-tos. Cloudflare's
    # registration API also returns transient 5xx errors, so retry a few times.
    info "Registering with Cloudflare WARP..."
    local reg_ok=false attempt
    local reg_log="$WGCF_TEMP_DIR/register.log"
    for attempt in 1 2 3; do
        if ( cd "$WGCF_TEMP_DIR" && timeout 30 wgcf register --accept-tos ) >"$reg_log" 2>&1; then
            reg_ok=true
            break
        fi
        warn "WARP registration attempt $attempt failed, retrying in 3s..."
        sleep 3
    done
    if [ "$reg_ok" != true ]; then
        error "Failed to register with Cloudflare WARP after 3 attempts"
        [ -s "$reg_log" ] && tail -n 5 "$reg_log" | sed 's/^/   /'
        restore_dns
        rm -rf "$WGCF_TEMP_DIR"
        error_exit "WARP registration failed (Cloudflare API may be temporarily unavailable)"
    fi

    if ! ( cd "$WGCF_TEMP_DIR" && wgcf generate ) >/dev/null 2>&1; then
        restore_dns
        rm -rf "$WGCF_TEMP_DIR"
        error_exit "Failed to generate WARP configuration"
    fi

    # Configure WARP
    info "Configuring WARP..."
    local WGCF_PROFILE="$WGCF_TEMP_DIR/wgcf-profile.conf"
    if [ ! -f "$WGCF_PROFILE" ]; then
        restore_dns
        rm -rf "$WGCF_TEMP_DIR"
        error_exit "WARP configuration file not found"
    fi

    # Emit a ready-to-paste native Xray `wireguard` outbound from the fresh
    # credentials BEFORE we strip/edit the profile for wg-quick.
    mkdir -p /etc/wireguard
    generate_warp_xray_outbound "$WGCF_PROFILE"
    if [ -f "$WGCF_TEMP_DIR/wgcf-account.toml" ]; then
        cp "$WGCF_TEMP_DIR/wgcf-account.toml" "$WARP_ACCOUNT_FILE"
        chmod 600 "$WARP_ACCOUNT_FILE"
    fi

    # Adapt the profile for wg-quick (the host-interface install path):
    # drop DNS (we manage it), disable routing table, keep the tunnel alive.
    sed -i '/^DNS =/d' "$WGCF_PROFILE"
    if ! grep -q "Table = off" "$WGCF_PROFILE"; then
        sed -i '/^MTU =/a Table = off' "$WGCF_PROFILE"
    fi
    if ! grep -q "PersistentKeepalive = 25" "$WGCF_PROFILE"; then
        sed -i '/^Endpoint =/a PersistentKeepalive = 25' "$WGCF_PROFILE"
    fi

    # Handle IPv6: wgcf emits a single combined "Address = <v4>/32, <v6>/128"
    # line. Strip only the IPv6 token, never the whole line (which holds v4 too).
    if ! check_ipv6_support; then
        warn "IPv6 disabled - removing IPv6 address from config"
        sed -i -E 's#,[[:space:]]*[0-9A-Fa-f:]+/128##g' "$WGCF_PROFILE"
        sed -i -E '/^AllowedIPs/ s#,[[:space:]]*::/0##' "$WGCF_PROFILE"
    fi

    # Install configuration for wg-quick@warp
    mv "$WGCF_PROFILE" "$WARP_CONFIG_FILE"
    chmod 600 "$WARP_CONFIG_FILE"
    ok "WARP configuration installed"

    rm -rf "$WGCF_TEMP_DIR"

    # Enable and start service
    if systemctl enable --now "$WARP_SERVICE" >/dev/null 2>&1; then
        ok "WARP service started ($WARP_SERVICE)"
    else
        warn "WARP service failed to start — check: journalctl -u $WARP_SERVICE"
    fi

    restore_dns

    # Verify connection
    sleep 3
    if verify_warp_connection; then
        ok "WARP installation completed successfully"
    else
        warn "WARP installed but connection verification failed"
    fi

    echo
    info "Native Xray WARP outbound written to: $WARP_XRAY_FILE"
    echo -e "\033[38;5;244m   (paste it into your Xray config — see 'XRay Configuration' menu)\033[0m"
}

# Build a native Xray `wireguard` outbound JSON from a wgcf profile.
# This is the modern, officially-recommended way to use WARP with Xray (>=1.6.5):
# Xray dials WARP directly, with no host wg-quick interface required.
generate_warp_xray_outbound() {
    local profile="$1"
    [ -f "$profile" ] || return 1

    local secret v4 v6 addrs addr_json
    secret=$(grep -E '^PrivateKey' "$profile" | head -1 | sed -E 's/^PrivateKey[[:space:]]*=[[:space:]]*//' | tr -d '[:space:]')
    # Collect every address token across one or more Address lines, classify v4/v6.
    # NB: strip only spaces (tr -d ' '), never newlines — the tokens are one-per-line.
    addrs=$(grep -E '^Address' "$profile" | sed -E 's/^Address[[:space:]]*=[[:space:]]*//' | tr ',' '\n' | tr -d ' ')
    v4=$(echo "$addrs" | grep '\.' | head -1)
    v6=$(echo "$addrs" | grep ':' | head -1)

    if [ -n "$v6" ] && check_ipv6_support; then
        addr_json="\"$v4\", \"$v6\""
    else
        addr_json="\"$v4\""
    fi

    # reserved [0,0,0] works for the generic endpoint. Some Cloudflare PoPs need
    # the account-specific value (from `wgcf-cli generate --xray` or warp-reg).
    cat > "$WARP_XRAY_FILE" <<EOF
{
  "tag": "warp",
  "protocol": "wireguard",
  "settings": {
    "secretKey": "$secret",
    "address": [$addr_json],
    "peers": [
      {
        "publicKey": "$WARP_PEER_PUBLIC_KEY",
        "endpoint": "$WARP_ENDPOINT",
        "allowedIPs": ["0.0.0.0/0", "::/0"]
      }
    ],
    "reserved": [0, 0, 0],
    "mtu": 1280,
    "noKernelTun": false
  }
}
EOF
    chmod 600 "$WARP_XRAY_FILE"
}

check_ipv6_support() {
    sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q ' = 0' && \
    sysctl net.ipv6.conf.default.disable_ipv6 2>/dev/null | grep -q ' = 0' && \
    ip -6 addr show scope global 2>/dev/null | grep -q 'inet6 '
}

verify_warp_connection() {
    curl -s --max-time 10 --interface warp https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -q "warp=on"
}

uninstall_warp() {
    step "Uninstalling WARP..."
    
    # Stop and disable service
    if systemctl is-active --quiet "$WARP_SERVICE" 2>/dev/null; then
        systemctl stop "$WARP_SERVICE" >/dev/null 2>&1
    fi
    if systemctl is-enabled --quiet "$WARP_SERVICE" 2>/dev/null; then
        systemctl disable "$WARP_SERVICE" >/dev/null 2>&1
    fi
    
    # Remove configuration, saved credentials and generated Xray snippet
    rm -f "$WARP_CONFIG_FILE" "$WARP_ACCOUNT_FILE" "$WARP_XRAY_FILE"

    # Remove wgcf binary
    if [ -f /usr/local/bin/wgcf ]; then
        rm -f /usr/local/bin/wgcf
    fi

    ok "WARP uninstalled successfully"
}

# ===== TOR FUNCTIONS =====

install_tor() {
    step "Installing Tor..."
    
    # Проверяем, установлен ли уже Tor (если не принудительная установка)
    if [ "${FORCE_INSTALL:-false}" != "true" ] && [ -f "$TOR_CONFIG_FILE" ]; then
        warn "Tor is already installed and configured at $TOR_CONFIG_FILE"
        echo "Use '--force' flag to reinstall: bash $0 install-tor-force"
        return 1
    fi
    
    # Check if ports are available
    if ! check_tor_ports; then
        error_exit "Required ports (9050, 9051) are not available"
    fi
    
    install_package tor

    # Configure Tor
    info "Configuring Tor..."

    # Backup original config
    if [ -f "$TOR_CONFIG_FILE" ] && [ ! -f "$TOR_CONFIG_FILE.backup" ]; then
        cp "$TOR_CONFIG_FILE" "$TOR_CONFIG_FILE.backup"
    fi

    mkdir -p /etc/tor

    # Optional control-port password (hashed). CookieAuthentication is always on,
    # so the control port is protected even without a password. We only add a
    # HashedControlPassword if hashing actually succeeds.
    local TOR_CONTROL_PASSWORD TOR_HASHED_PASSWORD=""
    if command -v tor >/dev/null 2>&1; then
        TOR_CONTROL_PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)
        TOR_HASHED_PASSWORD=$(tor --hash-password "$TOR_CONTROL_PASSWORD" 2>/dev/null | grep "^16:")
        if [ -n "$TOR_HASHED_PASSWORD" ]; then
            echo "$TOR_CONTROL_PASSWORD" > /etc/tor/.control_password
            chmod 600 /etc/tor/.control_password
            chown debian-tor:debian-tor /etc/tor/.control_password 2>/dev/null || \
                chown tor:tor /etc/tor/.control_password 2>/dev/null || true
        else
            warn "Could not hash a control password — using cookie authentication only"
        fi
    fi

    # Create Tor configuration. Ports are bound explicitly to 127.0.0.1 so the
    # SOCKS proxy and (especially) the control port are never exposed to the
    # network by an accidental default change.
    cat > "$TOR_CONFIG_FILE" <<EOF
# Tor configuration for local proxy mode (managed by wtm)
SocksPort 127.0.0.1:9050
ControlPort 127.0.0.1:9051
${TOR_HASHED_PASSWORD:+HashedControlPassword $TOR_HASHED_PASSWORD}
CookieAuthentication 1
DataDirectory /var/lib/tor
Log notice file /var/log/tor/tor.log

# Only accept SOCKS requests from localhost
SocksPolicy accept 127.0.0.1
SocksPolicy reject *

# Performance / circuit tuning
MaxClientCircuitsPending 48
KeepalivePeriod 60
NewCircuitPeriod 30
MaxCircuitDirtiness 600

# Exit policy - this node never acts as an exit relay
ExitPolicy reject *:*
EOF

    # Set permissions
    chown debian-tor:debian-tor "$TOR_CONFIG_FILE" 2>/dev/null || chown tor:tor "$TOR_CONFIG_FILE" 2>/dev/null
    chmod 644 "$TOR_CONFIG_FILE"

    # Create log directory
    mkdir -p /var/log/tor
    chown debian-tor:debian-tor /var/log/tor 2>/dev/null || chown tor:tor /var/log/tor 2>/dev/null

    # Enable and start Tor
    if systemctl enable --now "$TOR_SERVICE" >/dev/null 2>&1; then
        systemctl restart "$TOR_SERVICE" >/dev/null 2>&1
    else
        warn "Tor service failed to enable/start — check: journalctl -u $TOR_SERVICE"
    fi

    # Wait for Tor to start
    sleep 5

    if verify_tor_connection; then
        ok "Tor installation completed successfully"
    else
        warn "Tor installed but connection verification failed"
    fi
}

verify_tor_connection() {
    # Check if Tor is listening on port 9050 (prefer ss; fall back to netstat)
    ss -tlnp 2>/dev/null | grep -q ":9050" || netstat -tlnp 2>/dev/null | grep -q ":9050"
}

uninstall_tor() {
    step "Uninstalling Tor..."
    
    # Stop and disable service
    if systemctl is-active --quiet "$TOR_SERVICE" 2>/dev/null; then
        systemctl stop "$TOR_SERVICE" >/dev/null 2>&1
    fi
    if systemctl is-enabled --quiet "$TOR_SERVICE" 2>/dev/null; then
        systemctl disable "$TOR_SERVICE" >/dev/null 2>&1
    fi
    
    # Remove package
    case $OS in
        ubuntu|debian)
            apt remove --purge -y tor >/dev/null 2>&1
            ;;
        centos|rhel|rocky|almalinux|fedora)
            yum remove -y tor >/dev/null 2>&1 || dnf remove -y tor >/dev/null 2>&1
            ;;
    esac
    
    # Remove configuration and data
    rm -rf /etc/tor /var/lib/tor /var/log/tor
    
    ok "Tor uninstalled successfully"
}

# ===== STATUS FUNCTIONS =====

get_service_memory() {
    local service="$1"
    local memory_kb
    
    # Специальная обработка для WARP через WireGuard
    if [ "$service" = "wg-quick@warp" ]; then
        # Проверим, активен ли интерфейс warp
        if ip link show warp >/dev/null 2>&1; then
            # Метод 1: Размер модуля wireguard из /proc/modules
            local wg_module_size=$(awk '/^wireguard/ {print $2}' /proc/modules 2>/dev/null)
            
            if [ -n "$wg_module_size" ] && [ "$wg_module_size" -gt 0 ] 2>/dev/null; then
                # Конвертируем байты в KB
                local wg_memory_kb=$((wg_module_size / 1024))
                
                # Добавляем оценку памяти для активных соединений
                local active_peers=$(wg show warp peers 2>/dev/null | wc -l 2>/dev/null || echo 0)
                if [ "$active_peers" -gt 0 ]; then
                    # Примерно 4KB на peer для состояния соединения
                    wg_memory_kb=$((wg_memory_kb + active_peers * 4))
                fi
                
                # Форматируем вывод
                if [ "$wg_memory_kb" -lt 1024 ]; then
                    echo "${wg_memory_kb}KB"
                else
                    local wg_memory_mb=$((wg_memory_kb / 1024))
                    echo "${wg_memory_mb}MB"
                fi
                return
            fi
            
            # Метод 2: Подсчет через kernel workers и интерфейс
            local wg_workers=$(ps aux | grep -c "\[wg-crypt-warp\]\|\[kworker.*wg-crypt-warp\]" 2>/dev/null || echo 0)
            local base_memory=64  # Базовая память для интерфейса
            
            if [ "$wg_workers" -gt 0 ]; then
                # Каждый worker добавляет примерно 8KB
                local total_kb=$((base_memory + wg_workers * 8))
                echo "${total_kb}KB"
                return
            fi
            
            # Метод 3: Проверка через /sys/class/net
            if [ -d "/sys/class/net/warp" ]; then
                # Интерфейс существует, но модуль не найден - минимальная оценка
                echo "~64KB"
                return
            fi
            
            echo "~32KB"
            return
        else
            echo "N/A"
            return
        fi
    fi
    
    # Обычная обработка для других сервисов
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        # Попробуем через systemctl
        memory_kb=$(systemctl show "$service" --property=MemoryCurrent --value 2>/dev/null)
        if [ -n "$memory_kb" ] && [ "$memory_kb" != "[not set]" ] && [ "$memory_kb" != "0" ] && [ "$memory_kb" -gt 0 ] 2>/dev/null; then
            local memory_mb=$((memory_kb / 1024))
            echo "${memory_mb}MB"
            return
        fi
        
        # Попробуем через ps и pgrep
        local pids
        case "$service" in
            "tor")
                pids=$(pgrep -x tor 2>/dev/null)
                ;;
            *)
                pids=$(pgrep -f "$service" 2>/dev/null)
                ;;
        esac
        
        if [ -n "$pids" ]; then
            local total_memory=0
            for pid in $pids; do
                local mem=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
                if [ -n "$mem" ] && [ "$mem" -gt 0 ] 2>/dev/null; then
                    total_memory=$((total_memory + mem))
                fi
            done
            
            if [ "$total_memory" -gt 0 ]; then
                local memory_mb=$((total_memory / 1024))
                echo "${memory_mb}MB"
                return
            fi
        fi
    fi
    
    echo "N/A"
}

check_warp_status() {
    if [ -f "$WARP_CONFIG_FILE" ]; then
        # Проверяем состояние WireGuard интерфейса
        if ip link show warp >/dev/null 2>&1; then
            local warp_state=$(ip link show warp | grep -o "state [A-Z]*" | cut -d' ' -f2)
            if [ "$warp_state" = "UP" ] || [ "$warp_state" = "UNKNOWN" ]; then
                if verify_warp_connection; then
                    echo "running"
                else
                    echo "installed"
                fi
            else
                echo "installed"
            fi
        else
            # Fallback: проверяем через systemctl
            if systemctl is-active --quiet "$WARP_SERVICE" 2>/dev/null; then
                if verify_warp_connection; then
                    echo "running"
                else
                    echo "installed"
                fi
            else
                echo "installed"
            fi
        fi
    else
        echo "not_installed"
    fi
}

check_tor_status() {
    if systemctl is-active --quiet "$TOR_SERVICE" 2>/dev/null; then
        if verify_tor_connection; then
            echo "running"
        else
            echo "installed"
        fi
    elif [ -f "$TOR_CONFIG_FILE" ]; then
        echo "installed"
    else
        echo "not_installed"
    fi
}

show_status() {
    print_banner
    
    # Show system info
    show_system_info
    
    echo -e "\033[1;37m🔍 Network Status:\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    # WARP Status
    local warp_status=$(check_warp_status)
    local warp_memory=""
    
    echo -e "\033[1;36m📡 WARP:\033[0m"
    case $warp_status in
        "running")
            warp_memory=$(get_service_memory "$WARP_SERVICE")
            ok "Active and working (Memory: $warp_memory)"
            echo -e "\033[38;5;250m   Interface: warp\033[0m"
            # Показываем информацию о WireGuard интерфейсе
            if ip link show warp >/dev/null 2>&1; then
                local warp_ip=$(ip addr show warp 2>/dev/null | grep 'inet ' | awk '{print $2}' | head -1)
                if [ -n "$warp_ip" ]; then
                    echo -e "\033[38;5;250m   Local IP: $warp_ip\033[0m"
                fi
            fi
            # Показываем основную информацию WireGuard (без приватного ключа)
            if command -v wg >/dev/null 2>&1; then
                wg show warp 2>/dev/null | grep -E "(endpoint|allowed ips|latest handshake)" | sed 's/^/   /' || true
            fi
            ;;
        "installed")
            warn "Installed but not running"
            ;;
        "not_installed")
            info "Not installed"
            ;;
    esac
    echo
    
    # Tor Status
    local tor_status=$(check_tor_status)
    local tor_memory=""
    
    echo -e "\033[1;36m🧅 Tor:\033[0m"
    case $tor_status in
        "running")
            tor_memory=$(get_service_memory "$TOR_SERVICE")
            ok "Active and running (Memory: $tor_memory)"
            echo -e "\033[38;5;250m   SOCKS5 Proxy: 127.0.0.1:9050\033[0m"
            echo -e "\033[38;5;250m   Control Port: 127.0.0.1:9051\033[0m"
            ;;
        "installed")
            warn "Installed but not running"
            ;;
        "not_installed")
            info "Not installed"
            ;;
    esac
    echo
}

show_logs() {
    local service="$1"
    case $service in
        warp)
            if systemctl is-active --quiet "$WARP_SERVICE" 2>/dev/null; then
                journalctl -u "$WARP_SERVICE" -f --no-pager
            else
                error "WARP service is not running"
            fi
            ;;
        tor)
            if systemctl is-active --quiet "$TOR_SERVICE" 2>/dev/null; then
                journalctl -u "$TOR_SERVICE" -f --no-pager
            else
                error "Tor service is not running"
            fi
            ;;
        *)
            error "Invalid service. Use: warp or tor"
            ;;
    esac
}

# ===== SERVICE CONTROL FUNCTIONS =====

control_service() {
    local action="$1"
    local service_type="$2"
    
    case $service_type in
        warp)
            local service_name="$WARP_SERVICE"
            ;;
        tor)
            local service_name="$TOR_SERVICE"
            ;;
        *)
            error "Invalid service type: $service_type"
            return 1
            ;;
    esac
    
    local past
    case $action in
        start)   past="started" ;;
        stop)    past="stopped" ;;
        restart) past="restarted" ;;
        *)       error "Invalid action: $action"; return 1 ;;
    esac

    # Report the real result of the systemctl operation instead of always
    # printing a green checkmark regardless of exit status.
    if systemctl "$action" "$service_name" >/dev/null 2>&1; then
        ok "$service_type service $past"
    else
        error "Failed to $action $service_type service ($service_name)"
        echo -e "\033[38;5;244m   Check logs: journalctl -u $service_name -n 20 --no-pager\033[0m"
        return 1
    fi
}

show_usage_examples() {
    print_banner
    echo -e "\033[1;37m📖 Usage Examples:\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    echo -e "\033[1;32m🚀 Quick Installation:\033[0m"
    echo -e "\033[38;5;250m   # Install WARP only\033[0m"
    echo -e "\033[38;5;244m   sudo wtm install-warp\033[0m"
    echo
    echo -e "\033[38;5;250m   # Install Tor only\033[0m"
    echo -e "\033[38;5;244m   sudo wtm install-tor\033[0m"
    echo
    echo -e "\033[38;5;250m   # Install both (recommended)\033[0m"
    echo -e "\033[38;5;244m   sudo wtm install-all\033[0m"
    echo
    echo -e "\033[1;33m🔄 Force Installation (overwrite existing):\033[0m"
    echo -e "\033[38;5;250m   # Force reinstall WARP\033[0m"
    echo -e "\033[38;5;244m   sudo wtm install-warp-force\033[0m"
    echo
    echo -e "\033[38;5;250m   # Force reinstall Tor\033[0m"
    echo -e "\033[38;5;244m   sudo wtm install-tor-force\033[0m"
    echo
    echo -e "\033[38;5;250m   # Force reinstall both\033[0m"
    echo -e "\033[38;5;244m   sudo wtm install-all-force\033[0m"
    echo
    
    echo -e "\033[1;32m⚙️ Service Management:\033[0m"
    echo -e "\033[38;5;250m   # Check status\033[0m"
    echo -e "\033[38;5;244m   sudo wtm status\033[0m"
    echo
    echo -e "\033[38;5;250m   # View live logs\033[0m"
    echo -e "\033[38;5;244m   sudo wtm logs warp\033[0m"
    echo -e "\033[38;5;244m   sudo wtm logs tor\033[0m"
    echo
    echo -e "\033[38;5;250m   # Restart services\033[0m"
    echo -e "\033[38;5;244m   sudo wtm restart-warp\033[0m"
    echo -e "\033[38;5;244m   sudo wtm restart-tor\033[0m"
    echo
    
    echo -e "\033[1;32m🧪 Testing & Diagnostics:\033[0m"
    echo -e "\033[38;5;250m   # Test all connections\033[0m"
    echo -e "\033[38;5;244m   sudo wtm test\033[0m"
    echo
    echo -e "\033[38;5;250m   # WARP memory diagnostic\033[0m"
    echo -e "\033[38;5;244m   sudo wtm warp-memory\033[0m"
    echo
    echo -e "\033[38;5;250m   # Test WARP connection\033[0m"
    echo -e "\033[38;5;244m   curl --interface warp https://www.cloudflare.com/cdn-cgi/trace\033[0m"
    echo
    echo -e "\033[38;5;250m   # Test Tor connection\033[0m"
    echo -e "\033[38;5;244m   curl --socks5 127.0.0.1:9050 https://check.torproject.org\033[0m"
    echo
    echo -e "\033[38;5;250m   # Check your IP through WARP\033[0m"
    echo -e "\033[38;5;244m   curl --interface warp https://ipinfo.io\033[0m"
    echo
    echo -e "\033[38;5;250m   # Check your IP through Tor\033[0m"
    echo -e "\033[38;5;244m   curl --socks5 127.0.0.1:9050 https://ipinfo.io\033[0m"
    echo
    
    echo -e "\033[1;32m🔧 System Commands:\033[0m"
    echo -e "\033[38;5;250m   # WARP interface status\033[0m"
    echo -e "\033[38;5;244m   wg show warp\033[0m"
    echo
    echo -e "\033[38;5;250m   # Tor service status\033[0m"
    echo -e "\033[38;5;244m   systemctl status tor\033[0m"
    echo
    echo -e "\033[38;5;250m   # Check listening ports\033[0m"
    echo -e "\033[38;5;244m   ss -tlnp | grep -E ':(9050|9051)'\033[0m"
    echo
    
    echo -e "\033[1;32m🗑️ Uninstallation:\033[0m"
    echo -e "\033[38;5;250m   # Remove WARP only\033[0m"
    echo -e "\033[38;5;244m   sudo wtm remove-warp\033[0m"
    echo
    echo -e "\033[38;5;250m   # Remove Tor only\033[0m"
    echo -e "\033[38;5;244m   sudo wtm remove-tor\033[0m"
    echo
    
    echo -e "\033[1;32m🔄 Updates & Version:\033[0m"
    echo -e "\033[38;5;250m   # Show current version\033[0m"
    echo -e "\033[38;5;244m   wtm version\033[0m"
    echo
    echo -e "\033[38;5;250m   # Check for updates\033[0m"
    echo -e "\033[38;5;244m   wtm check-updates\033[0m"
    echo
    echo -e "\033[38;5;250m   # Auto-update script\033[0m"
    echo -e "\033[38;5;244m   sudo wtm self-update\033[0m"
    echo
    
    echo -e "\033[1;32m⚙️ Script Installation:\033[0m"
    echo -e "\033[38;5;250m   # Install script globally (manual)\033[0m"
    echo -e "\033[38;5;244m   sudo wtm install-script\033[0m"
    echo
    echo -e "\033[38;5;250m   # Uninstall global script\033[0m"
    echo -e "\033[38;5;244m   sudo wtm uninstall-script\033[0m"
    echo
    echo -e "\033[38;5;214m   💡 Note: Script installs automatically when running any install command\033[0m"
    echo -e "\033[38;5;214m      This allows you to use 'wtm' command from anywhere\033[0m"
    echo
    
    echo -e "\033[1;32m❓ Help & Information:\033[0m"
    echo -e "\033[38;5;250m   # Show help\033[0m"
    echo -e "\033[38;5;244m   wtm help\033[0m"
    echo
    echo -e "\033[38;5;250m   # Show system information\033[0m"
    echo -e "\033[38;5;244m   wtm system-info\033[0m"
    echo
    echo -e "\033[38;5;250m   # Show WARP memory diagnostic\033[0m"
    echo -e "\033[38;5;244m   wtm warp-memory\033[0m"
    echo
    echo -e "\033[38;5;250m   # Show usage examples\033[0m"
    echo -e "\033[38;5;244m   wtm usage-examples\033[0m"
    echo
}

# Системная информация
show_system_info() {
    printf "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    printf "${BOLD}                         SYSTEM INFO                          ${NC}\n"
    printf "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n\n"
    
    printf "${BOLD}${CYAN}OS:${NC} $(lsb_release -d 2>/dev/null | cut -f2 || uname -o)\n"
    printf "${BOLD}${CYAN}Kernel:${NC} $(uname -r)\n"
    printf "${BOLD}${CYAN}Arch:${NC} $(uname -m)\n"
    printf "${BOLD}${CYAN}CPU:${NC} $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')\n"
    printf "${BOLD}${CYAN}RAM:${NC} $(free -h | awk '/^Mem:/ {print $3"/"$2}')\n"
    printf "${BOLD}${CYAN}Uptime:${NC} $(uptime -p 2>/dev/null || uptime)\n"
    
    if command -v iptables >/dev/null 2>&1; then
        local rules=$(iptables -L | wc -l)
        printf "${BOLD}${CYAN}Firewall:${NC} $rules rules\n"
    fi
    
    local ip=$(curl -s4 ifconfig.me 2>/dev/null || echo "Unknown")
    printf "${BOLD}${CYAN}Public IP:${NC} $ip\n"
    
    printf "\n${DIM}Press Enter to continue...${NC}"
    read -r
}

# Функция помощи
show_help() {
    printf "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    printf "${BOLD}                           HELP                              ${NC}\n"
    printf "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n\n"
    
    printf "${BOLD}${CYAN}About WARP:${NC}\n"
    printf "Cloudflare WARP is a VPN service that makes your internet safer.\n"
    printf "It encrypts traffic and can improve speed by routing through\n"
    printf "Cloudflare's global network.\n\n"
    
    printf "${BOLD}${CYAN}About Tor:${NC}\n"
    printf "Tor provides anonymous browsing by routing traffic through\n"
    printf "multiple encrypted relays. Slower but highly private.\n\n"
    
    printf "${BOLD}${CYAN}Quick Start:${NC}\n"
    printf "1. Choose 'Install' → 'WARP' or 'Tor'\n"
    printf "2. Configure using 'Config' menu\n"
    printf "3. Test connection with 'Manage' → 'Test'\n\n"
    
    printf "${BOLD}${CYAN}Auto Installation:${NC}\n"
    printf "Script automatically installs globally when you run any\n"
    printf "install command. This allows you to use ${GREEN}wtm${NC} from anywhere.\n\n"
    
    printf "${BOLD}${CYAN}Common Issues:${NC}\n"
    printf "• Run as root: ${GREEN}sudo wtm${NC}\n"
    printf "• Check logs if service fails to start\n"
    printf "• Disable conflicting VPNs\n\n"
    
    printf "${DIM}Press Enter to continue...${NC}"
    read -r
}

# Главное меню в стиле remnanode
# Map a service status string to an ANSI color escape (printed literally, then
# re-interpreted by `echo -e` at the call site).
status_color() {
    case "$1" in
        running)   echo "\033[1;32m" ;;
        installed) echo "\033[1;33m" ;;
        *)         echo "\033[38;5;244m" ;;
    esac
}

# Render the WARP status block. Shared by every menu so the rendering lives in
# exactly one place. $1 = status string from check_warp_status.
render_warp_status_block() {
    local warp_status="$1" color
    color=$(status_color "$warp_status")
    case $warp_status in
        running)
            echo -e "${color}✅ RUNNING\033[0m"
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Memory:" "$(get_service_memory "$WARP_SERVICE")"
            if wg show warp >/dev/null 2>&1; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Active\033[0m\n" "Interface:"
                local endpoint
                endpoint=$(wg show warp 2>/dev/null | grep "endpoint:" | awk '{print $2}')
                [ -n "$endpoint" ] && printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Endpoint:" "$endpoint"
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not found\033[0m\n" "Interface:"
            fi
            ;;
        installed)
            echo -e "${color}⚠️  INSTALLED BUT STOPPED\033[0m"
            echo -e "\033[38;5;244m   Use WARP menu to start service\033[0m"
            ;;
        not_installed)
            echo -e "${color}📦 NOT INSTALLED\033[0m"
            echo -e "\033[38;5;244m   Cloudflare WARP is not installed\033[0m"
            ;;
    esac
}

# Render the Tor status block. Shared by every menu. $1 = check_tor_status.
render_tor_status_block() {
    local tor_status="$1" color
    color=$(status_color "$tor_status")
    case $tor_status in
        running)
            echo -e "${color}✅ RUNNING\033[0m"
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Memory:" "$(get_service_memory "$TOR_SERVICE")"
            if check_port_listening 9050; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ 127.0.0.1:9050\033[0m\n" "SOCKS5:"
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not accessible\033[0m\n" "SOCKS5:"
            fi
            if check_port_listening 9051; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ 127.0.0.1:9051\033[0m\n" "Control:"
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not accessible\033[0m\n" "Control:"
            fi
            ;;
        installed)
            echo -e "${color}⚠️  INSTALLED BUT STOPPED\033[0m"
            echo -e "\033[38;5;244m   Use Tor menu to start service\033[0m"
            ;;
        not_installed)
            echo -e "${color}📦 NOT INSTALLED\033[0m"
            echo -e "\033[38;5;244m   Tor anonymity network is not installed\033[0m"
            ;;
    esac
}

show_main_menu() {
    clear
    echo -e "\033[1;37m🌐 WARP & Tor Manager\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    # Статус сервисов
    local warp_status=$(check_warp_status)
    local tor_status=$(check_tor_status)

    echo -e "\033[1;37m📡 WARP Status:\033[0m"
    render_warp_status_block "$warp_status"

    echo

    echo -e "\033[1;37m🧅 Tor Status:\033[0m"
    render_tor_status_block "$tor_status"

    # Системная информация
    echo
    echo -e "\033[1;37m💾 System Info:\033[0m"
    local ram=$(free -h | awk '/^Mem:/ {print $3"/"$2}' 2>/dev/null || echo "N/A")
    local ip=$(curl -s4 --max-time 3 ifconfig.me 2>/dev/null || echo "Unknown")
    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "RAM Usage:" "$ram"
    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Public IP:" "$ip"
    
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    echo -e "\033[1;37m🛠️  Service Management:\033[0m"
    echo -e "   \033[38;5;15m1)\033[0m 📡 WARP Menu"
    echo -e "   \033[38;5;15m2)\033[0m 🧅 Tor Menu"
    echo -e "   \033[38;5;15m3)\033[0m 🔄 Quick Actions"
    echo
    echo -e "\033[1;37m📊 Monitoring & Tools:\033[0m"
    echo -e "   \033[38;5;15m4)\033[0m 🧪 Test Connections"
    echo -e "   \033[38;5;15m5)\033[0m 📋 View Logs"
    echo -e "   \033[38;5;15m6)\033[0m 💻 System Information"
    echo
    echo -e "\033[1;37m📖 Configuration:\033[0m"
    echo -e "   \033[38;5;15m7)\033[0m ⚙️  XRay Configuration"
    echo -e "   \033[38;5;15m8)\033[0m ❓ Help & Usage Examples"
    echo -e "   \033[38;5;15m9)\033[0m 🔄 Check Updates"
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo -e "\033[38;5;15m   0)\033[0m 🚪 Exit"
    echo
    
    # Подсказки в зависимости от состояния
    if [ "$warp_status" = "not_installed" ] && [ "$tor_status" = "not_installed" ]; then
        echo -e "\033[1;34m💡 Tip: Start with WARP Menu (1) or Tor Menu (2) to install services\033[0m"
    elif [ "$warp_status" = "running" ] || [ "$tor_status" = "running" ]; then
        echo -e "\033[1;34m💡 Tip: Test connections (4) to verify everything works correctly\033[0m"
    else
        echo -e "\033[1;34m💡 Tip: Use service menus to start installed components\033[0m"
    fi
    
    echo -e "\033[38;5;8mWARP & Tor Manager v$SCRIPT_VERSION • Network Proxy Solutions\033[0m"
    echo
    read -p "$(echo -e "\033[1;37mSelect option [0-9]:\033[0m ")" choice
}

# Подменю WARP
show_warp_menu() {
    clear
    echo -e "\033[1;37m📡 WARP Management\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 45))\033[0m"
    echo
    
    local warp_status=$(check_warp_status)

    echo -e "\033[1;37m📡 WARP Status:\033[0m"
    render_warp_status_block "$warp_status"

    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 45))\033[0m"
    echo
    echo -e "\033[1;37m🛠️  Installation & Management:\033[0m"
    echo -e "   \033[38;5;15m1)\033[0m 🛠️  Install WARP"
    echo -e "   \033[38;5;15m2)\033[0m ▶️  Start WARP"
    echo -e "   \033[38;5;15m3)\033[0m ⏹️  Stop WARP"
    echo -e "   \033[38;5;15m4)\033[0m 🔄 Restart WARP"
    echo -e "   \033[38;5;15m5)\033[0m 🗑️  Uninstall WARP"
    echo
    echo -e "\033[1;37m📊 Monitoring:\033[0m"
    echo -e "   \033[38;5;15m6)\033[0m 📊 Show detailed status"
    echo -e "   \033[38;5;15m7)\033[0m 📋 View logs"
    echo -e "   \033[38;5;15m8)\033[0m 🧪 Test WARP connection"
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 45))\033[0m"
    echo -e "\033[38;5;15m   0)\033[0m ← Back to main menu"
    echo
    
    case $warp_status in
        "not_installed")
            echo -e "\033[1;34m💡 Tip: Install WARP (1) to get started with Cloudflare's VPN\033[0m"
            ;;
        "installed")
            echo -e "\033[1;34m💡 Tip: Start WARP (2) to enable the VPN connection\033[0m"
            ;;
        "running")
            echo -e "\033[1;34m💡 Tip: Test connection (8) to verify WARP is working correctly\033[0m"
            ;;
    esac
    
    echo
    read -p "$(echo -e "\033[1;37mSelect option [0-8]:\033[0m ")" choice
}

# Подменю Tor
show_tor_menu() {
    clear
    echo -e "\033[1;37m🧅 Tor Management\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 45))\033[0m"
    echo
    
    local tor_status=$(check_tor_status)

    echo -e "\033[1;37m🧅 Tor Status:\033[0m"
    render_tor_status_block "$tor_status"

    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 45))\033[0m"
    echo
    echo -e "\033[1;37m🛠️  Installation & Management:\033[0m"
    echo -e "   \033[38;5;15m1)\033[0m 🛠️  Install Tor"
    echo -e "   \033[38;5;15m2)\033[0m ▶️  Start Tor"
    echo -e "   \033[38;5;15m3)\033[0m ⏹️  Stop Tor"
    echo -e "   \033[38;5;15m4)\033[0m 🔄 Restart Tor"
    echo -e "   \033[38;5;15m5)\033[0m 🗑️  Uninstall Tor"
    echo
    echo -e "\033[1;37m📊 Monitoring:\033[0m"
    echo -e "   \033[38;5;15m6)\033[0m 📊 Show detailed status"
    echo -e "   \033[38;5;15m7)\033[0m 📋 View logs"
    echo -e "   \033[38;5;15m8)\033[0m 🧪 Test Tor connection"
    echo
    echo -e "\033[1;37m⚙️  Configuration:\033[0m"
    echo -e "   \033[38;5;15m9)\033[0m 🔧 Edit Tor configuration"
    echo -e "   \033[38;5;15m10)\033[0m 🔄 Regenerate identity"
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 45))\033[0m"
    echo -e "\033[38;5;15m   0)\033[0m ← Back to main menu"
    echo
    
    case $tor_status in
        "not_installed")
            echo -e "\033[1;34m💡 Tip: Install Tor (1) to enable anonymous browsing\033[0m"
            ;;
        "installed")
            echo -e "\033[1;34m💡 Tip: Start Tor (2) to enable SOCKS5 proxy on port 9050\033[0m"
            ;;
        "running")
            echo -e "\033[1;34m💡 Tip: Test connection (8) to verify Tor is working correctly\033[0m"
            ;;
    esac
    
    echo
    read -p "$(echo -e "\033[1;37mSelect option [0-10]:\033[0m ")" choice
}

# Подменю быстрых действий
show_quick_actions_menu() {
    clear
    echo -e "\033[1;37m🔄 Quick Actions\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    echo
    
    local warp_status=$(check_warp_status)
    local tor_status=$(check_tor_status)
    
    echo -e "\033[1;37m📊 Current Status:\033[0m"
    printf "   \033[38;5;15m%-8s\033[0m " "WARP:"
    case $warp_status in
        "running") echo -e "\033[1;32m✅ Running\033[0m" ;;
        "installed") echo -e "\033[1;33m⚠️  Stopped\033[0m" ;;
        "not_installed") echo -e "\033[38;5;244m📦 Not installed\033[0m" ;;
    esac
    
    printf "   \033[38;5;15m%-8s\033[0m " "Tor:"
    case $tor_status in
        "running") echo -e "\033[1;32m✅ Running\033[0m" ;;
        "installed") echo -e "\033[1;33m⚠️  Stopped\033[0m" ;;
        "not_installed") echo -e "\033[38;5;244m📦 Not installed\033[0m" ;;
    esac
    
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    echo
    echo -e "\033[1;37m🛠️  Installation:\033[0m"
    echo -e "   \033[38;5;15m1)\033[0m 📡 Install WARP only"
    echo -e "   \033[38;5;15m2)\033[0m 🧅 Install Tor only"
    echo -e "   \033[38;5;15m3)\033[0m 🛠️  Install both services"
    echo
    echo -e "\033[1;37m⚙️  Service Control:\033[0m"
    echo -e "   \033[38;5;15m4)\033[0m ▶️  Start all services"
    echo -e "   \033[38;5;15m5)\033[0m ⏹️  Stop all services"
    echo -e "   \033[38;5;15m6)\033[0m 🔄 Restart all services"
    echo
    echo -e "\033[1;37m🗑️  Cleanup:\033[0m"
    echo -e "   \033[38;5;15m7)\033[0m 🗑️  Uninstall WARP"
    echo -e "   \033[38;5;15m8)\033[0m 🗑️  Uninstall Tor"
    echo -e "   \033[38;5;15m9)\033[0m 🗑️  Uninstall everything"
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    echo -e "\033[38;5;15m   0)\033[0m ← Back to main menu"
    echo
    
    echo -e "\033[1;34m💡 Tip: Use this menu for batch operations on both services\033[0m"
    echo
    read -p "$(echo -e "\033[1;37mSelect option [0-9]:\033[0m ")" choice
}

# Примеры использования (страница 2)
show_usage_examples_page() {
    clear
    printf "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    printf "${BOLD}                      USAGE EXAMPLES                         ${NC}\n"
    printf "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n\n"
    
    printf "${BOLD}${CYAN}WARP (via WireGuard interface):${NC}\n\n"
    
    printf "${BOLD}curl with WARP:${NC}\n"
    printf "${GREEN}curl --interface warp https://ifconfig.me${NC}\n\n"
    
    printf "${BOLD}wget with WARP:${NC}\n"
    printf "${GREEN}wget --bind-address=warp https://example.com${NC}\n\n"
    
    printf "${BOLD}Check WARP status:${NC}\n"
    printf "${GREEN}wg show warp${NC}\n"
    printf "${GREEN}curl --interface warp https://www.cloudflare.com/cdn-cgi/trace${NC}\n\n"
    
    printf "${BOLD}${CYAN}Tor (via SOCKS5 proxy):${NC}\n\n"
    
    printf "${BOLD}curl with Tor:${NC}\n"
    printf "${GREEN}curl --socks5 127.0.0.1:9050 https://ifconfig.me${NC}\n\n"
    
    printf "${BOLD}SSH through Tor:${NC}\n"
    printf "${GREEN}ssh -o ProxyCommand='nc -X 5 -x 127.0.0.1:9050 %%h %%p' user@server${NC}\n\n"
    
    printf "${BOLD}Git with Tor:${NC}\n"
    printf "${GREEN}git config --global http.proxy socks5://127.0.0.1:9050${NC}\n\n"
    
    printf "${DIM}Press Enter to continue...${NC}"
    read -r
}

# Команды тестирования (страница 3)
show_testing_commands_page() {
    clear
    printf "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    printf "${BOLD}                    TESTING COMMANDS                         ${NC}\n"
    printf "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n\n"
    
    printf "${BOLD}${CYAN}Check Your IP:${NC}\n"
    printf "${GREEN}curl ifconfig.me${NC} ${DIM}# Direct connection${NC}\n"
    printf "${GREEN}curl --interface warp ifconfig.me${NC} ${DIM}# Through WARP${NC}\n"
    printf "${GREEN}curl --socks5 127.0.0.1:9050 ifconfig.me${NC} ${DIM}# Through Tor${NC}\n\n"
    
    printf "${BOLD}${CYAN}Test WARP Interface:${NC}\n"
    printf "${GREEN}wg show warp${NC} ${DIM}# Check WireGuard interface${NC}\n"
    printf "${GREEN}ip link show warp${NC} ${DIM}# Check interface status${NC}\n\n"
    
    printf "${BOLD}${CYAN}Test Tor Connection:${NC}\n"
    printf "${GREEN}ss -tuln | grep ':9050'${NC} ${DIM}# Check SOCKS5 port${NC}\n"
    printf "${GREEN}ss -tuln | grep ':9051'${NC} ${DIM}# Check control port${NC}\n"
    printf "${GREEN}curl --socks5 127.0.0.1:9050 ifconfig.me${NC} ${DIM}# Test connection${NC}\n\n"
    
    printf "${BOLD}${CYAN}Cloudflare WARP Test:${NC}\n"
    printf "${GREEN}curl --interface warp https://www.cloudflare.com/cdn-cgi/trace${NC}\n\n"
    
    printf "${BOLD}${CYAN}Tor Project Test:${NC}\n"
    printf "${GREEN}curl --socks5 127.0.0.1:9050 https://check.torproject.org${NC}\n\n"
    
    printf "${BOLD}${CYAN}Speed Tests:${NC}\n"
    printf "${GREEN}curl --interface warp -o /dev/null -s -w \"%%{time_total}\\n\" https://speedtest.net${NC}\n"
    printf "${GREEN}curl --socks5 127.0.0.1:9050 -o /dev/null -s -w \"%%{time_total}\\n\" https://speedtest.net${NC}\n\n"
    
    printf "${DIM}Press Enter to continue...${NC}"
    read -r
}

# Конфигурация XRay (страница 4)
show_xray_config_page() {
    clear
    printf "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    printf "${BOLD}                     XRAY CONFIGURATION                      ${NC}\n"
    printf "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n\n"

    printf "${BOLD}${CYAN}WARP via native Xray WireGuard outbound (recommended)${NC}\n"
    printf "${DIM}Xray-core (>=1.6.5, current v26.x) dials WARP directly — no host${NC}\n"
    printf "${DIM}wg-quick interface, /etc/wireguard/warp.conf or kernel module needed.${NC}\n\n"

    if [ -f "$WARP_XRAY_FILE" ]; then
        printf "${YELLOW}A ready-to-use outbound with YOUR WARP keys was generated at:${NC}\n"
        printf "${GREEN}  $WARP_XRAY_FILE${NC}\n\n"
        printf "${DIM}Current contents (paste as one of your Xray outbounds):${NC}\n"
        printf "${GREEN}"
        cat "$WARP_XRAY_FILE"
        printf "${NC}\n\n"
    else
        printf "${DIM}Template — fill secretKey/address from your wgcf profile${NC}\n"
        printf "${DIM}(install WARP via this script to auto-generate a filled version):${NC}\n"
        printf "${GREEN}"
        cat <<'EOF'
{
  "tag": "warp",
  "protocol": "wireguard",
  "settings": {
    "secretKey": "<wgcf PrivateKey>",
    "address": ["172.16.0.2/32", "2606:4700:110:8949:...:c8e1/128"],
    "peers": [
      {
        "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
        "endpoint": "engage.cloudflareclient.com:2408",
        "allowedIPs": ["0.0.0.0/0", "::/0"]
      }
    ],
    "reserved": [0, 0, 0],
    "mtu": 1280
  }
}
EOF
        printf "${NC}\n\n"
    fi

    printf "${YELLOW}• In Docker / read-only or unprivileged hosts add  \"noKernelTun\": true${NC}\n"
    printf "${YELLOW}• Some Cloudflare PoPs need a real \"reserved\" — get it from${NC}\n"
    printf "${YELLOW}  'wgcf-cli generate --xray' or the warp-reg one-liner${NC}\n\n"

    printf "${BOLD}${CYAN}Full example: WARP + Tor + routing${NC}\n\n"
    printf "${GREEN}"
    cat <<'EOF'
{
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    {
      "tag": "warp",
      "protocol": "wireguard",
      "settings": {
        "secretKey": "<wgcf PrivateKey>",
        "address": ["172.16.0.2/32"],
        "peers": [
          {
            "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
            "endpoint": "engage.cloudflareclient.com:2408"
          }
        ],
        "reserved": [0, 0, 0]
      }
    },
    {
      "tag": "tor",
      "protocol": "socks",
      "settings": {
        "servers": [{ "address": "127.0.0.1", "port": 9050 }]
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "inboundTag": ["VTR-USA", "VTR-NL", "to-foreign-inbound"],
        "outboundTag": "tor",
        "domain": [
          "regexp:.*\\.onion$",
          "domain:duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion"
        ]
      },
      {
        "inboundTag": ["VTR-USA", "VTR-NL", "to-foreign-inbound"],
        "outboundTag": "warp",
        "domain": [
          "geosite:category-ads-all",
          "geosite:google",
          "geosite:cloudflare",
          "geosite:youtube",
          "geosite:netflix"
        ]
      },
      {
        "inboundTag": ["VTR-RU", "VTR-LOCAL", "local-inbound"],
        "outboundTag": "direct",
        "domain": ["geosite:private", "geosite:cn", "geosite:ru"]
      }
    ]
  }
}
EOF
    printf "${NC}\n\n"

    printf "${BOLD}${CYAN}Routing intent:${NC}\n"
    printf "${YELLOW}• Foreign inbounds + .onion        → Tor SOCKS5 (127.0.0.1:9050)${NC}\n"
    printf "${YELLOW}• Foreign inbounds + Ads/Streaming → WARP (native wireguard)${NC}\n"
    printf "${YELLOW}• Local inbounds + Private/RU/CN    → Direct${NC}\n\n"

    printf "${BOLD}${CYAN}Notes for the latest Xray-core (v26.x):${NC}\n"
    printf "${YELLOW}• Routing rules no longer need  \"type\": \"field\"  (removed/ignored).${NC}\n"
    printf "${YELLOW}• geosite:/geoip: tags need geosite.dat/geoip.dat in${NC}\n"
    printf "${YELLOW}  /usr/local/share/xray/  (or set XRAY_LOCATION_ASSET).${NC}\n"
    printf "${YELLOW}• A wireguard outbound can NOT carry streamSettings/sockopt;${NC}\n"
    printf "${YELLOW}  to chain it behind another proxy use dialerProxy on that proxy.${NC}\n\n"

    printf "${BOLD}${CYAN}Legacy host-interface variant (non-Xray host apps):${NC}\n"
    printf "${DIM}This script also installs a wg-quick@warp kernel interface. It is${NC}\n"
    printf "${DIM}fine for host tools (curl --interface warp), but for Xray prefer the${NC}\n"
    printf "${DIM}native outbound above — the old freedom + sockopt.interface:\"warp\"${NC}\n"
    printf "${DIM}config depends on that kernel interface and fails in many containers.${NC}\n\n"

    printf "${DIM}Press Enter to continue...${NC}"
    read -r
}

# Функция для тестирования соединений
test_connections() {
    clear
    echo -e "\033[1;37m🧪 Connection Testing\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 45))\033[0m"
    echo
    
    echo -e "\033[1;37m🌐 Testing direct connection...\033[0m"
    local direct_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "Failed")
    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Direct IP:" "$direct_ip"
    echo
    
    # Тест WARP
    echo -e "\033[1;37m📡 Testing WARP...\033[0m"
    local warp_status=$(check_warp_status)
    
    if [ "$warp_status" = "running" ]; then
        # Проверяем через WireGuard интерфейс
        if wg show warp >/dev/null 2>&1; then
            local warp_ip=$(curl -s --max-time 10 --interface warp https://ifconfig.me 2>/dev/null || echo "Failed")
            if [ "$warp_ip" != "Failed" ]; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ %s\033[0m\n" "WARP IP:" "$warp_ip"
                if [ "$direct_ip" != "$warp_ip" ]; then
                    printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Working correctly\033[0m\n" "Status:"
                else
                    printf "   \033[38;5;15m%-12s\033[0m \033[1;33m⚠️  IP not changed\033[0m\n" "Status:"
                fi
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Connection failed\033[0m\n" "WARP IP:"
            fi
        else
            printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Interface not found\033[0m\n" "WireGuard:"
        fi
        
        # Проверяем Cloudflare trace
        local trace_result=$(curl -s --max-time 10 --interface warp https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep "warp=" || echo "warp=off")
        local warp_enabled=$(echo "$trace_result" | cut -d'=' -f2)
        if [ "$warp_enabled" = "on" ]; then
            printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Verified by Cloudflare\033[0m\n" "CF Trace:"
        else
            printf "   \033[38;5;15m%-12s\033[0m \033[1;33m⚠️  Not detected by CF\033[0m\n" "CF Trace:"
        fi
    else
        printf "   \033[38;5;15m%-12s\033[0m \033[38;5;244m📦 Service not running\033[0m\n" "Status:"
    fi
    
    echo
    
    # Тест Tor
    echo -e "\033[1;37m🧅 Testing Tor...\033[0m"
    local tor_status=$(check_tor_status)
    
    if [ "$tor_status" = "running" ]; then
        # Проверяем SOCKS5 порт
        if check_port_listening 9050; then
            printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Accessible\033[0m\n" "SOCKS5:"
            
            # Тестируем соединение через Tor
            local tor_ip=$(curl -s --max-time 15 --socks5 127.0.0.1:9050 https://ifconfig.me 2>/dev/null || echo "Failed")
            if [ "$tor_ip" != "Failed" ]; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ %s\033[0m\n" "Tor IP:" "$tor_ip"
                if [ "$direct_ip" != "$tor_ip" ]; then
                    printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Working correctly\033[0m\n" "Status:"
                else
                    printf "   \033[38;5;15m%-12s\033[0m \033[1;33m⚠️  IP not changed\033[0m\n" "Status:"
                fi
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Connection failed\033[0m\n" "Tor IP:"
            fi
            
            # Проверяем через Tor Project
            local tor_check=$(curl -s --max-time 15 --socks5 127.0.0.1:9050 https://check.torproject.org 2>/dev/null | grep -o "Congratulations" || echo "Failed")
            if [ "$tor_check" = "Congratulations" ]; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Verified by Tor Project\033[0m\n" "Tor Check:"
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;33m⚠️  Could not verify\033[0m\n" "Tor Check:"
            fi
        else
            printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Port 9050 not accessible\033[0m\n" "SOCKS5:"
        fi
        
        # Проверяем контрольный порт
        if check_port_listening 9051; then
            printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Accessible\033[0m\n" "Control:"
        else
            printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Port 9051 not accessible\033[0m\n" "Control:"
        fi
    else
        printf "   \033[38;5;15m%-12s\033[0m \033[38;5;244m📦 Service not running\033[0m\n" "Status:"
    fi
    
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 45))\033[0m"
    echo
    
    # Общая сводка
    local working_services=0
    if [ "$warp_status" = "running" ] && wg show warp >/dev/null 2>&1; then
        working_services=$((working_services + 1))
    fi
    if [ "$tor_status" = "running" ] && check_port_listening 9050; then
        working_services=$((working_services + 1))
    fi
    
    echo -e "\033[1;37m📊 Summary:\033[0m"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%d/2 services working\033[0m\n" "Active Services:" "$working_services"
    
    if [ $working_services -eq 2 ]; then
        echo -e "\033[1;32m✅ All proxy services are working correctly!\033[0m"
    elif [ $working_services -eq 1 ]; then
        echo -e "\033[1;33m⚠️  Some services need attention\033[0m"
    else
        echo -e "\033[1;31m❌ No proxy services are working\033[0m"
    fi
    
    echo
    read -p "$(echo -e "\033[1;37mPress Enter to continue...\033[0m ")"
}

# Алиасы для совместимости с новой системой меню
install_warp_client() {
    print_banner
    auto_install_script_if_needed
    detect_os
    detect_arch
    update_packages
    install_warp
}

install_tor_complete() {
    print_banner
    auto_install_script_if_needed
    detect_os
    detect_arch
    update_packages
    install_tor
}

remove_warp_client() {
    print_banner
    uninstall_warp
}

remove_tor() {
    print_banner
    uninstall_tor
}

# ===== XRAY EXAMPLES FUNCTION =====

show_xray_examples() {
    show_xray_config_page
}

# ===== WARP MEMORY DIAGNOSTIC FUNCTION =====

get_warp_memory_detailed() {
    echo -e "\033[1;37m🔍 WARP Memory Diagnostic:\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    
    # 1. Проверка интерфейса
    if ip link show warp >/dev/null 2>&1; then
        echo -e "\033[1;32m✅ Interface warp exists\033[0m"
    else
        echo -e "\033[1;31m❌ Interface warp not found\033[0m"
        return 1
    fi
    
    # 2. Размер модуля WireGuard
    if [ -f "/proc/modules" ]; then
        local wg_info=$(grep "^wireguard" /proc/modules 2>/dev/null)
        if [ -n "$wg_info" ]; then
            echo -e "   ✅ Module loaded: $wg_info"
            local wg_size=$(echo "$wg_info" | awk '{print $2}')
            local wg_size_kb=$((wg_size / 1024))
            echo -e "   📊 Module size: ${wg_size} bytes (${wg_size_kb}KB)"
        else
            echo -e "   ❌ WireGuard module not found in /proc/modules"
        fi
    else
        echo -e "   ❌ /proc/modules not accessible"
    fi
    echo
    
    # 3. Проверка kernel workers
    echo -e "\033[1;36m⚙️ Kernel Workers:\033[0m"
    local workers=$(ps aux | grep -E "\[wg-crypt-warp\]|\[kworker.*wg-crypt-warp\]" | grep -v grep 2>/dev/null)
    if [ -n "$workers" ]; then
        local worker_count=$(echo "$workers" | wc -l)
        echo -e "   ✅ Found $worker_count WireGuard workers"
        echo "$workers" | sed 's/^/   /' | head -5
        if [ "$worker_count" -gt 5 ]; then
            echo -e "   \033[38;5;244m   ... and $((worker_count - 5)) more\033[0m"
        fi
    else
        echo -e "   ⚠️  No WireGuard workers found"
    fi
    echo
    
    # 4. Проверка активных соединений
    echo -e "\033[1;36m🔗 Active Connections:\033[0m"
    if command -v wg >/dev/null 2>&1; then
        local peer_info=$(wg show warp 2>/dev/null)
        if [ -n "$peer_info" ]; then
            echo -e "   ✅ WireGuard interface active"
            local peer_count=$(echo "$peer_info" | grep "peer:" | wc -l 2>/dev/null || echo 0)
            echo -e "   📊 Active peers: $peer_count"
            if [ "$peer_count" -gt 0 ]; then
                wg show warp | sed 's/^/   /'
            fi
        else
            echo -e "   ⚠️  No active WireGuard connections"
        fi
    else
        echo -e "   ❌ wg command not available"
    fi
    echo
    
    # 5. Проверка systemd сервиса
    echo -e "\033[1;36m🔧 Service Status:\033[0m"
    local service_status=$(systemctl is-active wg-quick@warp 2>/dev/null || echo "unknown")
    local service_memory=$(systemctl show wg-quick@warp --property=MemoryCurrent --value 2>/dev/null)
    
    echo -e "   Status: $service_status"
    echo -e "   Memory (systemd): $service_memory"
    
    local last_start=$(systemctl show wg-quick@warp --property=ActiveEnterTimestamp --value 2>/dev/null)
    if [ -n "$last_start" ] && [ "$last_start" != "n/a" ]; then
        echo -e "   Last start: $last_start"
    fi
    echo
    
    # Итоговая оценка памяти
    echo -e "\033[1;36m📊 Memory Estimation:\033[0m"
    local estimated_memory=$(get_service_memory "wg-quick@warp")
    echo -e "   💾 Estimated usage: \033[1;32m$estimated_memory\033[0m"
    echo
    
    echo -e "\033[1;33m💡 Note:\033[0m WireGuard operates in kernel space, making exact"
    echo -e "   memory measurement challenging. Values are estimated based on"
    echo -e "   module size, active workers, and connection state."
    echo
    
    read -p "Press Enter to continue..."
}

# ===== SCRIPT INSTALLATION FUNCTIONS =====

# Автоматическая установка скрипта в систему (если не установлен)
auto_install_script_if_needed() {
    # Проверяем, установлен ли скрипт уже
    if [ -f "/usr/local/bin/wtm" ]; then
        return 0  # Уже установлен
    fi
    
    # Проверяем, запущен ли скрипт локально (не из /usr/local/bin)
    local script_path="$(readlink -f "${BASH_SOURCE[0]}")"
    if [[ "$script_path" != "/usr/local/bin/wtm" ]]; then
        # Проверяем, что это не повторный вызов в той же сессии
        if [ "$AUTO_INSTALL_ATTEMPTED" = "true" ]; then
            return 0
        fi
        export AUTO_INSTALL_ATTEMPTED="true"
        
        echo
        info "Installing WTM script globally for easy access..."
        echo -e "\033[38;5;244m   This will allow you to use 'wtm' command from anywhere\033[0m"

        if download_and_install_wtm; then
            ok "✅ WTM script installed successfully at /usr/local/bin/wtm"
            echo -e "\033[1;37m💡 You can now use 'wtm' command from anywhere!\033[0m"
            echo
        else
            warn "Failed to install script globally, continuing with installation..."
        fi
    fi
}

install_wtm_script_globally() {
    info "Installing WARP & Tor Manager script globally..."
    if download_and_install_wtm; then
        ok "WTM script installed successfully at /usr/local/bin/wtm"
    else
        error_exit "Failed to install WTM script globally"
    fi
}

install_script_command() {
    check_root
    info "Installing WTM script globally"
    install_wtm_script_globally
    ok "✅ Script installed successfully!"
    echo -e "\033[1;37mYou can now run 'wtm' from anywhere\033[0m"
    echo
    echo -e "\033[1;37m📋 Quick commands to try:\033[0m"
    echo -e "   \033[38;5;15mwtm version\033[0m       - Show version information"
    echo -e "   \033[38;5;15mwtm status\033[0m        - Check services status"
    echo -e "   \033[38;5;15mwtm install-all\033[0m   - Install WARP + Tor"
    echo -e "   \033[38;5;15mwtm help\033[0m          - Show help information"
}

uninstall_script_command() {
    check_root
    if [ ! -f "/usr/local/bin/wtm" ]; then
        warn "WTM script is not installed globally"
        echo "Nothing to uninstall"
        exit 0
    fi
    
    read -p "Are you sure you want to remove the WTM script? (y/n): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 0
    fi
    
    info "Removing WTM script"
    rm -f /usr/local/bin/wtm
    ok "✅ Script removed successfully!"
}

# ===== MAIN FUNCTION =====

# Основная функция - обновленная версия
main() {
    check_root
    setup_colors
    
    # Если есть аргументы командной строки, выполняем их
    if [ -n "$COMMAND" ]; then
        case "$COMMAND" in
            install-warp)
                install_warp_client
                ;;
            install-warp-force|install-warp-f)
                FORCE_INSTALL=true install_warp_client
                ;;
            install-tor)
                install_tor_complete
                ;;
            install-tor-force|install-tor-f)
                FORCE_INSTALL=true install_tor_complete
                ;;
            install-all)
                install_warp_client && install_tor_complete
                ;;
            install-all-force|install-all-f)
                FORCE_INSTALL=true install_warp_client && FORCE_INSTALL=true install_tor_complete
                ;;
            remove-warp)
                remove_warp_client
                ;;
            remove-tor)
                remove_tor
                ;;
            install-script)
                install_script_command
                ;;
            uninstall-script)
                uninstall_script_command
                ;;
            status)
                show_status
                ;;
            logs)
                # Поддержка разных форматов: wtm logs, wtm logs warp, wtm logs tor
                if [ -n "$1" ]; then
                    show_logs "$1"
                else
                    show_logs warp
                fi
                ;;
            logs-warp)
                show_logs warp
                ;;
            logs-tor)
                show_logs tor
                ;;
            test)
                test_connections
                ;;
            system-info)
                show_system_info
                ;;
            warp-memory)
                get_warp_memory_detailed
                ;;
            start-warp)
                control_service start warp
                ;;
            stop-warp)
                control_service stop warp
                ;;
            restart-warp)
                control_service restart warp
                ;;
            start-tor)
                control_service start tor
                ;;
            stop-tor)
                control_service stop tor
                ;;
            restart-tor)
                control_service restart tor
                ;;
            xray-examples)
                show_xray_examples
                ;;
            usage-examples)
                show_usage_examples
                ;;
            version|--version|-v)
                show_version
                ;;
            check-updates)
                check_for_updates
                ;;
            self-update|update)
                self_update
                ;;
            help|--help|-h)
                usage
                ;;
            *)
                error "Unknown command: $COMMAND"
                echo "Use '$0 help' for available commands"
                exit 1
                ;;
        esac
        return
    fi
    
    # Интерактивный режим - автоматическая установка скрипта если нужно
    auto_install_script_if_needed
    
    # Интерактивный режим - проверяем обновления при первом запуске
    if check_for_updates 2>/dev/null; then
        echo
    fi
    
    # Интерактивный режим - основной цикл меню
    while true; do
        show_main_menu
        
        case "$choice" in
            1)
                # WARP Menu
                while true; do
                    show_warp_menu
                    case "$choice" in
                        1) install_warp_client; read -p "Press Enter to continue..." ;;
                        2) control_service start warp; read -p "Press Enter to continue..." ;;
                        3) control_service stop warp; read -p "Press Enter to continue..." ;;
                        4) control_service restart warp; read -p "Press Enter to continue..." ;;
                        5) remove_warp_client; read -p "Press Enter to continue..." ;;
                        6) show_status; read -p "Press Enter to continue..." ;;
                        7) show_logs warp ;;
                        8) test_connections ;;
                        0) break ;;
                        *) echo -e "\033[1;31mInvalid option. Press Enter to try again...\033[0m"; read ;;
                    esac
                done
                ;;
            2)
                # Tor Menu
                while true; do
                    show_tor_menu
                    case "$choice" in
                        1) install_tor_complete; read -p "Press Enter to continue..." ;;
                        2) control_service start tor; read -p "Press Enter to continue..." ;;
                        3) control_service stop tor; read -p "Press Enter to continue..." ;;
                        4) control_service restart tor; read -p "Press Enter to continue..." ;;
                        5) remove_tor; read -p "Press Enter to continue..." ;;
                        6) show_status; read -p "Press Enter to continue..." ;;
                        7) show_logs tor ;;
                        8) test_connections ;;
                        9)
                            if [ -f "$TOR_CONFIG_FILE" ]; then
                                edit_file "$TOR_CONFIG_FILE"
                            else
                                echo "Tor config file not found"
                                read -p "Press Enter to continue..."
                            fi
                            ;;
                        10)
                            if systemctl is-active --quiet "$TOR_SERVICE" 2>/dev/null; then
                                if systemctl reload "$TOR_SERVICE" >/dev/null 2>&1; then
                                    echo "Tor identity regenerated"
                                else
                                    echo "Failed to reload Tor (check: journalctl -u $TOR_SERVICE)"
                                fi
                            else
                                echo "Tor service is not running"
                            fi
                            read -p "Press Enter to continue..."
                            ;;
                        0) break ;;
                        *) echo -e "\033[1;31mInvalid option. Press Enter to try again...\033[0m"; read ;;
                    esac
                done
                ;;
            3)
                # Quick Actions Menu
                while true; do
                    show_quick_actions_menu
                    case "$choice" in
                        1) install_warp_client; read -p "Press Enter to continue..." ;;
                        2) install_tor_complete; read -p "Press Enter to continue..." ;;
                        3) install_warp_client && install_tor_complete; read -p "Press Enter to continue..." ;;
                        4) 
                            control_service start warp
                            control_service start tor
                            read -p "Press Enter to continue..."
                            ;;
                        5)
                            control_service stop warp
                            control_service stop tor
                            read -p "Press Enter to continue..."
                            ;;
                        6)
                            control_service restart warp
                            control_service restart tor
                            read -p "Press Enter to continue..."
                            ;;
                        7) remove_warp_client; read -p "Press Enter to continue..." ;;
                        8) remove_tor; read -p "Press Enter to continue..." ;;
                        9) 
                            remove_warp_client
                            remove_tor
                            read -p "Press Enter to continue..."
                            ;;
                        0) break ;;
                        *) echo -e "\033[1;31mInvalid option. Press Enter to try again...\033[0m"; read ;;
                    esac
                done
                ;;
            4)
                # Test Connections
                test_connections
                ;;
            5)
                # View Logs Menu
                clear
                echo -e "\033[1;37m📋 View Logs\033[0m"
                echo "1) WARP Logs"
                echo "2) Tor Logs"
                echo "0) Back"
                read -p "Select option: " log_choice
                case "$log_choice" in
                    1) show_logs warp ;;
                    2) show_logs tor ;;
                esac
                ;;
            6)
                # System Information
                show_system_info
                ;;
            7)
                # XRay Configuration
                show_xray_config_page
                ;;
            8)
                # Help & Usage Examples
                clear
                echo -e "\033[1;37m❓ Help & Usage\033[0m"
                echo "1) General Help"
                echo "2) Usage Examples"
                echo "3) Testing Commands"
                echo "0) Back"
                read -p "Select option: " help_choice
                case "$help_choice" in
                    1) show_help ;;
                    2) show_usage_examples_page ;;
                    3) show_testing_commands_page ;;
                esac
                ;;
            9)
                # Check Updates
                clear
                echo -e "\033[1;37m🔄 Update Manager\033[0m"
                echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
                echo
                show_version
                echo
                if check_for_updates; then
                    echo
                    read -p "Do you want to update now? (y/n): " update_choice
                    if [[ "$update_choice" =~ ^[Yy]$ ]]; then
                        self_update
                    fi
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            0)
                echo -e "\033[1;32m👋 Goodbye!\033[0m"
                exit 0
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Press Enter to try again...\033[0m"
                read -r
                ;;
        esac
    done
}

# Run main function
main "$@"
