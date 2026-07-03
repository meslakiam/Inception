FROM debian:13

RUN apt-get update && \
    apt-get install -y nginx openssl && \
    apt-get clean

COPY srcs/secrets/nginx.crt /run/secrets/nginx.crt
COPY srcs/secrets/nginx.key /run/secrets/nginx.key

COPY srcs/requirements/nginx/conf/index.html /var/www/html/index.html


COPY srcs/requirements/nginx/conf/nginx.sh /setup.sh

RUN chmod +x /setup.sh

EXPOSE 443

ENTRYPOINT ["/setup.sh"]
