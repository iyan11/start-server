#!/bin/bash

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

# Функция для выполнения скрипта Ubuntu
run_ubuntu_script() {
    chmod +x ./Ubuntu/start.sh
    dialog --infobox "Запуск скрипта для Ubuntu..." 5 40
    sleep 1
    clear
    ./Ubuntu/start.sh
}

# Функция для выполнения скрипта SUSE Linux
run_suse_script() {
    chmod +x ./MosOS/start.sh
    dialog --infobox "Запуск скрипта для MosOS..." 5 40
    sleep 1
    clear
    ./MosOS/start.sh
}

# Основное меню
while true; do
    choice=$(dialog --clear \
                    --backtitle "Выбор операционной системы" \
                    --title "Меню" \
                    --menu "Выберите операционную систему:" \
                    15 50 4 \
                    1 "Ubuntu" \
                    2 "MosOS" \
                    3 "Выход" \
                    2>&1 >/dev/tty)

    case $choice in
        1)
            run_ubuntu_script
            break
            ;;
        2)
            run_suse_script
            break
            ;;
        *)
            dialog --infobox "Выход из программы." 5 40
            sleep 1
            clear
            break
            ;;
    esac
done
