#!/bin/bash

set -e

if [ -f /run/secrets/ftp_password ]; then
    FTP_PASSWORD=$(cat /run/secrets/ftp_password)
else
    FTP_PASSWORD="${FTP_PASSWORD:-}"
fi

if ! id "$FTP_USER" >/dev/null 2>&1; then
    useradd -m "$FTP_USER"
fi

echo "$FTP_USER:$FTP_PASSWORD" | chpasswd

#add ftp user to www-data group (so it can modify files in /var/www/html)
usermod -aG www-data "$FTP_USER"

mkdir -p /var/run/vsftpd/empty

chown -R $FTP_USER:$FTP_USER /var/www/html

exec /usr/sbin/vsftpd /etc/vsftpd.conf