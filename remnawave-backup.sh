#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}   Welcome to Remnawave Backup Installer${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${BLUE}This script will create a ${YELLOW}backup.sh${BLUE} file with your settings.${NC}"
echo

prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    echo -ne "${prompt} [${default}]: "
    read input
    eval "$var_name=\"${input:-$default}\""
}

echo -e "${YELLOW}📍 Specify the path to docker-compose.yml for Remnawave:${NC}"
echo -e "${BLUE}  1) /root/remnawave${NC}"
echo -e "${BLUE}  2) /opt/remnawave${NC}"
echo -e "${BLUE}  3) Enter manually${NC}"
echo -e "${GREEN}Note:${NC} Info from .env and other files will be read from this path."
echo -ne "Choose an option (1-3) [2]: "
read choice
choice=${choice:-2}

case $choice in
    1) COMPOSE_PATH="/root/remnawave" ;;
    2) COMPOSE_PATH="/opt/remnawave" ;;
    3) prompt_input "${YELLOW}Enter the path manually${NC}" COMPOSE_PATH "" ;;
    *) COMPOSE_PATH="/opt/remnawave" ;;
esac

if [ ! -f "$COMPOSE_PATH/docker-compose.yml" ]; then
    echo -e "${RED}✖ Error: docker-compose.yml not found at $COMPOSE_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}📁 Do you want to backup the entire folder ($COMPOSE_PATH)?${NC}"
echo -e "${BLUE}  1) Yes, backup all files and subfolders${NC}"
echo -e "${BLUE}  2) No, backup only specific files (docker-compose.yml, .env, app-config.json)${NC}"
echo -ne "Choose an option (1-2) [2]: "
read backup_choice
backup_choice=${backup_choice:-2}

case $backup_choice in
    1) BACKUP_ENTIRE_FOLDER="true" ;;
    2) BACKUP_ENTIRE_FOLDER="false" ;;
    *) BACKUP_ENTIRE_FOLDER="false" ;;
esac

read_env_var() {
    local var_name="$1"
    local file="$2"
    local value
    # Читаем значение и обрабатываем случаи с пробелами и кавычками
    value=$(grep "^$var_name=" "$file" | cut -d '=' -f 2- | head -n 1)
    # Убираем возможные комментарии в конце строки
    value=$(echo "$value" | sed 's/[[:space:]]*#.*$//')
    echo "$value"
}

if [ -f "$COMPOSE_PATH/.env" ]; then
    echo -e "${GREEN}✔ .env file found at $COMPOSE_PATH. Using it for DB connection.${NC}"
    USE_ENV=true
    POSTGRES_USER=$(read_env_var "POSTGRES_USER" "$COMPOSE_PATH/.env")
    POSTGRES_PASSWORD=$(read_env_var "POSTGRES_PASSWORD" "$COMPOSE_PATH/.env")
    POSTGRES_DB=$(read_env_var "POSTGRES_DB" "$COMPOSE_PATH/.env")
    POSTGRES_USER=$(echo "$POSTGRES_USER" | sed 's/^"//;s/"$//')
    POSTGRES_PASSWORD=$(echo "$POSTGRES_PASSWORD" | sed 's/^"//;s/"$//')
    POSTGRES_DB=$(echo "$POSTGRES_DB" | sed 's/^"//;s/"$//')
    
    # Проверяем что все необходимые переменные заданы
    if [ -z "$POSTGRES_USER" ]; then
        echo -e "${RED}✖ Error: POSTGRES_USER not found or empty in .env file!${NC}"
        exit 1
    fi
    if [ -z "$POSTGRES_DB" ]; then
        echo -e "${RED}✖ Error: POSTGRES_DB not found or empty in .env file!${NC}"
        exit 1
    fi
    if [ -z "$POSTGRES_PASSWORD" ]; then
        echo -e "${RED}✖ Error: POSTGRES_PASSWORD not found or empty in .env file!${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Using database config: User=$POSTGRES_USER, DB=$POSTGRES_DB${NC}"
else
    echo -e "${YELLOW}⚠ .env file not found at $COMPOSE_PATH.${NC}"
    echo -e "${BLUE}You’ll need to enter DB connection details manually.${NC}"
    USE_ENV=false
    prompt_input "${YELLOW}Enter POSTGRES_USER${NC}" POSTGRES_USER "postgres"
    prompt_input "${YELLOW}Enter POSTGRES_PASSWORD${NC}" POSTGRES_PASSWORD ""
    prompt_input "${YELLOW}Enter POSTGRES_DB${NC}" POSTGRES_DB "postgres"
fi

DB_CONTAINER=$(docker ps --filter "name=remnawave-db" --format "{{.Names}}")
if [ -z "$DB_CONTAINER" ]; then
    echo -e "${RED}✖ Error: Database container 'remnawave-db' not found!${NC}"
    echo -e "${BLUE}Please enter the correct container name for the database:${NC}"
    prompt_input "${YELLOW}Enter DB container name${NC}" DB_CONTAINER "remnawave-db"
fi

echo -e "${YELLOW}📡 Telegram Settings:${NC}"
prompt_input "${BLUE}Enter Telegram Bot Token (from @BotFather)${NC}" TELEGRAM_BOT_TOKEN ""
prompt_input "${BLUE}Enter Telegram Chat/Channel ID (e.g., -1001234567890)${NC}" TELEGRAM_CHAT_ID ""
prompt_input "${BLUE}Enter Telegram Topic ID (optional, press Enter to skip)${NC}" TELEGRAM_TOPIC_ID ""

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo -e "${RED}✖ Error: Telegram Bot Token and Chat ID are required!${NC}"
    exit 1
fi

BACKUP_SCRIPT="$COMPOSE_PATH/backup.sh"

# Читаем прокси из .env панели (если задан и раскомментирован)
TELEGRAM_BOT_PROXY=""
if [ -f "$COMPOSE_PATH/.env" ]; then
    TELEGRAM_BOT_PROXY=$(grep "^TELEGRAM_BOT_PROXY=" "$COMPOSE_PATH/.env" | cut -d'=' -f2- | sed 's/^"//;s/"$//')
    if [ -n "$TELEGRAM_BOT_PROXY" ] && [ "$TELEGRAM_BOT_PROXY" != "change_me" ]; then
        echo -e "${GREEN}✔ Found Telegram proxy in .env: $TELEGRAM_BOT_PROXY${NC}"
    else
        TELEGRAM_BOT_PROXY=""
    fi
fi

cat << EOF > "$BACKUP_SCRIPT"
#!/bin/bash
cd "$COMPOSE_PATH" || { echo "Error: Could not change to $COMPOSE_PATH"; exit 1; }
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
TELEGRAM_TOPIC_ID="$TELEGRAM_TOPIC_ID"
TELEGRAM_BOT_PROXY="$TELEGRAM_BOT_PROXY"
BACKUP_DIR="/tmp/backup_\$(date +%Y%m%d_%H%M%S)"
BACKUP_DATE="\$(date '+%Y-%m-%d %H:%M:%S UTC')"
ARCHIVE_NAME="\$BACKUP_DIR.tar.gz"
MAX_SIZE_MB=49
DB_CONTAINER="$DB_CONTAINER"
POSTGRES_USER="$POSTGRES_USER"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
POSTGRES_DB="$POSTGRES_DB"
mkdir -p "\$BACKUP_DIR"
export PGPASSWORD="\$POSTGRES_PASSWORD"
docker exec "\$DB_CONTAINER" pg_dump -U "\$POSTGRES_USER" -d "\$POSTGRES_DB" > "\$BACKUP_DIR/db_backup.sql"
if [ \$? -ne 0 ]; then
    echo "Error: Failed to create database backup"
    unset PGPASSWORD
    exit 1
fi
unset PGPASSWORD
EOF

if [ "$BACKUP_ENTIRE_FOLDER" = "true" ]; then
    cat << EOF >> "$BACKUP_SCRIPT"
TEMP_ARCHIVE_DIR="/tmp/archive_\$(date +%Y%m%d_%H%M%S)"
mkdir -p "\$TEMP_ARCHIVE_DIR"
cp -r "$COMPOSE_PATH/." "\$TEMP_ARCHIVE_DIR/"
mv "\$BACKUP_DIR/db_backup.sql" "\$TEMP_ARCHIVE_DIR/db_backup.sql"
tar -czvf "\$ARCHIVE_NAME" -C "\$TEMP_ARCHIVE_DIR" .
if [ \$? -ne 0 ]; then
    echo "Error: Failed to create archive"
    rm -rf "\$TEMP_ARCHIVE_DIR"
    exit 1
fi
rm -rf "\$TEMP_ARCHIVE_DIR"
CONTENTS="📁 Entire folder ($COMPOSE_PATH)
📋 db_backup.sql"
EOF
else
    cat << 'EOF' >> "$BACKUP_SCRIPT"
cp docker-compose.yml "$BACKUP_DIR/" || { echo "Error: Failed to copy docker-compose.yml"; exit 1; }
[ -f .env ] && cp .env "$BACKUP_DIR/" || echo "File .env not found, skipping"
[ -f app-config.json ] && cp app-config.json "$BACKUP_DIR/" || echo "File app-config.json not found, skipping"
CONTENTS=""
[ -f "$BACKUP_DIR/db_backup.sql" ] && CONTENTS="$CONTENTS📋 db_backup.sql
"
[ -f "$BACKUP_DIR/docker-compose.yml" ] && CONTENTS="$CONTENTS📄 docker-compose.yml
"
[ -f "$BACKUP_DIR/.env" ] && CONTENTS="$CONTENTS🔑 .env
"
[ -f "$BACKUP_DIR/app-config.json" ] && CONTENTS="$CONTENTS⚙️ app-config.json
"
tar -czvf "$ARCHIVE_NAME" -C "$BACKUP_DIR" .
if [ $? -ne 0 ]; then
    echo "Error: Failed to create archive"
    exit 1
fi
EOF
fi

cat << 'EOF' >> "$BACKUP_SCRIPT"
ARCHIVE_SIZE=$(du -m "$ARCHIVE_NAME" | cut -f1)
MESSAGE=$(printf "🔔 Remnawave Backup\n📅 Date: %s\n📦 Archive contents:\n%s" "$BACKUP_DATE" "$CONTENTS")
send_telegram() {
    local file="$1"
    local caption="$2"
    local curl_cmd="curl"
    [ -n "$TELEGRAM_BOT_PROXY" ] && curl_cmd="$curl_cmd --proxy \"$TELEGRAM_BOT_PROXY\""
    curl_cmd="$curl_cmd -F chat_id=\"$TELEGRAM_CHAT_ID\""
    [ -n "$TELEGRAM_TOPIC_ID" ] && curl_cmd="$curl_cmd -F message_thread_id=\"$TELEGRAM_TOPIC_ID\""
    curl_cmd="$curl_cmd -F document=@\"$file\" -F \"caption=$caption\" \"https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument\" -o telegram_response.json"
    eval "$curl_cmd"
}
if [ "$ARCHIVE_SIZE" -gt "$MAX_SIZE_MB" ]; then
    echo "Archive size ($ARCHIVE_SIZE MB) exceeds $MAX_SIZE_MB MB, splitting into parts..."
    split -b 49m "$ARCHIVE_NAME" "$BACKUP_DIR/part_"
    PARTS=("$BACKUP_DIR"/part_*)
    PART_COUNT=${#PARTS[@]}
    for i in "${!PARTS[@]}"; do
        PART_FILE="${PARTS[$i]}"
        PART_NUM=$((i + 1))
        PART_MESSAGE=$(printf "🔔 Remnawave Backup (Part %d of %d)\n📅 Date: %s\n📦 Archive contents:\n\n%s" "$PART_NUM" "$PART_COUNT" "$BACKUP_DATE" "$CONTENTS")
        send_telegram "$PART_FILE" "$PART_MESSAGE"
        if [ $? -ne 0 ] || grep -q '"ok":false' telegram_response.json; then
            echo "Error sending part $PART_NUM:"
            cat telegram_response.json
            exit 1
        fi
        echo "Part $PART_NUM of $PART_COUNT sent successfully"
    done
else
    send_telegram "$ARCHIVE_NAME" "$MESSAGE"
    if [ $? -ne 0 ]; then
        echo "Error sending archive to Telegram"
        cat telegram_response.json
        exit 1
    fi
    if grep -q '"ok":false' telegram_response.json; then
        echo "Telegram returned an error:"
        cat telegram_response.json
    else
        echo "Archive successfully sent to Telegram"
    fi
fi
rm -rf "$BACKUP_DIR"
rm "$ARCHIVE_NAME"
rm telegram_response.json
EOF

chmod +x "$BACKUP_SCRIPT"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}   Backup script created successfully at: $BACKUP_SCRIPT${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${BLUE}To run it, use: ${YELLOW}$BACKUP_SCRIPT${NC}"
echo -e "${BLUE}To add to crontab, run '${YELLOW}crontab -e${BLUE}' and add, e.g.:${NC}"
echo -e "${YELLOW}0 */2 * * * $BACKUP_SCRIPT${NC}"
