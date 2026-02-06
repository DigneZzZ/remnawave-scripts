#!/usr/bin/env bash
# Remnawave Panel Installation Script
# This script installs and manages Remnawave Panel
# VERSION=5.8.4

SCRIPT_VERSION="5.8.4"
BACKUP_SCRIPT_VERSION="1.3.0"  # Версия backup скрипта создаваемого Schedule функцией

if [ $# -gt 0 ] && [ "$1" = "@" ]; then
    shift  
fi

if [ $# -gt 0 ]; then
    COMMAND="$1"
    shift
fi

SCRIPT_URL="https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/remnawave.sh"  # Update with actual URL

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
                if [[ -n "$2" && "$2" =~ remnawave\.sh$ ]]; then
                    SCRIPT_URL="$2"
                    shift 2
                else
                    echo "Error: --source parameter must be a URL to a remnawave.sh file."
                    exit 1
                fi
            else
                echo "Error: --source parameter is only allowed with 'install-script' command."
                exit 1
            fi
        ;;
        --compress|-c|--data-only|--include-configs|-h|--help)
            # Аргументы команды backup - не обрабатываем здесь, пропускаем
            break
        ;;
        *)  
            break
        ;;  
    esac  
done


# Fetch IP address from ipinfo.io API
NODE_IP=$(curl -s -4 ifconfig.io)

# If the IPv4 retrieval is empty, attempt to retrieve the IPv6 address
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(curl -s -6 ifconfig.io)
fi

# Set default app name if not provided
if [[ "$COMMAND" == "install" || "$COMMAND" == "install-script" ]] && [ -z "$APP_NAME" ]; then
    APP_NAME="remnawave"
fi
# Set script name if APP_NAME is not set
if [ -z "$APP_NAME" ]; then
    SCRIPT_NAME=$(basename "$0")
    APP_NAME="${SCRIPT_NAME%.*}"
fi

INSTALL_DIR="/opt"
APP_DIR="$INSTALL_DIR/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"
SUB_ENV_FILE="$APP_DIR/.env.subscription"
BACKUP_CONFIG_FILE="$APP_DIR/backup-config.json"
BACKUP_SCRIPT_FILE="$APP_DIR/backup-scheduler.sh"
BACKUP_LOG_FILE="$APP_DIR/logs/backup.log"
LANG_CONFIG_FILE="$APP_DIR/.menu-lang"

# ===== LOCALIZATION SYSTEM =====

# Default language
MENU_LANG="en"

# Load saved language preference
load_menu_language() {
    if [ -f "$LANG_CONFIG_FILE" ]; then
        local saved_lang=$(cat "$LANG_CONFIG_FILE" 2>/dev/null | tr -d '[:space:]')
        if [ "$saved_lang" = "ru" ] || [ "$saved_lang" = "en" ]; then
            MENU_LANG="$saved_lang"
        fi
    fi
}

# Save language preference
save_menu_language() {
    local lang="$1"
    mkdir -p "$(dirname "$LANG_CONFIG_FILE")" 2>/dev/null
    echo "$lang" > "$LANG_CONFIG_FILE" 2>/dev/null
    MENU_LANG="$lang"
}

# Get localized string
L() {
    local key="$1"
    local var_name="L_${MENU_LANG}_${key}"
    echo "${!var_name:-$key}"
}

# ===== ENGLISH STRINGS =====
# Main Menu
L_en_MENU_TITLE="Main Menu"
L_en_MENU_STATUS_MONITORING="Status & Monitoring"
L_en_MENU_SERVICES_CONTROL="Services Control"
L_en_MENU_REVERSE_PROXY="Reverse Proxy"
L_en_MENU_SUBSCRIPTION="Subscription Page"
L_en_MENU_BACKUP="Backup & Restore"
L_en_MENU_INSTALLATION="Installation"
L_en_MENU_ADVANCED="Advanced"
L_en_MENU_EXIT="Exit to terminal"
L_en_MENU_SELECT="Select option"
L_en_MENU_LANG_SWITCH="Language: English"

# Status & Monitoring submenu
L_en_SUB_STATUS="Services status"
L_en_SUB_LOGS="View logs"
L_en_SUB_HEALTH="Health check"
L_en_SUB_MONITOR="Performance monitor"
L_en_SUB_BACK="Back to main menu"

# Services Control submenu
L_en_SVC_START="Start all services"
L_en_SVC_STOP="Stop all services"
L_en_SVC_RESTART="Restart all services"
L_en_SVC_TITLE="Services Control"

# Installation submenu
L_en_INST_INSTALL="Install Remnawave panel"
L_en_INST_UPDATE="Update to latest version"
L_en_INST_UNINSTALL="Remove panel completely"
L_en_INST_TITLE="Installation & Updates"

# Backup submenu
L_en_BAK_MANUAL="Manual backup"
L_en_BAK_SCHEDULE="Scheduled backups"
L_en_BAK_RESTORE="Restore from backup"

# Caddy
L_en_CADDY_MANAGEMENT="Caddy management"
L_en_CADDY_INSTALL="Install Caddy reverse proxy"
L_en_CADDY_RUNNING="Running"
L_en_CADDY_STOPPED="Stopped"
L_en_CADDY_TITLE="Caddy Reverse Proxy Management"
L_en_CADDY_STATUS="Current Status"
L_en_CADDY_CONTAINER="Container"
L_en_CADDY_MODE="Mode"
L_en_CADDY_MODE_SIMPLE="Simple"
L_en_CADDY_MODE_SECURE="Secure (with auth)"
L_en_CADDY_PANEL="Panel"
L_en_CADDY_SUBSCRIPTION="Subscription"
L_en_CADDY_ACTIONS="Actions"
L_en_CADDY_SHOW_STATUS="Show detailed status"
L_en_CADDY_START="Start Caddy"
L_en_CADDY_STOP="Stop Caddy"
L_en_CADDY_RESTART="Restart Caddy"
L_en_CADDY_LOGS="View logs"
L_en_CADDY_EDIT="Edit Caddyfile"
L_en_CADDY_RESET_PASS="Reset admin password"
L_en_CADDY_RESET_SECURE_ONLY="Reset admin password (Secure mode only)"
L_en_CADDY_UNINSTALL="Uninstall Caddy"
L_en_CADDY_NOT_INSTALLED="Not installed"

# Advanced
L_en_ADV_EDIT="Edit configuration files"
L_en_ADV_SHELL="Access container shell"
L_en_ADV_PM2="PM2 process monitor"

# Panel Status
L_en_PANEL_RUNNING="Panel Status: RUNNING"
L_en_PANEL_STOPPED="Panel Status: STOPPED"
L_en_PANEL_NOT_INSTALLED="Panel Status: NOT INSTALLED"
L_en_PANEL_VERSION="Version"
L_en_PANEL_ACCESS_URLS="Access URLs"
L_en_PANEL_ADMIN="Admin Panel"
L_en_PANEL_SUBSCRIPTIONS="Subscriptions"
L_en_SERVICES_STATUS="Services Status"
L_en_RESOURCE_USAGE="Resource Usage"
L_en_BACKUP_STATUS="Backup Status"
L_en_INVALID_OPTION="Invalid option!"
L_en_PRESS_ENTER="Press Enter to continue..."

# Standalone Subpage
L_en_STANDALONE_TITLE="Standalone Subscription-Page"
L_en_STANDALONE_RUNNING="Subscription-Page: Running"
L_en_STANDALONE_STOPPED="Subscription-Page: Stopped"
L_en_STANDALONE_REMOTE_PANEL="Remote Panel"
L_en_STANDALONE_CONFIG_TOKEN="Configure API Token"
L_en_STANDALONE_EDIT_ENV="Edit .env.subscription"
L_en_STANDALONE_UPDATE="Update Container"
L_en_STANDALONE_UNINSTALL="Uninstall"

# ===== RUSSIAN STRINGS =====
# Main Menu
L_ru_MENU_TITLE="Главное меню"
L_ru_MENU_STATUS_MONITORING="Статус и мониторинг"
L_ru_MENU_SERVICES_CONTROL="Управление сервисами"
L_ru_MENU_REVERSE_PROXY="Reverse Proxy"
L_ru_MENU_SUBSCRIPTION="Страница подписки"
L_ru_MENU_BACKUP="Бэкап и восстановление"
L_ru_MENU_INSTALLATION="Установка"
L_ru_MENU_ADVANCED="Дополнительно"
L_ru_MENU_EXIT="Выход"
L_ru_MENU_SELECT="Выберите опцию"
L_ru_MENU_LANG_SWITCH="Язык: Русский"

# Status & Monitoring submenu
L_ru_SUB_STATUS="Статус сервисов"
L_ru_SUB_LOGS="Просмотр логов"
L_ru_SUB_HEALTH="Диагностика"
L_ru_SUB_MONITOR="Монитор производительности"
L_ru_SUB_BACK="Назад в главное меню"

# Services Control submenu
L_ru_SVC_START="Запустить все сервисы"
L_ru_SVC_STOP="Остановить все сервисы"
L_ru_SVC_RESTART="Перезапустить все сервисы"
L_ru_SVC_TITLE="Управление сервисами"

# Installation submenu
L_ru_INST_INSTALL="Установить панель Remnawave"
L_ru_INST_UPDATE="Обновить до последней версии"
L_ru_INST_UNINSTALL="Удалить панель полностью"
L_ru_INST_TITLE="Установка и обновление"

# Backup submenu
L_ru_BAK_MANUAL="Ручной бэкап"
L_ru_BAK_SCHEDULE="Автоматические бэкапы"
L_ru_BAK_RESTORE="Восстановить из бэкапа"

# Caddy
L_ru_CADDY_MANAGEMENT="Управление Caddy"
L_ru_CADDY_INSTALL="Установить Caddy reverse proxy"
L_ru_CADDY_RUNNING="Работает"
L_ru_CADDY_STOPPED="Остановлен"
L_ru_CADDY_TITLE="Управление Caddy Reverse Proxy"
L_ru_CADDY_STATUS="Текущий статус"
L_ru_CADDY_CONTAINER="Контейнер"
L_ru_CADDY_MODE="Режим"
L_ru_CADDY_MODE_SIMPLE="Простой"
L_ru_CADDY_MODE_SECURE="Защищённый (с авторизацией)"
L_ru_CADDY_PANEL="Панель"
L_ru_CADDY_SUBSCRIPTION="Подписки"
L_ru_CADDY_ACTIONS="Действия"
L_ru_CADDY_SHOW_STATUS="Показать детальный статус"
L_ru_CADDY_START="Запустить Caddy"
L_ru_CADDY_STOP="Остановить Caddy"
L_ru_CADDY_RESTART="Перезапустить Caddy"
L_ru_CADDY_LOGS="Просмотр логов"
L_ru_CADDY_EDIT="Редактировать Caddyfile"
L_ru_CADDY_RESET_PASS="Сбросить пароль админа"
L_ru_CADDY_RESET_SECURE_ONLY="Сброс пароля (только Secure режим)"
L_ru_CADDY_UNINSTALL="Удалить Caddy"
L_ru_CADDY_NOT_INSTALLED="Не установлен"

# Advanced
L_ru_ADV_EDIT="Редактировать конфиги"
L_ru_ADV_SHELL="Доступ к контейнеру"
L_ru_ADV_PM2="PM2 монитор"

# Panel Status
L_ru_PANEL_RUNNING="Статус панели: РАБОТАЕТ"
L_ru_PANEL_STOPPED="Статус панели: ОСТАНОВЛЕНА"
L_ru_PANEL_NOT_INSTALLED="Статус панели: НЕ УСТАНОВЛЕНА"
L_ru_PANEL_VERSION="Версия"
L_ru_PANEL_ACCESS_URLS="URL доступа"
L_ru_PANEL_ADMIN="Админ-панель"
L_ru_PANEL_SUBSCRIPTIONS="Подписки"
L_ru_SERVICES_STATUS="Статус сервисов"
L_ru_RESOURCE_USAGE="Использование ресурсов"
L_ru_BACKUP_STATUS="Статус бэкапов"
L_ru_INVALID_OPTION="Неверная опция!"
L_ru_PRESS_ENTER="Нажмите Enter для продолжения..."

# Standalone Subpage (Russian)
L_ru_STANDALONE_TITLE="Standalone Страница подписки"
L_ru_STANDALONE_RUNNING="Страница подписки: Запущена"
L_ru_STANDALONE_STOPPED="Страница подписки: Остановлена"
L_ru_STANDALONE_REMOTE_PANEL="Удалённая панель"
L_ru_STANDALONE_CONFIG_TOKEN="Настроить API токен"
L_ru_STANDALONE_EDIT_ENV="Редактировать .env.subscription"
L_ru_STANDALONE_UPDATE="Обновить контейнер"
L_ru_STANDALONE_UNINSTALL="Удалить"

# Load language on script start
load_menu_language

# ===== BACKUP SCRIPT VERSION CHECK FUNCTIONS =====

# ===== PANEL VERSION FUNCTIONS =====

get_panel_version() {
    local container_name="${APP_NAME:-remnawave}"
    
    # Проверяем что контейнер запущен
    if ! docker exec "$container_name" echo "test" >/dev/null 2>&1; then
        # Пробуем с явным именем контейнера
        container_name="remnawave"
        if ! docker exec "$container_name" echo "test" >/dev/null 2>&1; then
            echo "unknown"
            return 1
        fi
    fi
    
    # Способ 1: через cat и jq (наиболее надежный)
    local version=$(docker exec "$container_name" cat package.json 2>/dev/null | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$version" ]; then
        # Способ 2: через awk
        version=$(docker exec "$container_name" awk -F'"' '/"version"/{print $4; exit}' package.json 2>/dev/null)
    fi
    
    if [ -z "$version" ]; then
        # Способ 3: через sed
        version=$(docker exec "$container_name" sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' package.json 2>/dev/null | head -1)
    fi
    
    # Проверяем что версия не пустая и не null
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        echo "unknown"
        return 1
    fi
    
    echo "$version"
    return 0
}

validate_panel_version_compatibility() {
    local backup_version="$1"
    local current_version="$2"
    
    # Если одна из версий неизвестна - предупреждение
    if [ "$backup_version" = "unknown" ] || [ "$current_version" = "unknown" ]; then
        return 2  # Warning - unknown version
    fi
    
    # Если версии совпадают - OK
    if [ "$backup_version" = "$current_version" ]; then
        return 0  # Compatible
    fi
    
    # Проверяем major.minor версии (игнорируем patch)
    local backup_major_minor=$(echo "$backup_version" | cut -d'.' -f1,2)
    local current_major_minor=$(echo "$current_version" | cut -d'.' -f1,2)
    
    if [ "$backup_major_minor" = "$current_major_minor" ]; then
        return 1  # Minor incompatibility (different patch versions)
    fi
    
    return 3  # Major incompatibility
}

# ===== END PANEL VERSION FUNCTIONS =====

# ===== ENV MIGRATION FUNCTIONS =====

migrate_deprecated_env_variables() {
    if [ ! -f "$ENV_FILE" ]; then
        return 0  # No .env file to migrate
    fi
    
    # Список устаревших переменных из Remnawave v2.2.0
    local deprecated_vars=(
        "TELEGRAM_OAUTH_ENABLED"
        "TELEGRAM_OAUTH_ADMIN_IDS"
        "OAUTH2_GITHUB_ENABLED"
        "OAUTH2_GITHUB_CLIENT_ID"
        "OAUTH2_GITHUB_CLIENT_SECRET"
        "OAUTH2_GITHUB_ALLOWED_EMAILS"
        "OAUTH2_POCKETID_ENABLED"
        "OAUTH2_POCKETID_CLIENT_ID"
        "OAUTH2_POCKETID_CLIENT_SECRET"
        "OAUTH2_POCKETID_ALLOWED_EMAILS"
        "OAUTH2_POCKETID_PLAIN_DOMAIN"
        "OAUTH2_YANDEX_ENABLED"
        "OAUTH2_YANDEX_CLIENT_ID"
        "OAUTH2_YANDEX_CLIENT_SECRET"
        "OAUTH2_YANDEX_ALLOWED_EMAILS"
        "BRANDING_LOGO_URL"
        "BRANDING_TITLE"
    )
    
    # Проверяем наличие хотя бы одной устаревшей переменной
    local found_deprecated=false
    for var in "${deprecated_vars[@]}"; do
        if grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
            found_deprecated=true
            break
        fi
    done
    
    if [ "$found_deprecated" = false ]; then
        return 0  # Нет устаревших переменных
    fi
    
    echo
    echo -e "\033[1;36m🔄 Detected deprecated environment variables\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    echo -e "\033[38;5;250mRemnawave v2.2.0+ manages these settings via UI:\033[0m"
    for var in "${deprecated_vars[@]}"; do
        if grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
            echo -e "\033[38;5;244m  • $var\033[0m"
        fi
    done
    echo
    
    # Создаем резервную копию
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${ENV_FILE}.backup.${timestamp}"
    
    if cp "$ENV_FILE" "$backup_file" 2>/dev/null; then
        echo -e "\033[1;32m✅ Backup created: $(basename "$backup_file")\033[0m"
    else
        echo -e "\033[1;31m❌ Failed to create backup\033[0m"
        return 1
    fi
    
    # Удаляем устаревшие переменные
    local temp_file="${ENV_FILE}.tmp"
    cp "$ENV_FILE" "$temp_file"
    
    for var in "${deprecated_vars[@]}"; do
        if grep -q "^${var}=" "$temp_file" 2>/dev/null; then
            sed -i.bak "/^${var}=/d" "$temp_file" 2>/dev/null || \
            sed -i '' "/^${var}=/d" "$temp_file" 2>/dev/null
            echo -e "\033[38;5;244m  ✓ Removed: $var\033[0m"
        fi
    done
    
    # Удаляем временный .bak файл если создался
    rm -f "${temp_file}.bak" 2>/dev/null
    
    # Заменяем оригинальный файл
    if mv "$temp_file" "$ENV_FILE" 2>/dev/null; then
        echo
        echo -e "\033[1;32m🎉 Migration completed successfully!\033[0m"
        echo -e "\033[38;5;250m   Configure these settings in panel UI:\033[0m"
        echo -e "\033[38;5;244m   Settings → Authentication → Login Methods\033[0m"
        echo -e "\033[38;5;244m   Settings → Branding\033[0m"
        echo
        return 0
    else
        echo -e "\033[1;31m❌ Failed to update .env file\033[0m"
        # Восстанавливаем из бэкапа
        if [ -f "$backup_file" ]; then
            cp "$backup_file" "$ENV_FILE"
            echo -e "\033[38;5;250m   Restored from backup\033[0m"
        fi
        return 1
    fi
}

check_deprecated_env_variables() {
    if [ ! -f "$ENV_FILE" ]; then
        return 1  # No .env file
    fi
    
    local deprecated_vars=(
        "TELEGRAM_OAUTH_ENABLED"
        "TELEGRAM_OAUTH_ADMIN_IDS"
        "OAUTH2_GITHUB_ENABLED"
        "OAUTH2_POCKETID_ENABLED"
        "OAUTH2_YANDEX_ENABLED"
        "BRANDING_LOGO_URL"
        "BRANDING_TITLE"
    )
    
    for var in "${deprecated_vars[@]}"; do
        if grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
            return 0  # Found deprecated variable
        fi
    done
    
    return 1  # No deprecated variables found
}

# ===== END ENV MIGRATION FUNCTIONS =====

check_backup_script_version() {
    if [ ! -f "$BACKUP_SCRIPT_FILE" ]; then
        return 1  # Script doesn't exist
    fi
    
    # Максимально простая и безопасная проверка версии
    local script_version=""
    
    # Пробуем прочитать только первую строку с версией
    script_version=$(sed -n '1,10p' "$BACKUP_SCRIPT_FILE" 2>/dev/null | grep "^BACKUP_SCRIPT_VERSION=" 2>/dev/null | head -1 | cut -d'"' -f2 2>/dev/null)
    
    # Если sed не сработал, пробуем awk
    if [ -z "$script_version" ]; then
        script_version=$(awk '/^BACKUP_SCRIPT_VERSION=/ {gsub(/.*"/,""); gsub(/".*/,""); print; exit}' "$BACKUP_SCRIPT_FILE" 2>/dev/null)
    fi
    
    if [ -z "$script_version" ]; then
        return 2  # Old script without version or error reading
    fi
    
    if [ "$script_version" != "$BACKUP_SCRIPT_VERSION" ]; then
        return 3  # Version mismatch
    fi
    
    return 0  # Version is current
}

prompt_backup_script_update() {
    local status=$1
    
    echo -e "\033[1;33m⚠️  Backup Script Update Required\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    echo
    
    case $status in
        1)
            echo -e "\033[38;5;250m📄 Backup script not found\033[0m"
            echo -e "\033[38;5;244m   A new backup script will be created\033[0m"
            ;;
        2) 
            echo -e "\033[38;5;250m📜 Old backup script detected (no version info)\033[0m"
            echo -e "\033[38;5;244m   Script needs to be updated for compatibility\033[0m"
            ;;
        3)
            # Безопасное чтение версии с timeout
            local script_version=""
            if command -v timeout >/dev/null 2>&1; then
                script_version=$(timeout 5 head -5 "$BACKUP_SCRIPT_FILE" 2>/dev/null | grep "^BACKUP_SCRIPT_VERSION=" | cut -d'"' -f2 2>/dev/null)
            else
                script_version=$(head -5 "$BACKUP_SCRIPT_FILE" 2>/dev/null | grep "^BACKUP_SCRIPT_VERSION=" | cut -d'"' -f2 2>/dev/null)
            fi
            echo -e "\033[38;5;250m🔄 Version mismatch detected\033[0m"
            echo -e "\033[38;5;244m   Current: ${script_version:-'unknown'} → Latest: $BACKUP_SCRIPT_VERSION\033[0m"
            ;;
    esac
    
    echo
    echo -e "\033[1;37m🔧 Improvements in latest version ($BACKUP_SCRIPT_VERSION):\033[0m"
    echo -e "\033[38;5;250m   ✓ Added volume backup support (3-10x faster)\033[0m"
    echo -e "\033[38;5;250m   ✓ Three backup types: SQL dump, volume, or both\033[0m"
    echo -e "\033[38;5;250m   ✓ Automatic restore scripts included\033[0m"
    echo -e "\033[38;5;250m   ✓ Fixed Telegram file size limits (auto-split large backups)\033[0m"
    echo -e "\033[38;5;250m   ✓ Better error handling and logging\033[0m"
    echo -e "\033[38;5;250m   ✓ Enhanced restore compatibility\033[0m"
    echo
    
    if [ "$status" -eq 1 ]; then
        echo -e "\033[1;32m✅ Creating backup script automatically...\033[0m"
        return 0
    fi
    
    echo -e "\033[1;37mUpdate backup script now?\033[0m"
    echo -e "\033[38;5;244m(Recommended - old backups will continue to work)\033[0m"
    echo
    read -p "Update backup script? [Y/n]: " -r update_choice
    
    case "$update_choice" in
        [nN]|[nN][oO])
            echo -e "\033[1;33m⚠️  Using old backup script (may cause compatibility issues)\033[0m"
            return 1
            ;;
        *)
            echo -e "\033[1;32m✅ Updating backup script...\033[0m"
            return 0
            ;;
    esac
}

# ===== END BACKUP SCRIPT VERSION CHECK FUNCTIONS =====


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

check_system_requirements() {
    local errors=0
    
    # Проверяем свободное место (минимум 2GB для панели)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 2097152 ]; then  # 2GB в KB
        colorized_echo red "Error: Insufficient disk space. At least 2GB required for Remnawave Panel."
        errors=$((errors + 1))
    fi
    
    # Проверяем RAM (минимум 1GB)
    local available_ram=$(free -m | awk 'NR==2{print $7}')
    if [ "$available_ram" -lt 512 ]; then
        colorized_echo yellow "Warning: Low available RAM (${available_ram}MB). Panel performance may be affected."
    fi
    
    # Проверяем архитектуру
    local arch=$(uname -m)
    case "$arch" in
        'amd64'|'x86_64'|'aarch64'|'arm64') ;;
        *) 
            colorized_echo red "Error: Unsupported architecture: $arch"
            errors=$((errors + 1))
            ;;
    esac
    
    return $errors
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This command must be run as root."
        exit 1
    fi
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

            # Create symlink for compatibility with older scripts
            ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

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

install_remnawave_script() {  
    colorized_echo blue "Installing remnawave script"  
    TARGET_PATH="/usr/local/bin/$APP_NAME"  

    if [ ! -d "/usr/local/bin" ]; then  
        mkdir -p /usr/local/bin  
    fi  

    curl -sSL $SCRIPT_URL -o $TARGET_PATH
    colorized_echo blue "Fetched remnawave script from $SCRIPT_URL"

    chmod 755 $TARGET_PATH  

    if [ -f "$TARGET_PATH" ]; then  
        colorized_echo green "Remnawave script installed successfully at $TARGET_PATH"  
    else  
        colorized_echo red "Failed to install remnawave script at $TARGET_PATH"  
        exit 1  
    fi  
}

# Функция для проверки и восстановления поврежденного backup-config.json
validate_and_fix_backup_config() {
    if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
        return 0  # Файл не существует, будет создан позже
    fi
    
    # Проверяем наличие jq перед использованием
    if ! command -v jq >/dev/null 2>&1; then
        # jq недоступен, пропускаем валидацию
        return 0
    fi
    
    # Проверяем валидность JSON
    if ! jq . "$BACKUP_CONFIG_FILE" >/dev/null 2>&1; then
        echo -e "\033[1;33m⚠️  Backup configuration file is corrupted, attempting to recover...\033[0m"
        
        # Пытаемся извлечь токен из поврежденного файла
        local existing_token=""
        local existing_chat_id=""
        local existing_thread_id=""
        
        if [ -f "$BACKUP_CONFIG_FILE" ]; then
            # Ищем токен в поврежденном файле (может быть без кавычек)
            existing_token=$(grep -o '"bot_token":[[:space:]]*[^,}]*' "$BACKUP_CONFIG_FILE" 2>/dev/null | sed 's/"bot_token":[[:space:]]*//' | sed 's/^"//;s/"$//' || echo "")
            existing_chat_id=$(grep -o '"chat_id":[[:space:]]*[^,}]*' "$BACKUP_CONFIG_FILE" 2>/dev/null | sed 's/"chat_id":[[:space:]]*//' | sed 's/^"//;s/"$//' || echo "")
            existing_thread_id=$(grep -o '"thread_id":[[:space:]]*[^,}]*' "$BACKUP_CONFIG_FILE" 2>/dev/null | sed 's/"thread_id":[[:space:]]*//' | sed 's/^"//;s/"$//' || echo "")
            
            # Создаем бэкап поврежденного файла
            cp "$BACKUP_CONFIG_FILE" "$BACKUP_CONFIG_FILE.corrupted.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        fi
        
        # Определяем значения для восстановления
        local bot_token_value="null"
        local chat_id_value="null"
        local thread_id_value="null"
        local telegram_enabled="false"
        
        if [ -n "$existing_token" ] && [ "$existing_token" != "null" ] && [ "$existing_token" != "*" ]; then
            bot_token_value="\"$existing_token\""
            telegram_enabled="true"
        fi
        
        if [ -n "$existing_chat_id" ] && [ "$existing_chat_id" != "null" ]; then
            chat_id_value="\"$existing_chat_id\""
        fi
        
        if [ -n "$existing_thread_id" ] && [ "$existing_thread_id" != "null" ]; then
            thread_id_value="\"$existing_thread_id\""
        fi
        
        # Пересоздаем конфигурационный файл с сохраненными данными
        cat > "$BACKUP_CONFIG_FILE" << EOF
{
  "app_name": "remnawave",
  "schedule": "0 2 * * *",
  "compression": {
    "enabled": true,
    "level": 6
  },
  "retention": {
    "days": 7,
    "min_backups": 3
  },
  "include_reverse_proxy": true,
  "telegram": {
    "enabled": $telegram_enabled,
    "bot_token": $bot_token_value,
    "chat_id": $chat_id_value,
    "thread_id": $thread_id_value,
    "split_large_files": true,
    "max_file_size": 49,
    "api_server": "https://api.telegram.org",
    "use_custom_api": false
  }
}
EOF
        
        # Проверяем что новый файл валиден
        if jq . "$BACKUP_CONFIG_FILE" >/dev/null 2>&1; then
            echo -e "\033[1;32m✅ Backup configuration restored successfully\033[0m"
            if [ "$telegram_enabled" = "true" ]; then
                echo -e "\033[1;36m📱 Telegram settings were preserved from corrupted file\033[0m"
            fi
        else
            echo -e "\033[1;31m❌ Failed to restore backup configuration\033[0m"
            return 1
        fi
    fi
    
    return 0
}

ensure_backup_dirs() {
    if [ ! -d "$APP_DIR" ]; then
        echo -e "\033[1;31m❌ Remnawave is not installed!\033[0m"
        echo -e "\033[38;5;8m   Run '\033[38;5;15msudo $APP_NAME install\033[38;5;8m' first\033[0m"
        return 1
    fi
    
    # Проверяем и исправляем поврежденный конфиг если нужно
    validate_and_fix_backup_config
    
    mkdir -p "$APP_DIR/logs" 2>/dev/null || true
    mkdir -p "$APP_DIR/backups" 2>/dev/null || true
    mkdir -p "$APP_DIR/temp" 2>/dev/null || true
    
    if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
        echo -e "\033[38;5;244m   Creating default backup configuration...\033[0m"
        cat > "$BACKUP_CONFIG_FILE" << EOF
{
  "app_name": "$APP_NAME",
  "schedule": "0 2 * * *",
  "backup_type": "sql_dump",
  "compression": {
    "enabled": true,
    "level": 6
  },
  "retention": {
    "days": 7,
    "min_backups": 3
  },
  "include_reverse_proxy": true,
  "telegram": {
    "enabled": false,
    "bot_token": null,
    "chat_id": null,
    "thread_id": null,
    "split_large_files": true,
    "max_file_size": 49,
    "api_server": "https://api.telegram.org",
    "use_custom_api": false
  }
}
EOF
    fi
    
    return 0
}

ensure_rsync_installed() {
    if command -v rsync >/dev/null 2>&1; then
        return 0
    fi
    
    echo -e "\033[38;5;250m📦 Installing rsync for better backup performance...\033[0m"
    
    local install_success=false
    
    if command -v apt-get >/dev/null 2>&1; then
        if apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq rsync >/dev/null 2>&1; then
            install_success=true
        fi
    elif command -v yum >/dev/null 2>&1; then
        if yum install -y -q rsync >/dev/null 2>&1; then
            install_success=true
        fi
    elif command -v dnf >/dev/null 2>&1; then
        if dnf install -y -q rsync >/dev/null 2>&1; then
            install_success=true
        fi
    elif command -v pacman >/dev/null 2>&1; then
        if pacman -S --noconfirm --quiet rsync >/dev/null 2>&1; then
            install_success=true
        fi
    fi
    
    if [ "$install_success" = true ]; then
        echo -e "\033[1;32m✅ rsync installed successfully\033[0m"
        return 0
    else
        echo -e "\033[1;33m⚠️  Could not install rsync, will use alternative method\033[0m"
        return 1
    fi
}

schedule_command() {
    if [ "$#" -eq 0 ]; then
        schedule_menu
        return
    fi
    
    # Проверяем версию backup-скрипта перед выполнением команд
    check_backup_script_version
    local version_status=$?
    
    if [ $version_status -ne 0 ] && [ "$1" != "help" ] && [ "$1" != "-h" ] && [ "$1" != "--help" ]; then
        if prompt_backup_script_update $version_status; then
            schedule_recreate_script
            echo
        fi
    fi
    
    if [ "$#" -eq 0 ]; then
        schedule_menu  
        return 0       
    fi
    
    case "$1" in
        setup|config) schedule_setup_menu ;;
        enable) schedule_enable ;;
        disable) schedule_disable ;;
        status) schedule_status ;;
        test) schedule_test_backup ;;
        test-telegram) schedule_test_telegram ;;
        run) schedule_run_backup ;;
        logs) schedule_show_logs ;;
        cleanup) schedule_cleanup ;;
        help|-h|--help) schedule_help ;;
        menu) schedule_menu ;;
        *) 
            echo -e "\033[1;31mUnknown command: $1\033[0m"
            echo -e "\033[38;5;8mUse '\033[38;5;15m$APP_NAME schedule help\033[38;5;8m' for available commands\033[0m"
            echo
            echo -e "\033[1;37mAvailable commands:\033[0m"
            echo -e "   \033[38;5;15msetup\033[0m           Configure backup settings"
            echo -e "   \033[38;5;15menable\033[0m          Enable scheduler"
            echo -e "   \033[38;5;15mdisable\033[0m         Disable scheduler"
            echo -e "   \033[38;5;15mstatus\033[0m          Show scheduler status"
            echo -e "   \033[38;5;15mtest\033[0m            Test backup creation"
            echo -e "   \033[38;5;15mtest-telegram\033[0m   Test Telegram delivery"
            echo -e "   \033[38;5;15mrun\033[0m             Run backup now"
            echo -e "   \033[38;5;15mlogs\033[0m            View backup logs"
            echo -e "   \033[38;5;15mcleanup\033[0m         Clean old backups"
            echo -e "   \033[38;5;15mhelp\033[0m            Show this help"
            ;;
    esac
}


schedule_menu() {
    # Проверяем наличие jq
    if ! command -v jq >/dev/null 2>&1; then
        clear
        echo -e "\033[1;31m❌ Требуется установка jq\033[0m"
        echo
        echo -e "\033[38;5;250mjq необходим для работы системы бэкапов\033[0m"
        echo
        echo -e "\033[1;37mУстановка:\033[0m"
        echo -e "\033[38;5;244m  Ubuntu/Debian: sudo apt install jq\033[0m"
        echo -e "\033[38;5;244m  CentOS/RHEL:   sudo yum install jq\033[0m"
        echo
        read -p "Нажмите Enter для возврата в меню..."
        return 1
    fi
    
    if ! ensure_backup_dirs; then
        return 1
    fi
    
    # Проверяем версию скрипта при входе в меню
    check_backup_script_version
    local version_status=$?
    
    if [ $version_status -ne 0 ]; then
        if prompt_backup_script_update $version_status; then
            schedule_recreate_script
            echo
            read -p "Press Enter to continue..."
        fi
    fi
    
    while true; do
        clear
        echo -e "\033[1;37m📅 Automatic Backup Scheduler\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo
        
        local status=$(schedule_get_status)
        if [ "$status" = "enabled" ]; then
            echo -e "\033[1;32m✅ Scheduler Status: ENABLED\033[0m"
        else
            echo -e "\033[1;31m❌ Scheduler Status: DISABLED\033[0m"
        fi
        
        if [ -f "$BACKUP_CONFIG_FILE" ]; then
            local schedule=$(jq -r '.schedule // "Not configured"' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            local telegram_enabled=$(jq -r '.telegram.enabled // false' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            local retention=$(jq -r '.retention.days // 7' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            local compression=$(jq -r '.compression.enabled // true' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            
            echo -e "\033[38;5;250mSchedule: $schedule\033[0m"
            echo -e "\033[38;5;250mBackup Type: Full (database + all configs)\033[0m"
            echo -e "\033[38;5;250mCompression: $([ "$compression" = "true" ] && echo "✅ Enabled" || echo "❌ Disabled")\033[0m"
            echo -e "\033[38;5;250mTelegram: $([ "$telegram_enabled" = "true" ] && echo "✅ Enabled" || echo "❌ Disabled")\033[0m"
            echo -e "\033[38;5;250mRetention: $retention days\033[0m"
        else
            echo -e "\033[38;5;244mNo configuration found\033[0m"
        fi
        
        # Показываем информацию о логах
        if [ -f "$BACKUP_LOG_FILE" ]; then
            local log_size=$(du -sh "$BACKUP_LOG_FILE" 2>/dev/null | cut -f1)
            local last_entry=$(tail -1 "$BACKUP_LOG_FILE" 2>/dev/null | grep -o '\[.*\]' | head -1 || echo "No entries")
            echo -e "\033[38;5;250mLog size: $log_size, Last: $last_entry\033[0m"
        fi
        
        echo
        echo -e "\033[1;37m📋 Available Actions:\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m 🔧 Configure backup settings"
        echo -e "   \033[38;5;15m2)\033[0m ⚙️  Enable/Disable scheduler"
        echo -e "   \033[38;5;15m3)\033[0m 🧪 Test backup creation"
        echo -e "   \033[38;5;15m4)\033[0m 📱 Test Telegram delivery"
        echo -e "   \033[38;5;15m5)\033[0m 📊 Show scheduler status"
        echo -e "   \033[38;5;15m6)\033[0m 📋 View backup logs"
        echo -e "   \033[38;5;15m7)\033[0m 🧹 Cleanup old backups"
        echo -e "   \033[38;5;15m8)\033[0m ▶️  Run full backup now"
        echo -e "   \033[38;5;15m9)\033[0m 🔄 Update backup script"
        echo -e "   \033[38;5;15ma)\033[0m 🧹  Clear logs"
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  Back to main menu"
        echo
        echo -e "\033[38;5;8m💡 All scheduled backups include database + configurations\033[0m"
        echo
        
        read -p "Select option [0-9,a]: " choice
        
        case "$choice" in
            1) schedule_setup_menu ;;
            2) schedule_toggle ;;
            3) 
                schedule_test_backup
                read -p "Press Enter to continue..."
                ;;
            4) 
                schedule_test_telegram
                read -p "Press Enter to continue..."
                ;;
            5) 
                schedule_status
                read -p "Press Enter to continue..."
                ;;
            6) schedule_show_logs ;;
            7) schedule_cleanup ;;
            8) schedule_run_backup ;;
            9) schedule_update_script ;;
            a|A) schedule_clear_logs ;;
            0) 
                clear
                return 0  
                ;;
            *) 
                echo -e "\033[1;31mInvalid option!\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Новая функция очистки логов
schedule_clear_logs() {
    echo
    read -p "Clear all backup logs? [y/N]: " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        if [ -f "$BACKUP_LOG_FILE" ]; then
            > "$BACKUP_LOG_FILE"  # Очищаем файл
            echo -e "\033[1;32m✅ Backup logs cleared\033[0m"
        else
            echo -e "\033[38;5;244mNo log file to clear\033[0m"
        fi
    else
        echo -e "\033[38;5;250mOperation cancelled\033[0m"
    fi
    
    sleep 2
}

schedule_update_script() {
    clear
    echo -e "\033[1;37m🔄 Update Backup Script\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
    echo
    
    # Упрощённое обновление - просто пересоздаём скрипт
    echo -e "\033[1;33m🔄 Updating backup script to latest version...\033[0m"
    echo -e "\033[38;5;244m   Recreating script with version $BACKUP_SCRIPT_VERSION\033[0m"
    echo
    
    # Создаём новый скрипт
    schedule_create_backup_script
    
    if [ -f "$BACKUP_SCRIPT_FILE" ]; then
        echo -e "\033[1;32m✅ Backup script updated successfully (v$BACKUP_SCRIPT_VERSION)\033[0m"
        echo -e "\033[38;5;244m   Script location: $BACKUP_SCRIPT_FILE\033[0m"
        
        echo
        echo -e "\033[1;37m🚀 Features in v$BACKUP_SCRIPT_VERSION:\033[0m"
        echo -e "\033[38;5;250m   ✓ Unified backup structure (compatible with manual backups)\033[0m"
        echo -e "\033[38;5;250m   ✓ Improved compression and file handling\033[0m"
        echo -e "\033[38;5;250m   ✓ Better error handling and logging\033[0m"
        echo -e "\033[38;5;250m   ✓ Enhanced restore compatibility\033[0m"
        echo -e "\033[38;5;250m   ✓ Automatic version checking\033[0m"
        
        # Если scheduler включен, показываем статус
        local status=$(schedule_get_status)
        if [ "$status" = "enabled" ]; then
            echo
            echo -e "\033[1;37m📋 Scheduler Status: ENABLED\033[0m"
            echo -e "\033[38;5;250m   Updated script will be used for next scheduled backup\033[0m"
            echo -e "\033[38;5;244m   No restart required - changes take effect immediately\033[0m"
        fi
    else
        echo -e "\033[1;31m❌ Failed to update backup script\033[0m"
    fi
    
    echo
    read -p "Press Enter to continue..."
}


schedule_setup_menu() {
    # Убеждаемся что rsync установлен для лучшей производительности
    if ! command -v rsync >/dev/null 2>&1; then
        ensure_rsync_installed
    fi

    while true; do
        clear
        echo -e "\033[1;37m🔧 Backup Configuration\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
        echo
        
        if [ -f "$BACKUP_CONFIG_FILE" ]; then
            echo -e "\033[1;37m📋 Current Settings:\033[0m"
            local schedule=$(jq -r '.schedule // "Not set"' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            local backup_type=$(jq -r '.backup_type // "sql_dump"' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            local compression=$(jq -r '.compression.enabled // false' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            local retention=$(jq -r '.retention.days // 7' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            local telegram_enabled=$(jq -r '.telegram.enabled // false' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            local include_reverse_proxy=$(jq -r '.include_reverse_proxy // true' "$BACKUP_CONFIG_FILE" 2>/dev/null)
            
            # Красивое отображение типа бэкапа
            local backup_type_display=""
            case "$backup_type" in
                "sql_dump") backup_type_display="SQL Dump (standard)" ;;
                "volume") backup_type_display="Volume (fast)" ;;
                "both") backup_type_display="Both (SQL + Volume)" ;;
                *) backup_type_display="$backup_type" ;;
            esac
            
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Backup Type:" "$backup_type_display"
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Schedule:" "$schedule"
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Compression:" "$([ "$compression" = "true" ] && echo "Enabled" || echo "Disabled")"
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s days\033[0m\n" "Retention:" "$retention"
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Reverse Proxy:" "$([ "$include_reverse_proxy" = "true" ] && echo "Auto-detect" || echo "Disabled")"
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Telegram:" "$([ "$telegram_enabled" = "true" ] && echo "Enabled (49MB limit)" || echo "Disabled")"
            echo
        fi
        
        echo -e "\033[1;37m⚙️  Configuration Options:\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m 💾 Set backup type"
        echo -e "   \033[38;5;15m2)\033[0m ⏰ Set backup schedule"
        echo -e "   \033[38;5;15m3)\033[0m 🗜️  Configure compression"
        echo -e "   \033[38;5;15m4)\033[0m 🗂️  Set retention policy"
        echo -e "   \033[38;5;15m5)\033[0m 🌐 Configure reverse proxy backup (Caddy/Traefik)"
        echo -e "   \033[38;5;15m6)\033[0m 📱 Configure Telegram"
        echo -e "   \033[38;5;15m7)\033[0m 🔄 Reset to defaults"
        echo -e "   \033[38;5;15m8)\033[0m 🔧 Recreate backup script"
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  Back"
        echo
        
        read -p "Select option [0-8]: " choice
        
        case "$choice" in
            1) schedule_configure_backup_type ;;
            2) schedule_configure_schedule ;;
            3) schedule_configure_compression ;;
            4) schedule_configure_retention ;;
            5) schedule_configure_reverse_proxy ;;
            6) schedule_configure_telegram ;;
            7) schedule_reset_config ;;
            8) schedule_recreate_script ;;
            0) 
                return 0  
                ;;
            *) 
                echo -e "\033[1;31mInvalid option!\033[0m"
                sleep 1
                ;;
        esac
    done
}

schedule_recreate_script() {
    echo
    echo -e "\033[1;37m🔧 Recreating Backup Script\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 35))\033[0m"
    echo
    echo -e "\033[38;5;250mThis will recreate the backup script with latest version\033[0m"
    read -p "Continue? [y/N]: " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # Удаляем старый скрипт
        if [ -f "$BACKUP_SCRIPT_FILE" ]; then
            rm -f "$BACKUP_SCRIPT_FILE"
            echo -e "\033[38;5;244m   Old script removed\033[0m"
        fi
        
        # Создаем новый
        schedule_create_backup_script
        echo -e "\033[1;32m✅ Backup script recreated successfully!\033[0m"
    else
        echo -e "\033[38;5;250mOperation cancelled\033[0m"
    fi
    
    sleep 2
}


schedule_configure_backup_type() {
    clear
    echo -e "\033[1;37m💾 Configure Backup Type\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    local current_type=$(jq -r '.backup_type // "sql_dump"' "$BACKUP_CONFIG_FILE" 2>/dev/null)
    echo -e "\033[38;5;250mCurrent type: \033[1;37m$current_type\033[0m"
    echo
    
    echo -e "\033[1;37m📋 Available Backup Types:\033[0m"
    echo
    echo -e "   \033[38;5;15m1) SQL Dump\033[0m (Recommended)"
    echo -e "      \033[38;5;244m✓ Works across PostgreSQL versions\033[0m"
    echo -e "      \033[38;5;244m✓ Human-readable and editable\033[0m"
    echo -e "      \033[38;5;244m✓ Can restore specific tables\033[0m"
    echo -e "      \033[38;5;244m⚠ Slower for large databases (>1GB)\033[0m"
    echo
    echo -e "   \033[38;5;15m2) Volume Backup\033[0m (Fast)"
    echo -e "      \033[38;5;244m✓ Much faster (3-10x speed)\033[0m"
    echo -e "      \033[38;5;244m✓ Exact binary copy of database\033[0m"
    echo -e "      \033[38;5;244m✓ Includes all PostgreSQL settings\033[0m"
    echo -e "      \033[38;5;244m⚠ Requires exact PostgreSQL version match\033[0m"
    echo -e "      \033[38;5;244m⚠ Database stopped during backup (~10s)\033[0m"
    echo
    echo -e "   \033[38;5;15m3) Both\033[0m (Maximum Safety)"
    echo -e "      \033[38;5;244m✓ SQL dump + Volume backup\033[0m"
    echo -e "      \033[38;5;244m✓ Choose restore method later\033[0m"
    echo -e "      \033[38;5;244m✓ Best for critical systems\033[0m"
    echo -e "      \033[38;5;244m⚠ Larger backup size\033[0m"
    echo -e "      \033[38;5;244m⚠ Takes longer to create\033[0m"
    echo
    echo -e "   \033[38;5;244m0) Cancel\033[0m"
    echo
    
    read -p "Select backup type [1-3, 0 to cancel]: " choice
    
    local backup_type=""
    case "$choice" in
        1) 
            backup_type="sql_dump"
            echo -e "\033[1;32m✅ Selected: SQL Dump\033[0m"
            ;;
        2) 
            backup_type="volume"
            echo -e "\033[1;32m✅ Selected: Volume Backup\033[0m"
            echo -e "\033[1;33m⚠️  Note: Database will be stopped for ~10 seconds during backup\033[0m"
            ;;
        3) 
            backup_type="both"
            echo -e "\033[1;32m✅ Selected: Both (SQL Dump + Volume)\033[0m"
            echo -e "\033[1;33m⚠️  Note: Larger backup size and longer backup time\033[0m"
            ;;
        0) 
            echo -e "\033[38;5;244mCancelled\033[0m"
            sleep 1
            return
            ;;
        *) 
            echo -e "\033[1;31m❌ Invalid option!\033[0m"
            sleep 2
            return
            ;;
    esac
    
    # Обновляем конфиг
    schedule_update_config ".backup_type" "\"$backup_type\""
    
    echo
    echo -e "\033[1;33m🔄 Recreating backup script with new type...\033[0m"
    schedule_recreate_script
    
    echo
    echo -e "\033[1;32m✅ Backup type updated successfully!\033[0m"
    sleep 3
}

schedule_configure_schedule() {
    clear
    echo -e "\033[1;37m⏰ Configure Backup Schedule\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 35))\033[0m"
    echo
    echo -e "\033[1;37m📋 Predefined Schedules:\033[0m"
    echo -e "   \033[38;5;15m1)\033[0m Daily at 2:00 AM"
    echo -e "   \033[38;5;15m2)\033[0m Daily at 4:00 AM"
    echo -e "   \033[38;5;15m3)\033[0m Every 12 hours"
    echo -e "   \033[38;5;15m4)\033[0m Weekly (Sunday 2:00 AM)"
    echo -e "   \033[38;5;15m5)\033[0m Custom cron expression"
    echo -e "   \033[38;5;15m0)\033[0m Back"
    echo
    
    read -p "Select schedule [0-5]: " choice
    
    local cron_expression=""
    case "$choice" in
        0) return ;;
        1) cron_expression="0 2 * * *" ;;
        2) cron_expression="0 4 * * *" ;;
        3) cron_expression="0 */12 * * *" ;;
        4) cron_expression="0 2 * * 0" ;;
        5) 
            echo
            echo -e "\033[1;37m⚙️  Custom Cron Expression\033[0m"
            echo -e "\033[38;5;244mFormat: minute hour day month weekday\033[0m"
            echo -e "\033[38;5;244mExample: 0 3 * * * (daily at 3:00 AM)\033[0m"
            echo
            read -p "Enter cron expression: " cron_expression
            
            if ! echo "$cron_expression" | grep -E '^[0-9\*\-\,\/]+ [0-9\*\-\,\/]+ [0-9\*\-\,\/]+ [0-9\*\-\,\/]+ [0-9\*\-\,\/]+$' >/dev/null; then
                echo -e "\033[1;31m❌ Invalid cron expression!\033[0m"
                sleep 2
                return
            fi
            ;;
        *) echo -e "\033[1;31mInvalid option!\033[0m"; sleep 1; return ;;
    esac
    
    schedule_update_config ".schedule" "\"$cron_expression\""
    echo -e "\033[1;32m✅ Schedule updated: $cron_expression\033[0m"
    sleep 2
}

schedule_configure_compression() {
    clear
    echo -e "\033[1;37m🗜️  Configure Compression\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
    echo
    echo -e "\033[38;5;250mCompression reduces backup size but increases CPU usage\033[0m"
    echo
    
    read -p "Enable compression? [y/N]: " enable_compression
    
    if [[ $enable_compression =~ ^[Yy]$ ]]; then
        schedule_update_config ".compression.enabled" "true"
        
        echo
        echo -e "\033[1;37m📊 Compression Level:\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m Fast (level 1)"
        echo -e "   \033[38;5;15m2)\033[0m Balanced (level 6)"
        echo -e "   \033[38;5;15m3)\033[0m Best (level 9)"
        echo
        
        read -p "Select compression level [1-3]: " level_choice
        
        local compression_level=6
        case "$level_choice" in
            1) compression_level=1 ;;
            2) compression_level=6 ;;
            3) compression_level=9 ;;
        esac
        
        schedule_update_config ".compression.level" "$compression_level"
        echo -e "\033[1;32m✅ Compression enabled (level $compression_level)\033[0m"
    else
        schedule_update_config ".compression.enabled" "false"
        echo -e "\033[1;32m✅ Compression disabled\033[0m"
    fi
    
    sleep 2
}

schedule_configure_retention() {
    clear
    echo -e "\033[1;37m🗂️  Configure Retention Policy\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 35))\033[0m"
    echo
    echo -e "\033[38;5;250mHow long to keep backup files before automatic deletion\033[0m"
    echo
    
    read -p "Retention period in days [7]: " retention_days
    retention_days=${retention_days:-7}
    
    if ! [[ "$retention_days" =~ ^[0-9]+$ ]] || [ "$retention_days" -lt 1 ]; then
        echo -e "\033[1;31m❌ Invalid number!\033[0m"
        sleep 2
        return
    fi
    
    schedule_update_config ".retention.days" "$retention_days"
    
    echo
    read -p "Keep minimum number of backups regardless of age? [y/N]: " keep_minimum
    if [[ $keep_minimum =~ ^[Yy]$ ]]; then
        read -p "Minimum backups to keep [3]: " min_backups
        min_backups=${min_backups:-3}
        
        if [[ "$min_backups" =~ ^[0-9]+$ ]] && [ "$min_backups" -ge 1 ]; then
            schedule_update_config ".retention.min_backups" "$min_backups"
        fi
    fi
    
    echo -e "\033[1;32m✅ Retention policy updated: $retention_days days\033[0m"
    sleep 2
}

schedule_configure_reverse_proxy() {
    clear
    echo -e "\033[1;37m🌐 Configure Reverse Proxy Backup\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 45))\033[0m"
    echo
    
    # Текущая настройка
    local include_reverse_proxy=$(jq -r '.include_reverse_proxy // true' "$BACKUP_CONFIG_FILE" 2>/dev/null)
    
    echo -e "\033[1;37m📋 Current Setting:\033[0m"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Reverse Proxy:" "$([ "$include_reverse_proxy" = "true" ] && echo "Enabled (auto-detect)" || echo "Disabled")"
    echo
    
    # Проверяем установленные прокси
    echo -e "\033[1;37m🔍 Detected Installations:\033[0m"
    
    local caddy_installed=false
    local traefik_installed=false
    local detected_proxies=""
    
    if [ -d "/opt/caddy-remnawave" ]; then
        caddy_installed=true
        echo -e "   \033[1;32m✓\033[0m Caddy found at \033[38;5;244m/opt/caddy-remnawave\033[0m"
        detected_proxies="Caddy"
    else
        echo -e "   \033[38;5;244m✗ Caddy not installed\033[0m"
    fi
    
    for traefik_dir in "/opt/traefik" "/opt/traefik-remnawave" "/etc/traefik"; do
        if [ -d "$traefik_dir" ]; then
            traefik_installed=true
            echo -e "   \033[1;32m✓\033[0m Traefik found at \033[38;5;244m$traefik_dir\033[0m"
            [ -n "$detected_proxies" ] && detected_proxies="$detected_proxies + Traefik" || detected_proxies="Traefik"
            break
        fi
    done
    
    if [ "$traefik_installed" = false ]; then
        echo -e "   \033[38;5;244m✗ Traefik not installed\033[0m"
    fi
    
    echo
    if [ -n "$detected_proxies" ]; then
        if [ "$include_reverse_proxy" = "true" ]; then
            echo -e "\033[38;5;244m💡 Will backup: $detected_proxies\033[0m"
        else
            echo -e "\033[38;5;244m💡 Backup disabled, would backup: $detected_proxies\033[0m"
        fi
    else
        echo -e "\033[38;5;244m💡 No reverse proxy detected. Nothing to backup.\033[0m"
    fi
    
    echo
    echo -e "\033[1;37m⚙️  Configuration Options:\033[0m"
    echo -e "   \033[38;5;15m1)\033[0m $([ "$include_reverse_proxy" = "true" ] && echo "Disable" || echo "Enable") reverse proxy backup"
    echo -e "   \033[38;5;244m0)\033[0m Back"
    echo
    
    read -p "Select option [0-1]: " choice
    
    case "$choice" in
        1)
            if [ "$include_reverse_proxy" = "true" ]; then
                schedule_update_config ".include_reverse_proxy" "false"
                echo -e "\033[1;32m✅ Reverse proxy backup disabled\033[0m"
            else
                schedule_update_config ".include_reverse_proxy" "true"
                echo -e "\033[1;32m✅ Reverse proxy backup enabled (auto-detect)\033[0m"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid option!\033[0m"
            ;;
    esac
    
    echo
    echo -e "\033[38;5;244m💡 Note: Run 'Recreate backup script' for changes to take effect\033[0m"
    sleep 2
}

schedule_configure_telegram() {
    clear
    echo -e "\033[1;37m📱 Configure Telegram Integration\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    echo
    
    read -p "Enable Telegram notifications? [y/N]: " enable_telegram
    
    if [[ $enable_telegram =~ ^[Yy]$ ]]; then
        schedule_update_config ".telegram.enabled" "true"

        schedule_update_config ".telegram.use_custom_api" "false"
        schedule_update_config ".telegram.api_server" "\"https://api.telegram.org\""
        schedule_update_config ".telegram.max_file_size" "49"
        schedule_update_config ".telegram.split_large_files" "true"
        
        echo -e "\033[1;32m✅ Using official Telegram Bot API (49MB file limit)\033[0m"
        
        # Bot Token
        echo
        echo -e "\033[1;37m🤖 Bot Token Configuration\033[0m"
        echo -e "\033[38;5;244mGet token from @BotFather on Telegram\033[0m"
        
        local current_token=$(jq -r '.telegram.bot_token // ""' "$BACKUP_CONFIG_FILE" 2>/dev/null)
        if [ -n "$current_token" ] && [ "$current_token" != "null" ]; then
            echo -e "\033[38;5;250mCurrent token: ${current_token:0:10}...\033[0m"
            read -p "Keep current token? [Y/n]: " keep_token
            if [[ ! $keep_token =~ ^[Nn]$ ]]; then
                current_token=""
            fi
        fi
        
        if [ -z "$current_token" ] || [ "$current_token" = "null" ]; then
            read -p "Enter bot token: " bot_token
            if [ -z "$bot_token" ]; then
                echo -e "\033[1;31m❌ Token is required!\033[0m"
                sleep 2
                return
            fi
            
            # Экранируем специальные символы в токене для безопасного JSON
            bot_token_escaped=$(printf '%s' "$bot_token" | sed 's/"/\\"/g')
            
            if schedule_update_config ".telegram.bot_token" "\"$bot_token_escaped\""; then
                echo -e "\033[1;32m✅ Bot token saved successfully\033[0m"
            else
                echo -e "\033[1;31m❌ Failed to save bot token\033[0m"
                sleep 2
                return
            fi
        fi
        
        # Chat ID
        echo
        echo -e "\033[1;37m💬 Chat Configuration\033[0m"
        echo -e "\033[38;5;244mFor groups: use negative ID (e.g., -1001234567890)\033[0m"
        echo -e "\033[38;5;244mFor private: use positive ID (e.g., 123456789)\033[0m"
        
        read -p "Enter chat ID: " chat_id
        if [ -z "$chat_id" ]; then
            echo -e "\033[1;31m❌ Chat ID is required!\033[0m"
            sleep 2
            return
        fi
        schedule_update_config ".telegram.chat_id" "\"$chat_id\""
        
        # Thread ID (optional)
        echo
        echo -e "\033[1;37m🧵 Thread Configuration (Optional)\033[0m"
        echo -e "\033[38;5;244mFor group threads/topics. Leave empty if not using threads.\033[0m"
        
        read -p "Enter thread ID (optional): " thread_id
        if [ -n "$thread_id" ]; then
            schedule_update_config ".telegram.thread_id" "\"$thread_id\""
        else
            schedule_update_config ".telegram.thread_id" "null"
        fi
        
        echo -e "\033[1;32m✅ Telegram integration configured!\033[0m"
        echo -e "\033[38;5;8m   Files larger than 49MB will be automatically split\033[0m"
        echo -e "\033[38;5;8m   Use 'Test Telegram' to verify settings\033[0m"
    else
        schedule_update_config ".telegram.enabled" "false"
        echo -e "\033[1;32m✅ Telegram notifications disabled\033[0m"
    fi
    
    sleep 2
}

schedule_update_config() {
    local key="$1"
    local value="$2"
    
    # Проверяем и исправляем поврежденный конфиг если нужно
    validate_and_fix_backup_config
    
    if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
        echo '{}' > "$BACKUP_CONFIG_FILE"
    fi

    local temp_file=$(mktemp)
    if jq "$key = $value" "$BACKUP_CONFIG_FILE" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$BACKUP_CONFIG_FILE"
    else
        echo -e "\033[1;31m❌ Failed to update backup configuration\033[0m"
        rm -f "$temp_file"
        return 1
    fi
}

ensure_cron_installed() {
    # Проверяем наличие crontab
    if command -v crontab >/dev/null 2>&1; then
        return 0
    fi
    
    echo -e "\033[38;5;250m📦 Installing cron service for backup scheduling...\033[0m"
    
    # Определяем пакетный менеджер и устанавливаем cron
    local install_success=false
    
    if command -v apt-get >/dev/null 2>&1; then
        if apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq cron >/dev/null 2>&1; then
            # Запускаем и включаем cron service
            systemctl start cron 2>/dev/null || service cron start 2>/dev/null || true
            systemctl enable cron 2>/dev/null || true
            install_success=true
        fi
    elif command -v yum >/dev/null 2>&1; then
        if yum install -y -q cronie >/dev/null 2>&1; then
            systemctl start crond 2>/dev/null || service crond start 2>/dev/null || true
            systemctl enable crond 2>/dev/null || true
            install_success=true
        fi
    elif command -v dnf >/dev/null 2>&1; then
        if dnf install -y -q cronie >/dev/null 2>&1; then
            systemctl start crond 2>/dev/null || service crond start 2>/dev/null || true
            systemctl enable crond 2>/dev/null || true
            install_success=true
        fi
    elif command -v pacman >/dev/null 2>&1; then
        if pacman -S --noconfirm --quiet cronie >/dev/null 2>&1; then
            systemctl start cronie 2>/dev/null || true
            systemctl enable cronie 2>/dev/null || true
            install_success=true
        fi
    fi
    
    if [ "$install_success" = true ]; then
        echo -e "\033[1;32m✅ Cron service installed and started successfully\033[0m"
        return 0
    else
        echo -e "\033[1;31m❌ Could not install cron service automatically\033[0m"
        echo -e "\033[38;5;244m   Please install manually:\033[0m"
        if command -v apt-get >/dev/null 2>&1; then
            echo -e "\033[38;5;117m   sudo apt-get install cron\033[0m"
        elif command -v yum >/dev/null 2>&1; then
            echo -e "\033[38;5;117m   sudo yum install cronie\033[0m"
        elif command -v dnf >/dev/null 2>&1; then
            echo -e "\033[38;5;117m   sudo dnf install cronie\033[0m"
        fi
        return 1
    fi
}

schedule_get_status() {
    if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT_FILE"; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

schedule_toggle() {
    local status=$(schedule_get_status)
    
    if [ "$status" = "enabled" ]; then
        echo -e "\033[1;33mDisabling scheduler...\033[0m"
        schedule_disable
    else
        echo -e "\033[1;33mEnabling scheduler...\033[0m"
        schedule_enable
    fi
    
    # Add pause to show result before returning to menu
    read -p "Press Enter to continue..."
}

schedule_enable() {
    # Проверяем и устанавливаем cron если необходимо
    if ! ensure_cron_installed; then
        echo -e "\033[1;31m❌ Cannot enable scheduler without cron service!\033[0m"
        sleep 3
        return
    fi
    
    if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
        echo -e "\033[1;31m❌ No configuration found! Please configure backup settings first.\033[0m"
        sleep 2
        return
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "\033[1;31m❌ jq is not installed! Please install jq first.\033[0m"
        echo -e "\033[38;5;244m   Install with: sudo apt-get install jq\033[0m"
        sleep 3
        return
    fi
    
    local schedule=$(jq -r '.schedule // ""' "$BACKUP_CONFIG_FILE" 2>/dev/null)
    if [ -z "$schedule" ] || [ "$schedule" = "null" ]; then
        echo -e "\033[1;31m❌ No schedule configured! Please set backup schedule first.\033[0m"
        sleep 2
        return
    fi

    # Проверяем и создаём backup скрипт если необходимо
    if [ ! -f "$BACKUP_SCRIPT_FILE" ]; then
        echo -e "\033[1;33m⚠️  Creating backup script...\033[0m"
        schedule_create_backup_script
    else
        # Простая проверка - если файл есть, но версия может быть старой, обновляем
        echo -e "\033[1;33m⚠️  Ensuring backup script is up-to-date...\033[0m"
        schedule_create_backup_script
    fi

    local cron_entry="$schedule $BACKUP_SCRIPT_FILE >> $BACKUP_LOG_FILE 2>&1 # Remnawave Backup Scheduler"
    
    # Удаляем старую запись для backup-scheduler.sh если есть
    if (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT_FILE"; echo "$cron_entry") | crontab - 2>/dev/null; then
        echo -e "\033[1;32m✅ Backup scheduler enabled!\033[0m"
        echo -e "\033[38;5;250mSchedule: $schedule\033[0m"
    else
        echo -e "\033[1;31m❌ Failed to enable scheduler! Check cron service status.\033[0m"
        echo -e "\033[38;5;244m   Try: sudo systemctl status cron\033[0m"
    fi
    
    sleep 2
}

schedule_disable() {
    if ! command -v crontab >/dev/null 2>&1; then
        echo -e "\033[1;33m⚠️  Crontab not available, but scheduler should be disabled\033[0m"
        sleep 2
        return
    fi
    
    if crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT_FILE" | crontab - 2>/dev/null; then
        echo -e "\033[1;32m✅ Backup scheduler disabled!\033[0m"
    else
        # Попробуем создать пустой crontab если его не было
        if crontab -l 2>/dev/null | wc -l | grep -q "^0$"; then
            echo "" | crontab - 2>/dev/null
            echo -e "\033[1;32m✅ Backup scheduler disabled (crontab was empty)!\033[0m"
        else
            echo -e "\033[1;33m⚠️  Could not modify crontab, but scheduler should be disabled\033[0m"
        fi
    fi
    
    sleep 2
}




# ===== RESTORE VALIDATION AND SAFETY FUNCTIONS =====

# Функция детального логирования для операций восстановления
log_restore_operation() {
    local operation="$1"
    local status="$2"
    local details="$3"
    local restore_log_file="$APP_DIR/logs/restore.log"
    
    # Создаем директорию для логов если не существует
    mkdir -p "$(dirname "$restore_log_file")"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] RESTORE: $operation - $status"
    
    if [ -n "$details" ]; then
        log_entry="$log_entry - $details"
    fi
    
    echo "$log_entry" >> "$restore_log_file"
    
    # Дополнительно выводим в основной лог если функция доступна
    if declare -f log_message >/dev/null 2>&1; then
        log_message "RESTORE: $operation - $status"
    fi
}

# Функция проверки совместимости версий
check_version_compatibility() {
    local backup_metadata="$1"
    local current_script_version="$SCRIPT_VERSION"
    
    if [ ! -f "$backup_metadata" ]; then
        log_restore_operation "Version Check" "WARNING" "No metadata file found, skipping version check"
        return 0
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_restore_operation "Version Check" "WARNING" "jq not available, skipping version check"
        return 0
    fi
    
    local backup_script_version=$(jq -r '.script_version // "unknown"' "$backup_metadata" 2>/dev/null)
    local backup_panel_version=$(jq -r '.panel_version // "unknown"' "$backup_metadata" 2>/dev/null)
    local backup_date=$(jq -r '.date_created // "unknown"' "$backup_metadata" 2>/dev/null)
    
    # Получаем текущую версию панели
    local current_panel_version=$(get_panel_version)
    
    log_restore_operation "Version Check" "INFO" "Backup script: $backup_script_version, Current: $current_script_version, Backup panel: $backup_panel_version, Current panel: $current_panel_version, Date: $backup_date"
    
    # Проверка совместимости версии панели (критически важно!)
    if [ "$backup_panel_version" != "unknown" ] && [ "$current_panel_version" != "unknown" ]; then
        validate_panel_version_compatibility "$backup_panel_version" "$current_panel_version"
        local panel_compat_result=$?
        
        case $panel_compat_result in
            0)
                echo -e "\033[1;32m✅ Panel version compatibility: Perfect match ($current_panel_version)\033[0m"
                log_restore_operation "Panel Version Check" "SUCCESS" "Versions match: $current_panel_version"
                ;;
            1)
                echo -e "\033[1;33m⚠️  Panel version compatibility: Minor difference\033[0m"
                echo -e "\033[38;5;244m   Backup panel: $backup_panel_version\033[0m"
                echo -e "\033[38;5;244m   Current panel: $current_panel_version\033[0m"
                echo -e "\033[38;5;244m   Restore should work but verify functionality after\033[0m"
                log_restore_operation "Panel Version Check" "WARNING" "Minor version difference: $backup_panel_version -> $current_panel_version"
                ;;
            3)
                echo -e "\033[1;31m❌ CRITICAL: Panel version incompatibility detected!\033[0m"
                echo -e "\033[38;5;244m   Backup panel version: $backup_panel_version\033[0m"
                echo -e "\033[38;5;244m   Current panel version: $current_panel_version\033[0m"
                echo -e "\033[1;31m   ⚠️  Restoring this backup may break your panel!\033[0m"
                echo
                echo -e "\033[1;37m🔧 Recommended actions:\033[0m"
                echo -e "\033[38;5;250m   1. Install Remnawave panel v$backup_panel_version first\033[0m"
                echo -e "\033[38;5;250m   2. Or create new backup from current v$current_panel_version panel\033[0m"
                echo
                read -p "Continue anyway? This is DANGEROUS! [y/N]: " -r force_continue
                if [[ ! $force_continue =~ ^[Yy]$ ]]; then
                    log_restore_operation "Panel Version Check" "ERROR" "User aborted due to version incompatibility"
                    echo -e "\033[1;33m⚠️  Restore aborted for safety\033[0m"
                    return 2
                fi
                log_restore_operation "Panel Version Check" "WARNING" "User forced continue despite incompatibility"
                ;;
        esac
    elif [ "$backup_panel_version" = "unknown" ]; then
        echo -e "\033[1;33m⚠️  Panel version unknown in backup - cannot verify compatibility\033[0m"
        log_restore_operation "Panel Version Check" "WARNING" "Unknown backup panel version"
    elif [ "$current_panel_version" = "unknown" ]; then
        echo -e "\033[1;33m⚠️  Current panel version unknown - cannot verify compatibility\033[0m"
        log_restore_operation "Panel Version Check" "WARNING" "Unknown current panel version"
    fi
    
    # Проверка версии скрипта (менее критично)
    if [ "$backup_script_version" != "unknown" ] && [ "$backup_script_version" != "$current_script_version" ]; then
        local backup_major=$(echo "$backup_script_version" | cut -d'.' -f1)
        local current_major=$(echo "$current_script_version" | cut -d'.' -f1)
        
        if [ "$backup_major" != "$current_major" ]; then
            log_restore_operation "Script Version Check" "WARNING" "Major version mismatch - backup may be incompatible"
            echo -e "\033[1;33m⚠️  Script version compatibility warning:\033[0m"
            echo -e "\033[38;5;244m   Backup script: $backup_script_version\033[0m"
            echo -e "\033[38;5;244m   Current script: $current_script_version\033[0m"
            return 1
        else
            log_restore_operation "Script Version Check" "INFO" "Minor script version difference, should be compatible"
        fi
    fi
    
    return 0
}

# Функция проверки системных ресурсов
check_system_resources() {
    local backup_file="$1"
    local target_dir="$2"
    
    echo -e "\033[38;5;250m📝 Checking system resources...\033[0m"
    
    # Размер бэкапа
    local backup_size=0
    if [ -f "$backup_file" ]; then
        backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
    fi
    
    # Доступное место на диске (в KB)
    local available_space=$(df "$(dirname "$target_dir")" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
    local available_bytes=$((available_space * 1024))
    
    # Проверяем что места достаточно (с запасом 50% для extraction и временных файлов)
    local required_space=$((backup_size * 15 / 10))
    
    if [ "$available_bytes" -lt "$required_space" ] && [ "$backup_size" -gt 0 ]; then
        local backup_mb=$((backup_size / 1024 / 1024))
        local available_mb=$((available_bytes / 1024 / 1024))
        echo -e "\033[1;31m❌ Insufficient disk space!\033[0m"
        echo -e "\033[38;5;244m   Required: ~${backup_mb}MB + 50% buffer, Available: ${available_mb}MB\033[0m"
        return 1
    fi
    
    # Проверка памяти (базовая)
    local available_memory=$(free -m 2>/dev/null | awk 'NR==2{print $7}' || echo "1000")
    if [ "$available_memory" -lt 500 ]; then
        echo -e "\033[1;33m⚠️  Low available memory (${available_memory}MB), restore may be slow\033[0m"
    fi
    
    echo -e "\033[1;32m✅ System resources check passed\033[0m"
    return 0
}

# Функция валидации SQL содержимого
validate_sql_integrity() {
    local sql_file="$1"
    
    if [ ! -f "$sql_file" ]; then
        return 1
    fi
    
    echo -e "\033[38;5;250m📝 Validating SQL file integrity...\033[0m"
    
    # Проверка размера файла
    local file_size=$(wc -c < "$sql_file" 2>/dev/null || echo "0")
    if [ "$file_size" -lt 100 ]; then
        echo -e "\033[1;31m❌ SQL file too small (${file_size} bytes)\033[0m"
        return 1
    fi
    
    # Проверка заголовков PostgreSQL (более мягкая проверка)
    local pg_header_found=false
    if head -20 "$sql_file" | grep -qi "PostgreSQL\|postgres\|pg_dump"; then
        pg_header_found=true
    fi
    
    # Проверка на наличие критических команд
    local has_structure=false
    local has_data=false
    local command_count=0
    
    # Более детальная проверка команд
    if grep -qE "CREATE\s+(TABLE|DATABASE|SCHEMA|INDEX)" "$sql_file" 2>/dev/null; then
        has_structure=true
        command_count=$((command_count + 1))
    fi
    
    if grep -qE "ALTER\s+(TABLE|DATABASE)" "$sql_file" 2>/dev/null; then
        has_structure=true
        command_count=$((command_count + 1))
    fi
    
    if grep -qE "INSERT\s+INTO|COPY\s+.*FROM\s+stdin" "$sql_file" 2>/dev/null; then
        has_data=true
        command_count=$((command_count + 1))
    fi
    
    # Проверяем специфичные для RemnaWave таблицы (если есть)
    local remnawave_tables=false
    if grep -qiE "(users|nodes|traffic|settings)" "$sql_file" 2>/dev/null; then
        remnawave_tables=true
    fi
    
    # Результаты проверки
    if [ "$has_structure" = false ] && [ "$has_data" = false ]; then
        echo -e "\033[1;31m❌ SQL file appears to contain no valid database commands\033[0m"
        return 1
    fi
    
    if [ "$pg_header_found" = false ] && [ "$command_count" -lt 3 ]; then
        echo -e "\033[1;33m⚠️  Warning: SQL file may not be a standard PostgreSQL dump\033[0m"
    fi
    
    if [ "$remnawave_tables" = true ]; then
        echo -e "\033[1;32m✅ RemnaWave database tables detected\033[0m"
    fi
    
    # Проверка на SQL инъекции и подозрительные команды
    if grep -qi "drop database\|rm -rf\|system\|exec\|eval" "$sql_file" 2>/dev/null; then
        echo -e "\033[1;33m⚠️  Warning: SQL file contains potentially dangerous commands\033[0m"
        echo -e "\033[38;5;244m   This is normal for database restore operations (DROP DATABASE, etc.)\033[0m"
    fi
    
    echo -e "\033[1;32m✅ SQL file validation passed\033[0m"
    return 0
}

# Функция валидации извлеченного бэкапа
validate_extracted_backup() {
    local target_dir="$1"
    local backup_type="${2:-full}"
    local app_name="$3"
    
    echo -e "\033[38;5;250m📝 Validating extracted backup...\033[0m"
    
    local validation_errors=0
    local validation_warnings=0
    
    # Проверка структуры файлов для full backup
    if [ "$backup_type" = "full" ]; then
        # Обязательные файлы: docker-compose.yml и .env
        if [ ! -f "$target_dir/docker-compose.yml" ]; then
            echo -e "\033[1;31m❌ Critical file missing: docker-compose.yml\033[0m"
            validation_errors=$((validation_errors + 1))
        else
            # Показываем информацию о файле
            local compose_size=$(wc -c < "$target_dir/docker-compose.yml" 2>/dev/null || echo "0")
            echo -e "\033[38;5;244m   Found docker-compose.yml (${compose_size} bytes)\033[0m"
            
            # Базовая проверка структуры docker-compose.yml
            # Проверяем только наличие обязательных секций, без запуска Docker
            if ! grep -q "services:" "$target_dir/docker-compose.yml" 2>/dev/null; then
                echo -e "\033[1;31m❌ Invalid docker-compose.yml structure (no services section)\033[0m"
                echo -e "\033[38;5;244m   Hint: Run with DEBUG_RESTORE=true to see file contents\033[0m"
                validation_errors=$((validation_errors + 1))
            elif ! head -100 "$target_dir/docker-compose.yml" | grep -qE "image:|build:" 2>/dev/null; then
                echo -e "\033[1;33m⚠️  Warning: docker-compose.yml may be incomplete (no image/build found)\033[0m"
                validation_warnings=$((validation_warnings + 1))
            else
                # Дополнительная проверка: есть ли базовые секции
                local compose_services_count=$(grep -c "^  [a-zA-Z]" "$target_dir/docker-compose.yml" 2>/dev/null || echo "0")
                echo -e "\033[1;32m✅ docker-compose.yml structure valid ($compose_services_count services detected)\033[0m"
            fi
        fi
        
        # .env является обязательным для RemnaWave (содержит настройки БД)
        if [ ! -f "$target_dir/.env" ]; then
            echo -e "\033[1;31m❌ Critical file missing: .env\033[0m"
            echo -e "\033[38;5;244m   .env file is required for database configuration\033[0m"
            validation_errors=$((validation_errors + 1))
        else
            # Проверяем что .env содержит необходимые переменные для PostgreSQL
            local required_vars=("POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_DB")
            for var in "${required_vars[@]}"; do
                if ! grep -q "^${var}=" "$target_dir/.env" 2>/dev/null; then
                    echo -e "\033[1;33m⚠️  Warning: .env missing variable: $var\033[0m"
                fi
            done
        fi
    fi
    
    # Проверка файлов базы данных (может быть в разных форматах и с разными именами)
    local database_files_found=()
    
    # Поиск файлов базы данных более надежным способом
    # Ищем все SQL файлы и их сжатые версии
    mapfile -t database_files_found < <(
        find "$target_dir" -maxdepth 1 -type f \( \
            -name "*.sql" -o \
            -name "*.sql.gz" -o \
            -name "*.sql.bz2" -o \
            -name "*.sql.xz" \
        \) -printf '%f\n' 2>/dev/null | sort
    )
    
    # Если find не поддерживает -printf (например, на macOS), используем альтернативный метод
    if [ ${#database_files_found[@]} -eq 0 ]; then
        while IFS= read -r -d '' file; do
            database_files_found+=("$(basename "$file")")
        done < <(find "$target_dir" -maxdepth 1 -type f \( \
            -name "*.sql" -o \
            -name "*.sql.gz" -o \
            -name "*.sql.bz2" -o \
            -name "*.sql.xz" \
        \) -print0 2>/dev/null | sort -z)
    fi
    
    if [ ${#database_files_found[@]} -gt 0 ]; then
        echo -e "\033[1;32m✅ Database files found: ${database_files_found[*]}\033[0m"
        
        # Валидируем найденные файлы БД
        for db_file in "${database_files_found[@]}"; do
            local full_db_path="$target_dir/$db_file"
            
            # Если файл сжат (.gz), временно разархивируем для проверки
            if [[ "$db_file" == *.gz ]]; then
                local temp_sql="/tmp/validate_db_$$.sql"
                if gunzip -c "$full_db_path" > "$temp_sql" 2>/dev/null; then
                    if ! validate_sql_integrity "$temp_sql"; then
                        echo -e "\033[1;31m❌ Compressed database file validation failed: $db_file\033[0m"
                        validation_errors=$((validation_errors + 1))
                    fi
                    rm -f "$temp_sql"
                else
                    echo -e "\033[1;31m❌ Failed to decompress database file: $db_file\033[0m"
                    validation_errors=$((validation_errors + 1))
                fi
            else
                # Обычный SQL файл
                if ! validate_sql_integrity "$full_db_path"; then
                    echo -e "\033[1;31m❌ Database file validation failed: $db_file\033[0m"
                    validation_errors=$((validation_errors + 1))
                fi
            fi
        done
    elif [ "$backup_type" = "full" ]; then
        echo -e "\033[1;33m⚠️  Warning: No database files found in backup\033[0m"
        echo -e "\033[38;5;244m   Expected files: database.sql, db_backup.sql, or compressed variants\033[0m"
    fi
    
    # Проверка прав доступа
    if [ ! -r "$target_dir" ] || [ ! -w "$target_dir" ]; then
        echo -e "\033[1;31m❌ Insufficient permissions for target directory\033[0m"
        validation_errors=$((validation_errors + 1))
    fi
    
    # Итоговый результат
    if [ $validation_errors -eq 0 ]; then
        if [ $validation_warnings -gt 0 ]; then
            echo -e "\033[1;33m✅ Backup validation passed with $validation_warnings warning(s)\033[0m"
            log_restore_operation "Backup Validation" "SUCCESS" "Validation passed with $validation_warnings warnings"
        else
            echo -e "\033[1;32m✅ Backup validation passed\033[0m"
            log_restore_operation "Backup Validation" "SUCCESS" "All validation checks passed"
        fi
        return 0
    else
        echo -e "\033[1;31m❌ Backup validation failed ($validation_errors errors, $validation_warnings warnings)\033[0m"
        log_restore_operation "Backup Validation" "ERROR" "$validation_errors validation errors found"
        return 1
    fi
}

# Функция создания safety backup перед восстановлением
create_safety_backup() {
    local target_dir="$1"
    local app_name="$2"
    local backup_dir="$3"
    
    if [ ! -d "$target_dir" ]; then
        echo -e "\033[38;5;244m   No existing installation found, skipping safety backup\033[0m"
        log_restore_operation "Safety Backup" "INFO" "No existing installation found"
        return 0
    fi
    
    echo -e "\033[38;5;250m📝 Creating safety backup before restore...\033[0m"
    
    local safety_backup_dir="$backup_dir/safety_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$safety_backup_dir"
    
    # Создаем дамп базы данных если она работает
    if [ -f "$target_dir/docker-compose.yml" ]; then
        cd "$target_dir"
        local db_container="${app_name}-db"
        
        if docker compose ps -q "$db_container" 2>/dev/null | grep -q .; then
            echo -e "\033[38;5;244m   Creating database dump...\033[0m"
            
            local postgres_user="postgres"
            local postgres_password="postgres"
            local postgres_db="postgres"
            
            # Читаем настройки из .env если доступны
            if [ -f "$target_dir/.env" ]; then
                postgres_user=$(grep "^POSTGRES_USER=" "$target_dir/.env" | cut -d'=' -f2 2>/dev/null || echo "postgres")
                postgres_password=$(grep "^POSTGRES_PASSWORD=" "$target_dir/.env" | cut -d'=' -f2 2>/dev/null || echo "postgres")
                postgres_db=$(grep "^POSTGRES_DB=" "$target_dir/.env" | cut -d'=' -f2 2>/dev/null || echo "postgres")
            fi
            
            if docker exec -e PGPASSWORD="$postgres_password" "$db_container" \
                pg_dump -U "$postgres_user" -d "$postgres_db" --clean --create > "$safety_backup_dir/database_safety.sql" 2>/dev/null; then
                echo -e "\033[1;32m✅ Database safety backup created\033[0m"
                log_restore_operation "Database Safety Backup" "SUCCESS" "Database dump created"
            else
                echo -e "\033[1;33m⚠️  Failed to create database safety backup\033[0m"
                log_restore_operation "Database Safety Backup" "WARNING" "Failed to create database dump"
            fi
        fi
    fi
    
    # Копируем важные файлы конфигурации
    echo -e "\033[38;5;244m   Backing up configuration files...\033[0m"
    
    local files_copied=0
    for file in docker-compose.yml .env config.json settings.yml remnawave.conf; do
        if [ -f "$target_dir/$file" ]; then
            cp "$target_dir/$file" "$safety_backup_dir/" 2>/dev/null && files_copied=$((files_copied + 1))
        fi
    done
    
    # Копируем важные директории если они небольшие
    for dir in certs ssl certificates config configs custom scripts; do
        if [ -d "$target_dir/$dir" ]; then
            local dir_size=$(du -s "$target_dir/$dir" 2>/dev/null | cut -f1 || echo "999999")
            if [ "$dir_size" -lt 10240 ]; then  # меньше 10MB
                cp -r "$target_dir/$dir" "$safety_backup_dir/" 2>/dev/null && files_copied=$((files_copied + 1))
            fi
        fi
    done
    
    # Сохраняем информацию о safety backup
    echo "$safety_backup_dir" > "/tmp/safety_backup_location_$$"
    
    echo -e "\033[1;32m✅ Safety backup created ($files_copied items) at: $safety_backup_dir\033[0m"
    log_restore_operation "Safety Backup" "SUCCESS" "$files_copied items backed up to $safety_backup_dir"
    return 0
}

# Функция отката в случае неудачного восстановления
rollback_from_safety_backup() {
    local target_dir="$1"
    local app_name="$2"
    
    if [ ! -f "/tmp/safety_backup_location_$$" ]; then
        echo -e "\033[1;31m❌ No safety backup location found for rollback\033[0m"
        log_restore_operation "Rollback" "ERROR" "No safety backup location found"
        return 1
    fi
    
    local safety_backup_dir=$(cat "/tmp/safety_backup_location_$$")
    
    if [ ! -d "$safety_backup_dir" ]; then
        echo -e "\033[1;31m❌ Safety backup directory not found: $safety_backup_dir\033[0m"
        log_restore_operation "Rollback" "ERROR" "Safety backup directory not found"
        return 1
    fi
    
    echo -e "\033[38;5;250m📝 Rolling back from safety backup...\033[0m"
    log_restore_operation "Rollback" "STARTED" "Rolling back from $safety_backup_dir"
    
    # Останавливаем сервисы
    if [ -f "$target_dir/docker-compose.yml" ]; then
        cd "$target_dir"
        docker compose down 2>/dev/null
    fi
    
    # Восстанавливаем файлы из safety backup
    local files_restored=0
    for file in docker-compose.yml .env config.json settings.yml remnawave.conf; do
        if [ -f "$safety_backup_dir/$file" ]; then
            cp "$safety_backup_dir/$file" "$target_dir/" 2>/dev/null && files_restored=$((files_restored + 1))
        fi
    done
    
    # Восстанавливаем директории
    for dir in certs ssl certificates config configs custom scripts; do
        if [ -d "$safety_backup_dir/$dir" ]; then
            rm -rf "$target_dir/$dir" 2>/dev/null
            cp -r "$safety_backup_dir/$dir" "$target_dir/" 2>/dev/null && files_restored=$((files_restored + 1))
        fi
    done
    
    # Восстанавливаем базу данных если есть
    if [ -f "$safety_backup_dir/database_safety.sql" ] && [ -f "$target_dir/docker-compose.yml" ]; then
        echo -e "\033[38;5;244m   Restoring database from safety backup...\033[0m"
        
        cd "$target_dir"
        docker compose up -d "${app_name}-db" 2>/dev/null
        
        # Ждем готовности БД
        local attempts=0
        while [ $attempts -lt 15 ]; do
            if docker exec "${app_name}-db" pg_isready -U postgres >/dev/null 2>&1; then
                break
            fi
            sleep 2
            attempts=$((attempts + 1))
        done
        
        if [ $attempts -lt 15 ]; then
            if docker exec -i "${app_name}-db" psql -U postgres < "$safety_backup_dir/database_safety.sql" >/dev/null 2>&1; then
                echo -e "\033[1;32m✅ Database rolled back successfully\033[0m"
                log_restore_operation "Database Rollback" "SUCCESS" "Database restored from safety backup"
            else
                echo -e "\033[1;33m⚠️  Database rollback had issues\033[0m"
                log_restore_operation "Database Rollback" "WARNING" "Database rollback had issues"
            fi
        fi
        
        docker compose down 2>/dev/null
    fi
    
    echo -e "\033[1;32m✅ Rollback completed ($files_restored items restored)\033[0m"
    log_restore_operation "Rollback" "SUCCESS" "$files_restored items restored"
    
    # Очищаем временные файлы
    rm -f "/tmp/safety_backup_location_$$"
    
    return 0
}

# Функция проверки целостности после восстановления
restore_telegram_bots() {
    local target_dir="$1"
    local target_app_name="$2"
    local bots_dir="$target_dir/telegram-bots"
    local success_count=0
    local failed_count=0
    
    if [ ! -d "$bots_dir" ]; then
        return 0
    fi
    
    echo -e "\033[38;5;244m   Searching for Telegram bot backups...\033[0m"
    
    for bot_dir in "$bots_dir"/*; do
        if [ ! -d "$bot_dir" ]; then
            continue
        fi
        
        local bot_name=$(basename "$bot_dir")
        echo -e "\033[38;5;244m   Found bot: $bot_name\033[0m"
        
        # Проверяем что контейнер бота существует
        if ! docker ps -a --format '{{.Names}}' | grep -q "^${bot_name}$"; then
            echo -e "\033[1;33m   ⚠️  Container $bot_name not found\033[0m"
            echo -e "\033[38;5;244m      Bot needs to be created first via docker-compose\033[0m"
            echo -e "\033[38;5;244m      Volumes and configs are saved in: $bot_dir\033[0m"
            failed_count=$((failed_count + 1))
            continue
        fi
        
        # Проверяем наличие docker-compose.yml для определения метода остановки
        local bot_compose_file="/opt/remnawave/telegram-bots/$bot_name/docker-compose.yml"
        local use_compose_down=false
        
        if [ -f "$bot_compose_file" ]; then
            use_compose_down=true
        fi

        # Предупреждение перед остановкой и удалением
        echo ""
        echo -e "\033[1;33m   ⚠️  ВНИМАНИЕ! Сейчас будут выполнены следующие действия:\033[0m"
        echo ""
        if [ "$use_compose_down" = true ]; then
            echo -e "\033[38;5;244m     1. Остановка всех контейнеров бота через docker compose down\033[0m"
            echo -e "\033[38;5;244m        (это остановит: $bot_name и ${bot_name}-db)\033[0m"
        else
            echo -e "\033[38;5;244m     1. Принудительная остановка и удаление контейнеров:\033[0m"
            echo -e "\033[38;5;244m        - $bot_name\033[0m"
            echo -e "\033[38;5;244m        - ${bot_name}-db\033[0m"
        fi
        echo -e "\033[38;5;244m     2. Удаление существующих volumes:\033[0m"
        echo -e "\033[38;5;244m        - ${bot_name}-data\033[0m"
        echo -e "\033[38;5;244m        - ${bot_name}-db-data\033[0m"
        echo -e "\033[38;5;244m     3. Восстановление данных из бэкапа\033[0m"
        echo -e "\033[38;5;244m     4. Восстановление базы данных\033[0m"
        echo -e "\033[38;5;244m     5. Запуск бота с восстановленными данными\033[0m"
        echo ""
        echo -e "\033[1;33m     Все текущие данные бота будут заменены данными из бэкапа!\033[0m"
        echo ""
        
        read -p "   Продолжить восстановление бота $bot_name? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "\033[1;31m   ❌ Восстановление отменено пользователем\033[0m"
            failed_count=$((failed_count + 1))
            continue
        fi
        echo ""

        # Останавливаем и удаляем контейнеры бота
        if [ "$use_compose_down" = true ]; then
            echo -e "\033[38;5;244m   Останавливаем все контейнеры бота через docker compose down...\033[0m"
            cd "/opt/remnawave/telegram-bots/$bot_name"
            if docker compose down -v 2>/dev/null; then
                echo -e "\033[38;5;244m   ✅ Контейнеры успешно остановлены через docker compose\033[0m"
            else
                echo -e "\033[1;33m   ⚠️  docker compose down не удался, используем принудительную остановку\033[0m"
                use_compose_down=false
            fi
            cd - > /dev/null
        fi
        
        # Если compose down не сработал или файл отсутствует - принудительная остановка
        if [ "$use_compose_down" = false ]; then
            echo -e "\033[38;5;244m   Принудительно останавливаем и удаляем контейнеры...\033[0m"
            
            # Останавливаем оба контейнера
            for container in "$bot_name" "${bot_name}-db"; do
                if docker ps -aq -f name="^${container}$" | grep -q .; then
                    echo -e "\033[38;5;244m     Stopping $container...\033[0m"
                    docker stop "$container" 2>/dev/null || true
                    docker rm -f "$container" 2>/dev/null || true
                fi
            done
        fi

        # Дополнительная проверка - убедимся что контейнеры удалены
        for container in "$bot_name" "${bot_name}-db"; do
            if docker ps -aq -f name="^${container}$" | grep -q .; then
                echo -e "\033[1;33m     ⚠️  Контейнер $container все еще существует, удаляем принудительно...\033[0m"
                docker rm -f "$container" 2>/dev/null || true
            fi
        done
        
        # Восстанавливаем volumes если есть
        if [ -d "$bot_dir/volumes" ]; then
            echo -e "\033[38;5;244m   Restoring volumes...\033[0m"
            local volume_restored=false
            
            for volume_archive in "$bot_dir/volumes"/*.tar.gz; do
                if [ ! -f "$volume_archive" ]; then
                    continue
                fi
                
                local volume_name=$(basename "$volume_archive" .tar.gz)
                echo -e "\033[38;5;244m     Restoring volume: $volume_name\033[0m"
                
                # Удаляем старый volume
                docker volume rm "$volume_name" 2>/dev/null || true
                
                # Создаем новый volume
                docker volume create "$volume_name" >/dev/null 2>&1
                
                # Восстанавливаем данные
                if docker run --rm \
                    -v "$volume_name:/target" \
                    -v "$bot_dir/volumes:/source:ro" \
                    alpine \
                    sh -c "cd /target && tar -xzf /source/$(basename "$volume_archive")" >/dev/null 2>&1; then
                    echo -e "\033[38;5;244m     ✅ Volume $volume_name restored\033[0m"
                    volume_restored=true
                else
                    echo -e "\033[1;31m     ❌ Failed to restore volume $volume_name\033[0m"
                    failed_count=$((failed_count + 1))
                fi
            done
        fi
        
        # Восстанавливаем БД бота если есть дамп
        local bot_db_dump="$bot_dir/bot-database.sql.gz"
        local bot_db_container="${bot_name}-db"
        
        if [ -f "$bot_db_dump" ]; then
            echo -e "\033[38;5;244m   Found bot database dump, checking for DB container...\033[0m"
            
            if docker ps -a --format '{{.Names}}' | grep -q "^${bot_db_container}$"; then
                echo -e "\033[38;5;244m   Restoring bot database...\033[0m"
                
                # Запускаем контейнер БД бота
                docker start "$bot_db_container" >/dev/null 2>&1
                
                # Ждем готовности БД бота (используем существующую функцию)
                echo -e "\033[38;5;244m   Waiting for bot DB to be ready...\033[0m"
                local bot_db_wait=0
                local bot_db_max_wait=30
                
                until [ "$(docker inspect --format='{{.State.Health.Status}}' "$bot_db_container" 2>/dev/null)" == "healthy" ]; do
                    sleep 2
                    echo -n "."
                    bot_db_wait=$((bot_db_wait + 1))
                    if [ $bot_db_wait -gt $bot_db_max_wait ]; then
                        echo ""
                        echo -e "\033[1;33m   ⚠️  Bot DB health check timeout, proceeding anyway...\033[0m"
                        break
                    fi
                done
                
                if [ $bot_db_wait -le $bot_db_max_wait ]; then
                    echo ""
                    echo -e "\033[38;5;244m   ✓ Bot DB is healthy\033[0m"
                fi
                
                # Восстанавливаем дамп
                echo -e "\033[38;5;244m   Importing database dump...\033[0m"
                if gunzip -c "$bot_db_dump" | docker exec -i "$bot_db_container" psql -U postgres -q >/dev/null 2>&1; then
                    echo -e "\033[1;32m   ✓ Bot database restored successfully\033[0m"
                else
                    echo -e "\033[1;33m   ⚠️  Failed to restore bot database (bot may not work correctly)\033[0m"
                fi
            else
                echo -e "\033[1;33m   ⚠️  DB container $bot_db_container not found, skipping DB restore\033[0m"
            fi
        fi
        
        # Показываем информацию о переменных окружения
        if [ -f "$bot_dir/environment.json" ]; then
            echo -e "\033[38;5;244m   ℹ️  Environment variables backed up\033[0m"
            echo -e "\033[38;5;244m      Note: Environment cannot be auto-applied to existing container\033[0m"
            echo -e "\033[38;5;244m      If bot fails to start, recreate container with correct env\033[0m"
        fi
        
        # Запускаем контейнер бота
        echo -e "\033[38;5;244m   Starting $bot_name...\033[0m"
        if docker start "$bot_name" >/dev/null 2>&1; then
            # Ждем готовности бота (если есть healthcheck)
            if docker inspect --format='{{.State.Health}}' "$bot_name" 2>/dev/null | grep -q "Status"; then
                echo -e "\033[38;5;244m   Waiting for bot to be healthy...\033[0m"
                local bot_wait=0
                local bot_max_wait=15
                
                until [ "$(docker inspect --format='{{.State.Health.Status}}' "$bot_name" 2>/dev/null)" == "healthy" ]; do
                    sleep 2
                    echo -n "."
                    bot_wait=$((bot_wait + 1))
                    if [ $bot_wait -gt $bot_max_wait ]; then
                        echo ""
                        echo -e "\033[1;33m   ⚠️  Bot health check timeout, but container is running\033[0m"
                        break
                    fi
                done
                
                if [ $bot_wait -le $bot_max_wait ]; then
                    echo ""
                fi
            fi
            
            echo -e "\033[1;32m   ✅ Bot $bot_name restored and started\033[0m"
            success_count=$((success_count + 1))
        else
            echo -e "\033[1;31m   ❌ Failed to start bot $bot_name\033[0m"
            echo -e "\033[38;5;244m      Check: docker logs $bot_name\033[0m"
            failed_count=$((failed_count + 1))
        fi
        
        echo
    done
    
    # Итоговая статистика
    if [ $success_count -gt 0 ]; then
        echo -e "\033[1;32m   Summary: $success_count bot(s) restored successfully\033[0m"
    fi
    
    if [ $failed_count -gt 0 ]; then
        echo -e "\033[1;33m   Warning: $failed_count bot(s) failed or skipped\033[0m"
        return 1
    fi
    
    return 0
}

verify_restore_integrity() {
    local target_dir="$1"
    local app_name="$2"
    local backup_type="${3:-full}"
    
    echo -e "\033[38;5;250m📝 Verifying restore integrity...\033[0m"
    
    local integrity_score=0
    local max_score=10
    local issues=()
    
    # --- Динамическое определение имён контейнеров из docker-compose.yml ---
    local db_container="${app_name}-db"
    local main_container="${app_name}"
    local redis_container="${app_name}-redis"
    
    if [ -f "$target_dir/docker-compose.yml" ]; then
        # Парсим реальные container_name из compose файла
        local parsed_db parsed_main parsed_redis
        parsed_db=$(grep -E "container_name:.*db" "$target_dir/docker-compose.yml" 2>/dev/null | head -1 | sed "s/.*container_name:[[:space:]]*['\"]*//" | sed "s/['\"].*//")
        parsed_main=$(grep -E "container_name:" "$target_dir/docker-compose.yml" 2>/dev/null | grep -v -E "db|redis|subscription|caddy" | head -1 | sed "s/.*container_name:[[:space:]]*['\"]*//" | sed "s/['\"].*//")
        parsed_redis=$(grep -E "container_name:.*redis" "$target_dir/docker-compose.yml" 2>/dev/null | head -1 | sed "s/.*container_name:[[:space:]]*['\"]*//" | sed "s/['\"].*//")
        
        [ -n "$parsed_db" ] && db_container="$parsed_db"
        [ -n "$parsed_main" ] && main_container="$parsed_main"
        [ -n "$parsed_redis" ] && redis_container="$parsed_redis"
    fi
    
    echo -e "\033[38;5;244m   Detected containers: main=$main_container, db=$db_container, redis=$redis_container\033[0m"
    
    # --- Читаем DB credentials из .env ---
    local postgres_user="postgres"
    local postgres_password="postgres"
    local postgres_db="postgres"
    if [ -f "$target_dir/.env" ]; then
        postgres_user=$(grep "^POSTGRES_USER=" "$target_dir/.env" 2>/dev/null | cut -d'=' -f2 || echo "postgres")
        postgres_password=$(grep "^POSTGRES_PASSWORD=" "$target_dir/.env" 2>/dev/null | cut -d'=' -f2 || echo "postgres")
        postgres_db=$(grep "^POSTGRES_DB=" "$target_dir/.env" 2>/dev/null | cut -d'=' -f2 || echo "postgres")
    fi
    
    # ===== Проверка 1: Файлы конфигурации (2 балла) =====
    if [ -f "$target_dir/docker-compose.yml" ]; then
        integrity_score=$((integrity_score + 1))
        
        # Проверяем использование latest тега
        if grep -q "ghcr.io/remnawave/backend:latest" "$target_dir/docker-compose.yml" 2>/dev/null; then
            echo -e "\033[1;33m⚠️  WARNING: docker-compose.yml uses 'latest' tag\033[0m"
            echo -e "\033[38;5;244m   Recommended: Pin to specific version (e.g., remnawave/backend:2.2.19)\033[0m"
            issues+=("using latest tag - version not pinned")
        fi
        
        if docker compose -f "$target_dir/docker-compose.yml" config >/dev/null 2>&1; then
            integrity_score=$((integrity_score + 1))
        else
            issues+=("docker-compose.yml syntax error")
        fi
    else
        issues+=("docker-compose.yml missing")
    fi
    
    # ===== Проверка 2: Запуск сервисов (4 балла) =====
    if [ -f "$target_dir/docker-compose.yml" ]; then
        cd "$target_dir"
        
        # Проверяем, уже ли запущены сервисы, чтобы не запускать повторно
        local already_running=$(docker compose ps -q 2>/dev/null | wc -l)
        
        if [ "$already_running" -gt 0 ]; then
            echo -e "\033[38;5;244m   Services already running, checking status...\033[0m"
            integrity_score=$((integrity_score + 2))
        elif docker compose up -d >/dev/null 2>&1; then
            integrity_score=$((integrity_score + 2))
        else
            issues+=("failed to start services")
        fi
        
        # Ждём healthcheck — до 90 секунд с прогрессом
        if [ $integrity_score -ge 2 ]; then
            echo -e "\033[38;5;244m   Waiting for containers to become healthy (up to 90s)...\033[0m"
            
            local wait_elapsed=0
            local wait_max=90
            local all_healthy=false
            
            while [ $wait_elapsed -lt $wait_max ]; do
                local total_services=0
                local running_count=0
                local healthy_count=0
                
                for container_id in $(docker compose ps -q 2>/dev/null); do
                    total_services=$((total_services + 1))
                    local c_status=$(docker inspect "$container_id" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
                    local c_health=$(docker inspect "$container_id" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' 2>/dev/null || echo "unknown")
                    
                    if [ "$c_status" = "running" ]; then
                        running_count=$((running_count + 1))
                        # Контейнер без healthcheck считается healthy если running
                        if [ "$c_health" = "healthy" ] || [ "$c_health" = "no-healthcheck" ]; then
                            healthy_count=$((healthy_count + 1))
                        fi
                    fi
                done
                
                # Все сервисы healthy — можно выходить
                if [ "$total_services" -gt 0 ] && [ "$healthy_count" -eq "$total_services" ]; then
                    all_healthy=true
                    break
                fi
                
                # Прогресс каждые 15 секунд
                if [ $((wait_elapsed % 15)) -eq 0 ] && [ $wait_elapsed -gt 0 ]; then
                    echo -e "\033[38;5;244m   ... ${wait_elapsed}s elapsed: $running_count/$total_services running, $healthy_count/$total_services healthy\033[0m"
                fi
                
                sleep 3
                wait_elapsed=$((wait_elapsed + 3))
            done
            
            # Финальная оценка
            local final_total=0
            local final_running=0
            local final_healthy=0
            local container_details=""
            
            for container_id in $(docker compose ps -q 2>/dev/null); do
                final_total=$((final_total + 1))
                local c_name=$(docker inspect "$container_id" --format '{{.Name}}' 2>/dev/null | sed 's|^/||')
                local c_status=$(docker inspect "$container_id" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
                local c_health=$(docker inspect "$container_id" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' 2>/dev/null || echo "unknown")
                
                if [ "$c_status" = "running" ]; then
                    final_running=$((final_running + 1))
                fi
                if [ "$c_health" = "healthy" ] || [ "$c_health" = "no-healthcheck" ]; then
                    final_healthy=$((final_healthy + 1))
                fi
                
                # Собираем статус для отчёта
                local status_icon="❌"
                [ "$c_status" = "running" ] && status_icon="🟡"
                [ "$c_health" = "healthy" ] || [ "$c_health" = "no-healthcheck" ] && [ "$c_status" = "running" ] && status_icon="🟢"
                container_details="${container_details}\n   ${status_icon} ${c_name}: status=${c_status}, health=${c_health}"
            done
            
            echo -e "\033[38;5;244m   Container status after ${wait_elapsed}s:${container_details}\033[0m"
            
            if [ "$final_total" -gt 0 ] && [ "$final_healthy" -eq "$final_total" ]; then
                integrity_score=$((integrity_score + 2))
                echo -e "\033[1;32m   ✅ All $final_total services healthy\033[0m"
            elif [ "$final_running" -eq "$final_total" ] && [ "$final_total" -gt 0 ]; then
                integrity_score=$((integrity_score + 1))
                issues+=("all services running but not all healthy ($final_healthy/$final_total healthy)")
            elif [ "$final_running" -gt 0 ]; then
                integrity_score=$((integrity_score + 1))
                issues+=("some services not running ($final_running/$final_total running, $final_healthy healthy)")
            else
                issues+=("no services running after ${wait_elapsed}s")
            fi
        fi
    fi
    
    # ===== Проверка 3: База данных (2 балла) =====
    if [ "$backup_type" = "full" ] || [ "$backup_type" = "database" ]; then
        if docker exec -e PGPASSWORD="$postgres_password" "$db_container" \
            pg_isready -U "$postgres_user" -d "$postgres_db" >/dev/null 2>&1; then
            integrity_score=$((integrity_score + 1))
            
            # Проверяем что в БД есть данные
            local table_count=$(docker exec -e PGPASSWORD="$postgres_password" "$db_container" \
                psql -U "$postgres_user" -d "$postgres_db" -t -c \
                "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ' || echo "0")
            
            if [ "$table_count" -gt 0 ]; then
                integrity_score=$((integrity_score + 1))
                echo -e "\033[38;5;244m   ✅ Database has $table_count tables\033[0m"
            else
                issues+=("database appears empty")
            fi
        else
            issues+=("database not responding (container: $db_container)")
        fi
    fi
    
    # ===== Проверка 4: Сеть и доступность приложения (2 балла) =====
    if docker exec "$main_container" echo "test" >/dev/null 2>&1; then
        integrity_score=$((integrity_score + 1))
        
        # Проверяем внутреннюю связность через hostname из compose
        if docker exec "$main_container" sh -c "nc -z ${db_container} 5432 2>/dev/null || curl -sf http://${db_container}:5432 2>/dev/null || pg_isready -h ${db_container} -p 5432 2>/dev/null" >/dev/null 2>&1; then
            integrity_score=$((integrity_score + 1))
        else
            # Пробуем альтернативный способ — через hostname
            local db_hostname="${app_name}-db"
            if docker exec "$main_container" sh -c "cat /etc/hosts | grep -q '${db_hostname}' 2>/dev/null" >/dev/null 2>&1; then
                integrity_score=$((integrity_score + 1))
                echo -e "\033[38;5;244m   ✅ Network connectivity verified via hosts\033[0m"
            else
                issues+=("network connectivity to database unverified")
            fi
        fi
    else
        issues+=("main application container not responding (container: $main_container)")
    fi
    
    # ===== Результат =====
    local percentage=$((integrity_score * 100 / max_score))
    
    if [ ${#issues[@]} -gt 0 ]; then
        echo -e "\033[38;5;244m   Issues detected:\033[0m"
        for issue in "${issues[@]}"; do
            echo -e "\033[38;5;244m   - $issue\033[0m"
        done
    fi
    
    if [ $percentage -ge 70 ]; then
        echo -e "\033[1;32m✅ Restore integrity check passed: $integrity_score/$max_score ($percentage%)\033[0m"
        log_restore_operation "Integrity Check" "SUCCESS" "$integrity_score/$max_score ($percentage%)"
        return 0
    elif [ $percentage -ge 50 ]; then
        echo -e "\033[1;33m⚠️  Restore integrity check warning: $integrity_score/$max_score ($percentage%)\033[0m"
        log_restore_operation "Integrity Check" "WARNING" "$integrity_score/$max_score ($percentage%) - ${#issues[@]} issues"
        return 1
    else
        echo -e "\033[1;31m❌ Restore integrity check failed: $integrity_score/$max_score ($percentage%)\033[0m"
        log_restore_operation "Integrity Check" "ERROR" "$integrity_score/$max_score ($percentage%) - ${#issues[@]} issues"
        return 2
    fi
}

# ===== END RESTORE VALIDATION AND SAFETY FUNCTIONS =====

schedule_create_backup_script() {
    local config_dir="$(dirname "$BACKUP_CONFIG_FILE")"
    mkdir -p "$config_dir"
    
    # Проверяем и исправляем поврежденный конфиг если нужно
    validate_and_fix_backup_config
    
    cat > "$BACKUP_SCRIPT_FILE" <<'BACKUP_SCRIPT_EOF'
#!/bin/bash

# Backup Script Version - used for compatibility checking
BACKUP_SCRIPT_VERSION="1.3.0"
BACKUP_SCRIPT_DATE="$(date '+%Y-%m-%d')"

# Читаем конфигурацию backup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/backup-config.json"
LOG_FILE="$SCRIPT_DIR/logs/backup.log"

# Функция логирования
log_message() {
    # Создаем директорию для логов если не существует
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Функция для проверки доступности команд
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_message "ERROR: Required command '$1' not found"
        exit 1
    fi
}

# Функция ожидания готовности БД через healthcheck
wait_for_db_health() {
    local container_name="$1"
    local max_wait="${2:-60}"
    local wait_count=0
    
    log_message "Waiting for database to be healthy..."
    
    until [ "$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)" == "healthy" ]; do
        sleep 2
        echo -n "."
        wait_count=$((wait_count + 1))
        
        if [ $wait_count -gt $max_wait ]; then
            log_message "ERROR: Database health check timeout after $((max_wait * 2)) seconds"
            return 1
        fi
        
        # Проверяем что контейнер вообще существует и запущен
        if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            log_message "ERROR: Container $container_name is not running"
            return 1
        fi
    done
    
    echo ""
    log_message "Database is healthy and ready"
    return 0
}

# Функция проверки что контейнер запущен
check_container_running() {
    local container_name="$1"
    
    if ! docker inspect "$container_name" > /dev/null 2>&1; then
        log_message "ERROR: Container '$container_name' not found"
        return 1
    fi
    
    if ! docker container inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q "true"; then
        log_message "ERROR: Container '$container_name' is not running"
        return 1
    fi
    
    return 0
}

# Проверяем необходимые команды
check_command docker
check_command jq

# ===== ПАРСИНГ АРГУМЕНТОВ КОМАНДНОЙ СТРОКИ =====
# Позволяет переопределять настройки из конфига при ручном запуске

CLI_DATA_ONLY=false
CLI_NO_COMPRESS=false
CLI_NO_REVERSE_PROXY=false
CLI_QUIET=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --data-only)
            CLI_DATA_ONLY=true
            ;;
        --no-compress)
            CLI_NO_COMPRESS=true
            ;;
        --no-reverse-proxy)
            CLI_NO_REVERSE_PROXY=true
            ;;
        --quiet|-q)
            CLI_QUIET=true
            ;;
        --help|-h)
            echo "Remnawave Backup Script v$BACKUP_SCRIPT_VERSION"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --data-only         Backup database only (skip configs)"
            echo "  --no-compress       Create uncompressed backup"
            echo "  --no-reverse-proxy  Skip Caddy/Traefik backup"
            echo "  --quiet, -q         Minimal output (for cron)"
            echo "  --help, -h          Show this help"
            echo ""
            echo "Without arguments, uses settings from backup-config.json"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Определяем переменные из конфигурации
if [ ! -f "$CONFIG_FILE" ]; then
    log_message "ERROR: Backup configuration not found: $CONFIG_FILE"
    exit 1
fi

# Проверяем валидность JSON конфигурации
if ! jq . "$CONFIG_FILE" >/dev/null 2>&1; then
    log_message "ERROR: Backup configuration file is corrupted: $CONFIG_FILE"
    log_message "Please run the main script to recreate configuration"
    exit 1
fi

APP_NAME=$(jq -r '.app_name // "remnawave"' "$CONFIG_FILE")
APP_DIR="/opt/$APP_NAME"
BACKUP_DIR="$APP_DIR/backups"
TEMP_BACKUP_ROOT="/tmp/${APP_NAME}_backup"
BACKUP_TYPE=$(jq -r '.backup_type // "sql_dump"' "$CONFIG_FILE")
COMPRESS_ENABLED=$(jq -r '.compression.enabled // true' "$CONFIG_FILE")
TELEGRAM_ENABLED=$(jq -r '.telegram.enabled // false' "$CONFIG_FILE")
INCLUDE_REVERSE_PROXY=$(jq -r '.include_reverse_proxy // true' "$CONFIG_FILE")
INCLUDE_CONFIGS=true

# ===== ПРИМЕНЯЕМ CLI АРГУМЕНТЫ (OVERRIDE КОНФИГА) =====
if [ "$CLI_DATA_ONLY" = true ]; then
    INCLUDE_CONFIGS=false
    log_message "CLI override: --data-only (database only, no configs)"
fi

if [ "$CLI_NO_COMPRESS" = true ]; then
    COMPRESS_ENABLED=false
    log_message "CLI override: --no-compress"
fi

if [ "$CLI_NO_REVERSE_PROXY" = true ]; then
    INCLUDE_REVERSE_PROXY=false
    log_message "CLI override: --no-reverse-proxy"
fi

# Создаем директории для бэкапов
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_BACKUP_ROOT"

# Генерируем имя бэкапа
timestamp=$(date +%Y%m%d_%H%M%S)
backup_name="remnawave_scheduled_${timestamp}"
temp_backup_dir="$TEMP_BACKUP_ROOT/temp_$timestamp"

log_message "Starting scheduled backup..."
log_message "Creating full system backup: $backup_name"

# Создаем временную директорию для сборки бэкапа
mkdir -p "$temp_backup_dir"

# Читаем параметры БД из .env файла (нужны для всех типов бэкапа)
postgres_user="postgres"
postgres_password="postgres"
postgres_db="postgres"

if [ -f "$APP_DIR/.env" ]; then
    postgres_user=$(grep "^POSTGRES_USER=" "$APP_DIR/.env" | cut -d'=' -f2 2>/dev/null | sed 's/^"//;s/"$//' || echo "postgres")
    postgres_password=$(grep "^POSTGRES_PASSWORD=" "$APP_DIR/.env" | cut -d'=' -f2 2>/dev/null | sed 's/^"//;s/"$//' || echo "postgres")
    postgres_db=$(grep "^POSTGRES_DB=" "$APP_DIR/.env" | cut -d'=' -f2 2>/dev/null | sed 's/^"//;s/"$//' || echo "postgres")
fi

db_container="${APP_NAME}-db"

# Проверяем что контейнер существует и запущен
if ! check_container_running "$db_container"; then
    log_message "ERROR: Database container is not ready"
    rm -rf "$temp_backup_dir"
    exit 1
fi

# Дополнительная проверка готовности через pg_isready
if ! docker exec "$db_container" pg_isready -U "$postgres_user" >/dev/null 2>&1; then
    log_message "ERROR: Database is not accepting connections"
    rm -rf "$temp_backup_dir"
    exit 1
fi

# Шаг 1: Экспорт базы данных (в зависимости от типа бэкапа)
log_message "Step 1: Backing up database (method: $BACKUP_TYPE)..."

case "$BACKUP_TYPE" in
    "sql_dump")
        log_message "Using SQL dump method..."
        database_file="$temp_backup_dir/database.sql"
        
        if docker exec -e PGPASSWORD="$postgres_password" "$db_container" \
            pg_dump -U "$postgres_user" -d "$postgres_db" --clean --if-exists > "$database_file" 2>/dev/null; then
            
            db_size=$(du -sh "$database_file" | cut -f1)
            log_message "Database SQL dump created successfully ($db_size)"
        else
            log_message "ERROR: Database SQL dump failed"
            rm -rf "$temp_backup_dir"
            exit 1
        fi
        ;;
        
    "volume")
        log_message "Using volume backup method..."
        
        # Останавливаем контейнер БД для консистентности
        log_message "Stopping database container for consistent backup..."
        docker stop "$db_container" >/dev/null 2>&1
        
        # Находим volume базы данных
        db_volume="${APP_NAME}-db-data"
        
        # Создаем директорию для volume
        volume_backup_dir="$temp_backup_dir/database-volume"
        mkdir -p "$volume_backup_dir"
        
        # Копируем данные из volume
        log_message "Copying database volume data..."
        docker run --rm \
            -v "$db_volume:/source:ro" \
            -v "$volume_backup_dir:/backup" \
            alpine \
            sh -c "cd /source && cp -a . /backup/" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            db_size=$(du -sh "$volume_backup_dir" | cut -f1)
            log_message "Database volume backup created successfully ($db_size)"
        else
            log_message "ERROR: Database volume backup failed"
            docker start "$db_container" >/dev/null 2>&1
            rm -rf "$temp_backup_dir"
            exit 1
        fi
        
        # Запускаем контейнер обратно
        log_message "Starting database container..."
        docker start "$db_container" >/dev/null 2>&1
        sleep 3
        ;;
        
    "both")
        log_message "Using both SQL dump and volume backup methods..."
        
        # Сначала SQL dump (без остановки контейнера)
        database_file="$temp_backup_dir/database.sql"
        log_message "Creating SQL dump..."
        
        if docker exec -e PGPASSWORD="$postgres_password" "$db_container" \
            pg_dump -U "$postgres_user" -d "$postgres_db" --clean --if-exists > "$database_file" 2>/dev/null; then
            
            sql_size=$(du -sh "$database_file" | cut -f1)
            log_message "SQL dump created successfully ($sql_size)"
        else
            log_message "ERROR: SQL dump failed"
            rm -rf "$temp_backup_dir"
            exit 1
        fi
        
        # Затем volume (с остановкой)
        log_message "Stopping database container for volume backup..."
        docker stop "$db_container" >/dev/null 2>&1
        
        db_volume="${APP_NAME}-db-data"
        volume_backup_dir="$temp_backup_dir/database-volume"
        mkdir -p "$volume_backup_dir"
        
        log_message "Copying database volume data..."
        docker run --rm \
            -v "$db_volume:/source:ro" \
            -v "$volume_backup_dir:/backup" \
            alpine \
            sh -c "cd /source && cp -a . /backup/" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            vol_size=$(du -sh "$volume_backup_dir" | cut -f1)
            log_message "Volume backup created successfully ($vol_size)"
        else
            log_message "ERROR: Volume backup failed"
            docker start "$db_container" >/dev/null 2>&1
            rm -rf "$temp_backup_dir"
            exit 1
        fi
        
        log_message "Starting database container..."
        docker start "$db_container" >/dev/null 2>&1
        sleep 3
        
        db_size="SQL: $sql_size, Volume: $vol_size"
        ;;
        
    *)
        log_message "ERROR: Unknown backup type: $BACKUP_TYPE"
        rm -rf "$temp_backup_dir"
        exit 1
        ;;
esac

# Шаг 2: Копирование конфигурационных файлов (если не --data-only)
if [ "$INCLUDE_CONFIGS" = true ]; then
    log_message "Step 2: Creating application configuration backup..."

    # Копируем всю структуру кроме некоторых директорий
    log_message "Copying application configuration files..."

    if command -v rsync >/dev/null 2>&1; then
        # rsync доступен, используем его с правильными исключениями
        rsync -av \
            --exclude='backups/' \
            --exclude='logs/' \
            --exclude='temp/' \
            --exclude='*.log' \
            --exclude='*.tmp' \
            --exclude='.git/' \
            "$APP_DIR/" \
            "$temp_backup_dir/" 2>/dev/null
        copy_result=$?
    else
        # Используем улучшенный cp метод без рекурсии
        log_message "rsync not available, using selective copy method"
        copy_result=0
        
        # Копируем файлы по одному, исключая проблемные директории
        find "$APP_DIR" -maxdepth 1 -type f \( \
            -name "*.json" -o \
            -name "*.yml" -o \
            -name "*.yaml" -o \
            -name "*.env*" -o \
            -name "*.conf" -o \
            -name "*.ini" -o \
            -name "*.sh" -o \
            -name "docker-compose*" \
        \) -exec cp {} "$temp_backup_dir/" \; 2>/dev/null || true
        
        # Копируем важные директории если они существуют (исключая backups, logs, temp)
        for dir in certs ssl certificates config configs custom scripts; do
            if [ -d "$APP_DIR/$dir" ]; then
                cp -r "$APP_DIR/$dir" "$temp_backup_dir/" 2>/dev/null || true
            fi
        done
        
        # Проверяем что хотя бы docker-compose.yml скопирован
        if [ ! -f "$temp_backup_dir/docker-compose.yml" ]; then
            copy_result=1
            log_message "ERROR: Critical file docker-compose.yml not found or failed to copy"
        fi
    fi

    if [ $copy_result -eq 0 ]; then
        app_files_count=$(find "$temp_backup_dir" -type f | wc -l)
        log_message "Application files copied successfully ($app_files_count files)"
        
        # Подменяем latest на конкретную версию в docker-compose.yml
        if [ -f "$temp_backup_dir/docker-compose.yml" ]; then
            # Получаем текущую версию панели
            panel_version=$(docker exec "${APP_NAME}" awk -F'"' '/"version"/{print $4; exit}' package.json 2>/dev/null || echo "unknown")
            
            if [ "$panel_version" != "unknown" ] && [ -n "$panel_version" ]; then
                log_message "Pinning panel version to $panel_version in docker-compose.yml"
                
                # Создаем временный файл с подмененной версией
                sed "s|image: remnawave/backend[:|$].*|image: remnawave/backend:$panel_version|g" \
                    "$temp_backup_dir/docker-compose.yml" > "$temp_backup_dir/docker-compose.yml.tmp"
                
                # Проверяем что подмена прошла успешно
                if [ -f "$temp_backup_dir/docker-compose.yml.tmp" ]; then
                    mv "$temp_backup_dir/docker-compose.yml.tmp" "$temp_backup_dir/docker-compose.yml"
                    log_message "Version pinned successfully: remnawave/backend -> remnawave/backend:$panel_version"
                else
                    log_message "WARNING: Failed to pin version, keeping original docker-compose.yml"
                fi
            else
                log_message "WARNING: Could not determine panel version, docker-compose.yml will use 'latest' tag"
            fi
        fi
    else
        log_message "ERROR: Failed to copy application files"
        rm -rf "$temp_backup_dir"
        exit 1
    fi
else
    log_message "Step 2: Skipping configuration backup (--data-only mode)"
fi

# Шаги 2.5-2.7 и 3 выполняются только если не --data-only
if [ "$INCLUDE_CONFIGS" = true ]; then

# Шаг 2.5: Бэкап Telegram ботов (если найдены)
log_message "Step 2.5: Checking for Telegram bot containers..."

# Функция бекапа Telegram бота
backup_telegram_bot() {
    local bot_name="$1"
    
    if docker ps --format '{{.Names}}' | grep -q "^${bot_name}$"; then
        log_message "Found Telegram bot: $bot_name, backing up..."
        
        # Создаем директорию для бота
        local bot_backup_dir="$temp_backup_dir/telegram-bots/$bot_name"
        mkdir -p "$bot_backup_dir"
        
        # Получаем информацию о контейнере
        local image=$(docker inspect --format='{{.Config.Image}}' "$bot_name" 2>/dev/null || echo "unknown")
        local created=$(docker inspect --format='{{.Created}}' "$bot_name" 2>/dev/null || echo "unknown")
        
        # Сохраняем метаданные
        cat > "$bot_backup_dir/bot-info.json" <<BOT_INFO_EOF
{
    "name": "$bot_name",
    "image": "$image",
    "created": "$created",
    "backup_time": "$(date -Iseconds)"
}
BOT_INFO_EOF
        
        # Бэкапим переменные окружения (без секретов в логах)
        docker inspect "$bot_name" --format='{{json .Config.Env}}' > "$bot_backup_dir/environment.json" 2>/dev/null || true
        
        # Проверяем наличие отдельного контейнера БД для бота
        local bot_db_container="${bot_name}-db"
        if docker ps --format '{{.Names}}' | grep -q "^${bot_db_container}$"; then
            log_message "  Found separate DB container: $bot_db_container, backing up database..."
            
            # Бэкапим БД бота через pg_dumpall
            local bot_db_dump="$bot_backup_dir/bot-database.sql.gz"
            if docker exec -t "$bot_db_container" pg_dumpall -c -U postgres 2>/dev/null | gzip -9 > "$bot_db_dump"; then
                log_message "  ✓ Bot database backed up successfully"
            else
                log_message "  WARNING: Failed to backup bot database from $bot_db_container"
            fi
        fi
        
        # Бэкапим volumes если есть
        local volumes=$(docker inspect "$bot_name" --format='{{range .Mounts}}{{.Name}},{{end}}' 2>/dev/null | sed 's/,$//')
        if [ -n "$volumes" ]; then
            log_message "  Backing up bot volumes: $volumes"
            mkdir -p "$bot_backup_dir/volumes"
            
            IFS=',' read -ra VOL_ARRAY <<< "$volumes"
            for vol in "${VOL_ARRAY[@]}"; do
                if [ -n "$vol" ]; then
                    docker run --rm -v "$vol":/source -v "$bot_backup_dir/volumes":/backup \
                        alpine tar czf "/backup/${vol}.tar.gz" -C /source . 2>/dev/null || \
                        log_message "  WARNING: Failed to backup volume $vol"
                fi
            done
        fi
        
        log_message "  Telegram bot $bot_name backup completed"
        return 0
    fi
    return 1
}

# Проверяем известные имена Telegram ботов
bot_found=false
for bot_variant in "${APP_NAME}-telegram-shop" "${APP_NAME}-tg-shop" "${APP_NAME}-telegram-bot" "${APP_NAME}-bot"; do
    if backup_telegram_bot "$bot_variant"; then
        bot_found=true
    fi
done

if [ "$bot_found" = false ]; then
    log_message "No Telegram bot containers found (checked ${APP_NAME}-telegram-shop, ${APP_NAME}-tg-shop variants)"
else
    log_message "Telegram bot backup completed"
fi

# Шаг 2.6: Бэкап Caddy (если включен reverse proxy и Caddy установлен)
INCLUDE_REVERSE_PROXY=$(jq -r '.include_reverse_proxy // true' "$CONFIG_FILE")
CADDY_DIR="/opt/caddy-remnawave"

if [ "$INCLUDE_REVERSE_PROXY" = "true" ] && [ -d "$CADDY_DIR" ]; then
    log_message "Step 2.6: Backing up Caddy configuration..."
    mkdir -p "$temp_backup_dir/caddy"
    
    caddy_files_count=0
    for caddy_file in "$CADDY_DIR"/*.yml "$CADDY_DIR"/*.yaml "$CADDY_DIR"/.env \
                      "$CADDY_DIR"/Caddyfile "$CADDY_DIR"/caddy-credentials.txt \
                      "$CADDY_DIR"/docker-compose.yml; do
        if [ -f "$caddy_file" ]; then
            cp "$caddy_file" "$temp_backup_dir/caddy/" 2>/dev/null && caddy_files_count=$((caddy_files_count + 1))
        fi
    done
    
    if [ $caddy_files_count -gt 0 ]; then
        # Определяем режим Caddy
        local caddy_mode="simple"
        if grep -q "security" "$CADDY_DIR/Caddyfile" 2>/dev/null; then
            caddy_mode="secure"
        fi
        echo "caddy_mode=$caddy_mode" > "$temp_backup_dir/caddy/caddy-info.txt"
        log_message "Caddy backed up ($caddy_files_count files, mode: $caddy_mode)"
    else
        log_message "WARNING: Caddy directory exists but no config files found"
        rmdir "$temp_backup_dir/caddy" 2>/dev/null || true
    fi
elif [ "$INCLUDE_REVERSE_PROXY" = "true" ]; then
    log_message "Caddy not installed at $CADDY_DIR, skipping"
fi

# Шаг 2.7: Бэкап Traefik (если включен reverse proxy и Traefik установлен)
# Проверяем стандартные пути для Traefik
TRAEFIK_DIR=""
for traefik_path in "/opt/traefik" "/opt/traefik-remnawave" "/etc/traefik"; do
    if [ -d "$traefik_path" ]; then
        TRAEFIK_DIR="$traefik_path"
        break
    fi
done

if [ "$INCLUDE_REVERSE_PROXY" = "true" ] && [ -n "$TRAEFIK_DIR" ] && [ -d "$TRAEFIK_DIR" ]; then
    log_message "Step 2.7: Backing up Traefik configuration from $TRAEFIK_DIR..."
    mkdir -p "$temp_backup_dir/traefik"
    
    traefik_files_count=0
    for traefik_file in "$TRAEFIK_DIR"/*.yml "$TRAEFIK_DIR"/*.yaml "$TRAEFIK_DIR"/*.toml \
                        "$TRAEFIK_DIR"/.env "$TRAEFIK_DIR"/docker-compose.yml \
                        "$TRAEFIK_DIR"/traefik.yml "$TRAEFIK_DIR"/traefik.toml; do
        if [ -f "$traefik_file" ]; then
            cp "$traefik_file" "$temp_backup_dir/traefik/" 2>/dev/null && traefik_files_count=$((traefik_files_count + 1))
        fi
    done
    
    # Бэкапим динамические конфиги если есть
    if [ -d "$TRAEFIK_DIR/dynamic" ]; then
        cp -r "$TRAEFIK_DIR/dynamic" "$temp_backup_dir/traefik/" 2>/dev/null || true
        traefik_files_count=$((traefik_files_count + $(find "$TRAEFIK_DIR/dynamic" -type f 2>/dev/null | wc -l)))
    fi
    
    if [ $traefik_files_count -gt 0 ]; then
        echo "traefik_path=$TRAEFIK_DIR" > "$temp_backup_dir/traefik/traefik-info.txt"
        log_message "Traefik backed up ($traefik_files_count files from $TRAEFIK_DIR)"
    else
        log_message "WARNING: Traefik directory exists but no config files found"
        rmdir "$temp_backup_dir/traefik" 2>/dev/null || true
    fi
elif [ "$INCLUDE_REVERSE_PROXY" = "true" ]; then
    log_message "Traefik not installed, skipping"
fi

if [ "$INCLUDE_REVERSE_PROXY" != "true" ]; then
    log_message "Reverse proxy backup disabled in config, skipping Caddy/Traefik"
fi

# Шаг 3: Добавляем скрипт управления
log_message "Step 3: Including management script..."

script_source="/usr/local/bin/$APP_NAME"
if [ -f "$script_source" ]; then
    cp "$script_source" "$temp_backup_dir/install-script.sh"
    log_message "Management script included"
else
    log_message "WARNING: Management script not found at $script_source"
fi

fi  # Конец if [ "$INCLUDE_CONFIGS" = true ]

# Шаг 4: Создаем скрипт восстановления для volume (если используется volume backup)
if [ "$BACKUP_TYPE" = "volume" ] || [ "$BACKUP_TYPE" = "both" ]; then
    log_message "Step 4: Creating volume restore script..."
    
    cat > "$temp_backup_dir/restore-volume.sh" << 'RESTORE_SCRIPT_EOF'
#!/bin/bash
# Remnawave Volume Restore Script
# This script restores database from volume backup

set -e

APP_NAME="__APP_NAME__"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==================================="
echo "Remnawave Volume Restore"
echo "==================================="
echo

# Проверяем что volume backup существует
if [ ! -d "$SCRIPT_DIR/database-volume" ]; then
    echo "ERROR: database-volume directory not found"
    exit 1
fi

# Останавливаем контейнер
echo "Stopping database container..."
docker stop "${APP_NAME}-db" 2>/dev/null || true

# Удаляем старый volume (с подтверждением)
echo
echo "WARNING: This will DELETE existing database!"
read -p "Continue? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled"
    docker start "${APP_NAME}-db" 2>/dev/null || true
    exit 1
fi

echo "Removing old volume..."
docker volume rm "${APP_NAME}-db-data" 2>/dev/null || true

# Создаем новый volume
echo "Creating new volume..."
docker volume create "${APP_NAME}-db-data"

# Восстанавливаем данные
echo "Restoring database volume..."
docker run --rm \
    -v "${APP_NAME}-db-data:/target" \
    -v "$SCRIPT_DIR/database-volume:/source:ro" \
    alpine \
    sh -c "cd /target && cp -a /source/. ."

if [ $? -eq 0 ]; then
    echo "Volume restored successfully"
else
    echo "ERROR: Volume restore failed"
    exit 1
fi

# Запускаем контейнер
echo "Starting database container..."
docker start "${APP_NAME}-db"

echo
echo "Waiting for database to be ready (checking healthcheck)..."

# Функция ожидания здоровья БД
wait_for_db_health() {
    local container_name="\$1"
    local max_wait="\${2:-60}"
    local wait_count=0
    
    until [ "\$(docker inspect --format='{{.State.Health.Status}}' "\$container_name" 2>/dev/null)" == "healthy" ]; do
        sleep 2
        wait_count=\$((wait_count + 1))
        if [ \$wait_count -gt \$max_wait ]; then
            return 1
        fi
    done
    return 0
}

if wait_for_db_health "${APP_NAME}-db" 30; then
    echo "✅ Database restored successfully!"
else
    echo "⚠️  Database container started but healthcheck timeout"
    echo "   Check logs: docker logs ${APP_NAME}-db"
    echo "   Current status: \$(docker inspect --format='{{.State.Health.Status}}' "${APP_NAME}-db" 2>/dev/null || echo 'unknown')"
fi

# Восстановление Telegram ботов (если есть)
if [ -d "$SCRIPT_DIR/telegram-bots" ]; then
    echo
    echo "==================================="
    echo "Restoring Telegram Bots"
    echo "==================================="
    echo
    
    for bot_dir in "$SCRIPT_DIR/telegram-bots"/*; do
        if [ ! -d "$bot_dir" ]; then
            continue
        fi
        
        bot_name=\$(basename "$bot_dir")
        echo "Found bot: $bot_name"
        
        # Проверяем что контейнер бота существует
        if ! docker ps -a --format '{{.Names}}' | grep -q "^${bot_name}$"; then
            echo "⚠️  Container $bot_name not found, skipping restore"
            echo "   Create container first using docker-compose"
            continue
        fi
        
        # Проверяем наличие docker-compose.yml для определения метода остановки
        bot_compose_file="/opt/remnawave/telegram-bots/\$bot_name/docker-compose.yml"
        use_compose_down=false
        
        if [ -f "\$bot_compose_file" ]; then
            use_compose_down=true
        fi

        # Предупреждение перед остановкой и удалением
        echo ""
        echo "⚠️  ВНИМАНИЕ! Сейчас будут выполнены следующие действия:"
        echo ""
        if [ "\$use_compose_down" = "true" ]; then
            echo "  1. Остановка всех контейнеров бота через docker compose down"
            echo "     (это остановит: \$bot_name и \${bot_name}-db)"
        else
            echo "  1. Принудительная остановка и удаление контейнеров:"
            echo "     - \$bot_name"
            echo "     - \${bot_name}-db"
        fi
        echo "  2. Удаление существующих volumes:"
        echo "     - \${bot_name}-data"
        echo "     - \${bot_name}-db-data"
        echo "  3. Восстановление данных из бэкапа"
        echo "  4. Восстановление базы данных"
        echo "  5. Запуск бота с восстановленными данными"
        echo ""
        echo "Все текущие данные бота будут заменены данными из бэкапа!"
        echo ""
        
        read -p "Продолжить восстановление бота \$bot_name? (y/n): " confirm
        if [[ ! "\$confirm" =~ ^[Yy]$ ]]; then
            echo "❌ Восстановление отменено пользователем"
            continue
        fi
        echo ""

        # Останавливаем и удаляем контейнеры бота
        if [ "\$use_compose_down" = "true" ]; then
            echo "  Останавливаем все контейнеры бота через docker compose down..."
            cd "/opt/remnawave/telegram-bots/\$bot_name"
            if docker compose down -v 2>/dev/null; then
                echo "  ✅ Контейнеры успешно остановлены через docker compose"
            else
                echo "  ⚠️  docker compose down не удался, используем принудительную остановку"
                use_compose_down=false
            fi
            cd - > /dev/null
        fi
        
        # Если compose down не сработал или файл отсутствует - принудительная остановка
        if [ "\$use_compose_down" = "false" ]; then
            echo "  Принудительно останавливаем и удаляем контейнеры..."
            
            # Останавливаем оба контейнера
            for container in "\$bot_name" "\${bot_name}-db"; do
                if docker ps -aq -f name="^\${container}$" | grep -q .; then
                    echo "    Stopping \$container..."
                    docker stop "\$container" 2>/dev/null || true
                    docker rm -f "\$container" 2>/dev/null || true
                fi
            done
        fi

        # Дополнительная проверка - убедимся что контейнеры удалены
        for container in "\$bot_name" "\${bot_name}-db"; do
            if docker ps -aq -f name="^\${container}$" | grep -q .; then
                echo "    ⚠️  Контейнер \$container все еще существует, удаляем принудительно..."
                docker rm -f "\$container" 2>/dev/null || true
            fi
        done
        
        # Восстанавливаем БД бота если есть дамп
        bot_db_dump="$bot_dir/bot-database.sql.gz"
        bot_db_container="${bot_name}-db"
        
        if [ -f "$bot_db_dump" ]; then
            echo "  Found bot database dump"
            
            if docker ps -a --format '{{.Names}}' | grep -q "^${bot_db_container}$"; then
                echo "  Restoring bot database..."
                
                # Запускаем контейнер БД бота
                docker start "$bot_db_container" 2>/dev/null || true
                
                # Ждем готовности БД бота
                echo "  Waiting for bot DB to be ready..."
                bot_db_wait=0
                bot_db_max_wait=30
                
                until [ "\$(docker inspect --format='{{.State.Health.Status}}' "$bot_db_container" 2>/dev/null)" == "healthy" ]; do
                    sleep 2
                    bot_db_wait=\$((bot_db_wait + 1))
                    if [ \$bot_db_wait -gt \$bot_db_max_wait ]; then
                        echo "  ⚠️  Bot DB health check timeout"
                        break
                    fi
                done
                
                if [ \$bot_db_wait -le \$bot_db_max_wait ]; then
                    echo "  ✓ Bot DB is healthy"
                fi
                
                # Восстанавливаем дамп
                echo "  Importing database dump..."
                if gunzip -c "$bot_db_dump" | docker exec -i "$bot_db_container" psql -U postgres -q >/dev/null 2>&1; then
                    echo "  ✅ Bot database restored"
                else
                    echo "  ⚠️  Failed to restore bot database"
                fi
            else
                echo "  ⚠️  DB container $bot_db_container not found"
            fi
        fi
        
        # Восстанавливаем volumes если есть
        if [ -d "$bot_dir/volumes" ]; then
            echo "  Restoring volumes..."
            for volume_archive in "$bot_dir/volumes"/*.tar.gz; do
                if [ ! -f "$volume_archive" ]; then
                    continue
                fi
                
                volume_name=\$(basename "$volume_archive" .tar.gz)
                echo "    Restoring volume: $volume_name"
                
                # Удаляем старый volume
                docker volume rm "$volume_name" 2>/dev/null || true
                
                # Создаем новый volume
                docker volume create "$volume_name"
                
                # Восстанавливаем данные
                docker run --rm \
                    -v "$volume_name:/target" \
                    -v "$bot_dir/volumes:/source:ro" \
                    alpine \
                    sh -c "cd /target && tar -xzf /source/\$(basename "$volume_archive")"
                    
                if [ $? -eq 0 ]; then
                    echo "    ✅ Volume $volume_name restored"
                else
                    echo "    ❌ Failed to restore volume $volume_name"
                fi
            done
        fi
        
        # Применяем переменные окружения (через docker inspect и update)
        if [ -f "$bot_dir/environment.json" ]; then
            echo "  ℹ️  Environment variables backed up (apply manually if needed)"
            echo "     File: $bot_dir/environment.json"
        fi
        
        # Запускаем контейнер бота
        echo "  Starting $bot_name..."
        if docker start "$bot_name" 2>/dev/null; then
            # Ждем готовности бота если есть healthcheck
            if docker inspect --format='{{.State.Health}}' "$bot_name" 2>/dev/null | grep -q "Status"; then
                echo "  Waiting for bot to be healthy..."
                bot_wait=0
                bot_max_wait=15
                
                until [ "\$(docker inspect --format='{{.State.Health.Status}}' "$bot_name" 2>/dev/null)" == "healthy" ]; do
                    sleep 2
                    bot_wait=\$((bot_wait + 1))
                    if [ \$bot_wait -gt \$bot_max_wait ]; then
                        echo "  ⚠️  Bot health check timeout"
                        break
                    fi
                done
            fi
        fi
        
        echo "  ✅ Bot $bot_name restored"
    done
    
    echo
    echo "✅ All Telegram bots restored"
fi

echo
echo "==================================="
echo "Restore Complete!"
echo "==================================="
RESTORE_SCRIPT_EOF

    # Заменяем __APP_NAME__ на реальное имя
    sed -i "s/__APP_NAME__/$APP_NAME/g" "$temp_backup_dir/restore-volume.sh" 2>/dev/null || \
        sed -i.bak "s/__APP_NAME__/$APP_NAME/g" "$temp_backup_dir/restore-volume.sh"
    
    chmod +x "$temp_backup_dir/restore-volume.sh"
    log_message "Volume restore script created"
fi

# Шаг 5: Создаем инструкцию по восстановлению
log_message "Step 5: Creating restore instructions..."

cat > "$temp_backup_dir/RESTORE-INSTRUCTIONS.md" << 'INSTRUCTIONS_EOF'
# Remnawave Backup Restore Instructions

## Backup Information

- **Backup Type**: __BACKUP_TYPE__
- **Created**: __TIMESTAMP__
- **App Name**: __APP_NAME__
- **Panel Version**: __PANEL_VERSION__

## Quick Restore

### Recommended: Automatic Restore
```bash
# 1. Extract backup
tar -xzf backup_file.tar.gz

# 2. Use built-in restore
sudo bash install-script.sh @ restore
```

## Manual Restore by Type

### SQL Dump Restore (backup_type: sql_dump)
```bash
# Stop services
sudo __APP_NAME__ down

# Restore database
cat database.sql | docker exec -i -e PGPASSWORD="postgres" __APP_NAME__-db psql -U postgres -d postgres

# Start services
sudo __APP_NAME__ up -d
```

### Volume Restore (backup_type: volume)
```bash
# Use provided restore script
sudo bash restore-volume.sh

# Or manually:
docker stop __APP_NAME__-db
docker volume rm __APP_NAME__-db-data
docker volume create __APP_NAME__-db-data
docker run --rm -v __APP_NAME__-db-data:/target -v $(pwd)/database-volume:/source:ro alpine sh -c "cd /target && cp -a /source/. ."
docker start __APP_NAME__-db
```

### Both Types Available (backup_type: both)
Choose either SQL dump or volume restore method above.
Volume restore is faster but requires exact version match.
SQL dump is more flexible and works across versions.

## Advantages by Type

### SQL Dump
- ✅ Works across different PostgreSQL versions
- ✅ Human-readable and editable
- ✅ Can restore specific tables
- ⚠️ Slower for large databases

### Volume
- ✅ Much faster restore
- ✅ Exact binary copy
- ✅ Includes all database settings
- ⚠️ Requires same PostgreSQL version

## Support

For automatic restore with all safety checks:
```bash
sudo __APP_NAME__ restore
```
INSTRUCTIONS_EOF

    # Заменяем переменные
    sed -i "s/__BACKUP_TYPE__/$BACKUP_TYPE/g; s/__APP_NAME__/$APP_NAME/g; s/__TIMESTAMP__/$(date)/g; s/__PANEL_VERSION__/$panel_version/g" "$temp_backup_dir/RESTORE-INSTRUCTIONS.md" 2>/dev/null || \
        sed -i.bak "s/__BACKUP_TYPE__/$BACKUP_TYPE/g; s/__APP_NAME__/$APP_NAME/g; s/__TIMESTAMP__/$(date)/g; s/__PANEL_VERSION__/$panel_version/g" "$temp_backup_dir/RESTORE-INSTRUCTIONS.md"
    
    log_message "Restore instructions created"

# Шаг 6: Создаем метаданные
log_message "Step 6: Creating backup metadata..."

metadata_file="$temp_backup_dir/backup-metadata.json"

# Получаем версию панели
panel_version=$(docker exec "${APP_NAME}" awk -F'"' '/"version"/{print $4; exit}' package.json 2>/dev/null || echo "unknown")

cat > "$metadata_file" <<METADATA_EOF
{
    "backup_type": "full_system",
    "database_backup_method": "$BACKUP_TYPE",
    "app_name": "$APP_NAME",
    "timestamp": "$timestamp",
    "date_created": "$(date -Iseconds)",
    "script_version": "$(grep '^SCRIPT_VERSION=' "$script_source" | cut -d'=' -f2 | tr -d '"' || echo 'unknown')",
    "backup_script_version": "$BACKUP_SCRIPT_VERSION",
    "panel_version": "$panel_version",
    "database_included": true,
    "application_files_included": true,
    "management_script_included": $([ -f "$temp_backup_dir/install-script.sh" ] && echo "true" || echo "false"),
    "restore_script_included": $([ -f "$temp_backup_dir/restore-volume.sh" ] && echo "true" || echo "false"),
    "docker_images": {
$(docker images --format '        "{{.Repository}}:{{.Tag}}": "{{.ID}}"' | grep -E "(remnawave|postgres|valkey)" | head -10 || echo '')
    },
    "system_info": {
        "hostname": "$(hostname)",
        "os": "$(lsb_release -d 2>/dev/null | cut -f2 || uname -s)",
        "docker_version": "$(docker --version | cut -d' ' -f3 | tr -d ',')",
        "backup_size_uncompressed": "$(du -sh "$temp_backup_dir" | cut -f1)"
    }
}
METADATA_EOF

log_message "Backup metadata created"

# Шаг 7: Сжатие бэкапа (если включено)
if [ "$COMPRESS_ENABLED" = "true" ]; then
    log_message "Step 7: Compressing backup..."
    
    cd "$(dirname "$temp_backup_dir")"
    if tar -czf "$BACKUP_DIR/${backup_name}.tar.gz" -C "$TEMP_BACKUP_ROOT" "temp_$timestamp" 2>/dev/null; then
        compressed_size=$(du -sh "$BACKUP_DIR/${backup_name}.tar.gz" | cut -f1)
        log_message "Backup compressed successfully ($compressed_size)"
        
        # Удаляем временную директорию
        rm -rf "$temp_backup_dir"
        
        final_backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    else
        log_message "ERROR: Backup compression failed"
        rm -rf "$temp_backup_dir"
        exit 1
    fi
else
    # Перемещаем несжатую директорию в финальное местоположение  
    mv "$temp_backup_dir" "$BACKUP_DIR/$backup_name"
    
    final_backup_file="$BACKUP_DIR/$backup_name"
    backup_size=$(du -sh "$final_backup_file" | cut -f1)
    log_message "Backup created successfully: $backup_name ($backup_size)"
fi

# Шаг 8: Отправка в Telegram (если включено)
if [ "$TELEGRAM_ENABLED" = "true" ]; 
    then    log_message "Step 8: Sending backup to Telegram..."
    
    telegram_bot_token=$(jq -r '.telegram.bot_token' "$CONFIG_FILE")
    telegram_chat_id=$(jq -r '.telegram.chat_id' "$CONFIG_FILE")
    telegram_thread_id=$(jq -r '.telegram.thread_id' "$CONFIG_FILE")
    
    if [ "$telegram_bot_token" != "null" ] && [ "$telegram_chat_id" != "null" ]; then
        # Отправляем информацию о бэкапе
        backup_info="🤖 *Scheduled Backup Created*

📦 *Name:* \`$backup_name\`
📅 *Date:* $(date '+%Y-%m-%d %H:%M:%S')
🔢 *Size:* $(du -sh "$final_backup_file" | cut -f1)
🏷️ *Type:* Full System Backup
📊 *Panel:* v$panel_version
🖥️ *Server:* $(hostname)
✅ *Status:* Success"
          # Получаем размер файла в байтах
        file_size_bytes=$(stat -c%s "$final_backup_file" 2>/dev/null || stat -f%z "$final_backup_file" 2>/dev/null || echo "0")
        max_telegram_size=$((49 * 1024 * 1024))  # 49MB в байтах (безопасный лимит для Telegram)
        
        # Функция экранирования спецсимволов для MarkdownV2
        escape_markdown_v2() {
            local text="$1"
            # Экранируем спецсимволы Telegram MarkdownV2: _ * [ ] ( ) ~ ` > # + - = | { } . !
            echo "$text" | sed -e 's/\\_/\\\\_/g' \
                              -e 's/\*/\\*/g' \
                              -e 's/\[/\\[/g' \
                              -e 's/\]/\\]/g' \
                              -e 's/(/\\(/g' \
                              -e 's/)/\\)/g' \
                              -e 's/~/\\~/g' \
                              -e 's/`/\\`/g' \
                              -e 's/>/\\>/g' \
                              -e 's/#/\\#/g' \
                              -e 's/+/\\+/g' \
                              -e 's/-/\\-/g' \
                              -e 's/=/\\=/g' \
                              -e 's/|/\\|/g' \
                              -e 's/{/\\{/g' \
                              -e 's/}/\\}/g' \
                              -e 's/\./\\./g' \
                              -e 's/!/\\!/g'
        }
        
        # Функция отправки файла в Telegram
        send_telegram_file() {
            local file_path="$1"
            local caption="$2"
            local part_info="$3"
            
            local full_caption="${caption}"
            if [ -n "$part_info" ]; then
                full_caption="${caption}

${part_info}"
            fi
            
            # Используем обычный Markdown вместо MarkdownV2 для совместимости
            if [ -n "$telegram_thread_id" ] && [ "$telegram_thread_id" != "null" ]; then
                curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendDocument" \
                    -F "chat_id=$telegram_chat_id" \
                    -F "document=@$file_path" \
                    -F "caption=$full_caption" \
                    -F "parse_mode=Markdown" \
                    -F "message_thread_id=$telegram_thread_id" >/dev/null 2>&1
            else
                curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendDocument" \
                    -F "chat_id=$telegram_chat_id" \
                    -F "document=@$file_path" \
                    -F "caption=$full_caption" \
                    -F "parse_mode=Markdown" >/dev/null 2>&1
            fi
            
            return $?
        }
        
        # Функция отправки текстового сообщения
        send_telegram_message() {
            local message="$1"
            
            if [ -n "$telegram_thread_id" ] && [ "$telegram_thread_id" != "null" ]; then
                curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" \
                    -F "chat_id=$telegram_chat_id" \
                    -F "text=$message" \
                    -F "parse_mode=Markdown" \
                    -F "message_thread_id=$telegram_thread_id" >/dev/null 2>&1
            else
                curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" \
                    -F "chat_id=$telegram_chat_id" \
                    -F "text=$message" \
                    -F "parse_mode=Markdown" >/dev/null 2>&1
            fi
            
            return $?
        }
        
        # Проверяем размер и отправляем
        if [ "$file_size_bytes" -lt "$max_telegram_size" ] && [[ "$final_backup_file" =~ \.tar\.gz$ ]]; then
            # Файл помещается в одно сообщение
            log_message "Sending file via Telegram API: $(basename "$final_backup_file") ($(du -sh "$final_backup_file" | cut -f1))"
            
            if send_telegram_file "$final_backup_file" "$backup_info" ""; then
                log_message "File sent successfully to Telegram"
            else
                log_message "ERROR: Failed to send file to Telegram"
            fi
        else
            # Файл слишком большой - разбиваем на части
            log_message "File is too large for single Telegram message ($(du -sh "$final_backup_file" | cut -f1))"
            log_message "Splitting file into 49MB chunks..."
            
            # Создаем временную директорию для частей
            split_dir="${TEMP_BACKUP_ROOT}/split_${timestamp}"
            mkdir -p "$split_dir"
            
            # Разбиваем файл на части по 49MB
            cd "$split_dir"
            split -b 49M "$final_backup_file" "$(basename "$final_backup_file")."
            
            # Получаем список частей
            parts=($(ls -1 "$(basename "$final_backup_file")".* 2>/dev/null | sort))
            total_parts=${#parts[@]}
            
            if [ "$total_parts" -gt 0 ]; then
                log_message "File split into $total_parts parts"
                
                # Отправляем информационное сообщение
                split_info="${backup_info}

📦 *File split into $total_parts parts*
⚠️ Download all parts to restore backup"
                
                if send_telegram_message "$split_info"; then
                    log_message "Split information sent to Telegram"
                fi
                
                # Отправляем каждую часть
                part_num=1
                for part_file in "${parts[@]}"; do
                    part_size=$(du -sh "$part_file" | cut -f1)
                    part_info="📎 *Part ${part_num}/${total_parts}* | Size: ${part_size}"
                    
                    log_message "Sending part ${part_num}/${total_parts}: ${part_file} (${part_size})"
                    
                    if send_telegram_file "$part_file" "" "$part_info"; then
                        log_message "Part ${part_num}/${total_parts} sent successfully"
                    else
                        log_message "ERROR: Failed to send part ${part_num}/${total_parts}"
                    fi
                    
                    part_num=$((part_num + 1))
                    
                    # Небольшая задержка между отправками (чтобы не нарушить rate limits)
                    sleep 2
                done
                
                # Отправляем завершающее сообщение
                completion_msg="✅ *All $total_parts parts sent successfully*

To restore, concatenate parts:
\`\`\`
cat $(basename "$final_backup_file").* > $(basename "$final_backup_file")
\`\`\`"
                
                if send_telegram_message "$completion_msg"; then
                    log_message "Completion message sent to Telegram"
                fi
                
                log_message "All parts sent to Telegram successfully"
            else
                log_message "ERROR: Failed to split file"
                
                # Отправляем уведомление об ошибке
                error_msg="${backup_info}

⚠️ *File too large and failed to split*
Please download from server manually"
                
                send_telegram_message "$error_msg"
            fi
            
            # Очищаем временные файлы
            rm -rf "$split_dir" 2>/dev/null || true
        fi
        
        log_message "Backup sent to Telegram successfully"
    else
        log_message "WARNING: Telegram credentials not configured"
    fi
fi

# Шаг 9: Очистка старых бэкапов
retention_days=$(jq -r '.retention.days // 7' "$CONFIG_FILE")
min_backups=$(jq -r '.retention.min_backups // 3' "$CONFIG_FILE")

log_message "Cleaning up backups older than $retention_days days..."

# Находим старые файлы
find "$BACKUP_DIR" -name "remnawave_scheduled_*" -type f -mtime +$retention_days -delete 2>/dev/null
find "$BACKUP_DIR" -name "remnawave_scheduled_*" -type d -mtime +$retention_days -exec rm -rf {} + 2>/dev/null

# Проверяем минимальное количество
current_backups=$(ls -1 "$BACKUP_DIR"/remnawave_scheduled_* 2>/dev/null | wc -l)
if [ "$current_backups" -lt "$min_backups" ]; then
    log_message "WARNING: Only $current_backups backups remain (minimum: $min_backups)"
fi

log_message "Old backups cleaned up"
log_message "Backup process completed successfully"

# Очистка временной директории бэкапа
log_message "Cleaning up temporary backup directory..."
rm -rf "$TEMP_BACKUP_ROOT" 2>/dev/null || true

BACKUP_SCRIPT_EOF

    chmod +x "$BACKUP_SCRIPT_FILE"
    echo -e "\033[1;32m✅ Backup script created: $BACKUP_SCRIPT_FILE\033[0m"
}

# Добавляем после функции backup_command:

restore_command() {
    check_running_as_root
    
    local backup_file=""
    local target_app_name="$APP_NAME"
    local target_base_dir="/opt"  
    local force_restore=false
    local database_only=false
    local skip_install=false
    
    # Парсинг аргументов
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --file|-f) 
                backup_file="$2"
                shift 2
                ;;
            --name|-n)
                target_app_name="$2"
                shift 2
                ;;
            --path|-p)  
                target_base_dir="$2"
                shift 2
                ;;
            --database-only)
                database_only=true
                shift
                ;;
            --skip-install)
                skip_install=true
                shift
                ;;
            --force)
                force_restore=true
                shift
                ;;
            -h|--help) 
                echo -e "\033[1;37m🔄 Remnawave Restore System\033[0m"
                echo
                echo -e "\033[1;37mUsage:\033[0m"
                echo -e "  \033[38;5;15m$APP_NAME restore\033[0m [\033[38;5;244moptions\033[0m]"
                echo
                echo -e "\033[1;37mOptions:\033[0m"
                echo -e "  \033[38;5;244m--file, -f <path>\033[0m     Restore from specific backup file"
                echo -e "  \033[38;5;244m--name, -n <name>\033[0m     Set custom app name (default: remnawave)"
                echo -e "  \033[38;5;244m--path, -p <path>\033[0m     Base installation path (default: /opt)"
                echo -e "  \033[38;5;244m--database-only\033[0m       Restore only database (requires existing installation)"
                echo -e "  \033[38;5;244m--skip-install\033[0m        Don't install management script"
                echo -e "  \033[38;5;244m--force\033[0m               Skip confirmation prompts"
                echo -e "  \033[38;5;244m--help, -h\033[0m            Show this help"
                echo
                echo -e "\033[1;37mExamples:\033[0m"
                echo -e "  \033[38;5;244m$APP_NAME restore --file backup.tar.gz\033[0m"
                echo -e "  \033[38;5;244m$APP_NAME restore --file backup.tar.gz --name newpanel\033[0m"
                echo -e "  \033[38;5;244m$APP_NAME restore --file backup.tar.gz --path /root\033[0m"
                echo -e "  \033[38;5;244m$APP_NAME restore --database-only --file backup.tar.gz\033[0m"
                echo
                echo -e "\033[1;37mQuick restore (common cases):\033[0m"
                echo -e "  \033[38;5;244mFull panel on clean host\033[0m"
                echo -e "  \033[38;5;15msudo $APP_NAME restore --file /path/to/remnawave_full_backup.tar.gz\033[0m"
                echo -e "  \033[38;5;244mDB-only into existing install\033[0m"
                echo -e "  \033[38;5;15msudo $APP_NAME restore --database-only --file /path/to/database.sql.gz\033[0m"
                echo
                exit 0
                ;;
            --) shift; break ;;  # Конец опций
            -*) 
                echo "Unknown option: $1" >&2
                echo "Use '$APP_NAME restore --help' for usage information."
                exit 1
                ;;
            *) break ;;  # Позиционные аргументы
        esac
    done
    
    # Устанавливаем целевую директорию
    local target_dir="$target_base_dir/$target_app_name"
    
    # Если файл не указан, показываем интерактивное меню
    if [ -z "$backup_file" ]; then
        restore_interactive_menu "$target_app_name" "$database_only" "$skip_install" "$force_restore" "$target_base_dir"
    else
        restore_from_backup "$backup_file" "$target_app_name" "$database_only" "$skip_install" "$force_restore" "$target_base_dir"
    fi
}

restore_interactive_menu() {
    local target_app_name="$1"
    local database_only="$2"
    local skip_install="$3"
    local force_restore="$4"
    local target_base_dir="$5"
    
    while true; do
        clear
        echo -e "\033[1;37m🔄 Restore from Backup\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
        echo
        
        # Показываем текущую конфигурацию
        echo -e "\033[1;37m⚙️  Restore Configuration:\033[0m"
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Target name:" "$target_app_name"
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Target path:" "$target_base_dir/$target_app_name"
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Restore type:" "$([ "$database_only" = true ] && echo "Database only" || echo "Full system")"
        echo
        
        # Проверяем существование целевой директории
        if [ -d "$target_base_dir/$target_app_name" ]; then
            echo -e "\033[1;33m⚠️  Target directory already exists!\033[0m"
            echo -e "\033[38;5;244m   Existing installation will be backed up and replaced\033[0m"
        else
            echo -e "\033[1;32m✅ Target directory is clean\033[0m"
        fi
        echo
        
        # Сканируем доступные бэкапы в разных локациях
        local backup_files=()
        
        # Ищем в стандартной директории текущего приложения
        if [ -d "$APP_DIR/backups" ]; then
            # Используем find для более надежного поиска всех типов backup файлов
            while IFS= read -r -d '' backup; do
                backup_files+=("$backup")
            done < <(find "$APP_DIR/backups" -maxdepth 1 -type f \( \
                -name "remnawave_*.tar.gz" -o \
                -name "remnawave_*.sql" -o \
                -name "remnawave_*.sql.gz" -o \
                -name "remnawave_*.sql.bz2" -o \
                -name "remnawave_*.sql.xz" \
            \) -print0 2>/dev/null | sort -zr)
        fi
        
        # Ищем в стандартных директориях других установок
        for possible_dir in /opt/remnawave*/backups /opt/*/backups; do
            if [ -d "$possible_dir" ] && [ "$possible_dir" != "$APP_DIR/backups" ]; then
                while IFS= read -r -d '' backup; do
                    backup_files+=("$backup")
                done < <(find "$possible_dir" -maxdepth 1 -type f \( \
                    -name "remnawave_*.tar.gz" -o \
                    -name "remnawave_*.sql" -o \
                    -name "remnawave_*.sql.gz" -o \
                    -name "remnawave_*.sql.bz2" -o \
                    -name "remnawave_*.sql.xz" \
                \) -print0 2>/dev/null | sort -zr)
            fi
        done
        
        if [ ${#backup_files[@]} -eq 0 ]; then
            echo -e "\033[1;33m⚠️  No backup files found!\033[0m"
            echo
            echo -e "\033[38;5;244mSearched in:\033[0m"
            echo -e "\033[38;5;244m   • $APP_DIR/backups/\033[0m"
            echo -e "\033[38;5;244m   • /opt/*/backups/\033[0m"
            echo
            echo -e "\033[1;37m📋 Options:\033[0m"
            echo -e "   \033[38;5;15m1)\033[0m 📁 Specify custom backup file path"
            echo -e "   \033[38;5;15m2)\033[0m ⚙️  Change restore settings"
            echo -e "   \033[38;5;244m0)\033[0m ⬅️  Back to main menu"
            echo
            
            read -p "Select option [0-2]: " choice
            
            case "$choice" in
                1) 
                    restore_custom_file "$target_app_name" "$database_only" "$skip_install" "$force_restore" "$target_base_dir"
                    ;;
                2) 
                    restore_configure_settings "$target_app_name" "$database_only" "$skip_install" "$force_restore" "$target_base_dir"
                    ;;
                0) return 0 ;;
                *) 
                    echo -e "\033[1;31mInvalid option!\033[0m"
                    sleep 1
                    ;;
            esac
            continue
        fi
        
        echo -e "\033[1;37m📦 Available Backups:\033[0m"
        echo
        
        local index=1
        for backup in "${backup_files[@]}"; do
            local backup_name=$(basename "$backup")
            local backup_date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
            local backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)
            local backup_source=$(dirname "$backup" | sed 's|/backups||')
            
            # Определяем тип бэкапа
            local backup_icon="📦"
            local backup_type="Unknown"
            
            if [[ "$backup_name" =~ scheduled ]]; then
                backup_icon="🤖"
                backup_type="Scheduled"
            elif [[ "$backup_name" =~ full ]]; then
                backup_icon="📁"
                backup_type="Full"
            elif [[ "$backup_name" =~ db ]]; then
                backup_icon="🗄️"
                backup_type="Database"
            fi
            
            # Определяем совместимость с текущим режимом восстановления
            local compatible=true
            local compat_note=""
            
            if [ "$database_only" = true ]; then
                if [[ "$backup_name" =~ \.tar\.gz$ ]]; then
                    compat_note=" (will extract DB)"
                fi
            else
                if [[ "$backup_name" =~ \.sql ]]; then
                    compat_note=" (DB only - need full backup)"
                    compatible=false
                fi
            fi
            
            if [ "$compatible" = true ]; then
                printf "   \033[38;5;15m%2d)\033[0m %s \033[38;5;250m%-30s\033[0m \033[38;5;244m%s\033[0m \033[38;5;244m%s\033[0m\033[38;5;117m%s\033[0m\n" \
                    "$index" "$backup_icon" "$backup_name" "$backup_size" "$backup_date" "$compat_note"
            else
                printf "   \033[38;5;244m%2d)\033[0m %s \033[38;5;244m%-30s\033[0m \033[38;5;244m%s\033[0m \033[38;5;244m%s\033[0m\033[1;31m%s\033[0m\n" \
                    "$index" "$backup_icon" "$backup_name" "$backup_size" "$backup_date" "$compat_note"
            fi
            printf "      \033[38;5;244m   Source: %s | Type: %s\033[0m\n" "$backup_source" "$backup_type"
            echo
            index=$((index + 1))
        done
        
        echo -e "\033[1;37m📋 Options:\033[0m"
        echo -e "   \033[38;5;15m97)\033[0m 📁 Specify custom backup file path"
        echo -e "   \033[38;5;15m98)\033[0m ⚙️  Change restore settings"
        echo -e "   \033[38;5;15m99)\033[0m 🔄 Refresh backup list"
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  Back to main menu"
        echo
        
        read -p "Select backup to restore [0-${#backup_files[@]}]: " choice
        
        case "$choice" in
            0) return 0 ;;
            97) 
                restore_custom_file "$target_app_name" "$database_only" "$skip_install" "$force_restore" "$target_base_dir"
                ;;
            98) 
                restore_configure_settings "$target_app_name" "$database_only" "$skip_install" "$force_restore" "$target_base_dir"
                ;;
            99) continue ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#backup_files[@]} ]; then
                    local selected_backup="${backup_files[$((choice - 1))]}"
                    restore_from_backup "$selected_backup" "$target_app_name" "$database_only" "$skip_install" "$force_restore" "$target_base_dir"
                    read -p "Press Enter to continue..."
                else
                    echo -e "\033[1;31mInvalid option!\033[0m"
                    sleep 1
                fi
                ;;
        esac
    done
}

restore_configure_settings() {
    local current_target_name="$1"
    local current_database_only="$2"
    local current_skip_install="$3"
    local current_force_restore="$4"
    local current_target_base_dir="$5"
    
    while true; do
        clear
        echo -e "\033[1;37m⚙️  Restore Settings\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
        echo
        
        echo -e "\033[1;37m📋 Current Settings:\033[0m"
        printf "   \033[38;5;15m1)\033[0m \033[38;5;250mTarget app name: \033[0m\033[1;37m%s\033[0m\n" "$current_target_name"
        printf "   \033[38;5;15m2)\033[0m \033[38;5;250mTarget path: \033[0m\033[1;37m%s\033[0m\n" "$current_target_base_dir"
        printf "   \033[38;5;15m3)\033[0m \033[38;5;250mRestore type: \033[0m\033[1;37m%s\033[0m\n" "$([ "$current_database_only" = true ] && echo "Database only" || echo "Full system")"
        printf "   \033[38;5;15m4)\033[0m \033[38;5;250mSkip script install: \033[0m\033[1;37m%s\033[0m\n" "$([ "$current_skip_install" = true ] && echo "Yes" || echo "No")"
        printf "   \033[38;5;15m5)\033[0m \033[38;5;250mForce mode: \033[0m\033[1;37m%s\033[0m\n" "$([ "$current_force_restore" = true ] && echo "Enabled" || echo "Disabled")"
        echo
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  Back to backup selection"
        echo
        
        read -p "Select setting to change [0-5]: " choice
        
        case "$choice" in
            1)
                echo
                echo -e "\033[1;37m📝 Change Target App Name\033[0m"
                echo -e "\033[38;5;250mCurrent: $current_target_name\033[0m"
                echo -e "\033[38;5;244mNote: Will be installed to $current_target_base_dir/<app_name>/\033[0m"
                echo
                read -p "Enter new app name: " new_name
                
                if [ -n "$new_name" ] && [[ "$new_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    current_target_name="$new_name"
                    echo -e "\033[1;32m✅ App name changed to: $current_target_name\033[0m"
                else
                    echo -e "\033[1;31m❌ Invalid app name! Use only letters, numbers, - and _\033[0m"
                fi
                sleep 2
                ;;
            2)
                echo
                echo -e "\033[1;37m📝 Change Target Base Path\033[0m"
                echo -e "\033[38;5;250mCurrent: $current_target_base_dir\033[0m"
                echo -e "\033[38;5;244mApp will be installed to: <path>/$current_target_name/\033[0m"
                echo
                read -p "Enter new base path: " new_path
                
                if [ -n "$new_path" ]; then
                    # Убираем конечный слеш
                    new_path="${new_path%/}"
                    current_target_base_dir="$new_path"
                    echo -e "\033[1;32m✅ Base path changed to: $current_target_base_dir\033[0m"
                else
                    echo -e "\033[1;31m❌ Path cannot be empty!\033[0m"
                fi
                sleep 2
                ;;
            3)
                if [ "$current_database_only" = true ]; then
                    current_database_only=false
                    echo -e "\033[1;32m✅ Changed to: Full system restore\033[0m"
                else
                    current_database_only=true
                    echo -e "\033[1;32m✅ Changed to: Database only restore\033[0m"
                fi
                sleep 2
                ;;
            4)
                if [ "$current_skip_install" = true ]; then
                    current_skip_install=false
                    echo -e "\033[1;32m✅ Management script will be installed\033[0m"
                else
                    current_skip_install=true
                    echo -e "\033[1;32m✅ Management script installation will be skipped\033[0m"
                fi
                sleep 2
                ;;
            5)
                if [ "$current_force_restore" = true ]; then
                    current_force_restore=false
                    echo -e "\033[1;32m✅ Confirmation prompts enabled\033[0m"
                else
                    current_force_restore=true
                    echo -e "\033[1;32m✅ Force mode enabled (skip confirmations)\033[0m"
                fi
                sleep 2
                ;;
            0)
                # Возвращаемся в меню с обновленными настройками
                restore_interactive_menu "$current_target_name" "$current_database_only" "$current_skip_install" "$current_force_restore" "$current_target_base_dir"
                return
                ;;
            *)
                echo -e "\033[1;31mInvalid option!\033[0m"
                sleep 1
                ;;
        esac
    done
}

restore_custom_file() {
    local target_app_name="$1"
    local database_only="$2"
    local skip_install="$3"
    local force_restore="$4"
    local target_base_dir="$5"
    
    echo
    echo -e "\033[1;37m📁 Custom Backup File\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
    echo
    echo -e "\033[38;5;250mEnter the full path to your backup file.\033[0m"
    echo -e "\033[38;5;244mSupported formats: .tar.gz, .sql, .sql.gz\033[0m"
    echo
    
    read -p "Backup file path: " -r custom_path
    
    if [ -z "$custom_path" ]; then
        echo -e "\033[1;31m❌ No path specified!\033[0m"
        sleep 2
        return
    fi
    
    # Расширяем относительные пути
    if [[ "$custom_path" == ~* ]]; then
        custom_path="${custom_path/#\~/$HOME}"
    fi
    
    if [ ! -f "$custom_path" ]; then
        echo -e "\033[1;31m❌ File not found: $custom_path\033[0m"
        sleep 2
        return
    fi
    
    restore_from_backup "$custom_path" "$target_app_name" "$database_only" "$skip_install" "$force_restore" "$target_base_dir"
}

check_system_requirements_for_restore() {
    echo -e "\033[1;37m🔍 Checking System Requirements\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    echo
    
    local requirements_met=true
    local install_needed=()
    
    # Проверка ОС
    echo -e "\033[38;5;250m📝 Step 1:\033[0m Checking operating system..."
    if ! command -v lsb_release >/dev/null 2>&1 && ! [ -f /etc/os-release ]; then
        echo -e "\033[1;33m⚠️  Cannot determine OS version\033[0m"
    else
        local os_info=""
        if command -v lsb_release >/dev/null 2>&1; then
            os_info=$(lsb_release -d | cut -f2)
        elif [ -f /etc/os-release ]; then
            os_info=$(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
        fi
        echo -e "\033[1;32m✅ OS: $os_info\033[0m"
    fi
    
    # Проверка прав root
    echo -e "\033[38;5;250m📝 Step 2:\033[0m Checking root privileges..."
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[1;31m❌ Root privileges required!\033[0m"
        echo -e "\033[38;5;244m   Please run with sudo\033[0m"
        return 1
    else
        echo -e "\033[1;32m✅ Root privileges confirmed\033[0m"
    fi
    
    # Проверка базовых утилит
    echo -e "\033[38;5;250m📝 Step 3:\033[0m Checking system utilities..."
    local basic_tools=("curl" "wget" "tar" "gzip" "jq")
    local missing_basic=()
    
    for tool in "${basic_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_basic+=("$tool")
        fi
    done
    
    if [ ${#missing_basic[@]} -eq 0 ]; then
        echo -e "\033[1;32m✅ All basic utilities available\033[0m"
    else
        echo -e "\033[1;33m⚠️  Missing utilities: ${missing_basic[*]}\033[0m"
        install_needed+=("${missing_basic[@]}")
    fi
    
    # Проверка Docker
    echo -e "\033[38;5;250m📝 Step 4:\033[0m Checking Docker..."
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "\033[1;33m⚠️  Docker not installed\033[0m"
        install_needed+=("docker")
        requirements_met=false
    else
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        echo -e "\033[1;32m✅ Docker installed: $docker_version\033[0m"
        
        # Проверка запуска Docker
        if ! docker info >/dev/null 2>&1; then
            echo -e "\033[1;33m⚠️  Docker daemon not running\033[0m"
            echo -e "\033[38;5;244m   Will attempt to start Docker service\033[0m"
        else
            echo -e "\033[38;5;244m   ✓ Docker daemon running\033[0m"
        fi
    fi
    
    # Проверка Docker Compose
    echo -e "\033[38;5;250m📝 Step 5:\033[0m Checking Docker Compose..."
    if ! docker compose version >/dev/null 2>&1; then
        echo -e "\033[1;33m⚠️  Docker Compose V2 not available\033[0m"
        
        # Проверяем старую версию
        if command -v docker-compose >/dev/null 2>&1; then
            local compose_version=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
            echo -e "\033[1;33m⚠️  Found legacy docker-compose: $compose_version\033[0m"
            echo -e "\033[38;5;244m   Recommend updating to Docker with built-in Compose V2\033[0m"
        else
            install_needed+=("docker-compose")
            requirements_met=false
        fi
    else
        local compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
        echo -e "\033[1;32m✅ Docker Compose V2: $compose_version\033[0m"
    fi
    
    # Проверка свободного места
    echo -e "\033[38;5;250m📝 Step 6:\033[0m Checking disk space..."
    local available_space=$(df / | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [ $available_gb -lt 2 ]; then
        echo -e "\033[1;31m❌ Insufficient disk space: ${available_gb}GB available\033[0m"
        echo -e "\033[38;5;244m   Minimum 2GB required for restore operation\033[0m"
        requirements_met=false
    else
        echo -e "\033[1;32m✅ Sufficient disk space: ${available_gb}GB available\033[0m"
    fi
    
    # Проверка сетевого подключения
    echo -e "\033[38;5;250m📝 Step 7:\033[0m Checking network connectivity..."
    if curl -s --connect-timeout 5 https://registry-1.docker.io/v2/ >/dev/null; then
        echo -e "\033[1;32m✅ Docker Hub connectivity confirmed\033[0m"
    else
        echo -e "\033[1;33m⚠️  Docker Hub connectivity issues\033[0m"
        echo -e "\033[38;5;244m   This may cause problems downloading Docker images\033[0m"
    fi
    
    # Итоговый результат
    echo
    if [ ${#install_needed[@]} -gt 0 ]; then
        echo -e "\033[1;37m📦 Missing Dependencies:\033[0m"
        for package in "${install_needed[@]}"; do
            echo -e "\033[38;5;244m   • $package\033[0m"
        done
        echo
        
        echo -e "\033[1;37m🔧 Auto-install missing dependencies?\033[0m"
        read -p "Install missing packages automatically? [Y/n]: " -r auto_install
        
        if [[ ! $auto_install =~ ^[Nn]$ ]]; then
            install_missing_dependencies "${install_needed[@]}"
            
            # Повторная проверка после установки
            echo
            echo -e "\033[1;37m🔄 Re-checking after installation...\033[0m"
            check_system_requirements_for_restore
            return $?
        else
            echo -e "\033[1;31m❌ Cannot proceed without required dependencies\033[0m"
            echo
            echo -e "\033[1;37m📋 Manual installation commands:\033[0m"
            show_manual_install_commands "${install_needed[@]}"
            return 1
        fi
    elif [ "$requirements_met" = false ]; then
        echo -e "\033[1;31m❌ System requirements not met\033[0m"
        return 1
    else
        echo -e "\033[1;32m🎉 All system requirements satisfied!\033[0m"
        return 0
    fi
}

install_missing_dependencies() {
    local packages=("$@")
    
    echo
    echo -e "\033[1;37m📦 Installing Missing Dependencies\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    
    # Определяем пакетный менеджер
    if command -v apt-get >/dev/null 2>&1; then
        install_with_apt "${packages[@]}"
    elif command -v yum >/dev/null 2>&1; then
        install_with_yum "${packages[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        install_with_dnf "${packages[@]}"
    else
        echo -e "\033[1;31m❌ Unsupported package manager!\033[0m"
        echo -e "\033[38;5;244m   Please install dependencies manually\033[0m"
        return 1
    fi
}


install_with_apt() {
    local packages=("$@")
    
    echo -e "\033[38;5;250m📝 Using APT package manager...\033[0m"
    
    # Обновляем список пакетов
    echo -e "\033[38;5;244m   Updating package list...\033[0m"
    if apt-get update >/dev/null 2>&1; then
        echo -e "\033[1;32m✅ Package list updated\033[0m"
    else
        echo -e "\033[1;33m⚠️  Package list update failed, continuing...\033[0m"
    fi
    
    for package in "${packages[@]}"; do
        echo -e "\033[38;5;250m📦 Installing $package...\033[0m"
        
        case "$package" in
            "docker")
                # Устанавливаем Docker официальным способом
                echo -e "\033[38;5;244m   Installing Docker from official repository...\033[0m"
                curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    systemctl start docker 2>/dev/null
                    systemctl enable docker 2>/dev/null
                    echo -e "\033[1;32m✅ Docker installed and started\033[0m"
                else
                    echo -e "\033[1;31m❌ Docker installation failed\033[0m"
                fi
                ;;
            "docker-compose")
                # Docker Compose как отдельный пакет уже включен в современный Docker
                echo -e "\033[1;32m✅ Docker Compose included with Docker\033[0m"
                ;;
            "jq")
                apt-get install -y jq >/dev/null 2>&1 && echo -e "\033[1;32m✅ jq installed\033[0m" || echo -e "\033[1;31m❌ jq installation failed\033[0m"
                ;;
            "curl")
                apt-get install -y curl >/dev/null 2>&1 && echo -e "\033[1;32m✅ curl installed\033[0m" || echo -e "\033[1;31m❌ curl installation failed\033[0m"
                ;;
            "wget")
                apt-get install -y wget >/dev/null 2>&1 && echo -e "\033[1;32m✅ wget installed\033[0m" || echo -e "\033[1;31m❌ wget installation failed\033[0m"
                ;;
            *)
                apt-get install -y "$package" >/dev/null 2>&1 && echo -e "\033[1;32m✅ $package installed\033[0m" || echo -e "\033[1;31m❌ $package installation failed\033[0m"
                ;;
        esac
    done
}

install_with_yum() {
    local packages=("$@")
    
    echo -e "\033[38;5;250m📝 Using YUM package manager...\033[0m"
    
    for package in "${packages[@]}"; do
        echo -e "\033[38;5;250m📦 Installing $package...\033[0m"
        
        case "$package" in
            "docker")
                curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
                systemctl start docker 2>/dev/null
                systemctl enable docker 2>/dev/null
                echo -e "\033[1;32m✅ Docker installed\033[0m"
                ;;
            *)
                yum install -y "$package" >/dev/null 2>&1 && echo -e "\033[1;32m✅ $package installed\033[0m" || echo -e "\033[1;31m❌ $package installation failed\033[0m"
                ;;
        esac
    done
}

install_with_dnf() {
    local packages=("$@")
    
    echo -e "\033[38;5;250m📝 Using DNF package manager...\033[0m"
    
    for package in "${packages[@]}"; do
        echo -e "\033[38;5;250m📦 Installing $package...\033[0m"
        
        case "$package" in
            "docker")
                curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
                systemctl start docker 2>/dev/null
                systemctl enable docker 2>/dev/null
                echo -e "\033[1;32m✅ Docker installed\033[0m"
                ;;
            *)
                dnf install -y "$package" >/dev/null 2>&1 && echo -e "\033[1;32m✅ $package installed\033[0m" || echo -e "\033[1;31m❌ $package installation failed\033[0m"
                ;;
        esac
    done
}

show_manual_install_commands() {
    local packages=("$@")
    
    echo
    if command -v apt-get >/dev/null 2>&1; then
        echo -e "\033[38;5;244m# Ubuntu/Debian:\033[0m"
        echo -e "\033[38;5;117msudo apt-get update\033[0m"
        for package in "${packages[@]}"; do
            if [ "$package" = "docker" ]; then
                echo -e "\033[38;5;117mcurl -fsSL https://get.docker.com | sh\033[0m"
            else
                echo -e "\033[38;5;117msudo apt-get install -y $package\033[0m"
            fi
        done
    elif command -v yum >/dev/null 2>&1; then
        echo -e "\033[38;5;244m# CentOS/RHEL:\033[0m"
        for package in "${packages[@]}"; do
            if [ "$package" = "docker" ]; then
                echo -e "\033[38;5;117mcurl -fsSL https://get.docker.com | sh\033[0m"
            else
                echo -e "\033[38;5;117msudo yum install -y $package\033[0m"
            fi
        done
    fi
}





restore_from_backup() {
    local backup_file="$1"
    local target_app_name="$2"
    local database_only="$3"
    local skip_install="$4"
    local force_restore="$5"
    local target_base_dir="${6:-/opt}"
    
    local target_dir="$target_base_dir/$target_app_name"
    
    
    if ! check_system_requirements_for_restore; then
        echo -e "\033[1;31m❌ System requirements check failed!\033[0m"
        echo -e "\033[38;5;244m   Please resolve the issues above before continuing\033[0m"
        return 1
    fi

    echo
    echo -e "\033[1;37m🔄 Preparing Restore Operation\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    # Валидация бэкапа
    echo -e "\033[38;5;250m📝 Step 1:\033[0m Validating backup file..."
    
    if [ ! -f "$backup_file" ]; then
        echo -e "\033[1;31m❌ Backup file not found: $backup_file\033[0m"
        return 1
    fi
    
    # Определяем тип файла
    local backup_type=""
    if [[ "$backup_file" =~ \.tar\.gz$ ]]; then
        backup_type="archive"
        # Проверяем архив
        if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
            echo -e "\033[1;31m❌ Invalid or corrupted backup archive!\033[0m"
            return 1
        fi
    elif [[ "$backup_file" =~ \.sql\.gz$ ]]; then
        backup_type="compressed_sql"
        # Проверяем сжатый SQL
        if ! gunzip -t "$backup_file" 2>/dev/null; then
            echo -e "\033[1;31m❌ Invalid or corrupted compressed SQL file!\033[0m"
            return 1
        fi
    elif [[ "$backup_file" =~ \.sql$ ]]; then
        backup_type="sql"
        # Проверяем что файл содержит SQL
        if ! head -10 "$backup_file" | grep -q -i "postgresql\|create\|insert\|copy\|select"; then
            echo -e "\033[1;33m⚠️  File may not be a valid SQL dump\033[0m"
        fi
    else
        echo -e "\033[1;31m❌ Unsupported file format! Supported: .tar.gz, .sql, .sql.gz\033[0m"
        return 1
    fi
    
    echo -e "\033[1;32m✅ Backup file validation passed (type: $backup_type)\033[0m"
    
    # Анализируем содержимое архива для .tar.gz
    local backup_info=""
    local original_app_name=""
    
    if [ "$backup_type" = "archive" ]; then
        echo -e "\033[38;5;244m   Analyzing backup content...\033[0m"
        
        local temp_analysis_dir="/tmp/backup_analysis_$$"
        mkdir -p "$temp_analysis_dir"
        
        # Извлекаем только метаданные для анализа
        tar -xzf "$backup_file" -C "$temp_analysis_dir" --wildcards "*/backup-metadata.json" 2>/dev/null || true
        
        local metadata_file=$(find "$temp_analysis_dir" -name "backup-metadata.json" 2>/dev/null | head -1)
        
        if [ -f "$metadata_file" ]; then
            original_app_name=$(jq -r '.app_name // "unknown"' "$metadata_file" 2>/dev/null)
            local backup_timestamp=$(jq -r '.timestamp // "unknown"' "$metadata_file" 2>/dev/null)
            local script_version=$(jq -r '.script_version // "unknown"' "$metadata_file" 2>/dev/null)
            local backup_type_meta=$(jq -r '.backup_type // "unknown"' "$metadata_file" 2>/dev/null)
            
            backup_info="Original: $original_app_name, Created: $backup_timestamp, Version: $script_version, Type: $backup_type_meta"
            echo -e "\033[38;5;244m   ✓ Backup metadata found and valid\033[0m"
        else
            echo -e "\033[1;33m⚠️  No metadata found in backup (older format?)\033[0m"
            original_app_name="unknown"
        fi
        
        rm -rf "$temp_analysis_dir"
    fi
    
    # Показываем план восстановления
    echo
    echo -e "\033[1;37m📋 Restore Plan:\033[0m"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Backup file:" "$(basename "$backup_file")"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Backup size:" "$(du -sh "$backup_file" | cut -f1)"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Backup type:" "$backup_type"
    if [ -n "$backup_info" ]; then
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Backup info:" "$backup_info"
    fi
    echo
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Target name:" "$target_app_name"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Target directory:" "$target_dir"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Restore type:" "$([ "$database_only" = true ] && echo "Database only" || echo "Full system")"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Install script:" "$([ "$skip_install" = true ] && echo "Skip" || echo "Yes")"
    
    # Проверка совместимости
    echo
    echo -e "\033[1;37m⚙️  Compatibility Check:\033[0m"
    local compatibility_issues=0
    
    if [ "$database_only" = false ] && [[ "$backup_file" =~ \.sql ]]; then
        echo -e "\033[1;31m❌ Full system restore requested but backup contains only database\033[0m"
        echo -e "\033[38;5;244m   Solution: Use --database-only flag or use full backup (.tar.gz)\033[0m"
        compatibility_issues=$((compatibility_issues + 1))
    fi
    
    if [ "$database_only" = true ] && [ "$backup_type" = "archive" ]; then
        echo -e "\033[1;32m✅ Database-only restore from archive (will extract database.sql)\033[0m"
    elif [ "$database_only" = true ] && [[ "$backup_file" =~ \.sql ]]; then
        echo -e "\033[1;32m✅ Database-only restore from SQL file\033[0m"
    elif [ "$database_only" = false ] && [ "$backup_type" = "archive" ]; then
        echo -e "\033[1;32m✅ Full system restore from archive\033[0m"
    fi
    
    if [ $compatibility_issues -gt 0 ]; then
        echo -e "\033[1;31m❌ Cannot proceed due to compatibility issues\033[0m"
        return 1
    fi
    
    # Проверяем текущее состояние
    echo
    echo -e "\033[1;37m⚙️  System Analysis:\033[0m"
    
    local target_exists=false
    local backup_needed=false
    
    if [ -d "$target_dir" ]; then
        target_exists=true
        echo -e "\033[1;33m⚠️  Target directory exists: $target_dir\033[0m"
        
        if [ "$database_only" = false ]; then
            echo -e "\033[38;5;244m   • Directory will be backed up and replaced\033[0m"
            backup_needed=true
        else
            echo -e "\033[38;5;244m   • Only database will be restored\033[0m"
        fi
    else
        echo -e "\033[1;32m✅ Target directory is clean: $target_dir\033[0m"
    fi
    
    # Проверяем наличие управляющего скрипта
    local script_exists=false
    if [ -f "/usr/local/bin/$target_app_name" ]; then
        script_exists=true
        echo -e "\033[1;33m⚠️  Management script exists: /usr/local/bin/$target_app_name\033[0m"
        if [ "$skip_install" = false ]; then
            echo -e "\033[38;5;244m   • Script will be updated\033[0m"
        fi
    else
        echo -e "\033[1;32m✅ No conflicting management script found\033[0m"
    fi
    
    # Запрашиваем подтверждение
    if [ "$force_restore" != true ]; then
        echo
        echo -e "\033[1;37m🤔 Proceed with restore operation?\033[0m"
        read -p "Continue? [y/N]: " -r confirm
        
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo -e "\033[38;5;250mRestore cancelled\033[0m"
            return 0
        fi
    fi
    
    # Начинаем процесс восстановления
    echo
    echo -e "\033[1;37m🔄 Starting Restore Process\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    
    # Шаг 1: Резервное копирование существующей установки
    if [ "$backup_needed" = true ]; then
        echo -e "\033[38;5;250m📝 Step 1:\033[0m Creating safety backup..."
        
        local safety_backup_dir="/opt/restore_backups"
        local safety_backup_name="${target_app_name}_pre_restore_$(date +%Y%m%d_%H%M%S)"
        
        mkdir -p "$safety_backup_dir"
        
        if tar -czf "$safety_backup_dir/${safety_backup_name}.tar.gz" -C "$(dirname "$target_dir")" "$(basename "$target_dir")" 2>/dev/null; then
            echo -e "\033[1;32m✅ Safety backup created: $safety_backup_dir/${safety_backup_name}.tar.gz\033[0m"
        else
            echo -e "\033[1;33m⚠️  Safety backup failed, but continuing...\033[0m"
        fi
    fi
    
    # Шаг 2: Обработка в зависимости от типа восстановления
    if [ "$database_only" = false ] && [ "$backup_type" = "archive" ]; then
        # Полное восстановление из архива
        restore_full_from_archive "$backup_file" "$target_dir" "$target_app_name" "$original_app_name" "$skip_install"
    elif [ "$database_only" = true ]; then
        # Восстановление только БД
        restore_database_only "$backup_file" "$backup_type" "$target_dir" "$target_app_name"
    fi
    
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo -e "\033[1;37m🎉 Restore Completed!\033[0m"
    echo
    
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Restored from:" "$(basename "$backup_file")"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Target name:" "$target_app_name"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Installation path:" "$target_dir"
    
    # Показываем URL доступа если возможно
    if [ -f "$target_dir/.env" ] && [ "$database_only" = false ]; then
        local app_port=$(grep "^APP_PORT=" "$target_dir/.env" | cut -d'=' -f2 2>/dev/null)
        local server_ip="${NODE_IP:-127.0.0.1}"
        
        echo
        echo -e "\033[1;37m🌐 Panel Access:\033[0m"
        if [ -n "$app_port" ]; then
            printf "   \033[38;5;15m%-20s\033[0m \033[38;5;117mhttp://%s:%s\033[0m\n" "Panel URL:" "$server_ip" "$app_port"
        fi
    fi
    
    echo
    echo -e "\033[38;5;8m💡 Next steps:\033[0m"
    echo -e "\033[38;5;244m   • Check status: sudo $target_app_name status\033[0m"
    echo -e "\033[38;5;244m   • View logs: sudo $target_app_name logs\033[0m"
    echo -e "\033[38;5;244m   • Health check: sudo $target_app_name health\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
}

restore_full_from_archive() {
    local backup_file="$1"
    local target_dir="$2"
    local target_app_name="$3"
    local original_app_name="$4"
    local skip_install="$5"
    
    log_restore_operation "Full Restore" "STARTED" "File: $backup_file, Target: $target_dir, App: $target_app_name"
    
    # Step 0: Проверка системных ресурсов
    echo -e "\033[38;5;250m📝 Step 0:\033[0m Checking system resources..."
    if ! check_system_resources "$backup_file" "$target_dir"; then
        log_restore_operation "Resource Check" "ERROR" "Insufficient system resources"
        return 1
    fi
    log_restore_operation "Resource Check" "SUCCESS" "System resources verified"
    
    # Step 1: Создание safety backup
    echo -e "\033[38;5;250m📝 Step 1:\033[0m Creating safety backup..."
    local backup_parent_dir="$(dirname "$target_dir")/backups"
    mkdir -p "$backup_parent_dir"
    
    if ! create_safety_backup "$target_dir" "$target_app_name" "$backup_parent_dir"; then
        echo -e "\033[1;33m⚠️  Failed to create safety backup, continuing with caution...\033[0m"
        log_restore_operation "Safety Backup" "WARNING" "Failed to create safety backup"
    else
        log_restore_operation "Safety Backup" "SUCCESS" "Safety backup created"
    fi
    
    # Step 2: Остановка существующих сервисов
    local services_were_running=false
    if [ -f "$target_dir/docker-compose.yml" ]; then
        echo -e "\033[38;5;250m📝 Step 2:\033[0m Stopping existing services..."
        
        cd "$target_dir"
        if docker compose ps -q | grep -q .; then
            services_were_running=true
            if docker compose down 2>/dev/null; then
                echo -e "\033[1;32m✅ Services stopped\033[0m"
                log_restore_operation "Service Shutdown" "SUCCESS" "All services stopped"
            else
                echo -e "\033[1;33m⚠️  Failed to stop services, continuing...\033[0m"
                log_restore_operation "Service Shutdown" "WARNING" "Failed to stop some services"
            fi
        else
            echo -e "\033[38;5;244m   No running services found\033[0m"
            log_restore_operation "Service Shutdown" "INFO" "No running services found"
        fi
    fi
    
    # Step 3: Извлечение архива
    echo -e "\033[38;5;250m📝 Step 3:\033[0m Extracting backup to target directory..."
    
    # Предварительная валидация архива
    echo -e "\033[38;5;244m   Validating backup archive...\033[0m"
    
    # Проверка 1: Файл существует
    if [ ! -f "$backup_file" ]; then
        echo -e "\033[1;31m❌ Backup file does not exist: $backup_file\033[0m"
        log_restore_operation "Archive Validation" "ERROR" "Backup file not found: $backup_file"
        return 1
    fi
    
    # Проверка 2: Файл читаемый
    if [ ! -r "$backup_file" ]; then
        echo -e "\033[1;31m❌ Backup file is not readable: $backup_file\033[0m"
        log_restore_operation "Archive Validation" "ERROR" "Backup file not readable"
        return 1
    fi
    
    # Проверка 3: Размер файла > 0
    local file_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null)
    if [ -z "$file_size" ] || [ "$file_size" -eq 0 ]; then
        echo -e "\033[1;31m❌ Backup file is empty or size cannot be determined\033[0m"
        log_restore_operation "Archive Validation" "ERROR" "Backup file is empty"
        return 1
    fi
    echo -e "\033[38;5;244m   Archive size: $(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "${file_size} bytes")\033[0m"
    
    # Проверка 4: Валидный tar.gz архив
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        echo -e "\033[1;31m❌ Backup file is not a valid tar.gz archive or is corrupted!\033[0m"
        echo -e "\033[38;5;244m   File: $backup_file\033[0m"
        log_restore_operation "Archive Validation" "ERROR" "Invalid or corrupted tar.gz archive"
        return 1
    fi
    echo -e "\033[38;5;244m   ✅ Archive validation passed\033[0m"
    
    # Проверка 5: Достаточно места на диске
    local available_space=$(df "$(dirname "$target_dir")" | awk 'NR==2 {print $4}')
    local required_space=$((file_size * 3 / 1024))  # Примерно 3x размера архива
    if [ "$available_space" -lt "$required_space" ]; then
        echo -e "\033[1;31m❌ Insufficient disk space!\033[0m"
        echo -e "\033[38;5;244m   Required: ~$(numfmt --to=iec-i --suffix=B $((required_space * 1024)) 2>/dev/null || echo "${required_space}KB")\033[0m"
        echo -e "\033[38;5;244m   Available: $(numfmt --to=iec-i --suffix=B $((available_space * 1024)) 2>/dev/null || echo "${available_space}KB")\033[0m"
        log_restore_operation "Archive Validation" "ERROR" "Insufficient disk space"
        return 1
    fi
    
    log_restore_operation "Archive Validation" "SUCCESS" "Archive validated successfully"
    
    # КРИТИЧЕСКИ ВАЖНО: Копируем backup file в безопасное место ПЕРЕД удалением target_dir
    # Проблема: если backup_file находится внутри target_dir (например /opt/remnawave/backups/),
    # он будет удален вместе с target_dir
    local safe_backup_file="$backup_file"
    local temp_backup_copy=""
    
    if [[ "$backup_file" == "$target_dir"* ]]; then
        echo -e "\033[38;5;244m   Backup is inside target directory, creating temporary copy...\033[0m"
        temp_backup_copy="/tmp/restore_backup_$(date +%s)_$(basename "$backup_file")"
        
        if cp "$backup_file" "$temp_backup_copy"; then
            safe_backup_file="$temp_backup_copy"
            backup_file="$temp_backup_copy"  # Обновляем переменную для использования далее
            echo -e "\033[38;5;244m   ✅ Temporary copy created: $temp_backup_copy\033[0m"
            log_restore_operation "Backup Safety" "SUCCESS" "Created temporary backup copy"
        else
            echo -e "\033[1;31m❌ Failed to create temporary backup copy!\033[0m"
            log_restore_operation "Backup Safety" "ERROR" "Failed to create temporary copy"
            return 1
        fi
    fi
    
    # Удаляем старую директорию если нужно
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
    
    # Создаем родительскую директорию
    mkdir -p "$(dirname "$target_dir")"
    
    # Извлекаем архив
    echo -e "\033[38;5;244m   Extracting archive...\033[0m"
    local temp_extract_dir="/tmp/restore_extract_$$"
    mkdir -p "$temp_extract_dir"
    
    # Извлекаем с показом реальных ошибок
    local tar_error_log="/tmp/tar_error_$$"
    if tar -xzf "$backup_file" -C "$temp_extract_dir" 2>"$tar_error_log"; then
        # Находим директорию с бэкапом
        local backup_content=$(ls "$temp_extract_dir")
        local backup_dir_name=$(echo "$backup_content" | head -1)
        
        if [ -d "$temp_extract_dir/$backup_dir_name" ]; then
            # Проверяем структуру - новый unified формат или старый с app/
            if [ -f "$temp_extract_dir/$backup_dir_name/docker-compose.yml" ]; then
                # НОВЫЙ ФОРМАТ: файлы приложения в корне бэкапа
                mv "$temp_extract_dir/$backup_dir_name" "$target_dir"
                echo -e "\033[1;32m✅ Backup extracted successfully (unified format)\033[0m"
                log_restore_operation "Archive Extraction" "SUCCESS" "Unified format backup extracted"
            elif [ -d "$temp_extract_dir/$backup_dir_name/app" ]; then
                # СТАРЫЙ ФОРМАТ: приложение в поддиректории app
                mv "$temp_extract_dir/$backup_dir_name/app" "$target_dir"
                
                # Копируем database.sql в target_dir для последующего использования
                if [ -f "$temp_extract_dir/$backup_dir_name/database.sql" ]; then
                    cp "$temp_extract_dir/$backup_dir_name/database.sql" "$target_dir/"
                fi
                
                # Сохраняем скрипт установки
                if [ -f "$temp_extract_dir/$backup_dir_name/install-script.sh" ]; then
                    cp "$temp_extract_dir/$backup_dir_name/install-script.sh" "/tmp/restore_script_$$"
                fi
                
                echo -e "\033[1;32m✅ Backup extracted successfully (legacy format)\033[0m"
                log_restore_operation "Archive Extraction" "SUCCESS" "Legacy format backup extracted"
            else
                # Очень старый формат - вся директория является приложением
                mv "$temp_extract_dir/$backup_dir_name" "$target_dir"
                echo -e "\033[1;32m✅ Backup extracted successfully (very old format)\033[0m"
                log_restore_operation "Archive Extraction" "SUCCESS" "Very old format backup extracted"
            fi
        else
            echo -e "\033[1;31m❌ Unexpected backup structure!\033[0m"
            echo -e "\033[38;5;244m   Expected directory not found in archive\033[0m"
            log_restore_operation "Archive Extraction" "ERROR" "Unexpected backup structure"
            rm -rf "$temp_extract_dir"
            rm -f "$tar_error_log"
            return 1
        fi
    else
        # Показываем детальную ошибку tar
        echo -e "\033[1;31m❌ Failed to extract backup archive!\033[0m"
        echo -e "\033[38;5;244m   File: $backup_file\033[0m"
        
        # Формируем полный текст ошибки для лога (все строки через точку с запятой)
        local full_error_text=""
        if [ -s "$tar_error_log" ]; then
            echo -e "\033[1;33m   Error details:\033[0m"
            while IFS= read -r line; do
                echo -e "\033[38;5;244m   $line\033[0m"
                # Добавляем строку в полный текст ошибки
                if [ -z "$full_error_text" ]; then
                    full_error_text="$line"
                else
                    full_error_text="$full_error_text; $line"
                fi
            done < "$tar_error_log"
        else
            full_error_text="No error details available"
        fi
        
        echo -e "\033[38;5;244m   Possible causes:\033[0m"
        echo -e "\033[38;5;244m   - Archive is corrupted\033[0m"
        echo -e "\033[38;5;244m   - Archive was not created properly\033[0m"
        echo -e "\033[38;5;244m   - Insufficient permissions\033[0m"
        echo -e "\033[38;5;244m   - Disk I/O error\033[0m"
        
        # Логируем с полным текстом ошибки
        log_restore_operation "Archive Extraction" "ERROR" "Failed to extract tar archive: $full_error_text"
        rm -rf "$temp_extract_dir"
        rm -f "$tar_error_log"
        return 1
    fi
    
    rm -rf "$temp_extract_dir"
    rm -f "$tar_error_log"
    
    # Step 4: Проверка совместимости версий (если есть метаданные)
    if [ -f "$target_dir/backup-metadata.json" ]; then
        echo -e "\033[38;5;250m📝 Step 4a:\033[0m Checking version compatibility..."
        check_version_compatibility "$target_dir/backup-metadata.json"
    fi
    
    # Step 4: Валидация извлеченного бэкапа
    echo -e "\033[38;5;250m📝 Step 4:\033[0m Validating extracted backup..."
    
    # Отладочная информация для диагностики
    if [ -f "$target_dir/docker-compose.yml" ]; then
        echo -e "\033[38;5;244m   Debug: docker-compose.yml found, checking structure...\033[0m"
        
        # Показываем первые 20 строк для диагностики
        if [ "${DEBUG_RESTORE:-false}" = "true" ]; then
            echo -e "\033[38;5;244m   First 20 lines of docker-compose.yml:\033[0m"
            head -20 "$target_dir/docker-compose.yml" | sed 's/^/     /' 2>/dev/null || true
        fi
    fi
    
    if ! validate_extracted_backup "$target_dir" "full" "$target_app_name"; then
        echo -e "\033[1;31m❌ Backup validation failed! Rolling back...\033[0m"
        log_restore_operation "Backup Validation" "ERROR" "Validation failed, initiating rollback"
        rollback_from_safety_backup "$target_dir" "$target_app_name"
        return 1
    else
        log_restore_operation "Backup Validation" "SUCCESS" "Extracted backup validated"
    fi
    
    # Step 5: Установка управляющего скрипта
    if [ "$skip_install" = false ]; then
        echo -e "\033[38;5;250m📝 Step 5:\033[0m Installing management script..."
        
        local script_source=""
        
        # Ищем скрипт в порядке приоритета
        if [ -f "/tmp/restore_script_$$" ]; then
            script_source="/tmp/restore_script_$$"
            echo -e "\033[38;5;244m   Using script from backup\033[0m"
        elif [ -f "$target_dir/install-script.sh" ]; then
            script_source="$target_dir/install-script.sh"
            echo -e "\033[38;5;244m   Using script from extracted files\033[0m"
        elif [ -f "/usr/local/bin/$APP_NAME" ]; then
            script_source="/usr/local/bin/$APP_NAME"
            echo -e "\033[38;5;244m   Using current system script\033[0m"
        fi
        
        if [ -n "$script_source" ]; then
            # Обновляем APP_NAME в скрипте если нужно
            if [ "$target_app_name" != "$original_app_name" ] && [ "$original_app_name" != "unknown" ]; then
                echo -e "\033[38;5;244m   Adapting script for new app name...\033[0m"
                sed "s/APP_NAME=\"$original_app_name\"/APP_NAME=\"$target_app_name\"/" "$script_source" > "/usr/local/bin/$target_app_name"
            else
                cp "$script_source" "/usr/local/bin/$target_app_name"
            fi
            
            chmod +x "/usr/local/bin/$target_app_name"
            echo -e "\033[1;32m✅ Management script installed: /usr/local/bin/$target_app_name\033[0m"
            log_restore_operation "Script Installation" "SUCCESS" "Management script installed: /usr/local/bin/$target_app_name"
        else
            echo -e "\033[1;33m⚠️  No management script found in backup, skipping installation\033[0m"
            log_restore_operation "Script Installation" "WARNING" "No management script found in backup"
        fi
        
        # Очищаем временный файл
        rm -f "/tmp/restore_script_$$"
    fi
    
    # Step 5.5: Проверка использования latest тега в docker-compose.yml
    if [ -f "$target_dir/docker-compose.yml" ]; then
        if grep -q "remnawave/backend:latest" "$target_dir/docker-compose.yml" 2>/dev/null; then
            echo
            echo -e "\033[1;33m⚠️  IMPORTANT: Version Compatibility Warning!\033[0m"
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
            echo
            echo -e "\033[38;5;250mYour backup uses \033[1;37m'latest'\033[38;5;250m tag in docker-compose.yml\033[0m"
            echo -e "\033[38;5;250mThis means Docker will pull the \033[1;31mnewest available version\033[38;5;250m\033[0m"
            echo
            echo -e "\033[1;37m⚠️  Potential Issues:\033[0m"
            echo -e "\033[38;5;250m   • Database schema mismatch if newer version is pulled\033[0m"
            echo -e "\033[38;5;250m   • Breaking changes in newer panel versions\033[0m"
            echo -e "\033[38;5;250m   • Restore may fail or cause data corruption\033[0m"
            echo
            echo -e "\033[1;37m✅ Recommendations:\033[0m"
            echo -e "\033[38;5;250m   1. Check backup metadata for original panel version\033[0m"
            echo -e "\033[38;5;250m   2. Manually edit docker-compose.yml to pin specific version\033[0m"
            echo -e "\033[38;5;250m      Example: remnawave/backend:latest → remnawave/backend:2.2.19\033[0m"
            echo -e "\033[38;5;250m   3. Or cancel and create new backup with pinned version\033[0m"
            echo
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
            echo
            read -p "Continue with 'latest' tag? [y/N]: " -r latest_confirm
            
            if [[ ! $latest_confirm =~ ^[Yy]$ ]]; then
                echo -e "\033[1;33m⚠️  Restore cancelled by user due to version concerns\033[0m"
                log_restore_operation "Version Check" "CANCELLED" "User cancelled due to latest tag usage"
                return 1
            fi
            
            log_restore_operation "Version Check" "WARNING" "User accepted restore with latest tag"
            echo -e "\033[1;32m✅ Proceeding with latest tag (user accepted risk)...\033[0m"
            echo
        fi
    fi
    
    # Step 6: Запуск и восстановление БД (с расширенной обработкой ошибок)
    echo -e "\033[38;5;250m📝 Step 6:\033[0m Starting database restore..."
    if ! restore_database_in_existing_installation "$target_dir" "$target_app_name"; then
        echo -e "\033[1;31m❌ Database restore failed! Rolling back...\033[0m"
        log_restore_operation "Database Restore" "ERROR" "Database restore failed, initiating rollback"
        rollback_from_safety_backup "$target_dir" "$target_app_name"
        return 1
    else
        log_restore_operation "Database Restore" "SUCCESS" "Database successfully restored"
    fi
    
    # Step 6.5: Восстановление Telegram ботов (если есть)
    if [ -d "$target_dir/telegram-bots" ]; then
        echo -e "\033[38;5;250m📝 Step 6.5:\033[0m Restoring Telegram bots..."
        if restore_telegram_bots "$target_dir" "$target_app_name"; then
            echo -e "\033[1;32m✅ Telegram bots restored successfully\033[0m"
            log_restore_operation "Telegram Bots Restore" "SUCCESS" "Telegram bots restored"
        else
            echo -e "\033[1;33m⚠️  Some Telegram bots failed to restore, check logs\033[0m"
            log_restore_operation "Telegram Bots Restore" "WARNING" "Some bots failed to restore"
        fi
    fi
    
    # Step 6.6: Восстановление Caddy (если есть в бэкапе)
    if [ -d "$target_dir/caddy" ]; then
        echo -e "\033[38;5;250m📝 Step 6.6:\033[0m Restoring Caddy configuration..."
        local caddy_target="/opt/caddy-remnawave"
        
        if [ -d "$caddy_target" ]; then
            echo -e "\033[38;5;244m   Caddy directory exists, backing up before restore...\033[0m"
            cp -r "$caddy_target" "${caddy_target}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        else
            mkdir -p "$caddy_target"
        fi
        
        # Копируем файлы Caddy
        local caddy_restored=0
        for caddy_file in "$target_dir/caddy"/*; do
            if [ -f "$caddy_file" ]; then
                local filename=$(basename "$caddy_file")
                if [ "$filename" != "caddy-info.txt" ]; then
                    cp "$caddy_file" "$caddy_target/" 2>/dev/null && caddy_restored=$((caddy_restored + 1))
                fi
            fi
        done
        
        if [ $caddy_restored -gt 0 ]; then
            echo -e "\033[1;32m✅ Caddy configuration restored ($caddy_restored files to $caddy_target)\033[0m"
            log_restore_operation "Caddy Restore" "SUCCESS" "Caddy restored: $caddy_restored files"
            
            # Показываем подсказку о перезапуске Caddy
            echo -e "\033[38;5;244m   💡 Restart Caddy: cd $caddy_target && docker compose restart\033[0m"
        else
            echo -e "\033[1;33m⚠️  No Caddy files were restored\033[0m"
            log_restore_operation "Caddy Restore" "WARNING" "No files restored"
        fi
    fi
    
    # Step 6.7: Восстановление Traefik (если есть в бэкапе)
    if [ -d "$target_dir/traefik" ]; then
        echo -e "\033[38;5;250m📝 Step 6.7:\033[0m Restoring Traefik configuration..."
        
        # Определяем путь для восстановления Traefik
        local traefik_target=""
        
        # Сначала проверяем сохранённый путь в info файле
        if [ -f "$target_dir/traefik/traefik-info.txt" ]; then
            traefik_target=$(grep "^traefik_path=" "$target_dir/traefik/traefik-info.txt" 2>/dev/null | cut -d'=' -f2)
        fi
        
        # Если путь не найден, используем стандартный
        if [ -z "$traefik_target" ]; then
            for traefik_path in "/opt/traefik" "/opt/traefik-remnawave" "/etc/traefik"; do
                if [ -d "$traefik_path" ]; then
                    traefik_target="$traefik_path"
                    break
                fi
            done
        fi
        
        # Если путь всё ещё не определён, используем дефолтный
        if [ -z "$traefik_target" ]; then
            traefik_target="/opt/traefik"
        fi
        
        if [ -d "$traefik_target" ]; then
            echo -e "\033[38;5;244m   Traefik directory exists, backing up before restore...\033[0m"
            cp -r "$traefik_target" "${traefik_target}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        else
            mkdir -p "$traefik_target"
        fi
        
        # Копируем файлы Traefik
        local traefik_restored=0
        for traefik_file in "$target_dir/traefik"/*; do
            if [ -f "$traefik_file" ]; then
                local filename=$(basename "$traefik_file")
                if [ "$filename" != "traefik-info.txt" ]; then
                    cp "$traefik_file" "$traefik_target/" 2>/dev/null && traefik_restored=$((traefik_restored + 1))
                fi
            elif [ -d "$traefik_file" ]; then
                # Копируем директории (например dynamic/)
                cp -r "$traefik_file" "$traefik_target/" 2>/dev/null && traefik_restored=$((traefik_restored + 1))
            fi
        done
        
        if [ $traefik_restored -gt 0 ]; then
            echo -e "\033[1;32m✅ Traefik configuration restored ($traefik_restored items to $traefik_target)\033[0m"
            log_restore_operation "Traefik Restore" "SUCCESS" "Traefik restored: $traefik_restored items"
            
            # Показываем подсказку о перезапуске Traefik
            echo -e "\033[38;5;244m   💡 Restart Traefik: cd $traefik_target && docker compose restart\033[0m"
        else
            echo -e "\033[1;33m⚠️  No Traefik files were restored\033[0m"
            log_restore_operation "Traefik Restore" "WARNING" "No files restored"
        fi
    fi
    
    # Step 7: Проверка целостности восстановления
    echo -e "\033[38;5;250m📝 Step 7:\033[0m Performing final integrity check..."
    local integrity_result=0
    verify_restore_integrity "$target_dir" "$target_app_name" "full"
    integrity_result=$?
    
    if [ $integrity_result -eq 0 ]; then
        echo -e "\033[1;32m🎉 Full restore completed successfully!\033[0m"
        log_restore_operation "Full Restore" "SUCCESS" "Restore completed successfully with full integrity"
        
        # Очищаем временную копию бэкапа если создавалась
        if [ -n "$temp_backup_copy" ] && [ -f "$temp_backup_copy" ]; then
            echo -e "\033[38;5;244m   Cleaning up temporary backup copy...\033[0m"
            rm -f "$temp_backup_copy"
            log_restore_operation "Cleanup" "SUCCESS" "Temporary backup copy removed"
        fi
        
        # Очищаем safety backup при успешном восстановлении
        if [ -f "/tmp/safety_backup_location_$$" ]; then
            local safety_backup_dir=$(cat "/tmp/safety_backup_location_$$")
            echo -e "\033[38;5;244m   Cleaning up safety backup: $safety_backup_dir\033[0m"
            rm -rf "$safety_backup_dir" 2>/dev/null
            rm -f "/tmp/safety_backup_location_$$"
            log_restore_operation "Cleanup" "SUCCESS" "Safety backup cleaned up"
        fi
        return 0
    elif [ $integrity_result -eq 1 ]; then
        echo -e "\033[1;33m⚠️  Restore completed with warnings - please check the application\033[0m"
        log_restore_operation "Full Restore" "WARNING" "Restore completed with integrity warnings"
        
        # Очищаем временную копию бэкапа и при частичном успехе
        if [ -n "$temp_backup_copy" ] && [ -f "$temp_backup_copy" ]; then
            rm -f "$temp_backup_copy"
        fi
        
        return 0
    else
        echo -e "\033[1;31m❌ Restore failed integrity check! Rolling back...\033[0m"
        log_restore_operation "Full Restore" "ERROR" "Restore failed integrity check, rolling back"
        
        # Очищаем временную копию бэкапа и при ошибке
        if [ -n "$temp_backup_copy" ] && [ -f "$temp_backup_copy" ]; then
            rm -f "$temp_backup_copy"
        fi
        
        rollback_from_safety_backup "$target_dir" "$target_app_name"
        return 1
    fi
}

restore_database_only() {
    local backup_file="$1"
    local backup_type="$2"
    local target_dir="$3"
    local target_app_name="$4"
    
    log_restore_operation "Database Only Restore" "STARTED" "File: $backup_file, Type: $backup_type, Target: $target_dir"
    
    # ВАЖНОЕ ПРЕДУПРЕЖДЕНИЕ о JWT секретах
    echo
    echo -e "\033[1;33m⚠️  IMPORTANT: Database-Only Restore Detected!\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    echo
    echo -e "\033[1;37m🔐 JWT Secrets Authentication Issue:\033[0m"
    echo
    echo -e "\033[38;5;250mIf you're restoring to a \033[1;37mNEW installation\033[38;5;250m with different JWT secrets,\033[0m"
    echo -e "\033[38;5;250myou \033[1;31mWON'T be able to log in\033[38;5;250m (403 error) after restore.\033[0m"
    echo
    echo -e "\033[1;37m✅ Solution (choose ONE):\033[0m"
    echo
    echo -e "\033[38;5;250m   Option 1 - Reset Admin (RECOMMENDED):\033[0m"
    echo -e "\033[38;5;244m   After restore, run: \033[38;5;15m$target_app_name console\033[0m"
    echo -e "\033[38;5;244m   Then select: \033[38;5;15m\"Reset superadmin\"\033[0m"
    echo
    echo -e "\033[38;5;250m   Option 2 - Match Old JWT Secrets:\033[0m"
    echo -e "\033[38;5;244m   Copy these from your OLD .env to NEW .env:\033[0m"
    echo -e "\033[38;5;244m   • JWT_AUTH_SECRET\033[0m"
    echo -e "\033[38;5;244m   • JWT_API_TOKENS_SECRET\033[0m"
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    echo
    read -p "Do you understand and want to continue? (y/n): " -r jwt_warning_confirm
    
    if [[ ! $jwt_warning_confirm =~ ^[Yy]$ ]]; then
        echo -e "\033[1;31m❌ Database restore cancelled by user\033[0m"
        log_restore_operation "Database Only Restore" "CANCELLED" "User cancelled due to JWT warning"
        return 1
    fi
    
    echo -e "\033[1;32m✅ Proceeding with database-only restore...\033[0m"
    echo
    
    # Step 1: Создание safety backup базы данных
    echo -e "\033[38;5;250m📝 Step 1:\033[0m Creating database safety backup..."
    local backup_parent_dir="$(dirname "$target_dir")/backups"
    mkdir -p "$backup_parent_dir"
    
    if ! create_safety_backup "$target_dir" "$target_app_name" "$backup_parent_dir"; then
        echo -e "\033[1;33m⚠️  Failed to create safety backup, continuing with caution...\033[0m"
        log_restore_operation "Safety Backup" "WARNING" "Failed to create safety backup"
    else
        log_restore_operation "Safety Backup" "SUCCESS" "Safety backup created"
    fi
    
    echo -e "\033[38;5;250m📝 Step 2:\033[0m Preparing database file..."
    
    local database_file=""
    
    # Получаем файл БД в зависимости от типа
    if [ "$backup_type" = "sql" ]; then
        database_file="$backup_file"
    elif [ "$backup_type" = "compressed_sql" ]; then
        # Распаковываем во временный файл
        database_file="/tmp/restore_db_$$.sql"
        if gunzip -c "$backup_file" > "$database_file"; then
            echo -e "\033[1;32m✅ SQL file decompressed\033[0m"
        else
            echo -e "\033[1;31m❌ Failed to decompress SQL file!\033[0m"
            return 1
        fi
    elif [ "$backup_type" = "archive" ]; then
        # Извлекаем файл базы данных из архива (поддержка разных имен)
        local temp_db_dir="/tmp/restore_db_$$"
        mkdir -p "$temp_db_dir"
        
        # Сначала получаем список всех файлов в архиве
        local archive_contents
        mapfile -t archive_contents < <(tar -tzf "$backup_file" 2>/dev/null | grep -E '\.(sql|sql\.gz|sql\.bz2|sql\.xz)$' | head -20)
        
        if [ ${#archive_contents[@]} -eq 0 ]; then
            echo -e "\033[1;31m❌ No database files found in archive!\033[0m"
            rm -rf "$temp_db_dir"
            return 1
        fi
        
        # Приоритетный список для выбора лучшего файла БД
        local priority_patterns=("database.sql" "db_backup.sql" "backup.sql" "dump.sql" "*.sql")
        local found_db_file=""
        local selected_file=""
        
        # Ищем файл по приоритету
        for pattern in "${priority_patterns[@]}"; do
            for archive_file in "${archive_contents[@]}"; do
                local basename_file=$(basename "$archive_file")
                if [[ "$basename_file" == $pattern ]]; then
                    selected_file="$archive_file"
                    break 2
                fi
            done
        done
        
        # Если не нашли по приоритету, берем первый SQL файл
        if [ -z "$selected_file" ] && [ ${#archive_contents[@]} -gt 0 ]; then
            selected_file="${archive_contents[0]}"
        fi
        
        if [ -n "$selected_file" ]; then
            echo -e "\033[38;5;250m📝 Extracting database file: $selected_file\033[0m"
            if tar -xzf "$backup_file" -C "$temp_db_dir" "$selected_file" 2>/dev/null; then
                found_db_file="$temp_db_dir/$selected_file"
                if [ -f "$found_db_file" ]; then
                    echo -e "\033[1;32m✅ Database file extracted from archive: $(basename "$found_db_file")\033[0m"
                    database_file="$found_db_file"
                else
                    echo -e "\033[1;31m❌ Extracted file not found: $found_db_file\033[0m"
                    rm -rf "$temp_db_dir"
                    return 1
                fi
            else
                echo -e "\033[1;31m❌ Failed to extract $selected_file from archive!\033[0m"
                rm -rf "$temp_db_dir"
                return 1
            fi
        else
            echo -e "\033[1;31m❌ No suitable database files found in archive!\033[0m"
            rm -rf "$temp_db_dir"
            return 1
        fi
    fi
    
    # Step 3: Валидация файла базы данных
    if [ -n "$database_file" ] && [ -f "$database_file" ]; then
        echo -e "\033[38;5;250m📝 Step 3:\033[0m Validating database file..."
        
        # Используем улучшенную валидацию SQL
        if ! validate_sql_integrity "$database_file"; then
            echo -e "\033[1;31m❌ Database file validation failed! Rolling back...\033[0m"
            log_restore_operation "SQL Validation" "ERROR" "Database file failed validation"
            rollback_from_safety_backup "$target_dir" "$target_app_name"
            return 1
        fi
        
        log_restore_operation "SQL Validation" "SUCCESS" "Database file validation passed"
        echo -e "\033[1;32m✅ Database file validation passed\033[0m"
    else
        echo -e "\033[1;31m❌ Database file not found or inaccessible!\033[0m"
        log_restore_operation "File Check" "ERROR" "Database file not found or inaccessible"
        return 1
    fi
    
    # Step 4: Восстанавливаем БД в существующей установке (с обработкой ошибок)
    if ! restore_database_in_existing_installation "$target_dir" "$target_app_name" "$database_file"; then
        echo -e "\033[1;31m❌ Database restore failed! Rolling back...\033[0m"
        log_restore_operation "Database Restore" "ERROR" "Database restore failed, initiating rollback"
        rollback_from_safety_backup "$target_dir" "$target_app_name"
        return 1
    fi
    
    # Step 5: Проверка целостности БД
    echo -e "\033[38;5;250m📝 Step 5:\033[0m Verifying database integrity..."
    local integrity_result=0
    verify_restore_integrity "$target_dir" "$target_app_name" "database"
    integrity_result=$?
    
    if [ $integrity_result -le 1 ]; then
        echo -e "\033[1;32m🎉 Database restore completed successfully!\033[0m"
        log_restore_operation "Database Only Restore" "SUCCESS" "Database restore completed with integrity check"
        # Очищаем safety backup при успешном восстановлении
        if [ -f "/tmp/safety_backup_location_$$" ]; then
            local safety_backup_dir=$(cat "/tmp/safety_backup_location_$$")
            echo -e "\033[38;5;244m   Cleaning up safety backup: $safety_backup_dir\033[0m"
            rm -rf "$safety_backup_dir" 2>/dev/null
            rm -f "/tmp/safety_backup_location_$$"
        fi
    else
        echo -e "\033[1;33m⚠️  Database restore completed but integrity check has warnings\033[0m"
    fi
    
    # Очищаем временные файлы
    if [ "$backup_type" = "compressed_sql" ]; then
        rm -f "/tmp/restore_db_$$.sql"
    elif [ "$backup_type" = "archive" ]; then
        rm -rf "/tmp/restore_db_$$"
    fi
}

restore_database_in_existing_installation() {
    local target_dir="$1"
    local target_app_name="$2"
    local database_file="$3"
    
    log_restore_operation "Database Installation" "STARTED" "Target: $target_dir, App: $target_app_name"

    if [ -z "$database_file" ]; then
        # Ищем файл БД в target_dir более надежным способом
        local found_db_files=()
        
        # Используем find для поиска всех файлов БД
        mapfile -t found_db_files < <(
            find "$target_dir" -maxdepth 1 -type f \( \
                -name "*.sql" -o \
                -name "*.sql.gz" -o \
                -name "*.sql.bz2" -o \
                -name "*.sql.xz" \
            \) -printf '%f\n' 2>/dev/null | sort
        )
        
        # Если find не поддерживает -printf, используем альтернативный метод
        if [ ${#found_db_files[@]} -eq 0 ]; then
            while IFS= read -r -d '' file; do
                found_db_files+=("$(basename "$file")")
            done < <(find "$target_dir" -maxdepth 1 -type f \( \
                -name "*.sql" -o \
                -name "*.sql.gz" -o \
                -name "*.sql.bz2" -o \
                -name "*.sql.xz" \
            \) -print0 2>/dev/null | sort -z)
        fi
        
        if [ ${#found_db_files[@]} -eq 0 ]; then
            echo -e "\033[1;31m❌ No database files found in $target_dir!\033[0m"
            return 1
        fi
        
        # Приоритетный выбор файла БД
        local priority_patterns=("database.sql" "db_backup.sql" "backup.sql" "dump.sql")
        local selected_db_file=""
        
        # Сначала ищем по приоритету среди несжатых файлов
        for pattern in "${priority_patterns[@]}"; do
            for db_file in "${found_db_files[@]}"; do
                if [[ "$db_file" == "$pattern" ]]; then
                    selected_db_file="$db_file"
                    break 2
                fi
            done
        done
        
        # Если не нашли несжатый, ищем сжатый по приоритету
        if [ -z "$selected_db_file" ]; then
            for pattern in "${priority_patterns[@]}"; do
                for db_file in "${found_db_files[@]}"; do
                    if [[ "$db_file" == "${pattern}.gz" ]] || [[ "$db_file" == "${pattern}.bz2" ]] || [[ "$db_file" == "${pattern}.xz" ]]; then
                        selected_db_file="$db_file"
                        break 2
                    fi
                done
            done
        fi
        
        # Если все еще не нашли, берем первый доступный файл
        if [ -z "$selected_db_file" ] && [ ${#found_db_files[@]} -gt 0 ]; then
            selected_db_file="${found_db_files[0]}"
        fi
        
        if [ -n "$selected_db_file" ]; then
            local full_db_path="$target_dir/$selected_db_file"
            
            # Проверяем, сжат ли файл
            if [[ "$selected_db_file" =~ \.(gz|bz2|xz)$ ]]; then
                local temp_sql="/tmp/restore_expanded_$$.sql"
                local decompress_cmd=""
                
                case "$selected_db_file" in
                    *.gz) decompress_cmd="gunzip -c" ;;
                    *.bz2) decompress_cmd="bunzip2 -c" ;;
                    *.xz) decompress_cmd="xz -dc" ;;
                esac
                
                if $decompress_cmd "$full_db_path" > "$temp_sql" 2>/dev/null; then
                    database_file="$temp_sql"
                    log_restore_operation "Database File" "INFO" "Using compressed $selected_db_file from target directory (decompressed)"
                    echo -e "\033[38;5;244m   Found compressed database file: $selected_db_file (decompressed)\033[0m"
                else
                    echo -e "\033[1;33m⚠️  Failed to decompress $selected_db_file\033[0m"
                fi
            else
                database_file="$full_db_path"
                log_restore_operation "Database File" "INFO" "Using $selected_db_file from target directory"
                echo -e "\033[38;5;244m   Found database file: $selected_db_file\033[0m"
            fi
        fi
    fi
    
    if [ -z "$database_file" ] || [ ! -f "$database_file" ]; then
        echo -e "\033[1;31m❌ Database file not found!\033[0m"
        echo -e "\033[38;5;244m   Expected: $target_dir/database.sql\033[0m"
        return 1
    fi
    
    # Дополнительная валидация файла БД
    local db_size=$(wc -c < "$database_file" 2>/dev/null || echo "0")
    if [ "$db_size" -lt 100 ]; then
        echo -e "\033[1;31m❌ Database file appears to be empty or corrupted (size: $db_size bytes)!\033[0m"
        return 1
    fi
    
    if [ ! -f "$target_dir/docker-compose.yml" ]; then
        echo -e "\033[1;31m❌ No docker-compose.yml found! Cannot restore database.\033[0m"
        return 1
    fi
    cd "$target_dir"
    
    echo -e "\033[38;5;250m📝 Starting database service...\033[0m"
    
    # Запускаем ТОЛЬКО базу данных для восстановления
    local db_startup_log="/tmp/db_startup_$$.log"
    if docker compose up -d "${target_app_name}-db" 2>"$db_startup_log"; then
        echo -e "\033[1;32m✅ Database service started\033[0m"
        
        # Ждем готовности базы данных через healthcheck
        echo -e "\033[38;5;244m   Waiting for database healthcheck...\033[0m"
        local attempts=0
        local max_attempts=60
        
        while [ $attempts -lt $max_attempts ]; do
            local health_status=$(docker inspect --format='{{.State.Health.Status}}' "${target_app_name}-db" 2>/dev/null)
            
            if [ "$health_status" == "healthy" ]; then
                echo -e "\033[1;32m✅ Database is healthy (attempt $((attempts + 1)), ${attempts}s)\033[0m"
                break
            fi
            
            # Показываем текущий статус каждые 10 попыток
            if [ $((attempts % 10)) -eq 0 ] && [ $attempts -gt 0 ]; then
                echo -e "\033[38;5;244m   Still waiting... Current status: ${health_status:-starting} (${attempts}s elapsed)\033[0m"
            fi
            
            sleep 1
            attempts=$((attempts + 1))
            
            if [ $attempts -eq $max_attempts ]; then
                echo -e "\033[1;31m❌ Database healthcheck timeout after $max_attempts seconds!\033[0m"
                echo -e "\033[38;5;244m   Final status: ${health_status:-unknown}\033[0m"
                echo -e "\033[38;5;244m   Check logs: docker compose logs ${target_app_name}-db\033[0m"
                if [ -f "$db_startup_log" ]; then
                    echo -e "\033[38;5;244m   Startup errors:\033[0m"
                    head -10 "$db_startup_log" | sed 's/^/     /'
                fi
                rm -f "$db_startup_log"
                return 1
            fi
        done
    else
        echo -e "\033[1;31m❌ Failed to start database service!\033[0m"
        if [ -f "$db_startup_log" ]; then
            echo -e "\033[38;5;244m   Startup errors:\033[0m"
            head -10 "$db_startup_log" | sed 's/^/     /'
        fi
        rm -f "$db_startup_log"
        return 1
    fi
    
    rm -f "$db_startup_log"
    
    echo -e "\033[38;5;250m📝 Restoring database...\033[0m"
    
    local db_container="${target_app_name}-db"
    local postgres_user="postgres"
    local postgres_password="postgres"
    local postgres_db="postgres"
    
    # Читаем настройки из env файла если доступны
    if [ -f "$target_dir/.env" ]; then
        postgres_user=$(grep "^POSTGRES_USER=" "$target_dir/.env" | cut -d'=' -f2 2>/dev/null || echo "postgres")
        postgres_password=$(grep "^POSTGRES_PASSWORD=" "$target_dir/.env" | cut -d'=' -f2 2>/dev/null || echo "postgres")
        postgres_db=$(grep "^POSTGRES_DB=" "$target_dir/.env" | cut -d'=' -f2 2>/dev/null || echo "postgres")
        echo -e "\033[38;5;244m   Using database credentials from .env file\033[0m"
    fi
    
    # Проверяем подключение к БД
    if ! docker exec -e PGPASSWORD="$postgres_password" "$db_container" \
        psql -U "$postgres_user" -d "$postgres_db" -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "\033[1;31m❌ Cannot connect to database with provided credentials!\033[0m"
        return 1
    fi
    
    # Создаем резервную копию текущей схемы (если есть данные)
    echo -e "\033[38;5;244m   Creating current schema backup...\033[0m"
    local current_schema_backup="/tmp/current_schema_backup_$$.sql"
    docker exec -e PGPASSWORD="$postgres_password" "$db_container" \
        pg_dump -U "$postgres_user" -d "$postgres_db" --schema-only > "$current_schema_backup" 2>/dev/null || true
    
    # Очищаем текущую базу данных
    echo -e "\033[38;5;244m   Clearing current database...\033[0m"
    local clear_db_log="/tmp/clear_db_$$.log"
    if docker exec -e PGPASSWORD="$postgres_password" "$db_container" \
        psql -U "$postgres_user" -d "$postgres_db" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >"$clear_db_log" 2>&1; then
        echo -e "\033[1;32m✅ Database cleared\033[0m"
    else
        echo -e "\033[1;31m❌ Failed to clear database!\033[0m"
        echo -e "\033[38;5;244m   Clear operation errors:\033[0m"
        head -5 "$clear_db_log" | sed 's/^/     /'
        rm -f "$clear_db_log" "$current_schema_backup"
        return 1
    fi
    rm -f "$clear_db_log"
    
    # Восстанавливаем данные с улучшенной безопасностью и логированием
    echo -e "\033[38;5;244m   Importing backup data ($(du -sh "$database_file" | cut -f1))...\033[0m"
    local restore_log="/tmp/restore_db_$$.log"
    local restore_errors="/tmp/restore_errors_$$.log"
    local restore_errors_file="${target_app_dir}/logs/restore_errors_$(date +%Y%m%d_%H%M%S).log"
    
    # Создаем директорию для логов
    mkdir -p "${target_app_dir}/logs"
    
    log_restore_operation "Database Import" "STARTED" "Importing $(du -sh "$database_file" | cut -f1) of data"
    
    # Восстанавливаем базу данных через stdin
    if cat "$database_file" | docker exec -i -e PGPASSWORD="$postgres_password" "$db_container" \
        psql -U "$postgres_user" -d "$postgres_db" --set ON_ERROR_STOP=on \
        >"$restore_log" 2>"$restore_errors"; then
        
        # Проверяем что данные действительно восстановились
        local table_count=$(docker exec -e PGPASSWORD="$postgres_password" "$db_container" \
            psql -U "$postgres_user" -d "$postgres_db" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ' || echo "0")
        
        if [ "$table_count" -gt 0 ]; then
            echo -e "\033[1;32m✅ Database restored successfully ($table_count tables)\033[0m"
            log_restore_operation "Database Import" "SUCCESS" "$table_count tables restored"
        else
            echo -e "\033[1;33m⚠️  Database restore completed but no tables found\033[0m"
            log_restore_operation "Database Import" "WARNING" "Restore completed but no tables found"
        fi
    else
        echo -e "\033[1;31m❌ Database restore failed!\033[0m"
        log_restore_operation "Database Import" "ERROR" "Database restore failed"
        
        # Сохраняем полные логи ошибок в файл
        if [ -f "$restore_errors" ] && [ -s "$restore_errors" ]; then
            {
                echo "==================================="
                echo "Database Restore Error Log"
                echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "Database: $postgres_db"
                echo "User: $postgres_user"
                echo "==================================="
                echo ""
                cat "$restore_errors"
                echo ""
                echo "==================================="
            } > "$restore_errors_file"
            
            echo -e "\033[38;5;244m   Full error log saved to: $restore_errors_file\033[0m"
            echo -e "\033[38;5;244m   Error preview:\033[0m"
            head -10 "$restore_errors" | sed 's/^/     /'
        fi
        
        # Показываем детали ошибки если доступны
        if [ -f "$restore_log" ] && [ -s "$restore_log" ]; then
            echo -e "\033[38;5;244m   Last operations:\033[0m"
            tail -5 "$restore_log" | sed 's/^/     /'
        fi
        echo -e "\033[38;5;244m   Check database logs: docker compose logs ${target_app_name}-db\033[0m"
        
        # Пытаемся восстановить старую схему при неудаче
        if [ -f "$current_schema_backup" ] && [ -s "$current_schema_backup" ]; then
            echo -e "\033[38;5;244m   Attempting to restore previous schema...\033[0m"
            docker exec -i -e PGPASSWORD="$postgres_password" "$db_container" \
                psql -U "$postgres_user" -d "$postgres_db" < "$current_schema_backup" >/dev/null 2>&1 || true
        fi
        
        rm -f "$restore_log" "$restore_errors" "$current_schema_backup"
        return 1
    fi
    
    # Очищаем временные файлы
    rm -f "$restore_log" "$restore_errors" "$current_schema_backup"
    
    # Очищаем временные файлы базы данных
    rm -f "$target_dir/database.sql" "$target_dir/db_backup.sql"
    
    # Останавливаем БД перед запуском всех сервисов
    echo -e "\033[38;5;250m📝 Stopping database service...\033[0m"
    docker compose down 2>/dev/null
    
    # Запускаем ВСЕ сервисы с улучшенной обработкой
    echo -e "\033[38;5;250m📝 Starting all services...\033[0m"
    
    local startup_log="/tmp/startup_$$.log"
    if docker compose up -d 2>"$startup_log"; then
        echo -e "\033[1;32m✅ All services started\033[0m"
    else
        echo -e "\033[1;33m⚠️  Service startup had issues\033[0m"
        if [ -f "$startup_log" ]; then
            echo -e "\033[38;5;244m   Startup warnings:\033[0m"
            head -5 "$startup_log" | sed 's/^/     /'
        fi
    fi
    rm -f "$startup_log"
    
    # Проверяем финальный статус с расширенной диагностикой
    echo -e "\033[38;5;244m   Performing health check...\033[0m"
    sleep 8
    
    local services_status=""
    if command -v jq >/dev/null 2>&1; then
        services_status=$(docker compose ps --format json 2>/dev/null | jq -r 'select(.Health == "healthy" or .State == "running") | .Service' 2>/dev/null)
        local healthy_services=$(echo "$services_status" | wc -l)
        local total_services=$(docker compose ps --format json 2>/dev/null | jq -r '.Service' 2>/dev/null | wc -l)
    else
        # Резервный метод без jq
        local healthy_services=$(docker compose ps | grep -c "Up\|healthy" || echo "0")
        local total_services=$(docker compose ps | tail -n +2 | wc -l)
    fi
    
    if [ "$healthy_services" -gt 0 ] && [ "$total_services" -gt 0 ]; then
        if [ "$healthy_services" -eq "$total_services" ]; then
            echo -e "\033[1;32m✅ All services healthy: $healthy_services/$total_services\033[0m"
        else
            echo -e "\033[1;33m⚠️  Partial health: $healthy_services/$total_services services healthy\033[0m"
            echo -e "\033[38;5;244m   Check individual service status: docker compose ps\033[0m"
        fi
    else
        echo -e "\033[1;33m⚠️  Service health check inconclusive\033[0m"
    fi
    
    return 0
}

schedule_test_backup() {
    clear
    echo -e "\033[1;37m🧪 Testing Backup Creation\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
    echo
    
    if ! is_remnawave_up; then
        echo -e "\033[1;31m❌ Remnawave services are not running!\033[0m"
        echo -e "\033[38;5;8m   Start services first with 'sudo $APP_NAME up'\033[0m"
        read -p "Press Enter to continue..."
        return
    fi
    
    if ! ensure_backup_dirs; then
        return 1
    fi
    
    echo -e "\033[38;5;250mCreating test backup...\033[0m"
    
    # Проверяем версию backup скрипта
    check_backup_script_version
    local version_status=$?
    
    if [ $version_status -ne 0 ]; then
        echo
        if prompt_backup_script_update $version_status; then
            schedule_create_backup_script
            echo -e "\033[1;32m✅ Backup script updated successfully\033[0m"
            echo
        fi
    fi
    
    if [ ! -f "$BACKUP_SCRIPT_FILE" ]; then
        schedule_create_backup_script
    fi
    
    if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
        echo -e "\033[1;33m⚠️  No backup configuration found. Creating default...\033[0m"
        schedule_reset_config 
    fi
    
    if bash "$BACKUP_SCRIPT_FILE"; then
        echo -e "\033[1;32m✅ Test backup completed successfully!\033[0m"
        echo -e "\033[38;5;250mCheck $APP_DIR/backups for the backup file\033[0m"
    else
        echo -e "\033[1;31m❌ Test backup failed!\033[0m"
        echo -e "\033[38;5;8m   Check logs: $BACKUP_LOG_FILE\033[0m"
    fi
    
    read -p "Press Enter to continue..."
}

schedule_test_telegram() {
    clear
    echo -e "\033[1;37m📱 Testing Telegram Integration\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 35))\033[0m"
    echo
    
    if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
        echo -e "\033[1;31m❌ No configuration found!\033[0m"
        read -p "Press Enter to continue..."
        return
    fi
    
    local telegram_enabled=$(jq -r '.telegram.enabled // false' "$BACKUP_CONFIG_FILE" 2>/dev/null)
    if [ "$telegram_enabled" != "true" ]; then
        echo -e "\033[1;31m❌ Telegram integration is disabled!\033[0m"
        read -p "Press Enter to continue..."
        return
    fi
    
    local bot_token=$(jq -r '.telegram.bot_token' "$BACKUP_CONFIG_FILE" 2>/dev/null)
    local chat_id=$(jq -r '.telegram.chat_id' "$BACKUP_CONFIG_FILE" 2>/dev/null)
    local thread_id=$(jq -r '.telegram.thread_id' "$BACKUP_CONFIG_FILE" 2>/dev/null)
    
    echo -e "\033[38;5;250mSending test message...\033[0m"
    
    local api_url="https://api.telegram.org/bot$bot_token"
    local message="🧪 Test message from Remnawave Backup System
📅 $(date '+%Y-%m-%d %H:%M:%S')
✅ Telegram integration is working correctly!"
    
    local params="chat_id=$chat_id&text=$(echo "$message" | sed 's/ /%20/g')"
    
    if [ -n "$thread_id" ] && [ "$thread_id" != "null" ]; then
        params="$params&message_thread_id=$thread_id"
    fi
    
    local response=$(curl -s -X POST "$api_url/sendMessage" -d "$params")
    
    if echo "$response" | jq -e '.ok' >/dev/null 2>&1; then
        echo -e "\033[1;32m✅ Test message sent successfully!\033[0m"
        echo -e "\033[38;5;250mCheck your Telegram for the test message\033[0m"
    else
        echo -e "\033[1;31m❌ Failed to send test message!\033[0m"
        echo -e "\033[38;5;244mResponse: $(echo "$response" | jq -r '.description // "Unknown error"')\033[0m"
    fi
    
    read -p "Press Enter to continue..."
}

schedule_status() {
    clear
    echo -e "\033[1;37m📊 Backup Scheduler Status\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 35))\033[0m"
    echo
      local status=$(schedule_get_status)
    
    # Проверяем статус cron service
    echo -e "\033[1;37m🔧 System Status:\033[0m"
    if command -v crontab >/dev/null 2>&1; then
        echo -e "\033[1;32m✅ Cron service: Available\033[0m"
        
        # Проверяем запущен ли cron daemon
        if systemctl is-active cron >/dev/null 2>&1 || systemctl is-active crond >/dev/null 2>&1 || pgrep -x "cron\|crond" >/dev/null 2>&1; then
            echo -e "\033[1;32m✅ Cron daemon: Running\033[0m"
        else
            echo -e "\033[1;33m⚠️  Cron daemon: Not running\033[0m"
        fi
    else
        echo -e "\033[1;31m❌ Cron service: Not installed\033[0m"
        echo -e "\033[38;5;244m   Install with: sudo apt-get install cron\033[0m"
    fi
    echo
    
    echo -e "\033[1;37m📋 Scheduler Status:\033[0m"
    if [ "$status" = "enabled" ]; then
        echo -e "\033[1;32m✅ Status: ENABLED\033[0m"
        

        local cron_line=$(crontab -l 2>/dev/null | grep "$BACKUP_SCRIPT_FILE")
        if [ -n "$cron_line" ]; then
            local schedule=$(echo "$cron_line" | awk '{print $1" "$2" "$3" "$4" "$5}')
            echo -e "\033[38;5;250mSchedule: $schedule\033[0m"
        fi
        
        if command -v crontab >/dev/null && [ -n "$cron_line" ]; then

            local schedule_desc=""
            case "$schedule" in
                "0 2 * * *") schedule_desc="Daily at 2:00 AM" ;;
                "0 4 * * *") schedule_desc="Daily at 4:00 AM" ;;
                "0 */12 * * *") schedule_desc="Every 12 hours" ;;
                "0 2 * * 0") schedule_desc="Weekly on Sunday at 2:00 AM" ;;
                *) schedule_desc="Custom: $schedule" ;;
            esac
            echo -e "\033[38;5;250mFrequency: $schedule_desc\033[0m"
        fi
    else
        echo -e "\033[1;31m❌ Status: DISABLED\033[0m"
    fi
    
    # Проверяем версию backup скрипта
    echo
    echo -e "\033[1;37m🔧 Backup Script Status:\033[0m"
    
    check_backup_script_version
    local version_status=$?
    
    case $version_status in
        0)
            echo -e "\033[1;32m✅ Script version: Current ($BACKUP_SCRIPT_VERSION)\033[0m"
            ;;
        1)
            echo -e "\033[1;33m⚠️  Script status: Not found\033[0m"
            echo -e "\033[38;5;244m   Will be created automatically when needed\033[0m"
            ;;
        2)
            echo -e "\033[1;31m❌ Script version: Legacy (no version info)\033[0m"
            echo -e "\033[38;5;244m   Update recommended for latest features\033[0m"
            ;;
        3)
            # Безопасное чтение версии с timeout
            local script_version=""
            if command -v timeout >/dev/null 2>&1; then
                script_version=$(timeout 5 head -5 "$BACKUP_SCRIPT_FILE" 2>/dev/null | grep "^BACKUP_SCRIPT_VERSION=" | cut -d'"' -f2 2>/dev/null)
            else
                script_version=$(head -5 "$BACKUP_SCRIPT_FILE" 2>/dev/null | grep "^BACKUP_SCRIPT_VERSION=" | cut -d'"' -f2 2>/dev/null)
            fi
            echo -e "\033[1;33m⚠️  Script version: Outdated (${script_version:-'unknown'})\033[0m"
            echo -e "\033[38;5;244m   Current version: $BACKUP_SCRIPT_VERSION - update recommended\033[0m"
            ;;
    esac

    echo
    echo -e "\033[1;37m📦 Recent Backups:\033[0m"
    

    local backup_directory="$APP_DIR/backups"
    

    if [ ! -d "$backup_directory" ]; then
        echo -e "\033[38;5;244m   Backup directory not found: $backup_directory\033[0m"
        echo -e "\033[38;5;244m   Run a backup to create the directory\033[0m"
    else

        local backup_files=""
        

        backup_files=$(ls -t "$backup_directory"/remnawave_scheduled_*.tar.gz "$backup_directory"/remnawave_scheduled_*.sql.gz "$backup_directory"/remnawave_scheduled_*.sql 2>/dev/null | head -5)
        

        if [ -z "$backup_files" ]; then
            backup_files=$(ls -t "$backup_directory"/remnawave_*.tar.gz "$backup_directory"/remnawave_*.sql.gz "$backup_directory"/remnawave_*.sql 2>/dev/null | head -5)
        fi
        
        if [ -n "$backup_files" ]; then
            echo "$backup_files" | while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local filename=$(basename "$file")
                    local file_size=$(du -sh "$file" 2>/dev/null | cut -f1)
                    local file_date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
                    

                    local backup_type="📦"
                    if [[ "$filename" =~ scheduled ]]; then
                        backup_type="🤖"  # автоматический
                    elif [[ "$filename" =~ full ]]; then
                        backup_type="📁"  # полный ручной
                    else
                        backup_type="📊"  # обычный
                    fi
                    
                    printf "   %s \033[38;5;250m%-35s\033[0m \033[38;5;244m%s\033[0m \033[38;5;244m%s\033[0m\n" "$backup_type" "$filename" "$file_size" "$file_date"
                fi
            done
        else
            echo -e "\033[38;5;244m   No backup files found in $backup_directory\033[0m"
            echo -e "\033[38;5;244m   Run a backup to see files here\033[0m"
        fi
    fi
    

    echo
    echo -e "\033[1;37m📈 Statistics:\033[0m"
    
    if [ -d "$backup_directory" ]; then

        local total_backups=$(find "$backup_directory" -maxdepth 1 -type f \( \
            -name "remnawave_*.tar.gz" -o \
            -name "remnawave_*.sql" -o \
            -name "remnawave_*.sql.gz" -o \
            -name "remnawave_*.sql.bz2" -o \
            -name "remnawave_*.sql.xz" \
        \) 2>/dev/null | wc -l)
        local scheduled_backups=$(find "$backup_directory" -maxdepth 1 -type f \( \
            -name "remnawave_scheduled_*.tar.gz" -o \
            -name "remnawave_scheduled_*.sql" -o \
            -name "remnawave_scheduled_*.sql.gz" -o \
            -name "remnawave_scheduled_*.sql.bz2" -o \
            -name "remnawave_scheduled_*.sql.xz" \
        \) 2>/dev/null | wc -l)
        local manual_backups=$(find "$backup_directory" -maxdepth 1 -type f \( \
            -name "remnawave_full_*.tar.gz" -o \
            -name "remnawave_full_*.sql" -o \
            -name "remnawave_full_*.sql.gz" -o \
            -name "remnawave_full_*.sql.bz2" -o \
            -name "remnawave_full_*.sql.xz" -o \
            -name "remnawave_db_*.sql" -o \
            -name "remnawave_db_*.sql.gz" -o \
            -name "remnawave_db_*.sql.bz2" -o \
            -name "remnawave_db_*.sql.xz" \
        \) 2>/dev/null | wc -l)
        
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Total backups:" "$total_backups"
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Scheduled backups:" "$scheduled_backups"
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Manual backups:" "$manual_backups"
        

        local backup_dir_size=$(du -sh "$backup_directory" 2>/dev/null | cut -f1)
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Total size:" "$backup_dir_size"
    else
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Total backups:" "0"
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Scheduled backups:" "0"
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Manual backups:" "0"
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Total size:" "0B"
    fi
    
    read -p "Press Enter to continue..."
}


schedule_show_logs() {
    clear
    echo -e "\033[1;37m📋 Backup Logs\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 20))\033[0m"
    echo
    
    if [ -f "$BACKUP_LOG_FILE" ]; then

        local log_size=$(du -sh "$BACKUP_LOG_FILE" 2>/dev/null | cut -f1)
        echo -e "\033[38;5;250mLog file: $(basename "$BACKUP_LOG_FILE") ($log_size)\033[0m"
        echo -e "\033[38;5;250mLocation: $BACKUP_LOG_FILE\033[0m"
        echo
        echo -e "\033[38;5;250mLast 30 log entries:\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        
        tail -30 "$BACKUP_LOG_FILE" | while IFS= read -r line; do
            if echo "$line" | grep -q "ERROR\|FAILED\|Failed"; then
                echo -e "\033[1;31m$line\033[0m"
            elif echo "$line" | grep -q "SUCCESS\|successfully\|SUCCESS\|✅\|completed"; then
                echo -e "\033[1;32m$line\033[0m"
            elif echo "$line" | grep -q "MANUAL BACKUP\|==="; then
                echo -e "\033[1;37m$line\033[0m"
            elif echo "$line" | grep -q "WARNING\|⚠️"; then
                echo -e "\033[1;33m$line\033[0m"
            elif echo "$line" | grep -q "Starting\|Step\|Creating"; then
                echo -e "\033[1;36m$line\033[0m"
            else
                echo -e "\033[38;5;250m$line\033[0m"
            fi
        done
        
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo
        echo -e "\033[38;5;244m💡 Commands:\033[0m"
        echo -e "\033[38;5;244m   View full log: tail -f $BACKUP_LOG_FILE\033[0m"
        echo -e "\033[38;5;244m   Clear log: > $BACKUP_LOG_FILE\033[0m"
    else
        echo -e "\033[38;5;244mNo log file found at: $BACKUP_LOG_FILE\033[0m"
        echo -e "\033[38;5;244mLogs will be created after first backup run\033[0m"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

schedule_run_backup() {
    clear
    echo -e "\033[1;37m▶️  Manual Full Backup Run\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 35))\033[0m"
    echo
    
    if ! is_remnawave_up; then
        echo -e "\033[1;31m❌ Remnawave services are not running!\033[0m"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "\033[1;37m📦 Backup Type: Full System Backup\033[0m"
    echo -e "\033[38;5;250m   ✓ PostgreSQL Database (complete dump)\033[0m"
    echo -e "\033[38;5;250m   ✓ Environment files (.env, .env.subscription)\033[0m"
    echo -e "\033[38;5;250m   ✓ Docker Compose configuration\033[0m"
    echo -e "\033[38;5;250m   ✓ All additional config files (*.json, *.yml, etc.)\033[0m"
    echo -e "\033[38;5;250m   ✓ Configuration directories (certs, custom, etc.)\033[0m"
    echo
    echo -e "\033[38;5;250m🏃‍♂️ Running backup now...\033[0m"
    echo

    # Создаем/обновляем backup скрипт
    if [ ! -f "$BACKUP_SCRIPT_FILE" ]; then
        schedule_create_backup_script
        echo -e "\033[1;32m✅ Backup script created\033[0m"
        echo
    fi
    
    if [ ! -f "$BACKUP_SCRIPT_FILE" ]; then
        schedule_create_backup_script
    fi
    mkdir -p "$(dirname "$BACKUP_LOG_FILE")"
    
    echo "" >> "$BACKUP_LOG_FILE"
    echo "=============================================" >> "$BACKUP_LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MANUAL FULL BACKUP STARTED by user" >> "$BACKUP_LOG_FILE"
    echo "=============================================" >> "$BACKUP_LOG_FILE"
    
    # Запускаем backup скрипт
    bash "$BACKUP_SCRIPT_FILE" 2>&1 | tee -a "$BACKUP_LOG_FILE"
    
    local exit_code=${PIPESTATUS[0]}
    
    echo "=============================================" >> "$BACKUP_LOG_FILE"
    if [ $exit_code -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] MANUAL FULL BACKUP COMPLETED SUCCESSFULLY" >> "$BACKUP_LOG_FILE"
        echo -e "\033[1;32m🎉 Manual full backup completed successfully!\033[0m"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] MANUAL FULL BACKUP FAILED" >> "$BACKUP_LOG_FILE"
        echo -e "\033[1;31m❌ Manual full backup failed!\033[0m"
    fi
    echo "=============================================" >> "$BACKUP_LOG_FILE"
    echo "" >> "$BACKUP_LOG_FILE"
    
    echo
    echo -e "\033[1;37m📋 Backup Information:\033[0m"
    echo -e "\033[38;5;250m   Type: Full system backup (database + all configs)\033[0m"
    echo -e "\033[38;5;250m   Location: $APP_DIR/backups/\033[0m"
    echo -e "\033[38;5;250m   Logs: $BACKUP_LOG_FILE\033[0m"
    
    local latest_backup=$(ls -t "$APP_DIR/backups"/remnawave_scheduled_*.{tar.gz,sql} 2>/dev/null | head -1)
    if [ -n "$latest_backup" ]; then
        local backup_size=$(du -sh "$latest_backup" | cut -f1)
        echo -e "\033[38;5;250m   Latest: $(basename "$latest_backup") ($backup_size)\033[0m"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

schedule_cleanup() {
    clear
    echo -e "\033[1;37m🧹 Cleanup Old Backups\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 25))\033[0m"
    echo
    
    local backup_directory="$APP_DIR/backups"
    
    if [ ! -d "$backup_directory" ]; then
        echo -e "\033[38;5;244mBackup directory not found: $backup_directory\033[0m"
        echo -e "\033[38;5;244mNo backups to clean\033[0m"
        read -p "Press Enter to continue..."
        return
    fi

    local retention_days=7
    local min_backups=3
    
    if [ -f "$BACKUP_CONFIG_FILE" ]; then
        retention_days=$(jq -r '.retention.days // 7' "$BACKUP_CONFIG_FILE" 2>/dev/null)
        min_backups=$(jq -r '.retention.min_backups // 3' "$BACKUP_CONFIG_FILE" 2>/dev/null)
    fi
    
    echo -e "\033[1;37m📋 Cleanup Configuration:\033[0m"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s days\033[0m\n" "Retention period:" "$retention_days"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s files\033[0m\n" "Minimum to keep:" "$min_backups"
    echo

    local all_backups=$(ls -t "$backup_directory"/remnawave_*.tar.gz "$backup_directory"/remnawave_*.sql.gz "$backup_directory"/remnawave_*.sql 2>/dev/null)
    local total_files=$(echo "$all_backups" | grep -c . 2>/dev/null || echo "0")
    
    echo -e "\033[1;37m📊 Current Status:\033[0m"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Total backup files:" "$total_files"
    
    if [ "$total_files" -eq 0 ]; then
        echo -e "\033[38;5;244mNo backup files found in $backup_directory\033[0m"
        echo -e "\033[38;5;244mNothing to clean\033[0m"
        read -p "Press Enter to continue..."
        return
    fi
    local dir_size=$(du -sh "$backup_directory" 2>/dev/null | cut -f1)
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Directory size:" "$dir_size"
    echo
    local old_files=""
    local old_count=0
    local current_time=$(date +%s)
    local cutoff_time=$((current_time - retention_days * 86400))
    
    echo -e "\033[1;37m🔍 Analyzing backup files:\033[0m"
    echo "$all_backups" | while IFS= read -r file; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local file_size=$(du -sh "$file" 2>/dev/null | cut -f1)
            local file_time=$(stat -c %Y "$file" 2>/dev/null)
            local file_date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
            local age_days=$(( (current_time - file_time) / 86400 ))
            local file_type="📦"
            local status_color="38;5;250"
            local status_text="Keep"
            
            if [[ "$filename" =~ scheduled ]]; then
                file_type="🤖"
            elif [[ "$filename" =~ full ]]; then
                file_type="📁"
            else
                file_type="📊"
            fi
            
            if [ $age_days -gt $retention_days ]; then
                status_color="1;31"
                status_text="DELETE (${age_days}d old)"
            else
                status_text="Keep (${age_days}d old)"
            fi
            
            printf "   %s \033[38;5;250m%-30s\033[0m \033[38;5;244m%s\033[0m \033[38;5;244m%s\033[0m \033[${status_color}m%s\033[0m\n" \
                "$file_type" "$filename" "$file_size" "$file_date" "$status_text"
        fi
    done
    echo "$all_backups" | while IFS= read -r file; do
        if [ -f "$file" ]; then
            local file_time=$(stat -c %Y "$file" 2>/dev/null)
            if [ $file_time -lt $cutoff_time ]; then
                echo "$file"
            fi
        fi
    done > /tmp/files_to_delete_$$
    
    old_files=$(cat /tmp/files_to_delete_$$ 2>/dev/null)
    old_count=$(cat /tmp/files_to_delete_$$ 2>/dev/null | wc -l)
    rm -f /tmp/files_to_delete_$$
    
    echo

    local remaining_count=$((total_files - old_count))
    
    if [ $remaining_count -lt $min_backups ]; then
        local files_to_keep=$((min_backups - remaining_count))
        echo -e "\033[1;33m⚠️  Protection activated!\033[0m"
        echo -e "\033[38;5;250mWould keep minimum $min_backups backups, reducing deletion by $files_to_keep files\033[0m"

        old_files=$(echo "$all_backups" | tail -n +$((min_backups + 1)) | while IFS= read -r file; do
            if [ -f "$file" ]; then
                local file_time=$(stat -c %Y "$file" 2>/dev/null)
                if [ $file_time -lt $cutoff_time ]; then
                    echo "$file"
                fi
            fi
        done)
        old_count=$(echo "$old_files" | grep -c . 2>/dev/null || echo "0")
    fi
    
    if [ "$old_count" -eq 0 ] || [ -z "$old_files" ]; then
        echo -e "\033[1;32m✅ No files to delete\033[0m"
        echo -e "\033[38;5;250mAll backups are within retention period or protected by minimum count\033[0m"
        read -p "Press Enter to continue..."
        return
    fi
    

    echo -e "\033[1;37m📋 Cleanup Summary:\033[0m"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Files to delete:" "$old_count"
    printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Files to keep:" "$remaining_count"
    
    # Простой подсчет размера без сложных операций
    local delete_size=0
    local temp_file="/tmp/delete_size_$$"
    echo "0" > "$temp_file"
    
    for file in $old_files; do
        if [ -f "$file" ]; then
            local size_bytes=$(stat -c %s "$file" 2>/dev/null || echo "0")
            delete_size=$((delete_size + size_bytes))
        fi
    done
    echo "$delete_size" > "$temp_file"
    
    local delete_size_human=""
    if command -v numfmt >/dev/null 2>&1; then
        delete_size_human=$(numfmt --to=iec --suffix=B $(cat "$temp_file" 2>/dev/null || echo "0"))
    else
        delete_size_human="Unknown"
    fi
    rm -f "$temp_file"
    
    if [ "$delete_size_human" != "Unknown" ]; then
        printf "   \033[38;5;15m%-20s\033[0m \033[38;5;250m%s\033[0m\n" "Space to free:" "$delete_size_human"
    fi
    
    echo
    echo -n "Proceed with cleanup? [y/N]: "
    read confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo
        echo -e "\033[1;37m🗑️  Deleting old backup files...\033[0m"
        
        local deleted_count=0
        local failed_count=0
        
        echo "$old_files" | while IFS= read -r file; do
            if [ -f "$file" ]; then
                local filename=$(basename "$file")
                if rm -f "$file" 2>/dev/null; then
                    echo -e "\033[1;32m   ✅ Deleted: $filename\033[0m"
                    deleted_count=$((deleted_count + 1))
                else
                    echo -e "\033[1;31m   ❌ Failed to delete: $filename\033[0m"
                    failed_count=$((failed_count + 1))
                fi
            fi
        done
        
        echo
        if [ $failed_count -eq 0 ]; then
            echo -e "\033[1;32m🎉 Cleanup completed successfully!\033[0m"
            echo -e "\033[38;5;250mDeleted $old_count backup files\033[0m"
        else
            echo -e "\033[1;33m⚠️  Cleanup completed with warnings\033[0m"
            echo -e "\033[38;5;250mDeleted: $deleted_count, Failed: $failed_count\033[0m"
        fi
        local new_dir_size=$(du -sh "$backup_directory" 2>/dev/null | cut -f1)
        echo -e "\033[38;5;250mNew directory size: $new_dir_size\033[0m"
    else
        echo -e "\033[38;5;250mCleanup cancelled\033[0m"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

schedule_reset_config() {
    echo
    read -p "Reset all backup configuration to defaults? [y/N]: " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        cat > "$BACKUP_CONFIG_FILE" << 'EOF'
{
  "schedule": "0 2 * * *",
  "compression": {
    "enabled": true,
    "level": 6
  },
  "retention": {
    "days": 7,
    "min_backups": 3
  },
  "telegram": {
    "enabled": false,
    "bot_token": null,
    "chat_id": null,
    "thread_id": null,
    "split_large_files": true,
    "max_file_size": 49,
    "api_server": "https://api.telegram.org",
    "use_custom_api": false
  }
}
EOF
        echo -e "\033[1;32m✅ Configuration reset to defaults\033[0m"
    else
        echo -e "\033[38;5;250mReset cancelled\033[0m"
    fi
    
    sleep 2
}

# Справка
schedule_help() {
    clear
    echo -e "\033[1;37m📚 Backup Scheduler Help\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
    echo
    echo -e "\033[1;37mCommands:\033[0m"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "setup" "🔧 Configure backup settings"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "enable" "✅ Enable scheduler"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "disable" "❌ Disable scheduler"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "status" "📊 Show status"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "test" "🧪 Test backup creation"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "test-telegram" "📱 Test Telegram delivery"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "run" "▶️  Run backup now"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "logs" "📋 View logs"
    printf "   \033[38;5;15m%-15s\033[0m %s\n" "cleanup" "🧹 Clean old backups"
    echo
    read -p "Press Enter to continue..."
}

generate_random_string() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex $((${1}/2))
    else
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1} | head -n 1
    fi
}

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
    
    # Проверяем на конфликт с известными сервисами
    case "$port" in
        22|80|443|53|25|110|143|993|995)
            colorized_echo yellow "Warning: Port $port is commonly used by system services"
            ;;
    esac
    
    return 0
}

get_occupied_ports() {
    local ports=""
    
    if command -v ss &>/dev/null; then
        ports=$(ss -tuln 2>/dev/null | awk 'NR>1 {print $5}' | grep -Eo '[0-9]+$' | sort -n | uniq)
    elif command -v netstat &>/dev/null; then
        ports=$(netstat -tuln 2>/dev/null | awk 'NR>2 {print $4}' | grep -Eo '[0-9]+$' | sort -n | uniq)
    else
        colorized_echo yellow "Installing network tools for port checking..."
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

sanitize_domain() {
    # Remove leading/trailing whitespace, trailing slashes, and protocol
    echo "$1" | sed -e 's|^https\?://||' -e 's|/$||' | xargs
}

validate_domain() {
    local domain="$1"
    # Check if domain contains slashes or spaces after sanitization
    if [[ "$domain" == */* ]] || [[ "$domain" == *\ * ]]; then
        return 1
    fi
    # Check if domain format is valid
    if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    return 0
}

validate_prefix() {
    local prefix="$1"
    # Check if prefix contains only alphanumeric characters and hyphens
    if [[ ! "$prefix" =~ ^[a-zA-Z0-9-]+$ ]]; then
        return 1
    fi
    return 0
}

# Validate domain DNS configuration
validate_domain_dns() {
    local domain="$1"
    local server_ip="${NODE_IP:-127.0.0.1}"
    local is_optional="${2:-false}"  # If true, skip validation for wildcard domains
    
    # Skip for wildcard domain
    if [[ "$domain" == "*" ]]; then
        return 0
    fi
    
    echo
    colorized_echo white "🔍 Validating DNS Configuration for: $domain"
    echo "───────────────────────────────────────"
    echo
    
    printf "   %-15s %s\n" "Domain:" "$domain"
    printf "   %-15s %s\n" "Server IP:" "$server_ip"
    echo
    
    # Check if dig is available
    if ! command -v dig >/dev/null 2>&1; then
        colorized_echo yellow "⚠️  Installing dig utility..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update >/dev/null 2>&1
            apt-get install -y dnsutils >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y bind-utils >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y bind-utils >/dev/null 2>&1
        else
            colorized_echo yellow "⚠️  Cannot install dig utility, skipping DNS validation"
            return 0
        fi
        
        if ! command -v dig >/dev/null 2>&1; then
            colorized_echo yellow "⚠️  Failed to install dig utility, skipping DNS validation"
            return 0
        fi
        colorized_echo green "✅ dig utility installed"
        echo
    fi
    
    # Initialize dns_match to false
    local dns_match="false"
    
    # A record check
    colorized_echo gray "   Checking A record..."
    local a_records=$(dig +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    
    if [ -z "$a_records" ]; then
        colorized_echo red "   ❌ No A record found"
    else
        colorized_echo green "   ✅ A record found:"
        while IFS= read -r ip; do
            echo "      → $ip"
            if [ "$ip" = "$server_ip" ]; then
                dns_match="true"
            fi
        done <<< "$a_records"
    fi
    
    # AAAA record check (IPv6)
    colorized_echo gray "   Checking AAAA record..."
    local aaaa_records=$(dig +short AAAA "$domain" 2>/dev/null)
    
    if [ -z "$aaaa_records" ]; then
        colorized_echo gray "   ℹ️  No AAAA record found (IPv6)"
    else
        colorized_echo green "   ✅ AAAA record found:"
        while IFS= read -r ip; do
            echo "      → $ip"
        done <<< "$aaaa_records"
    fi
    
    # CNAME record check
    colorized_echo gray "   Checking CNAME record..."
    local cname_record=$(dig +short CNAME "$domain" 2>/dev/null)
    
    if [ -n "$cname_record" ]; then
        colorized_echo green "   ✅ CNAME record found:"
        echo "      → $cname_record"
        
        # Check CNAME target
        colorized_echo gray "   Resolving CNAME target..."
        local cname_a_records=$(dig +short A "$cname_record" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        
        if [ -n "$cname_a_records" ]; then
            colorized_echo green "   ✅ CNAME target resolved:"
            while IFS= read -r ip; do
                echo "      → $ip"
                if [ "$ip" = "$server_ip" ]; then
                    dns_match="true"
                fi
            done <<< "$cname_a_records"
        fi
    else
        colorized_echo gray "   ℹ️  No CNAME record found"
    fi
    
    echo
    
    # DNS propagation check with multiple servers
    colorized_echo white "🌐 Checking DNS Propagation:"
    echo
    
    local dns_servers=("8.8.8.8" "1.1.1.1" "208.67.222.222" "9.9.9.9")
    local propagation_count=0
    
    for dns_server in "${dns_servers[@]}"; do
        echo -n "   Checking via $dns_server... "
        local remote_a=$(dig @"$dns_server" +short A "$domain" 2>/dev/null | head -1)
        
        if [ -n "$remote_a" ] && [[ "$remote_a" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            if [ "$remote_a" = "$server_ip" ]; then
                colorized_echo green "✅ $remote_a (matches server)"
                ((propagation_count++))
            else
                colorized_echo yellow "⚠️  $remote_a (different IP)"
            fi
        else
            colorized_echo red "❌ No response"
        fi
    done
    
    echo
    
    # Summary and recommendations
    colorized_echo white "📋 DNS Validation Summary:"
    echo "───────────────────────────────────────"
    
    if [ "$dns_match" = "true" ]; then
        colorized_echo green "✅ Domain correctly points to this server"
        colorized_echo green "✅ DNS propagation: $propagation_count/4 servers"
        
        if [ "$propagation_count" -ge 2 ]; then
            colorized_echo green "✅ DNS propagation looks good"
            echo
            return 0
        else
            colorized_echo yellow "⚠️  DNS propagation is limited"
            echo "   This might cause issues with SSL certificates"
        fi
    else
        colorized_echo red "❌ Domain does not point to this server"
        echo "   Expected IP: $server_ip"
        
        if [ -n "$a_records" ]; then
            echo "   Current IPs: $(echo "$a_records" | tr '\n' ' ')"
        fi
    fi
    
    echo
    colorized_echo white "🔧 What you need to do:"
    echo "   • Go to your DNS provider (Cloudflare, etc.)"
    echo "   • Add A record: $domain → $server_ip"
    echo "   • Wait for DNS propagation (usually 5-15 minutes)"
    echo
    
    # Ask user decision
    if [ "$dns_match" = "true" ] && [ "$propagation_count" -ge 2 ]; then
        colorized_echo green "🎉 DNS validation passed!"
        echo
        return 0
    else
        colorized_echo yellow "⚠️  DNS validation has warnings."
        echo
        read -p "Do you want to continue anyway? [y/N]: " -r continue_anyway
        
        if [[ $continue_anyway =~ ^[Yy]$ ]]; then
            colorized_echo yellow "⚠️  Continuing despite DNS issues..."
            echo
            return 0
        else
            colorized_echo gray "Please fix DNS configuration and try again."
            return 1
        fi
    fi
}

# ===== CADDY REVERSE PROXY FUNCTIONS =====

CADDY_DIR="/opt/caddy-remnawave"
CADDY_VERSION="2.10.2"

# Check if web server is already installed
check_existing_webserver() {
    local found_webserver=""
    
    # Check for Nginx service
    if systemctl is-active --quiet nginx 2>/dev/null; then
        found_webserver="nginx (systemd service)"
    fi
    
    # Check for Apache service
    if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
        if [ -n "$found_webserver" ]; then
            found_webserver="$found_webserver, apache"
        else
            found_webserver="apache (systemd service)"
        fi
    fi
    
    # Check for Caddy service
    if systemctl is-active --quiet caddy 2>/dev/null; then
        if [ -n "$found_webserver" ]; then
            found_webserver="$found_webserver, caddy"
        else
            found_webserver="caddy (systemd service)"
        fi
    fi
    
    # Check for nginx docker containers
    local nginx_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE "nginx|openresty" || true)
    if [ -n "$nginx_containers" ]; then
        if [ -n "$found_webserver" ]; then
            found_webserver="$found_webserver, nginx docker ($nginx_containers)"
        else
            found_webserver="nginx docker ($nginx_containers)"
        fi
    fi
    
    # Check for caddy docker containers
    local caddy_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE "caddy" || true)
    if [ -n "$caddy_containers" ]; then
        if [ -n "$found_webserver" ]; then
            found_webserver="$found_webserver, caddy docker ($caddy_containers)"
        else
            found_webserver="caddy docker ($caddy_containers)"
        fi
    fi
    
    # Check for traefik docker containers
    local traefik_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE "traefik" || true)
    if [ -n "$traefik_containers" ]; then
        if [ -n "$found_webserver" ]; then
            found_webserver="$found_webserver, traefik docker ($traefik_containers)"
        else
            found_webserver="traefik docker ($traefik_containers)"
        fi
    fi
    
    # Check if port 80 or 443 is in use
    local port80_in_use=""
    local port443_in_use=""
    
    if command -v ss >/dev/null 2>&1; then
        port80_in_use=$(ss -tlnp 2>/dev/null | grep ":80 " | head -1 || true)
        port443_in_use=$(ss -tlnp 2>/dev/null | grep ":443 " | head -1 || true)
    elif command -v netstat >/dev/null 2>&1; then
        port80_in_use=$(netstat -tlnp 2>/dev/null | grep ":80 " | head -1 || true)
        port443_in_use=$(netstat -tlnp 2>/dev/null | grep ":443 " | head -1 || true)
    fi
    
    if [ -n "$found_webserver" ]; then
        echo "$found_webserver"
        return 0
    fi
    
    if [ -n "$port80_in_use" ] || [ -n "$port443_in_use" ]; then
        echo "port_in_use"
        return 0
    fi
    
    echo ""
    return 0
}

# Check if Caddy for Remnawave is already installed
is_caddy_installed() {
    if [ -d "$CADDY_DIR" ] && [ -f "$CADDY_DIR/docker-compose.yml" ]; then
        return 0
    fi
    return 1
}

# Check if Caddy is running
is_caddy_up() {
    if ! is_caddy_installed; then
        return 1
    fi
    local running=$(docker ps --filter "name=caddy-remnawave" --format '{{.Names}}' 2>/dev/null | head -1)
    if [ -n "$running" ]; then
        return 0
    fi
    return 1
}

# Check firewall ports for Caddy (UFW/firewalld)
check_firewall_ports() {
    local ports_ok=true
    local warnings=""
    
    # Check UFW
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        if [[ "$ufw_status" == *"active"* ]]; then
            local port80_open=$(ufw status 2>/dev/null | grep -E "^80[/ ]" || true)
            local port443_open=$(ufw status 2>/dev/null | grep -E "^443[/ ]" || true)
            local http_open=$(ufw status 2>/dev/null | grep -E "^HTTP|^Nginx|^Apache|^WWW" || true)
            
            if [ -z "$port80_open" ] && [ -z "$http_open" ]; then
                warnings="${warnings}   • Port 80 (HTTP) - not open in UFW\n"
                ports_ok=false
            fi
            if [ -z "$port443_open" ] && [ -z "$http_open" ]; then
                warnings="${warnings}   • Port 443 (HTTPS) - not open in UFW\n"
                ports_ok=false
            fi
            
            if [ "$ports_ok" = false ]; then
                echo -e "\033[1;33m⚠️  UFW firewall is active but required ports may be closed:\033[0m"
                echo -e "\033[38;5;244m$warnings\033[0m"
                echo -e "\033[38;5;250m   Run these commands to open ports:\033[0m"
                echo -e "\033[38;5;15m   sudo ufw allow 80/tcp\033[0m"
                echo -e "\033[38;5;15m   sudo ufw allow 443/tcp\033[0m"
                echo
                return 1
            fi
        fi
    fi
    
    # Check firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        local firewalld_running=$(firewall-cmd --state 2>/dev/null || true)
        if [ "$firewalld_running" = "running" ]; then
            local http_open=$(firewall-cmd --query-service=http 2>/dev/null || echo "no")
            local https_open=$(firewall-cmd --query-service=https 2>/dev/null || echo "no")
            
            if [ "$http_open" != "yes" ]; then
                warnings="${warnings}   • HTTP service - not open in firewalld\n"
                ports_ok=false
            fi
            if [ "$https_open" != "yes" ]; then
                warnings="${warnings}   • HTTPS service - not open in firewalld\n"
                ports_ok=false
            fi
            
            if [ "$ports_ok" = false ]; then
                echo -e "\033[1;33m⚠️  firewalld is active but required services may be blocked:\033[0m"
                echo -e "\033[38;5;244m$warnings\033[0m"
                echo -e "\033[38;5;250m   Run these commands to open ports:\033[0m"
                echo -e "\033[38;5;15m   sudo firewall-cmd --permanent --add-service=http\033[0m"
                echo -e "\033[38;5;15m   sudo firewall-cmd --permanent --add-service=https\033[0m"
                echo -e "\033[38;5;15m   sudo firewall-cmd --reload\033[0m"
                echo
                return 1
            fi
        fi
    fi
    
    return 0
}

# Install Caddy reverse proxy for Remnawave
# Parameters: panel_domain, sub_domain, panel_port, sub_port, sub_prefix, secure_mode
install_caddy_reverse_proxy() {
    local panel_domain="$1"
    local sub_domain="$2"
    local panel_port="${3:-3000}"
    local sub_port="${4:-3010}"
    local sub_prefix="${5:-sub}"
    local secure_mode="${6:-false}"
    
    colorized_echo cyan "==================================================="
    if [ "$secure_mode" = "true" ]; then
        colorized_echo cyan "🔒 Installing Caddy Reverse Proxy (Secure Mode)"
    else
        colorized_echo cyan "🔧 Installing Caddy Reverse Proxy"
    fi
    colorized_echo cyan "==================================================="
    echo
    
    # Check for existing web servers
    local existing_webserver=$(check_existing_webserver)
    
    if [ -n "$existing_webserver" ] && [ "$existing_webserver" != "port_in_use" ]; then
        colorized_echo yellow "⚠️  Existing web server detected: $existing_webserver"
        echo
        colorized_echo yellow "Caddy needs ports 80 and 443 to work properly."
        colorized_echo yellow "You need to stop or remove the existing web server first."
        echo
        read -p "Do you want to continue anyway? (y/n): " -r continue_install
        if [[ ! $continue_install =~ ^[Yy]$ ]]; then
            colorized_echo gray "Caddy installation cancelled."
            return 1
        fi
    elif [ "$existing_webserver" = "port_in_use" ]; then
        colorized_echo yellow "⚠️  Ports 80 or 443 are already in use"
        echo
        colorized_echo yellow "Caddy needs these ports to work properly."
        echo
        read -p "Do you want to continue anyway? (y/n): " -r continue_install
        if [[ ! $continue_install =~ ^[Yy]$ ]]; then
            colorized_echo gray "Caddy installation cancelled."
            return 1
        fi
    fi
    
    # Check if Caddy is already installed
    if is_caddy_installed; then
        colorized_echo yellow "⚠️  Caddy for Remnawave is already installed at $CADDY_DIR"
        read -p "Do you want to reinstall? (y/n): " -r reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            colorized_echo gray "Caddy installation cancelled."
            return 1
        fi
        # Stop existing Caddy
        cd "$CADDY_DIR"
        docker compose down 2>/dev/null || true
    fi
    
    # Create directory
    mkdir -p "$CADDY_DIR"
    mkdir -p "$CADDY_DIR/logs"
    
    colorized_echo blue "📁 Creating configuration in $CADDY_DIR"
    echo
    
    # Determine caddy image based on mode
    local caddy_image="caddy:${CADDY_VERSION}"
    if [ "$secure_mode" = "true" ]; then
        caddy_image="remnawave/caddy-with-auth:latest"
    fi
    
    # Create .env file
    cat > "$CADDY_DIR/.env" << EOF
# Caddy Reverse Proxy for Remnawave
# Generated on $(date)
# Server IP: ${NODE_IP:-127.0.0.1}
# Mode: $([ "$secure_mode" = "true" ] && echo "Secure (with Caddy Security)" || echo "Simple")

PANEL_DOMAIN=$panel_domain
SUB_DOMAIN=$sub_domain
PANEL_PORT=$panel_port
SUB_PORT=$sub_port
SUB_PREFIX=$sub_prefix
EOF

    # Add security-specific env vars
    if [ "$secure_mode" = "true" ]; then
        # Generate admin credentials
        local caddy_admin_user="admin"
        local caddy_admin_email="${caddy_admin_user}@${panel_domain}"
        local caddy_admin_password=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 16)
        
        cat >> "$CADDY_DIR/.env" << EOF

# Caddy Security Settings
REMNAWAVE_PANEL_DOMAIN=$panel_domain
AUTH_TOKEN_LIFETIME=604800

# Admin Credentials (used to create initial user)
AUTHP_ADMIN_USER=$caddy_admin_user
AUTHP_ADMIN_EMAIL=$caddy_admin_email
AUTHP_ADMIN_SECRET=$caddy_admin_password
EOF
    fi

    colorized_echo green "✅ .env file created"
    
    # Create docker-compose.yml - using remnawave-network like in docs
    cat > "$CADDY_DIR/docker-compose.yml" << EOF
services:
  caddy:
    image: $caddy_image
    container_name: caddy-remnawave
    hostname: caddy
    restart: always
    ports:
      - "0.0.0.0:80:80"
      - "0.0.0.0:443:443"
      - "0.0.0.0:443:443/udp"  # HTTP/3 QUIC
    networks:
      - remnawave-network
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./logs:/var/log/caddy
      - caddy-ssl-data:/data
    env_file:
      - .env
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge
    external: true

volumes:
  caddy-ssl-data:
    driver: local
    external: false
    name: caddy-ssl-data
EOF

    colorized_echo green "✅ docker-compose.yml created"
    
    # Create Caddyfile based on mode
    if [ "$secure_mode" = "true" ]; then
        # Secure mode with Caddy Security
        create_secure_caddyfile "$panel_domain" "$sub_domain" "$sub_prefix"
    else
        # Simple mode
        create_simple_caddyfile "$panel_domain" "$sub_domain" "$sub_prefix"
    fi
    
    colorized_echo green "✅ Caddyfile created"
    echo
    
    # Create remnawave-network if it doesn't exist
    if ! docker network ls --format '{{.Name}}' | grep -q "^remnawave-network$"; then
        colorized_echo blue "🔗 Creating remnawave-network..."
        docker network create remnawave-network 2>/dev/null || true
    fi
    
    # Start Caddy
    colorized_echo blue "🚀 Starting Caddy..."
    cd "$CADDY_DIR"
    
    if docker compose up -d 2>&1; then
        colorized_echo green "✅ Caddy started successfully!"
    else
        colorized_echo red "❌ Failed to start Caddy"
        return 1
    fi
    
    # Wait for Caddy to start
    sleep 3
    
    # Check if running
    if docker ps --format '{{.Names}}' | grep -q "caddy-remnawave"; then
        colorized_echo green "✅ Caddy is running"
    else
        colorized_echo red "❌ Caddy container is not running"
        colorized_echo yellow "Check logs with: docker logs caddy-remnawave"
        return 1
    fi
    
    echo
    colorized_echo green "==================================================="
    colorized_echo green "🎉 Caddy Reverse Proxy installed successfully!"
    colorized_echo green "==================================================="
    echo
    colorized_echo white "📋 Configuration:"
    if [ "$panel_domain" != "*" ]; then
        echo "   Panel URL:        https://$panel_domain"
    fi
    if [ "$panel_domain" = "$sub_domain" ]; then
        echo "   Subscription URL: https://$sub_domain/$sub_prefix/"
    else
        echo "   Subscription URL: https://$sub_domain"
    fi
    echo "   Config directory: $CADDY_DIR"
    
    if [ "$secure_mode" = "true" ]; then
        echo
        colorized_echo white "🔒 Security Mode:"
        echo "   Auth portal:      https://$panel_domain/r"
        echo "   API access:       Open (for integrations)"
        
        # Read admin credentials from .env (already generated)
        local caddy_admin_user=$(grep "^AUTHP_ADMIN_USER=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2)
        local caddy_admin_email=$(grep "^AUTHP_ADMIN_EMAIL=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2)
        local caddy_admin_password=$(grep "^AUTHP_ADMIN_SECRET=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2)
        
        colorized_echo green "   ✅ Admin credentials configured!"
        colorized_echo gray "   (Caddy will create user on first start)"
        
        # Save credentials to file
        local caddy_creds_file="$CADDY_DIR/caddy-credentials.txt"
        cat > "$caddy_creds_file" << CREDSEOF
========================================
  CADDY SECURITY ADMIN CREDENTIALS
========================================
  Created: $(date '+%Y-%m-%d %H:%M:%S')
  
  Auth Portal: https://$panel_domain/r
  
  Username: $caddy_admin_user
  Email:    $caddy_admin_email
  Password: $caddy_admin_password
  
  ⚠️  IMPORTANT: Keep this file secure!
  Delete after memorizing credentials.

----------------------------------------
  Developed by GIG.ovh project
----------------------------------------
========================================
CREDSEOF
        chmod 600 "$caddy_creds_file"
        
        echo
        colorized_echo cyan "==================================================="
        colorized_echo cyan "🔐 CADDY SECURITY CREDENTIALS"
        colorized_echo cyan "==================================================="
        echo -e "\033[1;37m   Auth Portal:\033[0m \033[38;5;117mhttps://$panel_domain/r\033[0m"
        echo -e "\033[1;37m   Username:\033[0m    \033[1;32m$caddy_admin_user\033[0m"
        echo -e "\033[1;37m   Password:\033[0m    \033[1;32m$caddy_admin_password\033[0m"
        colorized_echo cyan "==================================================="
        colorized_echo yellow "⚠️  Credentials saved to: $caddy_creds_file"
        colorized_echo cyan "==================================================="
    fi
    
    echo
    colorized_echo white "📝 Useful commands:"
    echo "   View logs:    docker logs caddy-remnawave"
    echo "   Restart:      cd $CADDY_DIR && docker compose restart"
    echo "   Edit config:  nano $CADDY_DIR/Caddyfile"
    echo "   Stop:         cd $CADDY_DIR && docker compose down"
    echo
    colorized_echo yellow "💡 Tip: SSL certificates will be automatically issued by Let's Encrypt"
    echo
    
    return 0
}

# Create simple Caddyfile (no security)
create_simple_caddyfile() {
    local panel_domain="$1"
    local sub_domain="$2"
    local sub_prefix="${3:-sub}"
    
    if [ "$panel_domain" = "$sub_domain" ]; then
        # Same domain for panel and subscription page
        cat > "$CADDY_DIR/Caddyfile" << EOF
# Caddy Reverse Proxy for Remnawave
# Single domain configuration
# Generated by remnawave.sh - GIG.OVH Project

# Global options - enable HTTP/3 (QUIC)
{
    servers {
        protocols h1 h2 h3
    }
}

# Panel + Subscription on same domain
https://{\$PANEL_DOMAIN} {
    # Enable compression (zstd preferred, gzip fallback)
    encode zstd gzip

    # Assets - open for all (tries both subscription-page and panel)
    handle /assets/* {
        reverse_proxy {
            to remnawave-subscription-page:{\$SUB_PORT}
            to remnawave:{\$PANEL_PORT}
            lb_policy first
            header_up X-Real-IP {remote_host}
            header_up Host {host}
        }
    }

    # Subscription page routes - open for all
    handle /${sub_prefix}/* {
        reverse_proxy remnawave-subscription-page:{\$SUB_PORT} {
            header_up X-Real-IP {remote_host}
            header_up Host {host}
        }
    }
    
    # Panel - all other routes
    handle {
        reverse_proxy remnawave:{\$PANEL_PORT} {
            header_up X-Real-IP {remote_host}
            header_up Host {host}
        }
    }
    
    log {
        output file /var/log/caddy/panel.log {
            roll_size 30mb
            roll_keep 10
            roll_keep_for 720h
        }
    }
}

# Fallback for any other HTTPS requests
:443 {
    tls internal
    respond 204
}
EOF
    else
        # Different domains for panel and subscription page
        cat > "$CADDY_DIR/Caddyfile" << EOF
# Caddy Reverse Proxy for Remnawave
# Multi-domain configuration
# Generated by remnawave.sh - GIG.OVH Project

# Global options - enable HTTP/3 (QUIC)
{
    servers {
        protocols h1 h2 h3
    }
}

# Panel domain
https://{\$PANEL_DOMAIN} {
    # Enable compression (zstd preferred, gzip fallback)
    encode zstd gzip

    reverse_proxy remnawave:{\$PANEL_PORT} {
        header_up X-Real-IP {remote_host}
        header_up Host {host}
    }
    
    log {
        output file /var/log/caddy/panel.log {
            roll_size 30mb
            roll_keep 10
            roll_keep_for 720h
        }
    }
}

# Subscription page domain
https://{\$SUB_DOMAIN} {
    # Enable compression (zstd preferred, gzip fallback)
    encode zstd gzip

    # Block root path - redirect (optional, remove if not needed)
    handle / {
        redir https://www.youtube.com/watch?v=dQw4w9WgXcQ 307
    }
    
    # Assets - explicitly handle for subscription page
    handle /assets/* {
        reverse_proxy remnawave-subscription-page:{\$SUB_PORT} {
            header_up X-Real-IP {remote_host}
            header_up Host {host}
        }
    }
    
    # All other subscription paths
    handle {
        reverse_proxy remnawave-subscription-page:{\$SUB_PORT} {
            header_up X-Real-IP {remote_host}
            header_up Host {host}
        }
    }
    
    log {
        output file /var/log/caddy/sub.log {
            roll_size 30mb
            roll_keep 10
            roll_keep_for 720h
        }
    }
}

# Fallback for any other HTTPS requests
:443 {
    tls internal
    respond 204
}
EOF
    fi
}

# Create secure Caddyfile with Caddy Security (authentication portal)
create_secure_caddyfile() {
    local panel_domain="$1"
    local sub_domain="$2"
    local sub_prefix="${3:-sub}"
    
    # Single domain with security
    if [ "$panel_domain" = "$sub_domain" ]; then
        cat > "$CADDY_DIR/Caddyfile" << 'EOF'
# Caddy Reverse Proxy for Remnawave with Security
# Single domain + Secure configuration
# Generated by remnawave.sh - GIG.OVH Project
# Docs: https://docs.rw/docs/security/caddy-with-minimal-setup

{
    # Enable HTTP/3 (QUIC)
    servers {
        protocols h1 h2 h3
    }

    order authenticate before respond
    order authorize before respond

    security {
        local identity store localdb {
            realm local
            path /data/.local/caddy/users.json
        }

        authentication portal remnawaveportal {
            crypto default token lifetime {$AUTH_TOKEN_LIFETIME}
            enable identity store localdb
            cookie domain {$REMNAWAVE_PANEL_DOMAIN}
            ui {
                links {
                    "Remnawave" "/dashboard/home" icon "las la-tachometer-alt"
                    "My Identity" "/r/whoami" icon "las la-user"
                    "API Keys" "/r/settings/apikeys" icon "las la-key"
                    "MFA" "/r/settings/mfa" icon "lab la-keycdn"
                }
            }
            transform user {
                match origin local
                action add role authp/admin
            }
        }

        authorization policy panelpolicy {
            set auth url /r
            allow roles authp/admin
            with api key auth portal remnawaveportal realm local
            acl rule {
                comment "Accept"
                match role authp/admin
                allow stop log info
            }
            acl rule {
                comment "Deny"
                match any
                deny log warn
            }
        }
    }
}

https://{$REMNAWAVE_PANEL_DOMAIN} {
    # Enable compression (zstd preferred, gzip fallback)
    encode zstd gzip

    # API routes - open for integrations
    route /api/* {
        reverse_proxy http://remnawave:{$PANEL_PORT}
    }

EOF
        # Add subscription and assets routes (open for all)
        cat >> "$CADDY_DIR/Caddyfile" << 'EOF'
    # Assets - open for all (tries both subscription-page and panel)
    route /assets/* {
        reverse_proxy {
            to remnawave-subscription-page:{$SUB_PORT}
            to http://remnawave:{$PANEL_PORT}
            lb_policy first
        }
    }

EOF
        cat >> "$CADDY_DIR/Caddyfile" << EOF
    # Subscription page routes - open for all
    route /${sub_prefix}/* {
        reverse_proxy remnawave-subscription-page:{\$SUB_PORT}
    }

EOF
        cat >> "$CADDY_DIR/Caddyfile" << 'EOF'
    # Auth portal
    handle /r {
        rewrite * /auth
        request_header +X-Forwarded-Prefix /r
        authenticate with remnawaveportal
    }

    route /r* {
        authenticate with remnawaveportal
    }

    # All other routes - protected
    route /* {
        authorize with panelpolicy
        reverse_proxy http://remnawave:{$PANEL_PORT}
    }

    log {
        output file /var/log/caddy/panel.log {
            roll_size 30mb
            roll_keep 10
            roll_keep_for 720h
        }
    }
}

# Fallback
:443 {
    tls internal
    respond 204
}
EOF
    else
        # Multi-domain with security (panel only protected)
        cat > "$CADDY_DIR/Caddyfile" << 'EOF'
# Caddy Reverse Proxy for Remnawave with Security
# Multi-domain + Secure configuration
# Generated by remnawave.sh - GIG.OVH Project
# Docs: https://docs.rw/docs/security/caddy-with-minimal-setup

{
    # Enable HTTP/3 (QUIC)
    servers {
        protocols h1 h2 h3
    }

    order authenticate before respond
    order authorize before respond

    security {
        local identity store localdb {
            realm local
            path /data/.local/caddy/users.json
        }

        authentication portal remnawaveportal {
            crypto default token lifetime {$AUTH_TOKEN_LIFETIME}
            enable identity store localdb
            cookie domain {$REMNAWAVE_PANEL_DOMAIN}
            ui {
                links {
                    "Remnawave" "/dashboard/home" icon "las la-tachometer-alt"
                    "My Identity" "/r/whoami" icon "las la-user"
                    "API Keys" "/r/settings/apikeys" icon "las la-key"
                    "MFA" "/r/settings/mfa" icon "lab la-keycdn"
                }
            }
            transform user {
                match origin local
                action add role authp/admin
            }
        }

        authorization policy panelpolicy {
            set auth url /r
            allow roles authp/admin
            with api key auth portal remnawaveportal realm local
            acl rule {
                comment "Accept"
                match role authp/admin
                allow stop log info
            }
            acl rule {
                comment "Deny"
                match any
                deny log warn
            }
        }
    }
}

# Panel domain - protected
https://{$REMNAWAVE_PANEL_DOMAIN} {
    # Enable compression (zstd preferred, gzip fallback)
    encode zstd gzip

    # API routes - open for integrations
    route /api/* {
        reverse_proxy http://remnawave:{$PANEL_PORT}
    }

    # Auth portal
    handle /r {
        rewrite * /auth
        request_header +X-Forwarded-Prefix /r
        authenticate with remnawaveportal
    }

    route /r* {
        authenticate with remnawaveportal
    }

    # All other routes - protected
    route /* {
        authorize with panelpolicy
        reverse_proxy http://remnawave:{$PANEL_PORT}
    }

    log {
        output file /var/log/caddy/panel.log {
            roll_size 30mb
            roll_keep 10
            roll_keep_for 720h
        }
    }
}

# Subscription page domain - open
https://{$SUB_DOMAIN} {
    # Enable compression (zstd preferred, gzip fallback)
    encode zstd gzip

    # Block root path
    handle / {
        redir https://www.youtube.com/watch?v=dQw4w9WgXcQ 307
    }
    
    # Assets - explicitly handle for subscription page
    handle /assets/* {
        reverse_proxy remnawave-subscription-page:{$SUB_PORT} {
            header_up X-Real-IP {remote_host}
            header_up Host {host}
        }
    }
    
    # All other subscription paths
    handle {
        reverse_proxy remnawave-subscription-page:{$SUB_PORT} {
            header_up X-Real-IP {remote_host}
            header_up Host {host}
        }
    }
    
    log {
        output file /var/log/caddy/sub.log {
            roll_size 30mb
            roll_keep 10
            roll_keep_for 720h
        }
    }
}

# Fallback
:443 {
    tls internal
    respond 204
}
EOF
    fi
}

# Display final credentials summary after installation
display_final_credentials_summary() {
    local panel_username="$1"
    local panel_password="$2"
    local panel_domain="$3"
    local sub_domain="$4"
    local sub_prefix="${5:-sub}"
    
    # Check if Caddy is installed
    local caddy_installed=false
    local caddy_secure_mode=false
    local caddy_admin_user=""
    local caddy_admin_password=""
    
    if is_caddy_installed; then
        caddy_installed=true
        
        # Check if running in secure mode
        if docker ps --format '{{.Names}}' | grep -q "caddy-remnawave"; then
            if docker exec caddy-remnawave caddy version 2>/dev/null | grep -q "security"; then
                caddy_secure_mode=true
                
                # Try to read Caddy credentials
                if [ -f "$CADDY_DIR/.env" ]; then
                    caddy_admin_user=$(grep "^AUTHP_ADMIN_USER=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2)
                    caddy_admin_password=$(grep "^AUTHP_ADMIN_SECRET=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2)
                fi
            fi
        fi
    fi
    
    echo
    echo
    colorized_echo green "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    colorized_echo green "┃                                                    "
    colorized_echo green "┃          🎉 INSTALLATION COMPLETED! 🎉              "
    colorized_echo green "┃                                                    "
    colorized_echo green "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    # Panel credentials
    if [ -n "$panel_username" ] && [ -n "$panel_password" ]; then
        colorized_echo cyan "┌─────────────────────────────────────────────────────"
        colorized_echo cyan "│  🔐 REMNAWAVE PANEL CREDENTIALS                     "
        colorized_echo cyan "└─────────────────────────────────────────────────────"
        echo
        
        if [ "$caddy_installed" = "true" ]; then
            if [ "$panel_domain" != "*" ]; then
                echo -e "   \033[1;37mPanel URL:\033[0m     \033[38;5;117mhttps://$panel_domain\033[0m"
            else
                echo -e "   \033[1;37mPanel URL:\033[0m     \033[38;5;244mhttp://YOUR-SERVER-IP:3000\033[0m"
            fi
            
            if [ "$panel_domain" = "$sub_domain" ]; then
                echo -e "   \033[1;37mSubscriptions:\033[0m \033[38;5;117mhttps://$sub_domain/$sub_prefix/\033[0m"
            elif [ "$sub_domain" != "*" ]; then
                echo -e "   \033[1;37mSubscriptions:\033[0m \033[38;5;117mhttps://$sub_domain\033[0m"
            fi
        else
            echo -e "   \033[1;37mPanel URL:\033[0m     \033[38;5;244mhttp://127.0.0.1:3000\033[0m"
            echo -e "   \033[1;37mSubscriptions:\033[0m \033[38;5;244mhttp://127.0.0.1:3010\033[0m"
        fi
        
        echo
        echo -e "   \033[1;37mUsername:\033[0m      \033[1;32m$panel_username\033[0m"
        echo -e "   \033[1;37mPassword:\033[0m      \033[1;32m$panel_password\033[0m"
        echo
        colorized_echo yellow "   💾 Saved to: $APP_DIR/admin-credentials.txt"
        echo
    fi
    
    # Caddy credentials (if secure mode)
    if [ "$caddy_secure_mode" = "true" ] && [ -n "$caddy_admin_user" ] && [ -n "$caddy_admin_password" ]; then
        colorized_echo cyan "┌─────────────────────────────────────────────────────"
        colorized_echo cyan "│  🔒 CADDY SECURITY AUTH PORTAL                      "
        colorized_echo cyan "└─────────────────────────────────────────────────────"
        echo
        
        if [ "$panel_domain" != "*" ]; then
            echo -e "   \033[1;37mAuth Portal:\033[0m   \033[38;5;117mhttps://$panel_domain/r\033[0m"
        fi
        echo -e "   \033[1;37mUsername:\033[0m      \033[1;32m$caddy_admin_user\033[0m"
        echo -e "   \033[1;37mPassword:\033[0m      \033[1;32m$caddy_admin_password\033[0m"
        echo
        colorized_echo yellow "   💾 Saved to: $CADDY_DIR/caddy-credentials.txt"
        echo
        colorized_echo gray "   ℹ️  API routes (/api/*) remain open for integrations"
        echo
    fi
    
    # Important notes
    colorized_echo cyan "┌─────────────────────────────────────────────────────"
    colorized_echo cyan "│  📋 IMPORTANT NOTES                                  "
    colorized_echo cyan "└─────────────────────────────────────────────────────"
    echo
    colorized_echo yellow "   ⚠️  Save your credentials securely!"
    colorized_echo yellow "   ⚠️  Delete credential files after memorizing"
    echo
    
    if [ "$caddy_installed" = "false" ]; then
        colorized_echo gray "   💡 No reverse proxy installed"
        colorized_echo gray "      Panel is only accessible from server (127.0.0.1)"
        colorized_echo gray "      Install Caddy: $APP_NAME caddy"
        echo
    fi
    
    # Useful commands
    colorized_echo cyan "┌─────────────────────────────────────────────────────"
    colorized_echo cyan "│  🛠️  USEFUL COMMANDS                                 "
    colorized_echo cyan "└─────────────────────────────────────────────────────"
    echo
    echo -e "   \033[38;5;244mStatus:\033[0m         \033[38;5;15m$APP_NAME status\033[0m"
    echo -e "   \033[38;5;244mLogs:\033[0m           \033[38;5;15m$APP_NAME logs\033[0m"
    echo -e "   \033[38;5;244mRestart:\033[0m        \033[38;5;15m$APP_NAME restart\033[0m"
    echo -e "   \033[38;5;244mBackup:\033[0m         \033[38;5;15m$APP_NAME backup\033[0m"
    
    if [ "$caddy_installed" = "true" ]; then
        echo -e "   \033[38;5;244mCaddy logs:\033[0m     \033[38;5;15mdocker logs caddy-remnawave\033[0m"
    fi
    
    echo
    colorized_echo gray "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    colorized_echo gray "         Developed by GIG.ovh project"
    colorized_echo gray "         Support: https://gig.ovh"
    colorized_echo gray "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
}

# Offer to install Caddy after panel installation
offer_caddy_installation() {
    local panel_domain="$1"
    local sub_domain="$2"
    local panel_port="${3:-3000}"
    local sub_port="${4:-3010}"
    local sub_prefix="${5:-sub}"
    
    # Skip for wildcard domains
    if [ "$panel_domain" = "*" ]; then
        colorized_echo yellow "⚠️  Panel domain is set to '*' (any domain)"
        colorized_echo yellow "    Automatic Caddy setup is not available for wildcard domains."
        echo
        colorized_echo cyan "==================================================="
        colorized_echo cyan "🌐 Manual Reverse Proxy Setup"
        colorized_echo cyan "==================================================="
        colorized_echo yellow "To access the panel from the internet, you need to"
        colorized_echo yellow "configure a reverse proxy (Nginx, Caddy, etc.)."
        echo
        colorized_echo blue "📖 Documentation:"
        echo -e "   \033[1;37mhttps://docs.rw/docs/install/reverse-proxies/\033[0m"
        colorized_echo cyan "==================================================="
        return 0
    fi
    
    echo
    colorized_echo cyan "==================================================="
    colorized_echo cyan "🌐 Reverse Proxy Setup"
    colorized_echo cyan "==================================================="
    echo
    colorized_echo white "Installing Caddy as a reverse proxy..."
    colorized_echo gray "Caddy will automatically obtain SSL certificates for your domains."
    echo
    colorized_echo white "📋 Domains that will be used (from installation):"
    echo "   Panel domain:        $panel_domain"
    if [ "$panel_domain" = "$sub_domain" ]; then
        echo "   Subscription path:   https://$panel_domain/$sub_prefix/"
    else
        echo "   Subscription domain: $sub_domain"
    fi
    echo
    
    # Check for existing web servers
    local existing_webserver=$(check_existing_webserver)
    
    if [ -n "$existing_webserver" ] && [ "$existing_webserver" != "port_in_use" ]; then
        colorized_echo yellow "⚠️  Note: Existing web server detected: $existing_webserver"
        echo
    elif [ "$existing_webserver" = "port_in_use" ]; then
        colorized_echo yellow "⚠️  Note: Ports 80/443 are already in use"
        echo
    fi
    
    # Check firewall ports first
    colorized_echo white "🔥 Checking firewall configuration..."
    echo
    if ! check_firewall_ports; then
        read -p "Continue anyway? Caddy may fail to obtain certificates (y/n): " -r continue_firewall
        if [[ ! $continue_firewall =~ ^[Yy]$ ]]; then
            colorized_echo gray "Caddy installation cancelled. Please open firewall ports first."
            return 0
        fi
        echo
    else
        colorized_echo green "✅ Firewall check passed (or no firewall detected)"
        echo
    fi
    
    colorized_echo white "🔍 Verifying DNS configuration for your domains..."
    echo
    
    # Validate panel domain DNS
    local panel_dns_ok=true
    if ! validate_domain_dns "$panel_domain"; then
        panel_dns_ok=false
        fi
        
        # Validate subscription domain DNS (if different)
        local sub_dns_ok=true
        if [ "$panel_domain" != "$sub_domain" ]; then
            if ! validate_domain_dns "$sub_domain"; then
                sub_dns_ok=false
            fi
        fi
        
        # If DNS validation failed, ask if user wants to continue anyway
        if [ "$panel_dns_ok" = "false" ] || [ "$sub_dns_ok" = "false" ]; then
            echo
            colorized_echo yellow "⚠️  Some DNS checks did not pass."
            colorized_echo yellow "    Caddy may fail to obtain SSL certificates if domains"
            colorized_echo yellow "    are not properly pointing to this server."
            echo
            read -p "Continue with Caddy installation anyway? (y/n): " -r continue_anyway
            if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
                colorized_echo gray "Caddy installation cancelled."
                echo
                colorized_echo cyan "==================================================="
                colorized_echo cyan "🌐 Manual Reverse Proxy Setup"
                colorized_echo cyan "==================================================="
                colorized_echo yellow "Fix DNS configuration, then install Caddy manually:"
                echo "   cd /opt/caddy-remnawave && docker compose up -d"
                echo
                colorized_echo blue "📖 Documentation:"
                echo -e "   \033[1;37mhttps://docs.rw/docs/install/reverse-proxies/\033[0m"
                colorized_echo cyan "==================================================="
                return 0
            fi
        fi
        
        echo
        colorized_echo white "Select Caddy configuration:"
        echo
        echo "  1) Simple (default) - Basic reverse proxy"
        echo "     • SSL certificates via Let's Encrypt"
        echo "     • No additional authentication"
        echo
        echo "  2) Secure - With Caddy Security portal"
        echo "     • SSL certificates via Let's Encrypt"
        echo "     • Additional authentication layer before panel"
        echo "     • API routes remain open for integrations"
        echo "     • Optional MFA support"
        echo "     • Docs: https://docs.rw/docs/security/caddy-with-minimal-setup"
        echo
        read -p "Choose option [1/2] (default: 1): " -r caddy_mode
        
        local secure_mode="false"
        if [[ "$caddy_mode" == "2" ]]; then
            secure_mode="true"
        fi
        
        install_caddy_reverse_proxy "$panel_domain" "$sub_domain" "$panel_port" "$sub_port" "$sub_prefix" "$secure_mode"
}

# ===== CADDY MANAGEMENT COMMANDS =====

# Start Caddy
caddy_up_command() {
    check_running_as_root
    
    if ! is_caddy_installed; then
        colorized_echo red "Caddy is not installed!"
        colorized_echo yellow "Install Caddy first with: $APP_NAME install"
        return 1
    fi
    
    colorized_echo blue "Starting Caddy..."
    cd "$CADDY_DIR"
    docker compose up -d
    
    sleep 2
    if is_caddy_up; then
        colorized_echo green "✅ Caddy started successfully!"
    else
        colorized_echo red "❌ Failed to start Caddy"
        docker compose logs --tail=20
        return 1
    fi
}

# Stop Caddy
caddy_down_command() {
    check_running_as_root
    
    if ! is_caddy_installed; then
        colorized_echo red "Caddy is not installed!"
        return 1
    fi
    
    colorized_echo blue "Stopping Caddy..."
    cd "$CADDY_DIR"
    docker compose down
    colorized_echo green "✅ Caddy stopped"
}

# Restart Caddy
caddy_restart_command() {
    check_running_as_root
    
    if ! is_caddy_installed; then
        colorized_echo red "Caddy is not installed!"
        return 1
    fi
    
    colorized_echo blue "Restarting Caddy..."
    cd "$CADDY_DIR"
    docker compose restart
    
    sleep 2
    if is_caddy_up; then
        colorized_echo green "✅ Caddy restarted successfully!"
    else
        colorized_echo red "❌ Failed to restart Caddy"
        return 1
    fi
}

# View Caddy logs
caddy_logs_command() {
    check_running_as_root
    
    if ! is_caddy_installed; then
        colorized_echo red "Caddy is not installed!"
        return 1
    fi
    
    cd "$CADDY_DIR"
    docker compose logs -f --tail=100
}

# Caddy status
caddy_status_command() {
    echo -e "\033[1;37m🌐 Caddy Reverse Proxy Status:\033[0m"
    echo
    
    if ! is_caddy_installed; then
        printf "   \033[38;5;15m%-12s\033[0m \033[1;33m⚠️  Not Installed\033[0m\n" "Status:"
        echo
        colorized_echo gray "   Install Caddy during panel installation or manually:"
        colorized_echo gray "   https://docs.rw/docs/install/reverse-proxies/"
        return 0
    fi
    
    if is_caddy_up; then
        printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Running\033[0m\n" "Status:"
    else
        printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Stopped\033[0m\n" "Status:"
    fi
    
    printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Directory:" "$CADDY_DIR"
    
    # Check if secure mode
    if [ -f "$CADDY_DIR/Caddyfile" ]; then
        if grep -q "security" "$CADDY_DIR/Caddyfile" 2>/dev/null; then
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;117mSecure (with authentication)\033[0m\n" "Mode:"
        else
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250mSimple (basic proxy)\033[0m\n" "Mode:"
        fi
    fi
    
    # Show domains from .env or Caddyfile
    if [ -f "$CADDY_DIR/.env" ]; then
        local panel_domain=$(grep "^PANEL_DOMAIN=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        local sub_domain=$(grep "^SUB_DOMAIN=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        
        # Fallback to REMNAWAVE_PANEL_DOMAIN for secure mode
        if [ -z "$panel_domain" ]; then
            panel_domain=$(grep "^REMNAWAVE_PANEL_DOMAIN=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        fi
        
        if [ -n "$panel_domain" ] || [ -n "$sub_domain" ]; then
            echo
            echo -e "\033[1;37m   Configured domains:\033[0m"
            if [ -n "$panel_domain" ]; then
                echo "     • https://$panel_domain"
            fi
            if [ -n "$sub_domain" ] && [ "$sub_domain" != "$panel_domain" ]; then
                echo "     • https://$sub_domain"
            fi
        fi
    fi
    
    echo
    
    # Show container stats if running
    if is_caddy_up; then
        local stats=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" caddy-remnawave 2>/dev/null || echo "N/A\tN/A")
        local cpu_perc=$(echo "$stats" | cut -f1)
        local mem_usage=$(echo "$stats" | cut -f2)
        
        if [ "$cpu_perc" != "N/A" ]; then
            echo -e "\033[1;37m   Resource usage:\033[0m"
            printf "     CPU: %-10s Memory: %s\n" "$cpu_perc" "$mem_usage"
        fi
    fi
}

# Edit Caddy configuration
caddy_edit_command() {
    check_running_as_root
    
    if ! is_caddy_installed; then
        colorized_echo red "Caddy is not installed!"
        return 1
    fi
    
    local caddyfile="$CADDY_DIR/Caddyfile"
    
    if [ ! -f "$caddyfile" ]; then
        colorized_echo red "Caddyfile not found at $caddyfile"
        return 1
    fi
    
    colorized_echo blue "Opening Caddyfile for editing..."
    colorized_echo yellow "After editing, run: $APP_NAME caddy restart"
    echo
    
    if command -v nano >/dev/null 2>&1; then
        nano "$caddyfile"
    elif command -v vim >/dev/null 2>&1; then
        vim "$caddyfile"
    elif command -v vi >/dev/null 2>&1; then
        vi "$caddyfile"
    else
        colorized_echo red "No editor found (nano, vim, vi)"
        colorized_echo yellow "Edit manually: $caddyfile"
        return 1
    fi
}

# Uninstall Caddy
caddy_uninstall_command() {
    check_running_as_root
    
    if ! is_caddy_installed; then
        colorized_echo yellow "Caddy is not installed."
        return 0
    fi
    
    echo -e "\033[1;31m⚠️  This will remove Caddy reverse proxy completely!\033[0m"
    echo
    read -p "Are you sure you want to uninstall Caddy? (y/n): " -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        colorized_echo blue "Stopping Caddy..."
        cd "$CADDY_DIR"
        docker compose down 2>/dev/null || true
        
        colorized_echo blue "Removing Caddy directory..."
        rm -rf "$CADDY_DIR"
        
        colorized_echo green "✅ Caddy has been uninstalled"
        echo
        colorized_echo yellow "Note: Your panel will need another reverse proxy to be accessible via HTTPS"
    else
        colorized_echo gray "Uninstall cancelled."
    fi
}

# Reset Caddy Security user (regenerate password)
caddy_reset_user_command() {
    check_running_as_root
    
    if ! is_caddy_installed; then
        colorized_echo red "Caddy is not installed!"
        return 1
    fi
    
    # Check if it's secure mode
    if ! grep -q "security" "$CADDY_DIR/Caddyfile" 2>/dev/null; then
        colorized_echo yellow "Caddy is running in Simple mode (no authentication)."
        colorized_echo yellow "This command is only for Secure mode with Caddy Security."
        return 1
    fi
    
    echo -e "\033[1;37m🔑 Reset Caddy Security User\033[0m"
    echo
    colorized_echo yellow "This will create a new admin user with a new password."
    colorized_echo yellow "The old user credentials will be replaced."
    echo
    
    read -p "Continue? (y/n): " -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        colorized_echo gray "Cancelled."
        return 0
    fi
    
    echo
    colorized_echo blue "🔑 Generating new admin credentials..."
    
    # Get panel domain from .env
    local panel_domain=""
    if [ -f "$CADDY_DIR/.env" ]; then
        panel_domain=$(grep "^REMNAWAVE_PANEL_DOMAIN=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    
    if [ -z "$panel_domain" ]; then
        panel_domain="localhost"
    fi
    
    # Generate new credentials
    local caddy_admin_user="admin"
    local caddy_admin_email="${caddy_admin_user}@${panel_domain}"
    local caddy_admin_password=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 16)
    
    # Step 1: Delete users.json inside container (if container is running)
    colorized_echo blue "🗑️  Removing old users.json..."
    if docker ps --format '{{.Names}}' | grep -q "^caddy-remnawave$"; then
        docker exec caddy-remnawave rm -f /data/.local/caddy/users.json 2>/dev/null || true
    fi
    
    # Step 2: Stop container
    colorized_echo blue "⏹️  Stopping Caddy..."
    cd "$CADDY_DIR"
    docker compose down >/dev/null 2>&1
    
    # Step 3: Update AUTHP_ADMIN_SECRET in .env (without $ symbols!)
    colorized_echo blue "📝 Updating credentials in .env..."
    if grep -q "^AUTHP_ADMIN_SECRET=" "$CADDY_DIR/.env" 2>/dev/null; then
        sed -i "s/^AUTHP_ADMIN_SECRET=.*/AUTHP_ADMIN_SECRET=$caddy_admin_password/" "$CADDY_DIR/.env"
    else
        # Add if not exists
        echo "" >> "$CADDY_DIR/.env"
        echo "# Admin Credentials" >> "$CADDY_DIR/.env"
        echo "AUTHP_ADMIN_USER=$caddy_admin_user" >> "$CADDY_DIR/.env"
        echo "AUTHP_ADMIN_EMAIL=$caddy_admin_email" >> "$CADDY_DIR/.env"
        echo "AUTHP_ADMIN_SECRET=$caddy_admin_password" >> "$CADDY_DIR/.env"
    fi
    
    # Step 4: Start container - Caddy will create new users.json from ENV
    colorized_echo blue "▶️  Starting Caddy..."
    docker compose up -d >/dev/null 2>&1
    sleep 3
    
    colorized_echo green "✅ Admin user reset successfully!"
    
    # Save credentials to file
    local caddy_creds_file="$CADDY_DIR/caddy-credentials.txt"
    cat > "$caddy_creds_file" << CREDSEOF
========================================
  CADDY SECURITY ADMIN CREDENTIALS
========================================
  Created: $(date '+%Y-%m-%d %H:%M:%S')
  
  Auth Portal: https://$panel_domain/r
  
  Username: $caddy_admin_user
  Email:    $caddy_admin_email
  Password: $caddy_admin_password
  
  ⚠️  IMPORTANT: Keep this file secure!
  Delete after memorizing credentials.

----------------------------------------
  Developed by GIG.ovh project
----------------------------------------
========================================
CREDSEOF
    chmod 600 "$caddy_creds_file"
    
    echo
    colorized_echo cyan "==================================================="
    colorized_echo cyan "🔐 NEW CADDY SECURITY CREDENTIALS"
    colorized_echo cyan "==================================================="
    echo -e "\033[1;37m   Auth Portal:\033[0m \033[38;5;117mhttps://$panel_domain/r\033[0m"
    echo -e "\033[1;37m   Username:\033[0m    \033[1;32m$caddy_admin_user\033[0m"
    echo -e "\033[1;37m   Password:\033[0m    \033[1;32m$caddy_admin_password\033[0m"
    colorized_echo cyan "==================================================="
    colorized_echo yellow "⚠️  Credentials saved to: $caddy_creds_file"
    colorized_echo cyan "==================================================="
}

# Main Caddy command handler
caddy_command() {
    local action="${1:-status}"
    
    case "$action" in
        up|start)
            caddy_up_command
            ;;
        down|stop)
            caddy_down_command
            ;;
        restart)
            caddy_restart_command
            ;;
        logs)
            caddy_logs_command
            ;;
        status)
            caddy_status_command
            ;;
        edit)
            caddy_edit_command
            ;;
        uninstall|remove)
            caddy_uninstall_command
            ;;
        reset-user|reset-password)
            caddy_reset_user_command
            ;;
        *)
            echo -e "\033[1;37m🌐 Caddy Management Commands:\033[0m"
            echo
            printf "   \033[38;5;15m%-22s\033[0m %s\n" "$APP_NAME caddy" "📊 Show Caddy status"
            printf "   \033[38;5;15m%-22s\033[0m %s\n" "$APP_NAME caddy up" "▶️  Start Caddy"
            printf "   \033[38;5;15m%-22s\033[0m %s\n" "$APP_NAME caddy down" "⏹️  Stop Caddy"
            printf "   \033[38;5;15m%-22s\033[0m %s\n" "$APP_NAME caddy restart" "🔄 Restart Caddy"
            printf "   \033[38;5;15m%-22s\033[0m %s\n" "$APP_NAME caddy logs" "📋 View Caddy logs"
            printf "   \033[38;5;15m%-22s\033[0m %s\n" "$APP_NAME caddy edit" "📝 Edit Caddyfile"
            printf "   \033[38;5;15m%-22s\033[0m %s\n" "$APP_NAME caddy reset-user" "🔑 Reset admin password (Secure mode)"
            printf "   \033[38;5;15m%-22s\033[0m %s\n" "$APP_NAME caddy uninstall" "🗑️  Remove Caddy"
            echo
            ;;
    esac
}

# Caddy management menu for interactive mode
caddy_menu() {
    while true; do
        clear
        echo -e "\033[1;37m🌐 $(L CADDY_TITLE)\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo
        
        # Check if Caddy is installed
        if ! is_caddy_installed; then
            echo -e "\033[1;37m📊 $(L CADDY_STATUS):\033[0m \033[1;33m⚠️  $(L CADDY_NOT_INSTALLED)\033[0m"
            echo
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
            echo
            echo -e "   \033[38;5;15m1)\033[0m 📦 $(L CADDY_INSTALL)"
            echo
            echo -e "   \033[38;5;244m0)\033[0m ⬅️  $(L SUB_BACK)"
            echo
            
            read -p "$(echo -e "\033[1;37m$(L MENU_SELECT) [0-1]:\033[0m ")" choice
            
            case "$choice" in
                1) install_caddy_reverse_proxy; read -p "$(L PRESS_ENTER)" ;;
                0) return 0 ;;
                *)
                    echo -e "\033[1;31m$(L INVALID_OPTION)\033[0m"
                    sleep 1
                    ;;
            esac
            continue
        fi
        
        # Caddy is installed - show full menu
        echo -e "\033[1;37m📊 $(L CADDY_STATUS):\033[0m"
        
        # Show running status
        if is_caddy_up; then
            echo -e "   \033[38;5;15m$(L CADDY_CONTAINER):\033[0m      \033[1;32m✅ $(L CADDY_RUNNING)\033[0m"
        else
            echo -e "   \033[38;5;15m$(L CADDY_CONTAINER):\033[0m      \033[1;31m❌ $(L CADDY_STOPPED)\033[0m"
        fi
        
        # Check mode (Simple or Secure)
        local caddy_mode="simple"
        local caddy_mode_display="$(L CADDY_MODE_SIMPLE)"
        if [ -f "$CADDY_DIR/.env" ]; then
            if grep -q "^AUTHP_ADMIN_USER=" "$CADDY_DIR/.env" 2>/dev/null; then
                caddy_mode="secure"
                caddy_mode_display="$(L CADDY_MODE_SECURE)"
            fi
        fi
        echo -e "   \033[38;5;15m$(L CADDY_MODE):\033[0m           \033[38;5;117m$caddy_mode_display\033[0m"
        
        # Show domains
        if [ -f "$CADDY_DIR/.env" ]; then
            local panel_domain=$(grep "^REMNAWAVE_PANEL_DOMAIN=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
            local sub_domain=$(grep "^REMNAWAVE_SUB_DOMAIN=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
            if [ -n "$panel_domain" ]; then
                echo -e "   \033[38;5;15m$(L CADDY_PANEL):\033[0m          \033[38;5;117mhttps://$panel_domain\033[0m"
            fi
            if [ -n "$sub_domain" ] && [ "$sub_domain" != "$panel_domain" ]; then
                echo -e "   \033[38;5;15m$(L CADDY_SUBSCRIPTION):\033[0m   \033[38;5;117mhttps://$sub_domain\033[0m"
            fi
        fi
        
        echo
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo
        echo -e "\033[1;37m🔧 $(L CADDY_ACTIONS):\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m 📊 $(L CADDY_SHOW_STATUS)"
        echo -e "   \033[38;5;15m2)\033[0m ▶️  $(L CADDY_START)"
        echo -e "   \033[38;5;15m3)\033[0m ⏹️  $(L CADDY_STOP)"
        echo -e "   \033[38;5;15m4)\033[0m 🔄 $(L CADDY_RESTART)"
        echo -e "   \033[38;5;15m5)\033[0m 📋 $(L CADDY_LOGS)"
        echo -e "   \033[38;5;15m6)\033[0m 📝 $(L CADDY_EDIT)"
        if [ "$caddy_mode" = "secure" ]; then
            echo -e "   \033[38;5;15m7)\033[0m 🔑 $(L CADDY_RESET_PASS)"
        else
            echo -e "   \033[38;5;8m7)\033[0m \033[38;5;8m🔑 $(L CADDY_RESET_SECURE_ONLY)\033[0m"
        fi
        echo -e "   \033[38;5;15m8)\033[0m 🗑️  $(L CADDY_UNINSTALL)"
        echo
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  $(L SUB_BACK)"
        echo
        
        read -p "$(echo -e "\033[1;37m$(L MENU_SELECT) [0-8]:\033[0m ")" choice
        
        case "$choice" in
            1) caddy_status_command; read -p "$(L PRESS_ENTER)" ;;
            2) caddy_up_command; read -p "$(L PRESS_ENTER)" ;;
            3) caddy_down_command; read -p "$(L PRESS_ENTER)" ;;
            4) caddy_restart_command; read -p "$(L PRESS_ENTER)" ;;
            5) caddy_logs_command ;;
            6) caddy_edit_command; read -p "$(L PRESS_ENTER)" ;;
            7)
                if [ "$caddy_mode" = "secure" ]; then
                    caddy_reset_user_command
                    read -p "$(L PRESS_ENTER)"
                else
                    colorized_echo yellow "⚠️  $(L CADDY_RESET_SECURE_ONLY)"
                    read -p "$(L PRESS_ENTER)"
                fi
                ;;
            8) caddy_uninstall_command; read -p "$(L PRESS_ENTER)" ;;
            0) return 0 ;;
            *)
                echo -e "\033[1;31m$(L INVALID_OPTION)\033[0m"
                sleep 1
                ;;
        esac
    done
}

# ===== REMNAWAVE API FUNCTIONS =====

# Get Remnawave panel port from .env or use default
get_panel_port() {
    local port="3000"
    
    if [ -f "$ENV_FILE" ]; then
        local env_port=$(grep "^APP_PORT=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        if [ -n "$env_port" ]; then
            port="$env_port"
        fi
    fi
    
    echo "$port"
}

# Make API request to Remnawave panel
make_api_request() {
    local method="$1"
    local url="$2"
    local token="$3"
    local data="$4"
    
    local headers=(
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1"
        -H "X-Forwarded-Proto: https"
        -H "X-Remnawave-Client-Type: browser"
    )
    
    if [ -n "$token" ]; then
        headers+=(-H "Authorization: Bearer $token")
    fi
    
    if [ -n "$data" ]; then
        curl -s -X "$method" "$url" "${headers[@]}" -d "$data" --max-time 30
    else
        curl -s -X "$method" "$url" "${headers[@]}" --max-time 30
    fi
}

# Wait for Remnawave API to be ready
wait_for_api_ready() {
    local max_attempts="${1:-30}"
    local panel_port=$(get_panel_port)
    local domain_url="127.0.0.1:$panel_port"
    local attempt=0
    
    colorized_echo blue "Waiting for Remnawave API to be ready..."
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        
        if curl -s -f --max-time 10 "http://$domain_url/api/auth/status" \
            --header 'X-Forwarded-For: 127.0.0.1' \
            --header 'X-Forwarded-Proto: https' \
            > /dev/null 2>&1; then
            colorized_echo green "API is ready!"
            return 0
        fi
        
        echo -ne "\r\033[38;5;244m   Attempt $attempt/$max_attempts - waiting...\033[0m"
        sleep 2
    done
    
    echo
    colorized_echo red "API is not responding after $max_attempts attempts"
    return 1
}

# Get admin access token (login or register)
get_admin_token() {
    local panel_port=$(get_panel_port)
    local domain_url="127.0.0.1:$panel_port"
    local username="$1"
    local password="$2"
    
    # Build JSON data properly (avoid variable expansion issues)
    local auth_data='{"username":"'"$username"'","password":"'"$password"'"}'
    
    # Helper function to extract accessToken from JSON response
    extract_token() {
        local response="$1"
        local token=""
        
        # Try jq first if available
        if command -v jq >/dev/null 2>&1; then
            token=$(echo "$response" | jq -r '.response.accessToken // .accessToken // ""' 2>/dev/null)
        fi
        
        # Fallback to grep/sed if jq failed or not available
        if [ -z "$token" ] || [ "$token" = "null" ]; then
            token=$(echo "$response" | grep -o '"accessToken":"[^"]*"' | head -1 | sed 's/"accessToken":"//;s/"$//')
        fi
        
        echo "$token"
    }
    
    # Try to login first
    local login_response=$(make_api_request "POST" "http://$domain_url/api/auth/login" "" "$auth_data")
    local token=$(extract_token "$login_response")
    
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        echo "$token"
        return 0
    fi
    
    # If login failed, try to register (first setup)
    local register_response=$(make_api_request "POST" "http://$domain_url/api/auth/register" "" "$auth_data")
    token=$(extract_token "$register_response")
    
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        echo "$token"
        return 0
    fi
    
    # Log error for debugging
    echo -e "\033[38;5;244m   Debug: Register response: $register_response\033[0m" >&2
    
    return 1
}

# Create API token for subscription-page
create_subscription_api_token() {
    local admin_token="$1"
    local token_name="${2:-subscription-page}"
    local panel_port=$(get_panel_port)
    local domain_url="127.0.0.1:$panel_port"
    
    local token_data="{\"tokenName\":\"$token_name\"}"
    local api_response=$(make_api_request "POST" "http://$domain_url/api/tokens" "$admin_token" "$token_data")
    
    if [ -z "$api_response" ]; then
        return 1
    fi
    
    local api_token=$(echo "$api_response" | jq -r '.response.token // ""' 2>/dev/null)
    
    if [ -n "$api_token" ] && [ "$api_token" != "null" ]; then
        echo "$api_token"
        return 0
    fi
    
    return 1
}

# Check if subscription-page API token is configured
check_subpage_token_configured() {
    if [ ! -f "$SUB_ENV_FILE" ]; then
        return 1
    fi
    
    local token=$(grep "^REMNAWAVE_API_TOKEN=" "$SUB_ENV_FILE" 2>/dev/null | cut -d'=' -f2-)
    
    if [ -n "$token" ] && [ "$token" != "" ]; then
        return 0
    fi
    
    return 1
}

# ===== END REMNAWAVE API FUNCTIONS =====

# ===== SUBSCRIPTION PAGE MANAGEMENT =====

subpage_command() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        colorized_echo red "Remnawave is not installed!"
        return 1
    fi
    
    subpage_menu
}

subpage_menu() {
    while true; do
        clear
        echo -e "\033[1;37m📄 Subscription Page Management\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo
        
        # Show current status
        echo -e "\033[1;37m📊 Current Status:\033[0m"
        
        # Check if subscription-page container exists
        local container_status=$(docker ps -a --filter "name=${APP_NAME}-subscription-page" --format "{{.Status}}" 2>/dev/null)
        if [ -n "$container_status" ]; then
            if echo "$container_status" | grep -q "Up"; then
                echo -e "   \033[38;5;15mContainer:\033[0m      \033[1;32m✅ Running\033[0m"
            else
                echo -e "   \033[38;5;15mContainer:\033[0m      \033[1;31m❌ Stopped\033[0m"
            fi
        else
            echo -e "   \033[38;5;15mContainer:\033[0m      \033[1;33m⚠️  Not found\033[0m"
        fi
        
        # Check API token status
        if check_subpage_token_configured; then
            echo -e "   \033[38;5;15mAPI Token:\033[0m      \033[1;32m✅ Configured\033[0m"
        else
            echo -e "   \033[38;5;15mAPI Token:\033[0m      \033[1;31m❌ Not configured\033[0m"
        fi
        
        # Check deprecated variables
        local deprecated_found=false
        if [ -f "$SUB_ENV_FILE" ]; then
            if grep -qE "^(META_TITLE|META_DESCRIPTION|SUBSCRIPTION_UI_DISPLAY_RAW_KEYS)=" "$SUB_ENV_FILE" 2>/dev/null; then
                deprecated_found=true
                echo -e "   \033[38;5;15mDeprecated vars:\033[0m \033[1;33m⚠️  Found (migration needed)\033[0m"
            fi
        fi
        
        echo
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo
        echo -e "\033[1;37m🔧 Actions:\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m 🔑 Configure API Token (auto/manual)"
        echo -e "   \033[38;5;15m2)\033[0m 🔄 Migrate .env.subscription to v7.0.0+"
        echo -e "   \033[38;5;15m3)\033[0m 🔃 Restart subscription-page container"
        echo -e "   \033[38;5;15m4)\033[0m 📋 View subscription-page logs"
        echo -e "   \033[38;5;15m5)\033[0m 📝 Edit .env.subscription"
        echo
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  Back to main menu"
        echo
        
        read -p "$(echo -e "\033[1;37mSelect option [0-5]:\033[0m ")" choice
        
        case "$choice" in
            1) subpage_configure_token; read -p "Press Enter to continue..." ;;
            2) subpage_migrate_env; read -p "Press Enter to continue..." ;;
            3) subpage_restart; read -p "Press Enter to continue..." ;;
            4) subpage_logs ;;
            5) edit_env_sub_command; read -p "Press Enter to continue..." ;;
            0) return 0 ;;
            *)
                echo -e "\033[1;31mInvalid option!\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Configure API token for subscription-page
subpage_configure_token() {
    echo
    echo -e "\033[1;37m🔑 Configure Subscription Page API Token\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    # Check if already configured
    if check_subpage_token_configured; then
        local existing_token=$(grep "^REMNAWAVE_API_TOKEN=" "$SUB_ENV_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo -e "\033[1;33m⚠️  API Token is already configured!\033[0m"
        echo -e "\033[38;5;244m   Current token: ${existing_token:0:20}...\033[0m"
        echo
        read -p "Replace existing token? (y/N): " -r replace_token
        if [[ ! $replace_token =~ ^[Yy]$ ]]; then
            echo -e "\033[38;5;244mKeeping existing token.\033[0m"
            return 0
        fi
    fi
    
    # Only manual token configuration (admin creates token in panel UI)
    echo
    echo -e "\033[38;5;244mTo get API token:\033[0m"
    echo -e "\033[38;5;244m  1. Open Remnawave Panel in browser\033[0m"
    echo -e "\033[38;5;244m  2. Login with admin credentials\033[0m"
    echo -e "\033[38;5;244m  3. Go to Settings → API Tokens\033[0m"
    echo -e "\033[38;5;244m  4. Create new token named 'subscription-page'\033[0m"
    echo -e "\033[38;5;244m  5. Copy the token and paste below\033[0m"
    echo
    
    read -p "Paste API token: " -r api_token
    
    if [ -z "$api_token" ]; then
        colorized_echo red "Token cannot be empty!"
        return 1
    fi
    
    # Basic validation
    if [ ${#api_token} -lt 20 ]; then
        colorized_echo red "Token seems too short. Please check and try again."
        return 1
    fi
    
    subpage_save_token "$api_token"
}

# Manual token configuration (legacy wrapper)
subpage_configure_token_manual() {
    subpage_configure_token
}

# Save API token to .env.subscription
subpage_save_token() {
    local api_token="$1"
    
    if [ ! -f "$SUB_ENV_FILE" ]; then
        colorized_echo red ".env.subscription file not found!"
        return 1
    fi
    
    # Backup current file
    cp "$SUB_ENV_FILE" "${SUB_ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Check if REMNAWAVE_API_TOKEN line exists
    if grep -q "^#*REMNAWAVE_API_TOKEN=" "$SUB_ENV_FILE"; then
        # Replace existing line (commented or not)
        sed -i "s|^#*REMNAWAVE_API_TOKEN=.*|REMNAWAVE_API_TOKEN=$api_token|" "$SUB_ENV_FILE"
    else
        # Add new line after CUSTOM_SUB_PREFIX
        sed -i "/^CUSTOM_SUB_PREFIX=/a\\
REMNAWAVE_API_TOKEN=$api_token" "$SUB_ENV_FILE"
    fi
    
    colorized_echo green "✅ API token saved to .env.subscription"
    echo
    
    # Ask to restart container
    read -p "Restart subscription-page container now? (Y/n): " -r restart_now
    if [[ ! $restart_now =~ ^[Nn]$ ]]; then
        subpage_restart
    fi
}

# Migrate .env.subscription to v7.0.0+
subpage_migrate_env() {
    echo
    echo -e "\033[1;37m🔄 Migrate .env.subscription to v7.0.0+\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    if [ ! -f "$SUB_ENV_FILE" ]; then
        colorized_echo red ".env.subscription file not found!"
        return 1
    fi
    
    local changes_made=false
    local deprecated_vars=("META_TITLE" "META_DESCRIPTION" "SUBSCRIPTION_UI_DISPLAY_RAW_KEYS")
    local found_vars=()
    
    # Check for deprecated variables
    for var in "${deprecated_vars[@]}"; do
        if grep -q "^$var=" "$SUB_ENV_FILE" 2>/dev/null; then
            found_vars+=("$var")
        fi
    done
    
    if [ ${#found_vars[@]} -eq 0 ]; then
        colorized_echo green "✅ No deprecated variables found!"
        echo -e "\033[38;5;244m.env.subscription is already compatible with v7.0.0+\033[0m"
        
        # Check if API token is missing
        if ! check_subpage_token_configured; then
            echo
            colorized_echo yellow "⚠️  However, REMNAWAVE_API_TOKEN is not configured!"
            colorized_echo yellow "This is REQUIRED for subscription-page v7.0.0+"
            read -p "Configure API token now? (Y/n): " -r configure_now
            if [[ ! $configure_now =~ ^[Nn]$ ]]; then
                subpage_configure_token
            fi
        fi
        return 0
    fi
    
    echo -e "\033[1;33m⚠️  Found deprecated variables:\033[0m"
    for var in "${found_vars[@]}"; do
        local value=$(grep "^$var=" "$SUB_ENV_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo -e "   \033[38;5;244m$var\033[0m = \033[38;5;250m${value:0:40}\033[0m"
    done
    echo
    echo -e "\033[38;5;244mThese settings are now managed through the Panel UI\033[0m"
    echo -e "\033[38;5;244m(Settings → Subscription Page)\033[0m"
    echo
    
    read -p "Remove deprecated variables? (Y/n): " -r confirm_remove
    if [[ $confirm_remove =~ ^[Nn]$ ]]; then
        colorized_echo yellow "Migration cancelled."
        return 0
    fi
    
    # Backup current file
    local backup_file="${SUB_ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SUB_ENV_FILE" "$backup_file"
    colorized_echo green "Backup created: $(basename $backup_file)"
    
    # Remove deprecated variables
    for var in "${found_vars[@]}"; do
        sed -i "/^$var=/d" "$SUB_ENV_FILE"
        colorized_echo green "   Removed: $var"
    done
    
    # Remove empty comment sections related to META
    sed -i '/^### META FOR SUBSCRIPTION PAGE ###$/d' "$SUB_ENV_FILE"
    sed -i '/^### RAW LINKS ###$/d' "$SUB_ENV_FILE"
    
    echo
    colorized_echo green "✅ Migration completed!"
    
    # Check if API token is missing
    if ! check_subpage_token_configured; then
        echo
        colorized_echo yellow "⚠️  REMNAWAVE_API_TOKEN is not configured!"
        colorized_echo yellow "This is REQUIRED for subscription-page v7.0.0+"
        read -p "Configure API token now? (Y/n): " -r configure_now
        if [[ ! $configure_now =~ ^[Nn]$ ]]; then
            subpage_configure_token
        fi
    else
        # Ask to restart
        read -p "Restart subscription-page container? (Y/n): " -r restart_now
        if [[ ! $restart_now =~ ^[Nn]$ ]]; then
            subpage_restart
        fi
    fi
}

# Restart subscription-page container
subpage_restart() {
    echo
    colorized_echo blue "Restarting subscription-page container..."
    
    detect_compose
    cd "$APP_DIR" 2>/dev/null || {
        colorized_echo red "Cannot access $APP_DIR"
        return 1
    }
    
    # Stop and recreate
    $COMPOSE -f "$COMPOSE_FILE" stop ${APP_NAME}-subscription-page 2>/dev/null
    $COMPOSE -f "$COMPOSE_FILE" up -d --force-recreate ${APP_NAME}-subscription-page 2>/dev/null
    
    if [ $? -eq 0 ]; then
        colorized_echo green "✅ subscription-page container restarted!"
        
        # Show status
        sleep 2
        local status=$(docker ps --filter "name=${APP_NAME}-subscription-page" --format "{{.Status}}" 2>/dev/null)
        echo -e "\033[38;5;244m   Status: $status\033[0m"
    else
        colorized_echo red "Failed to restart container!"
        return 1
    fi
}

# View subscription-page logs
subpage_logs() {
    detect_compose
    cd "$APP_DIR" 2>/dev/null || {
        colorized_echo red "Cannot access $APP_DIR"
        read -p "Press Enter to continue..."
        return 1
    }
    
    echo -e "\033[1;37m📋 Subscription Page Logs\033[0m"
    echo -e "\033[38;5;244mPress Ctrl+C to exit\033[0m"
    echo
    
    $COMPOSE -f "$COMPOSE_FILE" logs -f --tail=100 ${APP_NAME}-subscription-page
}

# Quick restart command for CLI
subpage_restart_command() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        colorized_echo red "Remnawave is not installed!"
        return 1
    fi
    
    subpage_restart
}

# ===== END SUBSCRIPTION PAGE MANAGEMENT =====

install_remnawave() {
    mkdir -p "$APP_DIR"

    # Generate random JWT secrets using openssl if available
    JWT_AUTH_SECRET=$(openssl rand -hex 128)
    JWT_API_TOKENS_SECRET=$(openssl rand -hex 128)

    # Generate random metrics credentials
    METRICS_USER=$(generate_random_string 12)
    METRICS_PASS=$(generate_random_string 32)

    # Check for occupied ports
    get_occupied_ports

    # Default ports
    DEFAULT_APP_PORT=3000
    DEFAULT_METRICS_PORT=3001
    DEFAULT_SUB_PAGE_PORT=3010
    DEFAULT_DB_PORT=6767

    # Check if default ports are occupied and ask for alternatives if needed
    APP_PORT=$DEFAULT_APP_PORT
    if is_port_occupied "$APP_PORT"; then
        colorized_echo yellow "Default APP_PORT $APP_PORT is already in use."
        while true; do
            read -p "Enter an alternative APP_PORT: " -r APP_PORT
            if [[ "$APP_PORT" -ge 1 && "$APP_PORT" -le 65535 ]]; then
                if is_port_occupied "$APP_PORT"; then
                    colorized_echo red "Port $APP_PORT is already in use. Please enter another port."
                else
                    break
                fi
            else
                colorized_echo red "Invalid port. Please enter a port between 1 and 65535."
            fi
        done
    fi

    METRICS_PORT=$DEFAULT_METRICS_PORT
    if is_port_occupied "$METRICS_PORT"; then
        colorized_echo yellow "Default METRICS_PORT $METRICS_PORT is already in use."
        while true; do
            read -p "Enter an alternative METRICS_PORT: " -r METRICS_PORT
            if [[ "$METRICS_PORT" -ge 1 && "$METRICS_PORT" -le 65535 ]]; then
                if is_port_occupied "$METRICS_PORT"; then
                    colorized_echo red "Port $METRICS_PORT is already in use. Please enter another port."
                else
                    break
                fi
            else
                colorized_echo red "Invalid port. Please enter a port between 1 and 65535."
            fi
        done
    fi

    SUB_PAGE_PORT=$DEFAULT_SUB_PAGE_PORT
    if is_port_occupied "$SUB_PAGE_PORT"; then
        colorized_echo yellow "Default subscription page port $SUB_PAGE_PORT is already in use."
        while true; do
            read -p "Enter an alternative subscription page port: " -r SUB_PAGE_PORT
            if [[ "$SUB_PAGE_PORT" -ge 1 && "$SUB_PAGE_PORT" -le 65535 ]]; then
                if is_port_occupied "$SUB_PAGE_PORT"; then
                    colorized_echo red "Port $SUB_PAGE_PORT is already in use. Please enter another port."
                else
                    break
                fi
            else
                colorized_echo red "Invalid port. Please enter a port between 1 and 65535."
            fi
        done
    fi

    DB_PORT=$DEFAULT_DB_PORT
    if is_port_occupied "$DB_PORT"; then
        colorized_echo yellow "Default DB_PORT $DB_PORT is already in use."
        while true; do
            read -p "Enter an alternative DB_PORT: " -r DB_PORT
            if [[ "$DB_PORT" -ge 1 && "$DB_PORT" -le 65535 ]]; then
                if is_port_occupied "$DB_PORT"; then
                    colorized_echo red "Port $DB_PORT is already in use. Please enter another port."
                else
                    break
                fi
            else
                colorized_echo red "Invalid port. Please enter a port between 1 and 65535."
            fi
        done
    fi

    # Ask about Caddy installation BEFORE domain input
    echo
    colorized_echo white "🌐 Caddy Reverse Proxy"
    echo "   Caddy provides automatic SSL certificates and can protect your panel."
    echo "   • Simple mode: Basic reverse proxy with auto SSL"
    echo "   • Secure mode: Authentication portal (Caddy Security)"
    echo
    read -p "Do you want to install Caddy reverse proxy after panel installation? (y/n): " -r INSTALL_CADDY_LATER
    
    local validate_dns=false
    if [[ "$INSTALL_CADDY_LATER" =~ ^[Yy]$ ]]; then
        validate_dns=true
        colorized_echo green "✅ Caddy will be installed after panel setup"
        colorized_echo yellow "⚠️  DNS validation will be performed for your domains"
    else
        colorized_echo gray "ℹ️  Caddy installation skipped. You can install it later with: $APP_NAME caddy"
    fi
    echo

    # Ask for domain names
    while true; do
        read -p "Enter the panel domain (e.g., panel.example.com or * for any domain): " -r FRONT_END_DOMAIN
        FRONT_END_DOMAIN=$(sanitize_domain "$FRONT_END_DOMAIN")
        if [[ "$FRONT_END_DOMAIN" == http* ]]; then
            colorized_echo red "Please enter only the domain without http:// or https://"
        elif [[ -z "$FRONT_END_DOMAIN" ]]; then
            colorized_echo red "Domain cannot be empty"
        elif ! validate_domain "$FRONT_END_DOMAIN" && [[ "$FRONT_END_DOMAIN" != "*" ]]; then
            colorized_echo red "Invalid domain format. Domain should be like: panel.example.com"
        else
            # Validate DNS only if Caddy will be installed and domain is not wildcard
            if [[ "$validate_dns" = true ]] && [[ "$FRONT_END_DOMAIN" != "*" ]]; then
                if ! validate_domain_dns "$FRONT_END_DOMAIN"; then
                    continue
                fi
            fi
            break
        fi
    done

    # Ask for subscription page domain and prefix
    while true; do
        read -p "Enter the subscription page domain (e.g., sub-link.example.com): " -r SUB_DOMAIN
        SUB_DOMAIN=$(sanitize_domain "$SUB_DOMAIN")
        if [[ "$SUB_DOMAIN" == http* ]]; then
            colorized_echo red "Please enter only the domain without http:// or https://"
        elif [[ -z "$SUB_DOMAIN" ]]; then
            colorized_echo red "Domain cannot be empty"
        elif [[ "$SUB_DOMAIN" == */* ]]; then
            colorized_echo red "Invalid domain format. Domain should not contain slashes."
        elif ! validate_domain "$SUB_DOMAIN"; then
            colorized_echo red "Invalid domain format. Domain should be like: sub.example.com"
        else
            # Validate DNS only if Caddy will be installed
            if [[ "$validate_dns" = true ]]; then
                if ! validate_domain_dns "$SUB_DOMAIN"; then
                    continue
                fi
            fi
            break
        fi
    done

    while true; do
        read -p "Enter the subscription page prefix (default: sub): " -r CUSTOM_SUB_PREFIX
        if [[ -z "$CUSTOM_SUB_PREFIX" ]]; then
            CUSTOM_SUB_PREFIX="sub"
            break
        elif ! validate_prefix "$CUSTOM_SUB_PREFIX"; then
            colorized_echo red "Invalid prefix format. Prefix should contain only letters, numbers, and hyphens."
        else
            break
        fi
    done

    # Construct SUB_PUBLIC_DOMAIN with the prefix
    SUB_PUBLIC_DOMAIN="${SUB_DOMAIN}/${CUSTOM_SUB_PREFIX}"

    # Ask about Telegram integration
    read -p "Do you want to enable Telegram notifications? (y/n): " -r enable_telegram
    IS_TELEGRAM_NOTIFICATIONS_ENABLED=false
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_NOTIFY_USERS_CHAT_ID=""
    TELEGRAM_NOTIFY_NODES_CHAT_ID=""
    TELEGRAM_NOTIFY_NODES_THREAD_ID=""
    TELEGRAM_NOTIFY_USERS_THREAD_ID=""
    TELEGRAM_NOTIFY_CRM_CHAT_ID=""
    TELEGRAM_NOTIFY_CRM_THREAD_ID=""

    if [[ "$enable_telegram" =~ ^[Yy]$ ]]; then
        IS_TELEGRAM_NOTIFICATIONS_ENABLED=true
        read -p "Enter your Telegram Bot Token: " -r TELEGRAM_BOT_TOKEN
        read -p "Enter your Users Notify Chat ID: " -r TELEGRAM_NOTIFY_USERS_CHAT_ID
        read -p "Enter your Nodes Notify Chat ID (default: same as Users Notify Chat ID): " -r TELEGRAM_NOTIFY_NODES_CHAT_ID
        if [[ -z "$TELEGRAM_NOTIFY_NODES_CHAT_ID" ]]; then
            TELEGRAM_NOTIFY_NODES_CHAT_ID="$TELEGRAM_NOTIFY_USERS_CHAT_ID"
        fi
        read -p "Enter your Users Notify Thread ID (optional): " -r TELEGRAM_NOTIFY_USERS_THREAD_ID
        read -p "Enter your Nodes Notify Thread ID (optional): " -r TELEGRAM_NOTIFY_NODES_THREAD_ID
        if [[ -z "$TELEGRAM_NOTIFY_NODES_THREAD_ID" ]]; then
            TELEGRAM_NOTIFY_NODES_THREAD_ID="$TELEGRAM_NOTIFY_USERS_THREAD_ID"
        fi
        
        # CRM Notification settings
        read -p "Enter your CRM Notify Chat ID (default: same as Nodes Notify Chat ID): " -r TELEGRAM_NOTIFY_CRM_CHAT_ID
        if [[ -z "$TELEGRAM_NOTIFY_CRM_CHAT_ID" ]]; then
            TELEGRAM_NOTIFY_CRM_CHAT_ID="$TELEGRAM_NOTIFY_NODES_CHAT_ID"
        fi
        read -p "Enter your CRM Notify Thread ID (default: same as Nodes Notify Thread ID): " -r TELEGRAM_NOTIFY_CRM_THREAD_ID
        if [[ -z "$TELEGRAM_NOTIFY_CRM_THREAD_ID" ]]; then
            TELEGRAM_NOTIFY_CRM_THREAD_ID="$TELEGRAM_NOTIFY_NODES_THREAD_ID"
        fi
    fi

    # Determine image tag based on --dev flag
    BACKEND_IMAGE_TAG="latest"
    if [ "$USE_DEV_BRANCH" == "true" ]; then
        BACKEND_IMAGE_TAG="dev"
    fi

    colorized_echo blue "Generating .env file"
    cat > "$ENV_FILE" <<EOL
### APP ###
APP_PORT=$APP_PORT
METRICS_PORT=$METRICS_PORT

### API ###
# Possible values: max (start instances on all cores), number (start instances on number of cores), -1 (start instances on all cores - 1)
# !!! Do not set this value more than physical cores count in your machine !!!
# Review documentation: https://docs.rw/docs/install/environment-variables#scaling-api
API_INSTANCES=1

### DATABASE ###
# FORMAT: postgresql://{user}:{password}@{host}:{port}/{database}
DATABASE_URL="postgresql://postgres:postgres@remnawave-db:5432/postgres"

### REDIS ###
REDIS_HOST=remnawave-redis
REDIS_PORT=6379

### JWT ###
### CHANGE DEFAULT VALUES ###
JWT_AUTH_SECRET=$JWT_AUTH_SECRET
JWT_API_TOKENS_SECRET=$JWT_API_TOKENS_SECRET

SHORT_UUID_LENGTH=25

### TELEGRAM NOTIFICATIONS ###
IS_TELEGRAM_NOTIFICATIONS_ENABLED=$IS_TELEGRAM_NOTIFICATIONS_ENABLED
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_NOTIFY_USERS_CHAT_ID=$TELEGRAM_NOTIFY_USERS_CHAT_ID
TELEGRAM_NOTIFY_NODES_CHAT_ID=$TELEGRAM_NOTIFY_NODES_CHAT_ID
TELEGRAM_NOTIFY_CRM_CHAT_ID=$TELEGRAM_NOTIFY_CRM_CHAT_ID

# Optional
# Only set if you want to use topics
TELEGRAM_NOTIFY_USERS_THREAD_ID=$TELEGRAM_NOTIFY_USERS_THREAD_ID
TELEGRAM_NOTIFY_NODES_THREAD_ID=$TELEGRAM_NOTIFY_NODES_THREAD_ID
TELEGRAM_NOTIFY_CRM_THREAD_ID=$TELEGRAM_NOTIFY_CRM_THREAD_ID

### FRONT_END ###
# Used by CORS, you can leave it as * or place your domain there
FRONT_END_DOMAIN=$FRONT_END_DOMAIN

### SUBSCRIPTION PUBLIC DOMAIN ###
### DOMAIN, WITHOUT HTTP/HTTPS, DO NOT ADD / AT THE END ###
### Used in "profile-web-page-url" response header and in UI/API ###
### Review documentation: https://docs.rw/docs/install/environment-variables#domains
SUB_PUBLIC_DOMAIN=$SUB_PUBLIC_DOMAIN

### If CUSTOM_SUB_PREFIX is set in @remnawave/subscription-page, append the same path to SUB_PUBLIC_DOMAIN. Example: SUB_PUBLIC_DOMAIN=sub-page.example.com/sub

### SWAGGER ###
SWAGGER_PATH=/docs
SCALAR_PATH=/scalar
IS_DOCS_ENABLED=false

### PROMETHEUS ###
### Metrics are available at http://127.0.0.1:METRICS_PORT/metrics
METRICS_USER=$METRICS_USER
METRICS_PASS=$METRICS_PASS

### WEBHOOK ###
WEBHOOK_ENABLED=false
### Only https:// is allowed
WEBHOOK_URL=https://webhook.site/1234567890
### This secret is used to sign the webhook payload, must be exact 64 characters. Only a-z, 0-9, A-Z are allowed.
WEBHOOK_SECRET_HEADER=vsmu67Kmg6R8FjIOF1WUY8LWBHie4scdEqrfsKmyf4IAf8dY3nFS0wwYHkhh6ZvQ


### Bandwidth usage reached notifications
BANDWIDTH_USAGE_NOTIFICATIONS_ENABLED=false
# Only in ASC order (example: [60, 80]), must be valid array of integer(min: 25, max: 95) numbers. No more than 5 values.
BANDWIDTH_USAGE_NOTIFICATIONS_THRESHOLD=[60, 80]

### Not connected users notification (webhook, telegram)
NOT_CONNECTED_USERS_NOTIFICATIONS_ENABLED=false
# Only in ASC order (example: [6, 12, 24]), must be valid array of integer(min: 1, max: 168) numbers. No more than 3 values.
# Each value represents HOURS passed after user creation (user.createdAt)
NOT_CONNECTED_USERS_NOTIFICATIONS_AFTER_HOURS=[6, 24, 48]

### CLOUDFLARE ###
# USED ONLY FOR docker-compose-prod-with-cf.yml
# NOT USED BY THE APP ITSELF
CLOUDFLARE_TOKEN=ey...

### Database ###
### For Postgres Docker container ###
# NOT USED BY THE APP ITSELF
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
EOL
    colorized_echo green "Environment file saved in $ENV_FILE"

SUB_ENV_FILE="$APP_DIR/.env.subscription"

colorized_echo blue "Generating .env.subscription for subscription-page"
cat > "$SUB_ENV_FILE" <<EOL
### Remnawave Panel URL, can be http://remnawave:3000 or https://panel.example.com
REMNAWAVE_PANEL_URL=http://${APP_NAME}:${APP_PORT}

APP_PORT=${SUB_PAGE_PORT}

# Serve at custom root path, for example, this value can be: CUSTOM_SUB_PREFIX=sub
# Do not place / at the start/end
CUSTOM_SUB_PREFIX=${CUSTOM_SUB_PREFIX}

# Support Marzban links
#MARZBAN_LEGACY_LINK_ENABLED=false
#MARZBAN_LEGACY_SECRET_KEY=
#REMNAWAVE_API_TOKEN=

# If you use "Caddy with security" addon, you can place here X-Api-Key, which will be applied to requests to Remnawave Panel.
#CADDY_AUTH_API_TOKEN=

EOL
colorized_echo green "Subscription environment saved in $SUB_ENV_FILE"

    colorized_echo blue "Generating docker-compose.yml file"
    cat > "$COMPOSE_FILE" <<EOL
x-common: &common
    ulimits:
        nofile:
            soft: 1048576
            hard: 1048576
    restart: always
    networks:
        - ${APP_NAME}-network

x-logging: &logging
    logging:
        driver: json-file
        options:
            max-size: "100m"
            max-file: "5"

x-env: &env
    env_file: .env

services:
    remnawave-db:
        image: postgres:17.6
        container_name: '${APP_NAME}-db'
        hostname: ${APP_NAME}-db
        <<: [*common, *logging, *env]
        environment:
            - POSTGRES_USER=\${POSTGRES_USER}
            - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
            - POSTGRES_DB=\${POSTGRES_DB}
            - TZ=UTC
        ports:
            - '127.0.0.1:6767:5432'
        volumes:
            - ${APP_NAME}-db-data:/var/lib/postgresql/data
        healthcheck:
            test: ['CMD-SHELL', 'pg_isready -U \$\${POSTGRES_USER} -d \$\${POSTGRES_DB}']
            interval: 3s
            timeout: 10s
            retries: 3


    remnawave:
        image: remnawave/backend:${BACKEND_IMAGE_TAG}
        container_name: '${APP_NAME}'
        hostname: ${APP_NAME}
        <<: [*common, *logging, *env]
        ports:
            - '127.0.0.1:${APP_PORT}:\${APP_PORT:-3000}'
            - '127.0.0.1:${METRICS_PORT}:\${METRICS_PORT:-3001}'
        healthcheck:
            test: ['CMD-SHELL', 'curl -f http://localhost:\${METRICS_PORT:-3001}/health']
            interval: 30s
            timeout: 5s
            retries: 3
            start_period: 30s
        depends_on:
            remnawave-db:
                condition: service_healthy
            remnawave-redis:
                condition: service_healthy


    remnawave-subscription-page:
        image: remnawave/subscription-page:latest
        container_name: ${APP_NAME}-subscription-page
        hostname: ${APP_NAME}-subscription-page
        <<: [*common, *logging]
        env_file:
            - .env.subscription
        ports:
            - '127.0.0.1:${SUB_PAGE_PORT}:\${APP_PORT:-3010}'
        depends_on:
            remnawave:
                condition: service_healthy

    remnawave-redis:
        image: valkey/valkey:8.1-alpine
        container_name: ${APP_NAME}-redis
        hostname: ${APP_NAME}-redis
        <<: [*common, *logging]
        volumes:
            - ${APP_NAME}-redis-data:/data
        command: >
            valkey-server
            --save ""
            --appendonly no
            --maxmemory-policy noeviction
            --loglevel warning
        healthcheck:
            test: ['CMD', 'valkey-cli', 'ping']
            interval: 3s
            timeout: 3s
            retries: 3


networks:
    ${APP_NAME}-network:
        name: ${APP_NAME}-network
        driver: bridge
        external: false

volumes:
    ${APP_NAME}-db-data:
        driver: local
        external: false
        name: ${APP_NAME}-db-data
    ${APP_NAME}-redis-data:
      driver: local
      external: false
      name: ${APP_NAME}-redis-data
EOL
    colorized_echo green "Docker Compose file saved in $COMPOSE_FILE"
}

uninstall_remnawave_script() {
    if [ -f "/usr/local/bin/$APP_NAME" ]; then
        colorized_echo yellow "Removing remnawave script"
        rm "/usr/local/bin/$APP_NAME"
    fi
}

uninstall_remnawave() {
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "Removing directory: $APP_DIR"
        rm -r "$APP_DIR"
    fi
}

uninstall_remnawave_docker_images() {
    images=$(docker images | grep remnawave | awk '{print $3}')
    if [ -n "$images" ]; then
        colorized_echo yellow "Removing Docker images of remnawave"
        for image in $images; do
            if docker rmi "$image" >/dev/null 2>&1; then
                colorized_echo yellow "Image $image removed"
            fi
        done
    fi
}

uninstall_remnawave_volumes() {
    volumes=$(docker volume ls | grep "${APP_NAME}" | awk '{print $2}')
    if [ -n "$volumes" ]; then
        colorized_echo yellow "Removing Docker volumes of remnawave"
        for volume in $volumes; do
            if docker volume rm "$volume" >/dev/null 2>&1; then
                colorized_echo yellow "Volume $volume removed"
            fi
        done
    fi
}

up_remnawave() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" up -d --remove-orphans
}

# Start only core services (without subscription-page) - used during initial installation
up_remnawave_core() {
    colorized_echo blue "Starting core services (database, redis, panel)..."
    
    # Change to app directory to avoid "getwd" errors
    cd "$APP_DIR" || {
        colorized_echo red "❌ Cannot access directory: $APP_DIR"
        return 1
    }
    
    # Stop subscription-page if it's running (from previous installation)
    $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" stop remnawave-subscription-page >/dev/null 2>&1 || true
    
    # Start only core services (use service names from docker-compose.yml, not container names)
    echo
    if ! $COMPOSE -f "$COMPOSE_FILE" -p "$APP_NAME" up -d remnawave-db remnawave-redis remnawave; then
        echo
        colorized_echo red "❌ Failed to start core services!"
        colorized_echo yellow "Check the error above and try again."
        return 1
    fi
    echo
    
    # Wait for services to be healthy
    local max_wait=60
    local waited=0
    echo -ne "\033[38;5;244m   Waiting for services to be ready"
    while [ $waited -lt $max_wait ]; do
        local db_healthy=$(docker inspect --format='{{.State.Health.Status}}' ${APP_NAME}-db 2>/dev/null)
        local redis_healthy=$(docker inspect --format='{{.State.Health.Status}}' ${APP_NAME}-redis 2>/dev/null)
        local panel_running=$(docker inspect --format='{{.State.Running}}' ${APP_NAME} 2>/dev/null)
        
        if [ "$db_healthy" = "healthy" ] && [ "$redis_healthy" = "healthy" ] && [ "$panel_running" = "true" ]; then
            echo -e "\033[0m"
            colorized_echo green "✅ Core services are running!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        waited=$((waited + 2))
    done
    echo -e "\033[0m"
    colorized_echo yellow "⚠️  Services may still be starting..."
    colorized_echo yellow "Check service status with: $APP_NAME status"
    return 0
}

recreate_remnawave() {
    # Принудительное пересоздание контейнеров с новыми образами
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" up -d --force-recreate --remove-orphans
}

down_remnawave() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" down
}

show_remnawave_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs
}

follow_remnawave_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs -f
}

update_remnawave_script() {
    colorized_echo blue "Updating remnawave script"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/$APP_NAME
    colorized_echo green "Remnawave script updated successfully"
}

update_remnawave() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" pull
}

backup_command() {
    check_running_as_root
    detect_compose  
    
    if ! is_remnawave_installed; then
        colorized_echo red "Remnawave not installed!"
        exit 1
    fi

    # Собираем аргументы для передачи в backup скрипт
    local backup_args=()
    
    # Парсинг аргументов
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --no-compress) 
                backup_args+=("--no-compress")
                ;;
            --data-only) 
                backup_args+=("--data-only")
                ;;
            --no-reverse-proxy)
                backup_args+=("--no-reverse-proxy")
                ;;
            --quiet|-q)
                backup_args+=("--quiet")
                ;;
            -h|--help) 
                echo -e "\033[1;37m💾 Remnawave Backup System\033[0m"
                echo
                echo -e "\033[1;37mUsage:\033[0m"
                echo -e "  \033[38;5;15m$APP_NAME backup\033[0m [\033[38;5;244moptions\033[0m]"
                echo
                echo -e "\033[1;37mOptions:\033[0m"
                echo -e "  \033[38;5;244m--no-compress\033[0m       Create uncompressed backup"
                echo -e "  \033[38;5;244m--data-only\033[0m         Backup database only (no configs)"
                echo -e "  \033[38;5;244m--no-reverse-proxy\033[0m  Skip Caddy/Traefik backup"
                echo -e "  \033[38;5;244m--quiet, -q\033[0m         Minimal output (for scripts)"
                echo -e "  \033[38;5;244m--help, -h\033[0m          Show this help"
                echo
                echo -e "\033[1;37mExamples:\033[0m"
                echo -e "  \033[38;5;15m$APP_NAME backup\033[0m                           \033[38;5;8m# Full backup (default)\033[0m"
                echo -e "  \033[38;5;15m$APP_NAME backup --data-only\033[0m               \033[38;5;8m# Database only\033[0m"
                echo -e "  \033[38;5;15m$APP_NAME backup --no-compress\033[0m             \033[38;5;8m# No compression\033[0m"
                echo -e "  \033[38;5;15m$APP_NAME backup --no-reverse-proxy\033[0m        \033[38;5;8m# Skip Caddy/Traefik\033[0m"
                echo
                echo -e "\033[38;5;8mDefault: Full backup (database + configs + reverse proxy)\033[0m"
                echo -e "\033[38;5;8mSettings can be configured via: $APP_NAME schedule setup\033[0m"
                exit 0
                ;;
            *) 
                echo "Unknown option: $1" >&2
                echo "Use '$APP_NAME backup --help' for usage information."
                exit 1
                ;;
        esac
        shift
    done
    
    if [ ! -f "$ENV_FILE" ]; then
        colorized_echo red ".env file not found!"
        exit 1
    fi

    # Проверяем, что база данных запущена
    if ! is_remnawave_up; then
        colorized_echo red "Remnawave services are not running!"
        echo -e "\033[38;5;8m   Run '\033[38;5;15msudo $APP_NAME up\033[38;5;8m' first\033[0m"
        exit 1
    fi

    # Проверяем, что контейнер базы данных доступен
    local db_container="${APP_NAME}-db"
    if ! docker ps --format "{{.Names}}" | grep -q "^${db_container}$"; then
        colorized_echo red "Database container '$db_container' not found or not running!"
        exit 1
    fi

    # Создаём backup скрипт если не существует
    if [ ! -f "$BACKUP_SCRIPT_FILE" ]; then
        echo -e "\033[38;5;250m📝 Creating backup script...\033[0m"
        schedule_create_backup_script
    fi
    
    # Убедимся что есть конфиг
    if ! ensure_backup_dirs; then
        colorized_echo red "Failed to create backup directories!"
        exit 1
    fi
    
    # Запускаем backup скрипт с переданными аргументами
    echo -e "\033[1;37m💾 Starting backup...\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    
    if bash "$BACKUP_SCRIPT_FILE" "${backup_args[@]}"; then
        echo
        echo -e "\033[1;32m✅ Backup completed successfully!\033[0m"
        
        # Показываем последний созданный бэкап
        local latest_backup=$(ls -t "$APP_DIR/backups"/remnawave_*.tar.gz 2>/dev/null | head -1)
        if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
            local backup_size=$(du -sh "$latest_backup" | cut -f1)
            echo
            echo -e "\033[1;37m📋 Backup Information:\033[0m"
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "File:" "$(basename "$latest_backup")"
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Size:" "$backup_size"
            printf "   \033[38;5;15m%-12s\033[0m \033[38;5;250m%s\033[0m\n" "Location:" "$APP_DIR/backups/"
        fi
    else
        echo
        echo -e "\033[1;31m❌ Backup failed!\033[0m"
        echo -e "\033[38;5;8m   Check logs: $BACKUP_LOG_FILE\033[0m"
        exit 1
    fi
}



monitor_command() {
    check_running_as_root
    
    if ! is_remnawave_installed; then
        echo -e "\033[1;31m❌ Remnawave not installed!\033[0m"
        return 1
    fi
    
    if ! is_remnawave_up; then
        echo -e "\033[1;31m❌ Remnawave services are not running!\033[0m"
        echo -e "\033[38;5;8m   Use 'sudo $APP_NAME up' to start services\033[0m"
        return 1
    fi
    
    # Однократный вывод статистики
    echo -e "\033[1;37m📊 Remnawave Performance Monitor - $(date '+%Y-%m-%d %H:%M:%S')\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 70))\033[0m"
    echo
    
    # Показываем статистику контейнеров
    echo -e "\033[1;37m🐳 Container Statistics:\033[0m"
    local stats_available=false
    
    # Проверяем доступность docker stats
    if docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null | grep -q "${APP_NAME}"; then
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | grep -E "(NAME|${APP_NAME})"
        stats_available=true
    else
        echo -e "\033[38;5;244m   Docker stats not available or no containers running\033[0m"
    fi
    
    echo
    
    # Показываем системные ресурсы
    echo -e "\033[1;37m💻 System Resources:\033[0m"
    
    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    echo -e "   \033[38;5;15mCPU:\033[0m $cpu_usage% usage"
    
    # Memory
    local mem_info=$(free -h | grep "Mem:" 2>/dev/null)
    if [ -n "$mem_info" ]; then
        local mem_used=$(echo "$mem_info" | awk '{print $3}')
        local mem_total=$(echo "$mem_info" | awk '{print $2}')
        local mem_percent=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
        echo -e "   \033[38;5;15mMemory:\033[0m $mem_percent% usage ($mem_used used / $mem_total total)"
    else
        echo -e "   \033[38;5;15mMemory:\033[0m N/A"
    fi
    
    # Disk
    local disk_info=$(df -h "$APP_DIR" 2>/dev/null | tail -1)
    if [ -n "$disk_info" ]; then
        local disk_used=$(echo "$disk_info" | awk '{print $3}')
        local disk_total=$(echo "$disk_info" | awk '{print $2}')
        local disk_percent=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
        echo -e "   \033[38;5;15mDisk:\033[0m $disk_used used / $disk_total total ($disk_percent%)"
    else
        echo -e "   \033[38;5;15mDisk:\033[0m N/A"
    fi
    
    echo
    
    # Дополнительная информация о контейнерах
    if [ "$stats_available" = true ]; then
        echo -e "\033[1;37m📋 Container Details:\033[0m"
        detect_compose
        cd "$APP_DIR" 2>/dev/null || true
        
        local container_info=$($COMPOSE -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
        if [ -n "$container_info" ]; then
            echo "$container_info" | tail -n +2 | while IFS=$'\t' read -r service status ports; do
                local status_icon="❓"
                local status_color="38;5;244"
                
                if [[ "$status" =~ "Up" ]]; then
                    if [[ "$status" =~ "healthy" ]]; then
                        status_icon="✅"
                        status_color="1;32"
                    elif [[ "$status" =~ "unhealthy" ]]; then
                        status_icon="❌"
                        status_color="1;31"
                    else
                        status_icon="🟡"
                        status_color="1;33"
                    fi
                elif [[ "$status" =~ "Exit" ]]; then
                    status_icon="❌"
                    status_color="1;31"
                fi
                
                printf "   \033[38;5;15m%-20s\033[0m \033[${status_color}m${status_icon} %-25s\033[0m \033[38;5;244m%s\033[0m\n" "$service:" "$status" "$ports"
            done
        fi
    fi
    
    echo
    echo -e "\033[38;5;8m📊 Snapshot taken at $(date '+%H:%M:%S')\033[0m"
    echo -e "\033[38;5;8m💡 For continuous monitoring, use: docker stats\033[0m"

        if [[ "${BASH_SOURCE[1]}" =~ "main_menu" ]] || [[ "$0" =~ "$APP_NAME" ]] && [[ "$1" != "--no-pause" ]]; then
        echo
        read -p "Press Enter to continue..."
    fi
}

is_remnawave_installed() {
    # Check if directory exists
    if [ ! -d "$APP_DIR" ]; then
        return 1
    fi
    
    # Directory exists - check if it's actually installed (not just an empty folder)
    # A real installation must have at least docker-compose.yml or .env file
    if [ -f "$APP_DIR/docker-compose.yml" ] || [ -f "$APP_DIR/.env" ]; then
        return 0
    fi
    
    # Directory exists but no config files - not considered installed
    return 1
}

is_remnawave_up() {
    detect_compose
    # Проверяем только ЗАПУЩЕННЫЕ контейнеры (без флага -a)
    if [ -z "$($COMPOSE -f $COMPOSE_FILE ps -q 2>/dev/null)" ]; then
        return 1
    else
        return 0
    fi
}

# Check if subpage is installed in standalone mode (without panel)
is_subpage_standalone() {
    # Check for standalone marker file
    if [ -f "$APP_DIR/.standalone-subpage" ]; then
        return 0
    fi
    return 1
}

# Check if only subpage is installed (standalone mode)
is_subpage_installed() {
    if [ -f "$APP_DIR/docker-compose.yml" ] && [ -f "$APP_DIR/.env.subscription" ]; then
        # Check if it's standalone (no panel in compose file)
        if ! grep -q "remnawave-db:" "$APP_DIR/docker-compose.yml" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Check if subpage container is running
is_subpage_up() {
    detect_compose
    local subpage_container=$(docker ps --filter "name=${APP_NAME}-subscription-page" --format '{{.Names}}' 2>/dev/null | head -1)
    if [ -n "$subpage_container" ]; then
        return 0
    fi
    return 1
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

warn_already_installed() {
    colorized_echo red "⚠️ Remnawave is already installed at: \e[1m$APP_DIR\e[0m"
    colorized_echo yellow "To install another instance, use the \e[1m--name <custom_name>\e[0m flag."
    colorized_echo cyan "Example: remnawave install --name mypanel"
}


install_command() {
    check_running_as_root
    local is_override=false
    local admin_username=""
    local admin_password=""
    
    if is_remnawave_installed; then
        warn_already_installed
        read -r -p "Do you want to override the previous installation? (y/n) "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo red "Aborted installation"
            exit 1
        fi
        is_override=true
        
        # Ask to stop running containers to avoid port conflicts
        if is_remnawave_up; then
            echo
            colorized_echo yellow "⚠️  Services are currently running."
            colorized_echo yellow "To avoid port conflicts during reinstallation, we need to stop them."
            echo
            read -r -p "Stop all running containers now? (y/n) "
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                colorized_echo blue "🛑 Stopping all services..."
                detect_compose
                cd "$APP_DIR" 2>/dev/null || true
                $COMPOSE down 2>/dev/null || true
                colorized_echo green "✅ Services stopped successfully"
                echo
                sleep 2
            else
                colorized_echo yellow "⚠️  Warning: Port conflicts may occur during installation."
                colorized_echo yellow "If installation fails, please run '$APP_NAME down' and try again."
                echo
                sleep 3
            fi
        fi
    fi
    detect_os
    if ! command -v curl >/dev/null 2>&1; then
        install_package curl
    fi
    if ! command -v openssl >/dev/null 2>&1; then
        install_package openssl
    fi
    if ! command -v jq >/dev/null 2>&1; then
        install_package jq
    fi
    if ! command -v docker >/dev/null 2>&1; then
        install_docker
    fi

    detect_compose
    install_remnawave_script
    install_remnawave
    
    # Start only core services first (without subscription-page)
    # subscription-page will be started after API token is configured
    if ! up_remnawave_core; then
        echo
        colorized_echo red "==================================================="
        colorized_echo red "❌ Installation failed - services did not start"
        colorized_echo red "==================================================="
        colorized_echo yellow "Possible issues:"
        colorized_echo yellow "  • Docker service not running"
        colorized_echo yellow "  • Network connectivity issues"
        colorized_echo yellow "  • Insufficient system resources"
        echo
        colorized_echo yellow "Try to start manually: $APP_NAME up"
        colorized_echo yellow "Check logs: $APP_NAME logs"
        exit 1
    fi
    
    echo
    colorized_echo green "==================================================="
    colorized_echo green "Remnawave Panel has been installed successfully!"
    colorized_echo green "Panel URL (local access only): http://127.0.0.1:$APP_PORT"
    colorized_echo green "Subscription Page URL (local access only): http://127.0.0.1:$SUB_PAGE_PORT"
    colorized_echo green "==================================================="
    colorized_echo yellow "IMPORTANT: These URLs are only accessible from the server itself."
    colorized_echo yellow "You must set up a reverse proxy to make them accessible from the internet."
    colorized_echo yellow "Configure your reverse proxy to point to:"
    colorized_echo yellow "Panel domain: $FRONT_END_DOMAIN -> 127.0.0.1:$APP_PORT"
    colorized_echo yellow "Subscription domain: $SUB_DOMAIN -> 127.0.0.1:$SUB_PAGE_PORT"
    colorized_echo green "==================================================="
    
    # Configure admin account and API token
    echo
    colorized_echo cyan "==================================================="
    colorized_echo cyan "📄 Admin Account & API Token Configuration"
    colorized_echo cyan "==================================================="
    
    if [ "$is_override" = true ]; then
        # Override installation - admin already exists
        colorized_echo yellow "This is an override installation."
        colorized_echo yellow "Admin account already exists - cannot create automatically."
        echo
        colorized_echo blue "To configure subscription-page API token:"
        echo -e "   \033[38;5;244m1. Login to Remnawave Panel\033[0m"
        echo -e "   \033[38;5;244m2. Go to Settings → API Tokens\033[0m"
        echo -e "   \033[38;5;244m3. Create token named 'subscription-page'\033[0m"
        echo -e "   \033[38;5;244m4. Run: $APP_NAME subpage\033[0m"
        echo
        colorized_echo yellow "Configure API token later: $APP_NAME subpage"
    else
        # Fresh installation - create admin and token
        colorized_echo yellow "Subscription-page v7.0.0+ requires REMNAWAVE_API_TOKEN"
        colorized_echo yellow "to communicate with the panel."
        echo
        colorized_echo blue "Creating admin account and API token automatically..."
        echo
        
        # Wait for panel to be fully ready
        if wait_for_api_ready 30; then
            echo
            colorized_echo green "Panel is ready!"
            
            # Additional wait for database migrations to complete
            colorized_echo blue "Waiting for database migrations..."
            sleep 10
            echo
            
            # Generate admin credentials automatically
            # Username: 10 chars (letters and digits)
            admin_username=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)
            # Password: 24 chars (letters, digits, and safe symbols that won't break JSON)
            admin_password=$(tr -dc 'a-zA-Z0-9_-' < /dev/urandom | head -c 24)
            
            colorized_echo blue "Generated admin credentials:"
            echo -e "   \033[1;37mUsername:\033[0m \033[1;32m$admin_username\033[0m"
            echo -e "   \033[1;37mPassword:\033[0m \033[1;32m$admin_password\033[0m"
            echo
            colorized_echo blue "Creating admin account and API token..."
            
            local admin_token=$(get_admin_token "$admin_username" "$admin_password")
            
            # Save credentials to file ALWAYS (even if token creation fails)
            local credentials_file="$APP_DIR/admin-credentials.txt"
            cat > "$credentials_file" << EOF
========================================
  REMNAWAVE ADMIN CREDENTIALS
========================================
  Created: $(date '+%Y-%m-%d %H:%M:%S')
  
  Username: $admin_username
  Password: $admin_password
  
  ⚠️  IMPORTANT: Keep this file secure!
  Delete after memorizing credentials.

----------------------------------------
  Developed by GIG.ovh project
  More guides available at our forum:
  https://gig.ovh
----------------------------------------
========================================
EOF
            chmod 600 "$credentials_file"
            
            if [ -n "$admin_token" ]; then
                colorized_echo green "✅ Admin account created successfully!"
                colorized_echo green "✅ Credentials saved to: $credentials_file"
                
                # Create subscription-page API token
                colorized_echo blue "Creating API token for subscription-page..."
                local api_token=$(create_subscription_api_token "$admin_token" "subscription-page")
                
                if [ -n "$api_token" ]; then
                    # Save token to .env.subscription
                    if grep -q "^#*REMNAWAVE_API_TOKEN=" "$SUB_ENV_FILE" 2>/dev/null; then
                        sed -i "s|^#*REMNAWAVE_API_TOKEN=.*|REMNAWAVE_API_TOKEN=$api_token|" "$SUB_ENV_FILE"
                    else
                        echo "REMNAWAVE_API_TOKEN=$api_token" >> "$SUB_ENV_FILE"
                    fi
                    
                    colorized_echo green "✅ API token created and saved!"
                    
                    # Recreate subscription-page container to apply token
                    colorized_echo blue "Starting subscription-page with API token..."
                    if $COMPOSE -f "$COMPOSE_FILE" up -d --force-recreate ${APP_NAME}-subscription-page; then
                        colorized_echo green "✅ Subscription-page started with API token!"
                    else
                        colorized_echo yellow "⚠️  Subscription-page start had issues. Check with: $APP_NAME status"
                    fi
                else
                    colorized_echo yellow "⚠️  Could not create API token automatically."
                    colorized_echo yellow "You can configure it later: $APP_NAME subpage"
                fi
                
                # Display credentials summary
                echo
                colorized_echo cyan "==================================================="
                colorized_echo cyan "🔐 YOUR ADMIN CREDENTIALS"
                colorized_echo cyan "==================================================="
                echo -e "\033[1;37m   Username:\033[0m \033[1;32m$admin_username\033[0m"
                echo -e "\033[1;37m   Password:\033[0m \033[1;32m$admin_password\033[0m"
                colorized_echo cyan "==================================================="
                colorized_echo yellow "⚠️  Save these credentials! They are also stored in:"
                colorized_echo yellow "   $credentials_file"
                colorized_echo cyan "==================================================="
            else
                colorized_echo red "❌ Failed to create admin account!"
                colorized_echo yellow "You can register manually at: http://127.0.0.1:$APP_PORT"
                colorized_echo yellow "Then configure API token: $APP_NAME subpage"
            fi
        else
            colorized_echo yellow "Panel is not responding yet."
            colorized_echo yellow "After panel starts, register admin at: http://127.0.0.1:$APP_PORT"
            colorized_echo yellow "Then configure API token: $APP_NAME subpage"
        fi
    fi
    
    colorized_echo green "==================================================="
    colorized_echo green "Installation complete!"
    colorized_echo green "==================================================="
    echo
    
    # Offer to install Caddy reverse proxy (only if user agreed earlier)
    if [[ "$INSTALL_CADDY_LATER" =~ ^[Yy]$ ]]; then
        offer_caddy_installation "$FRONT_END_DOMAIN" "$SUB_DOMAIN" "$APP_PORT" "$SUB_PORT" "$CUSTOM_SUB_PREFIX"
    else
        colorized_echo gray "💡 Tip: You can install Caddy later with: $APP_NAME caddy"
        echo
    fi
    
    # Display final credentials summary
    display_final_credentials_summary "$admin_username" "$admin_password" "$FRONT_END_DOMAIN" "$SUB_DOMAIN" "$CUSTOM_SUB_PREFIX"
}

uninstall_command() {
    check_running_as_root
    if ! is_remnawave_installed; then
        colorized_echo red "Remnawave not installed!"
        exit 1
    fi

    read -p "Do you really want to uninstall Remnawave? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Aborted"
        exit 1
    fi
    
    # Спрашиваем про Caddy заранее
    local remove_caddy=false
    if is_caddy_installed; then
        echo
        colorized_echo yellow "🌐 Caddy Reverse Proxy is also installed at $CADDY_DIR"
        read -p "Do you also want to remove Caddy? (y/n) "
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            remove_caddy=true
        fi
    fi
    
    # Create safety backup before uninstall
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$HOME/remnawave-backup-before-uninstall-$backup_timestamp"
    
    echo
    colorized_echo cyan "==================================================="
    colorized_echo cyan "💾 Creating safety backup before uninstall..."
    colorized_echo cyan "==================================================="
    echo
    
    mkdir -p "$backup_dir"
    
    # Backup main panel directory
    if [ -d "$APP_DIR" ]; then
        colorized_echo blue "📦 Backing up panel directory: $APP_DIR"
        cp -r "$APP_DIR" "$backup_dir/panel/" 2>/dev/null || true
        colorized_echo green "   ✅ Panel directory backed up"
    fi
    
    # Backup Caddy directory if exists
    if [ -d "$CADDY_DIR" ]; then
        colorized_echo blue "📦 Backing up Caddy directory: $CADDY_DIR"
        cp -r "$CADDY_DIR" "$backup_dir/caddy/" 2>/dev/null || true
        colorized_echo green "   ✅ Caddy directory backed up"
    fi
    
    # Export database if running
    detect_compose
    if is_remnawave_up; then
        colorized_echo blue "📦 Exporting database..."
        local db_backup_file="$backup_dir/database.sql"
        
        # Get DB credentials from .env
        local db_user=$(grep "^POSTGRES_USER=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        local db_pass=$(grep "^POSTGRES_PASSWORD=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        local db_name=$(grep "^POSTGRES_DB=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        
        if [ -n "$db_user" ] && [ -n "$db_pass" ] && [ -n "$db_name" ]; then
            if docker exec -e PGPASSWORD="$db_pass" "${APP_NAME}-db" pg_dump -U "$db_user" -d "$db_name" > "$db_backup_file" 2>/dev/null; then
                gzip "$db_backup_file" 2>/dev/null || true
                colorized_echo green "   ✅ Database exported to database.sql.gz"
            else
                colorized_echo yellow "   ⚠️  Could not export database (container may not be ready)"
            fi
        fi
    fi
    
    # Create final archive
    colorized_echo blue "📦 Creating compressed archive..."
    local final_archive="$HOME/remnawave-backup-$backup_timestamp.tar.gz"
    tar -czf "$final_archive" -C "$backup_dir" . 2>/dev/null
    rm -rf "$backup_dir"
    
    echo
    colorized_echo green "==================================================="
    colorized_echo green "✅ Safety backup created!"
    colorized_echo green "==================================================="
    colorized_echo white "📁 Location: $final_archive"
    echo
    colorized_echo yellow "💡 This backup can be used to restore later with:"
    colorized_echo yellow "   $APP_NAME restore --file $final_archive"
    echo

    detect_compose
    if is_remnawave_up; then
        down_remnawave
    fi
    
    # Also stop and remove Caddy if installed
    if is_caddy_installed; then
        colorized_echo blue "Stopping Caddy..."
        cd "$CADDY_DIR" && docker compose down 2>/dev/null || true
        
        if [ "$remove_caddy" = true ]; then
            colorized_echo yellow "Removing Caddy directory: $CADDY_DIR"
            rm -rf "$CADDY_DIR"
            colorized_echo green "✅ Caddy removed"
        else
            colorized_echo gray "Caddy preserved at: $CADDY_DIR"
        fi
    fi
    
    uninstall_remnawave_script
    uninstall_remnawave
    uninstall_remnawave_docker_images

    read -p "Do you want to remove Remnawave data volumes too? This will DELETE ALL DATABASE DATA! (y/n) "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        uninstall_remnawave_volumes
        
        # Also remove Caddy volumes
        local caddy_volumes=$(docker volume ls -q | grep -E "caddy" || true)
        if [ -n "$caddy_volumes" ]; then
            colorized_echo yellow "Removing Caddy volumes..."
            echo "$caddy_volumes" | xargs docker volume rm 2>/dev/null || true
        fi
    fi

    colorized_echo green "Remnawave uninstalled successfully"
    echo
    colorized_echo yellow "📁 Your backup is saved at: $final_archive"
}

install_subpage_command() {
    check_running_as_root
    
    # Help message
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        echo -e "\033[1;37m📄 install-subpage\033[0m - Install subscription-page container only"
        echo
        echo -e "\033[1;37mDescription:\033[0m"
        echo -e "  Adds subscription-page container to existing Remnawave installation."
        echo -e "  Use when panel is already installed but subscription-page was removed"
        echo -e "  or needs to be reinstalled."
        echo
        echo -e "\033[1;37mUsage:\033[0m"
        echo -e "  \033[38;5;15m$APP_NAME\033[0m \033[38;5;250minstall-subpage\033[0m"
        echo
        echo -e "\033[1;37mAfter installation:\033[0m"
        echo -e "  Configure API token: \033[38;5;15m$APP_NAME\033[0m subpage"
        echo
        exit 0
    fi
    
    if ! is_remnawave_installed; then
        colorized_echo red "Remnawave panel is not installed!"
        colorized_echo yellow "First install the full panel: $APP_NAME install"
        exit 1
    fi
    
    detect_compose
    
    colorized_echo cyan "==================================================="
    colorized_echo cyan "📄 Install Subscription-Page Container"
    colorized_echo cyan "==================================================="
    echo
    
    # Check if subscription-page service exists in compose
    if ! grep -q "${APP_NAME}-subscription-page:" "$COMPOSE_FILE" 2>/dev/null; then
        colorized_echo red "Subscription-page service not found in docker-compose.yml"
        colorized_echo yellow "This may require reinstalling: $APP_NAME install"
        exit 1
    fi
    
    # Check if .env.subscription exists
    if [ ! -f "$SUB_ENV_FILE" ]; then
        colorized_echo yellow "Creating $SUB_ENV_FILE..."
        
        # Get current panel URL from .env
        local sub_public_url=$(grep "^SUB_PUBLIC_URL=" "$ENV_FILE" 2>/dev/null | cut -d '=' -f2)
        if [ -z "$sub_public_url" ]; then
            read -p "Enter subscription page public URL (e.g., https://sub.domain.com): " -r sub_public_url
        fi
        
        # Create .env.subscription
        cat > "$SUB_ENV_FILE" << EOF
# Subscription Page Configuration
# Created by install-subpage command

# API Token - Get from Remnawave Panel → Settings → API Tokens
REMNAWAVE_API_TOKEN=

# Subscription Page Public URL
SUB_PUBLIC_URL=$sub_public_url
EOF
        colorized_echo green "✅ Created $SUB_ENV_FILE"
    else
        colorized_echo green "✅ $SUB_ENV_FILE already exists"
    fi
    
    # Pull and start subscription-page container
    colorized_echo blue "Pulling subscription-page image..."
    $COMPOSE -f "$COMPOSE_FILE" pull ${APP_NAME}-subscription-page
    
    colorized_echo blue "Starting subscription-page container..."
    $COMPOSE -f "$COMPOSE_FILE" up -d ${APP_NAME}-subscription-page
    
    colorized_echo green "==================================================="
    colorized_echo green "✅ Subscription-page container installed!"
    colorized_echo green "==================================================="
    echo
    colorized_echo yellow "⚠️  IMPORTANT: Configure API token to enable functionality"
    echo
    colorized_echo blue "Steps:"
    echo -e "   \033[38;5;244m1. Login to Remnawave Panel\033[0m"
    echo -e "   \033[38;5;244m2. Go to Settings → API Tokens\033[0m"
    echo -e "   \033[38;5;244m3. Create token named 'subscription-page'\033[0m"
    echo -e "   \033[38;5;244m4. Run: $APP_NAME subpage\033[0m"
    echo
    colorized_echo yellow "Or directly configure: $APP_NAME subpage-token"
}

# ===== STANDALONE SUBPAGE INSTALLATION =====
# Install subscription-page on a separate server (without panel)

install_subpage_standalone_command() {
    check_running_as_root
    
    # Help message
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        echo -e "\033[1;37m📄 install-subpage-standalone\033[0m - Install subscription-page on separate server"
        echo
        echo -e "\033[1;37mDescription:\033[0m"
        echo -e "  Installs subscription-page container on a standalone server"
        echo -e "  (without Remnawave panel). Connects to remote panel via API."
        echo
        echo -e "\033[1;37mUsage:\033[0m"
        echo -e "  \033[38;5;15m$APP_NAME\033[0m \033[38;5;250minstall-subpage-standalone\033[0m [\033[38;5;244m--with-caddy\033[0m]"
        echo
        echo -e "\033[1;37mOptions:\033[0m"
        echo -e "  \033[38;5;244m--with-caddy\033[0m    Also install Caddy reverse proxy"
        echo
        echo -e "\033[1;37mRequirements:\033[0m"
        echo -e "  • Remote Remnawave panel URL (https://panel.domain.com)"
        echo -e "  • API token from panel (Settings → API Tokens)"
        echo -e "  • Domain for subscription page"
        echo
        exit 0
    fi
    
    local with_caddy=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --with-caddy) with_caddy=true ;;
            *) ;;
        esac
        shift
    done
    
    # Check if already installed
    if is_subpage_standalone; then
        colorized_echo yellow "⚠️  Standalone subscription-page is already installed at $APP_DIR"
        read -r -p "Do you want to reinstall? (y/n) "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo red "Aborted installation"
            exit 1
        fi
        # Stop existing container
        detect_compose
        cd "$APP_DIR" 2>/dev/null || true
        $COMPOSE down 2>/dev/null || true
    fi
    
    # Check if full panel is installed
    if is_remnawave_installed && ! is_subpage_standalone; then
        colorized_echo red "⚠️  Full Remnawave panel is already installed on this server!"
        colorized_echo yellow "Standalone subpage mode is for separate servers only."
        colorized_echo yellow "Use '$APP_NAME install-subpage' to add subpage to existing panel."
        exit 1
    fi
    
    detect_os
    if ! command -v curl >/dev/null 2>&1; then
        install_package curl
    fi
    
    colorized_echo cyan "==================================================="
    colorized_echo cyan "📄 Standalone Subscription-Page Installation"
    colorized_echo cyan "==================================================="
    echo
    colorized_echo white "This will install ONLY the subscription-page container"
    colorized_echo white "on this server, connecting to a remote Remnawave panel."
    echo
    
    # Get remote panel URL
    echo -e "\033[1;37m📡 Remote Panel Configuration:\033[0m"
    echo
    read -p "Enter Remnawave panel URL (e.g., https://panel.domain.com): " -r panel_url
    
    # Validate URL format
    if [[ ! "$panel_url" =~ ^https?:// ]]; then
        colorized_echo yellow "Adding https:// prefix..."
        panel_url="https://$panel_url"
    fi
    # Remove trailing slash
    panel_url="${panel_url%/}"
    
    echo
    colorized_echo blue "Testing connection to panel..."
    
    # Test connection to panel
    local test_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$panel_url" 2>/dev/null || echo "000")
    if [ "$test_status" = "000" ]; then
        colorized_echo yellow "⚠️  Cannot connect to $panel_url"
        colorized_echo yellow "Make sure the panel URL is correct and accessible."
        read -p "Continue anyway? (y/n): " -r continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            colorized_echo red "Aborted installation"
            exit 1
        fi
    else
        colorized_echo green "✅ Panel is reachable (HTTP $test_status)"
    fi
    
    echo
    echo -e "\033[1;37m🔑 API Token:\033[0m"
    echo -e "\033[38;5;244mGet token from panel: Settings → API Tokens → Create new token\033[0m"
    echo
    read -p "Enter API token (or leave empty to configure later): " -r api_token
    
    echo
    echo -e "\033[1;37m🌐 Subscription Page Domain:\033[0m"
    read -p "Enter domain for subscription page (e.g., sub.domain.com): " -r sub_domain
    
    if [ -z "$sub_domain" ]; then
        colorized_echo red "Domain is required!"
        exit 1
    fi
    
    # Subscription prefix
    read -p "Enter subscription path prefix (default: sub): " -r sub_prefix
    sub_prefix="${sub_prefix:-sub}"
    
    # Port for subscription page
    local sub_port="${SUB_PAGE_PORT:-3010}"
    
    echo
    colorized_echo blue "📁 Creating directory $APP_DIR..."
    mkdir -p "$APP_DIR"
    mkdir -p "$APP_DIR/logs"
    
    # Create standalone marker
    echo "standalone" > "$APP_DIR/.standalone-subpage"
    echo "Installed: $(date)" >> "$APP_DIR/.standalone-subpage"
    echo "Panel URL: $panel_url" >> "$APP_DIR/.standalone-subpage"
    
    # Create .env.subscription
    colorized_echo blue "📝 Creating .env.subscription..."
    cat > "$SUB_ENV_FILE" << EOF
### Standalone Subscription Page Configuration
### Created by install-subpage-standalone command
### $(date)

# Remote Remnawave Panel URL
REMNAWAVE_PANEL_URL=$panel_url

# Subscription page port inside container
APP_PORT=$sub_port

# Custom subscription prefix path (without leading/trailing slashes)
CUSTOM_SUB_PREFIX=$sub_prefix

# API Token from Remnawave Panel (Settings → API Tokens)
REMNAWAVE_API_TOKEN=$api_token

# Support Marzban links (optional)
#MARZBAN_LEGACY_LINK_ENABLED=false
#MARZBAN_LEGACY_SECRET_KEY=
EOF
    colorized_echo green "✅ Created $SUB_ENV_FILE"
    
    # Generate standalone docker-compose.yml
    colorized_echo blue "📝 Creating docker-compose.yml..."
    generate_standalone_subpage_compose "$sub_port"
    colorized_echo green "✅ Created $COMPOSE_FILE"
    
    # Install Docker if needed
    if ! command -v docker >/dev/null 2>&1; then
        colorized_echo blue "🐳 Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
    fi
    
    detect_compose
    
    # Pull and start container
    colorized_echo blue "📥 Pulling subscription-page image..."
    cd "$APP_DIR"
    $COMPOSE pull
    
    colorized_echo blue "🚀 Starting subscription-page container..."
    $COMPOSE up -d
    
    # Wait for container to start
    sleep 3
    
    # Check if running
    if is_subpage_up; then
        colorized_echo green "✅ Subscription-page container is running"
    else
        colorized_echo red "❌ Container failed to start"
        colorized_echo yellow "Check logs: docker logs ${APP_NAME}-subscription-page"
    fi
    
    # Install Caddy if requested
    if [ "$with_caddy" = true ]; then
        echo
        install_caddy_for_standalone_subpage "$sub_domain" "$sub_port" "$sub_prefix"
    else
        echo
        colorized_echo yellow "💡 Tip: Install Caddy for HTTPS:"
        echo -e "   \033[38;5;15m$APP_NAME caddy-standalone\033[0m"
    fi
    
    echo
    colorized_echo green "==================================================="
    colorized_echo green "🎉 Standalone Subscription-Page Installed!"
    colorized_echo green "==================================================="
    echo
    colorized_echo white "📋 Configuration:"
    echo "   Panel URL:     $panel_url"
    echo "   Subpage Port:  $sub_port (localhost only)"
    echo "   Domain:        $sub_domain"
    echo "   Config dir:    $APP_DIR"
    echo
    
    if [ -z "$api_token" ]; then
        colorized_echo yellow "⚠️  IMPORTANT: Configure API token!"
        echo -e "   \033[38;5;244m1. Login to Remnawave Panel\033[0m"
        echo -e "   \033[38;5;244m2. Go to Settings → API Tokens\033[0m"
        echo -e "   \033[38;5;244m3. Create token named 'subscription-page'\033[0m"
        echo -e "   \033[38;5;244m4. Run: $APP_NAME subpage-token\033[0m"
    fi
    
    echo
    colorized_echo white "📝 Useful commands:"
    echo "   Status:   $APP_NAME status"
    echo "   Logs:     $APP_NAME logs"
    echo "   Restart:  $APP_NAME restart"
    echo "   Menu:     $APP_NAME"
    echo
}

# Generate standalone docker-compose.yml for subscription-page only
generate_standalone_subpage_compose() {
    local sub_port="${1:-3010}"
    
    cat > "$COMPOSE_FILE" << EOL
# Standalone Subscription-Page for Remnawave
# Generated by remnawave.sh - GIG.OVH Project
# This configuration is for running subscription-page on a SEPARATE server
# without the main Remnawave panel.

services:
    ${APP_NAME}-subscription-page:
        image: remnawave/subscription-page:latest
        container_name: ${APP_NAME}-subscription-page
        hostname: ${APP_NAME}-subscription-page
        restart: always
        env_file:
            - .env.subscription
        ports:
            - '127.0.0.1:${sub_port}:\${APP_PORT:-3010}'
        logging:
            driver: "json-file"
            options:
                max-size: "10m"
                max-file: "3"
        healthcheck:
            test: ['CMD-SHELL', 'wget -q --spider http://localhost:\${APP_PORT:-3010}/health || exit 1']
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 10s

networks:
    default:
        name: ${APP_NAME}-standalone-network
        driver: bridge
EOL
}

# Install Caddy for standalone subscription-page
install_caddy_for_standalone_subpage() {
    local sub_domain="$1"
    local sub_port="${2:-3010}"
    local sub_prefix="${3:-sub}"
    
    colorized_echo cyan "==================================================="
    colorized_echo cyan "🌐 Installing Caddy for Standalone Subpage"
    colorized_echo cyan "==================================================="
    echo
    
    # Check for existing web servers
    local existing_webserver=$(check_existing_webserver)
    
    if [ -n "$existing_webserver" ] && [ "$existing_webserver" != "port_in_use" ]; then
        colorized_echo yellow "⚠️  Existing web server detected: $existing_webserver"
        echo
        colorized_echo yellow "Caddy needs ports 80 and 443 to work properly."
        colorized_echo yellow "You need to stop or remove the existing web server first."
        echo
        read -p "Do you want to continue anyway? (y/n): " -r continue_install
        if [[ ! $continue_install =~ ^[Yy]$ ]]; then
            colorized_echo gray "Caddy installation cancelled."
            return 1
        fi
    elif [ "$existing_webserver" = "port_in_use" ]; then
        colorized_echo yellow "⚠️  Ports 80 or 443 are already in use"
        echo
        colorized_echo yellow "Caddy needs these ports to work properly."
        echo
        read -p "Do you want to continue anyway? (y/n): " -r continue_install
        if [[ ! $continue_install =~ ^[Yy]$ ]]; then
            colorized_echo gray "Caddy installation cancelled."
            return 1
        fi
    fi
    
    # Check firewall
    check_firewall_ports
    
    # DNS validation
    colorized_echo white "🔍 Verifying DNS configuration for $sub_domain..."
    echo
    if ! validate_domain_dns "$sub_domain"; then
        echo
        colorized_echo yellow "⚠️  DNS check did not pass."
        colorized_echo yellow "    Caddy may fail to obtain SSL certificates if domain"
        colorized_echo yellow "    is not properly pointing to this server."
        echo
        read -p "Continue with Caddy installation anyway? (y/n): " -r continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            colorized_echo gray "Caddy installation cancelled."
            colorized_echo yellow "Fix DNS configuration and run: remnawave caddy-standalone"
            return 1
        fi
    else
        colorized_echo green "✅ DNS check passed for $sub_domain"
        echo
    fi
    
    # Check if Caddy is already installed
    if is_caddy_installed; then
        colorized_echo yellow "⚠️  Caddy is already installed at $CADDY_DIR"
        read -p "Do you want to reinstall? (y/n): " -r reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            colorized_echo gray "Caddy installation cancelled."
            return 1
        fi
        cd "$CADDY_DIR"
        docker compose down 2>/dev/null || true
    fi
    
    # Create directory
    mkdir -p "$CADDY_DIR"
    mkdir -p "$CADDY_DIR/logs"
    
    colorized_echo blue "📁 Creating configuration in $CADDY_DIR"
    echo
    
    # Create .env file
    cat > "$CADDY_DIR/.env" << EOF
# Caddy Reverse Proxy for Standalone Subscription-Page
# Generated on $(date)
# Server IP: ${NODE_IP:-127.0.0.1}

SUB_DOMAIN=$sub_domain
SUB_PORT=$sub_port
SUB_PREFIX=$sub_prefix
EOF
    colorized_echo green "✅ .env file created"
    
    # Create docker-compose.yml for Caddy
    cat > "$CADDY_DIR/docker-compose.yml" << EOF
services:
  caddy:
    image: caddy:${CADDY_VERSION}
    container_name: caddy-remnawave
    hostname: caddy
    restart: always
    ports:
      - "0.0.0.0:80:80"
      - "0.0.0.0:443:443"
      - "0.0.0.0:443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./logs:/var/log/caddy
      - caddy-ssl-data:/data
    env_file:
      - .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  caddy-ssl-data:
    driver: local
    external: false
    name: caddy-standalone-ssl-data
EOF
    colorized_echo green "✅ docker-compose.yml created"
    
    # Create Caddyfile for standalone subpage
    cat > "$CADDY_DIR/Caddyfile" << EOF
# Caddy Reverse Proxy for Standalone Subscription-Page
# Generated by remnawave.sh - GIG.OVH Project

{
    servers {
        protocols h1 h2 h3
    }
}

https://{\$SUB_DOMAIN} {
    encode zstd gzip
    
    log {
        output file /var/log/caddy/access.log {
            roll_size 10mb
            roll_keep 3
        }
    }
    
    # Health check endpoint
    handle /health {
        reverse_proxy host.docker.internal:{\$SUB_PORT}
    }
    
    # All requests go to subscription-page
    handle /* {
        reverse_proxy host.docker.internal:{\$SUB_PORT} {
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}
            header_up Host {host}
        }
    }
}

# HTTP to HTTPS redirect
http://{\$SUB_DOMAIN} {
    redir https://{\$SUB_DOMAIN}{uri} permanent
}
EOF
    colorized_echo green "✅ Caddyfile created"
    
    # Start Caddy
    colorized_echo blue "🚀 Starting Caddy..."
    cd "$CADDY_DIR"
    
    if docker compose up -d 2>&1; then
        colorized_echo green "✅ Caddy started successfully!"
    else
        colorized_echo red "❌ Failed to start Caddy"
        return 1
    fi
    
    # Wait for Caddy to start
    sleep 3
    
    # Check if running
    if docker ps --format '{{.Names}}' | grep -q "caddy-remnawave"; then
        colorized_echo green "✅ Caddy is running"
    else
        colorized_echo red "❌ Caddy container is not running"
        colorized_echo yellow "Check logs with: docker logs caddy-remnawave"
        return 1
    fi
    
    echo
    colorized_echo green "==================================================="
    colorized_echo green "🎉 Caddy Reverse Proxy installed!"
    colorized_echo green "==================================================="
    echo
    colorized_echo white "📋 Configuration:"
    echo "   Subscription URL: https://$sub_domain"
    echo "   Config directory: $CADDY_DIR"
    echo
    colorized_echo yellow "💡 SSL certificates will be automatically issued by Let's Encrypt"
    echo
    
    return 0
}

# Caddy command for standalone mode
caddy_standalone_command() {
    check_running_as_root
    
    if ! is_subpage_standalone; then
        colorized_echo red "This command is for standalone subpage mode only."
        colorized_echo yellow "Use '$APP_NAME caddy' for full panel installation."
        exit 1
    fi
    
    # Get subpage domain from .env.subscription or ask
    local sub_domain=""
    local sub_port="${SUB_PAGE_PORT:-3010}"
    local sub_prefix="sub"
    
    if [ -f "$APP_DIR/.standalone-subpage" ]; then
        # Try to get existing domain from Caddy config
        if [ -f "$CADDY_DIR/.env" ]; then
            sub_domain=$(grep "^SUB_DOMAIN=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2)
            sub_port=$(grep "^SUB_PORT=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2)
            sub_prefix=$(grep "^SUB_PREFIX=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2)
        fi
    fi
    
    if [ -z "$sub_domain" ]; then
        read -p "Enter domain for subscription page: " -r sub_domain
    fi
    
    if [ -z "$sub_domain" ]; then
        colorized_echo red "Domain is required!"
        exit 1
    fi
    
    install_caddy_for_standalone_subpage "$sub_domain" "$sub_port" "$sub_prefix"
}

up_command() {
    help() {
        colorized_echo red "Usage: remnawave up [options]"
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }

    local no_logs=false
    
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs) no_logs=true ;;
            -h|--help) 
                echo -e "\033[1;37m▶️  up\033[0m - Start all Remnawave services"
                echo
                echo -e "\033[1;37mUsage:\033[0m"
                echo -e "  \033[38;5;15m$APP_NAME\033[0m \033[38;5;250mup\033[0m [\033[38;5;244m--no-logs\033[0m]"
                echo
                echo -e "\033[1;37mOptions:\033[0m"
                echo -e "  \033[38;5;244m-n, --no-logs\033[0m   Start without following logs"
                echo
                exit 0
                ;;
            *) 
                echo "Error: Invalid option: $1" >&2
                echo "Use '$APP_NAME up --help' for usage information."
                exit 1
                ;;
        esac
        shift
    done
    

    if ! is_remnawave_installed; then
        colorized_echo red "Remnawave not installed!"
        exit 1
    fi

    detect_compose

    if is_remnawave_up; then
        colorized_echo red "Remnawave already up"
        exit 1
    fi

    up_remnawave
    if [ "$no_logs" = false ]; then
        follow_remnawave_logs
    fi
}

down_command() {
    if ! is_remnawave_installed; then
        colorized_echo red "Remnawave not installed!"
        exit 1
    fi

    detect_compose

    if ! is_remnawave_up; then
        colorized_echo red "Remnawave already down"
        exit 1
    fi

    down_remnawave
}

restart_command() {
    help() {
        colorized_echo red "Usage: remnawave restart [options]"
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

    if ! is_remnawave_installed; then
        colorized_echo red "Remnawave not installed!"
        exit 1
    fi

    detect_compose

    down_remnawave
    up_remnawave

    if [ "$no_logs" = false ]; then
        follow_remnawave_logs
    fi
}

health_check_command() {
    echo -e "\033[1;37m🏥 Remnawave System Health Check\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    local issues=0
    
    # Проверка установки
    if ! is_remnawave_installed; then
        echo -e "\033[1;31m❌ Panel not installed\033[0m"
        return 1
    fi
    
    # Проверка Docker
    if ! command -v docker >/dev/null; then
        echo -e "\033[1;31m❌ Docker not installed\033[0m"
        issues=$((issues + 1))
    else
        echo -e "\033[1;32m✅ Docker installed\033[0m"
        
        # Проверка статуса Docker daemon
        if ! docker info >/dev/null 2>&1; then
            echo -e "\033[1;31m❌ Docker daemon not running\033[0m"
            issues=$((issues + 1))
        else
            echo -e "\033[1;32m✅ Docker daemon running\033[0m"
        fi
    fi
    
    # Проверка Docker Compose
    detect_compose
    if [ -z "$COMPOSE" ]; then
        echo -e "\033[1;31m❌ Docker Compose not found\033[0m"
        issues=$((issues + 1))
    else
        echo -e "\033[1;32m✅ Docker Compose available ($COMPOSE)\033[0m"
    fi
    
    # Проверка конфигурационных файлов
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "\033[1;31m❌ Environment file missing: $ENV_FILE\033[0m"
        issues=$((issues + 1))
    else
        echo -e "\033[1;32m✅ Environment file exists\033[0m"
        
        # Проверка обязательных переменных
        local required_vars=("APP_PORT" "JWT_AUTH_SECRET" "JWT_API_TOKENS_SECRET" "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_DB")
        for var in "${required_vars[@]}"; do
            if ! grep -q "^${var}=" "$ENV_FILE"; then
                echo -e "\033[1;31m❌ Missing required variable: $var\033[0m"
                issues=$((issues + 1))
            fi
        done
    fi
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "\033[1;31m❌ Docker Compose file missing: $COMPOSE_FILE\033[0m"
        issues=$((issues + 1))
    else
        echo -e "\033[1;32m✅ Docker Compose file exists\033[0m"
        
        # Проверка валидности compose файла
        if validate_compose_file "$COMPOSE_FILE"; then
            echo -e "\033[1;32m✅ Docker Compose file valid\033[0m"
        else
            echo -e "\033[1;31m❌ Docker Compose file invalid\033[0m"
            issues=$((issues + 1))
        fi
    fi
    
    # Проверка портов
    if [ -f "$ENV_FILE" ]; then
        echo -e "\033[1;37m🔌 Port Status Check:\033[0m"
        
        local app_port=$(grep "^APP_PORT=" "$ENV_FILE" | cut -d'=' -f2)
        local metrics_port=$(grep "^METRICS_PORT=" "$ENV_FILE" | cut -d'=' -f2)
        
        if [ -f "$SUB_ENV_FILE" ]; then
            local sub_port=$(grep "^APP_PORT=" "$SUB_ENV_FILE" | cut -d'=' -f2)
        fi
        
        # Проверяем каждый порт отдельно
        for port in $app_port $metrics_port $sub_port; do
            if [ -n "$port" ]; then
                local port_info=""
                local status_color="1;32"
                local status_icon="✅"
                
                # Получаем информацию о процессе, использующем порт
                if command -v ss >/dev/null 2>&1; then
                    port_info=$(ss -tlnp 2>/dev/null | grep ":$port " | head -1)
                elif command -v netstat >/dev/null 2>&1; then
                    port_info=$(netstat -tlnp 2>/dev/null | grep ":$port " | head -1)
                fi
                
                if [ -n "$port_info" ]; then
                    # Извлекаем имя процесса
                    local process_name=""
                    if echo "$port_info" | grep -q "docker-proxy"; then
                        process_name="docker-proxy"
                    elif echo "$port_info" | grep -q "nginx"; then
                        process_name="nginx"
                    elif echo "$port_info" | grep -q "apache"; then
                        process_name="apache"
                    else
                        # Попытка извлечь имя процесса из вывода
                        process_name=$(echo "$port_info" | grep -o 'users:(([^)]*))' | sed 's/users:((\([^)]*\)).*/\1/' | cut -d',' -f1 | tr -d '"' | head -1)
                        if [ -z "$process_name" ]; then
                            process_name="unknown process"
                        fi
                    fi
                    
                    # Определяем, это наш порт или чужой
                    if echo "$process_name" | grep -q "docker"; then
                        status_color="1;32"
                        status_icon="✅"
                        printf "   \033[38;5;15mPort %s:\033[0m \033[${status_color}m${status_icon} Used by Remnawave (docker)\033[0m\n" "$port"
                    else
                        status_color="1;33"
                        status_icon="⚠️ "
                        printf "   \033[38;5;15mPort %s:\033[0m \033[${status_color}m${status_icon} Occupied by %s\033[0m\n" "$port" "$process_name"
                        issues=$((issues + 1))
                    fi
                else
                    printf "   \033[38;5;15mPort %s:\033[0m \033[1;32m✅ Available\033[0m\n" "$port"
                fi
            fi
        done
    fi
    
    # Проверка дискового пространства
    local available_space=$(df "$APP_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [ "$available_space" -lt 1048576 ]; then  # 1GB в KB
        echo -e "\033[1;33m⚠️  Low disk space: $(( available_space / 1024 ))MB available\033[0m"
        issues=$((issues + 1))
    else
        echo -e "\033[1;32m✅ Sufficient disk space: $(( available_space / 1024 ))MB available\033[0m"
    fi
    
    # Проверка RAM
    local available_ram=$(free -m | awk 'NR==2{print $7}')
    if [ "$available_ram" -lt 256 ]; then
        echo -e "\033[1;33m⚠️  Low available RAM: ${available_ram}MB\033[0m"
    else
        echo -e "\033[1;32m✅ Sufficient RAM: ${available_ram}MB available\033[0m"
    fi
    
    # Проверка состояния сервисов (если установлены)
    if is_remnawave_up; then
        echo -e "\033[1;37m🐳 Services Status:\033[0m"
        detect_compose
        cd "$APP_DIR" 2>/dev/null || true
        
        # Получаем статус каждого сервиса
        local services_status=$($COMPOSE -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.Status}}" 2>/dev/null || echo "")
        
        if [ -n "$services_status" ]; then
            echo "$services_status" | tail -n +2 | while IFS=$'\t' read -r service status; do
                local status_icon="❓"
                local status_color="38;5;244"
                
                if [[ "$status" =~ "Up" ]]; then
                    if [[ "$status" =~ "healthy" ]]; then
                        status_icon="✅"
                        status_color="1;32"
                    elif [[ "$status" =~ "unhealthy" ]]; then
                        status_icon="❌"
                        status_color="1;31"
                    else
                        status_icon="🟡"
                        status_color="1;33"
                    fi
                elif [[ "$status" =~ "Exit" ]]; then
                    status_icon="❌"
                    status_color="1;31"
                elif [[ "$status" =~ "Restarting" ]]; then
                    status_icon="🔄"
                    status_color="1;33"
                fi
                
                printf "   \033[38;5;15m%-20s\033[0m \033[${status_color}m${status_icon} ${status}\033[0m\n" "$service:"
            done
        fi
    fi
    
    echo
    if [ $issues -eq 0 ]; then
        echo -e "\033[1;32m🎉 System health: EXCELLENT\033[0m"
        return 0
    else
        echo -e "\033[1;33m⚠️  Found $issues issue(s) that may affect performance\033[0m"
        
        # Предлагаем решения для типичных проблем
        echo
        echo -e "\033[1;37m💡 Recommendations:\033[0m"
        if [ $issues -gt 0 ]; then
            echo -e "\033[38;5;244m   • Check port conflicts and reconfigure if needed\033[0m"
            echo -e "\033[38;5;244m   • Review logs with '\033[38;5;15msudo $APP_NAME logs\033[38;5;244m'\033[0m"
            echo -e "\033[38;5;244m   • Restart services with '\033[38;5;15msudo $APP_NAME restart\033[38;5;244m'\033[0m"
        fi
        
        return 1
    fi
}



validate_compose_file() {
    local compose_file="$1"
    
    if [ ! -f "$compose_file" ]; then
        return 1
    fi
    
    local current_dir=$(pwd)
    cd "$(dirname "$compose_file")"
    
    if command -v docker >/dev/null 2>&1; then
        detect_compose
        
        if $COMPOSE config >/dev/null 2>&1; then
            cd "$current_dir"
            return 0
        else
            cd "$current_dir"
            return 1
        fi
    fi
    
    cd "$current_dir"
    return 0
}

status_command() {
    check_running_as_root
    detect_compose
    
    echo -e "\033[1;37m📊 Remnawave Panel Status Check:\033[0m"
    echo
    
    # Проверяем статус панели
    if is_remnawave_installed; then
        if is_remnawave_up; then
            printf "   \033[38;5;15m%-12s\033[0m \033[1;32m✅ Running\033[0m\n" "Status:"
        else
            printf "   \033[38;5;15m%-12s\033[0m \033[1;31m❌ Stopped\033[0m\n" "Status:"
        fi
    else
        printf "   \033[38;5;15m%-12s\033[0m \033[1;33m⚠️  Not Installed\033[0m\n" "Status:"
        return 1
    fi
    
    echo
    
    # Показываем статус сервисов
    echo -e "\033[1;37m🔧 Services Status:\033[0m"
    cd "$APP_DIR" 2>/dev/null || true
    
    local services_status=$($COMPOSE -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "")
    
    if [ -n "$services_status" ]; then
        echo "$services_status" | tail -n +2 | while IFS=$'\t' read -r service status ports; do
            local status_icon="❓"
            local status_color="38;5;244"
            
            if [[ "$status" =~ "Up" ]]; then
                if [[ "$status" =~ "healthy" ]]; then
                    status_icon="✅"
                    status_color="1;32"
                elif [[ "$status" =~ "unhealthy" ]]; then
                    status_icon="❌"
                    status_color="1;31"
                else
                    status_icon="🟡"
                    status_color="1;33"
                fi
            elif [[ "$status" =~ "Exit" ]]; then
                status_icon="❌"
                status_color="1;31"
            elif [[ "$status" =~ "Restarting" ]]; then
                status_icon="🔄"
                status_color="1;33"
            fi
            
            printf "   \033[38;5;15m%-25s\033[0m \033[${status_color}m${status_icon} %-25s\033[0m \033[38;5;244m%s\033[0m\n" "$service" "$status" "$ports"
        done
    else
        echo -e "\033[38;5;244m   No services found\033[0m"
    fi
    
    echo
    
    # Показываем использование ресурсов основного контейнера
    echo -e "\033[1;37m💾 Resource Usage:\033[0m"
    local main_stats=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" "${APP_NAME}" 2>/dev/null || echo "N/A\tN/A")
    local cpu_perc=$(echo "$main_stats" | cut -f1)
    local mem_usage=$(echo "$main_stats" | cut -f2)
    
    if [ "$cpu_perc" != "N/A" ]; then
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250mCPU: %-10s %s\033[0m\n" "Main Panel:" "$cpu_perc" "$mem_usage"
    else
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;244mStats not available\033[0m\n" "Main Panel:"
    fi
    
    echo
    
    # Показываем информацию о подключении
    if [ -f "$ENV_FILE" ]; then
        echo -e "\033[1;37m🌐 Connection Information:\033[0m"
        
        local app_port=$(grep "^APP_PORT=" "$ENV_FILE" | cut -d'=' -f2)
        local metrics_port=$(grep "^METRICS_PORT=" "$ENV_FILE" | cut -d'=' -f2)
        local panel_domain=$(grep "^FRONT_END_DOMAIN=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs 2>/dev/null)
        local sub_domain=$(grep "^SUB_PUBLIC_DOMAIN=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs 2>/dev/null)
        
        # Subscription port
        local sub_port=""
        if [ -f "$SUB_ENV_FILE" ]; then
            sub_port=$(grep "^APP_PORT=" "$SUB_ENV_FILE" | cut -d'=' -f2)
        fi
        
        # IP адрес
        local server_ip="${NODE_IP:-127.0.0.1}"
        
        # URL подключения
        if [ -n "$app_port" ]; then
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s:%s\033[0m\n" "Panel URL:" "$server_ip" "$app_port"
        fi
        
        if [ -n "$sub_port" ]; then
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s:%s\033[0m\n" "Sub Page URL:" "$server_ip" "$sub_port"
        fi
        
        if [ -n "$metrics_port" ]; then
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s:%s/api/metrics\033[0m\n" "Metrics URL:" "$server_ip" "$metrics_port"
        fi
        
        # Домены
        if [ -n "$panel_domain" ] && [ "$panel_domain" != "null" ]; then
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Panel Domain:" "$panel_domain"
        fi
        
        if [ -n "$sub_domain" ] && [ "$sub_domain" != "null" ]; then
            printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250m%s\033[0m\n" "Sub Domain:" "$sub_domain"
        fi
    fi
    
    echo
    
    # Caddy Reverse Proxy Status
    echo -e "\033[1;37m🌐 Reverse Proxy (Caddy):\033[0m"
    if is_caddy_installed; then
        if is_caddy_up; then
            printf "   \033[38;5;15m%-15s\033[0m \033[1;32m✅ Running\033[0m\n" "Status:"
            
            # Check mode
            if [ -f "$CADDY_DIR/Caddyfile" ]; then
                if grep -q "security" "$CADDY_DIR/Caddyfile" 2>/dev/null; then
                    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;117mSecure (authentication enabled)\033[0m\n" "Mode:"
                else
                    printf "   \033[38;5;15m%-15s\033[0m \033[38;5;250mSimple (basic proxy)\033[0m\n" "Mode:"
                fi
            fi
        else
            printf "   \033[38;5;15m%-15s\033[0m \033[1;31m❌ Stopped\033[0m\n" "Status:"
            echo -e "\033[38;5;244m   Run '$APP_NAME caddy up' to start\033[0m"
        fi
    else
        printf "   \033[38;5;15m%-15s\033[0m \033[38;5;244mNot installed\033[0m\n" "Status:"
        echo -e "\033[38;5;244m   Install via '$APP_NAME install' or manually\033[0m"
    fi
    
    echo

    if is_remnawave_up; then
        local unhealthy_count=$(docker ps --format "{{.Names}}\t{{.Status}}" | grep "$APP_NAME" | grep -c "unhealthy" 2>/dev/null || echo "0")
        if ! [[ "$unhealthy_count" =~ ^[0-9]+$ ]]; then
            unhealthy_count=0
        fi
        
        if [ "$unhealthy_count" -eq 0 ]; then
            echo -e "\033[1;32m🎉 All services are healthy and running!\033[0m"
        else
            echo -e "\033[1;33m⚠️  Some services may have health issues ($unhealthy_count unhealthy)\033[0m"
        fi
    else
        echo -e "\033[1;31m❌ Services are not running\033[0m"
        echo -e "\033[38;5;8m   Use 'sudo $APP_NAME up' to start services\033[0m"
    fi
    
    # Проверяем наличие устаревших переменных в .env
    if check_deprecated_env_variables; then
        echo
        echo -e "\033[1;33m⚠️  Deprecated environment variables detected\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo -e "\033[38;5;250mRemnawave v2.2.0+ manages these via UI:\033[0m"
        echo -e "\033[38;5;244m   • OAuth settings (Telegram, GitHub, etc.)\033[0m"
        echo -e "\033[38;5;244m   • Branding configuration\033[0m"
        echo
        echo -e "\033[38;5;250m💡 Run '\033[38;5;15msudo $APP_NAME update\033[38;5;250m' to clean up automatically\033[0m"
        echo -e "\033[38;5;250m   Or configure in panel: Settings → Authentication/Branding\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    fi
    
    if [[ "${BASH_SOURCE[1]}" =~ "main_menu" ]] || [[ "$0" =~ "$APP_NAME" ]] && [[ "$1" != "--no-pause" ]]; then
        echo
        read -p "Press Enter to continue..."
    fi
}

logs_command() {
    check_running_as_root
    detect_compose
    
    if ! is_remnawave_installed; then
        colorized_echo red "Remnawave not installed!"
        return 1
    fi

    if ! is_remnawave_up; then
        colorized_echo red "Remnawave services are not running!"
        colorized_echo yellow "   Run 'sudo $APP_NAME up' first"
        return 1
    fi

    logs_menu
}

logs_menu() {
    while true; do
        clear
        echo -e "\033[1;37m📋 Application Logs\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
        echo
        
        echo -e "\033[1;37m📊 Log Options:\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m 📱 Follow all logs (real-time)"
        echo -e "   \033[38;5;15m2)\033[0m 📄 Show last 100 lines"
        echo -e "   \033[38;5;15m3)\033[0m 🔍 Show specific service logs"
        echo -e "   \033[38;5;15m4)\033[0m ❌ Show error logs only"
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  Back"
        echo
        
        read -p "Select option [0-4]: " choice
        
        case "$choice" in
            1) show_live_logs ;;
            2) show_recent_logs ;;
            3) show_service_logs ;;
            4) show_error_logs ;;
            0) return 0 ;;
            *) 
                echo -e "\033[1;31mInvalid option!\033[0m"
                sleep 1
                ;;
        esac
    done
}

show_live_logs() {
    clear
    echo -e "\033[1;37m📱 Live Logs (Press Ctrl+C to exit)\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    cd "$APP_DIR"
    $COMPOSE -f "$COMPOSE_FILE" logs -f --tail=50
    
    echo
    read -p "Press Enter to return to logs menu..."
}

show_recent_logs() {
    clear
    echo -e "\033[1;37m📄 Last 100 Log Lines\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    cd "$APP_DIR"
    $COMPOSE -f "$COMPOSE_FILE" logs --tail=100
    
    echo
    read -p "Press Enter to return to logs menu..."
}

show_service_logs() {
    while true; do
        clear
        echo -e "\033[1;37m🔍 Service Logs\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
        echo
        
        echo -e "\033[1;37m📦 Available Services:\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m 🚀 Main Panel (remnawave)"
        echo -e "   \033[38;5;15m2)\033[0m 🗄️  Database (remnawave-db)"
        echo -e "   \033[38;5;15m3)\033[0m 📊 Redis (remnawave-redis)"
        echo -e "   \033[38;5;15m4)\033[0m 📄 Subscription Page"
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  Back"
        echo
        
        read -p "Select service [0-4]: " service_choice
        
        local service_name=""
        case "$service_choice" in
            1) service_name="remnawave" ;;
            2) service_name="remnawave-db" ;;
            3) service_name="remnawave-redis" ;;
            4) service_name="remnawave-subscription-page" ;;
            0) return 0 ;;
            *) 
                echo -e "\033[1;31mInvalid option!\033[0m"
                sleep 1
                continue
                ;;
        esac
        
        clear
        echo -e "\033[1;37m📋 Logs for: $service_name\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo
        
        cd "$APP_DIR"
        $COMPOSE -f "$COMPOSE_FILE" logs --tail=100 "$service_name"
        
        echo
        read -p "Press Enter to continue..."
    done
}

show_error_logs() {
    clear
    echo -e "\033[1;37m❌ Error Logs Only\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    cd "$APP_DIR"
    $COMPOSE -f "$COMPOSE_FILE" logs --tail=200 | grep -i "error\|exception\|failed\|fatal" || echo "No errors found in recent logs"
    
    echo
    read -p "Press Enter to return to logs menu..."
}
# Функция для получения digest локального образа (из RepoDigests)
get_local_image_digest() {
    local image="$1"
    # RepoDigests может содержать несколько digest - возвращаем все через пробел
    docker inspect --format='{{range .RepoDigests}}{{.}} {{end}}' "$image" 2>/dev/null | grep -o 'sha256:[a-f0-9]*' | tr '\n' ' '
}

# Быстрое получение remote digest через Registry API v2
# Возвращает: "digest:method" где method = api|fallback
get_remote_image_digest_fast() {
    local full_image="$1"
    local image="$full_image"
    local registry=""
    local repo=""
    local tag="latest"
    
    # Парсим image name
    if [[ "$image" == *":"* ]]; then
        tag="${image##*:}"
        image="${image%:*}"
    fi
    
    # Определяем registry и repo
    if [[ "$image" == ghcr.io/* ]]; then
        registry="ghcr.io"
        repo="${image#ghcr.io/}"
    elif [[ "$image" == *"/"* ]] && [[ "$image" != *"."* ]]; then
        # Docker Hub с namespace (user/repo)
        registry="docker.io"
        repo="$image"
    elif [[ "$image" != *"/"* ]]; then
        # Docker Hub official image (postgres, redis, etc.)
        registry="docker.io"
        repo="library/$image"
    else
        # Другой registry - fallback на docker manifest
        local digest=$(docker manifest inspect "$full_image" 2>/dev/null | grep -o '"digest"[[:space:]]*:[[:space:]]*"sha256:[a-f0-9]*"' | head -1 | grep -o 'sha256:[a-f0-9]*')
        echo "${digest}:fallback"
        return
    fi
    
    local digest=""
    local method="api"
    local arch=$(uname -m)
    local platform_arch="amd64"
    case "$arch" in
        x86_64|amd64) platform_arch="amd64" ;;
        aarch64|arm64) platform_arch="arm64" ;;
    esac
    
    if [ "$registry" = "docker.io" ]; then
        # Docker Hub - нужен token
        local token=$(curl -s --connect-timeout 3 "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull" 2>/dev/null | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$token" ]; then
            # Получаем digest из заголовка
            digest=$(curl -sI --connect-timeout 3 -H "Authorization: Bearer $token" \
                -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
                -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                "https://registry-1.docker.io/v2/${repo}/manifests/${tag}" 2>/dev/null | \
                tr -d '\r' | grep -i "^docker-content-digest:" | awk '{print $2}')
        fi
    elif [ "$registry" = "ghcr.io" ]; then
        # GitHub Container Registry - использует OCI формат
        local token=$(curl -s --connect-timeout 3 "https://ghcr.io/token?scope=repository:${repo}:pull" 2>/dev/null | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$token" ]; then
            # Сначала пробуем получить digest из заголовка с OCI Accept
            digest=$(curl -sI --connect-timeout 3 -H "Authorization: Bearer $token" \
                -H "Accept: application/vnd.oci.image.index.v1+json" \
                -H "Accept: application/vnd.oci.image.manifest.v1+json" \
                -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
                -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                "https://ghcr.io/v2/${repo}/manifests/${tag}" 2>/dev/null | \
                tr -d '\r' | grep -i "^docker-content-digest:" | awk '{print $2}')
            
            # Если заголовок пустой - получаем из тела
            if [ -z "$digest" ]; then
                local manifest_body=$(curl -s --connect-timeout 3 -H "Authorization: Bearer $token" \
                    -H "Accept: application/vnd.oci.image.index.v1+json" \
                    -H "Accept: application/vnd.oci.image.manifest.v1+json" \
                    "https://ghcr.io/v2/${repo}/manifests/${tag}" 2>/dev/null)
                
                # Ищем digest для нашей платформы
                digest=$(echo "$manifest_body" | grep -B5 "\"architecture\"[[:space:]]*:[[:space:]]*\"$platform_arch\"" | grep -o 'sha256:[a-f0-9]*' | head -1)
                
                # Fallback - берём первый digest
                if [ -z "$digest" ]; then
                    digest=$(echo "$manifest_body" | grep -o 'sha256:[a-f0-9]*' | head -1)
                fi
            fi
        fi
    fi
    
    # Fallback на docker manifest inspect если API не сработал
    if [ -z "$digest" ]; then
        digest=$(docker manifest inspect "$full_image" 2>/dev/null | grep -o '"digest"[[:space:]]*:[[:space:]]*"sha256:[a-f0-9]*"' | head -1 | grep -o 'sha256:[a-f0-9]*')
        method="fallback"
    fi
    
    echo "${digest}:${method}"
}

# Проверка одного образа (для параллельного запуска)
check_single_image_update() {
    local image="$1"
    local result_file="$2"
    
    local local_digests=$(get_local_image_digest "$image")
    local remote_result=$(get_remote_image_digest_fast "$image")
    local remote_digest="${remote_result%:*}"
    local method="${remote_result##*:}"
    
    # Метка метода проверки
    local method_label=""
    if [ "$method" = "api" ]; then
        method_label="via API"
    elif [ "$method" = "fallback" ]; then
        method_label="via manifest"
    fi
    
    if [ -z "$remote_digest" ]; then
        # Не удалось получить remote digest - образ недоступен или приватный
        echo "SKIP:$image|unavailable" >> "$result_file"
    elif [ -z "$local_digests" ]; then
        # Образ не найден локально, но доступен удалённо
        echo "NEW:$image|$method_label" >> "$result_file"
    elif echo "$local_digests" | grep -q "$remote_digest"; then
        # Remote digest найден среди локальных - обновлений нет
        echo "OK:$image|$method_label" >> "$result_file"
    else
        # Remote digest не найден среди локальных - есть обновление
        echo "UPDATE:$image|$method_label" >> "$result_file"
    fi
}

# Функция для быстрой ПАРАЛЛЕЛЬНОЙ проверки обновлений образов (без скачивания)
check_images_for_updates() {
    local compose_images="$1"
    local updates_available=false
    
    # Создаём временный файл для результатов
    local result_file=$(mktemp)
    local pids=""
    local image_count=0
    
    # Запускаем проверки ПАРАЛЛЕЛЬНО
    while IFS= read -r image; do
        [ -z "$image" ] && continue
        check_single_image_update "$image" "$result_file" &
        pids="$pids $!"
        image_count=$((image_count + 1))
    done <<< "$compose_images"
    
    # Ждём завершения всех проверок (таймаут 10 секунд на все)
    local start_time=$(date +%s)
    local timeout=10
    
    while [ -n "$pids" ]; do
        local still_running=""
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                still_running="$still_running $pid"
            fi
        done
        pids="$still_running"
        
        # Проверяем таймаут
        local now=$(date +%s)
        if [ $((now - start_time)) -ge $timeout ]; then
            # Убиваем зависшие процессы (тихо)
            for pid in $pids; do
                kill -9 "$pid" 2>/dev/null
                wait "$pid" 2>/dev/null
            done
            echo -e "\033[38;5;244m   ⚠ Timeout checking some images\033[0m"
            break
        fi
        
        [ -n "$pids" ] && sleep 0.3
    done
    
    # Обрабатываем результаты
    local updated_list=""
    local ok_count=0
    local skip_count=0
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local status="${line%%:*}"
        local rest="${line#*:}"
        local img="${rest%%|*}"
        local method="${rest##*|}"
        
        # Форматируем метод для вывода
        local method_info=""
        [ -n "$method" ] && method_info=" \033[38;5;240m[$method]\033[0m"
        
        case "$status" in
            UPDATE)
                updates_available=true
                updated_list="$updated_list\n   🔄 $img"
                ;;
            NEW)
                updates_available=true
                updated_list="$updated_list\n   📦 $img (not found locally)"
                ;;
            OK)
                ok_count=$((ok_count + 1))
                echo -e "\033[38;5;244m   ✓ $img\033[0m$method_info"
                ;;
            SKIP)
                skip_count=$((skip_count + 1))
                if [ "$method" = "unavailable" ]; then
                    echo -e "\033[38;5;244m   ⚠ $img \033[38;5;240m[unavailable/private]\033[0m"
                else
                    echo -e "\033[38;5;244m   ⚠ $img (check skipped)\033[0m"
                fi
                ;;
        esac
    done < "$result_file"
    
    # Удаляем временный файл
    rm -f "$result_file"
    
    if [ "$updates_available" = true ]; then
        echo -e "\033[1;33m📦 Updates available:\033[0m"
        echo -e "$updated_list"
        return 0  # Updates available
    else
        return 1  # No updates
    fi
}

update_command() {
    check_running_as_root
    if ! is_remnawave_installed; then
        echo -e "\033[1;31m❌ Remnawave not installed!\033[0m"
        echo -e "\033[38;5;8m   Run '\033[38;5;15msudo $APP_NAME install\033[38;5;8m' first\033[0m"
        exit 1
    fi
    
    detect_compose
    
    echo -e "\033[1;37m🔄 Starting Remnawave Update Check...\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    
    # === ШАГ 1: Проверка обновлений скрипта ===
    local current_script_version="$SCRIPT_VERSION"
    echo -e "\033[38;5;250m📝 Step 1:\033[0m Checking for script updates..."
    local remote_script_version=$(curl -s --connect-timeout 5 "$SCRIPT_URL" 2>/dev/null | grep "^SCRIPT_VERSION=" | cut -d'"' -f2)
    
    if [ -n "$remote_script_version" ] && [ "$remote_script_version" != "$current_script_version" ]; then
        echo -e "\033[1;33m🔄 Script update available: \033[38;5;15mv$current_script_version\033[0m → \033[1;37mv$remote_script_version\033[0m"
        read -p "Do you want to update the script first? (y/n): " -r update_script
        if [[ $update_script =~ ^[Yy]$ ]]; then
            update_remnawave_script
            echo -e "\033[1;32m✅ Script updated to v$remote_script_version\033[0m"
            echo -e "\033[38;5;8m   Please run the update command again to continue\033[0m"
            exit 0
        fi
    else
        echo -e "\033[1;32m✅ Script is up to date (v$current_script_version)\033[0m"
    fi
    
    cd "$APP_DIR" 2>/dev/null || { echo -e "\033[1;31m❌ Cannot access app directory\033[0m"; exit 1; }

    # === ШАГ 2: Получение списка образов ===
    echo -e "\033[38;5;250m📝 Step 2:\033[0m Checking current images..."
    local compose_images=$($COMPOSE -f "$COMPOSE_FILE" config 2>/dev/null | grep "image:" | awk '{print $2}' | sort | uniq)
    
    if [ -z "$compose_images" ]; then
        echo -e "\033[1;31m❌ Cannot read compose file images\033[0m"
        exit 1
    fi
    
    local total_images_count=$(echo "$compose_images" | wc -l | tr -d ' ')
    echo -e "\033[38;5;244mFound $total_images_count image(s) to check\033[0m"

    # === ШАГ 3: Быстрая проверка обновлений (без скачивания) ===
    echo -e "\033[38;5;250m📝 Step 3:\033[0m Quick update check (comparing digests)..."
    
    local images_need_update=false
    if check_images_for_updates "$compose_images"; then
        images_need_update=true
    fi
    
    # Проверяем устаревшие переменные .env
    local has_deprecated_vars=false
    if check_deprecated_env_variables; then
        has_deprecated_vars=true
    fi
    
    # Если нет обновлений образов
    if [ "$images_need_update" = false ]; then
        echo
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        echo -e "\033[1;32m🎉 All images are already up to date!\033[0m"
        
        # Проверяем .env на устаревшие переменные
        if [ "$has_deprecated_vars" = true ]; then
            echo
            echo -e "\033[1;33m⚠️  Deprecated variables detected in .env\033[0m"
            read -p "Would you like to clean them up now? (y/n): " -r clean_vars
            if [[ $clean_vars =~ ^[Yy]$ ]]; then
                migrate_deprecated_env_variables
            fi
        fi
        
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
        exit 0
    fi
    
    # === ШАГ 4: Подтверждение и скачивание образов ===
    echo
    read -p "Download and apply updates? (Y/n): " -r confirm_update
    if [[ $confirm_update =~ ^[Nn]$ ]]; then
        echo -e "\033[1;33m⚠️  Update cancelled by user\033[0m"
        exit 0
    fi
    
    echo -e "\033[38;5;250m📝 Step 4:\033[0m Downloading new images..."
    
    local pull_exit_code=0
    $COMPOSE -f "$COMPOSE_FILE" pull 2>&1 || pull_exit_code=$?
    
    if [ $pull_exit_code -ne 0 ]; then
        echo -e "\033[1;31m❌ Failed to pull images\033[0m"
        exit 1
    fi
    echo -e "\033[1;32m✅ Images downloaded successfully\033[0m"
    
    # === ШАГ 5: Миграция переменных окружения ===
    echo -e "\033[38;5;250m📝 Step 5:\033[0m Checking environment configuration..."
    if [ "$has_deprecated_vars" = true ]; then
        migrate_deprecated_env_variables
    else
        echo -e "\033[38;5;244m   Environment is clean\033[0m"
    fi
    
    # === ШАГ 6: Перезапуск контейнеров с новыми образами ===
    echo -e "\033[38;5;250m📝 Step 6:\033[0m Recreating containers with new images..."
    
    # Используем recreate для принудительного пересоздания контейнеров
    if recreate_remnawave; then
        echo -e "\033[1;32m✅ Containers recreated successfully\033[0m"
    else
        echo -e "\033[1;31m❌ Failed to recreate containers\033[0m"
        echo -e "\033[38;5;8m   Check logs with '\033[38;5;15msudo $APP_NAME logs\033[38;5;8m'\033[0m"
        exit 1
    fi
    
    # === ШАГ 7: Проверка здоровья сервисов ===
    echo -e "\033[38;5;250m📝 Step 7:\033[0m Waiting for services to become healthy..."
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        sleep 2
        if is_remnawave_up; then
            echo -e "\033[1;32m✅ All services are healthy\033[0m"
            break
        fi
        attempts=$((attempts + 1))
        
        if [ $attempts -eq $max_attempts ]; then
            echo -e "\033[1;33m⚠️  Services started but may still be initializing\033[0m"
            echo -e "\033[38;5;8m   Check status with '\033[38;5;15msudo $APP_NAME status\033[38;5;8m'\033[0m"
        fi
    done
    
    # === Итог ===
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo -e "\033[1;37m🎉 Remnawave updated successfully!\033[0m"
    echo -e "\033[38;5;250m💡 Services are running with latest versions\033[0m"
    echo -e "\033[38;5;8m   Check status: '\033[38;5;15msudo $APP_NAME status\033[38;5;8m'\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
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
    if [ -f "$ENV_FILE" ]; then
        $EDITOR "$ENV_FILE"
    else
        colorized_echo red "Environment file not found at $ENV_FILE"
        exit 1
    fi
}

edit_env_sub_command() {
    detect_os
    check_editor
    if [ -f "$SUB_ENV_FILE" ]; then
        $EDITOR "$SUB_ENV_FILE"
    else
        colorized_echo red "Environment file not found at $SUB_ENV_FILE"
        exit 1
    fi
}

console_command() {
        if ! is_remnawave_installed; then
            colorized_echo red "Remnawave not installed!"
            exit 1
        fi
    
     detect_compose
 
        if ! is_remnawave_up; then
            colorized_echo red "Remnawave is not running. Start it first with '$APP_NAME up'"
            exit 1
        fi

    docker exec -it $APP_NAME remnawave
}

pm2_monitor() {
        if ! is_remnawave_installed; then
            colorized_echo red "Remnawave not installed!"
            exit 1
        fi
    
     detect_compose
 
        if ! is_remnawave_up; then
            colorized_echo red "Remnawave is not running. Start it first with '$APP_NAME up'"
            exit 1
        fi

    docker exec -it $APP_NAME pm2 monit
}

# ===== STANDALONE SUBPAGE MENU =====
# Limited menu for standalone subscription-page mode

standalone_subpage_menu() {
    while true; do
        clear
        local lang_indicator="🇬🇧"
        [ "$MENU_LANG" = "ru" ] && lang_indicator="🇷🇺"
        
        echo -e "\033[1;37m📄 Standalone Subscription-Page\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m  $lang_indicator"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
        echo
        
        # Get panel URL from marker file
        local panel_url=""
        if [ -f "$APP_DIR/.standalone-subpage" ]; then
            panel_url=$(grep "^Panel URL:" "$APP_DIR/.standalone-subpage" 2>/dev/null | cut -d' ' -f3-)
        fi
        
        # Status display
        if is_subpage_up; then
            echo -e "\033[1;32m✅ Subscription-Page: Running\033[0m"
        else
            echo -e "\033[1;31m❌ Subscription-Page: Stopped\033[0m"
        fi
        
        # Show Caddy status
        if is_caddy_installed; then
            if is_caddy_up; then
                echo -e "\033[1;32m✅ Caddy: Running\033[0m"
            else
                echo -e "\033[1;31m❌ Caddy: Stopped\033[0m"
            fi
        fi
        
        if [ -n "$panel_url" ]; then
            echo
            echo -e "\033[38;5;244m📡 Remote Panel: $panel_url\033[0m"
        fi
        
        # Get subpage domain from Caddy config
        if [ -f "$CADDY_DIR/.env" ]; then
            local sub_domain=$(grep "^SUB_DOMAIN=" "$CADDY_DIR/.env" 2>/dev/null | cut -d'=' -f2)
            if [ -n "$sub_domain" ]; then
                echo -e "\033[38;5;117m🌐 URL: https://$sub_domain\033[0m"
            fi
        fi
        
        echo
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
        echo
        
        echo -e "\033[1;37m📊 Status & Monitoring:\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m 📊 Status"
        echo -e "   \033[38;5;15m2)\033[0m 📋 View Logs"
        echo
        
        echo -e "\033[1;37m⚙️  Services Control:\033[0m"
        echo -e "   \033[38;5;15m3)\033[0m ▶️  Start"
        echo -e "   \033[38;5;15m4)\033[0m ⏹️  Stop"
        echo -e "   \033[38;5;15m5)\033[0m 🔄 Restart"
        echo
        
        echo -e "\033[1;37m🌐 Caddy Reverse Proxy:\033[0m"
        if is_caddy_installed; then
            echo -e "   \033[38;5;15m6)\033[0m 🌐 Caddy Management →"
        else
            echo -e "   \033[38;5;15m6)\033[0m 🌐 Install Caddy"
        fi
        echo
        
        echo -e "\033[1;37m🔧 Configuration:\033[0m"
        echo -e "   \033[38;5;15m7)\033[0m 🔑 Configure API Token"
        echo -e "   \033[38;5;15m8)\033[0m 📝 Edit .env.subscription"
        echo -e "   \033[38;5;15m9)\033[0m ⬆️  Update Container"
        echo
        
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 55))\033[0m"
        echo -e "   \033[38;5;15mL)\033[0m 🌐 Language / Язык"
        echo -e "   \033[38;5;244mU)\033[0m 🗑️  Uninstall"
        echo -e "   \033[38;5;15m0)\033[0m 🚪 Exit"
        echo
        echo -e "\033[38;5;8mStandalone Subpage CLI v$SCRIPT_VERSION by DigneZzZ • gig.ovh\033[0m"
        echo
        read -p "$(echo -e "\033[1;37mSelect [0-9, L, U]:\033[0m ")" choice
        
        case "$choice" in
            1) standalone_status_command; read -p "Press Enter to continue..." ;;
            2) standalone_logs_command ;;
            3) standalone_up_command; read -p "Press Enter to continue..." ;;
            4) standalone_down_command; read -p "Press Enter to continue..." ;;
            5) standalone_restart_command; read -p "Press Enter to continue..." ;;
            6) 
                if is_caddy_installed; then
                    caddy_menu
                else
                    caddy_standalone_command
                    read -p "Press Enter to continue..."
                fi
                ;;
            7) subpage_configure_token; read -p "Press Enter to continue..." ;;
            8) standalone_edit_env ;;
            9) standalone_update_command; read -p "Press Enter to continue..." ;;
            [Ll]) 
                if [ "$MENU_LANG" = "en" ]; then
                    save_menu_language "ru"
                else
                    save_menu_language "en"
                fi
                ;;
            [Uu]) standalone_uninstall_command; read -p "Press Enter to continue..." ;;
            0) clear; exit 0 ;;
            *) 
                echo -e "\033[1;31mInvalid option!\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Standalone subpage commands
standalone_status_command() {
    clear
    echo -e "\033[1;37m📊 Standalone Subpage Status\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    detect_compose
    
    echo -e "\033[1;37mContainer Status:\033[0m"
    docker ps --filter "name=${APP_NAME}-subscription-page" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers found"
    echo
    
    if is_caddy_installed; then
        echo -e "\033[1;37mCaddy Status:\033[0m"
        docker ps --filter "name=caddy-remnawave" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Not running"
        echo
    fi
    
    echo -e "\033[1;37mConfiguration:\033[0m"
    if [ -f "$APP_DIR/.standalone-subpage" ]; then
        cat "$APP_DIR/.standalone-subpage"
    fi
    echo
    
    # Check API token
    if [ -f "$SUB_ENV_FILE" ]; then
        local api_token=$(grep "^REMNAWAVE_API_TOKEN=" "$SUB_ENV_FILE" 2>/dev/null | cut -d'=' -f2)
        if [ -z "$api_token" ]; then
            echo -e "\033[1;33m⚠️  API Token: Not configured\033[0m"
        else
            echo -e "\033[1;32m✅ API Token: Configured\033[0m"
        fi
    fi
}

standalone_logs_command() {
    detect_compose
    cd "$APP_DIR"
    $COMPOSE logs -f --tail=100
}

standalone_up_command() {
    detect_compose
    cd "$APP_DIR"
    colorized_echo blue "Starting subscription-page..."
    $COMPOSE up -d
    
    if is_subpage_up; then
        colorized_echo green "✅ Subscription-page started!"
    else
        colorized_echo red "❌ Failed to start"
    fi
    
    # Also start Caddy if installed
    if is_caddy_installed; then
        colorized_echo blue "Starting Caddy..."
        cd "$CADDY_DIR"
        docker compose up -d
        if is_caddy_up; then
            colorized_echo green "✅ Caddy started!"
        fi
    fi
}

standalone_down_command() {
    detect_compose
    cd "$APP_DIR"
    colorized_echo blue "Stopping subscription-page..."
    $COMPOSE down
    colorized_echo green "✅ Subscription-page stopped"
    
    # Also stop Caddy if installed
    if is_caddy_installed; then
        colorized_echo blue "Stopping Caddy..."
        cd "$CADDY_DIR"
        docker compose down
        colorized_echo green "✅ Caddy stopped"
    fi
}

standalone_restart_command() {
    detect_compose
    cd "$APP_DIR"
    colorized_echo blue "Restarting subscription-page..."
    $COMPOSE restart
    
    if is_subpage_up; then
        colorized_echo green "✅ Subscription-page restarted!"
    else
        colorized_echo red "❌ Container not running"
    fi
    
    # Also restart Caddy if installed
    if is_caddy_installed && is_caddy_up; then
        colorized_echo blue "Restarting Caddy..."
        cd "$CADDY_DIR"
        docker compose restart
        colorized_echo green "✅ Caddy restarted!"
    fi
}

standalone_update_command() {
    detect_compose
    cd "$APP_DIR"
    
    colorized_echo blue "Pulling latest subscription-page image..."
    $COMPOSE pull
    
    colorized_echo blue "Recreating container with new image..."
    $COMPOSE up -d --force-recreate
    
    if is_subpage_up; then
        colorized_echo green "✅ Subscription-page updated!"
    else
        colorized_echo red "❌ Update failed"
    fi
}

standalone_edit_env() {
    check_editor
    
    if [ ! -f "$SUB_ENV_FILE" ]; then
        colorized_echo red ".env.subscription file not found!"
        return 1
    fi
    
    $EDITOR "$SUB_ENV_FILE"
    
    echo
    colorized_echo yellow "⚠️  Restart required for changes to take effect"
    read -p "Restart now? (y/n): " -r restart_now
    if [[ $restart_now =~ ^[Yy]$ ]]; then
        standalone_restart_command
    fi
}

standalone_uninstall_command() {
    colorized_echo yellow "⚠️  This will remove the standalone subscription-page installation"
    echo
    read -p "Are you sure? (y/n): " -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        colorized_echo gray "Cancelled"
        return 0
    fi
    
    detect_compose
    
    # Stop and remove containers
    colorized_echo blue "Stopping containers..."
    cd "$APP_DIR" 2>/dev/null && $COMPOSE down 2>/dev/null || true
    
    if is_caddy_installed; then
        colorized_echo blue "Stopping Caddy..."
        cd "$CADDY_DIR" && docker compose down 2>/dev/null || true
        
        read -p "Remove Caddy configuration? (y/n): " -r remove_caddy
        if [[ $remove_caddy =~ ^[Yy]$ ]]; then
            rm -rf "$CADDY_DIR"
            colorized_echo green "✅ Caddy removed"
        fi
    fi
    
    read -p "Remove all configuration files? (y/n): " -r remove_config
    if [[ $remove_config =~ ^[Yy]$ ]]; then
        rm -rf "$APP_DIR"
        colorized_echo green "✅ Configuration removed"
    fi
    
    colorized_echo green "✅ Standalone subscription-page uninstalled"
}

main_menu() {
    # Check for script updates on first menu display
    local remote_script_version=$(curl -s --connect-timeout 3 "$SCRIPT_URL" 2>/dev/null | grep "^SCRIPT_VERSION=" | head -1 | cut -d'"' -f2)
    if [ -n "$remote_script_version" ] && [ "$remote_script_version" != "$SCRIPT_VERSION" ]; then
        echo
        echo -e "\033[1;33m📦 New version available: v$remote_script_version (current: v$SCRIPT_VERSION)\033[0m"
        read -r -p "Update now? (y/n) " update_choice
        if [[ "$update_choice" =~ ^[Yy]$ ]]; then
            colorized_echo blue "Updating script..."
            curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/$APP_NAME
            colorized_echo green "✅ Script updated successfully! Restarting..."
            sleep 1
            exec "$APP_NAME" "$@"
        fi
        echo
    fi
    
    while true; do
        clear
        # Header with language indicator
        local lang_indicator="🇬🇧"
        [ "$MENU_LANG" = "ru" ] && lang_indicator="🇷🇺"
        
        echo -e "\033[1;37m⚡ $APP_NAME Panel Management\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m  $lang_indicator"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
        echo
        
        # Panel status display
        if is_remnawave_installed; then
            if is_remnawave_up; then
                echo -e "\033[1;32m✅ $(L PANEL_RUNNING)\033[0m"
                
                # Show Caddy status if installed
                if is_caddy_installed; then
                    if is_caddy_up; then
                        echo -e "\033[1;32m✅ Caddy: Running\033[0m"
                    else
                        echo -e "\033[1;31m❌ Caddy: Stopped\033[0m"
                    fi
                fi
                
                if [ -f "$ENV_FILE" ]; then
                    local panel_domain=$(grep "^FRONT_END_DOMAIN=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" | awk '{print $1}')
                    local sub_domain=$(grep "^SUB_PUBLIC_DOMAIN=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" | awk '{print $1}')
                    
                    if [ -n "$panel_domain" ] && [ "$panel_domain" != "null" ]; then
                        echo
                        echo -e "\033[1;37m🌐 $(L PANEL_ACCESS_URLS):\033[0m"
                        if [[ "$panel_domain" =~ ^https?:// ]]; then
                            printf "   \033[38;5;15m📊 $(L PANEL_ADMIN):\033[0m    \033[38;5;117m%s\033[0m\n" "$panel_domain"
                        else
                            printf "   \033[38;5;15m📊 $(L PANEL_ADMIN):\033[0m    \033[38;5;117mhttps://%s\033[0m\n" "$panel_domain"
                        fi
                        if [ -n "$sub_domain" ] && [ "$sub_domain" != "null" ]; then
                            if [[ "$sub_domain" =~ ^https?:// ]]; then
                                printf "   \033[38;5;15m📄 $(L PANEL_SUBSCRIPTIONS):\033[0m \033[38;5;117m%s\033[0m\n" "$sub_domain"
                            else
                                printf "   \033[38;5;15m📄 $(L PANEL_SUBSCRIPTIONS):\033[0m \033[38;5;117mhttps://%s\033[0m\n" "$sub_domain"
                            fi
                        fi
                    fi
                fi
            else
                echo -e "\033[1;31m❌ $(L PANEL_STOPPED)\033[0m"
            fi
        else
            echo -e "\033[1;33m⚠️  $(L PANEL_NOT_INSTALLED)\033[0m"
        fi
        
        echo
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
        echo
        
        # Menu sections
        echo -e "\033[1;37m📊 $(L MENU_STATUS_MONITORING):\033[0m"
        echo -e "   \033[38;5;15m1)\033[0m 📊 $(L SUB_STATUS)"
        echo -e "   \033[38;5;15m2)\033[0m 📋 $(L SUB_LOGS)"
        echo -e "   \033[38;5;15m3)\033[0m 🩺 $(L SUB_HEALTH)"
        echo -e "   \033[38;5;15m4)\033[0m 📈 $(L SUB_MONITOR)"
        echo
        
        echo -e "\033[1;37m⚙️  $(L MENU_SERVICES_CONTROL):\033[0m"
        echo -e "   \033[38;5;15m5)\033[0m ⚙️  $(L MENU_SERVICES_CONTROL) →"
        echo
        
        echo -e "\033[1;37m🌐 $(L MENU_REVERSE_PROXY):\033[0m"
        if is_caddy_installed; then
            if is_caddy_up; then
                echo -e "   \033[38;5;15m6)\033[0m 🌐 $(L CADDY_MANAGEMENT) → \033[1;32m($(L CADDY_RUNNING))\033[0m"
            else
                echo -e "   \033[38;5;15m6)\033[0m 🌐 $(L CADDY_MANAGEMENT) → \033[1;31m($(L CADDY_STOPPED))\033[0m"
            fi
        else
            echo -e "   \033[38;5;15m6)\033[0m 🌐 $(L CADDY_INSTALL)"
        fi
        echo
        
        echo -e "\033[1;37m📄 $(L MENU_SUBSCRIPTION):\033[0m"
        echo -e "   \033[38;5;15m7)\033[0m 📄 $(L MENU_SUBSCRIPTION) →"
        echo
        
        echo -e "\033[1;37m💾 $(L MENU_BACKUP):\033[0m"
        echo -e "   \033[38;5;15m8)\033[0m 💾 $(L BAK_MANUAL)"
        echo -e "   \033[38;5;15m9)\033[0m 📅 $(L BAK_SCHEDULE) →"
        echo -e "   \033[38;5;15m10)\033[0m 🔄 $(L BAK_RESTORE)"
        echo
        
        echo -e "\033[1;37m🛠️  $(L MENU_INSTALLATION):\033[0m"
        echo -e "   \033[38;5;15m11)\033[0m 🛠️  $(L MENU_INSTALLATION) →"
        echo
        
        echo -e "\033[1;37m⚙️  $(L MENU_ADVANCED):\033[0m"
        echo -e "   \033[38;5;15m12)\033[0m 📝 $(L ADV_EDIT) →"
        echo -e "   \033[38;5;15m13)\033[0m 🖥️  $(L ADV_SHELL)"
        echo -e "   \033[38;5;15m14)\033[0m 📊 $(L ADV_PM2)"
        echo
        
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
        echo -e "   \033[38;5;15mL)\033[0m 🌐 $(L MENU_LANG_SWITCH)"
        echo -e "   \033[38;5;15m0)\033[0m 🚪 $(L MENU_EXIT)"
        echo
        echo -e "\033[38;5;8mRemnawave Panel CLI v$SCRIPT_VERSION by DigneZzZ • gig.ovh\033[0m"
        echo
        read -p "$(echo -e "\033[1;37m$(L MENU_SELECT) [0-14, L]:\033[0m ")" choice

        case "$choice" in
            1) status_command; read -p "$(L PRESS_ENTER)" ;;
            2) logs_command ;;
            3) health_check_command; read -p "$(L PRESS_ENTER)" ;;
            4) monitor_command ;;
            5) services_control_menu ;;
            6)
                if is_caddy_installed; then
                    caddy_menu
                else
                    install_caddy_reverse_proxy
                    read -p "$(L PRESS_ENTER)"
                fi
                ;;
            7) subpage_menu ;;
            8) backup_command; read -p "$(L PRESS_ENTER)" ;;
            9) schedule_menu ;;
            10) restore_command; read -p "$(L PRESS_ENTER)" ;;
            11) installation_menu ;;
            12) edit_command_menu ;;
            13) console_command ;;
            14) pm2_monitor ;;
            [Ll]) 
                if [ "$MENU_LANG" = "en" ]; then
                    save_menu_language "ru"
                else
                    save_menu_language "en"
                fi
                ;;
            0) clear; exit 0 ;;
            *) 
                echo -e "\033[1;31m$(L INVALID_OPTION)\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Services Control submenu
services_control_menu() {
    while true; do
        clear
        echo -e "\033[1;37m⚙️  $(L SVC_TITLE)\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
        echo
        
        # Show current status
        if is_remnawave_up; then
            echo -e "   \033[38;5;15mStatus:\033[0m \033[1;32m✅ Running\033[0m"
        else
            echo -e "   \033[38;5;15mStatus:\033[0m \033[1;31m❌ Stopped\033[0m"
        fi
        echo
        
        echo -e "   \033[38;5;15m1)\033[0m ▶️  $(L SVC_START)"
        echo -e "   \033[38;5;15m2)\033[0m ⏹️  $(L SVC_STOP)"
        echo -e "   \033[38;5;15m3)\033[0m 🔄 $(L SVC_RESTART)"
        echo
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  $(L SUB_BACK)"
        echo
        
        read -p "$(echo -e "\033[1;37m$(L MENU_SELECT) [0-3]:\033[0m ")" choice
        
        case "$choice" in
            1) up_command; read -p "$(L PRESS_ENTER)" ;;
            2) down_command; read -p "$(L PRESS_ENTER)" ;;
            3) restart_command; read -p "$(L PRESS_ENTER)" ;;
            0) return 0 ;;
            *)
                echo -e "\033[1;31m$(L INVALID_OPTION)\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Installation submenu
installation_menu() {
    while true; do
        clear
        echo -e "\033[1;37m🛠️  $(L INST_TITLE)\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
        echo
        
        # Show installation status
        if is_remnawave_installed; then
            echo -e "   \033[38;5;15mStatus:\033[0m \033[1;32m✅ Installed\033[0m"
        else
            echo -e "   \033[38;5;15mStatus:\033[0m \033[1;33m⚠️  Not installed\033[0m"
        fi
        echo
        
        echo -e "   \033[38;5;15m1)\033[0m 🛠️  $(L INST_INSTALL)"
        echo -e "   \033[38;5;15m2)\033[0m ⬆️  $(L INST_UPDATE)"
        echo -e "   \033[38;5;15m3)\033[0m 🗑️  $(L INST_UNINSTALL)"
        echo
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  $(L SUB_BACK)"
        echo
        
        read -p "$(echo -e "\033[1;37m$(L MENU_SELECT) [0-3]:\033[0m ")" choice
        
        case "$choice" in
            1) install_command; read -p "$(L PRESS_ENTER)" ;;
            2) update_command; read -p "$(L PRESS_ENTER)" ;;
            3) uninstall_command; read -p "$(L PRESS_ENTER)" ;;
            0) return 0 ;;
            *)
                echo -e "\033[1;31m$(L INVALID_OPTION)\033[0m"
                sleep 1
                ;;
        esac
    done
}


edit_command_menu() {
    while true; do
        clear
        echo -e "\033[1;37m📝 Configuration Editor\033[0m"
        echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
        echo
        echo -e "   \033[38;5;15m1)\033[0m 📝 Edit docker-compose.yml"
        echo -e "   \033[38;5;15m2)\033[0m ⚙️  Edit main environment (.env)"
        echo -e "   \033[38;5;15m3)\033[0m 📄 Edit subscription environment (.env.subscription)"
        echo -e "   \033[38;5;244m0)\033[0m ⬅️  Back"
        echo
        
        read -p "Select option [0-3]: " choice
        
        case "$choice" in
            1) edit_command; read -p "Press Enter to continue..." ;;
            2) edit_env_command; read -p "Press Enter to continue..." ;;
            3) edit_env_sub_command; read -p "Press Enter to continue..." ;;
            0) return 0 ;;
            *) 
                echo -e "\033[1;31mInvalid option!\033[0m"
                sleep 1
                ;;
        esac
    done
}

usage() {
    echo -e "\033[1;37m⚡ $APP_NAME\033[0m \033[38;5;8mPanel Management CLI\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    echo
    echo -e "\033[1;37m🎯 Installation & Updates:\033[0m"
    printf "   \033[38;5;15m%-18s\033[0m %s\n" "install" "🛠️  Install Remnawave panel"
    printf "   \033[38;5;15m%-18s\033[0m %s\n" "update" "⬆️  Update to latest version"
    printf "   \033[38;5;15m%-18s\033[0m %s\n" "uninstall" "🗑️  Remove panel completely"
    echo

    echo -e "\033[1;37m⚙️  Service Management:\033[0m"
    printf "   \033[38;5;250m%-18s\033[0m %s\n" "up" "▶️  Start all services"
    printf "   \033[38;5;250m%-18s\033[0m %s\n" "down" "⏹️  Stop all services"
    printf "   \033[38;5;250m%-18s\033[0m %s\n" "restart" "🔄 Restart all services"
    printf "   \033[38;5;250m%-18s\033[0m %s\n" "status" "📊 Show services status"
    echo

    echo -e "\033[1;37m📊 Monitoring & Logs:\033[0m"
    printf "   \033[38;5;244m%-18s\033[0m %s\n" "logs" "📋 View application logs"
    printf "   \033[38;5;244m%-18s\033[0m %s\n" "monitor" "📈 System performance monitor"
    printf "   \033[38;5;244m%-18s\033[0m %s\n" "health" "🩺 Health check diagnostics"
    echo

    echo -e "\033[1;37m💾 Backup & Restore:\033[0m"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "backup" "💾 Manual database backup"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "schedule" "📅 Scheduled backup system"
    printf "   \033[38;5;178m%-18s\033[0m %s\n" "restore" "🔄 Restore from backup" 
    echo

    echo -e "\033[1;37m🔧 Configuration & Access:\033[0m"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "subpage" "📄 Subscription page settings"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "subpage-restart" "🔃 Quick restart subscription-page"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "subpage-token" "🔑 Configure API token"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "install-subpage" "📦 Install subscription-page only"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "edit" "📝 Edit docker-compose.yml"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "edit-env" "⚙️  Edit environment variables"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "edit-env-sub" "⚙️  Edit subscription environment variables"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "console" "📥  Access container shell"
    printf "   \033[38;5;117m%-18s\033[0m %s\n" "pm2-monitor" "📊 PM2 process monitor"
    echo

    echo -e "\033[1;37m� Standalone Subscription-Page:\033[0m"
    printf "   \033[38;5;214m%-24s\033[0m %s\n" "install-subpage-standalone" "🌐 Install subpage on separate server"
    printf "   \033[38;5;214m%-24s\033[0m %s\n" "caddy-standalone" "🔒 Install Caddy for standalone subpage"
    echo

    echo -e "\033[1;37m�📊 Script Management:\033[0m"
    printf "   \033[38;5;244m%-18s\033[0m %s\n" "install-script" "📥 Install this script globally"
    printf "   \033[38;5;244m%-18s\033[0m %s\n" "uninstall-script" "📤 Remove script from system"
    echo

    echo -e "\033[1;37m🌐 Caddy Reverse Proxy:\033[0m"
    printf "   \033[38;5;81m%-18s\033[0m %s\n" "caddy" "📊 Show Caddy status & help"
    printf "   \033[38;5;81m%-18s\033[0m %s\n" "caddy up" "▶️  Start Caddy"
    printf "   \033[38;5;81m%-18s\033[0m %s\n" "caddy down" "⏹️  Stop Caddy"
    printf "   \033[38;5;81m%-18s\033[0m %s\n" "caddy restart" "🔄 Restart Caddy"
    printf "   \033[38;5;81m%-18s\033[0m %s\n" "caddy logs" "📋 View Caddy logs"
    printf "   \033[38;5;81m%-18s\033[0m %s\n" "caddy edit" "📝 Edit Caddyfile"
    printf "   \033[38;5;81m%-18s\033[0m %s\n" "caddy reset-user" "🔑 Reset admin password"
    echo

    echo -e "\033[38;5;8m💡 Flexible restore paths:\033[0m"
    echo -e "\033[38;5;244m   $APP_NAME restore --path /root --name newpanel\033[0m"
    echo -e "\033[38;5;244m   # Installs to /root/newpanel/\033[0m"

    if is_remnawave_installed && [ -f "$ENV_FILE" ]; then
        local panel_domain=$(grep "FRONT_END_DOMAIN=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs 2>/dev/null)
        if [ -n "$panel_domain" ] && [ "$panel_domain" != "null" ]; then
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
            if [[ "$panel_domain" =~ ^https?:// ]]; then
                echo -e "\033[1;37m🌐 Panel Access:\033[0m \033[38;5;117m$panel_domain\033[0m"
            else
                echo -e "\033[1;37m🌐 Panel Access:\033[0m \033[38;5;117mhttps://$panel_domain\033[0m"
            fi
        fi
    fi

    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    echo -e "\033[1;37m📖 Examples:\033[0m"
    echo -e "\033[38;5;244m   sudo $APP_NAME install --name mypanel\033[0m"
    echo -e "\033[38;5;244m   sudo $APP_NAME schedule setup\033[0m"
    echo -e "\033[38;5;244m   sudo $APP_NAME backup --compress\033[0m"
    echo -e "\033[38;5;244m   $APP_NAME menu           # Interactive menu\033[0m"
    echo -e "\033[38;5;244m   $APP_NAME                # Same as menu\033[0m"
    echo
    echo -e "\033[38;5;8mUse '\033[38;5;15m$APP_NAME <command> --help\033[38;5;8m' for detailed command help\033[0m"
    echo
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
    echo -e "\033[38;5;8m📚 Project: \033[38;5;250mhttps://gig.ovh\033[0m"
    echo -e "\033[38;5;8m🐛 Issues: \033[38;5;250mhttps://github.com/DigneZzZ/remnawave-scripts\033[0m"
    echo -e "\033[38;5;8m💬 Support: \033[38;5;250mhttps://t.me/remnawave\033[0m"
    echo -e "\033[38;5;8m👨‍💻 Author: \033[38;5;250mDigneZzZ\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
}

usage_minimal() {
    echo -e "\033[1;37m⚡ $APP_NAME\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo
    echo -e "\033[1;37mMain:\033[0m"
    printf "   \033[38;5;15m%-12s\033[0m %s\n" "install" "🛠️  Install"
    printf "   \033[38;5;15m%-12s\033[0m %s\n" "update" "⬆️  Update"
    printf "   \033[38;5;15m%-12s\033[0m %s\n" "uninstall" "🗑️  Remove"
    echo
    echo -e "\033[1;37mControl:\033[0m"
    printf "   \033[38;5;250m%-12s\033[0m %s\n" "up" "▶️  Start"
    printf "   \033[38;5;250m%-12s\033[0m %s\n" "down" "⏹️  Stop"
    printf "   \033[38;5;250m%-12s\033[0m %s\n" "restart" "🔄 Restart"
    printf "   \033[38;5;250m%-12s\033[0m %s\n" "status" "📊 Status"
    echo
    echo -e "\033[1;37mTools:\033[0m"
    printf "   \033[38;5;244m%-12s\033[0m %s\n" "logs" "📋 Logs"
    printf "   \033[38;5;244m%-12s\033[0m %s\n" "monitor" "📈 Monitor"
    printf "   \033[38;5;244m%-12s\033[0m %s\n" "health" "🩺 Health"
    printf "   \033[38;5;244m%-12s\033[0m %s\n" "backup" "💾 Backup"
    printf "   \033[38;5;244m%-12s\033[0m %s\n" "schedule" "📅 Schedule"
    echo
    echo -e "\033[38;5;8mUse '\033[38;5;15m$APP_NAME help\033[38;5;8m' for full help\033[0m"
    echo -e "\033[38;5;8m👨‍💻 DigneZzZ | 📚 gig.ovh\033[0m"
}

usage_compact() {
    echo -e "\033[1;37m⚡ $APP_NAME\033[0m \033[38;5;8mPanel CLI\033[0m \033[38;5;244mv$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 50))\033[0m"
    echo
    
    echo -e "\033[1;37m🚀 Main:\033[0m"
    printf "   \033[38;5;15m%-16s\033[0m %s\n" "install" "🛠️  Install panel"
    printf "   \033[38;5;15m%-16s\033[0m %s\n" "update" "⬆️  Update system"
    printf "   \033[38;5;15m%-16s\033[0m %s\n" "uninstall" "🗑️  Remove panel"
    echo

    echo -e "\033[1;37m⚙️  Control:\033[0m"
    printf "   \033[38;5;250m%-16s\033[0m %s\n" "up" "▶️  Start services"
    printf "   \033[38;5;250m%-16s\033[0m %s\n" "down" "⏹️  Stop services"
    printf "   \033[38;5;250m%-16s\033[0m %s\n" "restart" "🔄 Restart services"
    printf "   \033[38;5;250m%-16s\033[0m %s\n" "status" "📊 Show status"
    echo

    echo -e "\033[1;37m📊 Monitoring:\033[0m"
    printf "   \033[38;5;244m%-16s\033[0m %s\n" "logs" "📋 View logs"
    printf "   \033[38;5;244m%-16s\033[0m %s\n" "monitor" "📈 Performance"
    printf "   \033[38;5;244m%-16s\033[0m %s\n" "health" "🩺 Health check"
    echo

    echo -e "\033[1;37m💾 Backup:\033[0m"
    printf "   \033[38;5;178m%-16s\033[0m %s\n" "backup" "💾 Manual backup"
    printf "   \033[38;5;178m%-16s\033[0m %s\n" "schedule" "📅 Auto backup"
    echo

    echo -e "\033[1;37m🔧 Config:\033[0m"
    printf "   \033[38;5;117m%-16s\033[0m %s\n" "edit" "📝 Edit compose"
    printf "   \033[38;5;117m%-16s\033[0m %s\n" "edit-env" "⚙️  Edit environment"
    printf "   \033[38;5;117m%-16s\033[0m %s\n" "edit-env-sub" "⚙️  Edit subscription environment"
    printf "   \033[38;5;117m%-16s\033[0m %s\n" "console" "🖥️  Shell access"
    echo

    if is_remnawave_installed && [ -f "$ENV_FILE" ]; then
        local panel_domain=$(grep "FRONT_END_DOMAIN=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs 2>/dev/null)
        if [ -n "$panel_domain" ] && [ "$panel_domain" != "null" ]; then
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 60))\033[0m"
            if [[ "$panel_domain" =~ ^https?:// ]]; then
                echo -e "\033[1;37m🌐 Panel Access:\033[0m \033[38;5;117m$panel_domain\033[0m"
            else
                echo -e "\033[1;37m🌐 Panel Access:\033[0m \033[38;5;117mhttps://$panel_domain\033[0m"
            fi
        fi
    fi
    echo
    echo -e "\033[38;5;8mUse '\033[38;5;15m$APP_NAME <command> help\033[38;5;8m' for details\033[0m"
    echo
    echo -e "\033[38;5;8m📚 \033[38;5;250mhttps://gig.ovh\033[38;5;8m | 💬 \033[38;5;250m@remnawave\033[38;5;8m | 👨‍💻 \033[38;5;250mDigneZzZ\033[0m"
}


show_version() {
    echo -e "\033[1;37m⚡ Remnawave Panel CLI\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
    echo -e "\033[38;5;250mVersion: \033[38;5;15m$SCRIPT_VERSION\033[0m"
    echo -e "\033[38;5;250mAuthor:  \033[38;5;15mDigneZzZ\033[0m"
    echo -e "\033[38;5;250mGitHub:  \033[38;5;15mhttps://github.com/DigneZzZ/remnawave-scripts\033[0m"
    echo -e "\033[38;5;250mProject: \033[38;5;15mhttps://gig.ovh\033[0m"
    echo -e "\033[38;5;250mCommunity: \033[38;5;15mhttps://openode.xyz\033[0m"
    echo -e "\033[38;5;250mSupport: \033[38;5;15mhttps://t.me/remnawave\033[0m"
    echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 40))\033[0m"
}


command_help() {
    local cmd="$1"
    
    case "$cmd" in
        install)
            echo -e "\033[1;37m📖 Install Command Help\033[0m"
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
            echo
            echo -e "\033[1;37mUsage:\033[0m"
            echo -e "   \033[38;5;15m$APP_NAME install [options]\033[0m"
            echo
            echo -e "\033[1;37mOptions:\033[0m"
            echo -e "   \033[38;5;15m--name <name>\033[0m    Custom installation name"
            echo -e "   \033[38;5;15m--dev\033[0m            Use development branch"
            echo
            echo -e "\033[1;37mExamples:\033[0m"
            echo -e "   \033[38;5;244m$APP_NAME install\033[0m"
            echo -e "   \033[38;5;244m$APP_NAME install --name mypanel\033[0m"
            echo -e "   \033[38;5;244m$APP_NAME install --dev\033[0m"
            ;;
        schedule)
            echo -e "\033[1;37m📖 Schedule Command Help\033[0m"
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
            echo
            echo -e "\033[1;37mUsage:\033[0m"
            echo -e "   \033[38;5;15m$APP_NAME schedule [action]\033[0m"
            echo
            echo -e "\033[1;37mActions:\033[0m"
            echo -e "   \033[38;5;15msetup\033[0m           Configure backup settings"
            echo -e "   \033[38;5;15menable\033[0m          Enable scheduler"
            echo -e "   \033[38;5;15mdisable\033[0m         Disable scheduler"
            echo -e "   \033[38;5;15mstatus\033[0m          Show scheduler status"
            echo -e "   \033[38;5;15mtest\033[0m            Test backup creation"
            echo -e "   \033[38;5;15mtest-telegram\033[0m   Test Telegram delivery"
            echo -e "   \033[38;5;15mrun\033[0m             Run backup now"
            echo -e "   \033[38;5;15mlogs\033[0m            View backup logs"
            echo -e "   \033[38;5;15mcleanup\033[0m         Clean old backups"
            echo
            echo -e "\033[1;37mFeatures:\033[0m"
            echo -e "   \033[38;5;250m• Automated database backups\033[0m"
            echo -e "   \033[38;5;250m• Telegram notifications with file splitting\033[0m"
            echo -e "   \033[38;5;250m• Configurable retention policies\033[0m"
            echo -e "   \033[38;5;250m• Compression options\033[0m"
            echo -e "   \033[38;5;250m• Thread support for group chats\033[0m"
            ;;

        backup)
            echo -e "\033[1;37m📖 Backup Command Help\033[0m"
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
            echo
            echo -e "\033[1;37mUsage:\033[0m"
            echo -e "   \033[38;5;15m$APP_NAME backup [options]\033[0m"
            echo
            echo -e "\033[1;37mOptions:\033[0m"
            echo -e "   \033[38;5;15m--compress\033[0m       Create compressed backup"
            echo -e "   \033[38;5;15m--output <dir>\033[0m   Specify output directory"
            echo
            echo -e "\033[1;37mNote:\033[0m"
            echo -e "   \033[38;5;250mFor automated backups with Telegram delivery,\033[0m"
            echo -e "   \033[38;5;250muse '\033[38;5;15m$APP_NAME schedule\033[38;5;250m' command instead.\033[0m"
            ;;
        monitor)
            echo -e "\033[1;37m📖 Monitor Command Help\033[0m"
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
            echo
            echo -e "\033[1;37mDescription:\033[0m"
            echo -e "   \033[38;5;250mReal-time system monitoring dashboard\033[0m"
            echo
            echo -e "\033[1;37mDisplays:\033[0m"
            echo -e "   \033[38;5;250m• CPU and Memory usage\033[0m"
            echo -e "   \033[38;5;250m• Docker container stats\033[0m"
            echo -e "   \033[38;5;250m• Network I/O\033[0m"
            echo -e "   \033[38;5;250m• Disk usage\033[0m"
            echo -e "   \033[38;5;250m• Service health status\033[0m"
            echo
            echo -e "\033[1;37mControls:\033[0m"
            echo -e "   \033[38;5;250mPress \033[38;5;15mCtrl+C\033[38;5;250m to exit\033[0m"
            ;;
        health)
            echo -e "\033[1;37m📖 Health Command Help\033[0m"
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
            echo
            echo -e "\033[1;37mDescription:\033[0m"
            echo -e "   \033[38;5;250mComprehensive system health diagnostics\033[0m"
            echo
            echo -e "\033[1;37mChecks:\033[0m"
            echo -e "   \033[38;5;250m• Service availability\033[0m"
            echo -e "   \033[38;5;250m• Database connectivity\033[0m"
            echo -e "   \033[38;5;250m• Port accessibility\033[0m"
            echo -e "   \033[38;5;250m• Resource usage\033[0m"
            echo -e "   \033[38;5;250m• Docker health\033[0m"
            echo -e "   \033[38;5;250m• Configuration validation\033[0m"
            ;;
        caddy)
            echo -e "\033[1;37m📖 Caddy Command Help\033[0m"
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 30))\033[0m"
            echo
            echo -e "\033[1;37mUsage:\033[0m"
            echo -e "   \033[38;5;15m$APP_NAME caddy [action]\033[0m"
            echo
            echo -e "\033[1;37mActions:\033[0m"
            echo -e "   \033[38;5;15mstatus\033[0m          Show Caddy status (default)"
            echo -e "   \033[38;5;15mup/start\033[0m        Start Caddy container"
            echo -e "   \033[38;5;15mdown/stop\033[0m       Stop Caddy container"
            echo -e "   \033[38;5;15mrestart\033[0m         Restart Caddy"
            echo -e "   \033[38;5;15mlogs\033[0m            View Caddy logs"
            echo -e "   \033[38;5;15medit\033[0m            Edit Caddyfile"
            echo -e "   \033[38;5;15mreset-user\033[0m      Reset admin password (Secure mode)"
            echo -e "   \033[38;5;15muninstall\033[0m       Remove Caddy"
            echo
            echo -e "\033[1;37mFeatures:\033[0m"
            echo -e "   \033[38;5;250m• Automatic SSL certificates (Let's Encrypt)\033[0m"
            echo -e "   \033[38;5;250m• Simple or Secure mode (with auth portal)\033[0m"
            echo -e "   \033[38;5;250m• Installed to /opt/caddy-remnawave/\033[0m"
            echo
            echo -e "\033[1;37mExamples:\033[0m"
            echo -e "   \033[38;5;244m$APP_NAME caddy\033[0m"
            echo -e "   \033[38;5;244m$APP_NAME caddy restart\033[0m"
            echo -e "   \033[38;5;244m$APP_NAME caddy logs\033[0m"
            echo -e "   \033[38;5;244m$APP_NAME caddy reset-user\033[0m"
            ;;
        *)
            echo -e "\033[1;37m📖 Command Help\033[0m"
            echo -e "\033[38;5;8m$(printf '─%.0s' $(seq 1 20))\033[0m"
            echo
            echo -e "\033[1;31mUnknown command: $cmd\033[0m"
            echo
            echo -e "\033[1;37mAvailable commands:\033[0m"
            echo -e "   \033[38;5;250minstall, update, uninstall, up, down, restart\033[0m"
            echo -e "   \033[38;5;250mstatus, logs, monitor, health, backup, schedule\033[0m"
            echo -e "   \033[38;5;250medit, edit-env, console, pm2-monitor, caddy\033[0m"
            echo
            echo -e "\033[38;5;8mUse '\033[38;5;15m$APP_NAME help\033[38;5;8m' for full usage\033[0m"
            ;;
    esac
}

smart_usage() {
    if [ "$1" = "help" ] && [ -n "$2" ]; then
        command_help "$2"
        return
    fi
    
    local terminal_width=$(tput cols 2>/dev/null || echo "80")
    local terminal_height=$(tput lines 2>/dev/null || echo "24")
    
    if [ "$terminal_width" -lt 50 ]; then
        usage_minimal
    elif [ "$terminal_width" -lt 80 ] || [ "$terminal_height" -lt 35 ]; then
        usage_compact
    else
        usage
    fi
}



case "$COMMAND" in
    install) install_command ;;
    install-subpage) install_subpage_command "$@" ;;
    install-subpage-standalone) install_subpage_standalone_command "$@" ;;
    update) 
        if is_subpage_standalone; then
            standalone_update_command
        else
            update_command
        fi
        ;;
    uninstall) 
        if is_subpage_standalone; then
            standalone_uninstall_command
        else
            uninstall_command
        fi
        ;;
    up) 
        if is_subpage_standalone; then
            standalone_up_command
        else
            up_command
        fi
        ;;
    down) 
        if is_subpage_standalone; then
            standalone_down_command
        else
            down_command
        fi
        ;;
    restart) 
        if is_subpage_standalone; then
            standalone_restart_command
        else
            restart_command
        fi
        ;;
    status) 
        if is_subpage_standalone; then
            standalone_status_command
        else
            status_command
        fi
        ;;
    logs) 
        if is_subpage_standalone; then
            standalone_logs_command
        else
            logs_command
        fi
        ;;
    monitor) monitor_command ;;
    health) health_check_command ;;
    schedule) schedule_command "$@" ;;
    install-script) install_remnawave_script ;;
    uninstall-script) uninstall_remnawave_script ;;
    update-script) update_remnawave_script ;;
    edit) edit_command ;;
    edit-env) edit_env_command ;;
    edit-env-sub) 
        if is_subpage_standalone; then
            standalone_edit_env
        else
            edit_env_sub_command
        fi
        ;;
    console) console_command ;;
    pm2-monitor) pm2_monitor ;;
    backup) backup_command "$@" ;;
    restore) restore_command "$@" ;;
    subpage) subpage_command ;;
    subpage-restart) subpage_restart_command ;;
    subpage-token) subpage_configure_token ;;
    caddy) 
        if is_subpage_standalone; then
            caddy_standalone_command
        else
            caddy_command "$1"
        fi
        ;;
    caddy-standalone) caddy_standalone_command ;;
    menu) 
        if is_subpage_standalone; then
            standalone_subpage_menu
        else
            main_menu
        fi
        ;;  
    help) smart_usage "help" "$1" ;;
    --version|-v) show_version ;;
    --help|-h) smart_usage ;;
    "") 
        if is_subpage_standalone; then
            standalone_subpage_menu
        else
            main_menu
        fi
        ;;    
    *) smart_usage ;;
esac
