FROM alpine:latest

RUN apk update  && apk upgrade && \
    apk add nginx && apk add openssl

RUN  mkdir -p /var/www/html /run/nginx && \
    mkdir -p /etc/ssl/certs /etc/ssl/private && \
    openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/ssl/private/privkey.pem \
    -out /etc/ssl/certs/fullchain.pem \
    -subj "/CN=localhost"

COPY wordpress.conf /etc/nginx/http.d/default.conf

WORKDIR /var/www/

EXPOSE 80

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]