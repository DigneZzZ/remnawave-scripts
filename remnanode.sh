#!/usr/bin/env bash
# Version: 3.7.3
set -e
SCRIPT_VERSION="3.7.3"

# Handle @ prefix for consistency with other scripts
if [ $# -gt 0 ] && [ "$1" = "@" ]; then
    shift  
fi

# Parse command line arguments
COMMAND=""
if [ $# -gt 0 ]; then
    COMMAND="$1"
    shift
fi

SCRIPT_URL="https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/remnanode.sh"

while [[ $# -gt 0 ]]; do
    key="$1"
    
    case $key in
        --name)
            if [[ "$COMMAND" == "install" || "$COMMAND" == "install-script" ]]; then
                APP_NAME="$2"
                shift # past argument
            else
                echo "Error: --name parameter is only allowed with 'install' or 'install-script' commands."
                exit 1
            fi
            shift # past value
        ;;
        --dev)
            if [[ "$COMMAND" == "install" ]]; then
                USE_DEV_BRANCH="true"
            else
                echo "Error: --dev parameter is only allowed with 'install' command."
                exit 1
            fi
            shift # past argument
        ;;
        --source)
            if [[ "$COMMAND" == "install-script" ]]; then
                if [[ -n "$2" && "$2" =~ remnanode\.sh$ ]]; then
                    SCRIPT_URL="$2"
                    shift 2
                else
                    echo "Error: --source parameter must be a URL to a remnanode.sh file."
                    exit 1
                fi
            else
                echo "Error: --source parameter is only allowed with 'install-script' command."
                exit 1
            fi
        ;;
        --help|-h)
            show_command_help "$COMMAND"
            exit 0
        ;;
        *)
            echo "Unknown argument: $key"
            exit 1
        ;;
    esac
done

# Fetch IP address from ipinfo.io API
NODE_IP=$(curl -s -4 ifconfig.io)

# If the IPv4 retrieval is empty, attempt to retrieve the IPv6 address
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(curl -s -6 ifconfig.io)
fi

if [[ "$COMMAND" == "install" || "$COMMAND" == "install-script" ]] && [ -z "$APP_NAME" ]; then
    APP_NAME="remnanode"
fi
# Set script name if APP_NAME is not set
if [ -z "$APP_NAME" ]; then
    SCRIPT_NAME=$(basename "$0")
    APP_NAME="${SCRIPT_NAME%.*}"
fi

INSTALL_DIR="/opt"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"
XRAY_FILE="$DATA_DIR/xray"
GEOIP_FILE="$DATA_DIR/geoip.dat"
GEOSITE_FILE="$DATA_DIR/geosite.dat"

# Default internal ports
DEFAULT_XTLS_API_PORT=61000
DEFAULT_INTERNAL_REST_PORT=61001
DEFAULT_SUPERVISORD_PORT=61002

# Port groups for multi-instance deployments (XTLS_API, INTERNAL_REST, SUPERVISORD)
# Each group is separated by 10 to allow easy identification
PORT_GROUP_0="61000,61001,61002"
PORT_GROUP_1="61010,61011,61012"
PORT_GROUP_2="61020,61021,61022"
PORT_GROUP_3="61030,61031,61032"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

colorized_echo() {
    local color=$1
    local text=$2
    local style=${3:-0}  # Default style is normal

    case $color in
        "red") printf "\e[${style};91m${text}\e[0m\n" ;;
        "green") printf "\e[${style};92m${text}\e[0m\n" ;;
        "yellow") printf "\e[${style};93m${text}\e[0m\n" ;;
        "blue") printf "\e[${style};94m${text}\e[0m\n" ;;
        "magenta") printf "\e[${style};95m${text}\e[0m\n" ;;
        "cyan") printf "\e[${style};96m${text}\e[0m\n" ;;
        *) echo "${text}" ;;
    esac
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This command must be run as root."
        exit 1
    fi
}


check_system_requirements() {
    local errors=0
    
    # Проверяем свободное место (минимум 1GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1048576 ]; then  # 1GB в KB
        colorized_echo red "Error: Insufficient disk space. At least 1GB required."
        errors=$((errors + 1))
    fi
    
    # Проверяем RAM (минимум 512MB)
    local available_ram=$(free -m | awk 'NR==2{print $7}')
    if [ "$available_ram" -lt 256 ]; then
        colorized_echo yellow "Warning: Low available RAM (${available_ram}MB). Performance may be affected."
    fi
    
    # Проверяем архитектуру
    if ! identify_the_operating_system_and_architecture 2>/dev/null; then
        colorized_echo red "Error: Unsupported system architecture."
        errors=$((errors + 1))
    fi
    
    return $errors
}

detect_os() {
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
    elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
        if [[ "$OS" == "Amazon Linux" ]]; then
            OS="Amazon"
        fi
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
    elif [ -f /etc/arch-release ]; then
        OS="Arch"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

detect_and_update_package_manager() {
    colorized_echo blue "Updating package manager"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update -qq >/dev/null 2>&1
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]] || [[ "$OS" == "Amazon"* ]]; then
        PKG_MANAGER="yum"
        $PKG_MANAGER update -y -q >/dev/null 2>&1
        if [[ "$OS" != "Amazon" ]]; then
            $PKG_MANAGER install -y -q epel-release >/dev/null 2>&1
        fi
    elif [[ "$OS" == "Fedora"* ]]; then
        PKG_MANAGER="dnf"
        $PKG_MANAGER update -q -y >/dev/null 2>&1
    elif [[ "$OS" == "Arch"* ]]; then
        PKG_MANAGER="pacman"
        $PKG_MANAGER -Sy --noconfirm --quiet >/dev/null 2>&1
    elif [[ "$OS" == "openSUSE"* ]]; then
        PKG_MANAGER="zypper"
        $PKG_MANAGER refresh --quiet >/dev/null 2>&1
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

detect_compose() {
    if docker compose >/dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        if [[ "$OS" == "Amazon"* ]]; then
            colorized_echo blue "Docker Compose plugin not found. Attempting manual installation..."
            mkdir -p /usr/libexec/docker/cli-plugins
            curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose >/dev/null 2>&1
            chmod +x /usr/libexec/docker/cli-plugins/docker-compose
            if docker compose >/dev/null 2>&1; then
                COMPOSE='docker compose'
                colorized_echo green "Docker Compose plugin installed successfully"
            else
                colorized_echo red "Failed to install Docker Compose plugin. Please check your setup."
                exit 1
            fi
        else
            colorized_echo red "docker compose not found"
            exit 1
        fi
    fi
}

install_package() {
    if [ -z "$PKG_MANAGER" ]; then
        detect_and_update_package_manager
    fi

    PACKAGE=$1
    colorized_echo blue "Installing $PACKAGE"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        $PKG_MANAGER -y -qq install "$PACKAGE" >/dev/null 2>&1
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]] || [[ "$OS" == "Amazon"* ]]; then
        $PKG_MANAGER install -y -q "$PACKAGE" >/dev/null 2>&1
    elif [[ "$OS" == "Fedora"* ]]; then
        $PKG_MANAGER install -y -q "$PACKAGE" >/dev/null 2>&1
    elif [[ "$OS" == "Arch"* ]]; then
        $PKG_MANAGER -S --noconfirm --quiet "$PACKAGE" >/dev/null 2>&1
    elif [[ "$OS" == "openSUSE"* ]]; then
        $PKG_MANAGER --quiet install -y "$PACKAGE" >/dev/null 2>&1
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_docker() {
    colorized_echo blue "Installing Docker"
    if [[ "$OS" == "Amazon"* ]]; then
        amazon-linux-extras enable docker >/dev/null 2>&1
        yum install -y docker >/dev/null 2>&1
        systemctl start docker
        systemctl enable docker
        colorized_echo green "Docker installed successfully on Amazon Linux"
    else
        curl -fsSL https://get.docker.com | sh
        colorized_echo green "Docker installed successfully"
    fi
}

install_remnanode_script() {
    colorized_echo blue "Installing remnanode script v$SCRIPT_VERSION"
    TARGET_PATH="/usr/local/bin/$APP_NAME"

    curl -sSL $SCRIPT_URL -o $TARGET_PATH
    colorized_echo blue "Fetched remnawave script from $SCRIPT_URL"

    chmod 755 $TARGET_PATH

    # Получаем версию установленного скрипта
    local installed_version=$(grep "^SCRIPT_VERSION=" "$TARGET_PATH" 2>/dev/null | head -1 | cut -d'"' -f2)
    if [ -n "$installed_version" ]; then
        colorized_echo green "Remnanode script v$installed_version installed successfully at $TARGET_PATH"
    else
        colorized_echo green "Remnanode script installed successfully at $TARGET_PATH"
    fi
}

# Улучшенная функция проверки доступности портов
validate_port() {
    local port="$1"
    
    # Проверяем диапазон портов
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    
    # Проверяем, что порт не зарезервирован системой
    if [ "$port" -lt 1024 ] && [ "$(id -u)" != "0" ]; then
        colorized_echo yellow "Warning: Port $port requires root privileges"
    fi
    
    return 0
}

# Улучшенная функция получения занятых портов с fallback
get_occupied_ports() {
    local ports=""
    
    if command -v ss &>/dev/null; then
        ports=$(ss -tuln 2>/dev/null | awk 'NR>1 {print $5}' | grep -Eo '[0-9]+$' | sort -n | uniq)
    elif command -v netstat &>/dev/null; then
        ports=$(netstat -tuln 2>/dev/null | awk 'NR>2 {print $4}' | grep -Eo '[0-9]+$' | sort -n | uniq)
    else
        colorized_echo yellow "Neither ss nor netstat found. Installing net-tools..."
        detect_os
        if install_package net-tools; then
            if command -v netstat &>/dev/null; then
                ports=$(netstat -tuln 2>/dev/null | awk 'NR>2 {print $4}' | grep -Eo '[0-9]+$' | sort -n | uniq)
            fi
        else
            colorized_echo yellow "Could not install net-tools. Skipping port conflict check."
            return 1
        fi
    fi
    
    OCCUPIED_PORTS="$ports"
    return 0
}
is_port_occupied() {
    if echo "$OCCUPIED_PORTS" | grep -q -w "$1"; then
        return 0
    else
        return 1
    fi
}

# Check if a port group is available (all 3 ports must be free)
is_port_group_available() {
    local group_ports="$1"
    IFS=',' read -r xtls_port rest_port supervisord_port <<< "$group_ports"
    
    for port in $xtls_port $rest_port $supervisord_port; do
        if is_port_occupied "$port"; then
            return 1
        fi
    done
    return 0
}

# Find first available internal port group
# Returns: group number (0-3) or empty if none available
find_available_port_group() {
    # Ensure we have current port information
    if [ -z "$OCCUPIED_PORTS" ]; then
        get_occupied_ports
    fi
    
    local groups=("$PORT_GROUP_0" "$PORT_GROUP_1" "$PORT_GROUP_2" "$PORT_GROUP_3")
    
    for i in "${!groups[@]}"; do
        if is_port_group_available "${groups[$i]}"; then
            echo "$i"
            return 0
        fi
    done
    
    # No free group found
    return 1
}

# Get port group by index
get_port_group() {
    local index="$1"
    case "$index" in
        0) echo "$PORT_GROUP_0" ;;
        1) echo "$PORT_GROUP_1" ;;
        2) echo "$PORT_GROUP_2" ;;
        3) echo "$PORT_GROUP_3" ;;
        *) echo "$PORT_GROUP_0" ;;
    esac
}

# Parse port group string into individual ports
parse_port_group() {
    local group_ports="$1"
    IFS=',' read -r XTLS_API_PORT INTERNAL_REST_PORT SUPERVISORD_PORT <<< "$group_ports"
}

install_latest_xray_core() {
    identify_the_operating_system_and_architecture
    mkdir -p "$DATA_DIR"
    cd "$DATA_DIR"
    
    latest_release=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep -oP '"tag_name": "\K(.*?)(?=")')
    if [ -z "$latest_release" ]; then
        colorized_echo red "Failed to fetch latest Xray-core version."
        exit 1
    fi
    
    if ! dpkg -s unzip >/dev/null 2>&1; then
        colorized_echo blue "Installing unzip..."
        detect_os
        install_package unzip
    fi
    
    xray_filename="Xray-linux-$ARCH.zip"
    xray_download_url="https://github.com/XTLS/Xray-core/releases/download/${latest_release}/${xray_filename}"
    
    colorized_echo blue "Downloading Xray-core version ${latest_release}..."
    wget "${xray_download_url}" -q
    if [ $? -ne 0 ]; then
        colorized_echo red "Error: Failed to download Xray-core."
        exit 1
    fi
    
    colorized_echo blue "Extracting Xray-core..."
    unzip -o "${xray_filename}" -d "$DATA_DIR" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        colorized_echo red "Error: Failed to extract Xray-core."
        exit 1
    fi

    rm "${xray_filename}"
    chmod +x "$XRAY_FILE"
    
    # Check what files were extracted
    colorized_echo blue "Extracted files:"
    if [ -f "$XRAY_FILE" ]; then
        colorized_echo green "  ✅ xray executable"
    fi
    if [ -f "$GEOIP_FILE" ]; then
        colorized_echo green "  ✅ geoip.dat"
    fi
    if [ -f "$GEOSITE_FILE" ]; then
        colorized_echo green "  ✅ geosite.dat"
    fi
    
    colorized_echo green "Latest Xray-core (${latest_release}) installed at $XRAY_FILE"
}

setup_log_rotation() {
    check_running_as_root
    
    # Check if the directory exists
    if [ ! -d "$DATA_DIR" ]; then
        colorized_echo blue "Creating directory $DATA_DIR"
        mkdir -p "$DATA_DIR"
    else
        colorized_echo green "Directory $DATA_DIR already exists"
    fi
    
    # Check if logrotate is installed
    if ! command -v logrotate &> /dev/null; then
        colorized_echo blue "Installing logrotate"
        detect_os
        install_package logrotate
    else
        colorized_echo green "Logrotate is already installed"
    fi
    
    # Check if logrotate config already exists
    LOGROTATE_CONFIG="/etc/logrotate.d/remnanode"
    if [ -f "$LOGROTATE_CONFIG" ]; then
        colorized_echo yellow "Logrotate configuration already exists at $LOGROTATE_CONFIG"
        read -p "Do you want to overwrite it? (y/n): " -r overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            colorized_echo yellow "Keeping existing logrotate configuration"
            return
        fi
    fi
    
    # Create logrotate configuration
    colorized_echo blue "Creating logrotate configuration at $LOGROTATE_CONFIG"
    cat > "$LOGROTATE_CONFIG" <<EOL
$DATA_DIR/*.log {
    size 50M
    rotate 5
    compress
    missingok
    notifempty
    copytruncate
}
EOL

    chmod 644 "$LOGROTATE_CONFIG"
    
    # Test logrotate configuration
    colorized_echo blue "Testing logrotate configuration"
    if logrotate -d "$LOGROTATE_CONFIG" &> /dev/null; then
        colorized_echo green "Logrotate configuration test successful"
        
        # Ask if user wants to run logrotate now
        read -p "Do you want to run logrotate now? (y/n): " -r run_now
        if [[ $run_now =~ ^[Yy]$ ]]; then
            colorized_echo blue "Running logrotate"
            if logrotate -vf "$LOGROTATE_CONFIG"; then
                colorized_echo green "Logrotate executed successfully"
            else
                colorized_echo red "Error running logrotate"
            fi
        fi
    else
        colorized_echo red "Logrotate configuration test failed"
        logrotate -d "$LOGROTATE_CONFIG"
    fi
    
    # Update docker-compose.yml to mount logs directory
    if [ -f "$COMPOSE_FILE" ]; then
        colorized_echo blue "Updating docker-compose.yml to mount logs directory"
        

        colorized_echo blue "Creating backup of docker-compose.yml..."
        backup_file=$(create_backup "$COMPOSE_FILE")
        if [ $? -eq 0 ]; then
            colorized_echo green "Backup created: $backup_file"
        else
            colorized_echo red "Failed to create backup"
            return
        fi
        

        local service_indent=$(get_service_property_indentation "$COMPOSE_FILE")
        local indent_type=""
        if [[ "$service_indent" =~ $'\t' ]]; then
            indent_type=$'\t'
        else
            indent_type="  "
        fi
        local volume_item_indent="${service_indent}${indent_type}"
        

        local escaped_service_indent=$(escape_for_sed "$service_indent")
        local escaped_volume_item_indent=$(escape_for_sed "$volume_item_indent")
        

        if grep -q "^${escaped_service_indent}volumes:" "$COMPOSE_FILE"; then
            if ! grep -q "$DATA_DIR:$DATA_DIR" "$COMPOSE_FILE"; then
                sed -i "/^${escaped_service_indent}volumes:/a\\${volume_item_indent}- $DATA_DIR:$DATA_DIR" "$COMPOSE_FILE"
                colorized_echo green "Added logs volume to existing volumes section"
            else
                colorized_echo yellow "Logs volume already exists in volumes section"
            fi
        elif grep -q "^${escaped_service_indent}# volumes:" "$COMPOSE_FILE"; then
            sed -i "s|^${escaped_service_indent}# volumes:|${service_indent}volumes:|g" "$COMPOSE_FILE"
            
            if grep -q "^${escaped_volume_item_indent}#.*$DATA_DIR:$DATA_DIR" "$COMPOSE_FILE"; then
                sed -i "s|^${escaped_volume_item_indent}#.*$DATA_DIR:$DATA_DIR|${volume_item_indent}- $DATA_DIR:$DATA_DIR|g" "$COMPOSE_FILE"
                colorized_echo green "Uncommented volumes section and logs volume line"
            else
                sed -i "/^${escaped_service_indent}volumes:/a\\${volume_item_indent}- $DATA_DIR:$DATA_DIR" "$COMPOSE_FILE"
                colorized_echo green "Uncommented volumes section and added logs volume line"
            fi
        else
            sed -i "/^${escaped_service_indent}restart: always/a\\${service_indent}volumes:\\n${volume_item_indent}- $DATA_DIR:$DATA_DIR" "$COMPOSE_FILE"
            colorized_echo green "Added new volumes section with logs volume"
        fi
        

        colorized_echo blue "Validating docker-compose.yml..."
        if validate_compose_file "$COMPOSE_FILE"; then
            colorized_echo green "Docker-compose.yml validation successful"
            cleanup_old_backups "$COMPOSE_FILE"

            if is_remnanode_up; then
                read -p "Do you want to restart RemnaNode to apply changes? (y/n): " -r restart_now
                if [[ $restart_now =~ ^[Yy]$ ]]; then
                    colorized_echo blue "Restarting RemnaNode"
                    if $APP_NAME restart -n; then
                        colorized_echo green "RemnaNode restarted successfully"
                    else
                        colorized_echo red "Failed to restart RemnaNode"
                    fi
                else
                    colorized_echo yellow "Remember to restart RemnaNode to apply changes"
                fi
            fi
        else
            colorized_echo red "Docker-compose.yml validation failed! Restoring backup..."
            if restore_backup "$backup_file" "$COMPOSE_FILE"; then
                colorized_echo green "Backup restored successfully"
            else
                colorized_echo red "Failed to restore backup!"
            fi
            return
        fi
    else
        colorized_echo yellow "Docker Compose file not found. Log directory will be mounted on next installation."
    fi
    
    colorized_echo green "Log rotation setup completed successfully"
}

# ============================================
# Selfsteal Socket Integration
# ============================================

# Socket path for nginx-selfsteal
SELFSTEAL_SOCKET="/dev/shm/nginx.sock"

# Check if selfsteal socket exists
check_selfsteal_socket() {
    if [ -S "$SELFSTEAL_SOCKET" ]; then
        return 0
    fi
    return 1
}

# Enable /dev/shm volume in docker-compose.yml
enable_shm_volume() {
    local compose_file="$1"
    
    if [ ! -f "$compose_file" ]; then
        return 1
    fi
    
    # Check if already uncommented
    if grep -qE "^[[:space:]]*-[[:space:]]*/dev/shm:/dev/shm" "$compose_file"; then
        colorized_echo green "✅ /dev/shm volume is already enabled"
        return 0
    fi
    
    # Check if commented and uncomment
    if grep -qE "^[[:space:]]*#.*-[[:space:]]*/dev/shm:/dev/shm" "$compose_file"; then
        colorized_echo blue "Enabling /dev/shm volume for selfsteal socket access..."
        
        # First, check if 'volumes:' is also commented and uncomment it
        if grep -qE "^[[:space:]]*#[[:space:]]*volumes:" "$compose_file"; then
            sed -i 's|^[[:space:]]*#[[:space:]]*\(volumes:\)|    \1|' "$compose_file"
        fi
        
        # Then uncomment the /dev/shm line
        sed -i 's|^[[:space:]]*#[[:space:]]*\(-[[:space:]]*/dev/shm:/dev/shm.*\)|      \1|' "$compose_file"
        
        if docker compose -f "$compose_file" config >/dev/null 2>&1; then
            colorized_echo green "✅ /dev/shm volume enabled successfully"
            return 0
        else
            colorized_echo red "Failed to validate docker-compose.yml after modification"
            return 1
        fi
    fi
    
    colorized_echo yellow "⚠️  /dev/shm volume line not found in docker-compose.yml"
    return 1
}

# Configure selfsteal socket access after installation
configure_selfsteal_integration() {
    echo
    colorized_echo cyan "🔍 Checking for Selfsteal (nginx/caddy) installation..."
    
    if check_selfsteal_socket; then
        colorized_echo green "✅ Detected selfsteal socket at $SELFSTEAL_SOCKET"
        colorized_echo blue "   Enabling socket access for remnanode container..."
        
        if enable_shm_volume "$COMPOSE_FILE"; then
            colorized_echo green "✅ Remnanode configured for selfsteal socket access"
            echo
            colorized_echo cyan "📋 Xray Reality Configuration:"
            colorized_echo white "   \"target\": \"$SELFSTEAL_SOCKET\","
            colorized_echo white "   \"xver\": 1"
        fi
    else
        colorized_echo gray "   No selfsteal socket detected"
        colorized_echo gray "   If you install selfsteal later with --nginx, run:"
        colorized_echo white "   remnanode enable-socket"
    fi
}

# Command to enable socket access manually
enable_socket_command() {
    echo
    colorized_echo cyan "🔌 Selfsteal Socket Configuration"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        colorized_echo red "❌ docker-compose.yml not found at $COMPOSE_FILE"
        colorized_echo gray "   Please install remnanode first: remnanode install"
        exit 1
    fi
    
    # Check if socket exists
    if check_selfsteal_socket; then
        colorized_echo green "✅ Selfsteal socket detected at $SELFSTEAL_SOCKET"
    else
        colorized_echo yellow "⚠️  Selfsteal socket not found at $SELFSTEAL_SOCKET"
        colorized_echo gray "   Make sure selfsteal with --nginx is installed and running"
        echo
        read -p "Continue anyway? [y/N]: " -r confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            colorized_echo gray "Cancelled"
            exit 0
        fi
    fi
    
    echo
    if enable_shm_volume "$COMPOSE_FILE"; then
        echo
        colorized_echo blue "🔄 Restarting remnanode container..."
        
        cd "$APP_DIR"
        if docker compose down && docker compose up -d; then
            colorized_echo green "✅ Remnanode restarted with socket access"
            
            # Verify
            sleep 2
            if docker exec "$APP_NAME" ls -la /dev/shm/nginx.sock >/dev/null 2>&1; then
                colorized_echo green "✅ Verified: Container can access $SELFSTEAL_SOCKET"
            else
                colorized_echo yellow "⚠️  Socket not accessible yet (selfsteal may not be running)"
            fi
        else
            colorized_echo red "❌ Failed to restart remnanode"
        fi
        
        echo
        colorized_echo cyan "📋 Xray Reality Configuration:"
        colorized_echo white "   \"target\": \"$SELFSTEAL_SOCKET\","
        colorized_echo white "   \"xver\": 1"
    else
        colorized_echo red "❌ Failed to enable socket access"
    fi
}

install_remnanode() {

    if ! check_system_requirements; then
        colorized_echo red "System requirements check failed. Installation aborted."
        exit 1
    fi

    colorized_echo blue "Creating directory $APP_DIR"
    mkdir -p "$APP_DIR"

    colorized_echo blue "Creating directory $DATA_DIR"
    mkdir -p "$DATA_DIR"

    # Prompt the user to input the SSL certificate
    colorized_echo blue "Please paste the content of the SECRET_KEY from Remnawave-Panel, press ENTER on a new line when finished: "
    SECRET_KEY_VALUE=""
    while IFS= read -r line; do
        if [[ -z $line ]]; then
            break
        fi
        SECRET_KEY_VALUE="$SECRET_KEY_VALUE$line"
    done

    get_occupied_ports
    while true; do
        read -p "Enter the NODE_PORT (default 3000): " -r NODE_PORT
        NODE_PORT=${NODE_PORT:-3000}
        
        if validate_port "$NODE_PORT"; then
            if is_port_occupied "$NODE_PORT"; then
                colorized_echo red "Port $NODE_PORT is already in use. Please enter another port."
                colorized_echo blue "Occupied ports: $(echo $OCCUPIED_PORTS | tr '\n' ' ')"
            else
                break
            fi
        else
            colorized_echo red "Invalid port. Please enter a port between 1 and 65535."
        fi
    done

    # ============================================
    # Internal Ports Configuration
    # ============================================
    echo
    colorized_echo cyan "🔧 Internal Ports Configuration"
    colorized_echo gray "   These ports are used internally by node components (Xray API, REST, Supervisord)."
    colorized_echo gray "   Default values work fine for single-node installations."
    echo
    
    # Find available port group
    local suggested_group=$(find_available_port_group)
    local suggested_group_ports=""
    
    if [ -z "$suggested_group" ]; then
        colorized_echo red "⚠️  All predefined port groups (61000-61032) are occupied!"
        colorized_echo yellow "   You'll need to enter custom ports manually."
        # Set defaults anyway, user will customize
        XTLS_API_PORT=$DEFAULT_XTLS_API_PORT
        INTERNAL_REST_PORT=$DEFAULT_INTERNAL_REST_PORT
        SUPERVISORD_PORT=$DEFAULT_SUPERVISORD_PORT
    else
        suggested_group_ports=$(get_port_group "$suggested_group")
        parse_port_group "$suggested_group_ports"
        
        if [ "$suggested_group" = "0" ]; then
            colorized_echo green "✅ Default internal ports (61000-61002) are available."
        else
            colorized_echo yellow "⚠️  Default internal ports (61000-61002) are already in use."
            colorized_echo green "✅ Suggesting alternative group $suggested_group: $XTLS_API_PORT, $INTERNAL_REST_PORT, $SUPERVISORD_PORT"
        fi
    fi
    
    echo
    read -p "Do you want to customize internal ports? [y/N]: " -r customize_ports
    if [[ $customize_ports =~ ^[Yy]$ ]]; then
        echo
        colorized_echo blue "Enter internal ports (press Enter to use suggested values):"
        
        # XTLS_API_PORT
        while true; do
            read -p "  XTLS_API_PORT (default $XTLS_API_PORT): " -r input_port
            input_port=${input_port:-$XTLS_API_PORT}
            if validate_port "$input_port"; then
                if is_port_occupied "$input_port"; then
                    colorized_echo red "  Port $input_port is already in use."
                else
                    XTLS_API_PORT=$input_port
                    break
                fi
            else
                colorized_echo red "  Invalid port. Please enter a port between 1 and 65535."
            fi
        done
        
        # INTERNAL_REST_PORT
        while true; do
            read -p "  INTERNAL_REST_PORT (default $INTERNAL_REST_PORT): " -r input_port
            input_port=${input_port:-$INTERNAL_REST_PORT}
            if validate_port "$input_port"; then
                if is_port_occupied "$input_port"; then
                    colorized_echo red "  Port $input_port is already in use."
                elif [ "$input_port" = "$XTLS_API_PORT" ]; then
                    colorized_echo red "  Port $input_port is already used for XTLS_API_PORT."
                else
                    INTERNAL_REST_PORT=$input_port
                    break
                fi
            else
                colorized_echo red "  Invalid port. Please enter a port between 1 and 65535."
            fi
        done
        
        # SUPERVISORD_PORT
        while true; do
            read -p "  SUPERVISORD_PORT (default $SUPERVISORD_PORT): " -r input_port
            input_port=${input_port:-$SUPERVISORD_PORT}
            if validate_port "$input_port"; then
                if is_port_occupied "$input_port"; then
                    colorized_echo red "  Port $input_port is already in use."
                elif [ "$input_port" = "$XTLS_API_PORT" ] || [ "$input_port" = "$INTERNAL_REST_PORT" ]; then
                    colorized_echo red "  Port $input_port is already used for another internal port."
                else
                    SUPERVISORD_PORT=$input_port
                    break
                fi
            else
                colorized_echo red "  Invalid port. Please enter a port between 1 and 65535."
            fi
        done
        
        echo
        colorized_echo green "✅ Custom internal ports configured:"
    else
        echo
        colorized_echo green "✅ Using internal ports:"
    fi
    
    colorized_echo white "   XTLS_API_PORT:      $XTLS_API_PORT"
    colorized_echo white "   INTERNAL_REST_PORT: $INTERNAL_REST_PORT"
    colorized_echo white "   SUPERVISORD_PORT:   $SUPERVISORD_PORT"
    echo

    # Ask about installing Xray-core
    read -p "Do you want to install the latest version of Xray-core? (y/n): " -r install_xray
    INSTALL_XRAY=false
    if [[ "$install_xray" =~ ^[Yy]$ ]]; then
        INSTALL_XRAY=true
        install_latest_xray_core
    fi

    colorized_echo blue "Generating .env file"
    cat > "$ENV_FILE" <<EOL
### NODE ###
NODE_PORT=$NODE_PORT

### XRAY ###
SECRET_KEY=$SECRET_KEY_VALUE

### Internal (local) ports
SUPERVISORD_PORT=$SUPERVISORD_PORT
INTERNAL_REST_PORT=$INTERNAL_REST_PORT
XTLS_API_PORT=$XTLS_API_PORT
EOL
    colorized_echo green "Environment file saved in $ENV_FILE"

    # Determine image based on --dev flag
    IMAGE_TAG="latest"
    if [ "$USE_DEV_BRANCH" == "true" ]; then
        IMAGE_TAG="dev"
    fi

    colorized_echo blue "Generating docker-compose.yml file"
    
    # Create docker-compose.yml with commented volumes section
    cat > "$COMPOSE_FILE" <<EOL
services:
  remnanode:
    container_name: $APP_NAME
    hostname: $APP_NAME
    image: ghcr.io/remnawave/node:${IMAGE_TAG}
    env_file:
      - .env
    network_mode: host
    restart: always
EOL

    # Add volumes section (commented by default)
    if [ "$INSTALL_XRAY" == "true" ]; then
        # If Xray is installed, add uncommented volumes section
        cat >> "$COMPOSE_FILE" <<EOL
    volumes:
      - $XRAY_FILE:/usr/local/bin/xray
EOL
        
        # Add geo files if they exist
        if [ -f "$GEOIP_FILE" ]; then
            echo "      - $GEOIP_FILE:/usr/local/share/xray/geoip.dat" >> "$COMPOSE_FILE"
        fi
        if [ -f "$GEOSITE_FILE" ]; then
            echo "      - $GEOSITE_FILE:/usr/local/share/xray/geosite.dat" >> "$COMPOSE_FILE"
        fi
        
        cat >> "$COMPOSE_FILE" <<EOL
      # - $DATA_DIR:$DATA_DIR
      # - /dev/shm:/dev/shm  # Uncomment for selfsteal socket access
EOL
    else
        # If Xray is not installed, add commented volumes section
        cat >> "$COMPOSE_FILE" <<EOL
    # volumes:
    #   - $XRAY_FILE:/usr/local/bin/xray
    #   - $GEOIP_FILE:/usr/local/share/xray/geoip.dat
    #   - $GEOSITE_FILE:/usr/local/share/xray/geosite.dat
    #   - $DATA_DIR:$DATA_DIR
    #   - /dev/shm:/dev/shm  # Uncomment for selfsteal socket access
EOL
    fi

    colorized_echo green "Docker Compose file saved in $COMPOSE_FILE"
}

uninstall_remnanode_script() {
    if [ -f "/usr/local/bin/$APP_NAME" ]; then
        colorized_echo yellow "Removing remnanode script"
        rm "/usr/local/bin/$APP_NAME"
    fi
}

uninstall_remnanode() {
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "Removing directory: $APP_DIR"
        rm -r "$APP_DIR"
    fi
}

uninstall_remnanode_docker_images() {
    images=$(docker images | grep remnawave/node | awk '{print $3}')
    if [ -n "$images" ]; then
        colorized_echo yellow "Removing Docker images of remnanode"
        for image in $images; do
            if docker rmi "$image" >/dev/null 2>&1; then
                colorized_echo yellow "Image $image removed"
            fi
        done
    fi
}

uninstall_remnanode_data_files() {
    if [ -d "$DATA_DIR" ]; then
        colorized_echo yellow "Removing directory: $DATA_DIR"
        rm -r "$DATA_DIR"
    fi
}

up_remnanode() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" up -d --remove-orphans
}

down_remnanode() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" down
}

show_remnanode_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs
}

follow_remnanode_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs -f
}

update_remnanode_script() {
    # Получаем текущую версию перед обновлением
    local old_version="unknown"
    if [ -f "/usr/local/bin/$APP_NAME" ]; then
        old_version=$(grep "^SCRIPT_VERSION=" "/usr/local/bin/$APP_NAME" 2>/dev/null | head -1 | cut -d'"' -f2)
        [ -z "$old_version" ] && old_version="unknown"
    fi
    
    colorized_echo blue "Updating remnanode script (current: v$old_version)"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/$APP_NAME
    
    # Получаем новую версию после обновления
    local new_version=$(grep "^SCRIPT_VERSION=" "/usr/local/bin/$APP_NAME" 2>/dev/null | head -1 | cut -d'"' -f2)
    if [ -n "$new_version" ]; then
        colorized_echo green "Remnanode script updated successfully: v$old_version → v$new_version"
    else
        colorized_echo green "Remnanode script updated successfully"
    fi
}

update_remnanode() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" pull
}

is_remnanode_installed() {
    if [ -d "$APP_DIR" ]; then
        return 0
    else
        return 1
    fi
}

is_remnanode_up() {
    if ! is_remnanode_installed; then
        return 1
    fi
    
    detect_compose
    if [ -z "$($COMPOSE -f $COMPOSE_FILE ps -q -a)" ]; then
        return 1
    else
        return 0
    fi
}

# Функция для получения версии RemnaNode из контейнера
get_remnanode_version() {
    local container_name="$APP_NAME"
    
    # Проверяем что контейнер запущен
    if ! docker exec "$container_name" echo "test" >/dev/null 2>&1; then
        echo "unknown"
        return 1
    fi
    
    # Пробуем получить версию из package.json с помощью awk
    local version=$(docker exec "$container_name" awk -F'"' '/"version"/{print $4; exit}' package.json 2>/dev/null)
    
    if [ -z "$version" ]; then
        # Альтернативный способ с sed
        version=$(docker exec "$container_name" sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' package.json 2>/dev/null | head -1)
    fi
    
    if [ -z "$version" ]; then
        echo "unknown"
        return 1
    fi
    
    echo "$version"
    return 0
}

# Функция для получения версии Xray из контейнера
get_container_xray_version() {
    local container_name="$APP_NAME"
    
    # Проверяем что контейнер запущен
    if ! docker exec "$container_name" echo "test" >/dev/null 2>&1; then
        echo "unknown"
        return 1
    fi
    
    # Получаем версию xray из контейнера
    local version_output=$(docker exec "$container_name" xray version 2>/dev/null | head -1)
    
    if [ -z "$version_output" ]; then
        # Пробуем через полный путь
        version_output=$(docker exec "$container_name" /usr/local/bin/xray version 2>/dev/null | head -1)
    fi
    
    if [ -z "$version_output" ]; then
        echo "unknown"
        return 1
    fi
    
    # Парсим версию: "Xray 25.10.15 (Xray, Penetrates Everything.) ..."
    local version=$(echo "$version_output" | awk '{print $2}')
    
    if [ -z "$version" ]; then
        echo "unknown"
        return 1
    fi
    
    echo "$version"
    return 0
}

install_command() {
    check_running_as_root
    if is_remnanode_installed; then
        colorized_echo red "Remnanode is already installed at $APP_DIR"
        read -p "Do you want to override the previous installation? (y/n) "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo red "Aborted installation"
            exit 1
        fi
    fi
    detect_os
    if ! command -v curl >/dev/null 2>&1; then
        install_package curl
    fi
    if ! command -v docker >/dev/null 2>&1; then
        install_docker
    fi

    detect_compose
    install_remnanode_script
    install_remnanode
    
    # Check for selfsteal socket and enable volume if needed
    configure_selfsteal_integration
    
    up_remnanode
    follow_remnanode_logs

    # final message
    clear
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
    echo -e "\033[1;37m🎉 RemnaNode Successfully Installed!\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
    echo
    
    echo -e "\033[1;37m🌐 Connection Information:\033[0m"
    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "IP Address:" "$NODE_IP"
    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Port:" "$NODE_PORT"
    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s:%s\033[0m\n" "Full URL:" "$NODE_IP" "$NODE_PORT"
    echo
    
    echo -e "\033[1;37m📋 Next Steps:\033[0m"
    echo -e "   \033[38;5;250m1.\033[0m Use the IP and port above to set up your Remnawave Panel"
    echo -e "   \033[38;5;250m2.\033[0m Configure log rotation: \033[38;5;15msudo $APP_NAME setup-logs\033[0m"
    
    if [ "$INSTALL_XRAY" == "true" ]; then
        echo -e "   \033[38;5;250m3.\033[0m \033[1;37mXray-core is already installed and ready! ✅\033[0m"
    else
        echo -e "   \033[38;5;250m3.\033[0m Install Xray-core: \033[38;5;15msudo $APP_NAME core-update\033[0m"
    fi
    
    echo -e "   \033[38;5;250m4.\033[0m Secure with UFW: \033[38;5;15msudo ufw allow from \033[38;5;244mPANEL_IP\033[38;5;15m to any port $NODE_PORT\033[0m"
    echo -e "      \033[38;5;8m(Enable UFW: \033[38;5;15msudo ufw enable\033[38;5;8m)\033[0m"
    echo
    
    echo -e "\033[1;37m🛠️  Quick Commands:\033[0m"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "status" "📊 Check service status"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "logs" "📋 View container logs"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "restart" "🔄 Restart the service"
    if [ "$INSTALL_XRAY" == "true" ]; then
        printf "   \033[38;5;15m%-15s\033[0m %s\n" "xray_log_out" "📤 View Xray logs"
    fi
    echo
    
    echo -e "\033[1;37m📁 File Locations:\033[0m"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Configuration:" "$APP_DIR"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Data:" "$DATA_DIR"
    if [ "$INSTALL_XRAY" == "true" ]; then
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Xray Binary:" "$XRAY_FILE"
    fi
    echo
    
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
    echo -e "\033[38;5;8m💡 For all commands: \033[38;5;15msudo $APP_NAME\033[0m"
    echo -e "\033[38;5;8m📚 Project: \033[38;5;250mhttps://gig.ovh\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
}

uninstall_command() {
    check_running_as_root
    if ! is_remnanode_installed; then
        colorized_echo red "Remnanode not installed!"
        exit 1
    fi
    
    read -p "Do you really want to uninstall Remnanode? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Aborted"
        exit 1
    fi
    
    detect_compose
    if is_remnanode_up; then
        down_remnanode
    fi
    uninstall_remnanode_script
    uninstall_remnanode
    uninstall_remnanode_docker_images
    
    read -p "Do you want to remove Remnanode data files too ($DATA_DIR)? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo green "Remnanode uninstalled successfully"
    else
        uninstall_remnanode_data_files
        colorized_echo green "Remnanode uninstalled successfully"
    fi
}

install_script_command() {
    check_running_as_root
    colorized_echo blue "Installing RemnaNode script globally"
    install_remnanode_script
    colorized_echo green "✅ Script installed successfully!"
    colorized_echo white "   Version: $SCRIPT_VERSION"
    colorized_echo white "   Location: /usr/local/bin/$APP_NAME"
    colorized_echo white "You can now run '$APP_NAME' from anywhere"
}

uninstall_script_command() {
    check_running_as_root
    if [ ! -f "/usr/local/bin/$APP_NAME" ]; then
        colorized_echo red "❌ Script not found at /usr/local/bin/$APP_NAME"
        exit 1
    fi
    
    read -p "Are you sure you want to remove the script? (y/n): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo yellow "Operation cancelled"
        exit 0
    fi
    
    colorized_echo blue "Removing RemnaNode script"
    uninstall_remnanode_script
    colorized_echo green "✅ Script removed successfully!"
}

up_command() {
    help() {
        colorized_echo red "Usage: remnanode up [options]"
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs) no_logs=true ;;
            -h|--help) help; exit 0 ;;
            *) echo "Error: Invalid option: $1" >&2; help; exit 0 ;;
        esac
        shift
    done
    
    if ! is_remnanode_installed; then
        colorized_echo red "Remnanode not installed!"
        exit 1
    fi
    
    detect_compose
    
    if is_remnanode_up; then
        colorized_echo red "Remnanode already up"
        exit 1
    fi
    
    up_remnanode
    if [ "$no_logs" = false ]; then
        follow_remnanode_logs
    fi
}

down_command() {
    if ! is_remnanode_installed; then
        colorized_echo red "Remnanode not installed!"
        exit 1
    fi
    
    detect_compose
    
    if ! is_remnanode_up; then
        colorized_echo red "Remnanode already down"
        exit 1
    fi
    
    down_remnanode
}

restart_command() {
    help() {
        colorized_echo red "Usage: remnanode restart [options]"
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs) no_logs=true ;;
            -h|--help) help; exit 0 ;;
            *) echo "Error: Invalid option: $1" >&2; help; exit 0 ;;
        esac
        shift
    done
    
    if ! is_remnanode_installed; then
        colorized_echo red "Remnanode not installed!"
        exit 1
    fi
    
    detect_compose
    
    down_remnanode
    up_remnanode
    
    # Добавляем поддержку флага --no-logs
    if [ "$no_logs" = false ]; then
        follow_remnanode_logs
    fi
}

status_command() {
    echo -e "\033[1;37m📊 RemnaNode Status Check:\033[0m"
    echo
    
    if ! is_remnanode_installed; then
        printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Not Installed\033[0m\n" "Status:"
        echo -e "\033[38;5;8m   Run '\033[38;5;15msudo $APP_NAME install\033[38;5;8m' to install\033[0m"
        exit 1
    fi
    
    detect_compose
    
    if ! is_remnanode_up; then
        printf "   \033[38;5;15m%-12s\033[0m \033[1;33m⏹️  Down\033[0m\n" "Status:"
        echo -e "\033[38;5;8m   Run '\033[38;5;15msudo $APP_NAME up\033[38;5;8m' to start\033[0m"
        exit 1
    fi
    
    printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Running\033[0m\n" "Status:"
    
    # Получаем порт через универсальную функцию
    local node_port=$(get_env_variable "NODE_PORT")
    # Fallback to old variable for backward compatibility
    if [ -z "$node_port" ]; then
        node_port=$(get_env_variable "APP_PORT")
    fi
    
    if [ -n "$node_port" ]; then
        printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Port:" "$node_port"
    fi
    
    # Получаем версию RemnaNode
    local node_version=$(get_remnanode_version 2>/dev/null || echo "unknown")
    if [ "$node_version" != "unknown" ]; then
        printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250mv%s\033[0m\n" "RemnaNode:" "$node_version"
    fi
    
    # Проверяем Xray
    local xray_version=$(get_current_xray_core_version)
    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Xray Core:" "$xray_version"
    
    echo
}

logs_command() {
    help() {
        colorized_echo red "Usage: remnanode logs [options]"
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-follow   do not show follow logs"
    }
    
    local no_follow=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-follow) no_follow=true ;;
            -h|--help) help; exit 0 ;;
            *) echo "Error: Invalid option: $1" >&2; help; exit 0 ;;
        esac
        shift
    done
    
    if ! is_remnanode_installed; then
        colorized_echo red "Remnanode not installed!"
        exit 1
    fi
    
    detect_compose
    
    if ! is_remnanode_up; then
        colorized_echo red "Remnanode is not up."
        exit 1
    fi
    
    if [ "$no_follow" = true ]; then
        show_remnanode_logs
    else
        follow_remnanode_logs
    fi
}

# Функция для получения переменной окружения из .env или docker-compose.yml
get_env_variable() {
    local var_name="$1"
    local value=""
    
    # Сначала пробуем .env файл
    if [ -f "$ENV_FILE" ]; then
        value=$(grep "^${var_name}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    fi
    
    # Если не нашли в .env, ищем в docker-compose.yml
    if [ -z "$value" ] && [ -f "$COMPOSE_FILE" ]; then
        # Проверяем секцию environment в docker-compose.yml
        value=$(grep -A 20 "environment:" "$COMPOSE_FILE" 2>/dev/null | grep "${var_name}=" | head -1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
    fi
    
    echo "$value"
}

# Функция для проверки, используется ли .env или переменные в docker-compose.yml
check_env_configuration() {
    local uses_env_file=false
    local uses_inline_env=false
    
    # Проверяем наличие .env файла
    if [ -f "$ENV_FILE" ] && [ -s "$ENV_FILE" ]; then
        uses_env_file=true
    fi
    
    # Проверяем наличие env_file в docker-compose.yml
    if [ -f "$COMPOSE_FILE" ]; then
        if grep -q "env_file:" "$COMPOSE_FILE" 2>/dev/null; then
            uses_env_file=true
        fi
        
        # Проверяем наличие inline environment переменных
        if grep -A 5 "environment:" "$COMPOSE_FILE" 2>/dev/null | grep -q "NODE_PORT\|APP_PORT\|SECRET_KEY\|SSL_CERT"; then
            uses_inline_env=true
        fi
    fi
    
    if [ "$uses_env_file" = true ]; then
        echo "env_file"
    elif [ "$uses_inline_env" = true ]; then
        echo "inline"
    else
        echo "unknown"
    fi
}

# Функция для миграции старых переменных окружения к новым
migrate_env_variables() {
    echo
    colorized_echo blue "🔄 Starting Environment Variables Migration Check..."
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    
    if ! is_remnanode_installed; then
        colorized_echo yellow "⚠️  RemnaNode not installed, nothing to migrate"
        return 0
    fi
    
    local env_type=$(check_env_configuration)
    
    colorized_echo blue "🔍 Detected configuration type: $env_type"
    echo
    
    if [ "$env_type" = "env_file" ]; then
        migrate_env_file
    elif [ "$env_type" = "inline" ]; then
        migrate_inline_env
    else
        colorized_echo yellow "⚠️  Unknown configuration type, skipping migration"
        return 0
    fi
    
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
}

# Функция для миграции .env файла
migrate_env_file() {
    local env_file="$ENV_FILE"
    
    if [ ! -f "$env_file" ]; then
        colorized_echo yellow "⚠️  .env file not found, skipping migration"
        return 0
    fi
    
    local needs_migration=false
    local has_app_port=false
    local has_ssl_cert=false
    
    # Проверяем наличие старых переменных
    if grep -q "^APP_PORT=" "$env_file"; then
        has_app_port=true
        needs_migration=true
    fi
    
    if grep -q "^SSL_CERT=" "$env_file"; then
        has_ssl_cert=true
        needs_migration=true
    fi
    
    if [ "$needs_migration" = false ]; then
        colorized_echo green "✅ .env file is up to date"
        colorized_echo blue "   No migration needed - all variables use new format:"
        colorized_echo blue "   • NODE_PORT (instead of APP_PORT)"
        colorized_echo blue "   • SECRET_KEY (instead of SSL_CERT)"
        return 0
    fi
    
    colorized_echo blue "🔄 Detected old environment variables in .env:"
    if [ "$has_app_port" = true ]; then
        colorized_echo yellow "   • APP_PORT → will be migrated to NODE_PORT"
    fi
    if [ "$has_ssl_cert" = true ]; then
        colorized_echo yellow "   • SSL_CERT → will be migrated to SECRET_KEY"
    fi
    echo
    colorized_echo blue "📝 Starting migration..."
    
    # Создаем backup
    local backup_file="${env_file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$env_file" "$backup_file"
    colorized_echo green "✅ Backup created: $backup_file"
    
    # Выполняем миграцию
    local temp_file=$(mktemp)
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^APP_PORT= ]]; then
            # Заменяем APP_PORT на NODE_PORT
            echo "$line" | sed 's/^APP_PORT=/NODE_PORT=/' >> "$temp_file"
            colorized_echo green "  ✅ Migrated: APP_PORT → NODE_PORT"
        elif [[ "$line" =~ ^SSL_CERT= ]]; then
            # Заменяем SSL_CERT на SECRET_KEY
            echo "$line" | sed 's/^SSL_CERT=/SECRET_KEY=/' >> "$temp_file"
            colorized_echo green "  ✅ Migrated: SSL_CERT → SECRET_KEY"
        elif [[ "$line" =~ ^###[[:space:]]*APP[[:space:]]*### ]]; then
            # Заменяем заголовок секции
            echo "### NODE ###" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$env_file"
    
    # Заменяем оригинальный файл
    mv "$temp_file" "$env_file"
    
    echo
    colorized_echo green "🎉 .env migration completed successfully!"
    colorized_echo blue "📋 Summary:"
    if [ "$has_app_port" = true ]; then
        colorized_echo green "   ✅ APP_PORT → NODE_PORT"
    fi
    if [ "$has_ssl_cert" = true ]; then
        colorized_echo green "   ✅ SSL_CERT → SECRET_KEY"
    fi
    colorized_echo blue "💾 Backup: $backup_file"
    echo
    colorized_echo yellow "⚠️  Note: Old variables are deprecated and will be removed in future versions"
    echo
    
    return 0
}

# Функция для миграции inline переменных в docker-compose.yml
migrate_inline_env() {
    local compose_file="$COMPOSE_FILE"
    
    if [ ! -f "$compose_file" ]; then
        colorized_echo yellow "⚠️  docker-compose.yml not found, skipping migration"
        return 0
    fi
    
    local needs_migration=false
    
    # Проверяем наличие старых переменных в docker-compose.yml
    if grep -A 10 "environment:" "$compose_file" | grep -q "APP_PORT\|SSL_CERT"; then
        needs_migration=true
    fi
    
    if [ "$needs_migration" = false ]; then
        colorized_echo green "✅ docker-compose.yml is up to date"
        colorized_echo blue "   No migration needed - all variables use new format:"
        colorized_echo blue "   • NODE_PORT (instead of APP_PORT)"
        colorized_echo blue "   • SECRET_KEY (instead of SSL_CERT)"
        return 0
    fi
    
    colorized_echo blue "🔄 Detected old environment variables in docker-compose.yml:"
    if grep -A 10 "environment:" "$compose_file" | grep -q "APP_PORT"; then
        colorized_echo yellow "   • APP_PORT → will be migrated to NODE_PORT"
    fi
    if grep -A 10 "environment:" "$compose_file" | grep -q "SSL_CERT"; then
        colorized_echo yellow "   • SSL_CERT → will be migrated to SECRET_KEY"
    fi
    echo
    colorized_echo blue "📝 Starting migration..."
    
    # Создаем backup
    local backup_file="${compose_file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$compose_file" "$backup_file"
    colorized_echo green "✅ Backup created: $backup_file"
    
    # Выполняем миграцию
    local temp_file=$(mktemp)
    
    while IFS= read -r line; do
        if [[ "$line" =~ APP_PORT ]]; then
            # Заменяем APP_PORT на NODE_PORT
            echo "$line" | sed 's/APP_PORT/NODE_PORT/g' >> "$temp_file"
            colorized_echo green "  ✅ Migrated: APP_PORT → NODE_PORT"
        elif [[ "$line" =~ SSL_CERT ]]; then
            # Заменяем SSL_CERT на SECRET_KEY
            echo "$line" | sed 's/SSL_CERT/SECRET_KEY/g' >> "$temp_file"
            colorized_echo green "  ✅ Migrated: SSL_CERT → SECRET_KEY"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$compose_file"
    
    # Заменяем оригинальный файл
    mv "$temp_file" "$compose_file"
    
    echo
    colorized_echo green "🎉 docker-compose.yml migration completed successfully!"
    colorized_echo blue "💾 Backup: $backup_file"
    echo
    
    # Предлагаем мигрировать на .env файл
    colorized_echo blue "💡 Recommendation: Consider migrating to .env file for better security"
    colorized_echo blue "   Environment variables in docker-compose.yml are less secure"
    echo
    read -p "Do you want to migrate to .env file now? (y/n): " -r migrate_to_env
    
    if [[ $migrate_to_env =~ ^[Yy]$ ]]; then
        migrate_to_env_file
    else
        colorized_echo yellow "⚠️  Keeping inline environment variables"
    fi
    
    echo
    colorized_echo yellow "⚠️  Note: Old variables are deprecated and will be removed in future versions"
    echo
    
    return 0
}

# Функция для миграции inline переменных в .env файл
migrate_to_env_file() {
    colorized_echo blue "🔄 Migrating inline environment variables to .env file..."
    
    # Извлекаем переменные из docker-compose.yml
    local node_port=$(grep -A 10 "environment:" "$COMPOSE_FILE" 2>/dev/null | grep "NODE_PORT" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
    local secret_key=$(grep -A 10 "environment:" "$COMPOSE_FILE" 2>/dev/null | grep "SECRET_KEY" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
    
    # Создаем .env файл
    cat > "$ENV_FILE" <<EOL
### NODE ###
NODE_PORT=${node_port:-3000}

### XRAY ###
SECRET_KEY=$secret_key
EOL
    
    colorized_echo green "✅ .env file created: $ENV_FILE"
    
    # Обновляем docker-compose.yml для использования env_file
    local temp_file=$(mktemp)
    local in_environment_section=false
    local environment_indent=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*environment:[[:space:]]*$ ]]; then
            in_environment_section=true
            environment_indent=$(echo "$line" | sed 's/environment:.*//' | grep -o '^[[:space:]]*')
            # Заменяем environment на env_file
            echo "${environment_indent}env_file:" >> "$temp_file"
            echo "${environment_indent}  - .env" >> "$temp_file"
            continue
        fi
        
        if [ "$in_environment_section" = true ]; then
            # Пропускаем строки с переменными окружения
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(NODE_PORT|SECRET_KEY|APP_PORT|SSL_CERT) ]]; then
                continue
            elif [[ "$line" =~ ^[[:space:]]*[A-Z_]+=.* ]]; then
                continue
            else
                in_environment_section=false
            fi
        fi
        
        if [ "$in_environment_section" = false ]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$COMPOSE_FILE"
    
    # Заменяем оригинальный файл
    mv "$temp_file" "$COMPOSE_FILE"
    
    colorized_echo green "✅ docker-compose.yml updated to use .env file"
}

# Старая функция для обратной совместимости (теперь просто вызывает новую)
# migrate_env_variables() - уже определена выше

# update_command() {
#     check_running_as_root
#     if ! is_remnanode_installed; then
#         echo -e "\033[1;31m❌ RemnaNode not installed!\033[0m"
#         echo -e "\033[38;5;8m   Run '\033[38;5;15msudo $APP_NAME install\033[38;5;8m' first\033[0m"
#         exit 1
#     fi
    
#     detect_compose
    
#     echo -e "\033[1;37m🔄 Starting RemnaNode Update...\033[0m"
#     echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    
#     echo -e "\033[38;5;250m📝 Step 1:\033[0m Updating script..."
#     update_remnanode_script
#     echo -e "\033[1;32m✅ Script updated\033[0m"
    
#     echo -e "\033[38;5;250m📝 Step 2:\033[0m Pulling latest version..."
#     update_remnanode
#     echo -e "\033[1;32m✅ Image updated\033[0m"
    
#     echo -e "\033[38;5;250m📝 Step 3:\033[0m Restarting services..."
#     down_remnanode
#     up_remnanode
#     echo -e "\033[1;32m✅ Services restarted\033[0m"
    
#     echo
#     echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
#     echo -e "\033[1;37m🎉 RemnaNode updated successfully!\033[0m"
#     echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
# }



update_command() {
    check_running_as_root
    if ! is_remnanode_installed; then
        echo -e "\033[1;31m❌ RemnaNode not installed!\033[0m"
        echo -e "\033[38;5;8m   Run '\033[38;5;15msudo $APP_NAME install\033[38;5;8m' first\033[0m"
        exit 1
    fi
    
    detect_compose
    
    echo -e "\033[1;37m🔄 Starting RemnaNode Update Check...\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    
    # Проверяем и обновляем скрипт ПЕРВЫМ ДЕЛОМ
    echo -e "\033[38;5;250m📝 Step 1:\033[0m Checking script version..."
    local current_script_version="$SCRIPT_VERSION"
    local remote_script_version=$(curl -s "$SCRIPT_URL" 2>/dev/null | grep "^SCRIPT_VERSION=" | cut -d'"' -f2)
    local script_was_updated=false
    
    if [ -z "$remote_script_version" ]; then
        echo -e "\033[1;33m⚠️  Unable to check remote script version\033[0m"
        echo -e "\033[38;5;8m   Current version: v$current_script_version\033[0m"
        echo -e "\033[38;5;8m   Continuing with Docker image check...\033[0m"
    elif [ "$remote_script_version" != "$current_script_version" ]; then
        echo -e "\033[1;33m🔄 Script update available:\033[0m \033[38;5;8mv$current_script_version\033[0m → \033[1;37mv$remote_script_version\033[0m"
        echo -e "\033[38;5;250m   Updating script first (required for migrations)...\033[0m"
        
        if update_remnanode_script; then
            echo -e "\033[1;32m✅ Script updated:\033[0m \033[38;5;8mv$current_script_version\033[0m → \033[1;37mv$remote_script_version\033[0m"
            echo -e "\033[1;33m⚠️  Script updated! Please run '\033[38;5;15msudo $APP_NAME update\033[1;33m' again to continue.\033[0m"
            echo -e "\033[38;5;8m   This ensures all new features and migrations work correctly.\033[0m"
            script_was_updated=true
            exit 0
        else
            echo -e "\033[1;31m❌ Failed to update script\033[0m"
            exit 1
        fi
    else
        echo -e "\033[1;32m✅ Script is up to date:\033[0m \033[38;5;15mv$current_script_version\033[0m"
    fi
    echo
    
    # Определяем используемый тег из docker-compose.yml
    local current_tag="latest"
    if [ -f "$COMPOSE_FILE" ]; then
        current_tag=$(grep -E "image:.*remnawave/node:" "$COMPOSE_FILE" | sed 's/.*remnawave\/node://' | tr -d '"' | tr -d "'" | xargs)
        if [ -z "$current_tag" ]; then
            current_tag="latest"
        fi
    fi
    
    echo -e "\033[38;5;250m🏷️  Current tag:\033[0m \033[38;5;15m$current_tag\033[0m"
    
    # Получаем локальную версию образа
    echo -e "\033[38;5;250m📝 Step 2:\033[0m Checking local image version..."
    local local_image_id=""
    local local_created=""
    local image_name="ghcr.io/remnawave/node"
    
    if docker images ${image_name}:$current_tag --format "table {{.ID}}\t{{.CreatedAt}}" | grep -v "IMAGE ID" > /dev/null 2>&1; then
        local_image_id=$(docker images ${image_name}:$current_tag --format "{{.ID}}" | head -1)
        local_created=$(docker images ${image_name}:$current_tag --format "{{.CreatedAt}}" | head -1 | cut -d' ' -f1,2)
        
        echo -e "\033[1;32m✅ Local image found\033[0m"
        echo -e "\033[38;5;8m   Image ID: $local_image_id\033[0m"
        echo -e "\033[38;5;8m   Created: $local_created\033[0m"
    else
        echo -e "\033[1;33m⚠️  Local image not found\033[0m"
        local_image_id="none"
    fi
    
    # Проверяем обновления через docker pull
    echo -e "\033[38;5;250m📝 Step 3:\033[0m Checking for updates with docker pull..."
    
    # Сохраняем текущий образ ID для сравнения
    local old_image_id="$local_image_id"
    
    # Запускаем docker pull
    if $COMPOSE -f $COMPOSE_FILE pull --quiet 2>/dev/null; then
        # Проверяем, изменился ли ID образа после pull
        local new_image_id=$(docker images ${image_name}:$current_tag --format "{{.ID}}" | head -1)
        
        local needs_update=false
        local update_reason=""
        
        if [ "$old_image_id" = "none" ]; then
            needs_update=true
            update_reason="Local image not found, downloaded new version"
            echo -e "\033[1;33m🔄 New image downloaded\033[0m"
        elif [ "$old_image_id" != "$new_image_id" ]; then
            needs_update=true
            update_reason="New version downloaded via docker pull"
            echo -e "\033[1;33m🔄 New version detected and downloaded\033[0m"
        else
            needs_update=false
            update_reason="Already up to date (verified via docker pull)"
            echo -e "\033[1;32m✅ Already up to date\033[0m"
        fi
    else
        echo -e "\033[1;33m⚠️  Docker pull failed, assuming update needed\033[0m"
        local needs_update=true
        local update_reason="Unable to verify current version"
        local new_image_id="$old_image_id"
    fi
    
    echo
    echo -e "\033[1;37m📊 Update Analysis:\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    
    if [ "$needs_update" = true ]; then
        echo -e "\033[1;33m🔄 Update Available\033[0m"
        echo -e "\033[38;5;250m   Reason: \033[38;5;15m$update_reason\033[0m"
        echo
        
        # Если новая версия уже загружена, автоматически продолжаем
        if [[ "$update_reason" == *"downloaded"* ]]; then
            echo -e "\033[1;37m🚀 New version already downloaded, proceeding with update...\033[0m"
        else
            read -p "Do you want to proceed with the update? (y/n): " -r confirm_update
            if [[ ! $confirm_update =~ ^[Yy]$ ]]; then
                echo -e "\033[1;31m❌ Update cancelled by user\033[0m"
                exit 0
            fi
        fi
        
        echo
        echo -e "\033[1;37m🚀 Performing Update...\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
        
        # Проверяем и мигрируем переменные окружения
        echo -e "\033[38;5;250m📝 Step 4:\033[0m Checking environment variables..."
        migrate_env_variables
        
        # Проверяем, запущен ли контейнер
        local was_running=false
        if is_remnanode_up; then
            was_running=true
            echo -e "\033[38;5;250m📝 Step 5:\033[0m Stopping running container..."
            if down_remnanode; then
                echo -e "\033[1;32m✅ Container stopped\033[0m"
            else
                echo -e "\033[1;31m❌ Failed to stop container\033[0m"
                exit 1
            fi
        else
            echo -e "\033[38;5;250m📝 Step 5:\033[0m Container not running, skipping stop..."
        fi
        
        # Загружаем образ только если еще не загружен
        if [[ "$update_reason" != *"downloaded"* ]]; then
            echo -e "\033[38;5;250m📝 Step 6:\033[0m Pulling latest image..."
            if update_remnanode; then
                echo -e "\033[1;32m✅ Image updated\033[0m"
                # Обновляем ID образа
                new_image_id=$(docker images ${image_name}:$current_tag --format "{{.ID}}" | head -1)
            else
                echo -e "\033[1;31m❌ Failed to pull image\033[0m"
                
                # Если контейнер был запущен, пытаемся его восстановить
                if [ "$was_running" = true ]; then
                    echo -e "\033[38;5;250m🔄 Attempting to restore service...\033[0m"
                    up_remnanode
                fi
                exit 1
            fi
        else
            echo -e "\033[38;5;250m📝 Step 6:\033[0m Image already updated during check\033[0m"
        fi
        
        # Запускаем контейнер только если он был запущен ранее
        if [ "$was_running" = true ]; then
            echo -e "\033[38;5;250m📝 Step 7:\033[0m Starting updated container..."
            if up_remnanode; then
                echo -e "\033[1;32m✅ Container started\033[0m"
            else
                echo -e "\033[1;31m❌ Failed to start container\033[0m"
                exit 1
            fi
        else
            echo -e "\033[38;5;250m📝 Step 7:\033[0m Container was not running, leaving it stopped..."
        fi
        
        # Показываем финальную информацию
        echo
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo -e "\033[1;37m🎉 RemnaNode updated successfully!\033[0m"
        
        # Получаем актуальную информацию об образе
        local final_image_id=$(docker images ${image_name}:$current_tag --format "{{.ID}}" | head -1)
        local final_created=$(docker images ${image_name}:$current_tag --format "{{.CreatedAt}}" | head -1 | cut -d' ' -f1,2)
        
        # Fallback если не нашли по полному имени
        if [ -z "$final_image_id" ]; then
            final_image_id=$(docker images --format "{{.ID}}" | head -1)
            final_created=$(docker images --format "{{.CreatedAt}}" | head -1 | cut -d' ' -f1,2)
        fi
        
        echo -e "\033[1;37m📋 Update Summary:\033[0m"
        echo -e "\033[38;5;250m   Previous: \033[38;5;8m${old_image_id:-N/A}\033[0m"
        echo -e "\033[38;5;250m   Current:  \033[38;5;15m${final_image_id:-N/A}\033[0m"
        echo -e "\033[38;5;250m   Created:  \033[38;5;15m${final_created:-N/A}\033[0m"
        echo -e "\033[38;5;250m   Script:   \033[38;5;15mv$current_script_version\033[0m"
        
        if [ "$was_running" = true ]; then
            echo -e "\033[38;5;250m   Status:   \033[1;32mRunning\033[0m"
        else
            echo -e "\033[38;5;250m   Status:   \033[1;33mStopped\033[0m"
            echo -e "\033[38;5;8m   Use '\033[38;5;15msudo $APP_NAME up\033[38;5;8m' to start\033[0m"
        fi
        
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        
    else
        echo -e "\033[1;32m✅ Already Up to Date\033[0m"
        echo -e "\033[38;5;250m   Reason: \033[38;5;15m$update_reason\033[0m"
        echo
        
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
        echo -e "\033[1;37m📊 Current Status:\033[0m"
        
        echo -e "\033[38;5;250m   Script:    \033[38;5;15mv$current_script_version\033[0m"
        
        if is_remnanode_up; then
            echo -e "\033[38;5;250m   Container: \033[1;32mRunning ✅\033[0m"
        else
            echo -e "\033[38;5;250m   Container: \033[1;33mStopped ⏹️\033[0m"
            echo -e "\033[38;5;8m   Use '\033[38;5;15msudo $APP_NAME up\033[38;5;8m' to start\033[0m"
        fi
        
        echo -e "\033[38;5;250m   Image Tag: \033[38;5;15m$current_tag\033[0m"
        echo -e "\033[38;5;250m   Image ID:  \033[38;5;15m$local_image_id\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    fi
}

identify_the_operating_system_and_architecture() {
    if [[ "$(uname)" == 'Linux' ]]; then
        case "$(uname -m)" in
            'i386' | 'i686') ARCH='32' ;;
            'amd64' | 'x86_64') ARCH='64' ;;
            'armv5tel') ARCH='arm32-v5' ;;
            'armv6l') ARCH='arm32-v6'; grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5' ;;
            'armv7' | 'armv7l') ARCH='arm32-v7a'; grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5' ;;
            'armv8' | 'aarch64') ARCH='arm64-v8a' ;;
            'mips') ARCH='mips32' ;;
            'mipsle') ARCH='mips32le' ;;
            'mips64') ARCH='mips64'; lscpu | grep -q "Little Endian" && ARCH='mips64le' ;;
            'mips64le') ARCH='mips64le' ;;
            'ppc64') ARCH='ppc64' ;;
            'ppc64le') ARCH='ppc64le' ;;
            'riscv64') ARCH='riscv64' ;;
            's390x') ARCH='s390x' ;;
            *) echo "error: The architecture is not supported."; exit 1 ;;
        esac
    else
        echo "error: This operating system is not supported."
        exit 1
    fi
}

# Функция для проверки, примонтирован ли Xray файл в контейнер
is_xray_mounted() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        return 1
    fi
    
    # Проверяем, есть ли активная (не закомментированная) строка с монтированием xray
    if grep -v "^[[:space:]]*#" "$COMPOSE_FILE" | grep -q "$XRAY_FILE"; then
        return 0
    else
        return 1
    fi
}

get_current_xray_core_version() {
    # Сначала проверяем, примонтирован ли Xray в контейнер
    if is_xray_mounted && [ -f "$XRAY_FILE" ]; then
        # Xray примонтирован, получаем версию из локального файла
        version_output=$("$XRAY_FILE" -version 2>/dev/null)
        if [ $? -eq 0 ]; then
            version=$(echo "$version_output" | head -n1 | awk '{print $2}')
            echo "$version (external)"
            return 0
        fi
    fi
    
    # Если Xray не примонтирован или файл не работает, проверяем встроенную версию в контейнере
    local container_version=$(get_container_xray_version 2>/dev/null)
    if [ "$container_version" != "unknown" ] && [ -n "$container_version" ]; then
        echo "$container_version (built-in)"
        return 0
    fi
    
    echo "Not installed"
    return 1
}

get_xray_core() {
    identify_the_operating_system_and_architecture
    clear
    
    validate_version() {
        local version="$1"
        local response=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/tags/$version")
        if echo "$response" | grep -q '"message": "Not Found"'; then
            echo "invalid"
        else
            echo "valid"
        fi
    }
    
    print_menu() {
        clear
        
        # Заголовок в монохромном стиле
        echo -e "\033[1;37m⚡ Xray-core Installer\033[0m \033[38;5;8mVersion Manager\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
        echo
        
        # Текущая версия
        current_version=$(get_current_xray_core_version)
        echo -e "\033[1;37m🌐 Current Status:\033[0m"
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Xray Version:" "$current_version"
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Architecture:" "$ARCH"
        
        # Показываем путь установки только если Xray примонтирован
        if is_xray_mounted; then
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Install Path:" "$XRAY_FILE"
            printf "   \033[38;5;15m%-15s\033[0m \033[1;32m%s\033[0m\n" "Mount Status:" "✅ Mounted to container"
        else
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;244m%s\033[0m\n" "Mount Status:" "⚪ Using built-in version"
        fi
        echo
        
        # Показываем режим выбора релизов
        echo -e "\033[1;37m🎯 Release Mode:\033[0m"
        if [ "$show_prereleases" = true ]; then
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m \033[38;5;244m(Including Pre-releases)\033[0m\n" "Current:" "All Releases"
        else
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m \033[1;37m(Stable Only)\033[0m\n" "Current:" "Stable Releases"
        fi
        echo
        
        # Доступные версии с метками
        echo -e "\033[1;37m🚀 Available Versions:\033[0m"
        for ((i=0; i<${#versions[@]}; i++)); do
            local version_num=$((i + 1))
            local version_name="${versions[i]}"
            local is_prerelease="${prereleases[i]}"
            
            # Определяем тип релиза и используем echo вместо printf
            if [ "$is_prerelease" = "true" ]; then
                echo -e "   \033[38;5;15m${version_num}:\033[0m \033[38;5;250m${version_name}\033[0m \033[38;5;244m(Pre-release)\033[0m"
            elif [ $i -eq 0 ] && [ "$is_prerelease" = "false" ]; then
                echo -e "   \033[38;5;15m${version_num}:\033[0m \033[38;5;250m${version_name}\033[0m \033[1;37m(Latest Stable)\033[0m"
            else
                echo -e "   \033[38;5;15m${version_num}:\033[0m \033[38;5;250m${version_name}\033[0m \033[38;5;8m(Stable)\033[0m"
            fi
        done
        echo
        
        # Опции
        echo -e "\033[1;37m🔧 Options:\033[0m"
        printf "   \033[38;5;15m%-3s\033[0m %s\n" "M:" "📝 Enter version manually"
        if [ "$show_prereleases" = true ]; then
            printf "   \033[38;5;15m%-3s\033[0m %s\n" "S:" "🔒 Show stable releases only"
        else
            printf "   \033[38;5;15m%-3s\033[0m %s\n" "A:" "🧪 Show all releases (including pre-releases)"
        fi
        printf "   \033[38;5;15m%-3s\033[0m %s\n" "R:" "🔄 Refresh version list"
        printf "   \033[38;5;15m%-3s\033[0m %s\n" "D:" "🏠 Restore to container default Xray"
        printf "   \033[38;5;15m%-3s\033[0m %s\n" "Q:" "❌ Quit installer"
        echo
        
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
        echo -e "\033[1;37m📖 Usage:\033[0m"
        echo -e "   Choose a number \033[38;5;15m(1-${#versions[@]})\033[0m, \033[38;5;15mM\033[0m for manual, \033[38;5;15mA/S\033[0m to toggle releases, \033[38;5;15mD\033[0m to restore default, or \033[38;5;15mQ\033[0m to quit"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
    }
    
    fetch_versions() {
        local include_prereleases="$1"
        echo -e "\033[1;37m🔍 Fetching Xray-core versions...\033[0m"
        
        if [ "$include_prereleases" = true ]; then
            echo -e "\033[38;5;8m   Including pre-releases...\033[0m"
            latest_releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=8")
        else
            echo -e "\033[38;5;8m   Stable releases only...\033[0m"
            latest_releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=15")
        fi
        
        if [ -z "$latest_releases" ] || echo "$latest_releases" | grep -q '"message":'; then
            echo -e "\033[1;31m❌ Failed to fetch versions. Please check your internet connection.\033[0m"
            return 1
        fi
        
        # Парсим JSON и извлекаем нужную информацию
        versions=()
        prereleases=()
        
        # Извлекаем данные с помощью более надежного парсинга
        local temp_file=$(mktemp)
        echo "$latest_releases" | grep -E '"(tag_name|prerelease)"' > "$temp_file"
        
        local current_version=""
        local count=0
        local max_count=6
        
        while IFS= read -r line; do
            if [[ "$line" =~ \"tag_name\":[[:space:]]*\"([^\"]+)\" ]]; then
                current_version="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ \"prerelease\":[[:space:]]*(true|false) ]]; then
                local is_prerelease="${BASH_REMATCH[1]}"
                
                # Если не показываем pre-releases, пропускаем их
                if [ "$include_prereleases" = false ] && [ "$is_prerelease" = "true" ]; then
                    current_version=""
                    continue
                fi
                
                # Добавляем версию в массивы
                if [ -n "$current_version" ] && [ $count -lt $max_count ]; then
                    versions+=("$current_version")
                    prereleases+=("$is_prerelease")
                    ((count++)) || true
                fi
                current_version=""
            fi
        done < "$temp_file"
        
        rm "$temp_file"
        
        if [ ${#versions[@]} -eq 0 ]; then
            echo -e "\033[1;31m❌ No versions found.\033[0m"
            return 1
        fi
        
        echo -e "\033[1;32m✅ Found ${#versions[@]} versions\033[0m"
        return 0
    }
    
    # Инициализация
    local show_prereleases=false
    
    # Первоначальная загрузка версий
    if ! fetch_versions "$show_prereleases"; then
        exit 1
    fi
    
    while true; do
        print_menu
        echo -n -e "\033[1;37m> \033[0m"
        read choice
        
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#versions[@]}" ]; then
            choice=$((choice - 1))
            selected_version=${versions[choice]}
            local selected_prerelease=${prereleases[choice]}
            
            echo
            if [ "$selected_prerelease" = "true" ]; then
                echo -e "\033[1;33m⚠️  Selected pre-release version: \033[1;37m$selected_version\033[0m"
                echo -e "\033[38;5;8m   Pre-releases may contain bugs and are not recommended for production.\033[0m"
                read -p "Are you sure you want to continue? (y/n): " -r confirm_prerelease
                if [[ ! $confirm_prerelease =~ ^[Yy]$ ]]; then
                    echo -e "\033[1;31m❌ Installation cancelled.\033[0m"
                    continue
                fi
            else
                echo -e "\033[1;32m✅ Selected stable version: \033[1;37m$selected_version\033[0m"
            fi
            break
            
        elif [ "$choice" == "M" ] || [ "$choice" == "m" ]; then
            echo
            echo -e "\033[1;37m📝 Manual Version Entry:\033[0m"
            while true; do
                echo -n -e "\033[38;5;8mEnter version (e.g., v1.8.4): \033[0m"
                read custom_version
                
                if [ -z "$custom_version" ]; then
                    echo -e "\033[1;31m❌ Version cannot be empty. Please try again.\033[0m"
                    continue
                fi
                
                echo -e "\033[1;37m🔍 Validating version $custom_version...\033[0m"
                if [ "$(validate_version "$custom_version")" == "valid" ]; then
                    selected_version="$custom_version"
                    echo -e "\033[1;32m✅ Version $custom_version is valid!\033[0m"
                    break 2
                else
                    echo -e "\033[1;31m❌ Version $custom_version not found. Please try again.\033[0m"
                    echo -e "\033[38;5;8m   Hint: Check https://github.com/XTLS/Xray-core/releases\033[0m"
                    echo
                fi
            done
            
        elif [ "$choice" == "A" ] || [ "$choice" == "a" ]; then
            if [ "$show_prereleases" = false ]; then
                show_prereleases=true
                if ! fetch_versions "$show_prereleases"; then
                    show_prereleases=false
                    continue
                fi
            fi
            
        elif [ "$choice" == "S" ] || [ "$choice" == "s" ]; then
            if [ "$show_prereleases" = true ]; then
                show_prereleases=false
                if ! fetch_versions "$show_prereleases"; then
                    show_prereleases=true
                    continue
                fi
            fi
            
        elif [ "$choice" == "R" ] || [ "$choice" == "r" ]; then
            if ! fetch_versions "$show_prereleases"; then
                continue
            fi
            
        elif [ "$choice" == "D" ] || [ "$choice" == "d" ]; then
            echo
            echo -e "\033[1;33m🏠 Restore to Container Default Xray\033[0m"
            echo -e "\033[38;5;8m   This will remove external Xray mount and use the version built into the container.\033[0m"
            echo
            read -p "Are you sure you want to restore to container default? (y/n): " -r confirm_restore
            if [[ $confirm_restore =~ ^[Yy]$ ]]; then
                restore_to_container_default
                echo
                echo -n -e "\033[38;5;8mPress Enter to continue...\033[0m"
                read
            else
                echo -e "\033[1;31m❌ Restore cancelled.\033[0m"
                echo
                echo -n -e "\033[38;5;8mPress Enter to continue...\033[0m"
                read
            fi
            
        elif [ "$choice" == "Q" ] || [ "$choice" == "q" ]; then
            echo
            echo -e "\033[1;31m❌ Installation cancelled by user.\033[0m"
            exit 0
            
        else
            echo
            echo -e "\033[1;31m❌ Invalid choice: '$choice'\033[0m"
            echo -e "\033[38;5;8m   Please enter a number between 1-${#versions[@]}, M for manual, A/S to toggle releases, R to refresh, D to restore default, or Q to quit.\033[0m"
            echo
            echo -n -e "\033[38;5;8mPress Enter to continue...\033[0m"
            read
        fi
    done
    
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    echo -e "\033[1;37m🚀 Starting Installation\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    
    # Проверка и установка unzip
    if ! dpkg -s unzip >/dev/null 2>&1; then
        echo -e "\033[1;37m📦 Installing required packages...\033[0m"
        detect_os
        install_package unzip
        echo -e "\033[1;32m✅ Packages installed successfully\033[0m"
    fi
    
    mkdir -p "$DATA_DIR"
    cd "$DATA_DIR"
    
    xray_filename="Xray-linux-$ARCH.zip"
    xray_download_url="https://github.com/XTLS/Xray-core/releases/download/${selected_version}/${xray_filename}"
    
    # Скачивание с прогрессом
    echo -e "\033[1;37m📥 Downloading Xray-core $selected_version...\033[0m"
    echo -e "\033[38;5;8m   URL: $xray_download_url\033[0m"
    
    if wget "${xray_download_url}" -q --show-progress; then
        echo -e "\033[1;32m✅ Download completed successfully\033[0m"
    else
        echo -e "\033[1;31m❌ Download failed!\033[0m"
        echo -e "\033[38;5;8m   Please check your internet connection or try a different version.\033[0m"
        exit 1
    fi
    
    # Извлечение
    echo -e "\033[1;37m📦 Extracting Xray-core...\033[0m"
    if unzip -o "${xray_filename}" -d "$DATA_DIR" >/dev/null 2>&1; then
        echo -e "\033[1;32m✅ Extraction completed successfully\033[0m"
    else
        echo -e "\033[1;31m❌ Extraction failed!\033[0m"
        echo -e "\033[38;5;8m   The downloaded file may be corrupted.\033[0m"
        exit 1
    fi
    
    # Очистка и настройка прав
    rm "${xray_filename}"
    chmod +x "$XRAY_FILE"
    
    # Финальное сообщение
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    echo -e "\033[1;37m🎉 Installation Complete!\033[0m"
    
    # Информация об установке
    echo -e "\033[1;37m📋 Installation Details:\033[0m"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Version:" "$selected_version"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Architecture:" "$ARCH"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Install Path:" "$XRAY_FILE"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "File Size:" "$(du -h "$XRAY_FILE" | cut -f1)"
    echo
    
    # Проверка версии
    echo -e "\033[1;37m🔍 Verifying installation...\033[0m"
    if installed_version=$("$XRAY_FILE" -version 2>/dev/null | head -n1 | awk '{print $2}'); then
        echo -e "\033[1;32m✅ Xray-core is working correctly\033[0m"
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Running Version:" "$installed_version"
    else
        echo -e "\033[1;31m⚠️  Installation completed but verification failed\033[0m"
        echo -e "\033[38;5;8m   The binary may not be compatible with your system\033[0m"
    fi
}



# Функция для создания резервной копии файла
create_backup() {
    local file="$1"
    local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$file" ]; then
        cp "$file" "$backup_file"
        echo "$backup_file"
        return 0
    else
        return 1
    fi
}

# Функция для восстановления из резервной копии
restore_backup() {
    local backup_file="$1"
    local original_file="$2"
    
    if [ -f "$backup_file" ]; then
        cp "$backup_file" "$original_file"
        return 0
    else
        return 1
    fi
}

# Функция для проверки валидности docker-compose файла
validate_compose_file() {
    local compose_file="$1"
    
    if [ ! -f "$compose_file" ]; then
        return 1
    fi
    

    local current_dir=$(pwd)
    

    cd "$(dirname "$compose_file")"
    

    if command -v docker >/dev/null 2>&1; then

        detect_compose
        
        # Проверяем синтаксис файла
        if $COMPOSE config >/dev/null 2>&1; then
            cd "$current_dir"
            return 0
        else

            colorized_echo red "Docker Compose validation errors:"
            $COMPOSE config 2>&1 | head -10
            cd "$current_dir"
            return 1
        fi
    else

        if grep -q "services:" "$compose_file" && grep -q "remnanode:" "$compose_file"; then
            cd "$current_dir"
            return 0
        else
            cd "$current_dir"
            return 1
        fi
    fi
}

# Функция для удаления старых резервных копий (оставляем только последние 5)
cleanup_old_backups() {
    local file_pattern="$1"
    local keep_count=5
    
    # Найти все файлы резервных копий и удалить старые
    ls -t ${file_pattern}.backup.* 2>/dev/null | tail -n +$((keep_count + 1)) | xargs rm -f 2>/dev/null || true
}

# Обновленная функция для определения отступов из docker-compose.yml
get_indentation_from_compose() {
    local compose_file="$1"
    local indentation=""
    
    if [ -f "$compose_file" ]; then
        # Сначала ищем строку с "remnanode:" (точное совпадение)
        local service_line=$(grep -n "remnanode:" "$compose_file" | head -1)
        if [ -n "$service_line" ]; then
            local line_content=$(echo "$service_line" | cut -d':' -f2-)
            indentation=$(echo "$line_content" | sed 's/remnanode:.*//' | grep -o '^[[:space:]]*')
        fi
        
        # Если не нашли точное совпадение, ищем любой сервис с "remna"
        if [ -z "$indentation" ]; then
            local remna_service_line=$(grep -E "^[[:space:]]*[a-zA-Z0-9_-]*remna[a-zA-Z0-9_-]*:" "$compose_file" | head -1)
            if [ -n "$remna_service_line" ]; then
                indentation=$(echo "$remna_service_line" | sed 's/[a-zA-Z0-9_-]*remna[a-zA-Z0-9_-]*:.*//' | grep -o '^[[:space:]]*')
            fi
        fi
        
        # Если не нашли сервис с "remna", пробуем найти любой сервис
        if [ -z "$indentation" ]; then
            local any_service_line=$(grep -E "^[[:space:]]*[a-zA-Z0-9_-]+:" "$compose_file" | head -1)
            if [ -n "$any_service_line" ]; then
                indentation=$(echo "$any_service_line" | sed 's/[a-zA-Z0-9_-]*:.*//' | grep -o '^[[:space:]]*')
            fi
        fi
    fi
    
    # Если ничего не нашли, используем 2 пробела по умолчанию
    if [ -z "$indentation" ]; then
        indentation="  "
    fi
    
    echo "$indentation"
}

# Обновленная функция для получения отступа для свойств сервиса
get_service_property_indentation() {
    local compose_file="$1"
    local base_indent=$(get_indentation_from_compose "$compose_file")
    local indent_type=""
    if [[ "$base_indent" =~ $'\t' ]]; then
        indent_type=$'\t'
    else
        indent_type="  "
    fi
    local property_indent=""
    if [ -f "$compose_file" ]; then
        local in_remna_service=false
        local current_service=""
        
        while IFS= read -r line; do

            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*$ ]]; then
                current_service=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/:[[:space:]]*$//')
                

                if [[ "$current_service" =~ remna ]]; then
                    in_remna_service=true
                else
                    in_remna_service=false
                fi
                continue
            fi
            

            if [ "$in_remna_service" = true ]; then
                local line_indent=$(echo "$line" | grep -o '^[[:space:]]*')
                

                if [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*$ ]] && [ ${#line_indent} -le ${#base_indent} ]; then
                    break
                fi
                

                if [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]] ]] && [[ ! "$line" =~ ^[[:space:]]*- ]]; then
                    property_indent=$(echo "$line" | sed 's/[a-zA-Z0-9_-]*:.*//' | grep -o '^[[:space:]]*')
                    break
                fi
            fi
        done < "$compose_file"
    fi
    
    # Если не нашли свойство, добавляем один уровень отступа к базовому
    if [ -z "$property_indent" ]; then
        property_indent="${base_indent}${indent_type}"
    fi
    
    echo "$property_indent"
}


escape_for_sed() {
    local text="$1"
    echo "$text" | sed 's/[]\.*^$()+?{|[]/\\&/g' | sed 's/\t/\\t/g'
}


update_core_command() {
    check_running_as_root
    get_xray_core
    colorized_echo blue "Updating docker-compose.yml with Xray-core volume..."
    

    if [ ! -f "$COMPOSE_FILE" ]; then
        colorized_echo red "Docker Compose file not found at $COMPOSE_FILE"
        exit 1
    fi
    

    colorized_echo blue "Creating backup of docker-compose.yml..."
    backup_file=$(create_backup "$COMPOSE_FILE")
    if [ $? -eq 0 ]; then
        colorized_echo green "Backup created: $backup_file"
    else
        colorized_echo red "Failed to create backup"
        exit 1
    fi
    

    local service_indent=$(get_service_property_indentation "$COMPOSE_FILE")
    

    local indent_type=""
    if [[ "$service_indent" =~ $'\t' ]]; then
        indent_type=$'\t'
    else
        indent_type="  "
    fi
    local volume_item_indent="${service_indent}${indent_type}"
    

    local escaped_service_indent=$(escape_for_sed "$service_indent")
    local escaped_volume_item_indent=$(escape_for_sed "$volume_item_indent")

    if grep -q "^${escaped_service_indent}volumes:" "$COMPOSE_FILE"; then
        # Remove existing xray-related volumes using # as delimiter to avoid issues with / in paths
        sed -i "\#$XRAY_FILE#d" "$COMPOSE_FILE"
        sed -i "\#geoip\.dat#d" "$COMPOSE_FILE"
        sed -i "\#geosite\.dat#d" "$COMPOSE_FILE"
        
        # Create temporary file with volume mounts
        temp_volumes=$(mktemp)
        echo "${volume_item_indent}- $XRAY_FILE:/usr/local/bin/xray" > "$temp_volumes"
        if [ -f "$GEOIP_FILE" ]; then
            echo "${volume_item_indent}- $GEOIP_FILE:/usr/local/share/xray/geoip.dat" >> "$temp_volumes"
        fi
        if [ -f "$GEOSITE_FILE" ]; then
            echo "${volume_item_indent}- $GEOSITE_FILE:/usr/local/share/xray/geosite.dat" >> "$temp_volumes"
        fi
        
        # Insert volumes after the volumes: line
        sed -i "/^${escaped_service_indent}volumes:/r $temp_volumes" "$COMPOSE_FILE"
        rm "$temp_volumes"
        colorized_echo green "Updated Xray volumes in existing volumes section"
        
    elif grep -q "^${escaped_service_indent}# volumes:" "$COMPOSE_FILE"; then
        sed -i "s|^${escaped_service_indent}# volumes:|${service_indent}volumes:|g" "$COMPOSE_FILE"
        
        # Create temporary file with volume mounts
        temp_volumes=$(mktemp)
        echo "${volume_item_indent}- $XRAY_FILE:/usr/local/bin/xray" > "$temp_volumes"
        if [ -f "$GEOIP_FILE" ]; then
            echo "${volume_item_indent}- $GEOIP_FILE:/usr/local/share/xray/geoip.dat" >> "$temp_volumes"
        fi
        if [ -f "$GEOSITE_FILE" ]; then
            echo "${volume_item_indent}- $GEOSITE_FILE:/usr/local/share/xray/geosite.dat" >> "$temp_volumes"
        fi
        
        # Insert volumes after the volumes: line
        sed -i "/^${escaped_service_indent}volumes:/r $temp_volumes" "$COMPOSE_FILE"
        rm "$temp_volumes"
        colorized_echo green "Uncommented volumes section and added Xray volumes"
        
    else
        # Create temporary file with volumes section
        temp_volumes=$(mktemp)
        echo "${service_indent}volumes:" > "$temp_volumes"
        echo "${volume_item_indent}- $XRAY_FILE:/usr/local/bin/xray" >> "$temp_volumes"
        if [ -f "$GEOIP_FILE" ]; then
            echo "${volume_item_indent}- $GEOIP_FILE:/usr/local/share/xray/geoip.dat" >> "$temp_volumes"
        fi
        if [ -f "$GEOSITE_FILE" ]; then
            echo "${volume_item_indent}- $GEOSITE_FILE:/usr/local/share/xray/geosite.dat" >> "$temp_volumes"
        fi
        
        # Insert volumes section after restart: always
        sed -i "/^${escaped_service_indent}restart: always/r $temp_volumes" "$COMPOSE_FILE"
        rm "$temp_volumes"
        colorized_echo green "Added new volumes section with Xray volumes"
    fi
    
    # Show what was mounted
    colorized_echo blue "Mounted volumes:"
    colorized_echo green "  ✅ xray → /usr/local/bin/xray"
    if [ -f "$GEOIP_FILE" ]; then
        colorized_echo green "  ✅ geoip.dat → /usr/local/share/xray/geoip.dat"
    fi
    if [ -f "$GEOSITE_FILE" ]; then
        colorized_echo green "  ✅ geosite.dat → /usr/local/share/xray/geosite.dat"
    fi
    

    colorized_echo blue "Validating docker-compose.yml..."
    if validate_compose_file "$COMPOSE_FILE"; then
        colorized_echo green "Docker-compose.yml validation successful"
        
        colorized_echo blue "Restarting RemnaNode..."

        restart_command -n
        
        colorized_echo green "Installation of XRAY-CORE version $selected_version completed."
        

        read -p "Operation completed successfully. Do you want to keep the backup file? (y/n): " -r keep_backup
        if [[ ! $keep_backup =~ ^[Yy]$ ]]; then
            rm "$backup_file"
            colorized_echo blue "Backup file removed"
        else
            colorized_echo blue "Backup file kept at: $backup_file"
        fi

        cleanup_old_backups "$COMPOSE_FILE"
        
    else
        colorized_echo red "Docker-compose.yml validation failed! Restoring backup..."
        if restore_backup "$backup_file" "$COMPOSE_FILE"; then
            colorized_echo green "Backup restored successfully"
            colorized_echo red "Please check the docker-compose.yml file manually"
        else
            colorized_echo red "Failed to restore backup! Original file may be corrupted"
            colorized_echo red "Backup location: $backup_file"
        fi
        exit 1
    fi
}


restore_to_container_default() {
    check_running_as_root
    colorized_echo blue "Restoring to container default Xray-core..."
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        colorized_echo red "Docker Compose file not found at $COMPOSE_FILE"
        exit 1
    fi
    
    # Create backup before making changes
    colorized_echo blue "Creating backup of docker-compose.yml..."
    backup_file=$(create_backup "$COMPOSE_FILE")
    if [ $? -eq 0 ]; then
        colorized_echo green "Backup created: $backup_file"
    else
        colorized_echo red "Failed to create backup"
        exit 1
    fi
    
    local service_indent=$(get_service_property_indentation "$COMPOSE_FILE")
    local escaped_service_indent=$(escape_for_sed "$service_indent")
    
    # Get the indent type for volume items
    local indent_type=""
    if [[ "$service_indent" =~ $'\t' ]]; then
        indent_type=$'\t'
    else
        indent_type="  "
    fi
    local volume_item_indent="${service_indent}${indent_type}"
    local escaped_volume_item_indent=$(escape_for_sed "$volume_item_indent")
    
    # Remove xray-related volume mounts using # as delimiter
    colorized_echo blue "Removing external Xray volume mounts..."
    sed -i "\#$XRAY_FILE#d" "$COMPOSE_FILE"
    sed -i "\#geoip\.dat#d" "$COMPOSE_FILE"
    sed -i "\#geosite\.dat#d" "$COMPOSE_FILE"
    
    # Check if volumes section is now empty and comment it out
    if grep -q "^${escaped_service_indent}volumes:" "$COMPOSE_FILE"; then
        # Count remaining volume items (lines starting with volume_item_indent and -)
        # We need to count lines between 'volumes:' and the next service-level property
        local temp_file=$(mktemp)
        local in_volumes=false
        local volume_count=0
        
        while IFS= read -r line; do
            # Check if we're entering the volumes section
            if [[ "$line" =~ ^${service_indent}volumes:[[:space:]]*$ ]]; then
                in_volumes=true
                continue
            fi
            
            # If we're in volumes section
            if [ "$in_volumes" = true ]; then
                # Check if this is a volume item
                if [[ "$line" =~ ^${volume_item_indent}-[[:space:]] ]]; then
                    ((volume_count++))
                # Check if we've exited the volumes section (found another service property or service)
                elif [[ "$line" =~ ^${service_indent}[a-zA-Z_] ]] || [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]*$ ]]; then
                    break
                fi
            fi
        done < "$COMPOSE_FILE"
        
        rm -f "$temp_file"
        
        if [ "$volume_count" -eq 0 ]; then
            colorized_echo blue "No volumes left, commenting out volumes section..."
            sed -i "s|^${escaped_service_indent}volumes:|${service_indent}# volumes:|g" "$COMPOSE_FILE"
        fi
    fi
    
    # Validate the docker-compose file
    colorized_echo blue "Validating docker-compose.yml..."
    if validate_compose_file "$COMPOSE_FILE"; then
        colorized_echo green "Docker-compose.yml validation successful"
        
        colorized_echo blue "Restarting RemnaNode to use container default Xray..."
        restart_command -n
        
        colorized_echo green "✅ Successfully restored to container default Xray-core"
        colorized_echo blue "The container will now use its built-in Xray version"
        
        # Ask about backup
        read -p "Operation completed successfully. Do you want to keep the backup file? (y/n): " -r keep_backup
        if [[ ! $keep_backup =~ ^[Yy]$ ]]; then
            rm "$backup_file"
            colorized_echo blue "Backup file removed"
        else
            colorized_echo blue "Backup file kept at: $backup_file"
        fi

        cleanup_old_backups "$COMPOSE_FILE"
        
    else
        colorized_echo red "Docker-compose.yml validation failed! Restoring backup..."
        if restore_backup "$backup_file" "$COMPOSE_FILE"; then
            colorized_echo green "Backup restored successfully"
            colorized_echo red "Please check the docker-compose.yml file manually"
        else
            colorized_echo red "Failed to restore backup! Original file may be corrupted"
            colorized_echo red "Backup location: $backup_file"
        fi
        exit 1
    fi
}


check_editor() {
    if [ -z "$EDITOR" ]; then
        if command -v nano >/dev/null 2>&1; then
            EDITOR="nano"
        elif command -v vi >/dev/null 2>&1; then
            EDITOR="vi"
        else
            detect_os
            install_package nano
            EDITOR="nano"
        fi
    fi
}

xray_log_out() {
    if ! is_remnanode_installed; then
        colorized_echo red "RemnaNode not installed!"
        exit 1
    fi
    detect_compose

    if ! is_remnanode_up; then
        colorized_echo red "RemnaNode is not running. Start it first with 'remnanode up'"
        exit 1
    fi

    # Check if log file exists
    if ! docker exec $APP_NAME test -f /var/log/supervisor/xray.out.log 2>/dev/null; then
        colorized_echo yellow "⚠️  Xray output log file not found yet."
        colorized_echo gray "   The log file will be created when Xray generates output."
        colorized_echo gray "   Try again later or check container logs: $APP_NAME logs"
        return 0
    fi

    colorized_echo blue "📤 Following Xray output logs (Ctrl+C to exit)..."
    echo
    docker exec -it $APP_NAME tail -n 100 -f /var/log/supervisor/xray.out.log
}

xray_log_err() {
    if ! is_remnanode_installed; then
        colorized_echo red "RemnaNode not installed!"
        exit 1
    fi
    
    detect_compose
 
    if ! is_remnanode_up; then
        colorized_echo red "RemnaNode is not running. Start it first with 'remnanode up'"
        exit 1
    fi

    # Check if log file exists
    if ! docker exec $APP_NAME test -f /var/log/supervisor/xray.err.log 2>/dev/null; then
        colorized_echo yellow "⚠️  Xray error log file not found yet."
        colorized_echo gray "   The log file will be created when Xray generates errors."
        colorized_echo green "   ✅ No errors is good news!"
        return 0
    fi

    # Check if log file is empty
    local log_size=$(docker exec $APP_NAME stat -c%s /var/log/supervisor/xray.err.log 2>/dev/null || echo "0")
    if [ "$log_size" = "0" ]; then
        colorized_echo green "✅ Xray error log is empty - no errors recorded!"
        return 0
    fi

    colorized_echo blue "📥 Following Xray error logs (Ctrl+C to exit)..."
    echo
    docker exec -it $APP_NAME tail -n 100 -f /var/log/supervisor/xray.err.log
}

edit_command() {
    detect_os
    check_editor
    if [ -f "$COMPOSE_FILE" ]; then
        $EDITOR "$COMPOSE_FILE"
    else
        colorized_echo red "Compose file not found at $COMPOSE_FILE"
        exit 1
    fi
}

edit_env_command() {
    detect_os
    check_editor
    
    local env_type=$(check_env_configuration)
    
    if [ "$env_type" = "env_file" ]; then
        if [ -f "$ENV_FILE" ]; then
            $EDITOR "$ENV_FILE"
        else
            colorized_echo red "Environment file not found at $ENV_FILE"
            exit 1
        fi
    elif [ "$env_type" = "inline" ]; then
        colorized_echo yellow "⚠️  Environment variables are stored in docker-compose.yml"
        colorized_echo blue "💡 Recommendation: Migrate to .env file for better security"
        echo
        read -p "Do you want to migrate to .env file now? (y/n): " -r migrate_choice
        
        if [[ $migrate_choice =~ ^[Yy]$ ]]; then
            migrate_to_env_file
            colorized_echo green "✅ Migration completed! Opening .env file for editing..."
            sleep 1
            $EDITOR "$ENV_FILE"
        else
            colorized_echo blue "Opening docker-compose.yml for editing..."
            sleep 1
            $EDITOR "$COMPOSE_FILE"
        fi
    else
        colorized_echo red "❌ Could not determine environment configuration"
        colorized_echo yellow "⚠️  Neither .env file nor inline environment variables found"
        echo
        read -p "Do you want to create a .env file? (y/n): " -r create_choice
        
        if [[ $create_choice =~ ^[Yy]$ ]]; then
            colorized_echo blue "Creating .env file template..."
            cat > "$ENV_FILE" <<EOL
### NODE ###
NODE_PORT=3000

### XRAY ###
SECRET_KEY=
EOL
            colorized_echo green "✅ .env file created: $ENV_FILE"
            colorized_echo blue "Opening for editing..."
            sleep 1
            $EDITOR "$ENV_FILE"
        else
            exit 1
        fi
    fi
}

# Show ports configuration command
ports_command() {
    echo
    echo -e "\033[1;37m🔌 Ports Configuration\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    
    if ! is_remnanode_installed; then
        colorized_echo red "❌ RemnaNode not installed"
        colorized_echo gray "   Run 'sudo $APP_NAME install' first"
        exit 1
    fi
    
    # External port
    echo
    echo -e "\033[1;37m🌐 External Port:\033[0m"
    local node_port=$(get_env_variable "NODE_PORT")
    if [ -z "$node_port" ]; then
        node_port=$(get_env_variable "APP_PORT")
    fi
    printf "   \033[38;5;15m%-22s\033[0m \033[38;5;250m%s\033[0m\n" "NODE_PORT:" "${node_port:-3000 (default)}"
    
    # Internal ports
    echo
    echo -e "\033[1;37m🔧 Internal Ports:\033[0m"
    
    local xtls_port=$(get_env_variable "XTLS_API_PORT")
    local rest_port=$(get_env_variable "INTERNAL_REST_PORT")
    local supervisord_port=$(get_env_variable "SUPERVISORD_PORT")
    
    printf "   \033[38;5;15m%-22s\033[0m \033[38;5;250m%s\033[0m\n" "XTLS_API_PORT:" "${xtls_port:-$DEFAULT_XTLS_API_PORT (default)}"
    printf "   \033[38;5;15m%-22s\033[0m \033[38;5;250m%s\033[0m\n" "INTERNAL_REST_PORT:" "${rest_port:-$DEFAULT_INTERNAL_REST_PORT (default)}"
    printf "   \033[38;5;15m%-22s\033[0m \033[38;5;250m%s\033[0m\n" "SUPERVISORD_PORT:" "${supervisord_port:-$DEFAULT_SUPERVISORD_PORT (default)}"
    
    # Check if internal ports are explicitly set
    if [ -z "$xtls_port" ] && [ -z "$rest_port" ] && [ -z "$supervisord_port" ]; then
        echo
        colorized_echo gray "   ℹ️  Internal ports not explicitly set in .env"
        colorized_echo gray "   Container will use default values (61000-61002)"
    fi
    
    # Show connection info
    echo
    echo -e "\033[1;37m📋 Connection Info:\033[0m"
    printf "   \033[38;5;15m%-22s\033[0m \033[38;5;117m%s:%s\033[0m\n" "Node Address:" "$NODE_IP" "${node_port:-3000}"
    
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    colorized_echo gray "💡 To modify ports, use: $APP_NAME edit-env"
    echo
}


usage() {
    clear

    echo -e "\033[1;37m⚡ $APP_NAME\033[0m \033[38;5;8mCommand Line Interface\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    echo
    echo -e "\033[1;37m📖 Usage:\033[0m"
    echo -e "   \033[38;5;15m$APP_NAME\033[0m \033[38;5;8m<command>\033[0m \033[38;5;244m[options]\033[0m"
    echo

    echo -e "\033[1;37m🚀 Core Commands:\033[0m"
    printf "   \033[38;5;15m%-18s\033[0m %s\n" "install" "🛠️  Install RemnaNode"
    printf "   \033[38;5;15m%-18s\033[0m %s\n" "update" "⬆️  Update to latest version"
    printf "   \033[38;5;15m%-18s\033[0m %s\n" "uninstall" "🗑️  Remove RemnaNode completely"
    echo

    echo -e "\033[1;37m⚙️  Service Control:\033[0m"
    printf "   \033[38;5;250m%-18s\033[0m %s\n" "up" "▶️  Start services"
    printf "   \033[38;5;250m%-18s\033[0m %s\n" "down" "⏹️  Stop services"
    printf "   \033[38;5;250m%-18s\033[0m %s\n" "restart" "🔄 Restart services"
    printf "   \033[38;5;250m%-18s\033[0m %s\n" "status" "📊 Show service status"
    echo

    echo -e "\033[1;37m📊 Monitoring & Logs:\033[0m"
    printf "   \033[38;5;244m%-18s\033[0m %s\n" "logs" "📋 View container logs"
    printf "   \033[38;5;244m%-18s\033[0m %s\n" "xray-log-out" "📤 View Xray output logs"
    printf "   \033[38;5;244m%-18s\033[0m %s\n" "xray-log-err" "📥 View Xray error logs"
    printf "   \033[38;5;244m%-18s\033[0m %s\n" "setup-logs" "🗂️  Setup log rotation"
    echo

    echo -e "\033[1;37m⚙️  Updates & Configuration:\033[0m"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "update" "🔄 Update RemnaNode"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "core-update" "⬆️  Update Xray-core"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "migrate" "🔄 Migrate environment variables"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "edit" "📝 Edit docker-compose.yml"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "edit-env" "🔐 Edit environment (.env)"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "ports" "🔌 Show ports configuration"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "enable-socket" "🔗 Enable selfsteal socket access"
    echo

    echo -e "\033[1;37m📋 Information:\033[0m"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "help" "📖 Show this help"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "version" "📋 Show version info"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "menu" "🎛️  Interactive menu"
    echo

    if is_remnanode_installed; then
        local node_port=$(get_env_variable "NODE_PORT")
        # Fallback to old variable for backward compatibility
        if [ -z "$node_port" ]; then
            node_port=$(get_env_variable "APP_PORT")
        fi
        if [ -n "$node_port" ]; then
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
            echo -e "\033[1;37m🌐 Node Access:\033[0m \033[38;5;117m$NODE_IP:$node_port\033[0m"
        fi
    fi

    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
    echo -e "\033[1;37m📖 Examples:\033[0m"
    echo -e "\033[38;5;244m   sudo $APP_NAME install\033[0m"
    echo -e "\033[38;5;244m   sudo $APP_NAME core-update\033[0m"
    echo -e "\033[38;5;244m   $APP_NAME logs\033[0m"
    echo -e "\033[38;5;244m   $APP_NAME menu           # Interactive menu\033[0m"
    echo -e "\033[38;5;244m   $APP_NAME                # Same as menu\033[0m"
    echo
    echo -e "\033[38;5;8mUse '\033[38;5;15m$APP_NAME <command> --help\033[38;5;8m' for detailed command help\033[0m"
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
    echo -e "\033[38;5;8m📚 Project: \033[38;5;250mhttps://gig.ovh\033[0m"
    echo -e "\033[38;5;8m🐛 Issues: \033[38;5;250mhttps://github.com/DigneZzZ/remnawave-scripts\033[0m"
    echo -e "\033[38;5;8m💬 Support: \033[38;5;250mhttps://t.me/remnawave\033[0m"
    echo -e "\033[38;5;8m👨‍💻 Author: \033[38;5;250mDigneZzZ\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
}

# Функция для версии
show_version() {
    echo -e "\033[1;37m🚀 RemnaNode Management CLI\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    echo -e "\033[38;5;250mVersion: \033[38;5;15m$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;250mAuthor:  \033[38;5;15mDigneZzZ\033[0m"
    echo -e "\033[38;5;250mGitHub:  \033[38;5;15mhttps://github.com/DigneZzZ/remnawave-scripts\033[0m"
    echo -e "\033[38;5;250mProject: \033[38;5;15mhttps://gig.ovh\033[0m"
    echo -e "\033[38;5;250mSupport: \033[38;5;15mhttps://t.me/remnawave\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
}

main_menu() {
    while true; do
        clear
        echo -e "\033[1;37m🚀 $APP_NAME Node Management\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
        echo
        
        # Проверка статуса узла
        local menu_status="Not installed"
        local status_color="\033[38;5;244m"
        local node_port=""
        local xray_version=""
        
        if is_remnanode_installed; then
            # Получаем порт через универсальную функцию
            node_port=$(get_env_variable "NODE_PORT")
            # Fallback to old variable for backward compatibility
            if [ -z "$node_port" ]; then
                node_port=$(get_env_variable "APP_PORT")
            fi
            
            if is_remnanode_up; then
                menu_status="Running"
                status_color="\033[1;32m"
                echo -e "${status_color}✅ Node Status: RUNNING\033[0m"
                
                # Показываем информацию о подключении
                if [ -n "$node_port" ]; then
                    echo
                    echo -e "\033[1;37m🌐 Connection Information:\033[0m"
                    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;117m%s\033[0m\n" "IP Address:" "$NODE_IP"
                    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;117m%s\033[0m\n" "Port:" "$node_port"
                    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;117m%s:%s\033[0m\n" "Full URL:" "$NODE_IP" "$node_port"
                fi
                
                # Проверяем Xray-core и версию RemnaNode
                xray_version=$(get_current_xray_core_version 2>/dev/null || echo "Not installed")
                local node_version=$(get_remnanode_version 2>/dev/null || echo "unknown")
                
                echo
                echo -e "\033[1;37m⚙️  Components Status:\033[0m"
                
                # Версия RemnaNode
                printf "   \033[38;5;15m%-12s\033[0m " "RemnaNode:"
                if [ "$node_version" != "unknown" ]; then
                    echo -e "\033[1;32m✅ v$node_version\033[0m"
                else
                    echo -e "\033[38;5;244m❓ version unknown\033[0m"
                fi
                
                # Версия Xray Core
                printf "   \033[38;5;15m%-12s\033[0m " "Xray Core:"
                if [ "$xray_version" != "Not installed" ]; then
                    echo -e "\033[1;32m✅ $xray_version\033[0m"
                else
                    echo -e "\033[1;33m⚠️  Not installed\033[0m"
                fi
                
                # Показываем использование ресурсов
                echo
                echo -e "\033[1;37m💾 Resource Usage:\033[0m"
                
                local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
                local mem_info=$(free -h | grep "Mem:" 2>/dev/null)
                local mem_used=$(echo "$mem_info" | awk '{print $3}' 2>/dev/null || echo "N/A")
                local mem_total=$(echo "$mem_info" | awk '{print $2}' 2>/dev/null || echo "N/A")
                
                printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s%%\033[0m\n" "CPU Usage:" "$cpu_usage"
                printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s / %s\033[0m\n" "Memory:" "$mem_used" "$mem_total"
                
                local disk_usage=$(df -h "$APP_DIR" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "N/A")
                local disk_available=$(df -h "$APP_DIR" 2>/dev/null | tail -1 | awk '{print $4}' 2>/dev/null || echo "N/A")
                
                printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s%% used, %s available\033[0m\n" "Disk Usage:" "$disk_usage" "$disk_available"
                
                # Проверяем логи
                if [ -d "$DATA_DIR" ]; then
                    local log_files=$(find "$DATA_DIR" -name "*.log" 2>/dev/null | wc -l)
                    if [ "$log_files" -gt 0 ]; then
                        local total_log_size=$(du -sh "$DATA_DIR"/*.log 2>/dev/null | awk '{total+=$1} END {print total"K"}' | sed 's/KK/K/')
                        printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s files (%s)\033[0m\n" "Log Files:" "$log_files" "$total_log_size"
                    fi
                fi
                
            else
                menu_status="Stopped"
                status_color="\033[1;31m"
                echo -e "${status_color}❌ Node Status: STOPPED\033[0m"
                echo -e "\033[38;5;244m   Services are installed but not running\033[0m"
                echo -e "\033[38;5;244m   Use option 2 to start the node\033[0m"
            fi
        else
            echo -e "${status_color}📦 Node Status: NOT INSTALLED\033[0m"
            echo -e "\033[38;5;244m   Use option 1 to install RemnaNode\033[0m"
        fi
        
        echo
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
        echo
        echo -e "\033[1;37m🚀 Installation & Management:\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m 🛠️  Install RemnaNode"
        echo -e "   \033[38;5;15m2)\033[0m ▶️  Start node services"
        echo -e "   \033[38;5;15m3)\033[0m ⏹️  Stop node services"
        echo -e "   \033[38;5;15m4)\033[0m 🔄 Restart node services"
        echo -e "   \033[38;5;15m5)\033[0m 🗑️  Uninstall RemnaNode"
        echo
        echo -e "\033[1;37m📊 Monitoring & Logs:\033[0m"
        echo -e "   \033[38;5;15m6)\033[0m 📊 Show node status"
        echo -e "   \033[38;5;15m7)\033[0m 📋 View container logs"
        echo -e "   \033[38;5;15m8)\033[0m 📤 View Xray output logs"
        echo -e "   \033[38;5;15m9)\033[0m 📥 View Xray error logs"
        echo
        echo -e "\033[1;37m⚙️  Updates & Configuration:\033[0m"
        echo -e "   \033[38;5;15m10)\033[0m 🔄 Update RemnaNode"
        echo -e "   \033[38;5;15m11)\033[0m ⬆️  Update Xray-core"
        echo -e "   \033[38;5;15m12)\033[0m 🔄 Migrate environment variables"
        echo -e "   \033[38;5;15m13)\033[0m 📝 Edit docker-compose.yml"
        echo -e "   \033[38;5;15m14)\033[0m 🔐 Edit environment (.env)"
        echo -e "   \033[38;5;15m15)\033[0m 🔌 Show ports configuration"
        echo -e "   \033[38;5;15m16)\033[0m 🗂️  Setup log rotation"
        echo
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
        echo -e "\033[38;5;15m   0)\033[0m 🚪 Exit to terminal"
        echo
        
        # Показываем подсказки в зависимости от состояния
        case "$menu_status" in
            "Not installed")
                echo -e "\033[1;34m💡 Tip: Start with option 1 to install RemnaNode\033[0m"
                ;;
            "Stopped")
                echo -e "\033[1;34m💡 Tip: Use option 2 to start the node\033[0m"
                ;;
            "Running")
                if [ "$xray_version" = "Not installed" ]; then
                    echo -e "\033[1;34m💡 Tip: Install Xray-core with option 11 for better performance\033[0m"
                else
                    echo -e "\033[1;34m💡 Tip: Check logs (7-9) or configure log rotation (14)\033[0m"
                fi
                ;;
        esac
        
        echo -e "\033[38;5;8mRemnaNode CLI v$SCRIPT_VERSION by DigneZzZ • gig.ovh\033[0m"
        echo
        read -p "$(echo -e "\033[1;37mSelect option [0-16]:\033[0m ")" choice

        case "$choice" in
            1) install_command; read -p "Press Enter to continue..." ;;
            2) up_command; read -p "Press Enter to continue..." ;;
            3) down_command; read -p "Press Enter to continue..." ;;
            4) restart_command; read -p "Press Enter to continue..." ;;
            5) uninstall_command; read -p "Press Enter to continue..." ;;
            6) status_command; read -p "Press Enter to continue..." ;;
            7) logs_command; read -p "Press Enter to continue..." ;;
            8) xray_log_out; read -p "Press Enter to continue..." ;;
            9) xray_log_err; read -p "Press Enter to continue..." ;;
            10) update_command; read -p "Press Enter to continue..." ;;
            11) update_core_command; read -p "Press Enter to continue..." ;;
            12) migrate_env_variables; read -p "Press Enter to continue..." ;;
            13) edit_command; read -p "Press Enter to continue..." ;;
            14) edit_env_command; read -p "Press Enter to continue..." ;;
            15) ports_command; read -p "Press Enter to continue..." ;;
            16) setup_log_rotation; read -p "Press Enter to continue..." ;;
            0) clear; exit 0 ;;
            *) 
                echo -e "\033[1;31m❌ Invalid option!\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Главная обработка команд
case "${COMMAND:-menu}" in
    install) install_command ;;
    install-script) install_script_command ;;
    uninstall) uninstall_command ;;
    uninstall-script) uninstall_script_command ;;
    up) up_command ;;
    down) down_command ;;
    restart) restart_command ;;
    status) status_command ;;
    logs) logs_command ;;
    xray-log-out) xray_log_out ;;
    xray-log-err) xray_log_err ;;
    update) update_command ;;
    core-update) update_core_command ;;
    migrate) migrate_env_variables ;;
    edit) edit_command ;;
    edit-env) edit_env_command ;;
    ports) ports_command ;;
    setup-logs) setup_log_rotation ;;
    enable-socket) enable_socket_command ;;
    help|--help|-h) usage ;;
    version|--version|-v) show_version ;;
    menu) main_menu ;;
    "") main_menu ;;
    *) 
        echo -e "\033[1;31m❌ Unknown command: $COMMAND\033[0m"
        echo -e "\033[38;5;244mUse '\033[38;5;15m$APP_NAME help\033[38;5;244m' for available commands\033[0m"
        exit 1
        ;;
esac
