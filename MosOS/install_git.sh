#!/bin/bash

#Установка git для MosOS

# Обновление системы
sudo zypper refresh
sudo zypper update -y

# Установка необходимых пакетов
sudo zypper install -y wget make gcc gcc-c++

# Проверка наличия библиотеки libsha1detectcoll.so.1
if ! ldconfig -p | grep -q libsha1detectcoll.so.1; then
    echo "Библиотека libsha1detectcoll.so.1 не найдена. Установка ICU..."

    # Скачивание и установка ICU
    wget https://github.com/unicode-org/icu/releases/download/release-67-1/icu4c-67_1-src.tgz
    tar -xzvf icu4c-67_1-src.tgz
    cd icu/source
    ./runConfigureICU Linux
    make
    sudo make install

    # Обновление кэша библиотек
    sudo ldconfig

    # Возврат в исходную директорию
    cd ../..
else
    echo "Библиотека libsha1detectcoll.so.1 найдена."
fi

# Установка Git
sudo zypper install -y git

# Настройка переменных окружения
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Проверка версии Git
git --version

echo "Установка и настройка Git завершена."
