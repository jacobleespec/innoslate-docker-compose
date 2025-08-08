#!/bin/bash

# !!!!NOTE!!!!
# This is only meant for INSTALLATION. Do not run this
# after your instance has been installed, it may result
# in losing data.

DOCKER_COMPOSE_COMMAND="docker compose"

# Load environment variables from .env
set -a
source .env
set +a

error_reported=0
trap '
  if [ $error_reported -eq 0 ]; then
    echo "Script failed with exit code $?"
    echo "Press enter to exit..."
    read
    error_reported=1
  fi
' ERR

# Remove previous db if it already exists
if docker volume inspect innoslatedb_volume >/dev/null 2>&1; then
  echo "Attempting to remove previously installed volume..."
  docker volume rm innoslatedb_volume || {
    exit 1
  }
fi

# Check that files exist
check() {
  echo "Checking" $1
  local path="./nginx-files/certs/$1"
  if [ ! -f "$path" ]; then
    echo "Missing required file: $path"
    exit 1
  fi
}

read -p "Enter host port: " HOST_PORT
if ! [[ "$HOST_PORT" =~ ^[0-9]+$ ]] || (( HOST_PORT < 1 || HOST_PORT > 65535 )); then
  echo "Invalid HOST_PORT number."
  exit 1
fi
DOCKER_COMPOSE_COMMAND="HOST_PORT=$HOST_PORT $DOCKER_COMPOSE_COMMAND"

read -p "Use NGINX? (y/n): " ANSWER
ANSWER=${ANSWER,,}  # convert to lowercase
if [[ "$ANSWER" == "y" ]]; then
  USE_NGINX=true
elif [[ "$ANSWER" == "n" ]]; then
  USE_NGINX=false
else
  echo "Invalid option: $ANSWER"
  exit 1
fi

read -p "Use Postgres? (y/n): " ANSWER
ANSWER=${ANSWER,,}  # convert to lowercase
if [[ "$ANSWER" == "y" ]]; then
  USE_POSTGRES=true
elif [[ "$ANSWER" == "n" ]]; then
  USE_POSTGRES=false
else
  echo "Invalid option: $ANSWER"
  exit 1
fi

if [[ "$USE_NGINX" == "true" ]]; then
  read -p "Use HTTPS? (y/n): " USE_HTTPS
  USE_HTTPS=${USE_HTTPS,,}

  if [[ "$USE_HTTPS" == "y" ]]; then
    read -p "Enter SSL certificate filename: " SSL_CERTIFICATE_FILE
    read -p "Enter SSL certificate key filename: " SSL_CERTIFICATE_KEY_FILE
  elif [[ "$USE_HTTPS" != "n" ]]; then
    exit 1
  fi
  # Verify that the files exist
  if [ -n "$SSL_CERTIFICATE_FILE" ] && [ -n "$SSL_CERTIFICATE_KEY_FILE" ]; then
    echo "Checking required files..."
    check "$SSL_CERTIFICATE_FILE"
    check "$SSL_CERTIFICATE_KEY_FILE"
    DOCKER_COMPOSE_COMMAND="FILE_SUFFIX=_https $DOCKER_COMPOSE_COMMAND"
    echo "Files found"
  fi
fi

if [ "$USE_POSTGRES" == "true" ]; then
  read -p "Enter Postgres database name: " POSTGRES_DB
  if [[ ! "$POSTGRES_DB" =~ ^[a-z0-9_-]+$ ]]; then
    echo "Error: Database name must contain only lowercase letters, numbers, underscores, or dashes."
    exit 1
  fi
  read -s -p "Enter Postgres password: " POSTGRES_PASSWORD

  echo "Enabling Postgres"
  DOCKER_COMPOSE_COMMAND="POSTGRES_DB=$POSTGRES_DB POSTGRES_PASSWORD=$POSTGRES_PASSWORD $DOCKER_COMPOSE_COMMAND --profile postgres"
fi


# Use different profiles depending on which service will be using the host port
if [ "$USE_NGINX" == "true" ]; then
  echo "Enabling nginx"
  DOCKER_COMPOSE_COMMAND+=" --profile nginx --profile innoslate-no-port"
else
  DOCKER_COMPOSE_COMMAND+=" --profile innoslate"
fi

DOCKER_COMPOSE_COMMAND+=" up -d"

echo "Running: $DOCKER_COMPOSE_COMMAND"
eval "$DOCKER_COMPOSE_COMMAND"
echo "Installation complete"