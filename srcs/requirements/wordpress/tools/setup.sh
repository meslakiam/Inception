#!/bin/sh
set -e

mkdir -p /run/php

cd /var/www/html

DB_PASSWORD="${db_user_password:-}"
ADMIN_PASSWORD="${WORDPRESS_ADMIN_PASSWORD:-}"
USER_PASSWORD="${WORDPRESS_USER_PASSWORD:-}"

[ -f /run/secrets/db_user_password ] && DB_PASSWORD=$(cat /run/secrets/db_user_password)
[ -f /run/secrets/wordpress_admin_password ] && ADMIN_PASSWORD=$(cat /run/secrets/wordpress_admin_password)
[ -f /run/secrets/wordpress_user_password ] && USER_PASSWORD=$(cat /run/secrets/wordpress_user_password)

# Create a must-use plugin that adds a floating login icon on the frontend.
mkdir -p /var/www/html/wp-content/mu-plugins

cat > /var/www/html/wp-content/mu-plugins/admin-login-icon.php <<'EOF'
<?php
/*
Plugin Name: Admin Login Icon
Description: Shows a floating login icon that links to wp-admin.
*/

if (!defined('ABSPATH')) {
    exit;
}

add_action('wp_footer', function () {
    if (is_admin()) {
        return;
    }

    $login_url = esc_url(home_url('/wp-admin/'));
    echo '<a href="' . $login_url . '" class="admin-login-icon" aria-label="Login">';
    echo '&#128274;';
    echo '</a>';
    echo '<style>';
    echo '.admin-login-icon{position:fixed;right:20px;bottom:20px;z-index:9999;width:52px;height:52px;border-radius:50%;display:flex;align-items:center;justify-content:center;text-decoration:none;font-size:24px;background:#111;color:#fff;box-shadow:0 8px 24px rgba(0,0,0,.25);}';
    echo '.admin-login-icon:hover{transform:translateY(-2px);transition:transform .15s ease;background:#000;}';
    echo '@media (max-width:768px){.admin-login-icon{right:14px;bottom:14px;width:46px;height:46px;font-size:20px;}}';
    echo '</style>';
});
EOF

# Configure WordPress on the first start.
if [ ! -f wp-config.php ]; then

    echo "Downloading WordPress..."

    wp core download --allow-root --force

    echo "Waiting for MariaDB..."

    until mariadb-admin \
        --host=$WORDPRESS_DB_HOST \
        --user=$DB_USER \
        --password=$DB_PASSWORD \
        ping --silent
    do
        sleep 2
    done

    echo "Creating wp-config.php..."

    wp config create \
        --allow-root \
        --dbname=$DB_NAME_IN_MARIADB \
        --dbuser=$DB_USER \
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

    # WordPress and wp-config.php now exist, so Redis can be installed safely.
    wp plugin install redis-cache --activate --allow-root
    wp config set WP_REDIS_HOST redis --allow-root
    wp config set WP_REDIS_PORT "$REDIS_PORT" --raw --allow-root

fi

#enable Redis Object Cache plugin
wp redis enable --allow-root

chown -R www-data:www-data /var/www/html
chmod -R g+rwX /var/www/html



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
