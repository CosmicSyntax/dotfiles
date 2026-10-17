#!/usr/bin/env bash

mkdir -p ~/Videos/Recordings

if pidof wf-recorder > /dev/null; then
    pkill wf-recorder
    notify-send "Recording Stopped" "Video saved to ~/Videos/Recordings" -i media-record
else
    # 1. Ask for region first
    notify-send "Screen Recording" "Select an area to begin... (Press ESC to cancel)" -i media-record
    REGION=$(slurp)
    
    # 2. If canceled, exit silently
    if [ -z "$REGION" ]; then
        exit 0
    fi

    # 3. Otherwise, generate filename and start recording
    FILE=~/Videos/Recordings/Record_$(date +'%Y%m%d_%H%M%S').mp4
    wf-recorder -g "$REGION" -f "$FILE" &
    
    # Notify that the actual recording has begun
    notify-send "Screen Recording" "Recording started! Press SUPER+SHIFT+R to stop." -i media-record
fi
