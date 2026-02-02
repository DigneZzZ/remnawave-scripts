#!/bin/bash

# VERSION=1.1.0
SCRIPT_VERSION="1.1.0"

# Mode: cli (default), ansible (quiet, no colors), init (interactive menu)
RUN_MODE="cli"
QUIET_MODE=false

# Colors (will be disabled in ansible mode)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Setup key (required, from CLI or env var)
SETUP_KEY="${NETBIRD_SETUP_KEY:-}"

# Disable colors for ansible/non-interactive mode
disable_colors() {
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
}

print_banner() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════"
    echo "║                   NetBird Installer                       "
    echo "║                     Version ${SCRIPT_VERSION}                         "
    echo "╚═══════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

print_success() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

print_info() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен быть запущен с правами root"
        echo "Используйте: sudo $0 $*"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        print_info "Обнаружена ОС: $PRETTY_NAME"
    else
        print_error "Не удалось определить операционную систему"
        exit 1
    fi
}

install_dependencies() {
    print_info "Установка зависимостей..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq ca-certificates curl gnupg >/dev/null 2>&1
            ;;
        centos|rhel|fedora|rocky|alma)
            yum install -y -q ca-certificates curl gnupg >/dev/null 2>&1
            ;;
        *)
            print_warning "Неизвестная ОС, попытка установки без зависимостей..."
            ;;
    esac
    
    print_success "Зависимости установлены"
}

install_netbird() {
    print_info "Установка NetBird..."
    
    if curl -fsSL https://pkgs.netbird.io/install.sh | sh; then
        print_success "NetBird успешно установлен"
        return 0
    else
        print_error "Ошибка при установке NetBird"
        return 1
    fi
}

connect_netbird() {
    local setup_key="$1"
    
    print_info "Подключение к NetBird с setup-key..."
    
    if netbird up --setup-key "$setup_key"; then
        print_success "NetBird успешно подключен!"
        echo ""
        print_info "Статус подключения:"
        netbird status
        return 0
    else
        print_error "Ошибка при подключении к NetBird"
        return 1
    fi
}

show_status() {
    print_info "Текущий статус NetBird:"
    netbird status 2>/dev/null || print_warning "NetBird не установлен"
}

uninstall_netbird() {
    print_warning "Удаление NetBird..."
    
    # Отключаемся
    netbird down 2>/dev/null
    
    # Удаляем пакет
    case $OS in
        ubuntu|debian)
            apt-get remove -y netbird netbird-ui 2>/dev/null
            apt-get autoremove -y 2>/dev/null
            ;;
        centos|rhel|fedora|rocky|alma)
            yum remove -y netbird netbird-ui 2>/dev/null
            ;;
    esac
    
    print_success "NetBird удален"
}

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
    echo "  connect --key KEY      Подключить существующий NetBird к сети"
    echo "  disconnect             Отключиться от сети NetBird"
    echo "  status                 Показать статус подключения"
    echo "  uninstall              Удалить NetBird"
    echo "  help                   Показать эту справку"
    echo ""
    echo "Опции:"
    echo "  --key, -k KEY          Setup key для подключения (ОБЯЗАТЕЛЬНО для install/connect/init)"
    echo "  --quiet, -q            Тихий режим (минимум вывода)"
    echo ""
    echo "Переменные окружения:"
    echo "  NETBIRD_SETUP_KEY      Setup key (альтернатива --key)"
    echo ""
    echo "Примеры:"
    echo "  $0 init --key YOUR-SETUP-KEY              # Автоустановка (cloud-init)"
    echo "  $0 menu                                   # Интерактивное меню"
    echo "  $0 install --key YOUR-SETUP-KEY           # CLI установка"
    echo "  $0 ansible install --key YOUR-KEY         # Ansible режим"
    echo ""
    echo "Cloud-init / user-data:"
    echo "  bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key YOUR-KEY"
    echo ""
    echo "Ansible playbook:"
    echo "  - name: Install NetBird"
    echo "    shell: bash <(curl -Ls .../netbird.sh) ansible install --key {{ netbird_key }}"
    echo ""
}

# Parse arguments
parse_args() {
    COMMAND=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            # Run modes
            init)
                # Non-interactive auto-install for cloud-init/provisioning
                RUN_MODE="init"
                QUIET_MODE=true
                shift
                ;;
            menu)
                # Interactive menu
                RUN_MODE="menu"
                shift
                ;;
            ansible)
                RUN_MODE="ansible"
                QUIET_MODE=true
                disable_colors
                shift
                ;;
            # Commands
            install|connect|disconnect|status|uninstall|help)
                COMMAND="$1"
                shift
                ;;
            # Options
            --key|-k)
                SETUP_KEY="$2"
                shift 2
                ;;
            --quiet|-q)
                QUIET_MODE=true
                shift
                ;;
            *)
                print_error "Неизвестный аргумент: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # For init/menu mode, don't require command
    if [[ "$RUN_MODE" == "init" || "$RUN_MODE" == "menu" ]]; then
        return
    fi
    
    # Default to help if no command in CLI mode
    if [[ -z "$COMMAND" ]]; then
        COMMAND="help"
    fi
}

# ==================== Interactive Menu ====================

show_menu() {
    clear
    print_banner
    echo -e "${CYAN}Выберите действие:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Установить NetBird"
    echo -e "  ${GREEN}2)${NC} Подключить к сети"
    echo -e "  ${GREEN}3)${NC} Отключить от сети"
    echo -e "  ${GREEN}4)${NC} Показать статус"
    echo -e "  ${GREEN}5)${NC} Удалить NetBird"
    echo -e "  ${RED}0)${NC} Выход"
    echo ""
}

prompt_setup_key() {
    if [[ -n "$SETUP_KEY" ]]; then
        local current_key="$SETUP_KEY"
        echo -e "${BLUE}Текущий setup-key:${NC} ${current_key:0:8}...${current_key: -8}"
        echo ""
        read -rp "Введите новый setup-key (или Enter для использования текущего): " new_key
        if [[ -n "$new_key" ]]; then
            SETUP_KEY="$new_key"
        fi
    else
        while [[ -z "$SETUP_KEY" ]]; do
            read -rp "Введите setup-key: " SETUP_KEY
            if [[ -z "$SETUP_KEY" ]]; then
                print_error "Setup key обязателен!"
            fi
        done
    fi
}

run_interactive_menu() {
    check_root
    check_os
    
    while true; do
        show_menu
        read -rp "Ваш выбор [0-5]: " choice
        echo ""
        
        case $choice in
            1)
                prompt_setup_key
                echo ""
                install_dependencies
                install_netbird
                connect_netbird "$SETUP_KEY"
                echo ""
                read -rp "Нажмите Enter для продолжения..."
                ;;
            2)
                prompt_setup_key
                echo ""
                connect_netbird "$SETUP_KEY"
                echo ""
                read -rp "Нажмите Enter для продолжения..."
                ;;
            3)
                print_info "Отключение от NetBird..."
                netbird down
                print_success "Отключено"
                echo ""
                read -rp "Нажмите Enter для продолжения..."
                ;;
            4)
                show_status
                echo ""
                read -rp "Нажмите Enter для продолжения..."
                ;;
            5)
                echo -e "${YELLOW}Вы уверены? (y/N):${NC} "
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    uninstall_netbird
                fi
                echo ""
                read -rp "Нажмите Enter для продолжения..."
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

# ==================== Init Mode (for cloud-init/provisioning) ====================

run_init_mode() {
    # Validate setup key
    if [[ -z "$SETUP_KEY" ]]; then
        echo "FAILED: Setup key is required for init mode" >&2
        echo "Usage: $0 init --key YOUR-SETUP-KEY" >&2
        exit 1
    fi
    
    # Silent auto-install
    check_root
    
    # Detect OS silently
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    else
        echo "FAILED: Cannot detect OS" >&2
        exit 1
    fi
    
    # Install dependencies silently
    case $OS in
        ubuntu|debian)
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq ca-certificates curl gnupg >/dev/null 2>&1
            ;;
        centos|rhel|fedora|rocky|alma)
            yum install -y -q ca-certificates curl gnupg >/dev/null 2>&1
            ;;
    esac
    
    # Install NetBird
    if ! curl -fsSL https://pkgs.netbird.io/install.sh 2>/dev/null | sh >/dev/null 2>&1; then
        echo "FAILED: NetBird installation failed" >&2
        exit 1
    fi
    
    # Connect
    if netbird up --setup-key "$SETUP_KEY" >/dev/null 2>&1; then
        echo "OK: NetBird installed and connected"
        exit 0
    else
        echo "FAILED: NetBird connection failed" >&2
        exit 1
    fi
}

# ==================== CLI Mode ====================

validate_setup_key() {
    if [[ -z "$SETUP_KEY" ]]; then
        print_error "Setup key обязателен!"
        echo ""
        echo "Используйте: $0 $COMMAND --key YOUR-SETUP-KEY"
        echo "Или: NETBIRD_SETUP_KEY=KEY $0 $COMMAND"
        exit 1
    fi
}

run_cli_mode() {
    case $COMMAND in
        install)
            validate_setup_key
            print_banner
            check_root
            check_os
            install_dependencies
            install_netbird
            connect_netbird "$SETUP_KEY"
            ;;
        connect)
            validate_setup_key
            print_banner
            check_root
            connect_netbird "$SETUP_KEY"
            ;;
        disconnect)
            print_banner
            check_root
            print_info "Отключение от NetBird..."
            netbird down
            print_success "Отключено"
            ;;
        status)
            print_banner
            show_status
            ;;
        uninstall)
            print_banner
            check_root
            check_os
            uninstall_netbird
            ;;
        help|*)
            show_help
            ;;
    esac
}

# ==================== Ansible Mode ====================

run_ansible_mode() {
    # Validate setup key for install/connect
    if [[ "$COMMAND" == "install" || "$COMMAND" == "connect" ]]; then
        if [[ -z "$SETUP_KEY" ]]; then
            echo "FAILED: Setup key is required. Use --key or NETBIRD_SETUP_KEY env var" >&2
            exit 1
        fi
    fi
    
    case $COMMAND in
        install)
            check_root
            check_os
            install_dependencies
            if install_netbird; then
                if connect_netbird "$SETUP_KEY"; then
                    echo "OK: NetBird installed and connected"
                    exit 0
                else
                    echo "FAILED: NetBird installed but connection failed" >&2
                    exit 1
                fi
            else
                echo "FAILED: NetBird installation failed" >&2
                exit 1
            fi
            ;;
        connect)
            check_root
            if connect_netbird "$SETUP_KEY"; then
                echo "OK: NetBird connected"
                exit 0
            else
                echo "FAILED: Connection failed" >&2
                exit 1
            fi
            ;;
        disconnect)
            check_root
            if netbird down 2>/dev/null; then
                echo "OK: NetBird disconnected"
                exit 0
            else
                echo "FAILED: Disconnect failed" >&2
                exit 1
            fi
            ;;
        status)
            if netbird status 2>/dev/null; then
                exit 0
            else
                echo "NetBird not running or not installed" >&2
                exit 1
            fi
            ;;
        uninstall)
            check_root
            check_os
            uninstall_netbird
            echo "OK: NetBird uninstalled"
            exit 0
            ;;
        *)
            echo "FAILED: Unknown command: $COMMAND" >&2
            echo "Available commands: install, connect, disconnect, status, uninstall" >&2
            exit 1
            ;;
    esac
}

# ==================== Main ====================

main() {
    parse_args "$@"
    
    case $RUN_MODE in
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
