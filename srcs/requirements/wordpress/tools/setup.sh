#!/bin/sh
set -e

mkdir -p /run/php

cd /var/www/html

if [ ! -f wp-config.php ]; then

    echo "Downloading WordPress..."

    wp core download --allow-root

    echo "Waiting for MariaDB..."

    until mariadb-admin \
        --host=$WORDPRESS_DB_HOST \
        --user=$MARIADB_USER \
        --password=$MARIADB_PASSWORD \
        ping --silent
    do
        sleep 2
    done

    echo "Creating wp-config.php..."

    wp config create \
        --allow-root \
        --dbname=$WORDPRESS_DB_NAME \
        --dbuser=$MARIADB_USER \
        --dbpass=$MARIADB_PASSWORD \
        --dbhost=$WORDPRESS_DB_HOST

    echo "Installing WordPress..."

    wp core install \
        --allow-root \
        --url=$DOMAIN_NAME \
        --title="$WORDPRESS_TITLE" \
        --admin_user=$WORDPRESS_ADMIN_USER \
        --admin_password=$WORDPRESS_ADMIN_PASSWORD \
        --admin_email=$WORDPRESS_ADMIN_EMAIL

    wp user create \
        $WORDPRESS_USER \
        $WORDPRESS_USER_EMAIL \
        --role=author \
        --user_pass=$WORDPRESS_USER_PASSWORD \
        --allow-root

    chown -R www-data:www-data /var/www/html
fi

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