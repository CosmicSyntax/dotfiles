---

# Comprehensive Fedora Hyprland Environment Setup Guide (UWSM Edition)

This blueprint details a fully configured, minimalist **Hyprland** Wayland environment on **Fedora Linux**, integrated cleanly with **UWSM (Universal Wayland Session Manager)**. This setup guarantees enterprise-grade systemd tracking, automated D-Bus portal synchronization for flawless screen sharing, Native HDR support, Zen Browser integration, a kernel-aware True Clamshell Mode, and a customized Nord-themed interface.

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

Install the compositor, session manager (`uwsm`), utilities, portals, media capture tools, and icon themes.

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

## Phase 3: Greetd & UWSM Configuration (Terminal Login)

Configure `greetd` to launch Hyprland securely inside a UWSM systemd scope on Virtual Terminal 1.

1. Open the configuration file:
```bash
sudo nvim /etc/greetd/config.toml

```


2. Add the following configuration:
```toml
[terminal]
vt = 1

[default_session]
command = "agreety --cmd 'uwsm start hyprland.desktop'"
user = "greetd"

```


3. Enable the required services:
```bash
sudo systemctl enable greetd
sudo systemctl enable --now power-profiles-daemon

```



---

## Phase 4: Display & Media Scripts

Create the custom background scripts required for the display engine and media capture.

```bash
mkdir -p ~/.config/hypr/scripts

```

### 1. Dynamic Night Light (`~/.config/hypr/scripts/dynamic-nightlight.sh`)

Fetches coordinates via IP, applies a warm gamma filter, and safely manages the laptop screen state.

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

# 2. Check the physical hardware switch; only re-disable if docked
if grep -iq closed /proc/acpi/button/lid/*/state 2>/dev/null; then
    if hyprctl monitors | grep -q "DP-1"; then
        hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
    fi
fi

```

### 2. Smart Lid Closure (`~/.config/hypr/scripts/lid-close.sh`)

Prevents zero-monitor segfaults by only turning off the screen if the OLED dock is connected.

```bash
#!/usr/bin/env bash
if hyprctl monitors | grep -q "DP-1"; then
    hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
else
    exit 0
fi

```

### 3. Screenshot Capture (`~/.config/hypr/scripts/screenshot.sh`)

```bash
#!/usr/bin/env bash
mkdir -p ~/Pictures/Screenshots
FILE=~/Pictures/Screenshots/Capture_$(date +'%Y%m%d_%H%M%S').png

if grim -g "$(slurp)" - | tee "$FILE" | wl-copy; then
    notify-send "Screenshot Captured" "Saved to Screenshots and copied to clipboard." -i camera-photo
fi

```

### 4. Screen Recording (`~/.config/hypr/scripts/screenrecord.sh`)

```bash
#!/usr/bin/env bash
mkdir -p ~/Videos/Recordings

if pidof wf-recorder > /dev/null; then
    pkill wf-recorder
    notify-send "Recording Stopped" "Video saved to ~/Videos/Recordings" -i media-record
else
    FILE=~/Videos/Recordings/Record_$(date +'%Y%m%d_%H%M%S').mp4
    notify-send "Screen Recording" "Select an area to begin recording..." -i media-record
    wf-recorder -g "$(slurp)" -f "$FILE" &
fi

```

*(Ensure all scripts are executable: `chmod +x ~/.config/hypr/scripts/*.sh`)*

---

## Phase 5: UWSM-Optimized Hyprland Configuration (`~/.config/hypr/hyprland.lua`)

This strictly DRY Lua configuration reads kernel states via DRM, manages native HDR, wraps major apps in UWSM scopes, and contains the media capture hooks.

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
local is_docked = (dp_state ~= "")

-- 3. Dynamically configure eDP-1 based on both variables
if is_closed and is_docked then
    -- True Clamshell: Lid is shut AND external monitor is present
    hl.monitor({ output = eDP1_config.output, disabled = true })
else
    -- Mobile or Open: Ensure the laptop screen stays on
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

-- Environment Variables
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Autostart Daemons & Services
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start swaync.service")
    hl.exec_cmd("systemctl --user start waybar.service")
    hl.exec_cmd("systemctl --user start hypridle.service")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

    hl.exec_cmd("uwsm app -- hyprpaper")
    hl.exec_cmd("uwsm app -- nm-applet --indicator")
    hl.exec_cmd("uwsm app -- blueman-applet")
    hl.exec_cmd("uwsm app -- gnome-keyring-daemon --start --components=secrets,ssh,pkcs11")
    
    hl.exec_cmd("~/.config/hypr/scripts/dynamic-nightlight.sh")

    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'")
end)

-- Core System Settings
hl.config({
    ecosystem = { no_donation_nag = true, no_update_news = false },
    general = { gaps_in = 4, gaps_out = 10, border_size = 0, layout = "dwindle", resize_on_border = true, allow_tearing = false },
    decoration = {
        rounding = 5,
        active_opacity = 1.0,
        inactive_opacity = 0.85,
        shadow = { enabled = true, range = 12, render_power = 2, color = 0xee1a1e24 },
        blur = { enabled = true, size = 4, passes = 2, vibrancy = 0.1696 },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = { force_default_wallpaper = 0, disable_hyprland_logo = true, disable_hyprland_guiutils_check = false },
    input = { kb_layout = "us", follow_mouse = 1, sensitivity = 0, touchpad = { natural_scroll = true } },
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
    
    -- Smart Scripts
    { mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/dynamic-nightlight.sh") },
    { mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh") },
    { mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh") },
}

for _, b in ipairs(app_binds) do hl.bind(b[1], b[2]) end

-- Focus / Movement / Resize (Omitted loop boilerplate for brevity in display)
local focus_binds = {
    { mainMod .. " + H", hl.dsp.focus({ direction = "left" }) },
    { mainMod .. " + L", hl.dsp.focus({ direction = "right" }) },
    { mainMod .. " + K", hl.dsp.focus({ direction = "up" }) },
    { mainMod .. " + J", hl.dsp.focus({ direction = "down" }) },
}
for _, b in ipairs(focus_binds) do hl.bind(b[1], b[2]) end

local move_binds = {
    { mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }) },
    { mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }) },
    { mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }) },
    { mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }) },
}
for _, b in ipairs(move_binds) do hl.bind(b[1], b[2]) end

local resizeUnit = 100
local resize_binds = {
    { mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = resizeUnit, y = 0, relative = true }) },
    { mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -resizeUnit, y = 0, relative = true }) },
    { mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -resizeUnit, relative = true }) },
    { mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0, y = resizeUnit, relative = true }) },
}
for _, b in ipairs(resize_binds) do hl.bind(b[1], b[2]) end

-- Workspaces 1-10
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad (Magic Workspace)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Smart Clamshell Mode
local wake_eDP1_cmd = string.format(
    [[hyprctl eval 'hl.monitor({output="%s", mode="%s", position="%s", scale="%s", bitdepth=%d, cm="%s", disabled=false})']],
    eDP1_config.output, eDP1_config.mode, eDP1_config.position, eDP1_config.scale, eDP1_config.bitdepth, eDP1_config.cm
)
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/scripts/lid-close.sh"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(wake_eDP1_cmd), { locked = true })

-- Media Keys
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

-- Window Rules
hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true }, no_focus = true })
hl.window_rule({ name = "smart-borders-solo", match = { workspace = "w[t1]", float = false }, border_size = 0 })
hl.window_rule({ name = "float-utilities", match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor)$" }, float = true, center = true })

```

---

## Phase 6: Native UI Theming (hyprtoolkit)

Theme the `hyprland-guiutils` notifications (crash reports, updates) to match the Nord palette.

```ini
# ~/.config/hypr/hyprtoolkit.conf

# Nord Color Palette
background = 0xFF2E3440        
base = 0xFF3B4252              
alternate_base = 0xFF434C5E    
text = 0xFFD8DEE9              
bright_text = 0xFFECEFF4       
accent = 0xFF81A1C1            
accent_secondary = 0xFF88C0D0  

# Fonts & Corners
font_family = GoogleSansMNerdFont-Regular
font_size = 13
h1_size = 19
h2_size = 15
h3_size = 13
icon_theme = Papirus-Dark

rounding_large = 10
rounding_small = 5             

```

---

## Phase 7: Wofi Toggle Script Wrapper

1. Create the script:
```bash
nvim ~/.config/hypr/scripts/wofi-toggle.sh

```


2. Add logic:
```bash
#!/usr/bin/env bash
if pidof wofi > /dev/null; then
    killall wofi
else
    wofi --show drun
fi

```



*(Ensure executable: `chmod +x ~/.config/hypr/scripts/wofi-toggle.sh`)*

---

## Phase 8: Waybar Setup & UWSM Power Menu

### 1. UWSM Power Menu Script (`~/.config/waybar/scripts/power-menu.sh`)

```bash
#!/usr/bin/env bash

# Power menu options
options="󰌾  Lock\n󰒲  Sleep\n󰍃  Logout\n󰑐  Reboot\n󰐥  Shutdown"
# Pass options to Wofi
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

### 2. Layout Configuration (`~/.config/waybar/config.jsonc`)

```jsonc
{
    "layer": "top",
    "position": "top",
    "height": 34,
    "spacing": 4,
    "exclusive": true,
    "gtk-layer-shell": true,

    "modules-left": [
        "hyprland/workspaces"
    ],
    "modules-center": [
        "hyprland/window"
    ],
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
    ],

    "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "format-icons": {
            "1": "1",
            "2": "2",
            "3": "3",
            "4": "4",
            "5": "5",
            "urgent": "",
            "active": "",
            "default": ""
        },
        "persistent-workspaces": {
            "*": 5
        }
    },

    "hyprland/window": {
        "format": "{}",
        "format-empty": "",
        "max-length": 50,
        "separate-outputs": true
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

### 3. Stylesheet (`~/.config/waybar/style.css`)

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

---

## Phase 9: SwayNC Configuration & Nord Styling

### 1. Configuration (`~/.config/swaync/config.json`)

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

### 2. Stylesheet (`~/.config/swaync/style.css`)

```css
/* --- Nord Theme for SwayNC --- */
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

## Phase 10: Thunar File Manager DBus Bridge

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
