#!/bin/bash
set -e

SECRETS_DIR="srcs/secrets"
DOMAIN="${USER}.42.fr"

echo "=== SSL Setup ==="

mkdir -p "$SECRETS_DIR"

# Don't regenerate if the certificate already exists
if [ -f "$SECRETS_DIR/nginx.crt" ] && [ -f "$SECRETS_DIR/nginx.key" ]; then
    echo "[+] SSL certificate already exists."
    exit 0
fi

# Use installed mkcert if available
if command -v mkcert >/dev/null 2>&1; then
    MKCERT="mkcert"
# Otherwise use local binary if already downloaded
elif [ -f "./mkcert" ]; then
    MKCERT="./mkcert"
# Otherwise download it
else
    echo "[+] Downloading mkcert..."

    curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"

    chmod +x mkcert-v*-linux-amd64
    mv mkcert-v*-linux-amd64 mkcert

    MKCERT="./mkcert"
fi

echo "[+] Installing local CA..."
$MKCERT -install

echo "[+] Generating TLS certificate..."

$MKCERT \
    -cert-file "$SECRETS_DIR/nginx.crt" \
    -key-file "$SECRETS_DIR/nginx.key" \
    "$DOMAIN" \
    localhost \
    127.0.0.1 \
    ::1

# Remove downloaded binary if we downloaded it
if [ "$MKCERT" = "./mkcert" ]; then
    rm -f ./mkcert
fi

echo
echo "[+] SSL certificate generated successfully."
echo "    Certificate: $SECRETS_DIR/nginx.crt"
echo "    Private key: $SECRETS_DIR/nginx.key"