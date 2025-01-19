#!/bin/bash

# Загрузка переменных из файла .env
set -a
source .env
set +a

# Функция для установки dialog на Ubuntu
install_dialog_ubuntu() {
    sudo apt-get update
    sudo apt-get install -y dialog
}

# Функция для установки dialog на SUSE Linux
install_dialog_suse() {
    sudo zypper refresh
    sudo zypper install -y dialog
}

# Проверка наличия dialog и установка, если необходимо
if ! command -v dialog &> /dev/null; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu)
                install_dialog_ubuntu
                ;;
            suse)
                install_dialog_suse
                ;;
            *)
                echo "Неподдерживаемая операционная система."
                exit 1
                ;;
        esac
    else
        echo "Не удалось определить операционную систему."
        exit 1
    fi
fi

# Функция для обновления и установки пакетов
update_and_install_packages() {
    dialog --infobox "Выполняется установка и обновление пакетов" 5 40
    sleep 2
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get install -y nano screen bashtop aptitude
    dialog --msgbox "Пакеты установлены и обновлены." 5 40
}

# Функция для установки PostgresSQL и PostGIS
install_postgresql_and_postgis() {
    dialog --infobox "Выполняется установка PostgresSQL + PostGIS" 5 40
    sleep 2
    sudo apt-get install -y postgresql-$POSTGRESQL_VERSION postgresql-$POSTGRESQL_VERSION-postgis-3
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION postgis;"
    dialog --msgbox "PostgresSQL и PostGIS установлены." 5 40
}

# Функция для установки PHP и необходимых модулей
install_php() {
    dialog --infobox "Выполняется установка PHP" 5 40
    sleep 2
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository ppa:ondrej/php
    sudo apt-get update
    sudo apt-get install -y php$PHP_VERSION php$PHP_VERSION-fpm php$PHP_VERSION-cli php$PHP_VERSION-common php$PHP_VERSION-zip php$PHP_VERSION-gd php$PHP_VERSION-mbstring php$PHP_VERSION-curl php$PHP_VERSION-xml php$PHP_VERSION-bcmath php$PHP_VERSION-pgsql php$PHP_VERSION-pdo php$PHP_VERSION-imagick php$PHP_VERSION-bcmath php$PHP_VERSION-gd php$PHP_VERSION-dom php-pear
    dialog --msgbox "PHP установлен." 5 40
}

# Функция для установки и настройки Nginx
install_and_configure_nginx() {
    dialog --infobox "Выполняется установка NGINX" 5 40
    sleep 2
    sudo apt-get install -y nginx
    sudo systemctl enable nginx
    sudo systemctl restart nginx
    sudo mkdir $NGINX_SSL_DIR
    sudo cp -r ../certs/* $NGINX_SSL_DIR
    dialog --msgbox "NGINX установлен и настроен." 5 40
}

# Функция для добавления домена в Nginx
add_nginx_domain() {
    dialog --infobox "Добавление домена в NGINX" 5 40
    sleep 2
    DOMAIN_NAME=$(dialog --inputbox "Введите имя домена:" 10 40 3>&1 1>&2 2>&3 3>&-)
    sudo tee /etc/nginx/sites-available/$DOMAIN_NAME <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $NGINX_ROOT;
    index $NGINX_INDEX;
    client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }

    listen 443 ssl;
    ssl_certificate $NGINX_SSL_DIR/$NGINX_SSL_CERTIFICATE;
    ssl_certificate_key $NGINX_SSL_DIR/$NGINX_SSL_CERTIFICATE_KEY;
}
EOF

    sudo ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl reload nginx
    sudo systemctl restart nginx
    dialog --msgbox "Домен добавлен в NGINX." 5 40
}

# Функция для установки Composer и Git
install_composer_and_git() {
    dialog --infobox "Выполняется установка composer и git" 5 40
    sleep 2
    sudo apt-get install -y composer git
    dialog --msgbox "Composer и Git установлены." 5 40
}

# Функция для настройки безопасности SSH
add_user_ssh() {
    dialog --infobox "Добавление пользователя SSH" 5 40
    sleep 2
    read -p "Введите имя пользователя: " USERNAME
    sudo adduser $USERNAME
    sudo su - $USERNAME -c "mkdir -p ~/.ssh && nano ~/.ssh/authorized_keys"
    # Вставьте ваш публичный ключ в файл authorized_keys
    sudo chmod 700 /home/$USERNAME/.ssh
    sudo chmod 600 /home/$USERNAME/.ssh/authorized_keys
    sudo usermod -aG sudo $USERNAME
    sudo usermod -aG www-data $USERNAME
    sudo usermod -aG docker $USERNAME
    dialog --msgbox "Пользователь SSH добавлен." 5 40
}

# Функция для удаления пользователя SSH
remove_ssh_user() {
    SSH_USER=$(dialog --inputbox "Введите имя пользователя SSH для удаления:" 10 40 3>&1 1>&2 2>&3 3>&-)
    sudo userdel -r $SSH_USER
    dialog --msgbox "Пользователь SSH $SSH_USER удалён." 5 40
}

# Функция настройки SSH
configure_ssh_security() {
    dialog --infobox "Выполняется настройка SSH" 5 40
    sleep 2
    sudo systemctl restart ssh
    sudo systemctl enable ssh
    sudo sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
    sudo sed -i "s/PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
    sudo sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
    sudo sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
    echo "PasswordAuthentication no" | sudo tee /etc/ssh/sshd_config.d/50-cloud-init.conf
    sudo sshd -t
    sudo systemctl restart sshd
    dialog --msgbox "SSH настроен." 5 40
}

# Функция для изменения порта PostgresSQL
change_postgresql_port() {
    dialog --infobox "Выполняется изменение порта PostgresSQL" 5 40
    sleep 2
    sudo sed -i "s/#port = 5432/port = $PG_PORT/" /etc/postgresql/$POSTGRESQL_VERSION/main/postgresql.conf
    sudo sed -i "s/port = 5432/port = $PG_PORT/" /etc/postgresql/$POSTGRESQL_VERSION/main/postgresql.conf
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$POSTGRESQL_VERSION/main/postgresql.conf
    sudo systemctl restart postgresql
    dialog --msgbox "Порт PostgresSQL изменён." 5 40
}

# Функция для добавления пользователей в PostgresSQL
add_postgresql_user() {
    dialog --infobox "Добавление пользователя PostgresSQL" 5 40
    sleep 2
    read -p "Введите имя пользователя: " USERNAME
    USER_PASSWORD=$(dialog --passwordbox "Введите пароль пользователя PostgresSQL:" 10 40 3>&1 1>&2 2>&3 3>&-)
    sudo -u postgres psql -c "CREATE USER $USERNAME WITH PASSWORD '$USER_PASSWORD' SUPERUSER;"
    sudo -u postgres psql -c "CREATE DATABASE $USERNAME;"
    sudo -u postgres psql -d $USERNAME -c "CREATE EXTENSION postgis;"
    dialog --msgbox "Пользователь PostgresSQL добавлен." 5 40
}

# Функция для удаления пользователя PostgresSQL
remove_postgresql_user() {
    PG_USER=$(dialog --inputbox "Введите имя пользователя PostgresSQL для удаления:" 10 40 3>&1 1>&2 2>&3 3>&-)
    sudo -u postgres psql -c "DROP USER $PG_USER;"
    sudo -u postgres psql -c "DROP DATABASE $PG_USER;"
    dialog --msgbox "Пользователь PostgresSQL $PG_USER и его база данных удалены." 5 40
}

# Функция добавления возможности подключения к PostgresSQL из вне
open_postgres_enter() {
    dialog --infobox "Добавление возможности подключения к PostgresSQL из вне" 5 40
    sleep 2
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$POSTGRESQL_VERSION/main/pg_hba.conf
    sudo systemctl restart postgresql
    dialog --msgbox "Возможность подключения к PostgresSQL из вне добавлена." 5 40
}

#Функция сохдания и ssh, и postgres пользователя
add_ssh_and_postgres_user() {
    dialog --infobox "Добавление пользователя SSH и PostgresSQL" 5 40
    sleep 2
    #USERNAME=$(dialog --inputbox "Введите имя пользователя:" 10 40 3>&1 1>&2 2>&3 3>&-)
    read -p "Введите имя пользователя: " USERNAME
    sudo adduser $USERNAME
    sudo su - $USERNAME -c "mkdir -p ~/.ssh && nano ~/.ssh/authorized_keys"
    # Вставьте ваш публичный ключ в файл authorized_keys
    sudo chmod 700 /home/$USERNAME/.ssh
    sudo chmod 600 /home/$USERNAME/.ssh/authorized_keys
    sudo usermod -aG sudo $USERNAME
    sudo usermod -aG www-data $USERNAME
    sudo usermod -aG docker $USERNAME
    echo "Введите пароль пользователя PostgresSQL: "
    read -s USER_PASSWORD
    sudo -u postgres psql -c "CREATE USER $USERNAME WITH PASSWORD '$USER_PASSWORD' SUPERUSER;"
    sudo -u postgres psql -c "CREATE DATABASE $USERNAME;"
    sudo -u postgres psql -d $USERNAME -c "CREATE EXTENSION postgis;"
    dialog --msgbox "Пользователь SSH и PostgresSQL добавлен." 5 40
}

#Функция установки Docker
install_docker() {
    dialog --infobox "Выполняется установка Docker" 5 40
    sleep 2
    # Установите необходимые пакеты
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    # Добавьте официальный GPG-ключ Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Добавьте репозиторий Docker
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    # Обновите пакеты снова
    sudo apt-get update

    # Установите Docker
    sudo apt-get install -y docker-ce

    # Проверьте установку Docker
    sudo systemctl status docker

    # Скачайте текущую стабильную версию Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K[^"]*')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    # Примените исполняемые права на бинарный файл
    sudo chmod +x /usr/local/bin/docker-compose

    # Проверьте установку Docker Compose
    docker-compose --version

    # Создайте группу docker, если она не существует
    sudo groupadd docker || true

    # Пройдитесь по всем пользователям и добавьте их в группу docker
    for user in $(cut -f1 -d: /etc/passwd); do
        sudo usermod -aG docker $user
    done
    dialog --msgbox "Docker установлен. Пожалуйста, перезайдите, чтобы изменения вступили в силу." 5 40
}

day_or_weekly() {
    res=$(dialog --clear \
                   --backtitle "Создание бэкапов" \
                   --title "Меню" \
                   --menu "Укажи период бекапов?" \
                   20 60 16 \
                   1 "Раз в неделю" \
                   2 "Раз в день" \
                   3 "Назад" \
                   4 "Выход" \
                   2>&1 >/dev/tty)
      case $res in
        1) echo "CRONTAB_TIME=@weekly" >> Ubuntu/.env_backup
           where_docker ;;
        2) echo "CRONTAB_TIME='0 2 * * *'" >> Ubuntu/.env_backup
           where_docker ;;
        3) return ;;
        4) dialog --infobox "Выход из скрипта." 5 40
             sleep 2
             clear
             exit ;;
     esac
}

where_docker() {
  res=$(dialog --clear \
                   --backtitle "Создание бэкапов" \
                   --title "Меню" \
                   --menu "У вас Postgres в Docker?" \
                   20 60 16 \
                   1 "Да" \
                   2 "Нет" \
                   3 "Назад" \
                   4 "Выход" \
                   2>&1 >/dev/tty)
      case $res in
        1) chmod +x Ubuntu/backup_docker.sh
           bash Ubuntu/backup_docker.sh ;;
        2) chmod +x Ubuntu/backup.sh
           bash Ubuntu/backup.sh ;;
        3) return ;;
        4) dialog --infobox "Выход из скрипта." 5 40
             sleep 2
             clear
             exit ;;
     esac
}

#Функция создания бэкапов
create_backups() {
    res=$(dialog --clear \
                 --backtitle "Создание бэкапов" \
                 --title "Меню" \
                 --menu "Вы настроили .env_backup?" \
                 20 60 16 \
                 1 "Да" \
                 2 "Нет (настроить)" \
                 3 "Назад" \
                 4 "Выход" \
                 2>&1 >/dev/tty)
    case $res in
      1) day_or_weekly ;;
      2) cp Ubuntu/env_backup.example Ubuntu/.env_backup
         nano Ubuntu/.env_backup
         create_backups ;;
      3) return ;;
      4) dialog --infobox "Выход из скрипта." 5 40
           sleep 2
           clear
           exit ;;
   esac
}

# Основное меню
while true; do
    choice=$(dialog --clear \
                    --backtitle "Настройка сервера" \
                    --title "Меню" \
                    --menu "Выберите опцию:" \
                    20 60 16 \
                    1 "Обновить и установить пакеты" \
                    2 "Установить PostgresSQL и PostGIS" \
                    3 "Установить PHP" \
                    4 "Установить и настроить Nginx" \
                    5 "Добавить домен в Nginx" \
                    6 "Установить Composer и Git" \
                    7 "Настроить безопасность SSH" \
                    8 "Изменить порт PostgresSQL" \
                    9 "Добавить пользователя SSH и PostgresSQL" \
                    10 "Выполнить все шаги" \
                    11 "Добавить пользователя SSH" \
                    12 "Добавить пользователя в PostgresSQL" \
                    13 "Удалить пользователя SSH" \
                    14 "Удалить пользователя PostgresSQL" \
                    15 "Установить Docker" \
                    16 "Создать скрипт бекапов (обязательно настроить .env_backup)" \
                    0 "Выход" \
                    2>&1 >/dev/tty)

    case $choice in
        1) update_and_install_packages ;;
        2) install_postgresql_and_postgis
           open_postgres_enter ;;
        3) install_php ;;
        4) install_and_configure_nginx ;;
        5) add_nginx_domain ;;
        6) install_composer_and_git ;;
        7) configure_ssh_security ;;
        8) change_postgresql_port ;;
        9) add_ssh_and_postgres_user ;;
        10) update_and_install_packages
            install_postgresql_and_postgis
            open_postgres_enter
            install_php
            install_and_configure_nginx
            install_composer_and_git
            configure_ssh_security
            change_postgresql_port
            add_ssh_and_postgres_user
            dialog --msgbox "Настройка сервера завершена!" 5 40 ;;
        11) add_user_ssh ;;
        12) add_postgresql_user ;;
        13) remove_ssh_user ;;
        14) remove_postgresql_user ;;
        15) install_docker ;;
        16) create_backups ;;
        *) dialog --infobox "Выход из скрипта." 5 40
           sleep 2
           clear
           break ;;
    esac
done

