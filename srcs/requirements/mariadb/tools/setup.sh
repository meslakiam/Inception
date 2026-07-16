#!/bin/sh
set -e

ROOT_PASSWORD="${db_root_password:-}"
DB_PASSWORD="${db_user_password:-}"

[ -f /run/secrets/db_root_password ] && ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
[ -f /run/secrets/db_user_password ] && DB_PASSWORD=$(cat /run/secrets/db_user_password)

echo "Configuring MariaDB..."

cat > /etc/mysql/mariadb.conf.d/my.cnf <<EOF
[mysqld]
bind-address=0.0.0.0
port=${DB_PORT}
datadir=/var/lib/mysql
EOF

# Start MariaDB only for initialization
mysqld --user=mysql --skip-networking &

echo "Waiting for MariaDB..."

until mariadb-admin ping --silent; do
    sleep 1
done

echo "Creating WordPress database..."
# echo "********DB_USER: $DB_USER"
# echo "********db_user_password: $db_user_password"
# echo "********DB_NAME_IN_MARIADB: $DB_NAME_IN_MARIADB"
# echo "********DB_ROOT_USER: $DB_ROOT_USER"
# echo "********db_root_password: $db_root_password"
# echo "********DB_PORT: $DB_PORT"

mariadb -u ${DB_ROOT_USER} -p"${ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME_IN_MARIADB};

CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES ON ${DB_NAME_IN_MARIADB}.* TO '${DB_USER}'@'%';

ALTER USER '${DB_ROOT_USER}'@'localhost'
IDENTIFIED BY '${ROOT_PASSWORD}';

FLUSH PRIVILEGES;
EOF

echo "Stopping temporary MariaDB..."

mariadb-admin -u ${DB_ROOT_USER} -p"${ROOT_PASSWORD}" shutdown

echo "Starting MariaDB..."

exec mysqld --user=mysql