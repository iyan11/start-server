#!/bin/bash

#Открываем порты для nginx

# Откройте порты 80 и 443
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

echo "Порты 80 и 443 открыты успешно!"