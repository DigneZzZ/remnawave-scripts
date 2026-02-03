#!/usr/bin/env bash
# WARP & Tor Network Setup Script
# This script installs and manages Cloudflare WARP and Tor connections
# VERSION=1.3.0

set -eE
SCRIPT_VERSION="1.3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Error handler for debugging
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

error_handler() {
    local exit_code=$1 line=$2 command=$3
    # Skip if exit code is 0 or command contains expected failures
    [[ $exit_code -eq 0 ]] && return
    # Don't exit on grep/check failures (expected in conditionals)
    [[ "$command" =~ (grep|check_|verify_) ]] && return
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

# Configuration
WARP_CONFIG_FILE="/etc/wireguard/warp.conf"
TOR_CONFIG_FILE="/etc/tor/torrc"
WARP_SERVICE="wg-quick@warp"
TOR_SERVICE="tor"
LOG_FILE="/var/log/wtm.log"

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

check_port_available() {
    local port=$1
    if netstat -tlnp 2>/dev/null | grep -q ":$port " || ss -tlnp 2>/dev/null | grep -q ":$port "; then
        return 1  # Port is occupied
    fi
    return 0  # Port is free
}

check_tor_ports() {
    local socks_port=9050
    local control_port=9051
    
    if ! check_port_available $socks_port; then
        warn "Port $socks_port is already in use"
        echo -e "\033[38;5;244m   Process using port $socks_port:\033[0m"
        netstat -tlnp 2>/dev/null | grep ":$socks_port " | sed 's/^/   /' || ss -tlnp 2>/dev/null | grep ":$socks_port " | sed 's/^/   /'
        return 1
    fi
    
    if ! check_port_available $control_port; then
        warn "Port $control_port is already in use"
        echo -e "\033[38;5;244m   Process using port $control_port:\033[0m"
        netstat -tlnp 2>/dev/null | grep ":$control_port " | sed 's/^/   /' || ss -tlnp 2>/dev/null | grep ":$control_port " | sed 's/^/   /'
        return 1
    fi
    
    return 0
}

# Функция для проверки доступности порта (для отображения в меню)
check_port_listening() {
    local port=$1
    local host=${2:-127.0.0.1}
    
    # Проверяем через netstat или ss
    if netstat -tlnp 2>/dev/null | grep -q "${host}:${port} " || ss -tlnp 2>/dev/null | grep -q "${host}:${port} "; then
        return 0  # Порт слушается
    fi
    
    # Fallback: пробуем через bash TCP redirect (если доступно)
    if command -v bash >/dev/null 2>&1; then
        if timeout 1 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
            return 0
        fi
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
    remote_script_version=$(curl -s "$SCRIPT_URL" 2>/dev/null | grep -m1 "^# VERSION=" | cut -d'=' -f2)
    
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

update_wtm_script() {
    info "Updating WARP & Tor Manager script..."
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/wtm
    ok "WARP & Tor Manager script updated successfully"
}

self_update() {
    if [[ "$(id -u)" != "0" ]]; then
        error "This operation requires root privileges"
        echo "Please run: sudo wtm self-update"
        exit 1
    fi
    
    local remote_script_version
    remote_script_version=$(curl -s "$SCRIPT_URL" 2>/dev/null | grep -m1 "^# VERSION=" | cut -d'=' -f2)
    
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
    info "Updating package lists..."
    case $OS in
        ubuntu|debian)
            apt update -qq >/dev/null 2>&1 || error_exit "Failed to update package lists"
            ;;
        centos|rhel|rocky|almalinux)
            yum update -y >/dev/null 2>&1 || error_exit "Failed to update package lists"
            ;;
        fedora)
            dnf update -y >/dev/null 2>&1 || error_exit "Failed to update package lists"
            ;;
        *)
            error_exit "Unsupported OS: $OS"
            ;;
    esac
    ok "Package lists updated"
}

install_package() {
    local packages="$1"
    info "Installing $packages..."
    case $OS in
        ubuntu|debian)
            apt install -y $packages >/dev/null 2>&1 || error_exit "Failed to install $packages"
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y $packages >/dev/null 2>&1 || error_exit "Failed to install $packages"
            ;;
        fedora)
            dnf install -y $packages >/dev/null 2>&1 || error_exit "Failed to install $packages"
            ;;
        *)
            error_exit "Unsupported OS: $OS"
            ;;
    esac
    ok "$packages installed"
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
    
    # Install WireGuard
    case $OS in
        ubuntu|debian)
            install_package "wireguard-tools"
            install_package "curl"
            install_package "wget"
            ;;
        centos|rhel|rocky|almalinux)
            # Enable EPEL for WireGuard
            if ! rpm -q epel-release >/dev/null 2>&1; then
                install_package "epel-release"
            fi
            install_package "wireguard-tools"
            install_package "curl"
            install_package "wget"
            ;;
        fedora)
            install_package "wireguard-tools"
            install_package "curl"
            install_package "wget"
            ;;
    esac
    
    setup_temporary_dns
    
    # Download and install wgcf
    info "Downloading wgcf..."
    WGCF_RELEASE_URL="https://api.github.com/repos/ViRb3/wgcf/releases/latest"
    WGCF_VERSION=$(curl -s "$WGCF_RELEASE_URL" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    
    if [ -z "$WGCF_VERSION" ]; then
        error_exit "Failed to get latest wgcf version"
    fi
    
    WGCF_DOWNLOAD_URL="https://github.com/ViRb3/wgcf/releases/download/${WGCF_VERSION}/wgcf_${WGCF_VERSION#v}_linux_${ARCH}"
    WGCF_BINARY="wgcf_${WGCF_VERSION#v}_linux_${ARCH}"
    
    if ! wget -q "$WGCF_DOWNLOAD_URL" -O "$WGCF_BINARY"; then
        error_exit "Failed to download wgcf"
    fi
    
    chmod +x "$WGCF_BINARY"
    mv "$WGCF_BINARY" /usr/local/bin/wgcf
    ok "wgcf $WGCF_VERSION installed"
    
    # Create temp directory with cleanup
    local WGCF_TEMP_DIR
    WGCF_TEMP_DIR=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$WGCF_TEMP_DIR'" EXIT
    
    # Register and generate config
    info "Registering with Cloudflare WARP..."
    cd "$WGCF_TEMP_DIR"
    if ! timeout 30 bash -c 'yes | wgcf register' >/dev/null 2>&1; then
        error_exit "Failed to register with WARP"
    fi
    
    if ! wgcf generate >/dev/null 2>&1; then
        error_exit "Failed to generate WARP configuration"
    fi
    
    # Configure WARP
    info "Configuring WARP..."
    WGCF_CONF_FILE="wgcf-profile.conf"
    
    if [ ! -f "$WGCF_CONF_FILE" ]; then
        error_exit "WARP configuration file not found"
    fi
    
    # Remove DNS and add custom settings
    sed -i '/^DNS =/d' "$WGCF_CONF_FILE"
    if ! grep -q "Table = off" "$WGCF_CONF_FILE"; then
        sed -i '/^MTU =/a Table = off' "$WGCF_CONF_FILE"
    fi
    if ! grep -q "PersistentKeepalive = 25" "$WGCF_CONF_FILE"; then
        sed -i '/^Endpoint =/a PersistentKeepalive = 25' "$WGCF_CONF_FILE"
    fi
    
    # Handle IPv6
    if ! check_ipv6_support; then
        warn "IPv6 disabled - removing IPv6 addresses from config"
        sed -i 's/,\s*[0-9a-fA-F:]\+\/128//' "$WGCF_CONF_FILE"
        sed -i '/Address = [0-9a-fA-F:]\+\/128/d' "$WGCF_CONF_FILE"
    fi
    
    # Install configuration
    mkdir -p /etc/wireguard
    mv "$WGCF_CONF_FILE" "$WARP_CONFIG_FILE"
    chmod 600 "$WARP_CONFIG_FILE"
    ok "WARP configuration installed"
    
    # Enable and start service
    systemctl enable "$WARP_SERVICE" >/dev/null 2>&1
    systemctl start "$WARP_SERVICE" >/dev/null 2>&1
    
    restore_dns
    
    # Verify connection
    sleep 3
    if verify_warp_connection; then
        ok "WARP installation completed successfully"
    else
        warn "WARP installed but connection verification failed"
    fi
}

check_ipv6_support() {
    sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q ' = 0' && \
    sysctl net.ipv6.conf.default.disable_ipv6 2>/dev/null | grep -q ' = 0' && \
    ip -6 addr show scope global | grep -qv 'inet6 .*fe80::'
}

verify_warp_connection() {
    local check_result
    check_result=$(curl -s --max-time 10 --interface warp https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep "warp=")
    echo "$check_result" | grep -q "warp=on"
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
    
    # Remove configuration
    if [ -f "$WARP_CONFIG_FILE" ]; then
        rm -f "$WARP_CONFIG_FILE"
    fi
    
    # Remove wgcf binary
    if [ -f /usr/local/bin/wgcf ]; then
        rm -f /usr/local/bin/wgcf
    fi
    
    # Clean up registration files
    rm -f /tmp/wgcf-account.toml /tmp/wgcf-profile.conf
    
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
    
    install_package "tor"
    
    # Configure Tor
    info "Configuring Tor..."
    
    # Backup original config
    if [ -f "$TOR_CONFIG_FILE" ] && [ ! -f "$TOR_CONFIG_FILE.backup" ]; then
        cp "$TOR_CONFIG_FILE" "$TOR_CONFIG_FILE.backup"
    fi
    
    # Generate random control password
    local TOR_CONTROL_PASSWORD
    local TOR_HASHED_PASSWORD
    TOR_CONTROL_PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)
    # Try to generate hashed password, fallback to cookie auth only if tor not available yet
    if command -v tor >/dev/null 2>&1; then
        TOR_HASHED_PASSWORD=$(tor --hash-password "$TOR_CONTROL_PASSWORD" 2>/dev/null || echo "")
    fi
    
    # Save password for reference (secure permissions set below)
    echo "$TOR_CONTROL_PASSWORD" > /etc/tor/.control_password
    chmod 600 /etc/tor/.control_password
    chown debian-tor:debian-tor /etc/tor/.control_password 2>/dev/null || chown tor:tor /etc/tor/.control_password 2>/dev/null || true
    
    # Create basic Tor configuration
    cat > "$TOR_CONFIG_FILE" <<EOF
# Tor configuration for proxy mode
# Control password saved in /etc/tor/.control_password
SocksPort 9050
ControlPort 9051
${TOR_HASHED_PASSWORD:+HashedControlPassword $TOR_HASHED_PASSWORD}
CookieAuthentication 1
DataDirectory /var/lib/tor
Log notice file /var/log/tor/tor.log

# Performance optimizations
ConnLimit 1000
MaxClientCircuitsPending 48
KeepalivePeriod 60
NewCircuitPeriod 30
MaxCircuitDirtiness 600

# Exit policy - only allow outgoing connections
ExitPolicy reject *:*
EOF
    
    # Set permissions
    chown debian-tor:debian-tor "$TOR_CONFIG_FILE" 2>/dev/null || chown tor:tor "$TOR_CONFIG_FILE" 2>/dev/null
    chmod 644 "$TOR_CONFIG_FILE"
    
    # Create log directory
    mkdir -p /var/log/tor
    chown debian-tor:debian-tor /var/log/tor 2>/dev/null || chown tor:tor /var/log/tor 2>/dev/null
    
    # Enable and start Tor
    systemctl enable "$TOR_SERVICE" >/dev/null 2>&1
    systemctl restart "$TOR_SERVICE" >/dev/null 2>&1
    
    # Wait for Tor to start
    sleep 5
    
    if verify_tor_connection; then
        ok "Tor installation completed successfully"
    else
        warn "Tor installed but connection verification failed"
    fi
}

verify_tor_connection() {
    # Check if Tor is listening on port 9050
    netstat -tlnp 2>/dev/null | grep -q ":9050" || ss -tlnp 2>/dev/null | grep -q ":9050"
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
    
    case $action in
        start)
            systemctl start "$service_name" >/dev/null 2>&1
            ok "$service_type service started"
            ;;
        stop)
            systemctl stop "$service_name" >/dev/null 2>&1
            ok "$service_type service stopped"
            ;;
        restart)
            systemctl restart "$service_name" >/dev/null 2>&1
            ok "$service_type service restarted"
            ;;
    esac
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
show_main_menu() {
    clear
    echo -e "\033[1;37m🌐 WARP & Tor Manager\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    # Статус сервисов
    local warp_status=$(check_warp_status)
    local tor_status=$(check_tor_status)
    local status_color_warp="\033[38;5;244m"
    local status_color_tor="\033[38;5;244m"
    
    # Определяем цвета статуса
    case $warp_status in
        "running") status_color_warp="\033[1;32m" ;;
        "installed") status_color_warp="\033[1;33m" ;;
        "not_installed") status_color_warp="\033[38;5;244m" ;;
    esac
    
    case $tor_status in
        "running") status_color_tor="\033[1;32m" ;;
        "installed") status_color_tor="\033[1;33m" ;;
        "not_installed") status_color_tor="\033[38;5;244m" ;;
    esac
    
    # Статус WARP
    echo -e "\033[1;37m📡 WARP Status:\033[0m"
    case $warp_status in
        "running")
            echo -e "${status_color_warp}✅ RUNNING\033[0m"
            local warp_memory=$(get_service_memory "$WARP_SERVICE")
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Memory:" "$warp_memory"
            
            # Проверяем WireGuard интерфейс
            if wg show warp >/dev/null 2>&1; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Active interface\033[0m\n" "WireGuard:"
                # Показываем endpoint если доступен
                local endpoint=$(wg show warp | grep "endpoint:" | awk '{print $2}' 2>/dev/null || echo "N/A")
                if [ "$endpoint" != "N/A" ]; then
                    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Endpoint:" "$endpoint"
                fi
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not found\033[0m\n" "WireGuard:"
            fi
            ;;
        "installed")
            echo -e "${status_color_warp}⚠️  INSTALLED BUT STOPPED\033[0m"
            echo -e "\033[38;5;244m   Use WARP menu to start service\033[0m"
            ;;
        "not_installed")
            echo -e "${status_color_warp}📦 NOT INSTALLED\033[0m"
            echo -e "\033[38;5;244m   Use WARP menu to install\033[0m"
            ;;
    esac
    
    echo
    
    # Статус Tor
    echo -e "\033[1;37m🧅 Tor Status:\033[0m"
    case $tor_status in
        "running")
            echo -e "${status_color_tor}✅ RUNNING\033[0m"
            local tor_memory=$(get_service_memory "$TOR_SERVICE")
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Memory:" "$tor_memory"
            
            # Проверяем SOCKS5 порт
            if check_port_listening 9050; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ 127.0.0.1:9050\033[0m\n" "SOCKS5:"
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not accessible\033[0m\n" "SOCKS5:"
            fi
            
            # Контрольный порт
            if check_port_listening 9051; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ 127.0.0.1:9051\033[0m\n" "Control:"
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not accessible\033[0m\n" "Control:"
            fi
            ;;
        "installed")
            echo -e "${status_color_tor}⚠️  INSTALLED BUT STOPPED\033[0m"
            echo -e "\033[38;5;244m   Use Tor menu to start service\033[0m"
            ;;
        "not_installed")
            echo -e "${status_color_tor}📦 NOT INSTALLED\033[0m"
            echo -e "\033[38;5;244m   Use Tor menu to install\033[0m"
            ;;
    esac
    
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
    local status_color="\033[38;5;244m"
    
    case $warp_status in
        "running") status_color="\033[1;32m" ;;
        "installed") status_color="\033[1;33m" ;;
        "not_installed") status_color="\033[38;5;244m" ;;
    esac
    
    echo -e "\033[1;37m📡 WARP Status:\033[0m"
    case $warp_status in
        "running")
            echo -e "${status_color}✅ RUNNING\033[0m"
            local warp_memory=$(get_service_memory "$WARP_SERVICE")
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Memory:" "$warp_memory"
            
            # Проверяем интерфейс
            if wg show warp >/dev/null 2>&1; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Active\033[0m\n" "Interface:"
                # Показываем информацию об интерфейсе
                local endpoint=$(wg show warp | grep "endpoint:" | awk '{print $2}' 2>/dev/null || echo "N/A")
                if [ "$endpoint" != "N/A" ]; then
                    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Endpoint:" "$endpoint"
                fi
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not found\033[0m\n" "Interface:"
            fi
            ;;
        "installed")
            echo -e "${status_color}⚠️  INSTALLED BUT STOPPED\033[0m"
            echo -e "\033[38;5;244m   Service is installed but not running\033[0m"
            ;;
        "not_installed")
            echo -e "${status_color}📦 NOT INSTALLED\033[0m"
            echo -e "\033[38;5;244m   Cloudflare WARP is not installed\033[0m"
            ;;
    esac
    
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
    local status_color="\033[38;5;244m"
    
    case $tor_status in
        "running") status_color="\033[1;32m" ;;
        "installed") status_color="\033[1;33m" ;;
        "not_installed") status_color="\033[38;5;244m" ;;
    esac
    
    echo -e "\033[1;37m🧅 Tor Status:\033[0m"
    case $tor_status in
        "running")
            echo -e "${status_color}✅ RUNNING\033[0m"
            local tor_memory=$(get_service_memory "$TOR_SERVICE")
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Memory:" "$tor_memory"
            
            # Проверяем порты
            if check_port_listening 9050; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ 127.0.0.1:9050\033[0m\n" "SOCKS5:"
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not accessible\033[0m\n" "SOCKS5:"
            fi
            
            # Контрольный порт
            if check_port_listening 9051; then
                printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ 127.0.0.1:9051\033[0m\n" "Control:"
            else
                printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not accessible\033[0m\n" "Control:"
            fi
            ;;
        "installed")
            echo -e "${status_color}⚠️  INSTALLED BUT STOPPED\033[0m"
            echo -e "\033[38;5;244m   Use Tor menu to start service\033[0m"
            ;;
        "not_installed")
            echo -e "${status_color}📦 NOT INSTALLED\033[0m"
            echo -e "\033[38;5;244m   Tor anonymity network is not installed\033[0m"
            ;;
    esac
    
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
    
    printf "${BOLD}${CYAN}XRay config with WARP + Tor routing:${NC}\n\n"
    
    printf "${GREEN}{\n"
    printf "  \"outbounds\": [\n"
    printf "    {\n"
    printf "      \"tag\": \"direct\",\n"
    printf "      \"protocol\": \"freedom\"\n"
    printf "    },\n"
    printf "    {\n"
    printf "      \"tag\": \"warp\",\n"
    printf "      \"protocol\": \"freedom\",\n"
    printf "      \"settings\": {},\n"
    printf "      \"streamSettings\": {\n"
    printf "        \"sockopt\": {\n"
    printf "          \"interface\": \"warp\"\n"
    printf "        }\n"
    printf "      }\n"
    printf "    },\n"
    printf "       {\n"
    printf "      \"tag\": \"tor\",\n"
    printf "      \"protocol\": \"socks\",\n"
    printf "      \"settings\": {\n"
    printf "        \"servers\": [\n"
    printf "          {\n"
    printf "            \"address\": \"127.0.0.1\",\n"
    printf "            \"port\": 9050\n"
    printf "          }\n"
    printf "        ]\n"
    printf "      }\n"
    printf "    }\n"
    printf "  ],\n"
    printf "  \"routing\": {\n"
    printf "    \"domainStrategy\": \"IPIfNonMatch\",\n"
    printf "    \"rules\": [\n"
    printf "      {\n"
    printf "        \"type\": \"field\",\n"
    printf "        \"inboundTag\": [\n"
    printf "          \"VTR-USA\",\n"
    printf "          \"VTR-LT\",\n"
    printf "          \"VTR-NL\",\n"
    printf "          \"VTR-GB\",\n"
    printf "          \"VTR-SWED\",\n"
    printf "          \"to-foreign-inbound\"\n"
    printf "        ],\n"
    printf "        \"outboundTag\": \"tor\",\n"
    printf "        \"domain\": [\n"
    printf "          \"regexp:.*\\\\.onion$\",\n"
    printf "          \"domain:duckduckgogg42ts25.onion\",\n"
    printf "          \"domain:facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion\"\n"
    printf "        ]\n"
    printf "      },\n"
    printf "      {\n"
    printf "        \"type\": \"field\",\n"
    printf "        \"inboundTag\": [\n"
    printf "          \"VTR-USA\",\n"
    printf "          \"VTR-LT\",\n"
    printf "          \"VTR-NL\",\n"
    printf "          \"to-foreign-inbound\"\n"
    printf "        ],\n"
    printf "        \"outboundTag\": \"warp\",\n"
    printf "        \"domain\": [\n"
    printf "          \"geosite:category-ads-all\",\n"
    printf "          \"geosite:google\",\n"
    printf "          \"geosite:cloudflare\",\n"
    printf "          \"geosite:youtube\",\n"
    printf "          \"geosite:netflix\"\n"
    printf "        ]\n"
    printf "      },\n"
    printf "      {\n"
    printf "        \"type\": \"field\",\n"
    printf "        \"inboundTag\": [\n"
    printf "          \"VTR-RU\",\n"
    printf "          \"VTR-LOCAL\",\n"
    printf "          \"local-inbound\"\n"
    printf "        ],\n"
    printf "        \"outboundTag\": \"direct\",\n"
    printf "        \"domain\": [\n"
    printf "          \"geosite:private\",\n"
    printf "          \"geosite:cn\",\n"
    printf "          \"geosite:ru\"\n"
    printf "        ]\n"
    printf "      }\n"
    printf "    ]\n"
    printf "  }\n"
    printf "}${NC}\n\n"
    
    printf "${BOLD}${CYAN}Key routing rules:${NC}\n"
    printf "${YELLOW}• Foreign inbounds + .onion domains → Tor SOCKS5 proxy${NC}\n"
    printf "${YELLOW}• Foreign inbounds + Ads/Streaming → WARP interface${NC}\n"
    printf "${YELLOW}• Local inbounds + Private/RU/CN → Direct connection${NC}\n"
    printf "${YELLOW}• API inbound → API outbound${NC}\n\n"
    
    printf "${BOLD}${CYAN}Example server inbound tags:${NC}\n"
    printf "${GREEN}• VTR-USA, VTR-LT, VTR-NL, VTR-GB, VTR-SWED ${DIM}(foreign servers)${NC}\n"
    printf "${GREEN}• VTR-RU, VTR-LOCAL ${DIM}(local/domestic servers)${NC}\n"
    printf "${GREEN}• to-foreign-inbound, local-inbound ${DIM}(general purpose)${NC}\n"
    printf "${GREEN}• api ${DIM}(API management)${NC}\n\n"
    
    printf "${BOLD}${CYAN}Alternative config (Tor for .onion, specific inbounds):${NC}\n\n"
    
    printf "${GREEN}{\n"
    printf "  \"outbounds\": [\n"
    printf "    {\"tag\": \"direct\", \"protocol\": \"freedom\"},\n"
    printf "    {\n"
    printf "      \"tag\": \"tor\",\n"
    printf "      \"protocol\": \"socks\",\n"
    printf "      \"settings\": {\n"
    printf "        \"servers\": [{\"address\": \"127.0.0.1\", \"port\": 9050}]\n"
    printf "      }\n"
    printf "    }\n"
    printf "  ],\n"
    printf "  \"routing\": {\n"
    printf "    \"rules\": [\n"
    printf "      {\n"
    printf "        \"type\": \"field\",\n"
    printf "        \"inboundTag\": [\n"
    printf "          \"VTR-USA\",\n"
    printf "          \"VTR-EU\",\n"
    printf "          \"to-foreign-inbound\"\n"
    printf "        ],\n"
    printf "        \"outboundTag\": \"tor\",\n"
    printf "        \"domain\": [\"regexp:.*\\\\.onion$\"]\n"
    printf "      }\n"
    printf "    ]\n"
    printf "  }\n"
    printf "}${NC}\n\n"
    
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
        
        if curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/wtm 2>/dev/null; then
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
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/wtm
    ok "WTM script installed successfully at /usr/local/bin/wtm"
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
                                nano "$TOR_CONFIG_FILE"
                            else
                                echo "Tor config file not found"
                                read -p "Press Enter to continue..."
                            fi
                            ;;
                        10)
                            if systemctl is-active --quiet "$TOR_SERVICE" 2>/dev/null; then
                                systemctl reload "$TOR_SERVICE"
                                echo "Tor identity regenerated"
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