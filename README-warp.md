# 🌐 WTM - WARP & Tor Manager

Автоматический установщик и менеджер для Cloudflare WARP (через WireGuard) и Tor прокси-сервера. Обеспечивает быструю настройку и управление прокси-соединениями на Linux серверах через удобную команду `wtm`.

### Релиз от проектов [GIG.ovh](https://gig.ovh) и [OpeNode.xyz](https://openode.xyz)

## 📋 Возможности

### 🚀 Основные функции
- **Автоматическая установка** Cloudflare WARP через WireGuard
- **Автоматическая установка** Tor с оптимизированной конфигурацией  
- **Интерактивное меню** в стиле remnanode для удобного управления
- **Мониторинг состояния** сервисов в реальном времени
- **Тестирование соединений** для проверки работоспособности
- **Принудительная переустановка** с флагом --force

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

## 📦 Установка

### Быстрая установка из репозитория

```bash
# Скачать и установить скрипт в одну команду
sudo wget https://raw.githubusercontent.com/remnawave/remnawave-scripts/main/wtm.sh -O /usr/local/bin/wtm && sudo chmod +x /usr/local/bin/wtm

# Запустить интерактивное меню
sudo wtm
```

### Альтернативный способ

```bash
# Клонировать весь репозиторий
git clone https://github.com/remnawave/remnawave-scripts.git
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
```

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

### Базовая конфигурация с роутингом:
```json
{
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "warp",
      "protocol": "freedom",
      "settings": {},
      "streamSettings": {
        "sockopt": {
          "bindToDevice": "warp"
        }
      }
    },
    {
      "tag": "tor",
      "protocol": "socks",
      "settings": {
        "servers": [
          {
            "address": "127.0.0.1",
            "port": 9050
          }
        ]
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "VTR-USA",
          "VTR-EU", 
          "to-foreign-inbound"
        ],
        "outboundTag": "tor",
        "domain": ["regexp:.*\\.onion$"]
      },
      {
        "type": "field",
        "inboundTag": [
          "VTR-USA",
          "VTR-EU",
          "to-foreign-inbound"
        ],
        "outboundTag": "warp",
        "domain": [
          "geosite:netflix",
          "geosite:youtube",
          "geosite:google"
        ]
      },
      {
        "type": "field",
        "inboundTag": [
          "VTR-RU",
          "local-inbound"
        ],
        "outboundTag": "direct"
      }
    ]
  }
}
```

### Серверные inbound примеры:
- `VTR-USA`, `VTR-EU`, `VTR-ASIA` - зарубежные серверы
- `VTR-RU`, `VTR-LOCAL` - локальные серверы  
- `to-foreign-inbound` - общий зарубежный
- `local-inbound` - общий локальный

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

### Полезные ссылки:
- [RemnaWave Scripts Repository](https://github.com/dignezzz/remnawave-scripts)
- [WGCF Tool](https://github.com/ViRb3/wgcf)
- [Tor Configuration Guide](https://community.torproject.org/relay/setup/)

## ⚠️ Важные замечания

### Безопасность:
- Скрипт требует root доступ для настройки сетевых интерфейсов
- Конфигурационные файлы содержат приватные ключи
- Рекомендуется регулярно обновлять Tor для безопасности

### Производительность:
- WARP обычно быстрее Tor для обычного трафика
- Tor добавляет латентность из-за многоуровневого шифрования
- .onion сайты доступны только через Tor

### Ограничения:
- WARP может не работать в некоторых географических регионах
- Tor может блокироваться некоторыми сайтами
- Некоторые провайдеры ограничивают VPN/прокси трафик

## 📄 Лицензия

Этот скрипт является частью проекта RemnaWave Scripts и распространяется под открытой лицензией. Используйте на свой страх и риск.

## 🤝 Поддержка

Если у вас возникли проблемы или вопросы:

1. Проверьте раздел "Устранение неполадок" выше
2. Запустите диагностику: `sudo wtm test`
3. Создайте issue в [GitHub репозитории](https://github.com/dignezzz/remnawave-scripts)

---

**Версия**: 1.1.4  
**Последнее обновление**: 7 января 2025  
**Автор**: DigneZzZ
**Проект**: https://gig.ovh
