# Fedora Hyprland Post-Install & Setup Guide

This guide details all packages, system configurations, and user configuration files needed to reproduce the complete Hyprland desktop setup on Fedora.

---

## 1. System Package Installation

Run the following commands to install the compositor ecosystem, utilities, audio/brightness controllers, and authentication tooling:

```bash
sudo dnf update -y
sudo dnf install -y \
    hyprland \
    hyprpaper \
    hypridle \
    hyprlock \
    waybar \
    wofi \
    alacritty \
    thunar \
    grim \
    slurp \
    wl-clipboard \
    wf-recorder \
    jq \
    brightnessctl \
    playerctl \
    wireplumber \
    polkit-gnome \
    gnome-keyring \
    gnome-keyring-pam \
    seahorse

```

---

## 2. Display Manager & Power Management

### SDDM Automatic Keyring Unlock

Ensure `/etc/pam.d/sddm` includes the GNOME Keyring PAM module so logging in automatically unlocks stored credentials:

```bash
sudo vi /etc/pam.d/sddm

```

Verify these two lines exist in their respective sections:

```plaintext
# Under auth
-auth        optional      pam_gnome_keyring.so

# Under session
-session     optional      pam_gnome_keyring.so auto_start

```

> **Note:** Use `seahorse` to create a default keyring named **Login** and ensure its password matches your Linux user account password.

### Laptop Lid Sleep Configuration

Configure `systemd-logind` so closing the laptop lid or pressing the power button suspends the machine:

```bash
sudo vi /etc/systemd/logind.conf

```

Set the following parameters:

```ini
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
HandlePowerKey=suspend

```

Apply immediately:

```bash
sudo systemctl restart systemd-logind

```

---

## 3. Configuration Files

### `~/.config/hypr/hyprpaper.conf`

```ini
splash = false

wallpaper {
    monitor = 
    path = ~/Pictures/wallpaper.png
    fit_mode = cover
}

ipc = on

```

### `~/.config/hypr/hypridle.conf`

```ini
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = hyprlock
}

listener {
    timeout = 600
    on-timeout = systemctl suspend
}

```

### `~/.config/waybar/config.jsonc`

```jsonc
{
    "layer": "top",
    "position": "top",
    "height": 34,
    "margin-top": 6,
    "margin-left": 10,
    "margin-right": 10,
    "spacing": 6,
    "modules-left": [
        "hyprland/workspaces",
        "hyprland/window"
    ],
    "modules-center": [
        "clock"
    ],
    "modules-right": [
        "power-profiles-daemon",
        "wireplumber",
        "backlight",
        "battery",
        "network",
        "tray"
    ],
    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}",
        "on-click": "activate"
    },
    "hyprland/window": {
        "format": "{}",
        "max-length": 40,
        "separate-outputs": true
    },
    "tray": {
        "icon-size": 16,
        "spacing": 8
    },
    "clock": {
        "format": "   {:%I:%M %p     %a, %b %d}",
        "tooltip-format": "<tt><small>{calendar}</small></tt>",
        "calendar": {
            "mode": "year",
            "mode-mon-col": 3,
            "weeks-pos": "right"
        }
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
    "wireplumber": {
        "format": "{icon}  {volume}%",
        "format-muted": "   Muted",
        "format-icons": ["", "", ""],
        "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
        "scroll-step": 5
    },
    "backlight": {
        "format": "{icon}  {percent}%",
        "format-icons": ["", "", "", "", "", "", "", ""],
        "scroll-step": 5
    },
    "battery": {
        "states": {
            "good": 95,
            "warning": 30,
            "critical": 15
        },
        "format": "{icon}  {capacity}%",
        "format-charging": "   {capacity}%",
        "format-plugged": "   {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    "network": {
        "format-wifi": "   {essid}",
        "format-ethernet": "󰈀   {ipaddr}",
        "format-linked": "󰈀   {ifname} (No IP)",
        "format-disconnected": "󰤭  Disconnected",
        "tooltip-format": "{ifname} via {gwaddr}"
    }
}

```

### `~/.config/waybar/style.css`

```css
* {
    border: none;
    border-radius: 0;
    font-family: "GoogleSansMNerdFont-Regular", monospace;
    font-weight: 600;
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background-color: rgba(46, 52, 64, 0.85); /* nord0 translucent */
    border: 2px solid #3B4252;               /* nord1 */
    border-radius: 8px;
    color: #D8DEE9;                          /* nord4 */
}

/* Individual Module Pills */
#workspaces,
#window,
#clock,
#power-profiles-daemon,
#wireplumber,
#backlight,
#battery,
#network,
#tray {
    background-color: #3B4252; /* nord1 */
    padding: 2px 12px;
    margin: 4px 2px;
    border-radius: 6px;
    color: #ECEFF4;            /* nord6 */
}

/* Workspaces */
#workspaces {
    background-color: transparent;
    padding: 0;
}

#workspaces button {
    padding: 2px 8px;
    margin: 4px 2px;
    background-color: #3B4252; /* nord1 */
    color: #D8DEE9;            /* nord4 */
    border-radius: 6px;
    transition: all 0.2s ease-in-out;
}

#workspaces button.active {
    background-color: #88C0D0; /* nord8 Frost */
    color: #2E3440;            /* nord0 */
}

#workspaces button:hover {
    background-color: #4C566A; /* nord3 */
    color: #ECEFF4;
}

#workspaces button.urgent {
    background-color: #BF616A; /* nord11 Red */
    color: #ECEFF4;
}

/* Window Title */
#window {
    background-color: transparent;
    color: #81A1C1;            /* nord9 */
}

/* Center Clock */
#clock {
    background-color: #434C5E; /* nord2 */
    color: #88C0D0;            /* nord8 */
}

/* Right Status Modules Accent Colors */
#power-profiles-daemon {
    color: #EBCB8B;            /* nord13 Yellow */
}

#wireplumber {
    color: #88C0D0;            /* nord8 Frost */
}

#wireplumber.muted {
    background-color: #BF616A;
    color: #2E3440;
}

#backlight {
    color: #EBCB8B;            /* nord13 Yellow */
}

#battery {
    color: #A3BE8C;            /* nord14 Green */
}

#battery.charging {
    color: #8FBCBB;            /* nord7 */
}

#battery.warning:not(.charging) {
    background-color: #D08770; /* nord12 Orange */
    color: #2E3440;
}

#battery.critical:not(.charging) {
    background-color: #BF616A; /* nord11 Red */
    color: #ECEFF4;
}

#network {
    color: #B48EAD;            /* nord15 Purple */
}

#network.disconnected {
    background-color: #BF616A;
    color: #ECEFF4;
}

```

### `~/.config/hypr/hyprland.lua`

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
local browser     = "zen-browser"
local mainMod     = "SUPER"

-- Autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("/usr/libexec/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,ssh,pkcs11")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'")
    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
end)

-- Environment Variables (Theming & Cursors)
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

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
            -- Nord Muted Theme: Soft Snow Storm / Nord Frost gradient
            active_border   = { colors = { "#81a1c1", "#2e3440" }, angle = 45 },
            -- Inactive: Polar Night Slate
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
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        -- disable_splash_rendering = true,
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

-- Application Launchers & Window Actions
local app_binds = {
    { mainMod .. " + T",         hl.dsp.exec_cmd(terminal) },
    { mainMod .. " + R",         hl.dsp.exec_cmd(menu) },
    { mainMod .. " + E",         hl.dsp.exec_cmd(fileManager) },
    { mainMod .. " + B",         hl.dsp.exec_cmd(browser) },
    { mainMod .. " + Q",         hl.dsp.window.close() },
    -- { mainMod .. " + T",      hl.dsp.window.float({ action = "toggle" }) },
    { mainMod .. " + P",         hl.dsp.window.pseudo() },
    { mainMod .. " + J",         hl.dsp.layout("togglesplit") },
    { mainMod .. " + M",         hl.dsp.exit() },
    { mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = 1 }) },
    { mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 0 }) },
}

for _, b in ipairs(app_binds) do
    hl.bind(b[1], b[2])
end

-- Screenshots & Screen Recording
local screenshot_dir = "~/Pictures/Screenshots"
local screenshot_area = string.format(
    "grim -g \"$(slurp)\" - | tee %s/$(date +%%Y-%%m-%%d_%%H-%%M-%%S).png | wl-copy && notify-send 'Screenshot' 'Area copied to clipboard and saved'",
    screenshot_dir)
local screenshot_full = string.format(
    "grim - | tee %s/$(date +%%Y-%%m-%%d_%%H-%%M-%%S).png | wl-copy && notify-send 'Screenshot' 'Full screen captured'",
    screenshot_dir)
local screenshot_window = string.format(
    "grim -g \"$(hyprctl -j activewindow | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"')\" - | tee %s/$(date +%%Y-%%m-%%d_%%H-%%M-%%S).png | wl-copy && notify-send 'Screenshot' 'Window captured'",
    screenshot_dir)

hl.bind("PRINT", hl.dsp.exec_cmd(screenshot_area))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot_area))
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd(screenshot_full))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd(screenshot_window))
hl.bind(mainMod .. " + SHIFT + R",
    hl.dsp.exec_cmd(
        "killall -s SIGINT wf-recorder || wf-recorder -g \"$(slurp)\" -f ~/Videos/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4 && notify-send 'Screen Recorder' 'Recording toggled'"))

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
    -- SUPER + [0-9]: Switch to workspace
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    -- SUPER + SHIFT + [0-9]: Move active window to workspace
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad (Magic Workspace)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Mouse Interactions (Drag, Resize, Workspace Scroll)
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media, Audio & Hardware Brightness Keys
local media_keys = {
    { "XF86AudioRaiseVolume",  "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" },
    { "XF86AudioLowerVolume",  "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
    { "XF86AudioMute",          "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
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

```

---

## 4. Key Reference Cheat Sheet

| Keybinding | Action |
| --- | --- |
| `SUPER + T` | Open Terminal (`alacritty`)

 |
| `SUPER + R` | Application Launcher (`wofi`)

 |
| `SUPER + E` | File Manager (`thunar`)

 |
| `SUPER + B` | Browser (`zen-browser`)

 |
| `SUPER + Q` | Close Active Window

 |
| `SUPER + F` | Maximize Active Tile (Monocle)

 |
| `SUPER + SHIFT + F` | True Fullscreen

 |
| `SUPER + P` | Pseudo Tile Mode

 |
| `SUPER + J` | Toggle Split Orientation

 |
| `SUPER + M` | Exit Hyprland

 |
| `SUPER + Arrow Keys` | Focus Window

 |
| `SUPER + SHIFT + Arrow Keys` | Move Tiled Window

 |
| `SUPER + 1..0` | Switch Workspace

 |
| `SUPER + SHIFT + 1..0` | Move Window to Workspace

 |
| `SUPER + S` | Toggle Magic Scratchpad

 |
| `SUPER + SHIFT + S` | Move Window to Scratchpad

 |
| `PRINT` / `SUPER + SHIFT + S` | Screenshot Selected Area to Clipboard & File

 |
