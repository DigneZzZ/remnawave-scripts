# 🌐 WTM - WARP & Tor Manager v1.4.0 - Профессиональное управление анонимными сетями

**WTM** - это комплексный bash-скрипт для автоматизации установки и управления **Cloudflare WARP** и **Tor** на Linux серверах.

🆕 **Версия v1.4.0** — современная интеграция WARP в ядро **Xray** через нативный `wireguard` outbound, безопасное самообновление, исправление опасного апгрейда ОС и крупный рефакторинг.

### Релиз от проектов [GIG.ovh](https://gig.ovh) и [OpeNode.xyz](https://openode.xyz)

![изображение](https://github.com/user-attachments/assets/907d9304-cd7d-4897-8e24-ea8086924a0a)

## 📋 Возможности

### 🚀 Основные функции

- **Автоматическая установка** Cloudflare WARP через WireGuard
- **Автоматическая установка** Tor с усиленной конфигурацией
- **Нативная интеграция WARP в Xray** — генерация готового `wireguard` outbound (🆕 v1.4.0)
- **Динамическая генерация пароля** Tor Control Port
- **Интерактивное меню** для удобного управления
- **Безопасная система автообновления** с проверкой целостности (🆕 v1.4.0)
- **Мониторинг состояния** сервисов в реальном времени
- **Тестирование соединений** для проверки работоспособности
- **Принудительная переустановка** флагом `--force` (теперь действительно работает — 🆕 v1.4.0)
- **Глобальная установка** в `/usr/local/bin/wtm` для системного доступа
- **Логирование действий** в `/var/log/wtm.log`
- **Полноценная CLI справка** `wtm --help`

## 💾 Изменения в v1.4.0

### 🎯 Интеграция с Xray (главное)
- **Нативный `wireguard` outbound** вместо устаревшего `freedom` + `sockopt.interface:"warp"`. Xray (с версии 1.6.5, актуально для текущей ветки v26.x) подключается к WARP **напрямую** — без kernel-интерфейса, `wg-quick` и `/etc/wireguard/warp.conf`. Это обходит конфликт kernel-WireGuard / `rp_filter`, из-за которого ноды падали в контейнерах.
- При установке WARP скрипт **сохраняет ключи и генерирует готовый Xray-сниппет** с вашими реальными значениями: `/etc/wireguard/warp-xray-outbound.json`. Раздел «XRay Configuration» в меню показывает именно ваш конфиг, а не плейсхолдеры.
- Учтены актуальные изменения схемы Xray: убран устаревший `"type": "field"`, поле `kernelMode` заменено на `noKernelTun` (для Docker / read-only хостов — `"noKernelTun": true`), добавлены оговорки про `geosite.dat`/`geoip.dat`.

### 🐛 Критические исправления
- **wgcf-регистрация починена**: `yes | wgcf register` больше не работает (современный wgcf прячет согласие с ToS за интерактивным TTY-промптом) → используется `wgcf register --accept-tos` с ретраями и выводом ошибок.
- **Опасный апгрейд ОС убран**: на RHEL/Rocky/Alma/Fedora `yum/dnf update -y` выполнял **полный апгрейд системы** (ядро, glibc…) при любой установке → заменено на `makecache` (только метаданные).
- **Безопасное самообновление**: `curl -sSL | install /dev/stdin` (молча писал битый файл при 404/обрыве и рапортовал «успех») заменено двухстадийной загрузкой с валидацией shebang+версии и проверкой реальной смены версии.
- **Флаг `--force`/`-f` теперь работает** — раньше парсился в неиспользуемую переменную, и `install-warp --force` молча делал обычную установку.

### 🔒 Безопасность и надёжность
- **Tor**: порты явно привязаны к `127.0.0.1`, добавлен `SocksPolicy accept 127.0.0.1 / reject *`, убран бесполезный `ConnLimit 1000`, надёжная генерация хэша control-пароля.
- **wgcf** скачивается во временную папку с проверкой целостности (не в текущий каталог).
- **systemctl**-операции рапортуют реальный результат (раньше любой сбой показывался зелёной галочкой).
- **EL8**: автоматически ставится `elrepo-release` + `kmod-wireguard` (модуля WireGuard нет in-tree на EL8; на EL9+ он встроен).
- Корректный strip IPv6, `cd` в подоболочке, очистка временных файлов.

### ♻️ Рефакторинг
- `set -eE` → `set -E` + диагностический ERR-trap: интерактивное меню больше не падает на «нормальных» ненулевых кодах возврата.
- Дедупликация блоков статуса (`render_warp_status_block` / `render_tor_status_block`), пакеты передаются массивами, `ss` приоритетнее `netstat`, редактор конфигов через `$EDITOR` (не хардкод `nano`).

## 💾 Система автообновления

**🔄 Умная система версионирования:**
- **Автоматическая проверка** новых версий при запуске интерактивного режима
- **Безопасное обновление** с двухстадийной загрузкой и проверкой целостности (🆕 v1.4.0)
- **Глобальная установка** в `/usr/local/bin/wtm` для системного доступа
- **Защита от битых обновлений** — версия на диске сверяется после установки

```bash
# Проверка текущей версии
wtm version                          # Полная информация о версии

# Проверка обновлений
wtm check-updates                    # Сравнение с GitHub

# Автоматическое обновление
sudo wtm self-update                 # Обновление до последней версии
sudo wtm update                      # Альтернативная команда
```

**Особенности системы обновлений:**
- **Единый URL обновлений** — совместимость с репозиторием remnawave-scripts
- **Проверка прав доступа** — требование root для обновления
- **Валидация загрузки** — проверка shebang, `# VERSION=` и фактической смены версии
- **Интерактивное меню обновлений** — пункт 9 в главном меню
- **Определение версии** через `# VERSION=` в заголовке скрипта

### ⚙️ Управление сервисами
- Запуск/остановка/перезапуск сервисов с реальной проверкой статуса
- Просмотр логов в реальном времени
- Отображение потребления памяти
- Проверка статуса портов и интерфейсов
- Удаление сервисов с очисткой конфигураций и ключей

### 📊 Мониторинг
- Статус WARP (WireGuard интерфейс)
- Статус Tor (SOCKS5 и Control порты)
- Системная информация (RAM, IP, архитектура)
- Тестирование подключений через каждый прокси
- Верификация через Cloudflare Trace API

### 🔧 Конфигурация
- Готовый нативный `wireguard` outbound для Xray (`/etc/wireguard/warp-xray-outbound.json`)
- Примеры роутинга .onion через Tor и стриминга/рекламы через WARP
- Примеры использования curl, ssh, git с прокси

## 📦 Быстрая установка и настройка

Всего одна команда для глобальной установки:

```bash
# Установка как глобальная команда
sudo bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) @ install-script

# Или прямой запуск
bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh)
```

### 🎯 Умная автоматическая установка

WTM автоматически устанавливается как глобальная команда при любой операции установки:

```bash
# Любая из этих команд автоматически установит wtm глобально
sudo bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) install-warp
sudo bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) install-all
# После этого просто используйте: wtm command
```

**Преимущества автоматической установки:**

- 🚀 **Мгновенный доступ** - команда `wtm` доступна сразу после установки
- 🔄 **Нет дублирования** - умная система предотвращает повторные установки
- 💾 **Безопасность** - валидация загруженного скрипта перед установкой
- 📱 **Удобство** - работает как в интерактивном, так и в командном режиме

### Альтернативный способ

```bash
# Скачать и установить скрипт в одну команду
sudo wget https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/wtm.sh -O /usr/local/bin/wtm && sudo chmod +x /usr/local/bin/wtm

# Запустить интерактивное меню
sudo wtm
```

### Из репозитория

```bash
# Клонировать весь репозиторий
git clone https://github.com/DigneZzZ/remnawave-scripts.git
cd remnawave-scripts

# Установить скрипт глобально
sudo cp wtm.sh /usr/local/bin/wtm && sudo chmod +x /usr/local/bin/wtm

# Запустить скрипт
sudo wtm
```

### 🚀 Быстрый старт

После установки просто выполните:

```bash
# Открыть интерактивное меню
sudo wtm

# Или установить всё сразу
sudo wtm install-all
```

## 🚀 Быстрые команды

### Установка сервисов

```bash
# Установить только WARP
sudo wtm install-warp

# Установить только Tor  
sudo wtm install-tor

# Установить оба сервиса (рекомендуется)
sudo wtm install-all
```

### 🔄 Принудительная установка (перезапись существующих)

```bash
# Принудительно переустановить WARP
sudo wtm install-warp-force
sudo wtm install-warp --force        # эквивалент (🆕 v1.4.0: флаг работает)

# Принудительно переустановить Tor
sudo wtm install-tor-force

# Принудительно переустановить оба
sudo wtm install-all-force
```

### ⚙️ Управление сервисами

```bash
# Проверить статус
sudo wtm status

# Запустить/остановить WARP
sudo wtm start-warp
sudo wtm stop-warp
sudo wtm restart-warp

# Запустить/остановить Tor
sudo wtm start-tor
sudo wtm stop-tor  
sudo wtm restart-tor
```

### 📊 Мониторинг и диагностика

```bash
# Тестировать все соединения
sudo wtm test

# Просмотр логов
sudo wtm logs-warp
sudo wtm logs-tor

# Системная информация
sudo wtm system-info
```

### 📖 Справка и документация

```bash
# Общая справка
sudo wtm help

# Примеры использования
sudo wtm usage-examples

# Примеры конфигурации XRay (включая ваш сгенерированный outbound)
sudo wtm xray-examples

# Проверка версии и обновлений
wtm version
wtm check-updates
sudo wtm self-update
```

## 🎨 Интерактивное меню - Профессиональный интерфейс

### 🖥️ Главное меню

```
🌐 WARP & Tor Manager v1.4.0
──────────────────────────────────────────────────

🛠️  Service Management:
   1) 📡 WARP Menu
   2) 🧅 Tor Menu  
   3) 🔄 Quick Actions

📊 Monitoring & Tools:
   4) 🧪 Test Connections
   5) 📋 View Logs
   6) 💻 System Information

📖 Configuration:
   7) ⚙️  XRay Configuration
   8) ❓ Help & Usage Examples
   9) 🔄 Check Updates

   0) 🚪 Exit
```

### 🎯 Умные подсказки

Контекстные советы в зависимости от состояния системы:
- **Новая установка**: "Start with WARP Menu (1) or Tor Menu (2)"
- **Активные сервисы**: "Test connections (4) to verify everything works"
- **Частично настроенная**: "Use service menus to start installed components"

## 🔧 Системные требования

### Минимальные требования:
- **ОС**: Ubuntu 20.04+, Debian 11+, RHEL/Rocky/AlmaLinux 8+, Fedora 35+
- **Права**: root доступ (sudo)
- **RAM**: 1GB свободной памяти
- **Сеть**: доступ в интернет

### Поддерживаемые дистрибутивы:
- Ubuntu (20.04, 22.04, 24.04)
- Debian (11, 12)
- RHEL / Rocky Linux / AlmaLinux (8, 9) — на EL8 модуль WireGuard ставится из ELRepo автоматически
- Fedora (35+)

### Требуемые пакеты (устанавливаются автоматически):
- `wireguard-tools` - для WARP (+ `kmod-wireguard` на EL8)
- `tor` - Tor прокси  
- `curl`, `wget` - для загрузки компонентов
- `wgcf` - генерация конфигурации WARP (скачивается с GitHub во временную папку)

## 📡 Порты, сервисы и файлы

### WARP (WireGuard):
- **Интерфейс**: `warp`
- **Сервис**: `wg-quick@warp`
- **Конфиг wg-quick**: `/etc/wireguard/warp.conf`
- **Учётные данные wgcf**: `/etc/wireguard/wgcf-account.toml` (права 600)
- **Готовый Xray outbound**: `/etc/wireguard/warp-xray-outbound.json` (🆕 v1.4.0)
- **Endpoint**: `engage.cloudflareclient.com:2408`

### Tor:
- **SOCKS5 порт**: `127.0.0.1:9050`
- **Control порт**: `127.0.0.1:9051`
- **Сервис**: `tor`
- **Конфиг**: `/etc/tor/torrc`
- **Логи**: `/var/log/tor/tor.log`
- **Пароль Control**: `/etc/tor/.control_password` (генерируется автоматически, если доступно хэширование)

## 🔍 Примеры использования

### Тестирование соединений:
```bash
# Прямое соединение
curl ifconfig.me

# Через WARP (host-интерфейс)
curl --interface warp ifconfig.me

# Через Tor
curl --socks5 127.0.0.1:9050 ifconfig.me
```

### ProxyChains конфигурация:
```bash
# /etc/proxychains.conf
socks5 127.0.0.1 9050
```

## 🎯 Интеграция с XRay

> 🆕 **v1.4.0:** рекомендуемый способ — **нативный `wireguard` outbound**. Xray подключается к WARP напрямую, без host-интерфейса `wg-quick@warp`. Это надёжнее в контейнерах и не требует прав на изменение `rp_filter`.

После `sudo wtm install-warp` готовый outbound с **вашими** ключами лежит в
`/etc/wireguard/warp-xray-outbound.json`. Команда `sudo wtm xray-examples`
покажет его содержимое.

### Нативный WARP outbound (рекомендуется)

```json
{
  "tag": "warp",
  "protocol": "wireguard",
  "settings": {
    "secretKey": "<wgcf PrivateKey>",
    "address": ["172.16.0.2/32", "2606:4700:110:...:c8e1/128"],
    "peers": [
      {
        "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
        "endpoint": "engage.cloudflareclient.com:2408",
        "allowedIPs": ["0.0.0.0/0", "::/0"]
      }
    ],
    "reserved": [0, 0, 0],
    "mtu": 1280
  }
}
```

- В Docker / на read-only или непривилегированных хостах добавьте `"noKernelTun": true`.
- Для отдельных PoP Cloudflare нужен реальный `reserved` (из `wgcf-cli generate --xray` или `warp-reg`).
- На `wireguard` outbound **нельзя** вешать `streamSettings`/`sockopt`; для цепочки используйте `dialerProxy` на другом outbound.

### Полный пример: WARP + Tor + роутинг

```json
{
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    {
      "tag": "warp",
      "protocol": "wireguard",
      "settings": {
        "secretKey": "<wgcf PrivateKey>",
        "address": ["172.16.0.2/32"],
        "peers": [
          {
            "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
            "endpoint": "engage.cloudflareclient.com:2408"
          }
        ],
        "reserved": [0, 0, 0]
      }
    },
    {
      "tag": "tor",
      "protocol": "socks",
      "settings": {
        "servers": [{ "address": "127.0.0.1", "port": 9050 }]
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "inboundTag": ["VTR-USA", "VTR-NL", "to-foreign-inbound"],
        "outboundTag": "tor",
        "domain": ["regexp:.*\\.onion$"]
      },
      {
        "inboundTag": ["VTR-USA", "VTR-NL", "to-foreign-inbound"],
        "outboundTag": "warp",
        "domain": [
          "geosite:category-ads-all",
          "geosite:google",
          "geosite:cloudflare",
          "geosite:youtube",
          "geosite:netflix"
        ]
      },
      {
        "inboundTag": ["VTR-RU", "VTR-LOCAL", "local-inbound"],
        "outboundTag": "direct",
        "domain": ["geosite:private", "geosite:cn", "geosite:ru"]
      }
    ]
  }
}
```

### 🔀 Маршрутизация трафика

- **.onion домены** → Tor SOCKS5 (`127.0.0.1:9050`)
- **Реклама / стриминг с иностранных inbound'ов** → WARP (нативный `wireguard`)
- **Локальные inbound'ы + Private/RU/CN** → прямое подключение

> **Примечание:** `"type": "field"` в правилах роутинга в актуальном Xray больше **не нужен** (удалён/игнорируется). Теги `geosite:`/`geoip:` требуют наличия `geosite.dat`/`geoip.dat` в `/usr/local/share/xray/` (или задайте `XRAY_LOCATION_ASSET`).

### 🧩 Legacy: host-интерфейсный вариант

Скрипт по-прежнему поднимает kernel-интерфейс `wg-quick@warp` — он удобен для
хостовых утилит (`curl --interface warp`). Для **Xray** же предпочтительнее
нативный outbound выше: старый вариант `freedom` + `sockopt.interface:"warp"`
зависит от этого kernel-интерфейса и часто не работает в контейнерах.

## 🛠️ Устранение неполадок

### Общие проблемы:

#### WARP не подключается:
```bash
# Проверить интерфейс
ip link show warp

# Проверить конфигурацию
cat /etc/wireguard/warp.conf

# Перезапустить сервис
sudo systemctl restart wg-quick@warp

# Логи сервиса
sudo journalctl -u wg-quick@warp -n 30 --no-pager
```

#### Регистрация WARP падает (Cloudflare 5xx):
```bash
# Cloudflare иногда отдаёт временные ошибки регистрации — скрипт делает
# до 3 попыток. Можно повторить установку чуть позже:
sudo wtm install-warp-force
```

#### Tor не работает:
```bash
# Проверить порты
ss -tlnp | grep ':9050\|:9051'

# Проверить логи
sudo journalctl -u tor -f

# Проверить конфигурацию
sudo tor --verify-config
```

#### Конфликт портов:
```bash
# Найти процесс, использующий порт (ss предпочтительнее netstat)
sudo ss -tlnp | grep ':9050'
sudo lsof -i :9050

# Остановить конфликтующий сервис
sudo systemctl stop service-name
```

### Диагностические команды:
```bash
# Статус всех сервисов
sudo wtm status

# Тест соединений
sudo wtm test

# Полная диагностика
sudo wtm system-info
```

## 📚 Дополнительные ресурсы

### Официальная документация:
- [Cloudflare WARP](https://developers.cloudflare.com/warp-client/)
- [WireGuard](https://www.wireguard.com/quickstart/)
- [Tor Project](https://www.torproject.org/docs/)
- [XRay — WireGuard outbound](https://xtls.github.io/config/outbounds/wireguard.html)
- [XRay — WARP guide](https://xtls.github.io/document/level-2/warp.html)
- [wgcf](https://github.com/ViRb3/wgcf)

## 🔗 Ресурсы и поддержка

- **GitHub Repository**: [https://github.com/DigneZzZ/remnawave-scripts](https://github.com/DigneZzZ/remnawave-scripts)
- **WTM Documentation**: Полная документация в README-warp.md
- **Issue Tracker**: Приветствуются баг-репорты и предложения
- **Project Website**: [https://gig.ovh](https://gig.ovh)

### 🎓 Обучающие материалы

- **XRay конфигурации** с нативным WARP outbound + Tor
- **Тестовые команды** для проверки анонимности

## 🎉 Заключение

✅ **Простота**: Установка в одну команду, интуитивное меню  
✅ **Надежность**: Безопасное самообновление, реальная проверка статуса сервисов  
✅ **Актуальность**: Нативная интеграция WARP в современный Xray (v26.x)  
✅ **Гибкость**: От домашнего использования до enterprise-решений  
✅ **Интеграция**: Часть экосистемы remnawave-scripts

---

**Версия**: v1.4.0  
**Последнее обновление**: 29 июня 2026  
**Автор**: DigneZzZ  
**Проект**: [https://gig.ovh](https://gig.ovh)
