#!/bin/bash

set -e

# !!!!NOTE!!!!
# This is only meant for INSTALLATION. Do not run this
# after your instance has been installed, it may result
# in losing data.

DOCKER_COMPOSE_COMMAND="docker compose"

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
while ! [[ "$HOST_PORT" =~ ^[0-9]+$ ]] || (( HOST_PORT < 1 || HOST_PORT > 65535 )); do
  echo "Invalid HOST_PORT number."
  read -p "Enter host port: " HOST_PORT
done
DOCKER_COMPOSE_COMMAND="HOST_PORT=$HOST_PORT $DOCKER_COMPOSE_COMMAND"

read -p "Use NGINX? (y/n): " ANSWER
ANSWER=$(echo "$ANSWER" | tr '[:upper:]' '[:lower:]') # convert to lowercase
while [[ "$ANSWER" != "y" && "$ANSWER" != "n" ]]; do
  echo "Invalid option: $ANSWER"
  read -p "Use NGINX? (y/n): " ANSWER
  ANSWER=$(echo "$ANSWER" | tr '[:upper:]' '[:lower:]') # convert to lowercase
done

if [[ "$ANSWER" == "y" ]]; then
  USE_NGINX=true
else
  USE_NGINX=false
fi

FILE_SUFFIX=
if [[ "$USE_NGINX" == "true" ]]; then
  read -p "Use HTTPS? (y/n): " USE_HTTPS
  USE_HTTPS=${USE_HTTPS,,}

  while [[ "$USE_HTTPS" != "y" && "$USE_HTTPS" != "n" ]]; do
    echo "Invalid option: $USE_HTTPS"
    read -p "Use HTTPS? (y/n): " USE_HTTPS
    USE_HTTPS=${USE_HTTPS,,}
  done

  if [[ "$USE_HTTPS" == "y" ]]; then
    read -p "Enter SSL certificate filename: " SSL_CERTIFICATE_FILE
    read -p "Enter SSL certificate key filename: " SSL_CERTIFICATE_KEY_FILE
  fi
  # Verify that the files exist
  if [ -n "$SSL_CERTIFICATE_FILE" ] && [ -n "$SSL_CERTIFICATE_KEY_FILE" ]; then
    echo "Checking required files..."
    check "$SSL_CERTIFICATE_FILE"
    check "$SSL_CERTIFICATE_KEY_FILE"
    FILE_SUFFIX=_https
    echo "Files found"
  fi
fi
DOCKER_COMPOSE_COMMAND="FILE_SUFFIX=${FILE_SUFFIX} $DOCKER_COMPOSE_COMMAND"

read -p "Use Postgres? (y/n): " ANSWER
ANSWER=$(echo "$ANSWER" | tr '[:upper:]' '[:lower:]') # convert to lowercase
while [[ "$ANSWER" != "y" && "$ANSWER" != "n" ]]; do
  echo "Invalid option: $ANSWER"
  read -p "Use Postgres? (y/n): " ANSWER
  ANSWER=$(echo "$ANSWER" | tr '[:upper:]' '[:lower:]') # convert to lowercase
done

if [[ "$ANSWER" == "y" ]]; then
  USE_POSTGRES=true
else
  USE_POSTGRES=false
fi

POSTGRES_PASSWORD=
POSTGRES_DB=
if [ "$USE_POSTGRES" == "true" ]; then
  read -p "Enter Postgres database name: " POSTGRES_DB
  while [[ ! "$POSTGRES_DB" =~ ^[a-z0-9_-]+$ ]]; do
    echo "Error: Database name must contain only lowercase letters, numbers, underscores, or dashes."
    read -p "Enter Postgres database name: " POSTGRES_DB
  done
  read -s -p "Enter Postgres password: " POSTGRES_PASSWORD

  echo "Enabling Postgres"
  DOCKER_COMPOSE_COMMAND="$DOCKER_COMPOSE_COMMAND --profile postgres"
fi
DOCKER_COMPOSE_COMMAND="POSTGRES_DB=$POSTGRES_DB POSTGRES_PASSWORD=$POSTGRES_PASSWORD $DOCKER_COMPOSE_COMMAND"


# Use different profiles depending on which service will be using the host port
if [ "$USE_NGINX" == "true" ]; then
  echo "Enabling nginx"
  DOCKER_COMPOSE_COMMAND+=" --profile nginx --profile innoslate-no-port"
else
  DOCKER_COMPOSE_COMMAND+=" --profile innoslate"
fi

mkdir -p ./config
sed "s/{PROXYPORT}/$HOST_PORT/g" ./innoslate-files/server_proxy${FILE_SUFFIX}.xml > ./config/server.xml

DOCKER_COMPOSE_COMMAND+=" up -d"

echo "Running: $DOCKER_COMPOSE_COMMAND"
eval "$DOCKER_COMPOSE_COMMAND"
echo "Installation complete"