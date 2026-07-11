#!/bin/sh
set -e

ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"
DB_PASSWORD="${MARIADB_PASSWORD:-}"

[ -f /run/secrets/mariadb_root_password ] && ROOT_PASSWORD=$(cat /run/secrets/mariadb_root_password)
[ -f /run/secrets/mariadb_password ] && DB_PASSWORD=$(cat /run/secrets/mariadb_password)

echo "Configuring MariaDB..."

cat > /etc/mysql/mariadb.conf.d/my.cnf <<EOF
[mysqld]
bind-address=0.0.0.0
port=${MARIADB_PORT}
datadir=/var/lib/mysql
EOF

# Start MariaDB only for initialization
mysqld --user=mysql --skip-networking &

echo "Waiting for MariaDB..."

until mariadb-admin ping --silent; do
    sleep 1
done

echo "Creating WordPress database..."
# echo "********MARIADB_USER: $MARIADB_USER"
# echo "********MARIADB_PASSWORD: $MARIADB_PASSWORD"
# echo "********WORDPRESS_DB_NAME: $WORDPRESS_DB_NAME"
# echo "********MARIADB_ROOT_USER: $MARIADB_ROOT_USER"
# echo "********MARIADB_ROOT_PASSWORD: $MARIADB_ROOT_PASSWORD"
# echo "********MARIADB_PORT: $MARIADB_PORT"

mariadb -u ${MARIADB_ROOT_USER} -p"${ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${WORDPRESS_DB_NAME};

CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES ON ${WORDPRESS_DB_NAME}.* TO '${MARIADB_USER}'@'%';

ALTER USER '${MARIADB_ROOT_USER}'@'localhost'
IDENTIFIED BY '${ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF

echo "Stopping temporary MariaDB..."

mariadb-admin -u ${MARIADB_ROOT_USER} -p"${ROOT_PASSWORD}" shutdown

echo "Starting MariaDB..."

exec mysqld --user=mysql