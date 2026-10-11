#!/bin/bash
# Version: 1.0.0
# RemnaNode Xray-core Updater
# Created by DigneZzZ

echo -e "\e[1m\e[33mOur community: https://gig.ovh\n\e[0m"
sleep 2s

echo -e "\e[1m\e[33mThis script installs/updates Xray-core for RemnaNode\n\e[0m"
sleep 1


# Color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Colored output function

colorized_echo() {
    local color=$1
    local text=$2
    local style=${3:-0}

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

# System architecture detection
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

# Find RemnaNode directory
find_remnanode_directory() {
    local possible_paths=(
        "/opt/remnanode"
        "/opt/remna"
        "/var/lib/remnanode"
        "/var/lib/remna"
    )
    
    colorized_echo blue "Searching for RemnaNode directory..."
    
    for path in "${possible_paths[@]}"; do
        if [ -d "$path" ] && [ -f "$path/docker-compose.yml" ]; then
            REMNANODE_DIR="$path"
            colorized_echo green "Found RemnaNode directory: $REMNANODE_DIR"
            return 0
        fi
    done
    
    local found_dirs=$(find / -type d -name "*remna*" -exec test -f "{}/docker-compose.yml" \; -print 2>/dev/null)
    
    if [ -n "$found_dirs" ]; then
        local first_dir=$(echo "$found_dirs" | head -1)
        REMNANODE_DIR="$first_dir"
        colorized_echo green "Found RemnaNode directory: $REMNANODE_DIR"
        return 0
    fi
    
    colorized_echo red "RemnaNode directory not found!"
    colorized_echo yellow "Make sure RemnaNode is installed and contains docker-compose.yml file"
    exit 1
}

# Get current Xray version
get_current_xray_core_version() {
    local xray_file="/var/lib/remnanode/xray"
    if [ -f "$xray_file" ]; then
        version_output=$("$xray_file" -version 2>/dev/null)
        if [ $? -eq 0 ]; then
            version=$(echo "$version_output" | head -n1 | awk '{print $2}')
            echo "$version"
            return
        fi
    fi
    echo "Not installed"
}

# Version validation via GitHub API
validate_version() {
    local version="$1"
    local response=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/tags/$version")
    if echo "$response" | grep -q '"message": "Not Found"'; then
        echo "invalid"
    else
        echo "valid"
    fi
}

# Fetch version list from GitHub
fetch_versions() {
    local include_prereleases="$1"
    colorized_echo blue "🔍 Fetching Xray-core version list..."
    
    if [ "$include_prereleases" = true ]; then
        colorized_echo cyan "   Including pre-releases..."
        latest_releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=8")
    else
        colorized_echo cyan "   Stable releases only..."
        # XTLS помечает большинство релизов как pre-release: последний
        # стабильный тег может находиться глубоко в списке (15+ записей).
        # При маленькой per_page в выборку попадают только pre-release, и
        # фильтр ниже не находит ни одной стабильной версии.
        latest_releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=100")
    fi
    
    if [ -z "$latest_releases" ] || echo "$latest_releases" | grep -q '"message":'; then
        colorized_echo red "❌ Failed to fetch version list. Check your internet connection."
        return 1
    fi
    
    versions=()
    prereleases=()
    
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
            
            if [ "$include_prereleases" = false ] && [ "$is_prerelease" = "true" ]; then
                current_version=""
                continue
            fi
            
            if [ -n "$current_version" ] && [ $count -lt $max_count ]; then
                versions+=("$current_version")
                prereleases+=("$is_prerelease")
                ((count++))
            fi
            current_version=""
        fi
    done < "$temp_file"
    
    rm "$temp_file"
    
    if [ ${#versions[@]} -eq 0 ]; then
        colorized_echo red "❌ No versions found."
        return 1
    fi
    
    colorized_echo green "✅ Found ${#versions[@]} versions"
    return 0
}

# Interactive version selection menu
print_menu() {
    clear
    
    echo -e "\033[1;37m⚡ Xray-core Installer for RemnaNode\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
    echo
    
    current_version=$(get_current_xray_core_version)
    echo -e "\033[1;37m🌐 Current Status:\033[0m"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Xray Version:" "$current_version"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Architecture:" "$ARCH"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "RemnaNode:" "$REMNANODE_DIR"
    echo
    
    echo -e "\033[1;37m🎯 Release Mode:\033[0m"
    if [ "$show_prereleases" = true ]; then
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m \033[38;5;244m(Including pre-releases)\033[0m\n" "Current:" "All releases"
    else
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m \033[1;37m(Stable only)\033[0m\n" "Current:" "Stable releases"
    fi
    echo
    
    echo -e "\033[1;37m🚀 Available Versions:\033[0m"
    for ((i=0; i<${#versions[@]}; i++)); do
        local version_num=$((i + 1))
        local version_name="${versions[i]}"
        local is_prerelease="${prereleases[i]}"
        
        if [ "$is_prerelease" = "true" ]; then
            echo -e "   \033[38;5;15m${version_num}:\033[0m \033[38;5;250m${version_name}\033[0m \033[38;5;244m(Pre-release)\033[0m"
        elif [ $i -eq 0 ] && [ "$is_prerelease" = "false" ]; then
            echo -e "   \033[38;5;15m${version_num}:\033[0m \033[38;5;250m${version_name}\033[0m \033[1;37m(Latest stable)\033[0m"
        else
            echo -e "   \033[38;5;15m${version_num}:\033[0m \033[38;5;250m${version_name}\033[0m \033[38;5;8m(Stable)\033[0m"
        fi
    done
    echo
    
    echo -e "\033[1;37m🔧 Options:\033[0m"
    printf "   \033[38;5;15m%-3s\033[0m %s\n" "M:" "📝 Enter version manually"
    if [ "$show_prereleases" = true ]; then
        printf "   \033[38;5;15m%-3s\033[0m %s\n" "S:" "🔒 Show stable releases only"
    else
        printf "   \033[38;5;15m%-3s\033[0m %s\n" "A:" "🧪 Show all releases (including pre-releases)"
    fi
    printf "   \033[38;5;15m%-3s\033[0m %s\n" "R:" "🔄 Refresh version list"
    printf "   \033[38;5;15m%-3s\033[0m %s\n" "Q:" "❌ Exit installer"
    echo
    
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
    echo -e "\033[1;37m📖 Usage:\033[0m"
    echo -e "   Select number \033[38;5;15m(1-${#versions[@]})\033[0m, \033[38;5;15mM\033[0m for manual input, \033[38;5;15mA/S\033[0m to toggle releases, or \033[38;5;15mQ\033[0m to exit"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
}

# Интерактивный выбор и загрузка Xray-core
get_xray_core() {
    identify_the_operating_system_and_architecture
    clear
    
    local show_prereleases=false
    
    if ! fetch_versions "$show_prereleases"; then
        # Стабильных релизов может не оказаться в выборке GitHub (XTLS помечает
        # pre-release почти все релизы). Не вылетаем, а откатываемся на показ
        # всех релизов — иначе до меню с опцией A вообще не добраться.
        colorized_echo yellow "   Falling back to all releases (incl. pre-releases)..."
        show_prereleases=true
        fetch_versions "$show_prereleases" || exit 1
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
                colorized_echo yellow "⚠️  Selected pre-release version: $selected_version"
                colorized_echo cyan "   Pre-releases may contain bugs and are not recommended for production."
                read -p "Are you sure you want to continue? (y/n): " -r confirm_prerelease
                if [[ ! $confirm_prerelease =~ ^[Yy]$ ]]; then
                    colorized_echo red "❌ Installation cancelled."
                    continue
                fi
            else
                colorized_echo green "✅ Selected stable version: $selected_version"
            fi
            break
            
        elif [ "$choice" == "M" ] || [ "$choice" == "m" ]; then
            echo
            colorized_echo blue "📝 Manual version input:"
            while true; do
                echo -n -e "\033[38;5;8mEnter version (e.g., v1.8.4): \033[0m"
                read custom_version
                
                if [ -z "$custom_version" ]; then
                    colorized_echo red "❌ Version cannot be empty. Try again."
                    continue
                fi
                
                colorized_echo blue "🔍 Checking version $custom_version..."
                if [ "$(validate_version "$custom_version")" == "valid" ]; then
                    selected_version="$custom_version"
                    colorized_echo green "✅ Version $custom_version found!"
                    break 2
                else
                    colorized_echo red "❌ Version $custom_version not found. Try again."
                    colorized_echo cyan "   Hint: Check https://github.com/XTLS/Xray-core/releases"
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
            
        elif [ "$choice" == "Q" ] || [ "$choice" == "q" ]; then
            echo
            colorized_echo red "❌ Installation cancelled by user."
            exit 0
            
        else
            echo
            colorized_echo red "❌ Invalid choice: '$choice'"
            colorized_echo cyan "   Enter number from 1 to ${#versions[@]}, M for manual input, A/S to toggle releases, R to refresh, or Q to exit."
            echo
            echo -n -e "\033[38;5;8mPress Enter to continue...\033[0m"
            read
        fi
    done
    
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    colorized_echo blue "🚀 Starting installation"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    
    if ! dpkg -s unzip >/dev/null 2>&1; then
        colorized_echo blue "📦 Installing required packages..."
        apt update -qq >/dev/null 2>&1
        apt install -y unzip >/dev/null 2>&1
        colorized_echo green "✅ Packages installed successfully"
    fi
    
    mkdir -p /var/lib/remnanode
    cd /var/lib/remnanode
    
    xray_filename="Xray-linux-$ARCH.zip"
    xray_download_url="https://github.com/XTLS/Xray-core/releases/download/${selected_version}/${xray_filename}"
    
    colorized_echo blue "📥 Downloading Xray-core $selected_version..."
    colorized_echo cyan "   URL: $xray_download_url"
    
    if wget "${xray_download_url}" -q --show-progress; then
        colorized_echo green "✅ Download completed successfully"
    else
        colorized_echo red "❌ Download error!"
        colorized_echo cyan "   Check internet connection or try another version."
        exit 1
    fi
    
    colorized_echo blue "📦 Extracting Xray-core..."
    if unzip -o "${xray_filename}" -d "/var/lib/remnanode" >/dev/null 2>&1; then
        colorized_echo green "✅ Extraction completed successfully"
        
        # Set permissions for executable
        chmod +x "/var/lib/remnanode/xray"
        
        # Check what files were extracted
        colorized_echo blue "📋 Extracted files:"
        if [ -f "/var/lib/remnanode/xray" ]; then
            colorized_echo green "   ✅ xray executable"
        fi
        if [ -f "/var/lib/remnanode/geoip.dat" ]; then
            colorized_echo green "   ✅ geoip.dat"
        fi
        if [ -f "/var/lib/remnanode/geosite.dat" ]; then
            colorized_echo green "   ✅ geosite.dat"
        fi
    else
        colorized_echo red "❌ Extraction error!"
        colorized_echo cyan "   The downloaded file may be corrupted."
        exit 1
    fi
    
    rm "${xray_filename}"
    
    colorized_echo green "🎉 Xray-core $selected_version installation completed!"
}

# Backup management
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

# Working with indentation in docker-compose.yml
get_service_property_indentation() {
    local compose_file="$1"
    local base_indent=""
    local property_indent=""
    
    if [ -f "$compose_file" ]; then
        local service_line=$(grep -E "^\s*[a-zA-Z0-9_-]*remna[a-zA-Z0-9_-]*:" "$compose_file" | head -1)
        if [ -n "$service_line" ]; then
            base_indent=$(echo "$service_line" | sed 's/[a-zA-Z0-9_-]*remna[a-zA-Z0-9_-]*:.*//' | grep -o '^[[:space:]]*')
        fi
        
        local in_remna_service=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*$ ]]; then
                local current_service=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/:[[:space:]]*$//')
                if [[ "$current_service" =~ remna ]]; then
                    in_remna_service=true
                else
                    in_remna_service=false
                fi
                continue
            fi
            
            if [ "$in_remna_service" = true ]; then
                if [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]] ]] && [[ ! "$line" =~ ^[[:space:]]*- ]]; then
                    property_indent=$(echo "$line" | sed 's/[a-zA-Z0-9_-]*:.*//' | grep -o '^[[:space:]]*')
                    break
                fi
            fi
        done < "$compose_file"
    fi
    
    if [ -z "$property_indent" ]; then
        if [ -z "$base_indent" ]; then
            base_indent="  "
        fi
        property_indent="${base_indent}  "
    fi
    
    echo "$property_indent"
}

escape_for_sed() {
    local text="$1"
    echo "$text" | sed 's/[]\.*^$()+?{|[]/\\&/g' | sed 's/\t/\\t/g'
}

# Update docker-compose.yml configuration
update_docker_compose() {
    local compose_file="$REMNANODE_DIR/docker-compose.yml"
    local xray_file="/var/lib/remnanode/xray"
    local geoip_file="/var/lib/remnanode/geoip.dat"
    local geosite_file="/var/lib/remnanode/geosite.dat"
    
    if [ ! -f "$compose_file" ]; then
        colorized_echo red "docker-compose.yml file not found in $REMNANODE_DIR"
        exit 1
    fi
    
    colorized_echo blue "Creating backup of docker-compose.yml..."
    backup_file=$(create_backup "$compose_file")
    if [ $? -eq 0 ]; then
        colorized_echo green "Backup created: $backup_file"
    else
        colorized_echo red "Failed to create backup"
        exit 1
    fi
    
    local service_indent=$(get_service_property_indentation "$compose_file")
    local indent_type=""
    if [[ "$service_indent" =~ $'\t' ]]; then
        indent_type=$'\t'
    else
        indent_type="  "
    fi
    local volume_item_indent="${service_indent}${indent_type}"
    
    local escaped_service_indent=$(escape_for_sed "$service_indent")
    local escaped_volume_item_indent=$(escape_for_sed "$volume_item_indent")

    if grep -q "^${escaped_service_indent}volumes:" "$compose_file"; then
        # Remove existing xray-related volumes using # as delimiter to avoid issues with / in paths
        sed -i "\#$xray_file#d" "$compose_file"
        sed -i "\#geoip\.dat#d" "$compose_file"
        sed -i "\#geosite\.dat#d" "$compose_file"
        
        # Create temporary file with volume mounts
        temp_volumes=$(mktemp)
        echo "${volume_item_indent}- $xray_file:/usr/local/bin/xray" > "$temp_volumes"
        if [ -f "$geoip_file" ]; then
            echo "${volume_item_indent}- $geoip_file:/usr/local/share/xray/geoip.dat" >> "$temp_volumes"
        fi
        if [ -f "$geosite_file" ]; then
            echo "${volume_item_indent}- $geosite_file:/usr/local/share/xray/geosite.dat" >> "$temp_volumes"
        fi
        
        # Insert volumes after the volumes: line
        sed -i "/^${escaped_service_indent}volumes:/r $temp_volumes" "$compose_file"
        rm "$temp_volumes"
        colorized_echo green "Updated Xray volumes in existing volumes section"
        
    elif grep -q "^${escaped_service_indent}# volumes:" "$compose_file"; then
        sed -i "s|^${escaped_service_indent}# volumes:|${service_indent}volumes:|g" "$compose_file"
        
        # Create temporary file with volume mounts
        temp_volumes=$(mktemp)
        echo "${volume_item_indent}- $xray_file:/usr/local/bin/xray" > "$temp_volumes"
        if [ -f "$geoip_file" ]; then
            echo "${volume_item_indent}- $geoip_file:/usr/local/share/xray/geoip.dat" >> "$temp_volumes"
        fi
        if [ -f "$geosite_file" ]; then
            echo "${volume_item_indent}- $geosite_file:/usr/local/share/xray/geosite.dat" >> "$temp_volumes"
        fi
        
        # Insert volumes after the volumes: line
        sed -i "/^${escaped_service_indent}volumes:/r $temp_volumes" "$compose_file"
        rm "$temp_volumes"
        colorized_echo green "Uncommented volumes section and added Xray volumes"
        
    else
        # Create temporary file with volumes section
        temp_volumes=$(mktemp)
        echo "${service_indent}volumes:" > "$temp_volumes"
        echo "${volume_item_indent}- $xray_file:/usr/local/bin/xray" >> "$temp_volumes"
        if [ -f "$geoip_file" ]; then
            echo "${volume_item_indent}- $geoip_file:/usr/local/share/xray/geoip.dat" >> "$temp_volumes"
        fi
        if [ -f "$geosite_file" ]; then
            echo "${volume_item_indent}- $geosite_file:/usr/local/share/xray/geosite.dat" >> "$temp_volumes"
        fi
        
        # Insert volumes section after restart: always
        sed -i "/^${escaped_service_indent}restart: always/r $temp_volumes" "$compose_file"
        rm "$temp_volumes"
        colorized_echo green "Added new volumes section with Xray volumes"
    fi
    
    colorized_echo green "docker-compose.yml configuration updated"
    
    # Show what was mounted
    colorized_echo blue "📋 Mounted volumes:"
    colorized_echo green "   ✅ xray → /usr/local/bin/xray"
    if [ -f "$geoip_file" ]; then
        colorized_echo green "   ✅ geoip.dat → /usr/local/share/xray/geoip.dat"
    fi
    if [ -f "$geosite_file" ]; then
        colorized_echo green "   ✅ geosite.dat → /usr/local/share/xray/geosite.dat"
    fi
}

# Restart RemnaNode
restart_remnanode() {
    if ! command -v docker >/dev/null 2>&1; then
        colorized_echo red "Docker not found!"
        exit 1
    fi
    
    local compose_cmd=""
    if docker compose >/dev/null 2>&1; then
        compose_cmd='docker compose'
    elif docker-compose >/dev/null 2>&1; then
        compose_cmd='docker-compose'
    else
        colorized_echo red "Docker Compose not found!"
        exit 1
    fi
    
    local compose_file="$REMNANODE_DIR/docker-compose.yml"
    local app_name=$(basename "$REMNANODE_DIR")
    
    colorized_echo blue "Restarting RemnaNode..."
    
    cd "$REMNANODE_DIR"
    
    $compose_cmd -f "$compose_file" -p "$app_name" down >/dev/null 2>&1
    
    if $compose_cmd -f "$compose_file" -p "$app_name" up -d --remove-orphans >/dev/null 2>&1; then
        colorized_echo green "✅ RemnaNode restarted successfully"
    else
        colorized_echo red "❌ RemnaNode restart error"
        colorized_echo yellow "Restoring backup..."
        if restore_backup "$backup_file" "$compose_file"; then
            colorized_echo green "Backup restored"
        fi
        exit 1
    fi
}

# Main script logic
main() {
    find_remnanode_directory
    get_xray_core
    
    colorized_echo blue "Updating docker-compose.yml configuration..."
    update_docker_compose
    restart_remnanode
    
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    colorized_echo green "🎉 Xray-core update completed!"
    
    echo
    colorized_echo blue "📋 Installation details:"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Version:" "$selected_version"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Architecture:" "$ARCH"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Install path:" "/var/lib/remnanode/xray"
    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "RemnaNode:" "$REMNANODE_DIR"
    
    echo
    colorized_echo blue "🔍 Checking installation..."
    if installed_version=$("/var/lib/remnanode/xray" -version 2>/dev/null | head -n1 | awk '{print $2}'); then
        colorized_echo green "✅ Xray-core working correctly"
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Running version:" "$installed_version"
    else
        colorized_echo yellow "⚠️  Installation completed, but verification failed"
        colorized_echo cyan "   Binary file may be incompatible with your system"
    fi
    
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    colorized_echo cyan "💡 RemnaNode restarted with new Xray-core version"
    colorized_echo cyan "💡 Backup saved: $backup_file"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
}

main "$@"
