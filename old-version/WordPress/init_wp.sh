#!/bin/sh

WP_PATH=/var/www/wordpress
WP_CONFIG=$WP_PATH/wp-config.php

if [ ! -f "$WP_CONFIG" ]; then
  cp $WP_PATH/wp-config-sample.php $WP_CONFIG

  sed -i "s/database_name_here/$WP_DB_NAME/" $WP_CONFIG
  sed -i "s/username_here/$WP_DB_USER/" $WP_CONFIG
  sed -i "s/password_here/$WP_DB_PASSWORD/" $WP_CONFIG
  sed -i "s/localhost/$WP_DB_HOST/" $WP_CONFIG
fi

exec php-fpm83 -F