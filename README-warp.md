# 🌐 WTM - WARP & Tor Manager v1.2.1 - Профессиональное управление анонимными сетями

**WTM** - это комплексный bash-скрипт корпоративного уровня для управления анонимными сетевыми подключениями. Современный инструмент для автоматизации установки и управления **Cloudflare WARP** и **Tor** на Linux серверах.

🆕 **Версия v1.2.1** включает революционную систему автообновления, интерактивные меню и профессиональную диагностику сетевых подключений!

### Релиз от проектов [GIG.ovh](https://gig.ovh) и [OpeNode.xyz](https://openode.xyz)

![изображение](https://github.com/user-attachments/assets/907d9304-cd7d-4897-8e24-ea8086924a0a)

## 📋 Возможности

### 🚀 Основные функции

- **Автоматическая установка** Cloudflare WARP через WireGuard
- **Автоматическая установка** Tor с оптимизированной конфигурацией  
- **Интерактивное меню** для удобного управления
- **Система автообновления** с проверкой новых версий
- **Мониторинг состояния** сервисов в реальном времени
- **Тестирование соединений** для проверки работоспособности
- **Принудительная переустановка** с флагом --force
- **Глобальная установка** в `/usr/local/bin/wtm` для системного доступа

## 💾 Система автообновления - Главная особенность v1.2.1

**🔄 Умная система версионирования:**
- **Автоматическая проверка** новых версий при запуске интерактивного режима
- **Безопасное обновление** с проверкой целостности файлов
- **Глобальная установка** в `/usr/local/bin/wtm` для системного доступа
- **Откат изменений** при неудачном обновлении

```bash
# Проверка текущей версии
wtm version                          # Полная информация о версии

# Проверка обновлений
wtm check-updates                    # Сравнение с GitHub

# Автоматическое обновление
sudo wtm self-update                 # Обновление до последней версии
sudo wtm update                      # Альтернативная команда
```

**Новые возможности v1.2.1:**
- **Единый URL обновлений** - совместимость с репозиторием remnawave-scripts
- **Проверка прав доступа** - требование root для обновления
- **Версионная совместимость** - автоматическая миграция конфигураций
- **Интерактивное меню обновлений** - пункт 9 в главном меню

### ⚙️ Управление сервисами
- Запуск/остановка/перезапуск сервисов
- Просмотр логов в реальном времени  
- Отображение потребления памяти
- Проверка статуса портов и интерфейсов
- Удаление сервисов с очисткой конфигураций

### 📊 Мониторинг
- Статус WARP (WireGuard интерфейс)
- Статус Tor (SOCKS5 и Control порты)
- Системная информация (RAM, IP, архитектура)
- Тестирование подключений через каждый прокси
- Верификация через Cloudflare Trace API

### 🔧 Конфигурация
- Примеры для XRay с роутингом .onion через Tor
- Серверные inbound конфигурации
- Балансировка нагрузки между inbound'ами
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

**Новинка v1.2.1:** WTM теперь автоматически устанавливается как глобальная команда при любой операции установки:

```bash
# Любая из этих команд автоматически установит wtm глобально
sudo bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) install-warp
sudo bash <(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh) install-all
# После этого просто используйте: wtm command
```

**Преимущества автоматической установки:**

- 🚀 **Мгновенный доступ** - команда `wtm` доступна сразу после установки
- 🔄 **Нет дублирования** - умная система предотвращает повторные установки
- 💾 **Безопасность** - установка только при необходимости
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
# Список всех команд
sudo wtm commands

# Общая справка
sudo wtm help

# Примеры использования
sudo wtm usage-examples

# Примеры конфигурации XRay
sudo wtm xray-examples

# Проверка версии и обновлений
wtm version
wtm check-updates
sudo wtm self-update
```

## 🎨 Интерактивное меню - Профессиональный интерфейс

### 🖥️ Главное меню

```
🌐 WARP & Tor Manager v1.2.1
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
   9) 🔄 Check Updates        # ← НОВОЕ в v1.2.1

   0) 🚪 Exit
```

### 🎯 Умные подсказки

Контекстные советы в зависимости от состояния системы:
- **Новая установка**: "Start with WARP Menu (1) or Tor Menu (2)"
- **Активные сервисы**: "Test connections (4) to verify everything works"
- **Частично настроенная**: "Use service menus to start installed components"

## 🔧 Системные требования

### Минимальные требования:
- **ОС**: Ubuntu 18.04+, Debian 10+, CentOS 7+, RHEL 7+
- **Права**: root доступ (sudo)
- **RAM**: 1GB свободной памяти
- **Диск**: 5GB свободного места
- **Сеть**: доступ в интернет

### Поддерживаемые дистрибутивы:
- Ubuntu (20.04, 22.04, 24.04)
- Debian (11, 12)
- CentOS ( 8, 9)
- RHEL (7, 8, 9)
- Rocky Linux (8, 9)
- AlmaLinux (8, 9)
- Fedora (35+)

### Требуемые пакеты (устанавливаются автоматически):
- `wireguard-tools` - для WARP
- `tor` - Tor прокси  
- `curl`, `wget` - для загрузки компонентов
- `systemctl` - управление сервисами

## 📡 Порты и сервисы

### WARP (WireGuard):
- **Интерфейс**: `warp`
- **Сервис**: `wg-quick@warp` 
- **Конфиг**: `/etc/wireguard/warp.conf`
- **Endpoint**: Cloudflare (автоматически)

### Tor:
- **SOCKS5 порт**: `9050`
- **Control порт**: `9051` 
- **Сервис**: `tor`
- **Конфиг**: `/etc/tor/torrc`
- **Логи**: `/var/log/tor/tor.log`

## 🔍 Примеры использования

### Тестирование соединений:
```bash
# Прямое соединение
curl ifconfig.me

# Через WARP
curl --interface warp ifconfig.me

# Через Tor
curl --socks5 127.0.0.1:9050 ifconfig.me
```

### ProxyChains конфигурация:
```bash
# /etc/proxychains.conf
socks5 127.0.0.1 9050
```

## 🎯 XRay конфигурация

### 🔧 XRay Integration - Для продвинутых пользователей

Встроенные примеры для Reality:

```json
{
  "inbounds": [
    
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "socks",
      "settings": {
        "servers": [{"address": "127.0.0.1", "port": 9050}]
      },
      "tag": "tor"
    }
  ],
  "routing": {
    "rules": [
      {
        "inboundTag": [
          "VTR-USA"
        ],
        "type": "field",
        "domain": ["regexp:.*\\.onion$"],
        "outboundTag": "tor"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "inboundTag": [
          "VTR-USA",
          "VTR-LT",
          "VTR-NL",
          "to-foreign-inbound"
        ],
        "outboundTag": "warp",
        "domain": [
          "geosite:category-ads-all",
          "geosite:google",
          "geosite:cloudflare",
          "geosite:youtube",
          "geosite:netflix"
        ]
      }
    ]
  }
}
```

### 🔀 Маршрутизация трафика

- **Автоматическая маршрутизация** .onion доменов через Tor
- **Прямое подключение** для обычного трафика
- **WARP integration** для обхода блокировок

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
```

#### Tor не работает:
```bash
# Проверить порты
ss -tuln | grep ':9050\|:9051'

# Проверить логи
sudo journalctl -u tor -f

# Проверить конфигурацию
sudo tor --verify-config
```

#### Конфликт портов:
```bash
# Найти процесс, использующий порт
sudo netstat -tlnp | grep ':9050'
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
- [XRay Core](https://xtls.github.io/config/)

## 🔗 Ресурсы и поддержка

- **GitHub Repository**: [https://github.com/DigneZzZ/remnawave-scripts](https://github.com/DigneZzZ/remnawave-scripts)
- **WTM Documentation**: Полная документация в README-warp.md
- **Issue Tracker**: Приветствуются баг-репорты и предложения
- **Project Website**: [https://gig.ovh](https://gig.ovh)

### 🎓 Обучающие материалы

- **XRay конфигурации** с примерами Reality + Tor
- **Тестовые команды** для проверки анонимности

## 🎉 Заключение

✅ **Простота**: Установка в одну команду, интуитивное меню  
✅ **Надежность**: Production-tested, автоматическое восстановление  
✅ **Актуальность**: Система автообновлений, активная разработка  
✅ **Гибкость**: От домашнего использования до enterprise-решений  
✅ **Интеграция**: Часть экосистемы remnawave-scripts

---

**Версия**: v1.2.1  
**Последнее обновление**: 8 августа 2025  
**Автор**: DigneZzZ  
**Проект**: [https://gig.ovh](https://gig.ovh)
