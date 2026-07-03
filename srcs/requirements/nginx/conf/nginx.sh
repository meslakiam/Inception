#! /bin/bash

if [ ! -f /run/secrets/nginx.crt ] || [ ! -f /run/secrets/nginx.key ]; then
    echo "SSL certificate or key not found. Please provide them in the secrets directory."
    exit 1
fi
echo 'server {
    listen '$NGINX_PORT' ssl;
    listen [::]:'$NGINX_PORT' ssl;
    server_name '$NGINX_HOSTNAME';

    # SSL Certificate
    ssl_certificate     /run/secrets/nginx.crt;
    ssl_certificate_key /run/secrets/nginx.key;

    # Allow only TLS 1.2 and TLS 1.3
    ssl_protocols TLSv1.2 TLSv1.3;

    # SSL Session
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    root /var/www/html;

    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }


}' > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'