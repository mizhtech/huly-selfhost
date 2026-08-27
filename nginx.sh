#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${CONFIG_FILE:-huly_v7.conf}"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Missing $CONFIG_FILE. Run ./setup.sh first." >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$CONFIG_FILE"
set +a

: "${HOST_ADDRESS:?HOST_ADDRESS is required}"
: "${GATEWAY_NETWORK:?GATEWAY_NETWORK is required}"
: "${GATEWAY_CONTAINER:?GATEWAY_CONTAINER is required}"
: "${GATEWAY_CONFIG_DIR:?GATEWAY_CONFIG_DIR is required}"
: "${SSL_CERTIFICATE:?SSL_CERTIFICATE is required}"
: "${SSL_CERTIFICATE_KEY:?SSL_CERTIFICATE_KEY is required}"

if ! docker network inspect "$GATEWAY_NETWORK" >/dev/null 2>&1; then
    echo "Central gateway Docker network not found: $GATEWAY_NETWORK" >&2
    exit 1
fi

if ! docker inspect "$GATEWAY_CONTAINER" >/dev/null 2>&1; then
    echo "Central gateway container not found: $GATEWAY_CONTAINER" >&2
    exit 1
fi

if [[ ! -d "$GATEWAY_CONFIG_DIR" ]]; then
    echo "Central gateway config directory not found: $GATEWAY_CONFIG_DIR" >&2
    exit 1
fi

if [[ ! -f "$SSL_CERTIFICATE" ]]; then
    echo "SSL certificate not found: $SSL_CERTIFICATE" >&2
    exit 1
fi
if [[ ! -f "$SSL_CERTIFICATE_KEY" ]]; then
    echo "SSL certificate key not found: $SSL_CERTIFICATE_KEY" >&2
    exit 1
fi

CERT_SUFFIX="$(basename "$(dirname "$SSL_CERTIFICATE")")"
OUTPUT_FILE="${GATEWAY_CONFIG_DIR%/}/huly.conf"

export HOST_ADDRESS CERT_SUFFIX
envsubst '${HOST_ADDRESS} ${CERT_SUFFIX}' < .template.nginx.conf > "$OUTPUT_FILE"

echo "Generated central gateway vhost: $OUTPUT_FILE"
echo "Gateway network: $GATEWAY_NETWORK"
echo "Huly upstream: huly-gateway:80"

docker exec "$GATEWAY_CONTAINER" nginx -t
docker exec "$GATEWAY_CONTAINER" nginx -s reload

echo "Central gateway reloaded for https://${HOST_ADDRESS}"
