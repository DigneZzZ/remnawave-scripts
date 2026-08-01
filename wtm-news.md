# 🌐 WTM - WARP & Tor Manager v1.2.1 - Профессиональное управление анонимными сетями

> Привет👋
> 
> Представляю вам **WTM (WARP & Tor Manager)** - современный инструмент для автоматизации установки и управления **Cloudflare WARP** и **Tor** на Linux серверах.
>
> 🆕 **Версия v1.2.1** включает революционную систему автообновления, интерактивные меню и профессиональную диагностику сетевых подключений!

![wtm-banner|690x470](upload://remnawave-script.webp)

## 🎯 Что такое WTM?

**WTM** - это комплексный bash-скрипт корпоративного уровня для управления анонимными сетевыми подключениями. Идеально подходит для настройки прокси-серверов, обхода блокировок и обеспечения приватности в production-окружении.

### 🚀 Cloudflare WARP - Скорость и надежность
* **Автоматическая установка WireGuard** с оптимизированными настройками
* **Интеграция с wgcf** для генерации конфигураций WARP
* **IPv6 поддержка** с автоматическим определением
* **Проверка подключения** через Cloudflare trace API
* **Управление сервисом** через systemctl

### 🧅 Tor Network - Максимальная анонимность
* **Оптимизированная конфигурация** для production-использования
* **SOCKS5 прокси** на порту 9050
* **Control Port** для программного управления
* **Автоматическая ротация** цепочек для безопасности
* **Логирование и мониторинг** подключений

## 💾 Система автообновления - Главная особенность

Особенно горжусь встроенной системой обновлений, реализованной по образцу других скриптов коллекции:

**🔄 Умная система версионирования:**
* **Автоматическая проверка** новых версий при запуске интерактивного режима
* **Безопасное обновление** с проверкой целостности файлов
* **Глобальная установка** в `/usr/local/bin/wtm` для системного доступа
* **Откат изменений** при неудачном обновлении

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
* **Единый URL обновлений** - совместимость с репозиторием remnawave-scripts
* **Проверка прав доступа** - требование root для обновления
* **Версионная совместимость** - автоматическая миграция конфигураций
* **Интерактивное меню обновлений** - пункт 9 в главном меню

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

* 🚀 **Мгновенный доступ** - команда `wtm` доступна сразу после установки
* 🔄 **Нет дублирования** - умная система предотвращает повторные установки
* 💾 **Безопасность** - установка только при необходимости
* 📱 **Удобство** - работает как в интерактивном, так и в командном режиме

## 🛠️ Комплексное управление сервисами

### 📡 WARP Management
```bash
# Установка и настройка
sudo wtm install-warp               # Обычная установка
sudo wtm install-warp-force         # Принудительная переустановка

# Управление сервисом
sudo wtm start-warp                 # Запуск WARP
sudo wtm stop-warp                  # Остановка
sudo wtm restart-warp               # Перезапуск

# Мониторинг
sudo wtm logs-warp                  # Просмотр логов в реальном времени
```

### 🧅 Tor Management
```bash
# Установка с оптимизацией
sudo wtm install-tor                # Установка с конфигурацией production
sudo wtm install-tor-force          # Переустановка

# Контроль сервиса
sudo wtm start-tor                  # Запуск Tor
sudo wtm stop-tor                   # Остановка
sudo wtm restart-tor                # Перезапуск

# Диагностика
sudo wtm logs-tor                   # Лог-файлы Tor
```

### 🔄 Быстрые действия
```bash
# Массовые операции
sudo wtm install-all                # Установка WARP + Tor
sudo wtm install-all-force          # Принудительная переустановка всего

# Универсальные команды
sudo wtm status                     # Статус всех сервисов
sudo wtm test                       # Тестирование подключений
sudo wtm system-info                # Информация о системе
```

## 📊 Продвинутая диагностика и мониторинг

Встроенные инструменты для production-мониторинга:

### 🔍 Автоматическое тестирование
```bash
# Комплексное тестирование подключений
sudo wtm test

# Результат включает:
├── 🌐 Прямое подключение (проверка базового интернета)
├── 📡 WARP тестирование
│   ├── WireGuard интерфейс (wg show warp)
│   ├── Cloudflare trace (warp=on/plus проверка)
│   └── Сравнение IP адресов
└── 🧅 Tor тестирование
    ├── SOCKS5 порт 9050 (доступность)
    ├── Tor Project verification
    └── Анонимизация IP
```

### 📈 Системный мониторинг
```bash
# Подробная информация о состоянии
sudo wtm status

# Отображает:
├── 💾 RAM usage и публичный IP
├── 📡 WARP статус
│   ├── Состояние сервиса (активен/остановлен)
│   ├── Потребление памяти
│   ├── WireGuard endpoint информация
│   └── Cloudflare verification
└── 🧅 Tor статус
    ├── Статус демона
    ├── SOCKS5 доступность (127.0.0.1:9050)
    ├── Control port (127.0.0.1:9051)
    └── Потребление ресурсов
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
* **Новая установка**: "Start with WARP Menu (1) or Tor Menu (2)"
* **Активные сервисы**: "Test connections (4) to verify everything works"
* **Частично настроенная**: "Use service menus to start installed components"

## 🔧 XRay Integration - Для продвинутых пользователей

### 📝 Готовые конфигурации
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
        ]
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
      },
    ]
  }
}
```

### 🔀 Маршрутизация трафика
* **Автоматическая маршрутизация** .onion доменов через Tor
* **Прямое подключение** для обычного трафика
* **WARP integration** для обхода блокировок

## 🌟 Production-готовность

### 🏗️ Системные требования
* **Операционные системы**: Ubuntu, Debian, CentOS, AlmaLinux, Fedora, Arch Linux
* **Архитектуры**: x86_64, ARM64, ARM32 (автоопределение)
* **Права доступа**: Root требуется для установки и управления сервисами
* **Сетевые порты**: 9050, 9051 (Tor) должны быть свободны

### 🔒 Безопасность и стабильность
* **Автоматическое управление DNS** с восстановлением
* **Проверка портов** перед установкой сервисов
* **Backup конфигураций** при изменениях
* **Валидация IPv6** поддержки
* **Временные DNS** для надежной установки

### 📈 Оптимизация производительности
```bash
# Tor оптимизации в конфигурации
ConnLimit 1000                      # Увеличенный лимит подключений
MaxClientCircuitsPending 48         # Больше цепочек для клиентов
NewCircuitPeriod 30                 # Быстрая ротация цепочек
MaxCircuitDirtiness 600             # Время жизни цепочки

# WARP настройки
Table = off                         # Отключение таблицы маршрутизации
PersistentKeepalive = 25           # Поддержание соединения
```

## 📱 Команды одной строкой

### 🔥 Quick Start
```bash
# Быстрый старт для новичков
curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/wtm.sh | sudo bash -s install-all

# Проверка работоспособности
wtm test

# Получение справки
wtm help
wtm usage-examples
```

### ⚡ Power User Commands
```bash
# Мониторинг в одной строке
watch -n 5 'wtm status | grep -A 20 "Network Status"'

# Логи в реальном времени
tmux new-session -d 'wtm logs-warp' \; split-window 'wtm logs-tor' \; attach

# Экспорт конфигураций
sudo cp /etc/wireguard/warp.conf /backup/
sudo cp /etc/tor/torrc /backup/
```

## 🔗 Ресурсы и поддержка

* **GitHub Repository**: [https://github.com/DigneZzZ/remnawave-scripts](https://github.com/DigneZzZ/remnawave-scripts)
* **WTM Documentation**: Полная документация в README-warp.md
* **Issue Tracker**: Приветствуются баг-репорты и предложения
* **Project Website**: [https://gig.ovh](https://gig.ovh)

### 🎓 Обучающие материалы
* **XRay конфигурации** с примерами Reality + Tor
* **Тестовые команды** для проверки анонимности  

---

## 🎉 Заключение

✅ **Простота**: Установка в одну команду, интуитивное меню  
✅ **Надежность**: Production-tested, автоматическое восстановление  
✅ **Актуальность**: Система автообновлений, активная разработка  
✅ **Гибкость**: От домашнего использования до enterprise-решений  
✅ **Интеграция**: Часть экосистемы remnawave-scripts  

Буду рад отзывам и предложениям! Если WTM оказался полезным - поставьте ⭐ на GitHub!