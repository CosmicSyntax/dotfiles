---

# Comprehensive Fedora Hyprland Environment Setup Guide (UWSM Edition)

This blueprint details a fully configured, minimalist **Hyprland** Wayland environment on **Fedora Linux**, integrated cleanly with **UWSM (Universal Wayland Session Manager)**. This setup guarantees enterprise-grade systemd tracking, automated D-Bus portal synchronization for screen sharing, native HDR support, Zen Browser integration, a kernel-aware True Clamshell Mode, silent PAM keyring unlocking via `greetd`, and a customized Nord-themed interface.

---

## Phase 1: Purging GNOME Desktop Infrastructure

Completely strip out the core GNOME Desktop Environment (DE) shell and competing portals.

### 1. Remove Core GNOME Shell & Mutter

```bash
sudo systemctl disable gdm
sudo dnf remove \
    gnome-shell \
    mutter \
    gnome-session \
    gnome-session-wayland \
    gdm \
    xdg-desktop-portal-gnome

```

### 2. Remove Unused Background Daemons

```bash
sudo dnf remove \
    "gnome-shell-extension*" \
    gnome-backgrounds \
    gnome-initial-setup \
    gnome-user-docs

```

### 3. Clean Dependencies

```bash
sudo dnf autoremove

```

---

## Phase 2: System Package Installation

Install the compositor, session manager (`uwsm`), utilities, portals, media capture tools, keyring libraries, and icon themes.

```bash
sudo dnf install \
    hyprland \
    uwsm \
    greetd \
    agreety \
    waybar \
    hyprpaper \
    hypridle \
    hyprlock \
    alacritty \
    wofi \
    thunar \
    pavucontrol \
    blueman \
    NetworkManager-tui \
    network-manager-applet \
    swaync \
    hyprpolkitagent \
    gnome-keyring \
    gnome-keyring-pam \
    seahorse \
    grim \
    slurp \
    wl-clipboard \
    wf-recorder \
    libnotify \
    pipewire \
    wireplumber \
    xdg-desktop-portal \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    wlsunset \
    papirus-icon-theme

```

---

## Phase 3: Greetd & PAM Auto-Unlock Configuration

Configure `greetd` to launch Hyprland securely inside a UWSM systemd scope on Virtual Terminal 1 and silently unlock `gnome-keyring`.

### 1. Configure Greetd (`/etc/greetd/config.toml`)

```bash
sudo nvim /etc/greetd/config.toml

```

```toml
[terminal]
vt = 1

[default_session]
command = "agreety --cmd 'uwsm start hyprland.desktop'"
user = "greetd"

```

### 2. Configure PAM for Greetd (`/etc/pam.d/greetd`)

Explicitly include `pam_gnome_keyring.so` to bypass service-name restrictions and unlock the login keyring during terminal authentication.

```bash
sudo nvim /etc/pam.d/greetd

```

```pam
#%PAM-1.0
auth       substack     system-auth
auth       optional     pam_gnome_keyring.so auto_start
auth       include      postlogin

account    required     pam_nologin.so
account    include      system-auth

password   include      system-auth

session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    required     pam_selinux.so open
session    optional     pam_keyinit.so force revoke
session    include      system-auth
session    optional     pam_gnome_keyring.so auto_start
session    include      postlogin

```

### 3. Enable System Services

```bash
sudo systemctl enable greetd
sudo systemctl enable --now power-profiles-daemon

```

---

## Phase 4: Display & Media Scripts

Create the custom background scripts required for display adjustments and media capture. These scripts are context-aware to prevent Wayland surface crashes during suspend/resume cycles.

```bash
mkdir -p ~/.config/hypr/scripts

```

### 1. Dynamic Night Light (`~/.config/hypr/scripts/dynamic-nightlight.sh`)

Fetches coordinates via IP, applies a warm gamma filter, and safely manages the laptop screen state if closed.

```bash
#!/usr/bin/env bash

# 1. Toggle Logic
if pidof wlsunset > /dev/null; then
    pkill wlsunset
else
    COORDS=$(curl -s ipinfo.io/loc)
    LAT=$(echo $COORDS | cut -d',' -f1)
    LON=$(echo $COORDS | cut -d',' -f2)

    if [ -z "$LAT" ] || [ -z "$LON" ]; then
        LAT="39.1"
        LON="-77.2"
    fi

    uwsm app -- wlsunset -l "$LAT" -L "$LON" -t 4500 &
fi

sleep 0.5

# 2. Check physical hardware switch; safely re-disable if docked
if grep -iq closed /proc/acpi/button/lid/*/state 2>/dev/null; then
    if [ "$(hyprctl monitors | grep -c "^Monitor")" -gt 1 ]; then
        if pidof hyprlock > /dev/null; then
            hyprctl dispatch dpms off eDP-1
        else
            hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
        fi
    fi
fi

```

### 2. Context-Aware Lid Close (`~/.config/hypr/scripts/lid-close.sh`)

Prevents rendering crashes by soft-disabling the screen (cutting DPMS power) if the lockscreen is active, or hard-disabling if unlocked.

```bash
#!/usr/bin/env bash
if [ "$(hyprctl monitors | grep -c "^Monitor")" -gt 1 ]; then
    if pidof hyprlock > /dev/null; then
        # Soft-disable: Cut power, preserve Wayland surface
        hyprctl dispatch dpms off eDP-1
    else
        # Hard-disable: Destroy output, migrate workspaces
        hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
    fi
fi

```

### 3. Context-Aware Lid Open (`~/.config/hypr/scripts/lid-open.sh`)

Restores the `eDP-1` display pipeline only if missing, and forces the backlight on to prevent black-screen resume hangs.

```bash
#!/usr/bin/env bash
if ! hyprctl monitors | grep -q "Monitor eDP-1"; then
    hyprctl eval 'hl.monitor({output="eDP-1", mode="2560x1600@60", position="0x1440", scale="1.0", bitdepth=10, cm="auto", disabled=false})'
fi
hyprctl dispatch dpms on

```

### 4. Screenshot Capture (`~/.config/hypr/scripts/screenshot.sh`)

```bash
#!/usr/bin/env bash
mkdir -p ~/Pictures/Screenshots

REGION=$(slurp)

if [ -z "$REGION" ]; then
    exit 0
fi

FILE=~/Pictures/Screenshots/Capture_$(date +'%Y%m%d_%H%M%S').png

if grim -g "$REGION" - | tee "$FILE" | wl-copy; then
    notify-send "Screenshot Captured" "Saved to Screenshots and copied to clipboard." -i camera-photo
fi

```

### 5. Screen Recording (`~/.config/hypr/scripts/screenrecord.sh`)

```bash
#!/usr/bin/env bash
mkdir -p ~/Videos/Recordings

if pidof wf-recorder > /dev/null; then
    pkill wf-recorder
    notify-send "Recording Stopped" "Video saved to ~/Videos/Recordings" -i media-record
else
    notify-send "Screen Recording" "Select an area to begin recording... (Press ESC to cancel)" -i media-record
    REGION=$(slurp)
    
    if [ -z "$REGION" ]; then
        exit 0
    fi

    FILE=~/Videos/Recordings/Record_$(date +'%Y%m%d_%H%M%S').mp4
    wf-recorder -g "$REGION" -f "$FILE" &
    
    notify-send "Screen Recording" "Recording started! Press SUPER+SHIFT+R to stop." -i media-record
fi

```

### 6. Wofi Application Toggle (`~/.config/hypr/scripts/wofi-toggle.sh`)

```bash
#!/usr/bin/env bash
if pidof wofi > /dev/null; then
    killall wofi
else
    wofi --show drun
fi

```

*(Ensure all scripts are executable: `chmod +x ~/.config/hypr/scripts/*.sh`)*

---

## Phase 5: Hyprland Lua Configuration (`~/.config/hypr/hyprland.lua`)

```lua
--------------------------------------------------------------------------------
-- HYPRLAND CONFIGURATION (LUA)
--------------------------------------------------------------------------------

-- 1. Define Laptop Panel Settings (Single Source of Truth)
local eDP1_config = {
    output   = "eDP-1",
    mode     = "2560x1600@60",
    position = "0x1440",
    scale    = "1.0",
    bitdepth = 10,
    cm       = "auto",
}

-- 2. Read hardware states from the Linux kernel
local handle_lid = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
local lid_state = handle_lid:read("*a") or ""
handle_lid:close()

local handle_dp = io.popen("cat /sys/class/drm/card*-DP-*/status 2>/dev/null | grep -w 'connected'")
local dp_state = handle_dp:read("*a") or ""
handle_dp:close()

local is_closed = string.find(string.lower(lid_state), "closed")

-- 3. Dynamically configure eDP-1 based on Lid State
if is_closed then
    hl.monitor({
        output   = eDP1_config.output,
        disabled = true,
    })
else
    hl.monitor(eDP1_config)
end

-- External Samsung OLED (Always On)
hl.monitor({
    output   = "DP-1",
    mode     = "highres@highrr",
    position = "0x0",
    scale    = "1.0",
    bitdepth = 10,
    cm       = "hdr",
})

-- Default Applications & Variables
local terminal    = "uwsm app -- alacritty"
local menu        = "~/.config/hypr/scripts/wofi-toggle.sh"
local fileManager = "uwsm app -- env GTK_THEME=Adwaita:dark thunar"
local browser     = "uwsm app -- flatpak run app.zen_browser.zen"
local mainMod     = "SUPER"

-- Environment Variables (Critical for Portals & Theming)
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Autostart Daemons & Services
hl.on("hyprland.start", function()
    -- 1. Sync authentication and display environments to D-Bus and systemd
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SSH_AUTH_SOCK")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SSH_AUTH_SOCK")

    -- 2. Start core daemons via user systemd units
    hl.exec_cmd("systemctl --user start swaync.service")
    hl.exec_cmd("systemctl --user start waybar.service")
    hl.exec_cmd("systemctl --user start hypridle.service")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

    -- 3. Wrap standalone background apps in UWSM scopes
    hl.exec_cmd("uwsm app -- hyprpaper")
    hl.exec_cmd("uwsm app -- nm-applet --indicator")
    hl.exec_cmd("uwsm app -- blueman-applet")
    hl.exec_cmd("~/.config/hypr/scripts/dynamic-nightlight.sh")

    -- 4. Set GTK Theme Properties
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'")
end)

-- Core System & Appearance Settings
hl.config({
    ecosystem = {
        no_donation_nag = true,
        no_update_news  = false,
    },

    general = {
        gaps_in          = 4,
        gaps_out         = 10,
        border_size      = 0,
        layout           = "dwindle",
        resize_on_border = true,
        allow_tearing    = false,
    },

    decoration = {
        rounding         = 5,
        active_opacity   = 1.0,
        inactive_opacity = 0.90,
        shadow           = {
            enabled      = true,
            range        = 12,
            render_power = 2,
            color        = 0xee1a1e24,
        },
        blur             = {
            enabled  = true,
            size     = 4,
            passes   = 2,
            vibrancy = 0.1696,
        },
    },

    animations = { enabled = true },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper         = 0,
        disable_hyprland_logo           = true,
        disable_hyprland_guiutils_check = false,
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad     = {
            natural_scroll = true,
        },
    },
})

--------------------------------------------------------------------------------
-- KEYBINDINGS
--------------------------------------------------------------------------------

local app_binds = {
    { mainMod .. " + T",         hl.dsp.exec_cmd(terminal) },
    { mainMod .. " + R",         hl.dsp.exec_cmd(menu) },
    { mainMod .. " + E",         hl.dsp.exec_cmd(fileManager) },
    { mainMod .. " + B",         hl.dsp.exec_cmd(browser) },
    { mainMod .. " + Q",         hl.dsp.window.close() },
    { mainMod .. " + P",         hl.dsp.window.pseudo() },
    { mainMod .. " + V",         hl.dsp.layout("togglesplit") },
    { mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = 1 }) },
    { mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 0 }) },
    { mainMod .. " + SHIFT + P", hl.dsp.window.float({ action = "toggle" }) },
    { mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/dynamic-nightlight.sh") },
    { mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh") },
    { mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh") },
}

for _, b in ipairs(app_binds) do
    hl.bind(b[1], b[2])
end

-- Focus Navigation (SUPER + H/J/K/L)
local focus_binds = {
    { mainMod .. " + H", hl.dsp.focus({ direction = "left" }) },
    { mainMod .. " + L", hl.dsp.focus({ direction = "right" }) },
    { mainMod .. " + K", hl.dsp.focus({ direction = "up" }) },
    { mainMod .. " + J", hl.dsp.focus({ direction = "down" }) },
}

for _, b in ipairs(focus_binds) do
    hl.bind(b[1], b[2])
end

-- Tile Movement (SUPER + SHIFT + H/J/K/L)
local move_binds = {
    { mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }) },
    { mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }) },
    { mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }) },
    { mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }) },
}

for _, b in ipairs(move_binds) do
    hl.bind(b[1], b[2])
end

-- Floating Window Movement (SUPER + ALT + Arrow Keys)
local floatStep = 50
local float_move_binds = {
    { mainMod .. " + ALT + right", hl.dsp.window.move({ x = floatStep, y = 0, relative = true }) },
    { mainMod .. " + ALT + left",  hl.dsp.window.move({ x = -floatStep, y = 0, relative = true }) },
    { mainMod .. " + ALT + up",    hl.dsp.window.move({ x = 0, y = -floatStep, relative = true }) },
    { mainMod .. " + ALT + down",  hl.dsp.window.move({ x = 0, y = floatStep, relative = true }) },
}

for _, b in ipairs(float_move_binds) do
    hl.bind(b[1], b[2], { repeating = true })
end

-- Window Resizing (SUPER + SHIFT + Arrow Keys)
local resizeUnit = 100
local resize_binds = {
    { mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = resizeUnit, y = 0, relative = true }) },
    { mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -resizeUnit, y = 0, relative = true }) },
    { mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -resizeUnit, relative = true }) },
    { mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0, y = resizeUnit, relative = true }) },
}

for _, b in ipairs(resize_binds) do
    hl.bind(b[1], b[2])
end

-- Workspaces 1-10 Navigation & Movement
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Magic Scratchpad
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Safe Hardware Clamshell Listeners
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/scripts/lid-close.sh"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/scripts/lid-open.sh"), { locked = true })

-- Media, Audio & Hardware Brightness Keys
local media_keys = {
    { "XF86AudioRaiseVolume",  "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" },
    { "XF86AudioLowerVolume",  "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
    { "XF86AudioMute",         "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    { "XF86AudioMicMute",      "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
    { "XF86MonBrightnessUp",   "brightnessctl set 5%+" },
    { "XF86MonBrightnessDown", "brightnessctl set 5%-" },
    { "XF86AudioNext",         "playerctl next" },
    { "XF86AudioPrev",         "playerctl previous" },
    { "XF86AudioPlay",         "playerctl play-pause" },
    { "XF86AudioPause",        "playerctl play-pause" },
}

for _, k in ipairs(media_keys) do
    hl.bind(k[1], hl.dsp.exec_cmd(k[2]), { locked = true, repeating = true })
end

--------------------------------------------------------------------------------
-- WINDOW RULES
--------------------------------------------------------------------------------

hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name     = "fix-xwayland-drags",
    match    = { class = "^$", title = "^$", xwayland = true, float = true },
    no_focus = true,
})

hl.window_rule({
    name        = "smart-borders-solo",
    match       = { workspace = "w[t1]", float = false },
    border_size = 0,
})

hl.window_rule({
    name   = "float-utilities",
    match  = { class = "^(pavucontrol|blueman-manager|nm-connection-editor)$" },
    float  = true,
    center = true,
})

```

---

## Phase 6: Session & Idle Management

Coordinate sleep events with `systemd` to guarantee the screen locks before the kernel cuts power, and wakes up cleanly upon resume without tearing down display pipelines.

### 1. Idle Daemon Config (`~/.config/hypr/hypridle.conf`)

```ini
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

```

### 2. Lockscreen Config (`~/.config/hypr/hyprlock.conf`)

Ensure `immediate_render` is NOT used, as it races with the DRM driver wake sequence and causes permanent black screens.

```ini
general {
    disable_loading_bar = true
    hide_cursor = true
    grace = 0
    no_fade_in = false
}

# (Followed by your standard background, input-field, and label definitions...)

```

---

## Phase 7: Waybar Multi-Output Configuration

Waybar uses a multi-output configuration that excludes the backlight widget on external displays while retaining it on `eDP-1`.

### 1. Shared Modules Definition (`~/.config/waybar/modules.jsonc`)

```jsonc
{
    "layer": "top",
    "position": "top",
    "height": 34,
    "spacing": 4,
    "exclusive": true,
    "gtk-layer-shell": true,

    "hyprland/workspaces": {
        "format": "{name}",
        "on-click": "activate",
        "persistent-workspaces": {
            "*": [1, 2, 3, 4, 5]
        }
    },

    "hyprland/window": {
        "format": "{}",
        "format-empty": "",
        "max-length": 50,
        "separate-outputs": true
    },

    "power-profiles-daemon": {
        "format": "{icon}",
        "tooltip-format": "Power profile: {profile}\nDriver: {driver}",
        "tooltip": true,
        "format-icons": {
            "default": "",
            "performance": "",
            "balanced": "",
            "power-saver": ""
        }
    },

    "clock": {
        "format": "{:%m/%d %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },

    "backlight": {
        "format": "{icon} {percent}%",
        "format-icons": ["", "", "", "", "", "", "", "", ""]
    },

    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": "󰂄 {capacity}%",
        "format-plugged": "󰚥 {capacity}%",
        "format-alt": "{time} {icon}",
        "format-icons": ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    },

    "network": {
        "format-wifi": "󰖩 {essid}",
        "format-ethernet": "󰈀 Wired",
        "format-disconnected": "󰖪 Disconnected",
        "on-click": "nm-connection-editor"
    },

    "bluetooth": {
        "format": " {status}",
        "format-disabled": "󰂲 Off",
        "format-off": "󰂲 Off",
        "format-on": "󰂯 On",
        "format-connected": "󰂱 {device_alias}",
        "tooltip-format": "{controller_alias}\t{controller_address}",
        "tooltip-format-connected": "{controller_alias}\t{controller_address}\n\n{device_enumerate}",
        "tooltip-format-enumerate-connected": "{device_alias}\t{device_address}",
        "on-click": "blueman-manager"
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-bluetooth": "{icon} {volume}% 󰂯",
        "format-muted": "󰝟",
        "format-icons": {
            "headphone": "󰋋",
            "hands-free": "󰋋",
            "headset": "󰋋",
            "phone": "󰏲",
            "portable": "󰏲",
            "car": "󰄋",
            "default": ["󰕿", "󰖀", "󰕾"]
        },
        "on-click": "pavucontrol"
    },

    "custom/notification": {
        "format": "{} {icon}",
        "format-icons": {
            "notification": "<span foreground='red'><sup></sup></span>",
            "none": "",
            "dnd-notification": "<span foreground='red'><sup></sup></span>",
            "dnd-none": "",
            "inhibited-notification": "<span foreground='red'><sup></sup></span>",
            "inhibited-none": "",
            "dnd-inhibited-notification": "<span foreground='red'><sup></sup></span>",
            "dnd-inhibited-none": ""
        },
        "return-type": "json",
        "exec-if": "which swaync-client",
        "exec": "swaync-client -swb",
        "on-click": "swaync-client -t -sw",
        "on-click-right": "swaync-client -d -sw",
        "escape": true
    },

    "custom/power": {
        "format": "⏻",
        "on-click": "~/.config/waybar/scripts/power-menu.sh",
        "tooltip": false
    }
}

```

### 2. Multi-Bar Root Config (`~/.config/waybar/config.jsonc`)

```jsonc
[
    {
        "output": ["eDP-1"],
        "include": ["~/.config/waybar/modules.jsonc"],
        "modules-left": ["hyprland/workspaces"],
        "modules-center": ["hyprland/window"],
        "modules-right": [
            "power-profiles-daemon",
            "pulseaudio",
            "network",
            "bluetooth",
            "backlight",
            "battery",
            "clock",
            "custom/notification",
            "custom/power"
        ]
    },
    {
        "output": ["DP-1", "DP-2", "DP-3", "HDMI-A-1"],
        "include": ["~/.config/waybar/modules.jsonc"],
        "modules-left": ["hyprland/workspaces"],
        "modules-center": ["hyprland/window"],
        "modules-right": [
            "power-profiles-daemon",
            "pulseaudio",
            "network",
            "bluetooth",
            "battery",
            "clock",
            "custom/notification",
            "custom/power"
        ]
    }
]

```

### 3. Waybar Stylesheet (`~/.config/waybar/style.css`)

```css
* {
    font-family: "GoogleSansMNerdFont-Regular", sans-serif;
    font-size: 15px;
    min-height: 0;
}

window#waybar {
    background: rgba(46, 52, 64, 0.85);
    color: #eceff4;
    border-bottom: 2px solid rgba(129, 161, 193, 0.3);
}

window#waybar.empty #window {
    background-color: transparent;
    border: none;
    padding: 0;
    margin: 0;
}

#workspaces button {
    padding: 0 8px;
    color: #d8dee9;
    background: transparent;
    border-radius: 4px;
    margin: 4px 2px;
}

#workspaces button:hover {
    background: rgba(129, 161, 193, 0.2);
    color: #81a1c1;
}

#workspaces button.active {
    background: #81a1c1;
    color: #2e3440;
}

#power-profiles-daemon,
#clock,
#battery,
#backlight,
#network,
#bluetooth,
#pulseaudio,
#custom-notification,
#custom-power,
#window {
    background: #3b4252;
    padding: 2px 10px;
    margin: 4px 3px;
    border-radius: 6px;
    color: #eceff4;
}

#battery.charging { color: #a3be8c; }
#battery.warning:not(.charging) { color: #ebcb8b; }

#battery.critical:not(.charging) {
    color: #bf616a;
    animation-name: blink;
    animation-duration: 0.5s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

@keyframes blink {
    to { background-color: #bf616a; color: #2e3440; }
}

#custom-power { color: #bf616a; margin-right: 6px; }
#custom-power:hover { background: #bf616a; color: #2e3440; }

```

### 4. Power Menu Script (`~/.config/waybar/scripts/power-menu.sh`)

```bash
#!/usr/bin/env bash

options="󰌾  Lock\n󰒲  Sleep\n󰍃  Logout\n󰑐  Reboot\n󰐥  Shutdown"
chosen=$(echo -e "$options" | wofi --dmenu --prompt "Power" --width 200 --lines 5 --cache-file /dev/null)

case "$chosen" in
    *"Lock")
        hyprlock
        ;;
    *"Sleep")
        systemctl suspend
        ;;
    *"Logout")
        uwsm stop
        ;;
    *"Reboot")
        systemctl reboot
        ;;
    *"Shutdown")
        systemctl poweroff
        ;;
esac

```

*(Ensure executable: `chmod +x ~/.config/waybar/scripts/power-menu.sh`)*

---

## Phase 8: SwayNC & Native UI Theming

### 1. Hyprtoolkit Config (`~/.config/hypr/hyprtoolkit.conf`)

```ini
background = 0xFF2E3440        
base = 0xFF3B4252              
alternate_base = 0xFF434C5E    
text = 0xFFD8DEE9              
bright_text = 0xFFECEFF4       
accent = 0xFF81A1C1            
accent_secondary = 0xFF88C0D0  

font_family = GoogleSansMNerdFont-Regular
font_size = 13
h1_size = 19
h2_size = 15
h3_size = 13
icon_theme = Papirus-Dark

rounding_large = 10
rounding_small = 5             

```

### 2. SwayNC Config (`~/.config/swaync/config.json`)

```json
{
  "$schema": "/etc/swaync/configSchema.json",
  "positionX": "right",
  "positionY": "top",
  "layer": "overlay",
  "control-center-width": 400,
  "control-center-height": 600,
  "notification-window-width": 400,
  "keyboard-shortcuts": true,
  "image-visibility": "never",
  "transition-time": 200,
  "hide-on-clear": true,
  "hide-on-action": true,
  "script-fail-notify": true,
  "widgets": [
    "title",
    "dnd",
    "notifications",
    "mpris"
  ],
  "widget-config": {
    "title": { "text": "Notification Center", "clear-all-button": true, "button-text": "Clear All" },
    "dnd": { "text": "Do Not Disturb" },
    "mpris": { "image-size": 96, "blur": 14 }
  }
}

```

### 3. SwayNC Stylesheet (`~/.config/swaync/style.css`)

```css
* { font-family: "GoogleSansMNerdFont-Regular", sans-serif; font-size: 13px; background: transparent; box-shadow: none; }
.control-center { background: rgba(46, 52, 64, 0.95); border: 2px solid #81a1c1; border-radius: 12px; box-shadow: 0 0 10px rgba(0, 0, 0, 0.5); color: #eceff4; padding: 12px; }
.control-center-list, .notification-row, .notification-background { background: transparent; box-shadow: none; border: none; margin: 4px 0; padding: 0px; }
.notification { background: #3b4252; border: 2px solid #81a1c1; border-radius: 10px; padding: 8px; color: #eceff4; }
.notification-content { background: transparent; color: #eceff4; }
.notification-icon { min-width: 0px; min-height: 0px; margin: 0px; display: none; }
.summary { font-weight: bold; color: #eceff4; font-size: 14px; }
.body { color: #d8dee9; font-size: 12px; }
.time { color: #4c566a; font-size: 10px; }
.close-button { background: #434c5e; color: #eceff4; border-radius: 6px; padding: 2px 6px; }
.close-button:hover { background: #bf616a; color: #2e3440; }
.widget-title { color: #eceff4; margin: 8px; font-size: 16px; }
.widget-title>button { background: #3b4252; color: #eceff4; border: 1px solid #434c5e; border-radius: 6px; padding: 4px 10px; }
.widget-title>button:hover { background: #81a1c1; color: #2e3440; }
.widget-dnd { background: #3b4252; border-radius: 8px; padding: 8px; margin: 8px 0; color: #eceff4; }
.widget-dnd switch { background: #434c5e; border-radius: 12px; }
.widget-dnd switch:checked { background: #81a1c1; }
.widget-mpris { background: #3b4252; border-radius: 10px; padding: 10px; margin-top: 8px; color: #eceff4; }
.widget-mpris-player { padding: 8px; }

```

---

## Phase 9: Thunar File Manager D-Bus Integration

```bash
xdg-mime default thunar.desktop inode/directory
mkdir -p ~/.local/share/dbus-1/services

```

Create `~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service`:

```ini
[D-BUS Service]
Name=org.freedesktop.FileManager1
Exec=/usr/bin/thunar --sm-client-disable

```

```bash
update-desktop-database ~/.local/share/applications

```
