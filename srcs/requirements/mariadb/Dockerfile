FROM debian:bookworm

RUN apt-get update && apt-get install -y mariadb-server mariadb-client

RUN mkdir -p /run/mysqld

RUN chown -R mysql:mysql /run/mysqld

COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

EXPOSE 3306

ENTRYPOINT ["/setup.sh"]
