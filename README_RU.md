<div align="center">

<img src="assets/hero.svg" alt="Remnawave Scripts" width="880">

[![Лицензия MIT](https://img.shields.io/badge/Лицензия-MIT-yellow.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/Язык-Bash-blue.svg)](#)
[![remnawave.sh](https://img.shields.io/badge/remnawave.sh-6.7.2-blue.svg)](#-remnawave-panel)
[![remnanode.sh](https://img.shields.io/badge/remnanode.sh-4.6.0-blue.svg)](#-remnanode)
[![Panel](https://img.shields.io/badge/Remnawave_Panel-3.4.x_ready-brightgreen.svg)](#)
[![Локализация](https://img.shields.io/badge/🌐-RU_|_EN-green.svg)](./README.md)

**[English](./README.md)** · **[Быстрый старт](#-быстрый-старт)** · **[Скрипты](#-скрипты)** · **[Бэкапы](#-бэкапы-и-миграция)** · **[Поддержка](https://gig.ovh/t/remnawave-managment-scripts-by-dignezzz/116)**

</div>

Однострочная установка и полноценный CLI для **Remnawave Panel**, **RemnaNode**, маскировки **Reality**, **WARP/Tor** и корпоративных бэкапов. Всё на Docker, интерфейс RU/EN, идемпотентные операции, автообновление.

> 🆕 **Remnawave Panel 3.4.x и node 3.4.x поддерживаются из коробки.** Свежие установки сразу
> получают актуальную конфигурацию — включая новый выбор `SHORT_UUID_METHOD` для ссылок подписки
> (`nanoid` / `uuid` / свой шаблон), — а `remnawave update` сам мигрирует старый `.env` с проверкой
> версии образа и бэкапом каждого изменённого файла.
>
> ⚠️ **Панель 3.3.0+ нужна только линейке нод 3.3.0 … 3.3.2** (эти релизы требуют производный SNI
> в TLS-handshake). В ноде 3.4.0 проверку сделали опциональной (`SNI_VERIFICATION`, по умолчанию
> выключена), поэтому свежая нода снова работает и со старой панелью.

## ⚡ Быстрый старт

```bash
# Панель Remnawave
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install

# Нода RemnaNode
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install

# Caddy Selfsteal — маскировка Reality
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ install
```

Нужен только CLI, без установки всего остального? Замените `install` на **`install-script`** — он
просто кладёт команду в `/usr/local/bin` (удобно на сервере, которым управляете удалённо, или чтобы
прямо сейчас получить свежий CLI):

```bash
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install-script
```

> **GitHub заблокирован на сервере?** Каждый скрипт зеркалируется через jsDelivr — используйте вместо
> `github.com/.../raw/main/` любой из адресов вида:
> `https://cdn.jsdelivr.net/gh/DigneZzZ/remnawave-scripts@main/<скрипт>.sh`
> После установки скрипты сами переключаются на эти зеркала — в том числе при самообновлении.

После установки скрипт доступен как глобальная команда: `remnawave`, `remnanode`, `selfsteal` — без аргументов открывается интерактивное меню.

## 📦 Скрипты

| Скрипт | Версия | Что делает | Документация |
|---|---|---|---|
| 🚀 **remnawave.sh** | `6.7.2` | Панель: установка, Caddy, бэкапы, subscription-page | этот файл |
| 🛰 **remnanode.sh** | `4.6.0` | Нода: Xray-core, логи, автоперезапуск | этот файл |
| 🎭 **selfsteal.sh** | `2.11.1` | Caddy-маскировка для Reality, 11 шаблонов сайтов | [README-selfsteal](./README-selfsteal.md) |
| 🌐 **wtm.sh** | `1.5.2` | WARP + Tor: WireGuard-outbound для Xray, WARP+ | [README-warp](./README-warp.md) |
| 🐦 **netbird.sh** | `1.4.2` | NetBird mesh-VPN: CLI / cloud-init / Ansible | [README-netbird](./README-netbird.md) |

Каждый скрипт держит себя в актуальном состоянии: проверяет свою версию при `update` (и при
открытии меню), ставит более новую **без вопросов** и повторяет вашу команду. Загрузка идёт сначала
через GitHub, потом через зеркала jsDelivr. Чтобы поставить или обновить только CLI на сервере —
команда `install-script`, см. таблицы команд ниже.

---

## 🚀 Remnawave Panel

<div align="center"><img src="assets/preview-remnawave.svg" alt="Меню remnawave" width="640"></div>

- **Установка под ключ** — `.env`, секреты, порты, compose и админ создаются автоматически (креды в `admin-credentials.txt`)
- **Формат ссылки подписки** — при установке выбирается `nanoid` (16..64 символов), `uuid` или свой шаблон; `update` дописывает блок в существующий `.env` и предлагает тот же выбор. Шаблон проверяется ровно так же, как это делает панель, и сразу показывается пример (панель 3.4.0+)
- **Caddy reverse proxy** — авто-SSL, опционально портал аутентификации с MFA (Caddy Security)
- **Subscription-page** — вместе с панелью или standalone на отдельном сервере; API-токен создаётся сам, с минимальными скоупами
- **Безопасный `update`** — снапшот БД и конфигов перед обновлением + автоматические миграции (включая v2 → v3)
- **Telegram** — уведомления и доставка бэкапов, поддержка тредов, прокси и собственного адреса Bot API (свой сервер или relay)

```bash
remnawave              # интерактивное меню
remnawave update       # обновление скрипта, образов и миграции
remnawave backup       # бэкап вручную (или `schedule` — по расписанию)
```

<details>
<summary><b>📋 Команды CLI и флаги установки</b></summary>

| Команда | Описание |
|---|---|
| `install` / `uninstall` | Установка / полное удаление |
| `install --name X --dev` | Своё имя каталога, dev-образ |
| `up` / `down` / `restart` / `status` / `logs` | Управление сервисами |
| `update` | Обновление скрипта и контейнеров с миграциями |
| `backup` / `restore` / `schedule` | Бэкапы: вручную, восстановление, cron |
| `upgrade-postgres` | Опциональный апгрейд PostgreSQL 17 → 18 (дамп → новый volume → рестор, с откатом) |
| `edit` / `edit-env` / `console` | compose, .env, консоль панели |
| `subpage` / `subpage-token` / `subpage-restart` | Управление subscription-page |
| `install-subpage-standalone --with-caddy` | Subpage на отдельном сервере |
| `caddy …` | Установка и управление Caddy (`up/down/logs/edit/reset-user`) |
| `install-script` / `update-script` | Установить или обновить **сам CLI** — контейнеры не трогаются |
| `uninstall-script` | Удалить CLI из `/usr/local/bin` |

> `install-script` — это не `install`. Она только ставит (или обновляет) команду `remnawave` на
> сервере: пригодится до установки панели, на машине, которой вы управляете удалённо, или чтобы
> прямо сейчас получить свежий CLI. `install` разворачивает саму панель.
> `update` и так обновляет CLI перед всем остальным, поэтому вручную это нужно редко.
> Все загрузки идут сначала через GitHub, потом через зеркала jsDelivr.

```bash
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install-script
# GitHub заблокирован? то же самое через зеркало:
sudo bash <(curl -Ls https://cdn.jsdelivr.net/gh/DigneZzZ/remnawave-scripts@main/remnawave.sh) @ install-script
```

</details>

<details>
<summary><b>📂 Структура файлов</b></summary>

```text
/opt/remnawave/            # .env, docker-compose.yml, backups/, logs/
/opt/caddy-remnawave/      # Caddy (если установлен)
/usr/local/bin/remnawave   # CLI-команда
```

</details>

---

## 🛰 RemnaNode

<div align="center"><img src="assets/preview-remnanode.svg" alt="Меню remnanode" width="640"></div>

- **Xray-core** — установка и обновление из меню, включая pre-release; логи Xray в реальном времени
- **Неинтерактивный режим** — `--force --secret-key="KEY"` для массового развёртывания
- **NET_ADMIN** и миграции конфигурации добавляются автоматически при `update`
- **Ротация логов** — 50 МБ × 5 файлов, без простоя; мультиарх: x86_64 / ARM64 / ARM32 / MIPS

```bash
remnanode                 # интерактивное меню
remnanode core-update     # обновить Xray-core
remnanode xray_log_err    # ошибки Xray в реальном времени
```

<details>
<summary><b>📋 Команды CLI и флаги установки</b></summary>

| Флаг установки | Описание |
|---|---|
| `--force`, `-f` | Без подтверждений (для автоматизации) |
| `--secret-key=KEY` | SECRET_KEY из панели (обязателен с `--force`) |
| `--port=PORT` / `--xtls-port=PORT` | NODE_PORT (3000) / устаревший XTLS_API_PORT (61000, игнорируется нодой 2.8.0+) |
| `--xray` / `--no-xray` | Ставить ли Xray-core |
| `--name NAME` / `--dev` | Имя каталога / dev-образ |
| `--tag VERSION` | Запинить версию образа ноды, например `--tag 3.4.1`. Только точные версии: плавающих тегов `2`/`3` у ноды нет. Запиненная нода не двигается при `update`; `update --tag VERSION` перепинивает уже установленную ноду |

> ⚠️ **Панель 3.3.0+ обязательна только для нод 3.3.0 … 3.3.2.** Эти релизы отклоняют
> TLS-handshake, если панель не предъявляет производный SNI, — такая нода на старой панели просто
> числится офлайн (`unknown sni` в логах ноды). Установщик спрашивает об этом один раз и только
> когда запрошенный тег попадает в это окно. С ноды 3.4.0 проверка спрятана за `SNI_VERIFICATION`
> (по умолчанию выключена), поэтому `latest` работает с любой панелью; включить проверку обратно
> можно строкой `SNI_VERIFICATION=true` в `.env` ноды, если панель на 3.3.0 или новее.
>
> `up` / `restart` никогда не меняют запущенный образ — это делает только `update`. А вот сам CLI
> обновляется автоматически (через зеркала jsDelivr, если GitHub недоступен).

| Команда | Описание |
|---|---|
| `install` / `uninstall` / `update` | Жизненный цикл |
| `up` / `down` / `restart` / `status` / `logs` | Управление сервисами |
| `core-update` | Обновление Xray-core |
| `xray_log_out` / `xray_log_err` | Логи Xray в реальном времени |
| `setup-logs` / `auto-restart` | Ротация логов / автоперезапуск по расписанию |
| `install-script` | Установить или обновить **сам CLI** — контейнеры не трогаются |
| `uninstall-script` | Удалить CLI из `/usr/local/bin` |

> `install-script` — это не `install`. Она только ставит (или обновляет) команду `remnanode` на
> сервере: пригодится до установки ноды или чтобы прямо сейчас получить свежий CLI. `install`
> разворачивает сам контейнер ноды. `update` и так сначала обновляет CLI, поэтому вручную это нужно
> редко.

```bash
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh) @ install-script
# GitHub заблокирован? то же самое через зеркало:
sudo bash <(curl -Ls https://cdn.jsdelivr.net/gh/DigneZzZ/remnawave-scripts@main/remnanode.sh) @ install-script
```

```text
/opt/remnanode/            # .env, docker-compose.yml
/var/lib/remnanode/        # бинарник Xray
/usr/local/bin/remnanode   # CLI-команда
```

</details>

---

## 🎭 Caddy Selfsteal

<div align="center"><img src="assets/preview-selfsteal.svg" alt="Меню selfsteal" width="640"></div>

- **11 шаблонов сайтов** для камуфляжа: соцсети, конвертеры, файлообменники, спидтест и др.
- **Антифингерпринт** — каждый шаблон уникализируется при установке (нет байт-в-байт совпадений), следы происхождения вырезаются
- **Встроенный гайд** по интеграции с Reality (`selfsteal guide`)
- **Проверка сертификата** в меню и `status`: выдан ли на используемый домен, доверенный ли, сколько дней осталось (ACME-сертификат Caddy читается из Docker-тома)

```bash
selfsteal template list                 # список шаблонов
selfsteal template install converter    # установить шаблон
```

```jsonc
// Xray Reality: dest указывает на Caddy
{ "realitySettings": { "dest": "127.0.0.1:9443", "serverNames": ["your-domain.com"] } }
```

Подробности (HTTP/3, `--no-randomize`, структура): **[README-selfsteal.md](./README-selfsteal.md)**

---

## 🌐 WTM — WARP & Tor Manager

<div align="center"><img src="assets/preview-wtm.svg" alt="Меню wtm" width="640"></div>

- **WARP** как нативный WireGuard-outbound для Xray (без TUN-интерфейса) + поддержка **WARP+**
- **Tor** SOCKS5-прокси и маршрутизация `.onion` через Xray
- Тесты соединений, watchdog, готовые фрагменты конфигов Xray

```bash
sudo bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) @ install-script
sudo wtm    # меню; или: wtm install-all / warp-plus / status
```

Полная документация: **[README-warp.md](./README-warp.md)**

## 🐦 NetBird

<div align="center"><img src="assets/preview-netbird.svg" alt="Меню netbird" width="640"></div>

Установщик [NetBird](https://netbird.io/) mesh-VPN: CLI, cloud-init, интерактивное меню, Ansible-режим.

```bash
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/netbird.sh) install --key ВАШ-SETUP-KEY
```

Полная документация: **[README-netbird.md](./README-netbird.md)**

---

## 💾 Бэкапы и миграция

```bash
remnawave backup                     # полный бэкап (.tar.gz) или --data-only (только БД)
remnawave schedule                   # cron-расписание, ретеншн, доставка в Telegram
remnawave restore --file backup.tar.gz
```

Перед каждым `update` автоматически создаётся защитный снимок (дамп БД + конфиги) в `backups/pre-update-*`. При восстановлении проверяется совместимость версий панели.

<details>
<summary><b>🚚 Перенос на другой сервер и ручное восстановление</b></summary>

```bash
# 1. На старом сервере
remnawave backup
# 2. Перенесите архив (scp) на новый сервер
# 3. На новом сервере
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh) @ install --name remnawave
remnawave restore --file backup.tar.gz
```

Если автоматика не сработала — ручное восстановление БД:

```bash
sudo remnawave down
cat database.sql | docker exec -i -e PGPASSWORD="пароль" remnawave-db psql -U postgres -d postgres
sudo remnawave up
```

> ⚠️ При восстановлении БД на **новую** установку не забудьте перенести секрет из старого `.env`: `APP_SECRET` (panel v3+) или `JWT_AUTH_SECRET`+`JWT_API_TOKENS_SECRET` (v2) — иначе получите 403 при входе.

</details>

---

## ⚙️ Требования и безопасность

**ОС:** Ubuntu 18.04+ / Debian 10+ / CentOS 7+ / AlmaLinux 8+ / Fedora 32+ / Arch / openSUSE 15+ · **Минимум:** 1 CPU, 512 МБ RAM · **Рекомендуется:** 2+ CPU, 2 ГБ RAM, SSD
**Зависимости** (ставятся сами): Docker + Compose v2, curl, openssl, jq

- Все сервисы слушают только `127.0.0.1`; наружу — через Caddy с авто-SSL
- Секреты, пароли БД и API-токены генерируются автоматически
- Диагностика: `remnawave status` / `logs --follow` / пункт меню «Health check»

<details>
<summary><b>🔒 Hardening для production (UFW)</b></summary>

```bash
sudo ufw default deny incoming && sudo ufw default allow outgoing
sudo ufw allow ssh && sudo ufw allow 443/tcp
sudo ufw enable
```

</details>

---

<div align="center">

**⭐ Если проект полезен — поставьте звёздочку!**

[Сообщить об ошибке](https://github.com/DigneZzZ/remnawave-scripts/issues) · [Предложить улучшение](https://github.com/DigneZzZ/remnawave-scripts/issues) · [Сообщество gig.ovh](https://gig.ovh) · [MIT License](./LICENSE)

*PR приветствуются: fork → ветка → изменения → PR. Тестируйте на нескольких дистрибутивах.*

</div>
