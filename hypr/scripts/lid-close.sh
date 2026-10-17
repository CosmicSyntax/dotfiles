#!/usr/bin/env bash

# Check if we have more than 1 monitor active
if [ "$(hyprctl monitors | grep -c "^Monitor")" -gt 1 ]; then
    
    # Check if the lock screen is currently actively rendering
    if pidof hyprlock > /dev/null; then
        # Soft-disable: Cut panel power via DPMS to prevent Wayland surface destruction
        hyprctl dispatch dpms off eDP-1
    else
        # Hard-disable: Safe to destroy the output and migrate workspaces to DP-1
        hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
    fi
    
fi
