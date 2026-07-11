FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    php-fpm \
    php-mysql \
    php-cli \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-soap \
    php-intl \
    php-zip \
    mariadb-client \
    curl \
    unzip\
    && apt-get clean

RUN apt-get install -y php-redis

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

    

RUN mkdir -p /run/php
RUN mkdir -p /var/www/html

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

WORKDIR /var/www/html

ENTRYPOINT ["/setup.sh"]