# Remnawave Скрипты

[![Лицензия MIT](https://img.shields.io/badge/Лицензия-MIT-yellow.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/Язык-Bash-blue.svg)](#)
[![Установка Remnawave](https://img.shields.io/badge/Инсталлятор-Remnawave-brightgreen)](#установка-панели-remnawave)
[![Установка RemnaNode](https://img.shields.io/badge/Инсталлятор-RemnaNode-lightgrey)](#установка-remnanode)
[![Backup](https://img.shields.io/badge/Инструмент-Бэкап-orange)](#скрипт-резервного-копирования-remnawave)
[![Restore](https://img.shields.io/badge/Инструмент-Восстановление-red)](#скрипт-восстановления-remnawave-бета)

---

## 📚 Содержание

Коллекция bash-скриптов для установки, управления, резервного копирования и восстановления **Remnawave** и **RemnaNode**. Скрипты позволяют упростить процесс настройки и обслуживания инфраструктуры.

- [Установка панели Remnawave](#установка-панели-remnawave)
- [Установка RemnaNode](#установка-remnanode)
- [Скрипт резервного копирования Remnawave](#скрипт-резервного-копирования-remnawave)
- [Скрипт восстановления Remnawave (БЕТА)](#скрипт-восстановления-remnawave-бета)
- [Контрибьюции](#контрибьюции)
- [Лицензия](#лицензия)
- [Присоединяйтесь к сообществу OpeNode.XYZ & NeoNode.cc](#присоединяйтесь-к-сообществу)

## [Readme on English](/README.MD)
---

# 🚀 Установщик панели Remnawave

Универсальный Bash-скрипт для установки и управления [Remnawave Panel](https://github.com/remnawave/):

* удобный CLI-интерфейс (`up`, `down`, `logs`, `restart`, `status`, `edit` и др.);
* автогенерация токенов, паролей и портов;
* поддержка Telegram-уведомлений;
* автоматическая установка зависимостей (`docker`, `docker compose`, `openssl` и др.);
* создание конфигурации и `docker-compose.yml` в `/opt/<название>`;
* поддержка `production` и `dev` образов с помощью флага `--dev`.

## 📦 Быстрый старт

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave.sh)" @ install
```

---

## ⚙️ Параметры установки

| Флаг     | Описание                                                       |
| -------- | -------------------------------------------------------------- |
| `--name` | Установить имя директории установки (по умолчанию `remnawave`) |
| `--dev`  | Установить dev-версию панели (`remnawave/backend:dev`)         |

Пример:

```bash
remnawave install --name remnawave --dev
```

---

## 🛠 Поддерживаемые команды

| Команда     | Описание                                |
| ----------- | --------------------------------------- |
| `install`   | Установка панели Remnawave              |
| `update`    | Обновление скрипта и образов            |
| `uninstall` | Удаление панели с опцией очистки данных |
| `up`        | Запуск панели                           |
| `down`      | Остановка панели                        |
| `restart`   | Перезапуск                              |
| `status`    | Проверка статуса                        |
| `logs`      | Просмотр логов                          |
| `edit`      | Редактирование `docker-compose.yml`     |
| `edit-env`  | Редактирование `.env`                   |
| `console`   | Вход в контейнер панели                 |

---

## 🔐 Telegram уведомления

Во время установки можно включить Telegram-уведомления:

* `IS_TELEGRAM_ENABLED=true`
* `TELEGRAM_BOT_TOKEN`
* `TELEGRAM_ADMIN_ID`
* `NODES_NOTIFY_CHAT_ID` (можно указать тот же, что и `TELEGRAM_ADMIN_ID`)
* `*_THREAD_ID` — опционально

> 📌 Используйте [BotFather](https://t.me/BotFather) для создания бота.

---

## 🌍 Обратный прокси

Порты проброшены на `127.0.0.1`, доступны только локально. Рекомендуется настроить обратный прокси (Nginx, Caddy и т.д.):

```text
panel.example.com        → 127.0.0.1:3000
sub.example.com/sub      → 127.0.0.1:3010
```

---

## 📂 Структура установки

```text
/opt/remnawave/
├── .env
├── docker-compose.yml
└── app-config.json      # (опционально)
```

---

## 🧩 Требования

Скрипт сам установит все зависимости:

* `curl`
* `docker`
* `docker compose`
* `openssl`
* `nano` или `vi`

---

## 🧼 Удаление панели

```bash
remnawave uninstall
```

> ⚠️ Скрипт предложит удалить и volume с данными базы

---

# 🛰 Установщик RemnaNode

Скрипт для установки RemnaNode — прокси-ноды с ядром Xray, совместимой с Remnawave. Обеспечивает быструю настройку и подключение.

## 📦 Установка

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnanode.sh)" @ install
```

Скрипт выполнит:

* установку в `/opt/remnanode`
* загрузку ядра Xray в `/var/lib/remnanode`
* создание CLI-интерфейса `remnanode` с командами `up`, `down`, `logs`, `core-update` и др.
* поддержку `--dev` флага для использования dev-версии

---

# 💾 Скрипт резервного копирования Remnawave

Создает резервные копии:

* базы данных (`db_backup.sql`)
* конфигурационных файлов `.env`, `docker-compose.yml`, `app-config.json`
* по выбору: только важные файлы или вся папка
* отправка архива в Telegram (бот + чат + топик)

## 📦 Запуск

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/remnawave-backup.sh)"
```

---

# 🔄 Скрипт восстановления (BETA)

Позволяет восстановить:

* только базу данных (`db_backup.sql`)
* или полностью: файлы + база

Поддерживает `.tar.gz` архив, проверяет зависимости, перезапускает контейнеры.

> ⚠️ Будьте осторожны — в режиме полного восстановления все текущие данные будут перезаписаны!

## 📦 Запуск

```bash
sudo bash -c "$(curl -sL https://github.com/DigneZzZ/remnawave-scripts/raw/main/restore.sh)"
```

---

## 🤝 Содействие

Если вы хотите улучшить скрипты, открывайте `issues` или отправляйте `pull requests`. Старайтесь сохранять текущую архитектуру и совместимость с Remnawave.

---

## 📜 Лицензия

MIT License

---

## 👥 Сообщество

Присоединяйтесь к нашему [форуму](https://openode.xyz) — платные клубы с подробными гайдами по установке **Remnawave**, **Marzban**, **SHM** и других панелей.

Дополнительно читайте открытый блог [Neonode.cc](https://neonode.cc) — скрипты, лайфхаки, статьи и инсайты по Linux, серверам, DevOps и VPN.
