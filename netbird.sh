#!/usr/bin/env bash
# ╔════════════════════════════════════════════════════════════════╗
# ║  NetBird Installer - mesh VPN для Linux-серверов                ║
# ║  Режимы: CLI · init (cloud-init) · menu · ansible               ║
# ║                                                                 ║
# ║  Project: remnawave-scripts (gig.ovh)                           ║
# ║  Author:  DigneZzZ (https://github.com/DigneZzZ)                ║
# ║  License: MIT                                                   ║
# ╚════════════════════════════════════════════════════════════════╝
# VERSION=2.0.0
set -Eeuo pipefail

SCRIPT_VERSION="2.0.0"

# Пропуск префиксного @ (консистентно с другими скриптами репозитория)
if [ $# -gt 0 ] && [ "$1" = "@" ]; then
    shift
fi

# ==================== Константы ====================

readonly NETBIRD_INSTALL_URL="https://pkgs.netbird.io/install.sh"
readonly NETBIRD_WG_PORT_DEFAULT=51820
readonly NETBIRD_LOCK_FILE="/var/run/netbird-installer.lock"
readonly GITHUB_LATEST_API="https://api.github.com/repos/netbirdio/netbird/releases/latest"
# Каталоги, удаляемые при --purge
readonly -a NETBIRD_CONFIG_DIRS=(
    "/etc/netbird"
    "/etc/wiretrustee"
    "/var/lib/netbird"
    "/var/log/netbird"
)

# ==================== Опции / состояние ====================

RUN_MODE="cli"          # cli | init | menu | ansible
COMMAND=""              # install | update | connect | disconnect | status | uninstall | help
QUIET_MODE=false        # минимум вывода
FORCE_MODE=false        # авто-подтверждение всех запросов
ENABLE_SSH=false        # SSH-доступ между пирами
SKIP_FIREWALL=false     # не трогать файрвол
PURGE_CONFIG=false      # удалить конфиги при uninstall
SETUP_KEY="${NETBIRD_SETUP_KEY:-}"
MANAGEMENT_URL="${NETBIRD_MANAGEMENT_URL:-}"
HOSTNAME_NAME=""
WG_PORT=0               # 0 = использовать значение netbird по умолчанию (51820)
LOG_FILE=""

OS=""
PACKAGE_MGR=""

# ==================== Цвета / вывод ====================

RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''

setup_colors() {
    # Отключаем цвета: NO_COLOR, TERM=dumb, вывод не в TTY
    if [[ -n ${NO_COLOR:-} ]] || [[ ${TERM:-} == "dumb" ]] || [[ ! -t 1 ]]; then
        return
    fi
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
}

print_banner() {
    [[ "$QUIET_MODE" == "true" ]] && return
    local width=59
    local title="NetBird Installer"
    local version="Version ${SCRIPT_VERSION}"
    local bars="" pad line
    for ((i = 0; i < width; i++)); do bars+="═"; done
    printf "${CYAN}╔%s╗\n" "$bars"
    for line in "$title" "$version"; do
        pad=$(((width - ${#line}) / 2))
        printf '║%*s%s%*s║\n' "$pad" '' "$line" "$((width - pad - ${#line}))" ''
    done
    printf "╚%s╝${NC}\n" "$bars"
}

print_success() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "${GREEN}✓ $1${NC}"
    log_message "OK: $1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
    log_message "ERROR: $1"
}

print_info() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "${BLUE}ℹ $1${NC}"
    log_message "INFO: $1"
}

print_warning() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "${YELLOW}⚠ $1${NC}"
    log_message "WARN: $1"
}

log_message() {
    [[ -z "$LOG_FILE" ]] && return
    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; } 2>/dev/null || true
}

show_version() {
    echo "NetBird Installer v${SCRIPT_VERSION}"
    echo "https://github.com/DigneZzZ/remnawave-scripts"
}

# Обработчик неожидаемых ошибок (set -Eeuo pipefail)
error_handler() {
    local exit_code=$1 line=$2 command=$3
    print_error "Команда '$command' завершилась с кодом $exit_code (строка $line)"
    echo -e "${YELLOW}Подробнее: bash -x $0 ...  или  --log FILE${NC}" >&2
    exit "$exit_code"
}
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

# ==================== Интерактивные помощники ====================

# read с защитой от EOF: неинтерактивные окружения не роняют скрипт,
# но пайп-ввод (menu < file) по-прежнему читается
prompt_read() {
    local __var=$1 __prompt=$2 __default=$3 __ans=""
    read -r -p "$__prompt" __ans || __ans=""
    printf -v "$__var" '%s' "${__ans:-$__default}"
}

# Подтверждение (по умолчанию — Нет). Неинтерактивно -> Нет.
confirm_action() {
    local ans=""
    if [[ ! -t 0 ]]; then
        return 1
    fi
    read -r -p "$1 (y/N): " ans || ans=""
    [[ "$ans" =~ ^[Yy]$ ]]
}

pause_if_interactive() {
    [[ -t 0 ]] || return 0
    local _
    read -r -p "Нажмите Enter для продолжения..." _ || true
}

acquire_lock() {
    command -v flock &>/dev/null || return 0
    exec 9>"$NETBIRD_LOCK_FILE"
    if ! flock -n 9; then
        print_error "Другой экземпляр установщика уже запущен ($NETBIRD_LOCK_FILE)"
        exit 1
    fi
}

# ==================== Проверки окружения ====================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен быть запущен с правами root"
        echo "Используйте: sudo $0 ${1:-$COMMAND}" >&2
        exit 1
    fi
}

detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Не удалось определить операционную систему (/etc/os-release отсутствует)"
        exit 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    OS="${ID:-}"
    local pretty="${PRETTY_NAME:-$OS}"
    case "$OS" in
        ubuntu|debian)
            PACKAGE_MGR="apt"
            ;;
        centos|rhel|fedora|rocky|alma|amzn)
            if command -v dnf &>/dev/null; then
                PACKAGE_MGR="dnf"
            else
                PACKAGE_MGR="yum"
            fi
            ;;
        *)
            # Fallback на ID_LIKE (например, ID=amzn -> "rhel fedora")
            case " ${ID_LIKE:-} " in
                *" debian "*|*" ubuntu "*)
                    OS="debian"
                    PACKAGE_MGR="apt"
                    ;;
                *" rhel "*|*" fedora "*|*" centos "*)
                    OS="rhel"
                    if command -v dnf &>/dev/null; then
                        PACKAGE_MGR="dnf"
                    else
                        PACKAGE_MGR="yum"
                    fi
                    ;;
                *)
                    PACKAGE_MGR=""
                    ;;
            esac
            ;;
    esac
    print_info "Обнаружена ОС: $pretty (архитектура: $(uname -m))"
    if [[ -z "$PACKAGE_MGR" ]]; then
        print_warning "Неизвестный менеджер пакетов — установка может не сработать"
    fi
}

check_dependencies() {
    local -a required=(curl)
    local -a missing=()
    local cmd
    for cmd in "${required[@]}"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "Отсутствуют: ${missing[*]}. Будут установлены..."
    fi
}

install_dependencies() {
    print_info "Установка зависимостей..."
    case "$PACKAGE_MGR" in
        apt)
            apt-get update -qq
            apt-get install -y -qq ca-certificates curl gnupg >/dev/null
            ;;
        dnf)
            dnf install -y -q ca-certificates curl gnupg >/dev/null
            ;;
        yum)
            yum install -y -q ca-certificates curl gnupg >/dev/null
            ;;
        *)
            print_warning "Неизвестная ОС, попытка продолжить без установки зависимостей..."
            return 0
            ;;
    esac
    print_success "Зависимости установлены"
}

# TUN-устройство нужен для WireGuard. Пробуем восстановить автоматически.
check_tun_device() {
    if [[ -c /dev/net/tun ]]; then
        return 0
    fi

    print_warning "TUN-устройство (/dev/net/tun) не найдено, пробую восстановить..."

    # Загружаем модуль ядра (если есть modprobe)
    if command -v modprobe &>/dev/null; then
        modprobe tun 2>/dev/null || true
    fi

    # Создаём устройство вручную
    if [[ ! -c /dev/net/tun && -d /dev/net ]]; then
        mknod /dev/net/tun c 10 200 2>/dev/null || true
        chmod 600 /dev/net/tun 2>/dev/null || true
    elif [[ ! -d /dev/net ]]; then
        mkdir -p /dev/net 2>/dev/null || true
        mknod /dev/net/tun c 10 200 2>/dev/null || true
        chmod 600 /dev/net/tun 2>/dev/null || true
    fi

    if [[ -c /dev/net/tun ]]; then
        print_success "TUN-устройство восстановлено"
        return 0
    fi

    print_error "TUN-устройство (/dev/net/tun) не найдено!"
    print_error "NetBird требует TUN для работы WireGuard."
    echo ""
    echo -e "${YELLOW}Возможные решения:${NC}"
    echo "  1. Если это VPS/контейнер — включите TUN в панели управления"
    echo "  2. Для OpenVZ/LXC контейнеров попросите хостера включить TUN"
    echo "  3. На обычном сервере выполните:"
    echo "     mkdir -p /dev/net && mknod /dev/net/tun c 10 200 && chmod 600 /dev/net/tun"
    echo "  4. Загрузите модуль ядра: modprobe tun"
    echo ""
    exit 3
}

# ==================== Состояние NetBird ====================

is_netbird_installed() {
    command -v netbird &>/dev/null
}

get_installed_version() {
    netbird version 2>/dev/null | head -n1 | tr -d '[:space:]' || echo ""
}

# Последняя версия с GitHub API (best-effort, не критично при ошибке)
get_latest_version() {
    local tag=""
    # без `head`: раннее закрытие пайпа даёт SIGPIPE под pipefail
    tag=$(curl -fsSL --connect-timeout 10 --max-time 20 \
        -H "Accept: application/vnd.github+json" \
        "$GITHUB_LATEST_API" 2>/dev/null \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p') || tag=""
    echo "${tag#v}"
}

# Полный вывод статуса (один вызов на проверку)
get_status_output() {
    netbird status 2>/dev/null || true
}

is_netbird_connected() {
    local out
    out=$(get_status_output)
    # Современный формат: "Management: Connected"; старый: строка "Connected"
    grep -qE '^Management:[[:space:]]*Connected' <<<"$out" || grep -qx 'Connected' <<<"$out"
}

# NetBird IP локального пира (устойчиво к смене формата вывода)
get_netbird_ip() {
    local ip=""
    # Современные версии: только IPv4 одним значением
    ip=$(netbird status --ipv4 2>/dev/null | head -n1 | tr -d '[:space:]') || ip=""
    if [[ -z "$ip" || ! "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        # Fallback: парсинг полного статуса
        ip=$(get_status_output | sed -n 's/^NetBird IP:[[:space:]]*//p' | head -n1)
        ip="${ip%%/*}"
        ip="${ip//[[:space:]]/}"
    fi
    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || ip=""
    echo "$ip"
}

# ==================== Файрвол ====================

# Порт WireGuard, который открываем в файрволе
effective_firewall_port() {
    if [[ "$WG_PORT" -gt 0 ]]; then
        echo "$WG_PORT"
    else
        echo "$NETBIRD_WG_PORT_DEFAULT"
    fi
}

open_ufw_port() {
    local port=$1
    if ufw allow "$port/udp" >/dev/null 2>&1; then
        print_success "Порт $port/udp открыт в UFW"
    else
        print_error "Не удалось открыть порт $port/udp в UFW"
    fi
}

open_firewalld_port() {
    local port=$1
    if firewall-cmd --permanent --add-port="$port/udp" >/dev/null 2>&1 && \
       firewall-cmd --reload >/dev/null 2>&1; then
        print_success "Порт $port/udp открыт в firewalld"
    else
        print_error "Не удалось открыть порт $port/udp в firewalld"
    fi
}

# Общий сценарий: проверить -> открыть (интерактивно или автоматически)
ensure_firewall_port() {
    local fw=$1          # ufw | firewalld
    local port=$2
    local auto_open=false
    [[ "$QUIET_MODE" == "true" || "$FORCE_MODE" == "true" || ! -t 0 ]] && auto_open=true

    local already_open=false
    if [[ "$fw" == "ufw" ]]; then
        ufw status 2>/dev/null | grep -q "$port/udp" && already_open=true
    else
        firewall-cmd --list-ports 2>/dev/null | grep -q "$port/udp" && already_open=true
    fi

    if [[ "$already_open" == "true" ]]; then
        print_success "Порт $port/udp уже открыт в $fw"
        return 0
    fi

    print_warning "Порт $port/udp не открыт в $fw"

    if [[ "$auto_open" == "true" ]]; then
        if [[ "$fw" == "ufw" ]]; then
            open_ufw_port "$port"
        else
            open_firewalld_port "$port"
        fi
        return 0
    fi

    local answer=""
    prompt_read answer "Открыть порт $port/udp в $fw? (Y/n): " "y"
    if [[ ! "$answer" =~ ^[Nn]$ ]]; then
        if [[ "$fw" == "ufw" ]]; then
            open_ufw_port "$port"
        else
            open_firewalld_port "$port"
        fi
    else
        print_warning "Порт не открыт. NetBird может работать хуже (relay вместо P2P)"
    fi
}

check_firewall() {
    [[ "$SKIP_FIREWALL" == "true" ]] && return 0

    local port
    port=$(effective_firewall_port)

    if command -v ufw &>/dev/null; then
        if ufw status 2>/dev/null | head -n1 | grep -q "active"; then
            print_info "UFW активен, проверяю порт $port/udp..."
            ensure_firewall_port "ufw" "$port"
        else
            print_info "UFW не активен, пропускаю настройку файрвола"
        fi
    elif command -v firewall-cmd &>/dev/null; then
        if systemctl is-active --quiet firewalld 2>/dev/null; then
            print_info "Firewalld активен, проверяю порт $port/udp..."
            ensure_firewall_port "firewalld" "$port"
        fi
    fi
}

# ==================== Установка / удаление ====================

# Запуск официального установщика
run_official_installer() {
    curl -fsSL --connect-timeout 15 "$NETBIRD_INSTALL_URL" | sh
}

# Удаление пакета (только бинарник, конфиги не трогаем)
remove_netbird_package() {
    case "$PACKAGE_MGR" in
        apt)
            # netbird-ui существует только на десктопах — удаляем при наличии
            if dpkg -s netbird-ui &>/dev/null; then
                apt-get remove -y netbird netbird-ui >/dev/null 2>&1 || apt-get remove -y netbird >/dev/null 2>&1
            else
                apt-get remove -y netbird >/dev/null 2>&1
            fi
            apt-get autoremove -y >/dev/null 2>&1 || true
            ;;
        dnf)
            dnf remove -y netbird >/dev/null 2>&1 || true
            ;;
        yum)
            yum remove -y netbird >/dev/null 2>&1 || true
            ;;
        *)
            print_warning "Не удалось удалить пакет: неизвестный менеджер пакетов"
            return 1
            ;;
    esac
    # Официальный установщик требует чистого состояния
    is_netbird_installed || return 0
    print_warning "Пакет всё ещё установлен после удаления"
    return 1
}

install_netbird() {
    # Уже установлен?
    if is_netbird_installed; then
        local current_version
        current_version=$(get_installed_version)
        print_warning "NetBird уже установлен (версия: ${current_version:-unknown})"

        local reinstall=""
        if [[ "$FORCE_MODE" == "true" || "$QUIET_MODE" == "true" ]]; then
            reinstall="n"
            if [[ "$FORCE_MODE" == "true" ]]; then
                reinstall="y"
            fi
        else
            prompt_read reinstall "Переустановить? (y/N): " "n"
        fi
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            print_info "Пропускаю установку, используется существующий NetBird"
            return 0
        fi
        # Официальный установщик отказывается работать при установленном netbird
        print_info "Удаляю текущий пакет перед переустановкой (конфиги сохраняются)..."
        netbird down >/dev/null 2>&1 || true
        netbird service stop >/dev/null 2>&1 || true
        remove_netbird_package || {
            print_error "Не удалось удалить текущий пакет"
            exit 4
        }
    fi

    print_info "Установка NetBird..."
    if ! run_official_installer; then
        print_error "Ошибка при установке NetBird"
        exit 4
    fi

    if ! is_netbird_installed; then
        print_error "Установщик завершился, но netbird не найден в PATH"
        exit 4
    fi

    print_success "NetBird успешно установлен (версия: $(get_installed_version))"
}

# Лучший effort по запуску daemon-сервиса после установки/обновления
ensure_service_running() {
    if netbird status >/dev/null 2>&1; then
        return 0
    fi
    print_info "Запускаю сервис netbird..."
    if command -v systemctl &>/dev/null && systemctl list-unit-files 2>/dev/null | grep -q '^netbird'; then
        systemctl enable --now netbird >/dev/null 2>&1 || true
    fi
    if ! netbird status >/dev/null 2>&1; then
        # Fallback для установок без systemd-юнита (binary install)
        netbird service install >/dev/null 2>&1 || true
        netbird service start >/dev/null 2>&1 || true
    fi
    if netbird status >/dev/null 2>&1; then
        print_success "Сервис netbird запущен"
    else
        print_warning "Не удалось проверить сервис. Попробуйте: netbird service start"
        return 1
    fi
}

uninstall_netbird() {
    print_warning "Удаление NetBird..."

    netbird down >/dev/null 2>&1 || true
    netbird service stop >/dev/null 2>&1 || true

    remove_netbird_package || print_warning "Пакет мог не удалиться полностью"

    if [[ "$PURGE_CONFIG" == "true" ]]; then
        local dir
        for dir in "${NETBIRD_CONFIG_DIRS[@]}"; do
            if [[ -e "$dir" ]]; then
                rm -rf "$dir"
                print_info "Удалён $dir"
            fi
        done
    fi

    print_success "NetBird удален"
}

# ==================== Подключение ====================

validate_setup_key_format() {
    local key="$1"
    if [[ ! "$key" =~ ^[A-Za-z0-9]{8}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{12}$ ]] && \
       [[ ! "$key" =~ ^[A-Za-z0-9-]{20,}$ ]]; then
        print_warning "Формат setup-key выглядит необычно. Продолжаю..."
    fi
}

# Единая точка запуска netbird up.
# Ключ передаётся через переменные окружения (NB_/WT_ поддерживаются самим netbird),
# чтобы он не попадал в argv и не был виден в `ps` другим пользователям.
run_netbird_up() {
    local setup_key=$1
    local -a args=(up)

    [[ -n "$MANAGEMENT_URL" ]] && args+=(--management-url "$MANAGEMENT_URL")
    [[ -n "$HOSTNAME_NAME" ]] && args+=(--hostname "$HOSTNAME_NAME")
    [[ "$WG_PORT" -gt 0 ]] && args+=(--wireguard-port "$WG_PORT")
    [[ "$ENABLE_SSH" == "true" ]] && args+=(--allow-server-ssh --enable-ssh-root)

    if [[ -n "$setup_key" ]]; then
        NB_SETUP_KEY="$setup_key" WT_SETUP_KEY="$setup_key" netbird "${args[@]}"
    else
        netbird "${args[@]}"
    fi
}

verify_connection() {
    print_info "Проверка подключения..."
    local retries=6
    local wait_time=5

    local i out
    for ((i = 1; i <= retries; i++)); do
        if is_netbird_connected; then
            print_success "NetBird успешно подключен!"
            local peer_ip
            peer_ip=$(get_netbird_ip)
            if [[ -n "$peer_ip" ]]; then
                print_info "NetBird IP: $peer_ip"
            fi
            return 0
        fi
        sleep "$wait_time"
    done

    print_warning "Подключение еще устанавливается. Проверьте 'netbird status' позже."
    return 1
}

connect_netbird() {
    local setup_key=$1

    check_tun_device

    if [[ -n "$setup_key" ]]; then
        validate_setup_key_format "$setup_key"
    fi

    if ! ensure_service_running; then
        print_error "NetBird daemon не отвечает"
        exit 5
    fi

    if [[ "$ENABLE_SSH" == "true" ]]; then
        print_info "Включен SSH доступ между серверами"
    fi
    print_info "Подключение к NetBird..."

    if run_netbird_up "$setup_key"; then
        # Отрицательный результат верификации не считается ошибкой установки:
        # управление уже зарегистрировано, соединение может догружаться
        verify_connection || true
        return 0
    fi

    print_error "Ошибка при подключении к NetBird"
    exit 5
}

# ==================== Команды (общие для всех режимов) ====================

require_setup_key() {
    if [[ -z "$SETUP_KEY" ]]; then
        print_error "Setup key обязателен!"
        echo ""
        echo "Используйте: $0 $COMMAND --key YOUR-SETUP-KEY"
        echo "Или: NETBIRD_SETUP_KEY=KEY $0 $COMMAND"
        exit 2
    fi
}

cmd_install() {
    require_setup_key
    check_root
    detect_os
    acquire_lock
    check_dependencies
    install_dependencies
    check_firewall
    install_netbird
    connect_netbird "$SETUP_KEY"
}

cmd_update() {
    check_root
    detect_os
    acquire_lock

    if ! is_netbird_installed; then
        print_error "NetBird не установлен. Используйте 'install' для установки."
        exit 1
    fi

    local current_version latest_version
    current_version=$(get_installed_version)
    print_info "Текущая версия: ${current_version:-unknown}"

    latest_version=$(get_latest_version)
    if [[ -n "$current_version" && -n "$latest_version" && "$current_version" == "$latest_version" ]]; then
        print_success "Установлена последняя версия ($current_version). Обновление не требуется"
        return 0
    fi
    if [[ -n "$latest_version" ]]; then
        print_info "Доступна версия: $latest_version"
    else
        print_info "Не удалось проверить последнюю версию (GitHub API), обновляюсь через репозиторий"
    fi

    print_info "Обновление NetBird..."

    # Официальный установщик отказывается работать при запущенном netbird
    netbird down >/dev/null 2>&1 || true
    netbird service stop >/dev/null 2>&1 || true

    if ! run_official_installer; then
        # Установщик мог отклонить обновление ("already installed") —
        # переустанавливаем пакет напрямую, конфиги в /etc/netbird сохраняются
        print_warning "Установщик отклонил обновление — переустановка пакета (конфиги сохраняются)..."
        remove_netbird_package || {
            print_error "Не удалось удалить текущий пакет"
            exit 4
        }
        if ! run_official_installer; then
            print_error "Ошибка при обновлении NetBird"
            exit 4
        fi
    fi

    if ! is_netbird_installed; then
        print_error "NetBird отсутствует после обновления"
        exit 4
    fi

    local new_version
    new_version=$(get_installed_version)
    print_success "NetBird обновлен до версии: ${new_version:-unknown}"

    # Восстанавливаем подключение (peer уже зарегистрирован, ключ не обязателен)
    ensure_service_running || true
    if [[ -n "$SETUP_KEY" ]]; then
        connect_netbird "$SETUP_KEY"
    else
        print_info "Восстанавливаю подключение..."
        if netbird up; then
            verify_connection || true
        else
            print_warning "Не удалось автоматически переподключиться. Выполните: netbird up --setup-key KEY"
        fi
    fi
}

cmd_connect() {
    require_setup_key
    check_root
    if ! is_netbird_installed; then
        print_error "NetBird не установлен. Используйте 'install' для установки."
        exit 1
    fi
    connect_netbird "$SETUP_KEY"
}

cmd_disconnect() {
    check_root
    if ! is_netbird_installed; then
        print_error "NetBird не установлен"
        exit 1
    fi
    print_info "Отключение от NetBird..."
    netbird down
    print_success "Отключено"
}

cmd_status() {
    if ! is_netbird_installed; then
        print_warning "NetBird не установлен"
        exit 1
    fi
    print_info "Текущий статус NetBird:"
    get_status_output
    # Код возврата: 0 — подключен, 1 — нет (удобно для мониторинга/Ansible)
    if is_netbird_connected; then
        return 0
    fi
    return 1
}

cmd_uninstall() {
    check_root
    detect_os
    acquire_lock
    if ! is_netbird_installed; then
        print_info "NetBird не установлен — нечего удалять"
        return 0
    fi
    uninstall_netbird
}

# ==================== Справка ====================

show_help() {
    print_banner
    echo "Использование: $0 [режим] [команда] [опции]"
    echo ""
    echo "Режимы запуска:"
    echo "  init --key KEY         Автоустановка для cloud-init/provisioning (тихий режим)"
    echo "  menu                   Интерактивное меню"
    echo "  ansible <command>      Режим для Ansible (без цветов, минимум вывода)"
    echo "  (по умолчанию)         CLI режим с командами"
    echo ""
    echo "Команды:"
    echo "  install --key KEY      Установить и подключить NetBird (ключ обязателен!)"
    echo "  update                 Обновить NetBird до последней версии"
    echo "  connect --key KEY      Подключить существующий NetBird к сети"
    echo "  disconnect             Отключиться от сети NetBird"
    echo "  status                 Показать статус (код 0 = подключен, 1 = нет)"
    echo "  uninstall [--purge]    Удалить NetBird (--purge — вместе с конфигами)"
    echo "  help                   Показать эту справку"
    echo ""
    echo "Опции:"
    echo "  --key, -k KEY          Setup key (или env NETBIRD_SETUP_KEY)"
    echo "  --management-url URL   Self-hosted Management URL (или env NETBIRD_MANAGEMENT_URL)"
    echo "  --hostname NAME        Имя пира в сети NetBird"
    echo "  --port, -p PORT        WireGuard порт (по умолчанию $NETBIRD_WG_PORT_DEFAULT)"
    echo "  --ssh                  Включить SSH доступ между серверами"
    echo "  --no-firewall          Не настраивать файрвол (UFW/firewalld)"
    echo "  --purge                При uninstall удалить конфиги (/etc/netbird и др.)"
    echo "  --force, -f            Автоматически принимать все запросы"
    echo "  --quiet, -q            Тихий режим (минимум вывода)"
    echo "  --log FILE             Записывать лог в файл"
    echo "  --version, -v          Показать версию скрипта"
    echo "  --help, -h             Показать эту справку"
    echo ""
    echo "Переменные окружения:"
    echo "  NETBIRD_SETUP_KEY          Setup key (альтернатива --key)"
    echo "  NETBIRD_MANAGEMENT_URL     Management URL для self-hosted"
    echo ""
    echo "Коды возврата: 0 — успех; 1 — общая ошибка; 2 — неверные аргументы;"
    echo "               3 — нет TUN; 4 — ошибка установки; 5 — ошибка подключения"
    echo ""
    echo "Примеры:"
    echo "  $0 install --key YOUR-KEY                    # Установка (SaaS)"
    echo "  $0 install --key YOUR-KEY --ssh -f           # Установка с SSH и auto-accept"
    echo "  $0 install --key YOUR-KEY -m https://nb.example.com:443   # Self-hosted"
    echo "  $0 install --key YOUR-KEY --hostname web-01  # С указанием имени пира"
    echo "  $0 update                                    # Обновление"
    echo "  $0 init --key YOUR-KEY --ssh                 # Cloud-init"
    echo "  $0 menu                                      # Интерактивное меню"
    echo "  $0 uninstall --purge                         # Удаление с конфигами"
    echo ""
    echo "Cloud-init / user-data:"
    echo "  bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key YOUR-KEY --ssh"
    echo ""
}

# ==================== Разбор аргументов ====================

usage_error() {
    print_error "$1"
    echo "Используйте: $0 --help" >&2
    exit 2
}

validate_port() {
    local value=$1
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        usage_error "Порт должен быть числом: $value"
    fi
    local -i port=$((10#$value))
    if ((port < 1 || port > 65535)); then
        usage_error "Порт вне диапазона 1-65535: $value"
    fi
    WG_PORT=$port
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            # Режимы запуска
            init)
                RUN_MODE="init"
                QUIET_MODE=true
                FORCE_MODE=true
                shift
                ;;
            menu)
                RUN_MODE="menu"
                shift
                ;;
            ansible)
                RUN_MODE="ansible"
                QUIET_MODE=true
                shift
                ;;
            # Команды
            install|update|connect|disconnect|status|uninstall|help)
                if [[ -n "$COMMAND" ]]; then
                    usage_error "Лишний аргумент: $1 (команда уже выбрана: $COMMAND)"
                fi
                COMMAND="$1"
                shift
                ;;
            # Опции
            --key|-k)
                [[ $# -lt 2 || -z "$2" ]] && usage_error "--key требует значение"
                SETUP_KEY="$2"
                shift 2
                ;;
            --management-url|-m)
                [[ $# -lt 2 || -z "$2" ]] && usage_error "--management-url требует значение"
                MANAGEMENT_URL="$2"
                shift 2
                ;;
            --hostname)
                [[ $# -lt 2 || -z "$2" ]] && usage_error "--hostname требует значение"
                HOSTNAME_NAME="$2"
                shift 2
                ;;
            --port|-p)
                [[ $# -lt 2 || -z "$2" ]] && usage_error "--port требует значение"
                validate_port "$2"
                shift 2
                ;;
            --ssh)
                ENABLE_SSH=true
                shift
                ;;
            --no-firewall)
                SKIP_FIREWALL=true
                shift
                ;;
            --purge)
                PURGE_CONFIG=true
                shift
                ;;
            --force|-f)
                FORCE_MODE=true
                shift
                ;;
            --quiet|-q)
                QUIET_MODE=true
                shift
                ;;
            --log)
                [[ $# -lt 2 || -z "$2" ]] && usage_error "--log требует значение"
                LOG_FILE="$2"
                shift 2
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            --help|-h)
                COMMAND="help"
                shift
                ;;
            *)
                usage_error "Неизвестный аргумент: $1"
                ;;
        esac
    done

    case "$RUN_MODE" in
        init)
            # init без команды = install
            if [[ -z "$COMMAND" ]]; then
                COMMAND="install"
            fi
            ;;
        ansible)
            if [[ -z "$COMMAND" ]]; then
                usage_error "Режиму ansible требуется команда: install|update|connect|disconnect|status|uninstall"
            fi
            ;;
        *)
            if [[ -z "$COMMAND" ]]; then
                COMMAND="help"
            fi
            ;;
    esac
}

# Инициализация окружения после разбора аргументов
init_environment() {
    setup_colors
    if [[ "$RUN_MODE" == "ansible" ]]; then
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
    fi
    if [[ -n "$LOG_FILE" ]]; then
        if ! touch "$LOG_FILE" 2>/dev/null; then
            print_error "Не удалось открыть лог-файл для записи: $LOG_FILE"
            exit 2
        fi
        log_message "=== NetBird Installer v$SCRIPT_VERSION (mode=$RUN_MODE cmd=$COMMAND) ==="
    fi
}

# ==================== Интерактивное меню ====================

prompt_setup_key() {
    if [[ -n "$SETUP_KEY" ]]; then
        echo -e "${BLUE}Текущий setup-key:${NC} ${SETUP_KEY:0:8}...${SETUP_KEY: -8}"
        echo ""
        local new_key=""
        prompt_read new_key "Введите новый setup-key (или Enter для использования текущего): " "$SETUP_KEY"
        SETUP_KEY="$new_key"
    else
        while [[ -z "$SETUP_KEY" ]]; do
            prompt_read SETUP_KEY "Введите setup-key: " ""
            if [[ -z "$SETUP_KEY" ]]; then
                print_error "Setup key обязателен!"
            fi
        done
    fi
}

show_menu() {
    clear
    print_banner
    echo -e "${CYAN}Выберите действие:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Установить NetBird"
    echo -e "  ${GREEN}2)${NC} Обновить NetBird"
    echo -e "  ${GREEN}3)${NC} Подключить к сети"
    echo -e "  ${GREEN}4)${NC} Отключить от сети"
    echo -e "  ${GREEN}5)${NC} Показать статус"
    echo -e "  ${GREEN}6)${NC} Удалить NetBird"
    echo -e "  ${RED}0)${NC} Выход"
    echo ""
}

run_interactive_menu() {
    check_root "menu"
    detect_os

    while true; do
        show_menu
        local choice=""
        prompt_read choice "Ваш выбор [0-6]: " ""
        echo ""

        case $choice in
            1)
                prompt_setup_key
                echo ""
                # подоболочка: ошибка установки не должна убивать меню
                if ( cmd_install ); then
                    echo ""
                    pause_if_interactive
                else
                    print_error "Установка не удалась (код $?)"
                    pause_if_interactive
                fi
                ;;
            2)
                ( cmd_update ) || print_warning "Обновление завершилось с ошибкой"
                echo ""
                pause_if_interactive
                ;;
            3)
                prompt_setup_key
                echo ""
                if ( cmd_connect ); then
                    echo ""
                else
                    print_error "Подключение не удалось (код $?)"
                fi
                pause_if_interactive
                ;;
            4)
                ( cmd_disconnect ) || print_warning "Отключение не удалось"
                echo ""
                pause_if_interactive
                ;;
            5)
                ( cmd_status ) || print_warning "NetBird не подключен"
                echo ""
                pause_if_interactive
                ;;
            6)
                if confirm_action "Вы уверены, что хотите удалить NetBird?"; then
                    local purge=""
                    prompt_read purge "Удалить также конфиги (/etc/netbird)? (y/N): " "n"
                    if [[ "$purge" =~ ^[Yy]$ ]]; then
                        PURGE_CONFIG=true
                    fi
                    ( cmd_uninstall ) || print_warning "Удаление завершилось с ошибкой"
                fi
                echo ""
                pause_if_interactive
                ;;
            0)
                echo -e "${GREEN}До свидания!${NC}"
                exit 0
                ;;
            *)
                print_error "Неверный выбор"
                sleep 1
                ;;
        esac
    done
}

# ==================== Режим init (cloud-init / provisioning) ====================

run_init_mode() {
    if [[ -z "$SETUP_KEY" ]]; then
        echo "FAILED: Setup key is required for init mode" >&2
        echo "Usage: $0 init --key YOUR-SETUP-KEY" >&2
        exit 2
    fi

    # Тихий авто-install: FORCE/QUIET уже установлены в parse_args.
    # Подоболочка ловит exit-коды cmd_install, чтобы вывести FAILED и вернуть
    # корректный код в cloud-init.
    local rc=0
    ( cmd_install ) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "OK: NetBird installed and connected"
        exit 0
    fi
    echo "FAILED: NetBird installation failed (code $rc)" >&2
    exit "$rc"
}

# ==================== Режим Ansible ====================

run_ansible_mode() {
    case $COMMAND in
        install|connect)
            if [[ -z "$SETUP_KEY" ]]; then
                echo "FAILED: Setup key is required. Use --key or NETBIRD_SETUP_KEY env var" >&2
                exit 2
            fi
            ;;
    esac

    # Команды выполняются в подоболочках: exit-коды не прерывают вывод OK/FAILED
    local rc=0
    case $COMMAND in
        install)
            if ( cmd_install ); then
                echo "OK: NetBird installed and connected"
            else
                rc=$?
                echo "FAILED: NetBird installation failed" >&2
            fi
            ;;
        update)
            if ( cmd_update ); then
                echo "OK: NetBird updated"
            else
                rc=$?
                echo "FAILED: Update failed" >&2
            fi
            ;;
        connect)
            if ( cmd_connect ); then
                echo "OK: NetBird connected"
            else
                rc=$?
                echo "FAILED: Connection failed" >&2
            fi
            ;;
        disconnect)
            if ( cmd_disconnect ); then
                echo "OK: NetBird disconnected"
            else
                rc=$?
                echo "FAILED: Disconnect failed" >&2
            fi
            ;;
        status)
            if out=$(get_status_output) && [[ -n "$out" ]]; then
                echo "$out"
                if is_netbird_connected; then
                    exit 0
                fi
                echo "NetBird is not connected" >&2
                exit 1
            fi
            echo "NetBird not running or not installed" >&2
            exit 1
            ;;
        uninstall)
            if ( cmd_uninstall ); then
                echo "OK: NetBird uninstalled"
            else
                rc=$?
                echo "FAILED: Uninstall failed" >&2
            fi
            ;;
        *)
            echo "FAILED: Unknown command: $COMMAND" >&2
            echo "Available commands: install, update, connect, disconnect, status, uninstall" >&2
            exit 2
            ;;
    esac
    exit "$rc"
}

# ==================== CLI режим ====================

run_cli_mode() {
    case $COMMAND in
        install)
            print_banner
            cmd_install
            ;;
        update)
            print_banner
            cmd_update
            ;;
        connect)
            print_banner
            cmd_connect
            ;;
        disconnect)
            print_banner
            cmd_disconnect
            ;;
        status)
            print_banner
            # код возврата: 0 — подключен, 1 — нет
            cmd_status || exit $?
            ;;
        uninstall)
            print_banner
            cmd_uninstall
            ;;
        help|*)
            show_help
            ;;
    esac
}

# ==================== Точка входа ====================

main() {
    parse_args "$@"
    init_environment

    case "$RUN_MODE" in
        init)
            run_init_mode
            ;;
        menu)
            run_interactive_menu
            ;;
        ansible)
            run_ansible_mode
            ;;
        cli|*)
            run_cli_mode
            ;;
    esac
}

main "$@"
