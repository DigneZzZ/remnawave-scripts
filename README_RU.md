# Remnawave Скрипты

[![Лицензия MIT](https://img.shields.io/badge/Лицензия-MIT-yellow.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/Язык-Bash-blue.svg)](#)
[![Версия](https://img.shields.io/badge/версия-5.8.0-blue.svg)](#)
[![Локализация](https://img.shields.io/badge/🌐_Языки-EN_|_RU-green.svg)](#)

![remnawave-script](remnawave-script.webp)

> **TL;DR:** Однострочные скрипты для развёртывания и управления **Remnawave Panel**, **RemnaNode** и **маскировки трафика Reality** через Docker. Включают резервное копирование/восстановление, Telegram-уведомления, Caddy reverse proxy и двуязычный CLI (RU/EN).

**[📖 Readme in English](/README.md)** · **[💬 Поддержка](https://gig.ovh/t/remnawave-managment-scripts-by-dignezzz/116)**

---

## 🚀 Быстрый старт

```bash
# Remnawave Panel
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install

# RemnaNode
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install

# Caddy Selfsteal (маскировка Reality)
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ install
```

После установки управляйте сервисами командами: `remnawave`, `remnanode` или `selfsteal`.

---

## 📦 Состав проекта

| Скрипт | Назначение | Команда управления |
|--------|------------|-------------------|
| **remnawave.sh** | Установщик и менеджер панели | `remnawave <команда>` |
| **remnanode.sh** | Установщик и менеджер узла | `remnanode <команда>` |
| **selfsteal.sh** | Маскировка трафика Reality | `selfsteal <команда>` |
| **wtm.sh** | Менеджер WARP и Tor | `wtm <команда>` |
| **netbird.sh** | Установщик NetBird VPN | `netbird.sh <команда>` |

**Общие возможности:** автообновление, интерактивные меню, двуязычный интерфейс (RU/EN), Docker Compose v2, идемпотентные операции.

---

## 🚀 Remnawave Panel

Полный установщик и менеджер [Remnawave Panel](https://github.com/remnawave/) с бэкапами, Caddy proxy, Telegram-интеграцией и управлением страницей подписки.

### Установка

```bash
# Стандартная установка
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install

# С параметрами
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install --name panel-prod --dev
```

| Флаг | Описание |
|------|----------|
| `--name NAME` | Пользовательское имя директории |
| `--dev` | Установка версии для разработки |

### Команды

<details>
<summary><b>📋 Все команды панели</b></summary>

| Команда | Описание |
|---------|----------|
| `install` | Установить Remnawave Panel |
| `install-script` | Установить только скрипт управления |
| `update` | Обновить скрипт и контейнеры |
| `uninstall` | Полностью удалить панель |
| `up` / `down` / `restart` | Жизненный цикл сервисов |
| `status` | Показать статус сервисов |
| `logs` | Просмотреть логи (`--follow`) |
| `edit` | Редактировать docker-compose.yml |
| `edit-env` | Редактировать .env |
| `console` | Доступ к CLI консоли панели |
| `backup` | Создать бэкап (`--data-only`, `--no-compress`) |
| `restore` | Восстановить из бэкапа (`--file FILE`, `--database-only`) |
| `schedule` | Управление расписанием бэкапов |
| `subpage` | Настройки страницы подписки |
| `subpage-token` | Настроить API токен |
| `subpage-restart` | Перезапустить subscription-page |
| `install-subpage` | Установить только subscription-page |
| `install-subpage-standalone` | Установить subpage на отдельном сервере (`--with-caddy`) |
| `caddy` / `caddy up` / `caddy down` | Управление Caddy |
| `caddy logs` / `caddy edit` | Логи и конфигурация Caddy |
| `caddy restart` / `caddy uninstall` | Жизненный цикл Caddy |
| `caddy reset-user` | Сбросить пароль админа Caddy |

</details>

### Основные возможности

- **Автогенерация** `.env`, секретов, портов, `docker-compose.yml`
- **Автосоздание админа** — credentials сохраняются в `admin-credentials.txt`
- **Caddy Reverse Proxy** — Простой режим (авто SSL) или Безопасный режим (портал аутентификации + MFA)
- **Система бэкапов** — полные/только БД, cron-расписание, доставка в Telegram, версионное восстановление → см. [💾 Бэкап, восстановление и миграция](#-бэкап-восстановление-и-миграция)
- **Миграция переменных** — устаревшие env-переменные удаляются автоматически при `update` (v2.2.0+)

<details>
<summary><b>🌐 Standalone Subscription-Page</b></summary>

Установка subscription-page на **отдельном сервере** с подключением к основной панели через API:

```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install-subpage-standalone --with-caddy
```

Установщик запросит URL панели, API токен и домен для подписки, затем сгенерирует минимальный docker-compose без зависимостей БД.

</details>

<details>
<summary><b>📱 Интеграция с Telegram</b></summary>

Настройка в `.env`:

```bash
IS_TELEGRAM_NOTIFICATIONS_ENABLED=true
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_NOTIFY_USERS_CHAT_ID=your_chat_id
TELEGRAM_NOTIFY_NODES_CHAT_ID=your_chat_id
```

Поддерживает уведомления о бэкапах, доставку больших файлов (>50MB частями) и треды в групповых чатах.

</details>

<details>
<summary><b>🔄 Миграция переменных (v2.2.0+)</b></summary>

При `remnawave update` устаревшие env-переменные (OAuth, Branding) автоматически удаляются из `.env` с созданием резервной копии. Настраивайте их в UI панели:

- **Настройки → Аутентификация → Методы входа** (OAuth)
- **Настройки → Брендинг** (Логотип, название)

</details>

<details>
<summary><b>📂 Структура файлов</b></summary>

```text
/opt/remnawave/
├── .env, .env.subscription
├── docker-compose.yml
├── app-config.json, backup-config.json
├── backup-scheduler.sh
├── backups/              # Хранилище бэкапов
└── logs/                 # Логи операций

/opt/caddy-remnawave/     # Caddy (если установлен)
├── docker-compose.yml, Caddyfile, .env
└── data/                 # SSL сертификаты

/usr/local/bin/remnawave  # CLI команда
```

</details>

---

## 💾 Бэкап, восстановление и миграция

Встроенная система резервного копирования в `remnawave.sh` с версионным восстановлением, cron-расписанием и доставкой в Telegram.

### Бэкап

```bash
remnawave backup                    # Полный системный бэкап (сжатый .tar.gz)
remnawave backup --data-only        # Только база данных (.sql.gz)
remnawave backup --no-compress      # Несжатый бэкап
```

### Бэкапы по расписанию

```bash
remnawave schedule                  # Интерактивная настройка cron-расписания
```

Параметры: ежедневные/еженедельные/ежемесячные интервалы, политики хранения, настройки сжатия, доставка в Telegram.

### Восстановление

```bash
remnawave restore --file backup.tar.gz                  # Полное восстановление (авто safety-бэкап)
remnawave restore --database-only --file database.sql.gz # Только база данных
```

**Проверка версий:** major/minor версии должны совпадать для восстановления; различия patch показывают предупреждения, но допускаются.

### Миграция на другой сервер

1. Создайте бэкап на **исходном** сервере:
   ```bash
   remnawave backup
   ```
2. Перенесите файл бэкапа на **целевой** сервер (например, через `scp`)
3. На **целевом** сервере установите и восстановите:
   ```bash
   bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install --name remnawave
   remnawave restore --file backup.tar.gz
   ```

<details>
<summary><b>🛠 Ручное восстановление (если автоматическое не работает)</b></summary>

```bash
# Вариант A: Новая установка
sudo bash remnawave.sh @ install --name remnawave
sudo remnawave down
tar -xzf backup.tar.gz
cat backup_folder/database.sql | docker exec -i -e PGPASSWORD="пароль" remnawave-db psql -U postgres -d postgres
sudo remnawave up

# Вариант B: Существующая установка
sudo remnawave down
cat database.sql | docker exec -i -e PGPASSWORD="пароль" remnawave-db psql -U postgres -d postgres
sudo remnawave up
```

</details>

---

## 🛰 RemnaNode

Установщик и менеджер **RemnaNode** — прокси-узлов с интеграцией Xray-core. Поддержка мультиархитектуры (x86_64, ARM64, ARM32, MIPS).

### Установка

```bash
# Интерактивный режим
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install

# Неинтерактивный (force режим)
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install \
    --force --secret-key="KEY" --port=3001 --xray
```

| Флаг | Описание | По умолчанию |
|------|----------|--------------|
| `--force`, `-f` | Пропустить все подтверждения | — |
| `--secret-key=KEY` | SECRET_KEY из панели (обязателен в force режиме) | — |
| `--port=PORT` | NODE_PORT | `3000` |
| `--xtls-port=PORT` | XTLS_API_PORT | `61000` |
| `--xray` / `--no-xray` | Установить Xray-core | не устанавливается в force режиме |
| `--name NAME` | Имя директории | `remnanode` |
| `--dev` | Образ для разработки | — |

### Команды

<details>
<summary><b>📋 Все команды узла</b></summary>

| Команда | Описание |
|---------|----------|
| `install` | Установить RemnaNode |
| `install-script` | Установить только скрипт |
| `update` | Обновить скрипт и контейнер |
| `uninstall` | Удалить узел |
| `up` / `down` / `restart` | Жизненный цикл сервисов |
| `status` / `logs` | Статус и логи |
| `core-update` | Обновить бинарный файл Xray-core |
| `edit` / `edit-env` | Редактирование конфигов |
| `setup-logs` | Настройка ротации логов |
| `xray_log_out` / `xray_log_err` | Логи Xray в реальном времени |

</details>

### Основные возможности

- **Xray-core** — автоопределение, интерактивный выбор версии, поддержка pre-release
- **NET_ADMIN capability** (v4.2.0+) — автоматически добавляется для функций IP Management (просмотр/сброс пользовательских соединений). Автомиграция при `update`
- **Ротация логов** — макс. 50MB, 5 файлов, сжатие, без простоя
- **Миграция конфигурации** (v2.2.2+) — `APP_PORT` → `NODE_PORT`, `SSL_CERT` → `SECRET_KEY` (автоматически при `update`)
- **Два формата конфигурации** — поддержка `.env` и inline-переменных в docker-compose

<details>
<summary><b>📂 Структура файлов</b></summary>

```text
/opt/remnanode/
├── .env
└── docker-compose.yml

/var/lib/remnanode/       # Бинарный файл Xray и логи
/usr/local/bin/remnanode  # CLI команда
/etc/logrotate.d/remnanode
```

</details>

---

## 🎭 Caddy Selfsteal (маскировка Reality)

Развёртывание Caddy как решения для **маскировки трафика Reality** с профессиональными шаблонами сайтов для HTTPS-камуфляжа.

### Установка

```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ install
```

### Команды

| Команда | Описание |
|---------|----------|
| `install` / `uninstall` | Установить или удалить |
| `up` / `down` / `restart` | Жизненный цикл сервисов |
| `status` / `logs` | Статус и логи |
| `template` | Управление шаблонами сайтов |
| `edit` | Редактировать Caddyfile |
| `guide` | Руководство по интеграции Reality |
| `update` | Обновить скрипт |

### Шаблоны

8 готовых шаблонов сайтов: `10gag`, `converter`, `downloader`, `filecloud`, `games-site`, `modmanager`, `speedtest`, `YouTube`.

```bash
selfsteal template list              # Список шаблонов
selfsteal template install converter # Установить шаблон
```

**Конфигурация Xray Reality:**
```json
{ "realitySettings": { "dest": "127.0.0.1:9443", "serverNames": ["your-domain.com"] } }
```

<details>
<summary><b>📂 Структура файлов</b></summary>

```text
/opt/caddy/
├── .env, docker-compose.yml, Caddyfile
├── logs/
└── html/           # Контент шаблона
    ├── index.html, 404.html
    └── assets/

/usr/local/bin/selfsteal
```

</details>

---

## ⚙️ Системные требования

| | Минимум | Рекомендуется |
|---|---------|---------------|
| **CPU** | 1 ядро | 2+ ядра |
| **RAM** | 512 МБ | 2 ГБ+ |
| **Хранилище** | 2 ГБ | 10 ГБ+ SSD |
| **Сеть** | Стабильная | 100 Мбит/с+ |

**ОС:** Ubuntu 18.04+, Debian 10+, CentOS 7+, AlmaLinux 8+, Fedora 32+, Arch, openSUSE 15+

**Зависимости** (устанавливаются автоматически): Docker Engine, Docker Compose V2, curl, openssl, jq, tar/gzip

---

## 🔐 Безопасность

- Сервисы привязываются к `127.0.0.1` по умолчанию
- Автогенерация учётных данных БД, JWT-секретов, API-токенов
- Подсказки по настройке UFW/firewalld при установке
- SSL/TLS через Caddy с DNS-валидацией

<details>
<summary><b>🔒 Hardening для production</b></summary>

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow from trusted_ip to any port panel_port
sudo ufw enable
```

</details>

---

## 📊 Мониторинг и логи

```bash
remnawave status && remnanode status && selfsteal status  # Статус сервисов
remnawave logs --follow    # Логи в реальном времени
docker stats               # Использование ресурсов
```

<details>
<summary><b>📋 Расположение логов</b></summary>

| Компонент | Путь |
|-----------|------|
| Панель | `/opt/remnawave/logs/` |
| Узел (Xray) | `/var/lib/remnanode/` |
| Caddy | `/opt/caddy/logs/` |

Ротация логов: макс. 50MB, хранится 5 файлов, автоматическое сжатие.

</details>

---

## 🧩 Другие скрипты

Репозиторий также включает дополнительные утилиты для управления сетью и настройки VPN.

### 🌐 WTM — WARP & Tor Manager

Профессиональный инструмент для управления **Cloudflare WARP** и **Tor** на Linux серверах. Включает интеграцию с XRay, интерактивные меню и автообновление.

```bash
# Установка как глобальная команда
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) @ install-script

# Или прямой запуск
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh)

# Установить WARP и Tor
sudo wtm install-all
```

Основные возможности: WARP (WireGuard), Tor SOCKS5 прокси, маршрутизация XRay для `.onion` доменов, тестирование соединений, мониторинг сервисов.

📖 Полная документация: [README-warp.md](./README-warp.md)

### 🐦 NetBird — Установщик VPN

Быстрый установщик для [NetBird](https://netbird.io/) mesh VPN. Поддерживает CLI, cloud-init, интерактивное меню и режим для Ansible.

```bash
# CLI установка
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key ВАШ-SETUP-KEY

# Автоустановка для cloud-init / provisioning
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) init --key ВАШ-SETUP-KEY

# Интерактивное меню
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) menu
```

Основные возможности: установка одной командой, SSH доступ между пирами (`--ssh`), автонастройка файрвола (UFW/firewalld), режим для Ansible.

📖 Полная документация: [README-netbird.md](./README-netbird.md)

---

## 🤝 Участие в разработке

1. Fork → ветка → изменения → тестирование → PR
2. Придерживайтесь существующего стиля кода, тестируйте на нескольких дистрибутивах
3. Проверяйте [существующие issues](https://github.com/DigneZzZ/remnawave-scripts/issues) перед отчётом об ошибках

---

## 📜 Лицензия

[MIT License](./LICENSE) — свободное использование в коммерческих и личных целях.

---

<div align="center">

**⭐ Если проект полезен — поставьте звёздочку!**

[Сообщить об ошибке](https://github.com/DigneZzZ/remnawave-scripts/issues) · [Запросить функцию](https://github.com/DigneZzZ/remnawave-scripts/issues) · [Сообщество: gig.ovh](https://gig.ovh)

</div>
