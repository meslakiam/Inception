FROM debian:bookworm

RUN apt update && \
    apt install -y \
        php-fpm \
        php-mysqli \
        wget && \
    apt clean


COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf


RUN mkdir -p /var/www/adminer

COPY tools/setup.sh /

RUN chmod +x /setup.sh

ENTRYPOINT ["/setup.sh"]