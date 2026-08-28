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

: "${HULY_GIT_REPOSITORY:?HULY_GIT_REPOSITORY is required}"
: "${HULY_GIT_BRANCH:?HULY_GIT_BRANCH is required}"
: "${HULY_SOURCE_DIR:?HULY_SOURCE_DIR is required}"
: "${HOST_ADDRESS:?HOST_ADDRESS is required}"
: "${DOCKER_NAME:?DOCKER_NAME is required}"
: "${CR_DATABASE:?CR_DATABASE is required}"
: "${CR_USERNAME:?CR_USERNAME is required}"
: "${CR_USER_PASSWORD:?CR_USER_PASSWORD is required}"
: "${CR_DB_URL:?CR_DB_URL is required}"
: "${SECRET:?SECRET is required}"
: "${SMTP_FROM:?SMTP_FROM is required}"
: "${SMTP_HOST:?SMTP_HOST is required}"
: "${SMTP_PORT:?SMTP_PORT is required}"
: "${SMTP_USERNAME:?SMTP_USERNAME is required}"
: "${SMTP_PASSWORD:?SMTP_PASSWORD is required}"
: "${EXTERNAL_MINIO_NETWORK:?EXTERNAL_MINIO_NETWORK is required}"
: "${EXTERNAL_MINIO_ENDPOINT:?EXTERNAL_MINIO_ENDPOINT is required}"
: "${EXTERNAL_MINIO_URL:?EXTERNAL_MINIO_URL is required}"
: "${EXTERNAL_MINIO_ACCESS_KEY:?EXTERNAL_MINIO_ACCESS_KEY is required}"
: "${EXTERNAL_MINIO_SECRET_KEY:?EXTERNAL_MINIO_SECRET_KEY is required}"
: "${GATEWAY_NETWORK:?GATEWAY_NETWORK is required}"
: "${GATEWAY_CONTAINER:?GATEWAY_CONTAINER is required}"
: "${GATEWAY_CONFIG_DIR:?GATEWAY_CONFIG_DIR is required}"

CR_DATA_PATH="${CR_DATA_PATH:-/workspace/apps/huly/data/cockroach}"
CR_CERTS_PATH="${CR_CERTS_PATH:-/workspace/apps/huly/data/cockroach-certs}"
REDPANDA_DATA_PATH="${REDPANDA_DATA_PATH:-/workspace/apps/huly/data/redpanda}"
TELEMETRY_DATA_PATH="${TELEMETRY_DATA_PATH:-/workspace/apps/huly/data/telemetry}"

export CR_DATA_PATH
export CR_CERTS_PATH
export REDPANDA_DATA_PATH
export TELEMETRY_DATA_PATH

if ! docker network inspect "$EXTERNAL_MINIO_NETWORK" >/dev/null 2>&1; then
  echo "External MinIO Docker network not found: $EXTERNAL_MINIO_NETWORK" >&2
  exit 1
fi

if ! docker network inspect "$GATEWAY_NETWORK" >/dev/null 2>&1; then
  echo "Central gateway Docker network not found: $GATEWAY_NETWORK" >&2
  exit 1
fi

for path in \
  "$CR_DATA_PATH" \
  "$CR_CERTS_PATH" \
  "$REDPANDA_DATA_PATH" \
  "$TELEMETRY_DATA_PATH"; do
  if [[ "$path" != /* ]]; then
    echo "Persistent data path must be absolute: $path" >&2
    exit 1
  fi
  mkdir -p "$path"
done

ensure_path_owner() {
  local path="$1"
  local uid="$2"
  local gid="$3"
  local current_owner

  current_owner="$(stat -c '%u:%g' "$path")"
  if [[ "$current_owner" == "$uid:$gid" ]]; then
    return
  fi

  echo "Setting ownership for $path to $uid:$gid..."
  if [[ "$(id -u)" -eq 0 ]]; then
    chown -R "$uid:$gid" "$path"
  elif command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$uid:$gid" "$path"
  else
    echo "Cannot set ownership for $path to $uid:$gid: run deploy as root or install/configure sudo." >&2
    exit 1
  fi
}

# These UIDs/GIDs are defined by the pinned runtime images in compose.yml.
ensure_path_owner "$REDPANDA_DATA_PATH" 101 101
ensure_path_owner "$TELEMETRY_DATA_PATH" 10001 0

case "$(node -p 'process.versions.node.split(`.`)[0]' 2>/dev/null || true)" in
  22) ;;
  *)
    echo "Node.js 22 is required to build Huly Platform." >&2
    exit 1
    ;;
esac

SOURCE_DIR="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$HULY_SOURCE_DIR")"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  mkdir -p "$(dirname "$SOURCE_DIR")"
  git clone --branch "$HULY_GIT_BRANCH" "$HULY_GIT_REPOSITORY" "$SOURCE_DIR"
else
  git -C "$SOURCE_DIR" fetch origin "$HULY_GIT_BRANCH"
  git -C "$SOURCE_DIR" checkout "$HULY_GIT_BRANCH"
  git -C "$SOURCE_DIR" pull --ff-only origin "$HULY_GIT_BRANCH"
fi

git -C "$SOURCE_DIR" submodule update --init --recursive

echo "Building Huly fork from $(git -C "$SOURCE_DIR" rev-parse --short HEAD)"
(
  cd "$SOURCE_DIR"
  node common/scripts/install-run-rush.js update
  node common/scripts/install-run-rush.js docker:min
  # The minified build excludes pod-mail; this deployment enables outbound SMTP.
  node common/scripts/install-run-rush.js docker:build --to @hcengineering/pod-mail
)

# Application images must come from the local fork build. Do not pull hardcoreeng/*
# here; compose.yml uses pull_policy: never for those services.
docker compose --env-file "$CONFIG_FILE" -f compose.yml config >/dev/null
docker compose --env-file "$CONFIG_FILE" -f compose.yml up -d --force-recreate

./nginx.sh

echo "Huly started on http://${HTTP_BIND:-127.0.0.1}:${HTTP_PORT:-8087}"
echo "Public URL: http${SECURE:+s}://${HOST_ADDRESS}"
