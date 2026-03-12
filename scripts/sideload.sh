#!/bin/sh
# Zip the channel and sideload it to a Roku device.
# Run from the project root:  ./scripts/sideload.sh
#
# Requires a .env file in the project root with:
#   ROKU_IP=<device ip>
#   ROKU_PASSWORD=<developer password>

set -e
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Missing .env file. Create one with ROKU_IP and ROKU_PASSWORD."
  exit 1
fi

# shellcheck source=/dev/null
. ./.env

if [ -z "$ROKU_IP" ] || [ -z "$ROKU_PASSWORD" ]; then
  echo "ROKU_IP and ROKU_PASSWORD must be set in .env"
  exit 1
fi

echo "Zipping channel..."
zip -qr roughstock-tv.zip manifest source components images sounds

echo "Sideloading to $ROKU_IP..."
http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
     --user "rokudev:$ROKU_PASSWORD" \
     --digest \
     -F "mysubmit=Install" \
     -F "archive=@roughstock-tv.zip" \
     "http://$ROKU_IP/plugin_install")

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
  echo "Installed successfully."
else
  echo "Install failed (HTTP $http_code)."
  exit 1
fi
