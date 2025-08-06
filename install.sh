#!/bin/bash

# Load environment variables from .env
set -a
source .env
set +a

check() {
  if [ ! -f "$1" ]; then
    echo "❌ Missing required file: $1"
    exit 1
  fi
}

if [ -n "$SSL_CERTIFICATE_FILE" ] && [ -n "$SSL_CERTIFICATE_KEY_FILE" ]; then
  echo "Checking required files..."
  check "$SSL_CERTIFICATE_FILE"
  check "$SSL_CERTIFICATE_KEY_FILE"
  echo "Files found"
fi

docker-compose up