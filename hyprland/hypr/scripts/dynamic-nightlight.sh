#!/usr/bin/env bash

# 1. Toggle Logic
if pidof wlsunset > /dev/null; then
    pkill wlsunset
else
    # Fetch coordinates
    COORDS=$(curl -s ipinfo.io/loc)
    LAT=$(echo $COORDS | cut -d',' -f1)
    LON=$(echo $COORDS | cut -d',' -f2)

    # Fallback to default coordinates
    if [ -z "$LAT" ] || [ -z "$LON" ]; then
        LAT="39.1"
        LON="-77.2"
    fi

    # Launch wlsunset in the background via UWSM
    uwsm app -- wlsunset -l "$LAT" -L "$LON" -t 4500 &
fi

# 2. Wait for the GPU to process the gamma reset
sleep 0.5

# 3. Check the physical hardware switch; only re-disable if docked
if grep -iq closed /proc/acpi/button/lid/*/state 2>/dev/null; then
    # Ask Hyprland if the Samsung OLED (DP-1) is active
    if hyprctl monitors | grep -q "DP-1"; then
        hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
    fi
fi
