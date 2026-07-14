#!/bin/bash

set -e

mkdir -p /run/php

wget -O /var/www/adminer/index.php \
    "https://github.com/vrana/adminer/releases/download/v5.4.2/adminer-5.4.2.php"

if command -v php-fpm >/dev/null 2>&1; then
    exec php-fpm -F
elif command -v php8.2-fpm >/dev/null 2>&1; then
    exec php8.2-fpm -F
elif command -v php-fpm8.2 >/dev/null 2>&1; then
    exec php-fpm8.2 -F
else
    echo "php-fpm binary not found" >&2
    exit 1
fi