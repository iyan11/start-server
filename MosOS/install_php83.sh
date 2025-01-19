#!/bin/bash

#Установка php8.3 + Postgres16 для MosOS

# Обновите пакетный менеджер
sudo zypper refresh

# Установите необходимые зависимости
sudo zypper install -y gcc make libxml2-devel libcurl-devel libopenssl-devel readline-devel sqlite3-devel libicu-devel

# Скачайте и установите PostgreSQL 16
cd /usr/local/src
sudo wget https://ftp.postgresql.org/pub/source/v16.0/postgresql-16.0.tar.gz
sudo tar -xzf postgresql-16.0.tar.gz
cd postgresql-16.0
sudo ./configure
sudo make
sudo make install

# Настройте переменные окружения для PostgreSQL
export PATH=/usr/local/pgsql/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/pgsql/lib:$LD_LIBRARY_PATH

# Создайте группу postgres
sudo groupadd postgres

# Создайте пользователя postgres и добавьте его в группу postgres
sudo useradd -m -d /var/lib/pgsql -s /bin/bash -g postgres postgres
sudo passwd postgres

# Создайте директорию данных PostgreSQL
sudo mkdir -p /usr/local/pgsql/data

# Измените владельца директории данных PostgreSQL
sudo chown -R postgres:postgres /usr/local/pgsql/data

# Инициализируйте базу данных PostgreSQL
sudo -u postgres /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data

# Создайте файл журнала с правильными правами доступа
sudo touch /usr/local/pgsql/logfile
sudo chown postgres:postgres /usr/local/pgsql/logfile

# Запустите PostgreSQL
sudo -u postgres /usr/local/pgsql/bin/pg_ctl -D /usr/local/pgsql/data -l /usr/local/pgsql/logfile start

# Скачайте и установите Oniguruma
cd /usr/local/src
sudo wget https://github.com/kkos/oniguruma/releases/download/v6.9.7/onig-6.9.7.tar.gz
sudo tar -xzf onig-6.9.7.tar.gz
cd onig-6.9.7
sudo ./configure
sudo make
sudo make install

# Настройте переменные окружения для Oniguruma
export ONIG_CFLAGS="-I/usr/local/include"
export ONIG_LIBS="-L/usr/local/lib -lonig"

# Скачайте исходный код PHP 8.3
cd /usr/local/src
sudo wget https://www.php.net/distributions/php-8.3.0.tar.gz
sudo tar -xzf php-8.3.0.tar.gz
cd php-8.3.0

# Сконфигурируйте и соберите PHP с поддержкой PostgreSQL и ICU
sudo ./configure --with-config-file-path=/etc --with-config-file-scan-dir=/etc/php.d --enable-mbstring --enable-xml --with-curl --with-zlib --with-openssl --with-readline --with-libxml --with-sqlite3 --with-onig --with-pgsql --with-pdo-pgsql --with-icu
sudo make
sudo make install

# Создайте символическую ссылку для PHP
sudo ln -s /usr/local/bin/php /usr/bin/php

# Проверьте установку
php -v

# Добавьте путь к psql в переменную окружения PATH
export PATH=/usr/local/pgsql/bin:$PATH

# Проверьте, что psql теперь доступен
psql --version

# Переключитесь на пользователя postgres и запустите psql
sudo -i -u postgres /usr/local/pgsql/bin/psql

echo "PHP 8.3 и PostgreSQL 16 установлены успешно!"
