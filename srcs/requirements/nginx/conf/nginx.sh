#! /bin/bash

if [ ! -f /run/secrets/nginx.crt ] || [ ! -f /run/secrets/nginx.key ]; then
    echo "SSL certificate or key not found. Please provide them in the secrets directory."
    exit 1
fi
cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen ${NGINX_PORT} ssl;
    listen [::]:${NGINX_PORT} ssl;
    server_name ${DOMAIN_NAME};

    ssl_certificate     /run/secrets/nginx.crt;
    ssl_certificate_key /run/secrets/nginx.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    root /var/www/html;
    index index.php index.html index.htm;

    client_max_body_size 100M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # Portfolio configuration
    location /portfolio/ {
        proxy_pass http://portfolio:5000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # WordPress configuration
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
    }

    # Adminer configuration
    location = /adminer {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/adminer/index.php;
        fastcgi_param SCRIPT_NAME /adminer/index.php;
        fastcgi_pass adminer:9000;
    }

    # Netdata configuration
    location = /netdata {
        return 301 /netdata/;
    }

    location /netdata/ {
        proxy_pass http://netdata:19999/;

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
}
EOF

exec nginx -g 'daemon off;'