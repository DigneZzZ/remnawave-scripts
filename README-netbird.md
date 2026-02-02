# NetBird Installer Script

[English](#english) | [Русский](#русский)

---

## English

A simple script for quick NetBird installation and connection on Linux servers. Supports CLI, auto-install for provisioning, interactive menu, and Ansible modes.

### Features

- 🚀 One-liner installation
- ☁️ Auto-install mode for cloud-init / provisioning (`init`)
- 🔧 Interactive menu mode (`menu`)
- 🤖 Ansible-friendly mode (no colors, minimal output)
- 🔑 Setup key via CLI or environment variable
- 📦 Supports Ubuntu, Debian, CentOS, RHEL, Fedora, Rocky, Alma

### Quick Start

**For cloud-init / user-data (silent auto-install):**
```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key YOUR-SETUP-KEY
```

**CLI installation:**
```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key YOUR-SETUP-KEY
```

### Usage

#### Modes

| Mode | Command | Description |
|------|---------|-------------|
| **init** | `init --key KEY` | Silent auto-install for cloud-init/provisioning |
| **menu** | `menu` | Interactive menu |
| **ansible** | `ansible <cmd> --key KEY` | Silent mode for Ansible playbooks |
| **cli** | `<command> --key KEY` | Default CLI with commands |

#### Interactive Menu

```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) menu
```

#### CLI Commands

| Command | Description |
|---------|-------------|
| `install --key KEY` | Install NetBird and connect (key required!) |
| `connect --key KEY` | Connect existing NetBird to network |
| `disconnect` | Disconnect from NetBird network |
| `status` | Show connection status |
| `uninstall` | Remove NetBird |
| `help` | Show help |

#### Examples

```bash
# Auto-install for cloud-init (silent)
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key ABC123-DEF456

# Auto-install with SSH access between servers
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key ABC123-DEF456 --ssh

# CLI install with output
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key ABC123-DEF456

# CLI install with SSH access
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key ABC123-DEF456 --ssh

# Using environment variable
NETBIRD_SETUP_KEY="ABC123-DEF456" bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init

# Check status
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) status
```

### SSH Access Between Servers

Use `--ssh` flag to enable SSH access between NetBird peers:

```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key YOUR-KEY --ssh
```

This enables:
- `--allow-server-ssh` — allows incoming SSH connections from other NetBird peers
- `--enable-ssh-root` — enables root SSH access

> ⚠️ **Note:** You also need to create an SSH Access Policy in your NetBird dashboard (starting from v0.61.0)

### Cloud-Init / User-Data

Add to your cloud-init configuration:

```yaml
#cloud-config
runcmd:
  - bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key YOUR-SETUP-KEY --ssh
```

Or in user-data script:

```bash
#!/bin/bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key YOUR-SETUP-KEY --ssh
```

### Ansible Integration

For Ansible playbooks, use the `ansible` mode for clean output and proper exit codes:

```yaml
- name: Install NetBird
  shell: |
    bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) \
    ansible install --key {{ netbird_setup_key }}
  register: netbird_result
  changed_when: "'OK' in netbird_result.stdout"
  failed_when: "'FAILED' in netbird_result.stdout"

- name: Check NetBird status
  shell: |
    bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) \
    ansible status
  register: netbird_status
  changed_when: false
```

Or using environment variable in inventory:

```yaml
# group_vars/all.yml
netbird_setup_key: "YOUR-SETUP-KEY-HERE"
```

### Exit Codes

| Code | Description |
|------|-------------|
| `0` | Success |
| `1` | Error (check stderr for details) |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `NETBIRD_SETUP_KEY` | Setup key (alternative to `--key`) |

---

## Русский

Простой скрипт для быстрой установки и подключения NetBird на Linux серверах. Поддерживает CLI, автоустановку для provisioning, интерактивное меню и режим для Ansible.

### Возможности

- 🚀 Установка одной командой
- ☁️ Автоустановка для cloud-init / provisioning (`init`)
- 🔧 Интерактивное меню (`menu`)
- 🤖 Режим для Ansible (без цветов, минимум вывода)
- 🔑 Setup key через CLI или переменную окружения
- � SSH доступ между серверами (`--ssh`)
- �📦 Поддержка Ubuntu, Debian, CentOS, RHEL, Fedora, Rocky, Alma

### Быстрый старт

**Для cloud-init / user-data (тихая автоустановка):**
```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key ВАШ-SETUP-KEY
```

**CLI установка:**
```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key ВАШ-SETUP-KEY
```

### Использование

#### Режимы

| Режим | Команда | Описание |
|-------|---------|----------|
| **init** | `init --key KEY` | Тихая автоустановка для cloud-init/provisioning |
| **menu** | `menu` | Интерактивное меню |
| **ansible** | `ansible <cmd> --key KEY` | Тихий режим для Ansible плейбуков |
| **cli** | `<command> --key KEY` | CLI режим с командами (по умолчанию) |

#### Интерактивное меню

```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) menu
```

#### CLI команды

| Команда | Описание |
|---------|----------|
| `install --key KEY` | Установить NetBird и подключить (ключ обязателен!) |
| `connect --key KEY` | Подключить существующий NetBird к сети |
| `disconnect` | Отключиться от сети NetBird |
| `status` | Показать статус подключения |
| `uninstall` | Удалить NetBird |
| `help` | Показать справку |

#### Примеры

```bash
# Автоустановка для cloud-init (тихий режим)
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key ABC123-DEF456

# Автоустановка с SSH доступом между серверами
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key ABC123-DEF456 --ssh

# CLI установка с выводом
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key ABC123-DEF456

# CLI установка с SSH доступом
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key ABC123-DEF456 --ssh

# Через переменную окружения
NETBIRD_SETUP_KEY="ABC123-DEF456" bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init

# Проверка статуса
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) status
```

### SSH доступ между серверами

Используйте флаг `--ssh` для включения SSH доступа между NetBird пирами:

```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key YOUR-KEY --ssh
```

Это включает:
- `--allow-server-ssh` — разрешает входящие SSH соединения от других NetBird пиров
- `--enable-ssh-root` — включает root SSH доступ

> ⚠️ **Важно:** Вам также нужно создать SSH Access Policy в дашборде NetBird (начиная с v0.61.0)

### Cloud-Init / User-Data

Добавьте в конфигурацию cloud-init:

```yaml
#cloud-config
runcmd:
  - bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key YOUR-SETUP-KEY --ssh
```

Или в скрипт user-data:

```bash
#!/bin/bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key YOUR-SETUP-KEY --ssh
```

### Интеграция с Ansible

Для Ansible плейбуков используйте режим `ansible` для чистого вывода и корректных кодов возврата:

```yaml
- name: Установка NetBird
  shell: |
    bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) \
    ansible install --key {{ netbird_setup_key }}
  register: netbird_result
  changed_when: "'OK' in netbird_result.stdout"
  failed_when: "'FAILED' in netbird_result.stdout"

- name: Проверка статуса NetBird
  shell: |
    bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) \
    ansible status
  register: netbird_status
  changed_when: false
```

### Коды возврата

| Код | Описание |
|-----|----------|
| `0` | Успех |
| `1` | Ошибка (подробности в stderr) |

### Переменные окружения

| Переменная | Описание |
|------------|----------|
| `NETBIRD_SETUP_KEY` | Setup key (альтернатива `--key`) |

---

## Getting Setup Key

1. Go to [NetBird Dashboard](https://app.netbird.io/) or your self-hosted instance
2. Navigate to **Setup Keys**
3. Create a new setup key or copy an existing one
4. Use the key with this script

## License

MIT License - see main repository for details.
