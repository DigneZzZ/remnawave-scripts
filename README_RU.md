# Remnawave Скрипты

[![Лицензия MIT](https://img.shields.io/badge/Лицензия-MIT-yellow.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/Язык-Bash-blue.svg)](#)
[![Установка Remnawave](https://img.shields.io/badge/Инсталлятор-RemnaWave-brightgreen)](#-установщик-панели-remnawave)
[![Установка RemnaNode](https://img.shields.io/badge/Инсталлятор-RemnaNode-lightgrey)](#-установщик-remnanode)
[![Backup](https://img.shields.io/badge/Инструмент-Бэкап-orange)](#-скрипт-резервного-копирования-remnawave)
[![Restore](https://img.shields.io/badge/Инструмент-Восстановление-red)](#-скрипт-восстановления-beta)

---

## 📚 Содержание

* [🚀 Установщик Remnawave Panel](#-установщик-remnawave-panel)
* [🛰 Установщик RemnaNode](#-установщик-remnanode)
* [💾 Скрипт резервного копирования Remnawave](#-скрипт-резервного-копирования-remnawave)
* [🔄 Скрипт восстановления Remnawave (BETA)](#️-скрипт-восстановления-remnawave-beta)
* [🤝 Вклад в проект](#-вклад-в-проект)
* [📜 Лицензия](#-лицензия)
* [👥 Присоединяйся к сообществу OpeNode.XYZ и NeoNode.cc!](#-сообщество)

[Readme on ENGLISH](README.md)
---

## 🚀 Установщик Remnawave Panel

Универсальный Bash-скрипт для установки и управления [Remnawave Panel](https://github.com/remnawave/). Предоставляет полный опыт установки "всё в одном" с полной автоматизацией и управлением через CLI.

### ✅ Основные возможности

* Интерфейс командной строки с командами `install`, `up`, `down`, `restart`, `logs`, `status`, `edit` и т.д.
* Автоматическая генерация `.env`, секретов, портов и `docker-compose.yml`
* Опциональный режим `--dev` для разработки
* Telegram-уведомления
* Безопасная среда с готовностью к проксированию

---

### 📦 Быстрый старт

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh)" @ install
```

---

### ⚙️ Флаги установки

| Флаг     | Описание                                                                 |
| -------- | ------------------------------------------------------------------------ |
| `--name` | Имя каталога установки (по умолчанию: `remnawave`)                       |
| `--dev`  | Установка dev-версии (`remnawave/backend:dev`)                           |

Можно установить **только скрипт**, без запуска полной установки панели:

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh)" @ install-script --name remnawave
```

Удалить только скрипт:

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh)" @ uninstall-script --name remnawave
```

Полный пример установки dev-версии с именем `remnawave-2`:

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh)" @ install --name remnawave-2 --dev
```

---

### 🛠 Поддерживаемые команды

| Команда      | Описание                                  |
| ------------ | ----------------------------------------- |
| `install`    | Установка панели                          |
| `update`     | Обновление скрипта и Docker-образов       |
| `uninstall`  | Полное удаление панели                    |
| `up`         | Запуск контейнеров                        |
| `down`       | Остановка контейнеров                     |
| `restart`    | Перезапуск панели                         |
| `status`     | Проверка статуса                          |
| `install-script`     | Установка скрипта в систему по пути `/usr/local/bin`|
| `uninstall-script`     | Удаление только скрипта из системы |
| `logs`       | Просмотр логов                            |
| `edit`       | Редактирование `docker-compose.yml`       |
| `edit-env`   | Редактирование `.env` файла               |
| `console`    | Внутренняя CLI-консоль панели Remnawave   |
| `backup`    | Создаст бэкап базы в /opt/remnawave/backup ( с флагом --data-only) |

---

### 🔐 Telegram-уведомления

При установке можно настроить оповещения через Telegram:

* `IS_TELEGRAM_ENABLED=true`
* `TELEGRAM_BOT_TOKEN`
* `TELEGRAM_ADMIN_ID`
* `NODES_NOTIFY_CHAT_ID`
* `*_THREAD_ID` (опционально)

> Рекомендуется использовать [@BotFather](https://t.me/BotFather) для создания бота.

---

### 🌍 Настройка обратного прокси

Порты по умолчанию привязаны к `127.0.0.1`. Пример настройки:

```text
panel.example.com       → 127.0.0.1:3000  
sub.example.com/sub     → 127.0.0.1:3010
```

---

### 📂 Структура файлов

```text
/opt/remnawave/
├── .env
├── docker-compose.yml
└── app-config.json      # Опционально
```

---

### 🧩 Требования

Скрипт автоматически устанавливает нужные пакеты:

* `curl`
* `docker`
* `docker compose`
* `openssl`
* `nano` или `vi`

---

### 🧼 Удаление панели

```bash
remnawave uninstall
```

> ⚠️ Будет предложено удалить тома базы данных.

---

## 🛰 Установщик RemnaNode

Универсальный Bash-скрипт для установки и управления **RemnaNode** — прокси-узлом для безопасного подключения к Remnawave Panel через **Xray-core**.

---

### 📦 Быстрый старт

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh)" @ install
```

---

### ✅ Возможности

* Интерфейс CLI (`install`, `up`, `down`, `restart`, `logs`, `status` и т.д.)
* Автоопределение конфликтов портов
* Возможность установки последней версии Xray-core
* Генерация `.env` и `docker-compose.yml`
* Поддержка установки из ветки `--dev`

---

### ⚙️ Флаги установки

| Флаг     | Описание                                                       |
| -------- | -------------------------------------------------------------- |
| `--name` | Кастомное имя узла (по умолчанию: remnanode)                   |
| `--dev`  | Использовать образ `remnawave/node:dev` вместо `latest`        |

---

### 🛠 Поддерживаемые команды

| Команда       | Описание                                    |
| ------------- | ------------------------------------------- |
| `install`     | Установка RemnaNode                         |
| `update`      | Обновление скрипта и Docker-образа         |
| `uninstall`   | Удаление узла и его данных (по запросу)     |
| `up`          | Запуск узла                                 |
| `down`        | Остановка узла                              |
| `restart`     | Перезапуск узла                             |
| `status`      | Проверка работы узла                        |
| `logs`        | Просмотр логов                              |
| `core-update` | Обновление/смена Xray-core                  |
| `edit`        | Редактирование `docker-compose.yml`         |

---

### 📂 Структура файлов

```text
/opt/remnanode/
├── .env
└── docker-compose.yml

/var/lib/remnanode/
└── xray               # бинарный файл Xray-core
```

---

### 🔐 Поддержка Xray-core

* Загружает и устанавливает последнюю или выбранную версию
* Располагает её в `/var/lib/remnanode/xray`
* Примонтирует в контейнер при запуске

---

### 🌐 Пример обратного прокси

```text
node.example.com → 127.0.0.1:3000
```

---

### 🧼 Удаление узла

```bash
remnanode uninstall
```

> ⚠️ Будет предложено удалить данные ядра.

---

## 💾 Скрипт резервного копирования Remnawave

Создаёт резервные копии базы данных и конфигурационных файлов Remnawave, с возможной отправкой через Telegram.

---

### 📦 Быстрый старт

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave-backup.sh)"
```

---

### 📂 Что резервируется

* `db_backup.sql` из базы данных Remnawave
* Один из вариантов:

  * Весь каталог установки (например, `/opt/remnawave`)
  * Отдельные файлы: `docker-compose.yml`, `.env`, `app-config.json`

---

### 🔔 Интеграция с Telegram

Будет предложено ввести:

* Токен бота  
* ID чата или канала  
* (Опционально) ID темы  

> Файлы автоматически разбиваются, если превышают лимит Telegram.

---

## 🧙‍♂️ Скрипт восстановления Remnawave (BETA)

Восстанавливает Remnawave из архива `.tar.gz`. **Используйте с осторожностью на рабочих системах.**

---

### 📦 Быстрый старт

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/restore.sh)"
```

---

### 🧩 Режимы восстановления

* **Полное восстановление:**

  * Распаковывает все файлы в указанную директорию  
  * Удаляет и заменяет данные PostgreSQL

* **Только база данных:**

  * Сохраняет текущие файлы  
  * Перезаписывает данные из `db_backup.sql`

---

### ✅ Требования

* `docker`
* `docker compose`
* Архив должен содержать `db_backup.sql`
* Учётные данные PostgreSQL должны быть в `.env` или вводиться вручную

---

## 🤝 Вклад в проект

PR'ы и предложения приветствуются. Пишите на Bash и сохраняйте совместимость с Docker.

---

## 🪪 Лицензия

Лицензия MIT

---

## 👥 Сообщество

Присоединяйтесь к нашему [форуму](https://openode.xyz) — платные клубы с подробными гайдами по установке **Remnawave**, **Marzban**, **SHM** и других панелей.

Дополнительно читайте открытый блог [Neonode.cc](https://neonode.cc) — скрипты, лайфхаки, статьи и инсайты по Linux, серверам, DevOps и VPN.
