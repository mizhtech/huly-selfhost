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
: "${EXTERNAL_MINIO_NETWORK:?EXTERNAL_MINIO_NETWORK is required}"
: "${EXTERNAL_MINIO_ENDPOINT:?EXTERNAL_MINIO_ENDPOINT is required}"
: "${EXTERNAL_MINIO_URL:?EXTERNAL_MINIO_URL is required}"
: "${EXTERNAL_MINIO_ACCESS_KEY:?EXTERNAL_MINIO_ACCESS_KEY is required}"
: "${EXTERNAL_MINIO_SECRET_KEY:?EXTERNAL_MINIO_SECRET_KEY is required}"

if ! docker network inspect "$EXTERNAL_MINIO_NETWORK" >/dev/null 2>&1; then
  echo "External MinIO Docker network not found: $EXTERNAL_MINIO_NETWORK" >&2
  exit 1
fi

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
)

# Application images must come from the local fork build. Do not pull hardcoreeng/*
# here; compose.yml uses pull_policy: never for those services.
docker compose -f compose.yml config >/dev/null
docker compose -f compose.yml up -d --force-recreate

echo "Huly started on http://${HTTP_BIND:-127.0.0.1}:${HTTP_PORT:-8087}"
echo "Public URL: http${SECURE:+s}://${HOST_ADDRESS}"
