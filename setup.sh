#!/usr/bin/env bash
CONFIG_FILE="huly_v7.conf"

# Parse command line arguments
RESET_VOLUMES=false
SECRET=false
QUICK=false

for arg in "$@"; do
    case $arg in
        --secret)
            SECRET=true
            ;;
        --reset-volumes)
            RESET_VOLUMES=true
            ;;
        --quick)
            QUICK=true
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --secret         Generate a new secret key"
            echo "  --reset-volumes  Reset all volume paths to default Docker named volumes"
            echo "  --quick          Quick setup with defaults (localhost:8087, no SSL, auto-start)"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ "$RESET_VOLUMES" == true ]; then
    echo -e "\033[33m--reset-volumes flag detected: Resetting all volume paths to default Docker named volumes.\033[0m"
    sed -i \
        -e '/^VOLUME_ELASTIC_PATH=/s|=.*|=|' \
        -e '/^VOLUME_FILES_PATH=/s|=.*|=|' \
        -e '/^VOLUME_CR_DATA_PATH=/s|=.*|=|' \
        -e '/^VOLUME_CR_CERTS_PATH=/s|=.*|=|' \
        -e '/^VOLUME_REDPANDA_PATH=/s|=.*|=|' \
        "$CONFIG_FILE"
    exit 0
fi

# Quick mode: use all defaults, skip prompts
if [ "$QUICK" == true ]; then
    echo -e "\033[1;34m🚀 Quick setup mode - using defaults for fast verification\033[0m"
    _HOST_ADDRESS="your-domain.com"
    _HTTP_PORT="8087"
    _SECURE="true"
    _VOLUME_ELASTIC_PATH=""
    _VOLUME_FILES_PATH=""
    _VOLUME_CR_DATA_PATH=""
    _VOLUME_CR_CERTS_PATH=""
    _VOLUME_REDPANDA_PATH=""
else

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

while true; do
    if [[ -n "$HOST_ADDRESS" ]]; then
        prompt_type="current"
        prompt_value="${HOST_ADDRESS}"
    else
        prompt_type="default"
        prompt_value="your-domain.com"
    fi
    read -p "Enter the host address (domain name or IP) [${prompt_type}: ${prompt_value}]: " input
    _HOST_ADDRESS="${input:-${HOST_ADDRESS:-your-domain.com}}"
    break
done

while true; do
    if [[ -n "$HTTP_PORT" ]]; then
        prompt_type="current"
        prompt_value="${HTTP_PORT}"
    else
        prompt_type="default"
        prompt_value="8087"
    fi
    read -p "Enter the port for HTTP [${prompt_type}: ${prompt_value}]: " input
    _HTTP_PORT="${input:-${HTTP_PORT:-8087}}"
    if [[ "$_HTTP_PORT" =~ ^[0-9]+$ && "$_HTTP_PORT" -ge 1 && "$_HTTP_PORT" -le 65535 ]]; then
        break
    else
        echo "Invalid port. Please enter a number between 1 and 65535."
    fi
done

echo "$_HOST_ADDRESS $HOST_ADDRESS $_HTTP_PORT $HTTP_PORT"

if [[ "$_HOST_ADDRESS" == "localhost" || "$_HOST_ADDRESS" == "127.0.0.1" || "$_HOST_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:?$ ]]; then
    _HOST_ADDRESS="${_HOST_ADDRESS%:}:${_HTTP_PORT}"
    SECURE=""
else
    while true; do
        if [[ -n "$SECURE" ]]; then
            prompt_type="current"
            prompt_value="Yes"
        else
            prompt_type="default"
            prompt_value="No"
        fi
        read -p "Will you serve Huly over SSL? (y/n) [${prompt_type}: ${prompt_value}]: " input
        case "${input}" in
            [Yy]* )
                _SECURE="true"; break;;
            [Nn]* )
                _SECURE=""; break;;
            "" )
                _SECURE="${SECURE:+true}"; break;;
            * )
                echo "Invalid input. Please enter Y or N.";;
        esac
    done
fi

# Volume path configuration
echo -e "\n\033[1;34mDocker Volume Configuration:\033[0m"

    echo "You can specify custom paths for persistent data storage, or leave empty to use default Docker named volumes."
    echo -e "\033[33mTip: To revert from custom paths to default volumes, enter 'default' or just press Enter when prompted.\033[0m"

    # Elasticsearch volume configuration
    if [[ -n "$VOLUME_ELASTIC_PATH" ]]; then
        current_elastic="custom: $VOLUME_ELASTIC_PATH"
    else
        current_elastic="default Docker volume"
    fi
    read -p "Enter custom path for Elasticsearch volume [current: ${current_elastic}]: " input
    if [[ "$input" == "default" ]]; then
        _VOLUME_ELASTIC_PATH=""
    else
        _VOLUME_ELASTIC_PATH="${input:-${VOLUME_ELASTIC_PATH}}"
    fi

    # Files volume configuration
    if [[ -n "$VOLUME_FILES_PATH" ]]; then
        current_files="custom: $VOLUME_FILES_PATH"
    else
        current_files="default Docker volume"
    fi
    read -p "Enter custom path for files volume [current: ${current_files}]: " input
    if [[ "$input" == "default" ]]; then
        _VOLUME_FILES_PATH=""
    else
        _VOLUME_FILES_PATH="${input:-${VOLUME_FILES_PATH}}"
    fi

    # Cockroach data volume configuration
    if [[ -n "$VOLUME_CR_DATA_PATH" ]]; then
        current_cr_data="custom: $VOLUME_CR_DATA_PATH"
    else
        current_cr_data="default Docker volume"
    fi
    read -p "Enter custom path for CR data volume [current: ${current_cr_data}]: " input
    if [[ "$input" == "default" ]]; then
        _VOLUME_CR_DATA_PATH=""
    else
        _VOLUME_CR_DATA_PATH="${input:-${VOLUME_CR_DATA_PATH}}"
    fi

    # Cockroach certs volume configuration
    if [[ -n "$VOLUME_CR_CERTS_PATH" ]]; then
        current_cr_certs="custom: $VOLUME_CR_CERTS_PATH"
    else
        current_cr_certs="default Docker volume"
    fi
    read -p "Enter custom path for CR certs volume [current: ${current_cr_certs}]: " input
    if [[ "$input" == "default" ]]; then
        _VOLUME_CR_CERTS_PATH=""
    else
        _VOLUME_CR_CERTS_PATH="${input:-${VOLUME_CR_CERTS_PATH}}"
    fi

    # Redpanda volume configuration
    if [[ -n "$VOLUME_REDPANDA_PATH" ]]; then
        current_redpanda="custom: $VOLUME_REDPANDA_PATH"
    else
        current_redpanda="default Docker volume"
    fi
    read -p "Enter custom path for Redpanda volume [current: ${current_redpanda}]: " input
    if [[ "$input" == "default" ]]; then
        _VOLUME_REDPANDA_PATH=""
    else
        _VOLUME_REDPANDA_PATH="${input:-${VOLUME_REDPANDA_PATH}}"
    fi

fi # End of non-quick mode

if [ ! -f .huly.secret ] || [ "$SECRET" == true ]; then
  openssl rand -hex 32 > .huly.secret
  echo "Secret generated and stored in .huly.secret"
else
  echo -e "\033[33m.huly.secret already exists, not overwriting."
  echo "Run this script with --secret to generate a new secret."
fi

if [ ! -f .cr.secret ]; then
  openssl rand -hex 32 > .cr.secret
  echo "Secret generated and stored in .cr.secret"
fi

if [ ! -f .rp.secret ]; then
  openssl rand -hex 32 > .rp.secret
  echo "Secret generated and stored in .rp.secret"
fi

export HOST_ADDRESS=$_HOST_ADDRESS
export SECURE=$_SECURE
export HTTP_PORT=$_HTTP_PORT
export HTTP_BIND=${HTTP_BIND:-127.0.0.1}
export SSL_CERTIFICATE=${SSL_CERTIFICATE:-/apps/certs/your-domain.com/fullchain.pem}
export SSL_CERTIFICATE_KEY=${SSL_CERTIFICATE_KEY:-/apps/certs/your-domain.com/privkey.pem}
export DOCKER_NAME=${DOCKER_NAME:-Huly}
export TITLE=${TITLE:-Huly}
export DEFAULT_LANGUAGE=${DEFAULT_LANGUAGE:-vi}
export LAST_NAME_FIRST=${LAST_NAME_FIRST:-true}
export HULY_GIT_REPOSITORY=${HULY_GIT_REPOSITORY:-https://github.com/mizhtech/huly-platform.git}
export HULY_GIT_BRANCH=${HULY_GIT_BRANCH:-dev-v0.7.426}
export HULY_SOURCE_DIR=${HULY_SOURCE_DIR:-./source/huly-platform}
export PLATFORM_ADMIN_EMAILS=${PLATFORM_ADMIN_EMAILS:-admin}
export EXTERNAL_MINIO_ENDPOINT=${EXTERNAL_MINIO_ENDPOINT:-}
export EXTERNAL_MINIO_URL=${EXTERNAL_MINIO_URL:-}
export EXTERNAL_MINIO_ACCESS_KEY=${EXTERNAL_MINIO_ACCESS_KEY:-}
export EXTERNAL_MINIO_SECRET_KEY=${EXTERNAL_MINIO_SECRET_KEY:-}
export EXTERNAL_MINIO_REGION=${EXTERNAL_MINIO_REGION:-local}
export BACKUP_BUCKET_NAME=${BACKUP_BUCKET_NAME:-huly-backups}
export CR_DATABASE=${CR_DATABASE:-defaultdb}
export CR_USERNAME=${CR_USERNAME:-selfhost}
export REDPANDA_ADMIN_USER=${REDPANDA_ADMIN_USER:-superadmin}
export VOLUME_ELASTIC_PATH=$_VOLUME_ELASTIC_PATH
export VOLUME_FILES_PATH=$_VOLUME_FILES_PATH
export VOLUME_CR_DATA_PATH=$_VOLUME_CR_DATA_PATH
export VOLUME_CR_CERTS_PATH=$_VOLUME_CR_CERTS_PATH
export VOLUME_REDPANDA_PATH=$_VOLUME_REDPANDA_PATH
export HULY_SECRET=$(cat .huly.secret)
export COCKROACH_SECRET=$(cat .cr.secret)
export REDPANDA_SECRET=$(cat .rp.secret)

envsubst < .template.huly.conf > $CONFIG_FILE

source "$CONFIG_FILE"
export CR_DB_URL=$CR_DB_URL

echo -e "\n\033[1;34mConfiguration Summary:\033[0m"
echo -e "Host Address: \033[1;32m$_HOST_ADDRESS\033[0m"
echo -e "HTTP Port: \033[1;32m$_HTTP_PORT\033[0m"
echo -e "SSL Certificate: \033[1;32m$SSL_CERTIFICATE\033[0m"
echo -e "SSL Certificate Key: \033[1;32m$SSL_CERTIFICATE_KEY\033[0m"
if [[ -n "$SECURE" ]]; then
    echo -e "SSL Enabled: \033[1;32mYes\033[0m"
else
    echo -e "SSL Enabled: \033[1;31mNo\033[0m"
fi
echo -e "Elasticsearch Volume: \033[1;32m${_VOLUME_ELASTIC_PATH:-Docker named volume}\033[0m"
echo -e "Files Volume: \033[1;32m${_VOLUME_FILES_PATH:-Docker named volume}\033[0m"
echo -e "CockroachDB Volume: \033[1;32m${_VOLUME_CR_DATA_PATH:-Docker named volume}\033[0m"
echo -e "CockroachDB Certs Volume: \033[1;32m${_VOLUME_CR_CERTS_PATH:-Docker named volume}\033[0m"
echo -e "Redpanda Volume: \033[1;32m${_VOLUME_REDPANDA_PATH:-Docker named volume}\033[0m"

if [ "$QUICK" == true ]; then
    echo -e "\033[1;32mRunning './deploy.sh' now...\033[0m"
    ./deploy.sh
else
    read -p "Do you want to build the fork and start Huly now? (Y/n): " RUN_DOCKER
    case "${RUN_DOCKER:-Y}" in
        [Yy]* )
             echo -e "\033[1;32mRunning './deploy.sh' now...\033[0m"
             ./deploy.sh
             ;;
        [Nn]* )
            echo "You can run ./deploy.sh later."
            ;;
    esac
fi

echo -e "\033[1;32mSetup is complete!\n Generating nginx.conf...\033[0m"
./nginx.sh

if [ "$QUICK" == true ]; then
    echo ""
    echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;32m✅ Quick setup complete!\033[0m"
    echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo -e "🌐 Access Huly at: \033[1;36mhttps://your-domain.com\033[0m"
    echo ""
    echo -e "⏳ Wait ~60 seconds for all services to initialize..."
    echo -e "📊 Check status with: \033[1;33mdocker compose ps\033[0m"
    echo -e "📋 View logs with:   \033[1;33mdocker compose logs -f\033[0m"
    echo ""
fi
