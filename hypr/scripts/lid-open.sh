#!/usr/bin/env bash

# If eDP-1 is missing from the active monitor list (because it was disabled), turn it back on.
if ! hyprctl monitors | grep -q "Monitor eDP-1"; then
    hyprctl eval 'hl.monitor({output="eDP-1", mode="2560x1600@60", position="0x1440", scale="1.25", bitdepth=10, cm="auto", disabled=false})'
fi
