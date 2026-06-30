FROM alpine:latest

RUN apk update && apk upgrade && \
    apk add wget php83 php83-fpm php83-mysqli

RUN adduser -D -g 'www' www || true

RUN sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /etc/php83/php-fpm.d/www.conf && \
    sed -i 's|^;*clear_env =.*|clear_env = no|' /etc/php83/php-fpm.d/www.conf && \
    sed -i 's|^user = .*|user = www|' /etc/php83/php-fpm.d/www.conf && \
    sed -i 's|^group = .*|group = www|' /etc/php83/php-fpm.d/www.conf

WORKDIR /var/www

RUN wget https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz && rm latest.tar.gz && \
    chown -R www:www /var/www/wordpress && \
    chmod -R 755 /var/www/wordpress

COPY init_wp.sh /init_wp.sh

RUN chmod +x /init_wp.sh

EXPOSE 9000

CMD ["/init_wp.sh"]
