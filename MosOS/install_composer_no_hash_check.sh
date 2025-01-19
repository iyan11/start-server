#!/bin/bash

#Установка composer на MosOS

# Скачайте и установите Composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"

# Переместите composer.phar в директорию /usr/local/bin и сделайте его исполняемым
sudo mv composer.phar /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer

# Проверьте установку Composer
composer --version

echo "Composer установлен успешно!"
