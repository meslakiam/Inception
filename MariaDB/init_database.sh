#!/bin/sh
# This runs on first container startup

# Start MariaDB temporarily in background
mysqld --user=mysql --skip-networking &
MYSQL_PID=$!

# Wait for MariaDB to be ready
until mariadb-admin ping -u root --silent; do sleep 1; done

# Create database and user
mariadb <<EOF
CREATE DATABASE IF NOT EXISTS ${WP_DB_NAME};
CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'%' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${WP_DB_NAME}.* TO '${WP_DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# Stop temporary MariaDB
kill $MYSQL_PID
wait $MYSQL_PID

mysqld --user=mysql --console --skip-networking=0

# The CMD will start MariaDB normally in forground