#!/usr/bin/env bash

mkdir -p ~/Pictures/Screenshots

# 1. Wait for the user to select a region (Pressing ESC makes this empty)
REGION=$(slurp)

# 2. If the region is empty (user canceled), just exit silently
if [ -z "$REGION" ]; then
    exit 0
fi

# 3. Otherwise, proceed with the capture
FILE=~/Pictures/Screenshots/Capture_$(date +'%Y%m%d_%H%M%S').png

if grim -g "$REGION" - | tee "$FILE" | wl-copy; then
    notify-send "Screenshot Captured" "Saved to Screenshots and copied to clipboard." -i camera-photo
fi
