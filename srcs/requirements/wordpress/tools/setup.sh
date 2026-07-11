#!/bin/sh
set -e

mkdir -p /run/php

cd /var/www/html

DB_PASSWORD="${MARIADB_PASSWORD:-}"
ADMIN_PASSWORD="${WORDPRESS_ADMIN_PASSWORD:-}"
USER_PASSWORD="${WORDPRESS_USER_PASSWORD:-}"

[ -f /run/secrets/mariadb_password ] && DB_PASSWORD=$(cat /run/secrets/mariadb_password)
[ -f /run/secrets/wordpress_admin_password ] && ADMIN_PASSWORD=$(cat /run/secrets/wordpress_admin_password)
[ -f /run/secrets/wordpress_user_password ] && USER_PASSWORD=$(cat /run/secrets/wordpress_user_password)

if [ ! -f wp-config.php ]; then

    echo "Downloading WordPress..."

    wp core download --allow-root --force

    echo "Waiting for MariaDB..."

    until mariadb-admin \
        --host=$WORDPRESS_DB_HOST \
        --user=$MARIADB_USER \
        --password=$DB_PASSWORD \
        ping --silent
    do
        sleep 2
    done

    echo "Creating wp-config.php..."

    wp config create \
        --allow-root \
        --dbname=$WORDPRESS_DB_NAME \
        --dbuser=$MARIADB_USER \
        --dbpass=$DB_PASSWORD \
        --dbhost=$WORDPRESS_DB_HOST

    echo "Installing WordPress..."

    wp core install \
        --allow-root \
        --url=$DOMAIN_NAME \
        --title="$WORDPRESS_TITLE" \
        --admin_user=$WORDPRESS_ADMIN_USER \
        --admin_password=$ADMIN_PASSWORD \
        --admin_email=$WORDPRESS_ADMIN_EMAIL

    wp user create \
        $WORDPRESS_USER \
        $WORDPRESS_USER_EMAIL \
        --role=author \
        --user_pass=$USER_PASSWORD \
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