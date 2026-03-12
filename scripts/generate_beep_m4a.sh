#!/bin/sh
# Generate sounds/beep.m4a (AAC) for the timer. Roku plays AAC more reliably than WAV.
# Run from the project root:  ./scripts/generate_beep_m4a.sh
# Then include the sounds/ folder in your channel zip.

set -e
cd "$(dirname "$0")/.."
mkdir -p sounds

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required. Install it (e.g. brew install ffmpeg), or convert sounds/beep.wav to AAC (m4a) with an online converter and save as sounds/beep.m4a"
  exit 1
fi

# Output is always 3 seconds: trim long files, pad short with silence
if [ -f sounds/beep.wav ]; then
  ffmpeg -y -i sounds/beep.wav -af "apad=whole_dur=3" -t 3 -c:a aac -b:a 128k sounds/beep.m4a
  echo "Created sounds/beep.m4a from sounds/beep.wav (3 seconds)"
else
  ffmpeg -y -f lavfi -i "sine=frequency=880:duration=3.0" -t 3 -c:a aac -b:a 128k sounds/beep.m4a
  echo "Created sounds/beep.m4a (880 Hz tone, 3 seconds)"
fi
# Verify duration (requires ffprobe)
if command -v ffprobe >/dev/null 2>&1; then
  dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 sounds/beep.m4a 2>/dev/null || true)
  if [ -n "$dur" ]; then echo "File duration: ${dur}s"; fi
fi
echo "Include the sounds/ folder in your channel zip so the timer beep plays."
