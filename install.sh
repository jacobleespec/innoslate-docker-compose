#!/bin/bash

set -e

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

# Check for existing containers
CONTAINERS_EXIST=false
for CONTAINER in "innoslate" "innoslate-postgres" "innoslate-nginx"; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    CONTAINERS_EXIST=true
    break
  fi
done

if [ "$CONTAINERS_EXIST" = true ]; then
  echo "WARNING: Removing the previous installation will permanently remove all Innoslate data."
  echo
  read -p "Existing Innoslate installation detected. Would you like to remove it? (y/n): " REMOVE_EXISTING
  REMOVE_EXISTING=$(echo "$REMOVE_EXISTING" | tr '[:upper:]' '[:lower:]') # convert to lowercase

  if [[ "$REMOVE_EXISTING" == "y" ]]; then
    echo "Removing existing installation..."
    for CONTAINER in "innoslate" "innoslate-postgres" "innoslate-nginx"; do
      if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        docker rm -f -v "$CONTAINER" || echo "Failed to remove $CONTAINER"
      fi
    done
  else
    echo "Installation cancelled by user."
    exit 0
  fi
fi

# Remove previous db if it already exists
if docker volume inspect innoslatedb_volume >/dev/null 2>&1; then
  echo "Attempting to remove previously installed volume..."
  docker volume rm innoslatedb_volume || {
    exit 1
  }
fi

# Check that files exist
check() {
  local path="./nginx-files/certs/$1"
  if [ ! -f "$path" ]; then
    echo "Missing required file: $path"
    return 1
  fi
  return 0
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
    # Certificate file
    while true; do
      read -p "Enter SSL certificate filename: " SSL_CERTIFICATE_FILE
      if [ -n "$SSL_CERTIFICATE_FILE" ]; then
        if check "$SSL_CERTIFICATE_FILE"; then
          break
        else
          echo "Please enter a valid certificate filename."
        fi
      else
        break
      fi
    done
    
    # Certificate key file
    while true; do
      read -p "Enter SSL certificate key filename: " SSL_CERTIFICATE_KEY_FILE
      if [ -n "$SSL_CERTIFICATE_KEY_FILE" ]; then
        if check "$SSL_CERTIFICATE_KEY_FILE"; then
          break
        else
          echo "Please enter a valid certificate key filename."
        fi
      else
        break
      fi
    done
  fi
  
  if [ -n "$SSL_CERTIFICATE_FILE" ] && [ -n "$SSL_CERTIFICATE_KEY_FILE" ]; then
    FILE_SUFFIX=_https
    echo "All required files found"
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
  echo

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