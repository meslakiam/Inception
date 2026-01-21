FROM alpine:latest

RUN apk update  && apk upgrade && apk add mariadb  && apk add mariadb-client && \
        mkdir -p /run/mysqld /var/lib/mysql && \
        chown -R mysql:mysql /run/mysqld /var/lib/mysql && \
        mysql_install_db --user=mysql --datadir=/var/lib/mysql

COPY init_database.sh /

RUN chmod 777 /init_database.sh

EXPOSE 3306


CMD ["./init_database.sh"]

