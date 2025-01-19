#!/bin/bash

#Установка Nginx для MosOS

# Обновите пакетный менеджер
sudo zypper refresh

# Установите Nginx
sudo zypper install -y nginx

# Запустите и включите Nginx для автоматического запуска при загрузке системы
sudo systemctl start nginx
sudo systemctl enable nginx

# Создайте директорию snippets, если она не существует
sudo mkdir -p /etc/nginx/snippets

# Создайте файл fastcgi-php.conf
sudo bash -c 'cat > /etc/nginx/snippets/fastcgi-php.conf' <<EOF
# regex to split \$uri to \$fastcgi_script_name and \$fastcgi_path_info
fastcgi_split_path_info ^(.+\.php)(\/.+)\$;

# Check that the PHP script exists before passing it
try_files \$fastcgi_script_name =404;

# Bypass the fact that try_files resets \$fastcgi_path_info
# see: http://trac.nginx.org/nginx/ticket/321
set \$path_info \$fastcgi_path_info;
fastcgi_param PATH_INFO \$path_info;

fastcgi_index index.php;
include fastcgi.conf;
EOF

# Создайте конфигурационный файл для вашего сайта
sudo bash -c 'cat > /etc/nginx/conf.d/default.conf' <<EOF
server {
    listen 80;
    server_name your_domain_or_ip;

    root /usr/share/nginx/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Проверьте конфигурацию Nginx на наличие ошибок
sudo nginx -t

# Перезапустите Nginx для применения изменений
sudo systemctl restart nginx

echo "Nginx установлен и настроен успешно!"
