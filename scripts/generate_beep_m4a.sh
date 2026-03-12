#!/bin/sh
# Generate sounds/beep.m4a (AAC) for the timer.
# Run from the project root:  ./scripts/generate_beep_m4a.sh
# Then include the sounds/ folder in your channel zip.

set -e
cd "$(dirname "$0")/.."
mkdir -p sounds

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required. Install it (e.g. brew install ffmpeg)."
  exit 1
fi

# 3-second 880 Hz continuous sine tone, AAC encoded.
ffmpeg -y -f lavfi -i "sine=frequency=880:duration=3.0" -t 3 -c:a aac -b:a 128k sounds/beep.m4a
echo "Created sounds/beep.m4a (880 Hz tone, 3 seconds)"

if command -v ffprobe >/dev/null 2>&1; then
  dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 sounds/beep.m4a 2>/dev/null || true)
  if [ -n "$dur" ]; then echo "File duration: ${dur}s"; fi
fi
echo "Include the sounds/ folder in your channel zip."
