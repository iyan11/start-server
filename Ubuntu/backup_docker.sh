#!/bin/bash

# Подключение переменных из .env_backup
if [ -f Ubuntu/.env_backup ]; then
  export $(grep -v '^#' Ubuntu/.env_backup | xargs)
else
  echo "Файл .env_backup не найден! Пожалуйста, создайте его."
  exit 1
fi

# Проверка обязательных переменных
REQUIRED_VARS=(DB_NAME DB_USER DB_HOST DB_PORT BACKUP_DIR PGPASSWORD FTP_HOST FTP_USER FTP_PASSWORD FTP_DIR CRON_USER DOCKER_CONTAINER_NAME CRONTAB_TIME)
for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    echo "Переменная $VAR отсутствует в .env_backup. Проверьте настройки."
    exit 1
  fi
done

# Создание каталога для бэкапов
sudo mkdir -p "$BACKUP_DIR"
if [ $? -ne 0 ]; then
  echo "Ошибка при создании директории $BACKUP_DIR"
  exit 1
fi

sudo chown -R $(whoami):$(whoami) "$BACKUP_DIR"
sudo chmod 2775 "$BACKUP_DIR"

# Создание .env файла
ENV_FILE="$BACKUP_DIR/.env"
cat <<EOL > "$ENV_FILE"
# PostgreSQL настройки
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
BACKUP_DIR=$BACKUP_DIR
PGPASSWORD=$PGPASSWORD

# FTP настройки
FTP_HOST=$FTP_HOST
FTP_USER=$FTP_USER
FTP_PASSWORD=$FTP_PASSWORD
FTP_DIR=$FTP_DIR

# Docker настройки
DOCKER_CONTAINER_NAME=$DOCKER_CONTAINER_NAME

# Время жизни бекапов в днях
DAYS_TO_KEEP=$DAYS_TO_KEEP
EOL
echo ".env файл создан: $ENV_FILE"

# Создание backup_pgsql.sh скрипта
BACKUP_SCRIPT="$BACKUP_DIR/backup_pgsql.sh"
cat <<'EOS' > "$BACKUP_SCRIPT"
#!/bin/bash

# Подключение переменных из .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "Файл .env не найден! Пожалуйста, создайте его."
  exit 1
fi

# Проверка обязательных переменных
REQUIRED_VARS=(DB_NAME DB_USER DB_HOST DB_PORT BACKUP_DIR PGPASSWORD FTP_HOST FTP_USER FTP_PASSWORD FTP_DIR DOCKER_CONTAINER_NAME DAYS_TO_KEEP)
for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    echo "Переменная $VAR отсутствует в файле .env. Проверьте настройки."
    exit 1
  fi
done

# Формирование имени дампа
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
DUMP_FILE="${BACKUP_DIR}/dumps/${DB_NAME}_${DATE}.sql"
COMPRESSED_FILE="${DUMP_FILE}.gz"

# Проверка, существует ли директория
if [ ! -d "$BACKUP_DIR/dumps" ]; then
  mkdir -p "$BACKUP_DIR/dumps"
fi

# Создание дампа и сжатие через Docker
docker exec "$DOCKER_CONTAINER_NAME" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$DUMP_FILE"
if [ $? -eq 0 ]; then
  gzip -9 "$DUMP_FILE"
  if [ $? -eq 0 ]; then
    echo "Дамп базы данных успешно создан и сжат: $COMPRESSED_FILE"

    # Проверка доступности FTP
    curl -s --head "ftp://$FTP_HOST" --user "$FTP_USER:$FTP_PASSWORD"
    if [ $? -ne 0 ]; then
      echo "FTP сервер недоступен!"
      exit 1
    fi

    # Отправка дампа на FTP
    curl -T "$COMPRESSED_FILE" --ftp-create-dirs -u "$FTP_USER:$FTP_PASSWORD" "ftp://$FTP_HOST/$FTP_DIR/"
    if [ $? -eq 0 ]; then
      echo "Дамп успешно отправлен на FTP: ftp://$FTP_HOST/$FTP_DIR/"

      # Удаление старых дампов с FTP
      FTP_LIST=$(curl -s -l --user "$FTP_USER:$FTP_PASSWORD" "ftp://$FTP_HOST/$FTP_DIR/")
      for FILE in $FTP_LIST; do
        if [[ "$FILE" == *.gz ]]; then
         echo "Обрабатываем файл: $FILE"
         FILE_TIMESTAMP=$(echo "$FILE" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}')
         if [[ -z "$FILE_TIMESTAMP" ]]; then
          echo "Не удалось извлечь временную метку из имени файла: $FILE"
          continue
         fi

         # Преобразование формата временной метки (замена "_" на пробел и "-" на ":")
         FORMATTED_TIMESTAMP=$(echo "$FILE_TIMESTAMP" | sed -E 's/_/ /; s/([0-9]{2})-([0-9]{2})-([0-9]{2})$/\1:\2:\3/')

         # Преобразование временной метки в UNIX-время
         FILE_DATE=$(date -d "$FORMATTED_TIMESTAMP" +%s 2>/dev/null)
          if [[ -z "$FILE_DATE" ]]; then
          echo "Некорректный формат даты: $FORMATTED_TIMESTAMP"
          continue
          fi
         echo "Извлеченная временная метка: $FILE_TIMESTAMP"
         CURRENT_DATE=$(date +%s)
         MAX_AGE=$((DAYS_TO_KEEP * 24 * 60 * 60))  # Конвертация дней в секунды
         if (( (CURRENT_DATE - FILE_DATE) > MAX_AGE )); then
          echo "Файл $FILE старше $((MAX_AGE / 86400)) дней. Удаляем..."
          curl -s --user "$FTP_USER:$FTP_PASSWORD" --quote "DELE $FTP_DIR/$FILE" "ftp://$FTP_HOST"
         fi
        fi
      done
    else
      echo "Ошибка при отправке дампа на FTP!"
      exit 1
    fi
  else
    echo "Ошибка при сжатии дампа!"
    exit 1
  fi
else
  echo "Ошибка при создании дампа базы данных!"
  exit 1
fi
# Удаление старых локальных дампов
find "$BACKUP_DIR/dumps" -type f -name "*.sql.gz" -mtime +$DAYS_TO_KEEP -exec rm -f {} \;
if [ $? -eq 0 ]; then
  echo "Старые локальные дампы (старше $DAYS_TO_KEEP дней) удалены."
else
  echo "Ошибка при удалении старых локальных дампов."
  exit 1
fi
EOS
echo "Скрипт backup_pgsql.sh создан: $BACKUP_SCRIPT"

# Делаем скрипт исполняемым
sudo chmod +x "$BACKUP_SCRIPT"

# Добавление задачи в crontab через sudo
CRON_JOB="$CRONTAB_TIME cd $BACKUP_DIR && /bin/bash $BACKUP_SCRIPT"
sudo bash -c "(crontab -u $CRON_USER -l 2>/dev/null; echo \"$CRON_JOB\") | crontab -u $CRON_USER -"
if [ $? -eq 0 ]; then
  echo "Задача добавлена в crontаb пользователя $CRON_USER: $CRON_JOB"
else
  echo "Ошибка при добавлении задачи в crontab!"
  exit 1
fi
