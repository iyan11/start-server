#!/bin/bash

# Скрипт для установки C++ компилятора, CMake, сборки libzip, пересборки PHP с поддержкой zip и настройки php.ini на SUSE Linux 15.4
# Запуск: chmod +x setup_libzip_php.sh && sudo ./setup_libzip_php.sh

set -e

echo "Обновление репозиториев..."
sudo zypper refresh

# 1. Установка C++ компилятора (gcc и g++)
echo "Установка C++ компилятора (gcc и g++)..."
sudo zypper install -y gcc gcc-c++ make libtool pkg-config

echo "Проверка установки компилятора..."
gcc --version && g++ --version

# 2. Установка CMake (если отсутствует)
CMAKE_VERSION=3.28.3
CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz"

if ! command -v cmake &> /dev/null; then
    echo "CMake не найден. Устанавливаю CMake v${CMAKE_VERSION}..."

    # Скачивание исходников
    wget ${CMAKE_URL} -O /tmp/cmake.tar.gz
    cd /tmp
    tar -xzf cmake.tar.gz
    cd cmake-${CMAKE_VERSION}

    # Сборка и установка
    ./bootstrap
    make -j$(nproc)
    sudo make install

    # Проверка установки
    cmake --version
else
    echo "CMake уже установлен: $(cmake --version | head -n1)"
fi

# 3. Установка сборочных утилит (autoconf, automake, m4), если они отсутствуют
echo "Проверка установки сборочных утилит..."

if ! command -v autoconf &> /dev/null || ! command -v automake &> /dev/null; then
    echo "Установка сборочных утилит (autoconf, automake, m4)..."

    # Проверка существующих репозиториев
    sudo zypper addrepo https://download.opensuse.org/distribution/leap/15.4/repo/oss/ leap-oss
    sudo zypper refresh

    # Установка необходимых утилит
    sudo zypper install -y autoconf automake m4

    # Проверка установки
    autoconf --version
    automake --version
else
    echo "autoconf и automake уже установлены."
fi

# 4. Сборка и установка libzip
LIBZIP_VERSION=1.10.1
LIBZIP_URL="https://libzip.org/download/libzip-${LIBZIP_VERSION}.tar.gz"

echo "Скачивание и сборка libzip v${LIBZIP_VERSION}..."
cd /tmp
wget ${LIBZIP_URL} -O /tmp/libzip.tar.gz
tar -xzf libzip.tar.gz
cd libzip-${LIBZIP_VERSION}

# Сборка libzip
mkdir -p build
cd build
cmake ..
make -j$(nproc)
sudo make install

# Обновление конфигурации динамического линкера
sudo ldconfig

echo "libzip успешно собран и установлен."

# 5. Пересборка PHP с поддержкой zip
PHP_SOURCE_DIR="/usr/local/src/php-8.3.0"  # Укажите правильный путь к исходникам PHP
PHP_INSTALL_PREFIX="/usr/local/php8"     # Путь для установки PHP

echo "Пересборка PHP с поддержкой zip..."

if [ ! -d "$PHP_SOURCE_DIR" ]; then
    echo "Ошибка: директория с исходниками PHP не найдена: $PHP_SOURCE_DIR"
    exit 1
fi

cd "$PHP_SOURCE_DIR"

# Конфигурация и сборка PHP с флагами для zip
./configure --prefix=$PHP_INSTALL_PREFIX --with-zip --with-libzip=/usr/local --enable-mbstring --with-curl --with-openssl --with-zlib
make -j$(nproc)
sudo make install

echo "PHP успешно пересобран с поддержкой zip."

# 6. Настройка php.ini
PHP_INI_PATH="$PHP_INSTALL_PREFIX/lib/php.ini"

echo "Настройка php.ini..."

if [ ! -f "$PHP_INI_PATH" ]; then
    echo "Создаю php.ini..."
    sudo cp "$PHP_SOURCE_DIR/php.ini-production" "$PHP_INI_PATH"
fi

# Добавляем настройки для модуля zip и базовые параметры
sudo tee -a "$PHP_INI_PATH" > /dev/null <<EOL

; ==============================
; Дополнительные настройки PHP
; ==============================
extension=zip

; Основные параметры PHP
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
date.timezone = "UTC"
EOL

echo "php.ini настроен по пути: $PHP_INI_PATH"

# 7. Проверка модуля zip
echo "Проверка модуля zip в PHP..."
$PHP_INSTALL_PREFIX/bin/php -m | grep zip && echo "Модуль zip успешно активирован в PHP." || echo "Ошибка: модуль zip не активирован."

echo "Все задачи успешно выполнены!"
