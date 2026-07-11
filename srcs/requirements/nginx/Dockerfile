FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y nginx openssl && \
    apt-get clean


COPY conf/nginx.sh /setup.sh

RUN chmod +x /setup.sh

EXPOSE ${NGINX_PORT}

ENTRYPOINT ["/setup.sh"]
