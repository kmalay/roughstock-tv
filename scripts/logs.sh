#!/bin/sh
# Connect to the Roku BrightScript debug console.
# Run from the project root:  ./scripts/logs.sh
#
# Reads ROKU_IP from the .env file in the project root.
# Press Ctrl+C to disconnect.

set -e
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Missing .env file. Create one with ROKU_IP."
  exit 1
fi

# shellcheck source=/dev/null
. ./.env

if [ -z "$ROKU_IP" ]; then
  echo "ROKU_IP must be set in .env"
  exit 1
fi

echo "Connecting to debug console at $ROKU_IP:8085 (Ctrl+C to quit)..."
nc "$ROKU_IP" 8085
