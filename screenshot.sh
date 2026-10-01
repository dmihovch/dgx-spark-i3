#!/usr/bin/env bash
# Screenshot helper  ·  ~/.config/i3/screenshot.sh
# Usage: screenshot.sh          -> full screen
#        screenshot.sh select   -> interactive region
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%F-%H%M%S).png"

if [[ "${1:-}" == "select" ]]; then
    maim -s "$file"
else
    maim "$file"
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -i camera "Screenshot saved" "$file"
fi
