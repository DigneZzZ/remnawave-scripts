<div align="center">

# 🎭 Selfsteal — Caddy/Nginx для Reality

[![Версия](https://img.shields.io/badge/selfsteal.sh-2.10.0-blue.svg)](#-что-нового)
[![Веб-сервер](https://img.shields.io/badge/Caddy_%7C_Nginx-supported-brightgreen.svg)](#-сравнение-caddy-vs-nginx)
[![Шаблоны](https://img.shields.io/badge/шаблонов-11_AI--generated-purple.svg)](#-шаблоны-сайтов)
[![Лицензия MIT](https://img.shields.io/badge/Лицензия-MIT-yellow.svg)](./LICENSE)

<img src="assets/preview-selfsteal.svg" alt="Меню selfsteal" width="640">

**[Установка](#-установка)** · **[Команды](#-команды)** · **[Caddy vs Nginx](#-сравнение-caddy-vs-nginx)** · **[Шаблоны](#-шаблоны-сайтов)** · **[Конфиг Xray](#-конфигурация-xray-reality)** · **[Главный README](./README_RU.md)**

</div>

Автоматическая установка и управление веб-сервером (**Caddy** или **Nginx**) для маскировки трафика **Reality** в связке с Xray. Порт 443 остаётся полностью за Xray — веб-сервер получает трафик от него через внутренний порт или Unix socket с proxy_protocol и отдаёт сайт-обманку с антифингерпринт-уникализацией.

Проект [gig.ovh](https://gig.ovh) · Автор: [DigneZzZ](https://github.com/DigneZzZ)

## 🆕 Что нового

| Версия | Главное |
|---|---|
| **2.10.0** | `selfsteal reissue-cert` — принудительный перевыпуск сертификата Caddy одной командой (с бэкапом и автооткатом при неудаче) |
| **2.9.0** | Устойчивое получение Docker-образов: fallback на зеркала, когда Docker Hub недоступен/заблокирован |
| **2.8.x** | Антифингерпринт-мутация шаблонов при установке, HTTP/3 выключен по умолчанию (`--h3` для включения), Caddy 2.11.4, `admin off` против boot-loop |

## 🏗 Архитектура

Веб-сервер **не слушает порт 443** — он полностью принадлежит Xray. При активной пробе Reality форвардит соединение на dest, и пробер получает настоящий сайт.

```
Интернет ──:443──▶ Xray (Reality, VLESS) ──proxy_protocol──▶ веб-сервер
                                                │
                     Caddy:  127.0.0.1:9443 (TCP)
                     Nginx:  /dev/shm/nginx.sock (Unix socket, по умолчанию) или TCP
```

**Порты:** `443` — только Xray · `9443` — внутренний TCP веб-сервера (Caddy или Nginx `--tcp`) · `80` — HTTP→HTTPS редирект · `8443+` — ACME TLS-ALPN для Nginx (автоперебор 8443→9443→10443→18443→28443 или `--acme-port`).

## ⚡ Установка

```bash
# Caddy (по умолчанию)
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ install

# Nginx с Unix socket (рекомендуется — см. сравнение ниже)
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ --nginx install

# Nginx с TCP-портом вместо socket
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ --nginx --tcp install
```

<details>
<summary><b>🚀 Force-режим для автоматизации (CI/CD, массовый деплой)</b></summary>

```bash
# Базовая force-установка (без интерактивных запросов и DNS-проверки)
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ --nginx --force --domain reality.example.com install

# С конкретным портом и шаблоном
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ --nginx --force --domain reality.example.com --port 8443 --template 5 install

# С ручным wildcard-сертификатом (Nginx или Caddy)
bash <(curl -Ls https://github.com/DigneZzZ/remnawave-scripts/raw/main/selfsteal.sh) @ --nginx --force --domain reality.example.com \
    --ssl-cert /path/to/fullchain.crt --ssl-key /path/to/private.key install
```

| Опция | Описание |
|---|---|
| `--force`, `-f` | Пропустить проверку DNS и все интерактивные запросы |
| `--domain <domain>` | Домен (обязателен с `--force`) |
| `--port <port>` | Внутренний HTTPS-порт (по умолчанию 9443) |
| `--template <1-11>` | Номер шаблона (иначе случайный) |
| `--ssl-cert` / `--ssl-key` | Ручной сертификат (fullchain) и ключ |
| `--h3`, `--quic` | Включить HTTP/3 у Caddy (по умолчанию **выкл**) |
| `--socket` / `--tcp` | Nginx: Unix socket (дефолт) / TCP-порт |
| `--acme-port <port>` | Nginx: конкретный порт для ACME TLS-ALPN |
| `--no-randomize` | Отключить антифингерпринт-мутацию шаблона |

Без `--ssl-cert` в force-режиме скрипт пробует ACME; при неудаче — self-signed.

</details>

## 📋 Команды

```bash
selfsteal          # интерактивное меню
```

| Команда | Описание |
|---|---|
| `install` / `uninstall` | Установка / удаление (только один веб-сервер одновременно) |
| `up` / `down` / `restart` / `status` / `logs` | Управление сервисами, статус с информацией о SSL |
| `template` | Выбор/смена шаблона (с бэкапом предыдущего) |
| `edit` | Редактирование конфигурации |
| `renew-ssl` | Обновить сертификат (Caddy — форс-перевыпуск, Nginx — acme.sh) |
| `reissue-cert [-f]` | Caddy: принудительный перевыпуск с бэкапом и автооткатом |
| `guide` | Гайд по интеграции с Reality |
| `update` | Обновление скрипта |

## ⚖️ Сравнение Caddy vs Nginx

| | Caddy | Nginx |
|---|---|---|
| SSL | Автоматически (ACME HTTP-01 на :80) | ACME TLS-ALPN (8443+, автоперебор) через acme.sh |
| Ручные сертификаты | ✅ `--ssl-cert/--ssl-key` | ✅ `--ssl-cert/--ssl-key` |
| Подключение от Xray | TCP `127.0.0.1:9443` | **Unix socket** `/dev/shm/nginx.sock` (или TCP) |
| Путь установки | `/opt/caddy` | `/opt/nginx-selfsteal` |
| HTTP/3 (QUIC) | Выкл по умолчанию (вкл `--h3`) | Не используется |
| **TLS-отпечаток** | Go `crypto/tls` — узнаваемый JARM/JA3S | **OpenSSL — как у обычных сайтов** |
| Обновление SSL | Автоматически / `reissue-cert` | `renew-ssl` |

> 🛡️ **Устойчивость к активному пробингу (РКН/ТСПУ).** При пробе Reality пробер завершает настоящее TLS-рукопожатие с веб-сервером. Отпечаток Go `crypto/tls` у Caddy (JARM/JA3S, HTTP/2 SETTINGS) **нельзя изменить средствами Caddy**; Nginx на OpenSSL выглядит как обычный сайт. При жёстком пробинге **Nginx как dest объективно «тише»** — если бан повторяется даже после отключения h3, переходите на `--nginx`. В острые периоды также помогает увод Reality с 443 на высокий порт (47000+).

> 🔒 **Почему HTTP/3 выключен.** Reality проксирует только TCP, поэтому dest, анонсирующий QUIC по UDP (которого там нет), создаёт лишний отпечаток. Включайте `--h3` только осознанно.

**Unix socket у Nginx**: быстрее (нет TCP-стека), не занимает порт, нет конфликтов. Требует проброса `/dev/shm` в контейнер Xray — см. [настройку ниже](#-unix-socket--xray-в-docker).

## 🎨 Шаблоны сайтов

11 AI-генерированных шаблонов; при первой установке выбирается случайный. Скрипт качает их из каталога [`sni-templates/`](https://github.com/DigneZzZ/remnawave-scripts/tree/main/sni-templates) этого репозитория (оригинальная коллекция — [SmallPoppa/sni-templates](https://github.com/SmallPoppa/sni-templates)):

`10gag` (мемы) · `converter` (видеоконвертер) · `convertit` (конвертер файлов, самый «тихий» — без внешних CDN) · `downloader` · `filecloud` (облако с формой логина) · `games-site` (ретро-игры) · `modmanager` · `speedtest` (RU-локализация) · `YouTube` (с бесконечной капчей) · `503 Error v1/v2` (страницы ошибок)

```bash
selfsteal template          # интерактивный выбор с превью и бэкапом текущего
```

### 🛡️ Антифингерпринт-уникализация (v2.8.0+)

Базовые шаблоны публичны и байт-в-байт совпадают у всех — цензор может хешировать страницу и вносить в чёрный список. Поэтому при установке шаблон **автоматически мутируется**:

- 🎲 **Уникальность инстанса**: случайные `<title>`/бренд/meta, per-install сдвиг палитры (hue-rotate), байт-«шум» в html/css/js, рандомный `?v=`, свежий `favicon.svg` — два сервера никогда не отдают идентичные файлы
- 🧹 **Зачистка утечек**: удаляются `README.md`/`*.md`/`*.map` (ссылки на исходный репозиторий), глушится «маяк» на `api.ipify.org`, убираются внешние Google Fonts, чинятся `vite.svg` и `site.webmanifest`

Отключение (для отладки): `--no-randomize`.

> ⚠️ Контент с иностранных CDN (giphy/unsplash/pexels) вшит в минифицированные бандлы части шаблонов — его не убрать без поломки страницы. Мутация ломает совпадение по хешу, но **не меняет TLS-отпечаток веб-сервера** (см. сравнение выше).

## 🔧 Конфигурация Xray Reality

### Nginx с Unix socket (рекомендуется)

```json
{
    "inbounds": [{
        "tag": "VLESS_REALITY_NGINX_SOCKET",
        "port": 443,
        "protocol": "vless",
        "settings": { "clients": [], "decryption": "none" },
        "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] },
        "streamSettings": {
            "network": "raw",
            "security": "reality",
            "realitySettings": {
                "show": false,
                "xver": 1,
                "target": "/dev/shm/nginx.sock",
                "spiderX": "/",
                "shortIds": [""],
                "privateKey": "#REPLACE_WITH_YOUR_PRIVATE_KEY",
                "serverNames": ["reality.example.com"]
            }
        }
    }]
}
```

### Caddy или Nginx с TCP-портом

Отличие одно: `"target": "127.0.0.1:9443"` вместо пути к сокету.

| Параметр | Значение |
|---|---|
| `target` | `/dev/shm/nginx.sock` (socket) или `127.0.0.1:9443` (TCP) |
| `xver` | Всегда `1` (proxy_protocol v1) |
| `serverNames` | Домен, указанный при установке |
| `privateKey` / `shortIds` | Ваши ключи Reality |

> ⚠️ При добавлении хоста в панели принудительно укажите **SNI** и **Host** такими же, как в `serverNames`.

<img width="438" alt="Настройки хоста в панели" src="https://github.com/user-attachments/assets/57f00a62-1cad-4225-825c-23ed6a779744" />

## 🐳 Unix socket + Xray в Docker

Socket создаётся в `/dev/shm/nginx.sock`; Docker-контейнер Xray (например, remnanode) имеет **изолированный** `/dev/shm` и не видит его. При установке скрипт **сам находит** контейнеры `remnanode`/`xray`/`marzban` и предлагает автоматически добавить volume. Вручную:

```yaml
services:
  remnanode:
    volumes:
      - /dev/shm:/dev/shm   # ← добавить
```

```bash
cd /opt/remnanode && docker compose down && docker compose up -d
docker exec remnanode ls -la /dev/shm/nginx.sock   # проверка
```

## 🛠 Устранение неполадок

<details>
<summary><b>Caddy «застрял» на self-signed / старом сертификате</b></summary>

```bash
selfsteal reissue-cert        # интерактивно
selfsteal reissue-cert -f     # без подтверждения
```

Останавливает Caddy, **бэкапит** текущий сертификат, чистит `/data/caddy/certificates` и запускает Caddy заново — тот запрашивает свежий сертификат (ACME HTTP-01 на :80). Скрипт ждёт до 90 с и проверяет, что выдан публично доверенный сертификат; при неудаче (закрыт :80, кривой DNS, лимиты CA) **автоматически восстанавливает прежний**, чтобы маскировка не осталась без TLS.

> ⚠️ Let's Encrypt лимитирует дубликаты (~5/неделю на домен) — используйте для восстановления, не по расписанию.

</details>

<details>
<summary><b>Контейнер не стартует / образ не тянется</b></summary>

```bash
selfsteal logs
docker logs caddy-selfsteal 2>&1 | tail -30
ss -tlnp | grep ':80\|:9443'      # порты свободны?
```

С v2.9.0 при недоступном Docker Hub образы автоматически тянутся через зеркала — если и они недоступны, проверьте сетевую связность/registry-mirrors.

</details>

<details>
<summary><b>SSL не выдаётся / сайт не отображается</b></summary>

```bash
dig your-domain.com A             # DNS указывает на сервер?
ls -la /opt/nginx-selfsteal/html/ # файлы шаблона на месте?
selfsteal status                  # статус + информация о сертификате
```

Для Nginx ACME нужен свободный порт из ряда 8443+ (или задайте `--acme-port`); порт нужен только на время выпуска/обновления.

</details>

**Файлы:** `/opt/caddy/` или `/opt/nginx-selfsteal/` (docker-compose.yml, Caddyfile/nginx.conf, `.env`, `html/`, `logs/`) · CLI: `/usr/local/bin/selfsteal`. Логи ротируются (лимит 50 МБ, очистка из меню). `.env` и конфиги содержат домен и настройки TLS — берегите их.

---

<div align="center">

**Ресурсы:** [Reality (XTLS)](https://github.com/XTLS/REALITY) · [Caddy](https://caddyserver.com/docs/) · [шаблоны сайтов](https://github.com/DigneZzZ/remnawave-scripts/tree/main/sni-templates)

[Сообщить об ошибке](https://github.com/DigneZzZ/remnawave-scripts/issues) · [Сообщество gig.ovh](https://gig.ovh) · Автор: **DigneZzZ** · [MIT License](./LICENSE)

</div>
