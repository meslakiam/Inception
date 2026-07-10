FROM debian:13

RUN apt-get update && \
    apt-get install -y nginx openssl && \
    apt-get clean


COPY conf/nginx.sh /setup.sh

RUN chmod +x /setup.sh

EXPOSE 443

ENTRYPOINT ["/setup.sh"]
