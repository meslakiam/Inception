#! /bin/bash

if [ ! -f /run/secrets/nginx.crt ] || [ ! -f /run/secrets/nginx.key ]; then
    echo "SSL certificate or key not found. Please provide them in the secrets directory."
    exit 1
fi
cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen ${NGINX_PORT} ssl;
    listen [::]:${NGINX_PORT} ssl;
    server_name ${NGINX_HOSTNAME};

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

    location /resume/ {
        proxy_pass http://resume:5000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
    }


    location = /adminer {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/adminer/index.php;
        fastcgi_param SCRIPT_NAME /adminer/index.php;
        fastcgi_pass adminer:9000;
    }
}
EOF

exec nginx -g 'daemon off;'