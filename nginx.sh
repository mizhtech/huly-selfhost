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
: "${SSL_CERTIFICATE:?SSL_CERTIFICATE is required}"
: "${SSL_CERTIFICATE_KEY:?SSL_CERTIFICATE_KEY is required}"

HTTP_PORT="${HTTP_PORT:-8087}"
export HTTP_PORT

# Print a host Nginx vhost. Install and reload it explicitly on the host;
# deployment must not depend on a separate gateway container or network.
envsubst '${HOST_ADDRESS} ${SSL_CERTIFICATE} ${SSL_CERTIFICATE_KEY} ${HTTP_PORT}' < .template.nginx.conf
