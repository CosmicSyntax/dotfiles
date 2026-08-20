```markdown
# Comprehensive Fedora Hyprland Environment Setup Guide

This document provides the complete, end-to-end blueprint for building a fully configured, minimalist **Hyprland** Wayland environment on **Fedora Linux**. It includes purging the GNOME Desktop Environment shell infrastructure, setting up `greetd` terminal login, your complete Hyprland Lua script, `hyprlock` authentication setup, Waybar status bar configurations with **GoogleSansMNerdFont-Regular**, and browser-to-file-manager bridges.

---

## Phase 1: Purging GNOME Desktop Infrastructure & Display Managers

To completely strip out the core GNOME Desktop Environment (DE) shell and its background session components while leaving standalone user utilities untouched, run the following commands:

### 1. Remove Core GNOME Shell, Mutter, and GDM
Tear out `gnome-shell`, session targets, Mutter window management infrastructure, GDM, and competing portals:
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

### 2. Remove Unused GNOME Panels & Background Daemons

Remove background shell extensions, desktop backgrounds, and initial setup wizards:

```bash
sudo dnf remove \
    "gnome-shell-extension*" \
    gnome-backgrounds \
    gnome-initial-setup \
    gnome-user-docs

```

### 3. Sweep Away Orphaned Dependencies

Clean up any remaining system libraries pulled in solely by `gnome-shell`:

```bash
sudo dnf autoremove

```

---

## Phase 2: System Package Installation

Install the window manager, greeter, applets, audio/network tools, utilities, and screen-sharing portals:

```bash
sudo dnf install \
    hyprland \
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
    dunst \
    hyprpolkitagent \
    grim \
    slurp \
    wl-clipboard \
    pipewire \
    wireplumber \
    xdg-desktop-portal \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk

```

---

## Phase 3: Greetd Configuration (Terminal Login)

Configure `greetd` with `agreety` to provide a clean text login prompt on Virtual Terminal 1 (`vt = 1`).

1. Open the configuration file:
```bash
sudo nvim /etc/greetd/config.toml

```


2. Add the following configuration:
```toml
[terminal]
vt = 1

[default_session]
command = "agreety --cmd start-hyprland"
user = "greetd"

```


3. Enable the service:
```bash
sudo systemctl enable greetd

```



---

## Phase 4: Hyprland Lua Configuration (`~/.config/hypr/hyprland.lua`)

This is your complete, production-ready Hyprland Lua script, handling monitors, environment variables, startup daemons, custom keybindings, and window rules.

```lua
--------------------------------------------------------------------------------
-- HYPRLAND CONFIGURATION (LUA)
--------------------------------------------------------------------------------

-- Monitors (HiDPI laptop panel)
hl.monitor({
    output   = "eDP-1",
    mode     = "3840x2400@60",
    position = "0x0",
    scale    = "1.6",
})

-- Default Applications & Variables
local terminal    = "alacritty"
local menu        = "wofi --show drun"
local fileManager = "env GTK_THEME=Adwaita:dark thunar"
local browser     = "flatpak run one.ablaze.floorp"
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
    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("dunst")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    
    -- Background Keyring Daemon
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,ssh,pkcs11")

    -- Set GTK Theme Properties via GSettings
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
        border_size      = 2,
        col              = {
            active_border   = { colors = { "#81a1c1", "#2e3440" }, angle = 45 },
            inactive_border = "#2e3440",
        },
        layout           = "dwindle",
        resize_on_border = false,
        allow_tearing    = false,
    },

    decoration = {
        rounding         = 8,
        active_opacity   = 1.0,
        inactive_opacity = 0.95,
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
    { mainMod .. " + J",         hl.dsp.layout("togglesplit") },
    { mainMod .. " + M",         hl.dsp.exit() },
    { mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = 1 }) },
    { mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 0 }) },
    { mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock") },
}

for _, b in ipairs(app_binds) do
    hl.bind(b[1], b[2])
end

-- Focus Navigation (SUPER + Arrow Keys)
local focus_binds = {
    { mainMod .. " + left",  hl.dsp.focus({ direction = "left" }) },
    { mainMod .. " + right", hl.dsp.focus({ direction = "right" }) },
    { mainMod .. " + up",    hl.dsp.focus({ direction = "up" }) },
    { mainMod .. " + down",  hl.dsp.focus({ direction = "down" }) },
}

for _, b in ipairs(focus_binds) do
    hl.bind(b[1], b[2])
end

-- Tile / Window Movement (SUPER + SHIFT + Arrow Keys)
local move_binds = {
    { mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }) },
    { mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }) },
    { mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }) },
    { mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }) },
}

for _, b in ipairs(move_binds) do
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

-- Media, Audio & Hardware Brightness Keys
local media_keys = {
    { "XF86AudioRaiseVolume",    "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" },
    { "XF86AudioLowerVolume",    "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
    { "XF86AudioMute",           "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    { "XF86AudioMicMute",        "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
    { "XF86MonBrightnessUp",     "brightnessctl set 5%+" },
    { "XF86MonBrightnessDown",   "brightnessctl set 5%-" },
    { "XF86AudioNext",           "playerctl next" },
    { "XF86AudioPrev",           "playerctl previous" },
    { "XF86AudioPlay",           "playerctl play-pause" },
    { "XF86AudioPause",          "playerctl play-pause" },
}

for _, k in ipairs(media_keys) do
    hl.bind(k[1], hl.dsp.exec_cmd(k[2]), { locked = true, repeating = true })
end

--------------------------------------------------------------------------------
-- WINDOW RULES
--------------------------------------------------------------------------------

hl.window_rule({
    name             = "suppress-maximize-events",
    match            = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name       = "fix-xwayland-drags",
    match      = { class = "^$", title = "^$", xwayland = true, float = true },
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

## Phase 5: Hyprlock Configuration (`~/.config/hypr/hyprlock.conf`)

```ini
background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 7
}

input-field {
    monitor =
    size = 250, 50
    outline_thickness = 3
    dots_size = 0.33
    dots_spacing = 0.15
    fade_on_empty = false
    placeholder_text = <span foreground="#cad3f5">Input Password...</span>
}

```

---

## Phase 6: Waybar Setup & Styling

### 1. Layout Configuration (`~/.config/waybar/config.jsonc`)

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
        "pulseaudio",
        "network",
        "backlight",
        "battery",
        "clock",
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

    "custom/power": {
        "format": "⏻",
        "on-click": "~/.config/waybar/scripts/power-menu.sh",
        "tooltip": false
    }
}

```

### 2. Stylesheet (`~/.config/waybar/style.css`)

```css
* {
    font-family: "GoogleSansMNerdFont-Regular", sans-serif;
    font-size: 13px;
    font-weight: bold;
    min-height: 0;
}

window#waybar {
    background: rgba(46, 52, 64, 0.85);
    color: #eceff4;
    border-bottom: 2px solid rgba(129, 161, 193, 0.3);
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

#clock,
#battery,
#backlight,
#network,
#pulseaudio,
#custom-power,
#window {
    background: #3b4252;
    padding: 2px 10px;
    margin: 4px 3px;
    border-radius: 6px;
    color: #eceff4;
}

#custom-power {
    color: #bf616a;
    margin-right: 6px;
}

#custom-power:hover {
    background: #bf616a;
    color: #2e3440;
}

```

### 3. Power Menu Script (`~/.config/waybar/scripts/power-menu.sh`)

```bash
#!/usr/bin/env bash

CHOICE=$(printf "Lock\nLogout\nReboot\nShutdown" | wofi --dmenu -p "Power Menu")

case "$CHOICE" in
    *"Lock")
        hyprlock
        ;;
    *"Logout")
        loginctl terminate-session $XDG_SESSION_ID
        ;;
    *"Reboot")
        systemctl reboot
        ;;
    *"Shutdown")
        systemctl poweroff
        ;;
esac

```

---

## Phase 7: Browser File Manager Bridge (Thunar)

1. Set the default directory handler:
```bash
xdg-mime default thunar.desktop inode/directory

```


2. Create the D-Bus file manager bridge service:
```bash
mkdir -p ~/.local/share/dbus-1/services
nvim ~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service

```


3. Paste this service definition:
```ini
[D-BUS Service]
Name=org.freedesktop.FileManager1
Exec=/usr/bin/thunar --sm-client-disable

```


4. Refresh application cache:
```bash
update-desktop-database ~/.local/share/applications

```
