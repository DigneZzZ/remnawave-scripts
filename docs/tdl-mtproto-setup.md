# TDL (MTProto) — Отправка больших файлов в Telegram

> **TL;DR:** Используйте `tdl` для отправки файлов до 2GB в Telegram без разбиения на части.

## Зачем это нужно?

| Метод | Лимит файла | Скорость |
|-------|-------------|----------|
| Bot API (`curl sendDocument`) | 50 MB | Средняя |
| MTProto (`tdl`) | **2 GB** (4 GB для Premium) | Высокая |

## Установка tdl

### Шаг 1: Скачивание

```bash
# Узнать последнюю версию
VERSION=$(curl -sI https://github.com/iyear/tdl/releases/latest | grep -i location | awk -F'/' '{print $NF}' | tr -d '\r')
echo "Latest version: $VERSION"

# Скачать и установить
cd /tmp && \
curl -L -o tdl.tar.gz "https://github.com/iyear/tdl/releases/download/${VERSION}/tdl_Linux_64bit.tar.gz" && \
tar -xzf tdl.tar.gz && \
mv tdl /usr/local/bin/ && \
chmod +x /usr/local/bin/tdl && \
rm tdl.tar.gz

# Проверить установку
tdl version
```

### Альтернатива: Установка через скрипт

```bash
curl -sSL https://raw.githubusercontent.com/iyear/tdl/master/scripts/install.sh | bash
```

## Настройка (один раз)

### Шаг 2: Получение API credentials

1. Перейдите на https://my.telegram.org/apps
2. Войдите по номеру телефона
3. Создайте приложение (любое название, например "Backup Script")
4. Скопируйте **API ID** (число) и **API Hash** (строка)

### Шаг 3: Авторизация tdl

```bash
tdl login
```

Утилита запросит:
- API ID
- API Hash
- Номер телефона (в формате +7...)
- Код подтверждения из Telegram

> ⚠️ **Важно:** Session сохраняется в `~/.tdl/`. Не делитесь этими файлами!

## Использование

### Отправка файла в Saved Messages

```bash
tdl up -p /path/to/backup.tar.gz
```

### Отправка в конкретный чат

```bash
# По username канала/группы
tdl up -p /path/to/backup.tar.gz -c @channel_name

# По chat_id
tdl up -p /path/to/backup.tar.gz -c 127192647

# Для группы с топиками (thread_id)
tdl up -p /path/to/backup.tar.gz -c -1001234567890
```

### Отправка нескольких файлов

```bash
tdl up -p file1.tar.gz -p file2.tar.gz -c @channel
```

### С caption (подписью)

```bash
tdl up -p backup.tar.gz -c @channel --caption "🔔 Daily Backup $(date)"
```

## Тестирование

### Создание тестового файла 100MB

```bash
dd if=/dev/urandom of=/tmp/test_100mb.bin bs=1M count=100
ls -lh /tmp/test_100mb.bin
```

### Отправка тестового файла

```bash
tdl up -p /tmp/test_100mb.bin
```

### Очистка после теста

```bash
rm /tmp/test_100mb.bin
```

## Интеграция с backup-config.json

Для интеграции с существующей системой бэкапов можно добавить в конфиг:

```json
{
  "telegram": {
    "enabled": true,
    "use_mtproto": true,
    "bot_token": "...",
    "chat_id": "...",
    "thread_id": null
  }
}
```

И в скрипте бэкапа:

```bash
# Если включён MTProto и tdl установлен
if command -v tdl &>/dev/null && [ "$use_mtproto" = "true" ]; then
    tdl up -p "$backup_file" -c "$chat_id"
else
    # Fallback на Bot API с разбиением
    curl -X POST "https://api.telegram.org/bot$token/sendDocument" ...
fi
```

## Устранение проблем

### Ошибка авторизации

```bash
# Удалить старую сессию и авторизоваться заново
rm -rf ~/.tdl/
tdl login
```

### Проверка статуса

```bash
tdl version
tdl chat ls  # Список доступных чатов
```

### Rate limits

При отправке множества файлов добавляйте паузу:

```bash
for file in *.tar.gz; do
    tdl up -p "$file" -c @channel
    sleep 5
done
```

## Ссылки

- [tdl GitHub](https://github.com/iyear/tdl)
- [Telegram API](https://my.telegram.org/apps)
- [MTProto Documentation](https://core.telegram.org/mtproto)
