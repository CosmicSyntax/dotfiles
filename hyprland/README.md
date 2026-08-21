---

# Comprehensive Fedora Hyprland Environment Setup Guide (UWSM Edition)

This blueprint details a fully configured, minimalist **Hyprland** Wayland environment on **Fedora Linux**, integrated cleanly with **UWSM (Universal Wayland Session Manager)**. This setup guarantees enterprise-grade systemd tracking, automated D-Bus portal synchronization for flawless screen sharing, Native HDR support, Zen Browser integration, a kernel-aware True Clamshell Mode, and a customized Nord-themed interface with globally applied Papirus icons.

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

Install the compositor, session manager (`uwsm`), utilities, portals, dynamic night light daemon, and icon themes.

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

## Phase 4: Dynamic Night Light Script (wlsunset)

Create a wrapper script that dynamically fetches your latitude and longitude via IP to trigger night-light transitions based on your local sunset.

1. Create the script:
```bash
mkdir -p ~/.config/hypr/scripts
nvim ~/.config/hypr/scripts/dynamic-nightlight.sh

```


2. Add the tracking logic:
```bash
#!/usr/bin/env bash

# Fetch latitude and longitude based on your current IP address
COORDS=$(curl -s ipinfo.io/loc)

# Split the output into separate variables
LAT=$(echo $COORDS | cut -d',' -f1)
LON=$(echo $COORDS | cut -d',' -f2)

# Fallback to default coordinates if offline on boot
if [ -z "$LAT" ] || [ -z "$LON" ]; then
    LAT="39.1"
    LON="-77.2"
fi

# Launch wlsunset with the dynamic coordinates (Warmth: 4500K)
wlsunset -l "$LAT" -L "$LON" -t 4500

```


3. Make it executable:
```bash
chmod +x ~/.config/hypr/scripts/dynamic-nightlight.sh

```



---

## Phase 5: UWSM-Optimized Hyprland Configuration (`~/.config/hypr/hyprland.lua`)

This Lua configuration features dynamic kernel-aware Clamshell Mode, Native HDR, 2560x1600 rendering, Zen Browser, dynamic night light, Papirus icon theming, and leverages `uwsm app --` to launch processes natively inside systemd.

```lua
--------------------------------------------------------------------------------
-- HYPRLAND CONFIGURATION (LUA)
--------------------------------------------------------------------------------

-- Monitors (HiDPI laptop panel)
local handle = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
local lid_state = handle:read("*a")
handle:close()

-- 2. Dynamically configure eDP-1 based on the physical switch
if string.find(string.lower(lid_state), "closed") then
    -- Lid is shut: keep the screen dead during config reloads
    hl.monitor({
        output   = "eDP-1",
        disabled = true,
    })
else
    -- Lid is open: initialize the panel normally
    hl.monitor({
        output   = "eDP-1",
        mode     = "2560x1600@60",
        position = "0x1440",
        scale    = "1.0",
        bitdepth = 10,
        cm       = "auto",
    })
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
local terminal    = "alacritty"
local menu        = "~/.config/hypr/scripts/wofi-toggle.sh"
local fileManager = "env GTK_THEME=Adwaita:dark thunar"
local browser     = "flatpak run app.zen_browser.zen"
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
    -- 1. Start core daemons using their native systemd services
    hl.exec_cmd("systemctl --user start swaync.service")
    hl.exec_cmd("systemctl --user start waybar.service")
    hl.exec_cmd("systemctl --user start hypridle.service")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

    -- 2. Wrap standalone background apps in UWSM scopes
    hl.exec_cmd("uwsm app -- hyprpaper")
    hl.exec_cmd("uwsm app -- nm-applet --indicator")
    hl.exec_cmd("uwsm app -- blueman-applet")
    hl.exec_cmd("uwsm app -- gnome-keyring-daemon --start --components=secrets,ssh,pkcs11")
    -- Dynamic Night Light via IP geolocation
    hl.exec_cmd("~/.config/hypr/scripts/dynamic-nightlight.sh")

    -- 3. Set GTK Theme Properties via GSettings
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'")
end)

-- Core System & Appearance Settings
hl.config({
    ecosystem = {
        no_donation_nag = true,
        no_update_news  = true,
    },

    general = {
        gaps_in          = 4,
        gaps_out         = 10,
        border_size      = 0,
        -- col              = {
        --      active_border   = { colors = { "#81a1c1", "#2e3440" }, angle = 45 },
        --      inactive_border = "#2e3440",
        -- },
        layout           = "dwindle",
        resize_on_border = true, -- Enables mouse-dragging on inner split borders
        allow_tearing    = false,
    },

    decoration = {
        rounding         = 5,
        active_opacity   = 1.0,
        inactive_opacity = 0.85,
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
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
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
    -- Toggle Night Light (Kills wlsunset if running, restarts dynamic script if not)
    { mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("pkill wlsunset || uwsm app -- ~/.config/hypr/scripts/dynamic-nightlight.sh") },
    -- { mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock") },

    -- Graceful session termination via UWSM
    { mainMod .. " + M",         hl.dsp.exec_cmd("uwsm stop") },
}

for _, b in ipairs(app_binds) do
    hl.bind(b[1], b[2])
end

-- Focus Navigation (SUPER + Arrow Keys)
local focus_binds = {
    { mainMod .. " + H", hl.dsp.focus({ direction = "left" }) },
    { mainMod .. " + L", hl.dsp.focus({ direction = "right" }) },
    { mainMod .. " + K", hl.dsp.focus({ direction = "up" }) },
    { mainMod .. " + J", hl.dsp.focus({ direction = "down" }) },
}

for _, b in ipairs(focus_binds) do
    hl.bind(b[1], b[2])
end

-- Tile / Window Movement (SUPER + SHIFT + Arrow Keys)
local move_binds = {
    { mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }) },
    { mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }) },
    { mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }) },
    { mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }) },
}

for _, b in ipairs(move_binds) do
    hl.bind(b[1], b[2])
end

-- Dynamic Window Resizing (SUPER + SHIFT + Arrow Keys)
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

-- Workspaces 1-10 Navigation & Window Relocation
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad (Magic Workspace)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Clamshell Mode (Lid Switch Listener)
-- Clamshell Mode (True monitor disable via Lua parser)
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd([[hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})']]),
    { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd([[hyprctl eval 'hl.monitor({output="eDP-1", disabled=false})']]),
    { locked = true })

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

## Phase 6: Wofi Toggle Script Wrapper

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


3. Make executable:
```bash
chmod +x ~/.config/hypr/scripts/wofi-toggle.sh

```



---

## Phase 7: Waybar Setup & UWSM Power Menu

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
        hyprctl dispatch exit
        ;;
    *"Reboot")
        systemctl reboot
        ;;
    *"Shutdown")
        systemctl poweroff
        ;;
esac

```

*(Make executable: `chmod +x ~/.config/waybar/scripts/power-menu.sh`)*

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

## Phase 8: SwayNC Configuration & Nord Styling

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

## Phase 9: Thunar File Manager DBus Bridge

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

---

## Phase 10: GTK & Flatpak Theming Engine

Ensure your GTK3 applications (like Thunar) and Flatpak applications (like Zen Browser) correctly inherit your dark mode and Papirus icons.

### 1. Hardcode GTK3 Settings (`settings.ini`)

```bash
mkdir -p ~/.config/gtk-3.0
cat <<EOF > ~/.config/gtk-3.0/settings.ini
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-application-prefer-dark-theme=1
EOF

```

### 2. Install Flatpak Icon Bridge

```bash
flatpak install flathub org.freedesktop.Platform.Icontheme.Papirus

```

### 3. (Optional) Apply Nord Color Palette to Folders

```bash
# Download the papirus-folders script
wget -qO- https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/install.sh | sh

# Apply the Nord color palette to the Dark theme
papirus-folders -C nord --theme Papirus-Dark

```
