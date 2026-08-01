<div align="center">

# 🐦 NetBird Installer

[![Версия](https://img.shields.io/badge/netbird.sh-1.4.2-blue.svg)](#)
[![Режимы](https://img.shields.io/badge/CLI_·_cloud--init_·_menu_·_Ansible-supported-brightgreen.svg)](#)
[![Лицензия MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

<img src="assets/preview-netbird.svg" alt="Меню netbird" width="640">

**[English](#english)** · **[Русский](#русский)** · **[Main README](./README.md)**

</div>

---

## English

A simple script for quick [NetBird](https://netbird.io/) mesh-VPN installation and connection on Linux servers. Supports CLI, silent auto-install for provisioning, interactive menu, and Ansible modes.

### Features

🚀 One-liner installation · ☁️ cloud-init/provisioning mode (`init`) · 🔧 Interactive menu · 🤖 Ansible-friendly mode (no colors, clean exit codes) · 🔑 Setup key via CLI or env var · 🔐 SSH access between peers (`--ssh`) · 🔥 Auto-firewall (UFW/firewalld) · 🔄 `update` command · 📝 Logging to file · ✅ Setup-key validation · 🔍 Connection verification after install · ⚡ Force mode (`--force`)

**Supported OS:** Ubuntu, Debian, CentOS, RHEL, Fedora, Rocky, Alma.

### Quick Start

```bash
# Silent auto-install for cloud-init / user-data
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key YOUR-SETUP-KEY

# CLI installation
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key YOUR-SETUP-KEY

# Interactive menu
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) menu
```

### Modes & Commands

| Mode | Command | Description |
|------|---------|-------------|
| **init** | `init --key KEY` | Silent auto-install for cloud-init/provisioning |
| **menu** | `menu` | Interactive menu |
| **ansible** | `ansible <cmd> --key KEY` | Silent mode for Ansible playbooks |
| **cli** | `<command> --key KEY` | Default CLI (see below) |

| Command | Description |
|---------|-------------|
| `install --key KEY` | Install NetBird and connect (key required) |
| `update` | Update NetBird to the latest version |
| `connect --key KEY` | Connect an existing NetBird to the network |
| `disconnect` | Disconnect from the network |
| `status` | Show connection status |
| `uninstall` | Remove NetBird |
| `help` | Show help |

| Option | Description |
|--------|-------------|
| `--key, -k KEY` | Setup key (or env var `NETBIRD_SETUP_KEY`) |
| `--ssh` | Enable SSH access between peers |
| `--force, -f` | Auto-accept all prompts (firewall, reinstall) |
| `--quiet, -q` | Minimal output |
| `--log FILE` | Write log to file |
| `--version, -v` | Show script version |

<details>
<summary><b>📋 More examples</b></summary>

```bash
# Auto-install with SSH access between servers
bash <(curl -Ls .../netbird.sh) init --key ABC123-DEF456 --ssh

# CLI install with auto-accept (no prompts)
bash <(curl -Ls .../netbird.sh) install --key ABC123-DEF456 --force

# Update / status / with logging
bash <(curl -Ls .../netbird.sh) update
bash <(curl -Ls .../netbird.sh) status
bash <(curl -Ls .../netbird.sh) install --key KEY --log /var/log/netbird-install.log
```

</details>

### SSH Access Between Servers

The `--ssh` flag enables `--allow-server-ssh` (incoming SSH from NetBird peers) and `--enable-ssh-root` (root SSH access).

> ⚠️ You also need to create an **SSH Access Policy** in your NetBird dashboard (since NetBird v0.61.0).

### Cloud-Init / User-Data

```yaml
#cloud-config
runcmd:
  - bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key YOUR-SETUP-KEY --ssh
```

### Ansible Integration

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

Exit codes: `0` — success, `1` — error (details in stderr).

### Getting a Setup Key

[NetBird Dashboard](https://app.netbird.io/) (or your self-hosted instance) → **Setup Keys** → create or copy a key.

---

## Русский

Простой скрипт для быстрой установки и подключения [NetBird](https://netbird.io/) mesh-VPN на Linux-серверах. Поддерживает CLI, тихую автоустановку для provisioning, интерактивное меню и режим для Ansible.

### Возможности

🚀 Установка одной командой · ☁️ Режим cloud-init/provisioning (`init`) · 🔧 Интерактивное меню · 🤖 Режим для Ansible (без цветов, корректные коды возврата) · 🔑 Setup key через CLI или переменную окружения · 🔐 SSH-доступ между пирами (`--ssh`) · 🔥 Автонастройка файрвола (UFW/firewalld) · 🔄 Команда `update` · 📝 Логирование в файл · ✅ Валидация setup-key · 🔍 Проверка подключения после установки · ⚡ Режим без подтверждений (`--force`)

**Поддерживаемые ОС:** Ubuntu, Debian, CentOS, RHEL, Fedora, Rocky, Alma.

### Быстрый старт

```bash
# Тихая автоустановка для cloud-init / user-data
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key ВАШ-SETUP-KEY

# CLI-установка
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key ВАШ-SETUP-KEY

# Интерактивное меню
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) menu
```

### Режимы и команды

| Режим | Команда | Описание |
|-------|---------|----------|
| **init** | `init --key KEY` | Тихая автоустановка для cloud-init/provisioning |
| **menu** | `menu` | Интерактивное меню |
| **ansible** | `ansible <cmd> --key KEY` | Тихий режим для Ansible-плейбуков |
| **cli** | `<команда> --key KEY` | CLI-режим (по умолчанию) |

| Команда | Описание |
|---------|----------|
| `install --key KEY` | Установить NetBird и подключить (ключ обязателен) |
| `update` | Обновить NetBird до последней версии |
| `connect --key KEY` | Подключить существующий NetBird к сети |
| `disconnect` | Отключиться от сети |
| `status` | Показать статус подключения |
| `uninstall` | Удалить NetBird |
| `help` | Показать справку |

| Опция | Описание |
|-------|----------|
| `--key, -k KEY` | Setup key (или переменная `NETBIRD_SETUP_KEY`) |
| `--ssh` | SSH-доступ между пирами |
| `--force, -f` | Автоподтверждение всех запросов (файрвол, переустановка) |
| `--quiet, -q` | Минимальный вывод |
| `--log FILE` | Записывать лог в файл |
| `--version, -v` | Версия скрипта |

<details>
<summary><b>📋 Больше примеров</b></summary>

```bash
# Автоустановка с SSH-доступом между серверами
bash <(curl -Ls .../netbird.sh) init --key ABC123-DEF456 --ssh

# CLI-установка без запросов
bash <(curl -Ls .../netbird.sh) install --key ABC123-DEF456 --force

# Обновление / статус / с логированием
bash <(curl -Ls .../netbird.sh) update
bash <(curl -Ls .../netbird.sh) status
bash <(curl -Ls .../netbird.sh) install --key KEY --log /var/log/netbird-install.log
```

</details>

### SSH-доступ между серверами

Флаг `--ssh` включает `--allow-server-ssh` (входящий SSH от NetBird-пиров) и `--enable-ssh-root` (root-доступ по SSH).

> ⚠️ Дополнительно нужно создать **SSH Access Policy** в дашборде NetBird (начиная с NetBird v0.61.0).

### Cloud-Init / User-Data

```yaml
#cloud-config
runcmd:
  - bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key ВАШ-SETUP-KEY --ssh
```

### Интеграция с Ansible

```yaml
- name: Установка NetBird
  shell: |
    bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) \
    ansible install --key {{ netbird_setup_key }}
  register: netbird_result
  changed_when: "'OK' in netbird_result.stdout"
  failed_when: "'FAILED' in netbird_result.stdout"
```

Коды возврата: `0` — успех, `1` — ошибка (подробности в stderr).

### Где взять Setup Key

[NetBird Dashboard](https://app.netbird.io/) (или self-hosted инстанс) → **Setup Keys** → создать или скопировать ключ.

---

<div align="center">

[Report Bug / Сообщить об ошибке](https://github.com/DigneZzZ/remnawave-scripts/issues) · [gig.ovh](https://gig.ovh) · **DigneZzZ** · [MIT License](./LICENSE)

</div>
