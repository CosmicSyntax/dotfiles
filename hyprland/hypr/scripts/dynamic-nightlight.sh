#!/usr/bin/env bash
ACTION=$1

if [ "$ACTION" = "off" ]; then
    pkill -f wlsunset
    exit 0
elif [ "$ACTION" = "on" ]; then
    if ! pgrep -f wlsunset > /dev/null; then
        COORDS=$(curl -s --max-time 2 ipinfo.io/loc)
        LAT=$(echo $COORDS | cut -d',' -f1)
        LON=$(echo $COORDS | cut -d',' -f2)

        if [ -z "$LAT" ] || [ -z "$LON" ]; then
            LAT="39.1"
            LON="-77.2"
        fi

        uwsm app -- wlsunset -l "$LAT" -L "$LON" -t 4500 &
    fi
else
    # Fallback for keybind (SUPER + SHIFT + N)
    if pgrep -f wlsunset > /dev/null; then
        pkill -f wlsunset
    else
        COORDS=$(curl -s --max-time 2 ipinfo.io/loc)
        LAT=$(echo $COORDS | cut -d',' -f1)
        LON=$(echo $COORDS | cut -d',' -f2)

        if [ -z "$LAT" ] || [ -z "$LON" ]; then
            LAT="39.1"
            LON="-77.2"
        fi

        uwsm app -- wlsunset -l "$LAT" -L "$LON" -t 4500 &
    fi
fi

sleep 0.5

if grep -iq closed /proc/acpi/button/lid/*/state 2>/dev/null; then
    if hyprctl monitors | grep -q "DP-1"; then
        hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
    fi
fi
