# Comprehensive Fedora Hyprland Environment Setup Guide (UWSM Edition)

This blueprint details a fully configured, minimalist **Hyprland** Wayland environment on **Fedora Linux**, integrated cleanly with **UWSM (Universal Wayland Session Manager)**. This setup guarantees enterprise-grade systemd tracking, automated D-Bus portal synchronization for screen sharing, native HDR support, a kernel-aware True Clamshell Mode, silent PAM keyring unlocking via `greetd`, an idle session management daemon (`hypridle`), a secure lockscreen (`hyprlock`), and a unified Nord-themed interface powered natively by **Quickshell** and **Walker**.

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

Install the compositor, session manager (`uwsm`), utilities, portals, media capture tools, keyring libraries, icon themes, idle manager, lockscreen, and the Walker application launcher.

```bash
sudo dnf copr enable errornointernet/walker
sudo dnf install \
    hyprland \
    uwsm \
    greetd \
    agreety \
    quickshell \
    walker \
    elephant \
    hyprpaper \
    hypridle \
    hyprlock \
    alacritty \
    thunar \
    pavucontrol \
    blueman \
    NetworkManager-tui \
    network-manager-applet \
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
    papirus-icon-theme

```

---

## Phase 3: Greetd & PAM Auto-Unlock Configuration

Configure `greetd` to launch Hyprland securely inside a UWSM systemd scope on Virtual Terminal 1 and silently unlock `gnome-keyring`.

### 1. Configure Greetd (`/etc/greetd/config.toml`)

```toml
[terminal]
vt = 1

[default_session]
command = "agreety --cmd 'uwsm start hyprland.desktop'"
user = "greetd"

```

### 2. Configure PAM for Greetd (`/etc/pam.d/greetd`)

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

Create custom background scripts for display adjustments, lid switching, and media capture.

```bash
mkdir -p ~/.config/hypr/scripts

```

### 1. Dynamic Night Light (`~/.config/hypr/scripts/dynamic-nightlight.sh`)

```bash
#!/usr/bin/env bash
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

if grep -iq closed /proc/acpi/button/lid/*/state 2>/dev/null; then
    if hyprctl monitors | grep -q "DP-1"; then
        hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
    fi
fi

```

### 2. Context-Aware Lid Close (`~/.config/hypr/scripts/lid-close.sh`)

```bash
#!/usr/bin/env bash
if [ "$(hyprctl monitors | grep -c "^Monitor")" -gt 1 ]; then
    if pidof hyprlock > /dev/null; then
        hyprctl dispatch dpms off eDP-1
    else
        hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
    fi
fi

```

### 3. Context-Aware Lid Open (`~/.config/hypr/scripts/lid-open.sh`)

```bash
#!/usr/bin/env bash
if ! hyprctl monitors | grep -q "Monitor eDP-1"; then
    hyprctl eval 'hl.monitor({output="eDP-1", mode="2560x1600@60", position="0x1440", scale="1.0", bitdepth=10, cm="auto", disabled=false})'
fi

```

### 4. Screenshot Capture (`~/.config/hypr/scripts/screenshot.sh`)

```bash
#!/usr/bin/env bash
mkdir -p ~/Pictures/Screenshots
REGION=$(slurp)
if [ -z "$REGION" ]; then exit 0; fi
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
    notify-send "Screen Recording" "Select an area to begin... (Press ESC to cancel)" -i media-record
    REGION=$(slurp)
    if [ -z "$REGION" ]; then exit 0; fi
    FILE=~/Videos/Recordings/Record_$(date +'%Y%m%d_%H%M%S').mp4
    wf-recorder -g "$REGION" -f "$FILE" &
    notify-send "Screen Recording" "Recording started! Press SUPER+SHIFT+R to stop." -i media-record
fi

```

*(Ensure all scripts are executable: `chmod +x ~/.config/hypr/scripts/*.sh`)*

---

## Phase 5: Idle & Session Management Configuration

### 1. Idle Daemon Config (`~/.config/hypr/hypridle.conf`)

Manages power-saving timeouts, screen dimming, locking, DPMS output shutdowns, and system suspension.

```ini
listener {
    timeout = 150
    on-timeout = brightnessctl -s set 10
    on-resume = brightnessctl -r
}

listener {
    timeout = 300
    on-timeout = loginctl lock-session
}

listener {
    timeout = 330
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 1800
    on-timeout = systemctl suspend
}

general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

```

### 2. Lockscreen Config (`~/.config/hypr/hyprlock.conf`)

Provides a blurred, Nord-styled security lock interface.

```ini
general {
    disable_loading_bar = true
    hide_cursor = true
    grace = 0
    no_fade_in = false
}

background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 8
    noise = 0.0117
    contrast = 0.8916
    brightness = 0.8172
    vibrancy = 0.1696
    color = rgb(46, 52, 64)
}

label {
    monitor =
    text = $TIME
    color = rgb(216, 222, 233)
    font_size = 90
    font_family = GoogleSansMNerdFont-Regular
    position = 0, 150
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 280, 50
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.2
    dots_center = true
    outer_color = rgb(136, 192, 208)
    inner_color = rgb(59, 66, 82)
    font_color = rgb(216, 222, 233)
    fade_on_empty = false
    placeholder_text = <i>  Enter Password...</i>
    hide_input = false
    check_color = rgb(235, 203, 139)
    fail_color = rgb(191, 97, 106)
    fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i>
    position = 0, -40
    halign = center
    valign = center
}

```

---

## Phase 6: Hyprland Lua Configuration (`~/.config/hypr/hyprland.lua`)

```lua
--------------------------------------------------------------------------------
-- HYPRLAND CONFIGURATION (LUA)
--------------------------------------------------------------------------------

local eDP1_config = {
    output   = "eDP-1",
    mode     = "2560x1600@60",
    position = "0x1440",
    scale    = "1.25",
    bitdepth = 10,
    cm       = "auto",
}

local handle_lid = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
local lid_state = handle_lid:read("*a") or ""
handle_lid:close()

local handle_dp = io.popen("cat /sys/class/drm/card*-DP-*/status 2>/dev/null | grep -w 'connected'")
local dp_state = handle_dp:read("*a") or ""
handle_dp:close()

local is_closed = string.find(string.lower(lid_state), "closed")

if is_closed then
    hl.monitor({ output = eDP1_config.output, disabled = true })
else
    hl.monitor(eDP1_config)
    hl.monitor({
        output   = "DP-1",
        mode     = "highres@highrr",
        position = "0x0",
        scale    = "1.0",
        bitdepth = 10,
        cm       = "auto",
    })
end

local terminal    = "uwsm app -- alacritty"
local menu        = "walker"
local fileManager = "uwsm app -- env GTK_THEME=Adwaita:dark thunar"
local browser     = "uwsm app -- flatpak run app.zen_browser.zen"
local mainMod     = "SUPER"

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.on("hyprland.start", function()
    hl.exec_cmd("gnome-keyring-daemon --start --components=pkcs11,secrets,ssh")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SSH_AUTH_SOCK")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SSH_AUTH_SOCK")
    
    hl.exec_cmd("systemctl --user start hypridle.service")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("uwsm app -- quickshell")

    hl.exec_cmd("uwsm app -- hyprpaper")
    hl.exec_cmd("uwsm app -- nm-applet --indicator")
    hl.exec_cmd("uwsm app -- blueman-applet")
    hl.exec_cmd("uwsm app -- elephant")
    hl.exec_cmd("uwsm app -- walker --gapplication-service")
    hl.exec_cmd("~/.config/hypr/scripts/dynamic-nightlight.sh")

    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'")
end)

hl.config({
    ecosystem = { no_donation_nag = true, no_update_news = false },
    general = { gaps_in = 4, gaps_out = 10, border_size = 0, layout = "dwindle", resize_on_border = true, allow_tearing = false },
    decoration = {
        rounding = 5, active_opacity = 1.0, inactive_opacity = 0.90,
        shadow = { enabled = true, range = 12, render_power = 2, color = 0xee1a1e24 },
        blur = { enabled = true, size = 4, passes = 2, vibrancy = 0.1696 },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_hyprland_guiutils_check = false,
        focus_on_activate = true,
    },
    input = { kb_layout = "us", follow_mouse = 0, sensitivity = 0, touchpad = { natural_scroll = true } },
})

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

for _, b in ipairs(app_binds) do hl.bind(b[1], b[2]) end

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

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/scripts/lid-close.sh"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/scripts/lid-open.sh"), { locked = true })

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
for _, k in ipairs(media_keys) do hl.bind(k[1], hl.dsp.exec_cmd(k[2]), { locked = true, repeating = true }) end

hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true }, no_focus = true })
hl.window_rule({ name = "smart-borders-solo", match = { workspace = "w[t1]", float = false }, border_size = 0 })
hl.window_rule({ name = "float-utilities", match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor)$" }, float = true, center = true })

```

---

## Phase 7: Walker Application Launcher Configuration

### 1. Walker Config (`~/.config/walker/config.toml`)



```toml
theme = "nord"
close_when_open = true
force_keyboard_focus = true

[builtins.applications]
weight = 100

[builtins.runner]
weight = 90

```

### 2. Walker Nord Theme (`~/.config/walker/themes/nord/style.css`)



```css
@define-color window_bg_color #2e3440;
@define-color accent_bg_color #81a1c1;
@define-color theme_fg_color #eceff4;
@define-color error_bg_color #bf616a;
@define-color error_fg_color #eceff4;

* {
  all: unset;
}

popover {
  background: #3b4252;
  border: 1px solid @accent_bg_color;
  border-radius: 18px;
  padding: 10px;
}

.normal-icons {
  -gtk-icon-size: 16px;
}

.large-icons {
  -gtk-icon-size: 32px;
}

scrollbar {
  opacity: 0;
}

.box-wrapper {
  box-shadow:
    0 19px 38px rgba(0, 0, 0, 0.4),
    0 15px 12px rgba(0, 0, 0, 0.3);
  background: @window_bg_color;
  padding: 20px;
  border-radius: 20px;
  border: 2px solid @accent_bg_color;
}

.preview-box,
.elephant-hint,
.placeholder {
  color: @theme_fg_color;
}

.search-container {
  border-radius: 10px;
}

.input placeholder {
  opacity: 0.5;
  color: #4c566a;
}

.input selection {
  background: #434c5e;
}

.input {
  caret-color: @theme_fg_color;
  background: #3b4252;
  padding: 12px;
  color: @theme_fg_color;
  border-radius: 8px;
  border: 1px solid #434c5e;
  font-family: "GoogleSansM Nerd Font", sans-serif;
  font-size: 16px;
}

.input:focus,
.input:active {
  border: 1px solid @accent_bg_color;
  background: #434c5e;
}

.list {
  color: @theme_fg_color;
  font-family: "GoogleSansM Nerd Font", sans-serif;
}

.item-box {
  border-radius: 10px;
  padding: 10px;
  font-family: "GoogleSansM Nerd Font", sans-serif;
}

child:selected .item-box,
row:selected .item-box {
  background: alpha(@accent_bg_color, 0.3);
  border-radius: 10px;
}

.item-text {
  color: @theme_fg_color;
  font-weight: bold;
}

.item-subtext {
  font-size: 12px;
  opacity: 0.8;
  color: #d8dee9;
}

.keybinds {
  padding-top: 10px;
  border-top: 1px solid #3b4252;
  font-size: 12px;
  color: #4c566a;
}

.keybind-label {
  padding: 2px 4px;
  border-radius: 4px;
  border: 1px solid #4c566a;
  color: @theme_fg_color;
}

.error {
  padding: 10px;
  background: @error_bg_color;
  color: @error_fg_color;
}

```

---

## Phase 8: Quickshell Architecture (Unified Shell & Notifications)

### 1. Root Scope (`~/.config/quickshell/shell.qml`)



```qml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "."

Scope {
    id: root

    property bool showControlCenter: false
    property bool animVisible: false

    property bool wifiEnabled: true
    property string wifiSsid: ""
    property int wifiSignal: 0
    property string wifiIcon: "󰤨"

    property bool bluetoothEnabled: false
    property bool dndEnabled: false

    property real brightnessLevel: 1.00

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volumeLevel: sink?.audio?.volume ?? 0.0
    readonly property bool volumeMuted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    function setVolume(val) {
        if (!sink?.ready || !sink.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.min(Math.max(val, 0.0), 1.0);
    }
    function toggleMute() {
        if (sink?.ready && sink.audio) sink.audio.muted = !sink.audio.muted;
    }
    function toggleMic() {
        if (source?.ready && source.audio) source.audio.muted = !source.audio.muted;
    }

    readonly property UPowerDevice battery: {
        if (UPower.displayDevice) return UPower.displayDevice;
        if (UPower.devices.values.length > 0) return UPower.devices.values[0];
        return null;
    }
    readonly property int batteryPercentage: {
        let p = battery?.percentage ?? 1.0;
        return Math.round(p <= 1.0 ? p * 100 : p);
    }
    readonly property bool batteryCharging:
        battery?.state === UPowerDeviceState.Charging
        || battery?.state === UPowerDeviceState.PendingCharge
    readonly property bool batteryFull: battery?.state === UPowerDeviceState.FullyCharged
    readonly property string batteryIcon: {
        if (root.batteryCharging) return "󰂄";
        let pct = root.batteryPercentage;
        if (pct >= 95) return "󰁹";
        if (pct >= 90) return "󰂂";
        if (pct >= 80) return "󰂁";
        if (pct >= 70) return "󰂀";
        if (pct >= 60) return "󰁿";
        if (pct >= 50) return "󰁾";
        if (pct >= 40) return "󰁽";
        if (pct >= 30) return "󰁼";
        if (pct >= 20) return "󰁻";
        if (pct >= 10) return "󰁺";
        return "󰂃";
    }

    readonly property string activeProfile: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:  return "power-saver";
        case PowerProfile.Performance: return "performance";
        default:                       return "balanced";
        }
    }
    function setPowerProfile(profile) {
        switch (profile) {
        case "power-saver": PowerProfiles.profile = PowerProfile.PowerSaver; break;
        case "performance": PowerProfiles.profile = PowerProfile.Performance; break;
        default:            PowerProfiles.profile = PowerProfile.Balanced; break;
        }
    }

    function updateWifiIcon() {
        if (!root.wifiEnabled) {
            root.wifiIcon = "󰖪";
        } else if (root.wifiSsid === "" || root.wifiSignal === 0) {
            root.wifiIcon = "󰤭";
        } else if (root.wifiSignal >= 75) {
            root.wifiIcon = "󰤨";
        } else if (root.wifiSignal >= 50) {
            root.wifiIcon = "󰤥";
        } else if (root.wifiSignal >= 25) {
            root.wifiIcon = "󰤢";
        } else {
            root.wifiIcon = "󰤟";
        }
    }

    Process {
        id: getWifiProc
        running: true
        command: [
            "sh", "-c",
            "if [ \"$(nmcli radio wifi 2>/dev/null)\" != 'enabled' ]; then " +
            "  echo 'disabled::0'; " +
            "else " +
            "  DEV_LINE=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null | awk -F: '$2==\"wifi\" && $3==\"connected\" {print $1 \":\" $4; exit}'); " +
            "  if [ -n \"$DEV_LINE\" ]; then " +
            "    IFACE=$(echo \"$DEV_LINE\" | cut -d: -f1); " +
            "    SSID=$(echo \"$DEV_LINE\" | cut -d: -f2-); " +
            "    SIG=$(awk -v dev=\"$IFACE:\" '$1==dev {sub(/\\./, \"\", $3); print int($3 * 100 / 70)}' /proc/net/wireless 2>/dev/null); " +
            "    [ -z \"$SIG\" ] && SIG=80; " +
            "    echo \"connected:${SSID}:${SIG}\"; " +
            "  else " +
            "    echo 'disconnected::0'; " +
            "  fi; " +
            "fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                let parts = line.split(":");
                let status = parts[0] || "";

                if (status === "disabled") {
                    root.wifiEnabled = false;
                    root.wifiSsid = "";
                    root.wifiSignal = 0;
                } else if (status === "connected" && parts.length >= 3) {
                    root.wifiEnabled = true;
                    root.wifiSignal = parseInt(parts[parts.length - 1]) || 80;
                    root.wifiSsid = parts.slice(1, parts.length - 1).join(":");
                } else {
                    root.wifiEnabled = true;
                    root.wifiSsid = "";
                    root.wifiSignal = 0;
                }
                root.updateWifiIcon();
            }
        }
    }

    Process {
        id: nmMonitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: _ => {
                getWifiProc.running = false;
                getWifiProc.running = true;
            }
        }
    }

    function toggleWifi() {
        root.wifiEnabled = !root.wifiEnabled;
        actionProc.exec(["nmcli", "radio", "wifi", root.wifiEnabled ? "on" : "off"]);
    }

    Process {
        id: getBrightProc
        running: true
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => {
                let val = parseFloat(data.trim());
                if (!isNaN(val)) root.brightnessLevel = Math.min(Math.max(val / 100.0, 0.05), 1.0);
            }
        }
    }

    Process { id: setBrightProc }
    function setBrightness(val) {
        root.brightnessLevel = Math.min(Math.max(val, 0.05), 1.0);
        setBrightProc.exec(["brightnessctl", "set", `${Math.round(root.brightnessLevel * 100)}%`]);
    }

    Process {
        id: getBtProc
        running: true
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: SplitParser {
            onRead: data => root.bluetoothEnabled = (data.trim() === "on")
        }
    }

    function toggleBluetooth() {
        root.bluetoothEnabled = !root.bluetoothEnabled;
        actionProc.exec(["bluetoothctl", "power", root.bluetoothEnabled ? "on" : "off"]);
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            getBrightProc.running = false; getBrightProc.running = true;
            getBtProc.running = false;     getBtProc.running = true;
            getWifiProc.running = false;   getWifiProc.running = true;
        }
    }

    Process { id: actionProc }
    Process { id: appLaunchProc }

    function runSystemCommand(cmd) {
        actionProc.exec(["sh", "-c", cmd]);
    }

    function openWifiSettings() {
        appLaunchProc.exec(["sh", "-c", "nm-connection-editor || foot -e nmtui"]);
    }

    function openBluetoothSettings() {
        appLaunchProc.exec(["sh", "-c", "blueman-manager || blueberry || foot -e bluetoothctl"]);
    }

    function openAudioSettings() {
        appLaunchProc.exec(["sh", "-c", "pavucontrol || helvum || foot -e alsamixer"]);
    }

    ListModel { id: notifHistoryModel }
    ListModel { id: activeToastModel }
    readonly property int defaultToastTimeout: 5000

    NotificationServer {
        id: notifServer
        actionsSupported: true
        imageSupported: true

        onNotification: notif => {
            if (!notif) return;
            notif.tracked = true;

            let summaryText = notif.summary ? notif.summary.toString() : "Notification";
            let bodyText = notif.body ? notif.body.toString() : "";
            let timeStr = Qt.formatTime(new Date(), "hh:mm");
            let nId = notif.id;
            let dEntry = notif.desktopEntry ? notif.desktopEntry.toString() : "";

            let timeoutMs = root.defaultToastTimeout;
            if (notif.urgency === NotificationUrgency.Critical) {
                timeoutMs = 0;
            } else if (notif.expireTimeout > 0) {
                timeoutMs = notif.expireTimeout * 1000;
            }

            notifHistoryModel.insert(0, {
                "notifId": nId,
                "summary": summaryText,
                "body": bodyText,
                "time": timeStr,
                "appName": dEntry
            });

            if (!root.dndEnabled) {
                activeToastModel.insert(0, {
                    "notifId": nId,
                    "summary": summaryText,
                    "body": bodyText,
                    "appName": dEntry,
                    "timeoutMs": timeoutMs
                });
            }
        }
    }

    function findNotification(nId) {
        let tracked = notifServer.trackedNotifications.values;
        for (let i = 0; i < tracked.length; i++) {
            if (tracked[i].id == nId) return tracked[i];
        }
        return null;
    }

    function removeFromModel(model, nId) {
        for (let i = 0; i < model.count; i++) {
            if (model.get(i).notifId == nId) {
                model.remove(i);
                return;
            }
        }
    }

    Connections {
        target: notifServer.trackedNotifications
        function onObjectRemovedPost(object, index) {
            root.removeFromModel(notifHistoryModel, object.id);
            root.removeFromModel(activeToastModel, object.id);
        }
    }

    function triggerAction(nId, appName) {
        let actionFired = false;
        let n = root.findNotification(nId);
        
        if (n) {
            let chosen = null;
            for (let j = 0; j < n.actions.length; j++) {
                if (n.actions[j].identifier === "default") {
                    chosen = n.actions[j];
                    break;
                }
            }
            if (!chosen && n.actions.length > 0) chosen = n.actions[0];
            if (chosen) {
                chosen.invoke();
                actionFired = true;
            } else {
                n.dismiss();
            }
        }

        if (!actionFired && appName && appName !== "") {
            let cleanName = appName.replace(".desktop", "");
            appLaunchProc.exec([
                "hyprctl", "dispatch", "focuswindow", `class:(?i)${cleanName}`
            ]);
        }
    }

    function activateNotification(nId) {
        let appName = "";
        for (let i = 0; i < notifHistoryModel.count; i++) {
            if (notifHistoryModel.get(i).notifId == nId) {
                appName = notifHistoryModel.get(i).appName;
                break;
            }
        }
        root.removeFromModel(activeToastModel, nId);
        root.removeFromModel(notifHistoryModel, nId);
        root.triggerAction(nId, appName);
    }

    function executeToastAction(nId) {
        root.activateNotification(nId);
    }

    function executeNotification(nId) {
        root.activateNotification(nId);
        root.showControlCenter = false;
    }

    function dismissToast(nId) {
        root.removeFromModel(activeToastModel, nId);
    }

    function removeNotification(nId) {
        let n = root.findNotification(nId);
        if (n) n.dismiss();
        root.removeFromModel(notifHistoryModel, nId);
        root.removeFromModel(activeToastModel, nId);
    }

    function clearAllNotifications() {
        for (let i = 0; i < notifHistoryModel.count; i++) {
            let n = root.findNotification(notifHistoryModel.get(i).notifId);
            if (n) n.dismiss();
        }
        notifHistoryModel.clear();
        activeToastModel.clear();
    }

    TopBar {
        id: topBar
        rootState: root
    }

    PanelWindow {
        id: dismissBackdrop
        visible: root.animVisible
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true; }
        MouseArea {
            anchors.fill: parent
            onClicked: root.showControlCenter = false
        }
    }

    ControlCenter {
        id: controlCenter
        rootState: root
        topBarWindow: topBar
        historyModel: notifHistoryModel
    }

    NotificationToasts {
        id: notificationToasts
        rootState: root
        toastModel: activeToastModel
    }
}

```

### 2. Control Center Component (`~/.config/quickshell/ControlCenter.qml`)



```qml
import QtQuick
import QtQuick.Controls
import Quickshell
import "components"

PopupWindow {
    id: ccWindow
    
    required property var rootState
    required property var topBarWindow
    required property var historyModel

    anchor.window: topBarWindow
    anchor.rect.x: topBarWindow.width - implicitWidth
    anchor.rect.y: topBarWindow.height + 10
    
    implicitWidth: 550
    implicitHeight: 580
    visible: rootState.animVisible
    color: "transparent"

    Rectangle {
        id: popupContainer
        anchors.fill: parent
        color: "#2e3440"
        radius: 16
        border.color: Qt.rgba(0.50, 0.63, 0.75, 0.3)
        border.width: 1

        opacity: 0.0
        y: -15

        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: popupContainer; property: "opacity"; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: popupContainer; property: "y"; to: 0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
        }

        ParallelAnimation {
            id: exitAnim
            NumberAnimation { target: popupContainer; property: "opacity"; to: 0.0; duration: 140; easing.type: Easing.InQuad }
            NumberAnimation { target: popupContainer; property: "y"; to: -15; duration: 140; easing.type: Easing.InQuad }
            onFinished: rootState.animVisible = false
        }

        Connections {
            target: rootState
            function onShowControlCenterChanged() {
                if (rootState.showControlCenter) {
                    exitAnim.stop();
                    rootState.animVisible = true;
                    enterAnim.restart();
                } else {
                    enterAnim.stop();
                    exitAnim.restart();
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Column {
                spacing: 4
                Text { text: "Control Center"; color: "#eceff4"; font.pixelSize: 18; font.bold: true; font.family: "GoogleSansM Nerd Font" }
                Text { text: "Focused system controls"; color: "#d8dee9"; font.pixelSize: 13; font.family: "GoogleSansM Nerd Font" }
            }
            
            Row {
                spacing: 15
                
                Column {
                    spacing: 15
                    
                    SliderCard {
                        icon: rootState.volumeMuted ? "󰝟" : (rootState.volumeLevel < 0.5 ? "" : "")
                        iconColor: "#81a1c1"
                        title: "Output volume"
                        value: rootState.volumeLevel
                        onValueChangedByUser: val => rootState.setVolume(val)
                        onRightClicked: rootState.openAudioSettings()
                    }

                    SliderCard {
                        icon: "󰃠"
                        iconColor: "#b48ead"
                        title: "Display brightness"
                        value: rootState.brightnessLevel
                        onValueChangedByUser: val => rootState.setBrightness(val)
                    }
                }

                Grid {
                    columns: 2
                    spacing: 15
                    
                    QuickToggle {
                        icon: rootState.wifiIcon
                        title: rootState.wifiSsid !== "" ? (rootState.wifiSsid.length > 8 ? rootState.wifiSsid.substring(0, 7) + "…" : rootState.wifiSsid) : "Wi-Fi"
                        active: rootState.wifiEnabled
                        onToggled: rootState.toggleWifi()
                        onRightClicked: rootState.openWifiSettings()
                    }

                    QuickToggle {
                        icon: rootState.bluetoothEnabled ? "󰂯" : "󰂲"
                        title: "Bluetooth"
                        active: rootState.bluetoothEnabled
                        onToggled: rootState.toggleBluetooth()
                        onRightClicked: rootState.openBluetoothSettings()
                    }

                    QuickToggle {
                        icon: rootState.micMuted ? "" : ""
                        title: rootState.micMuted ? "Muted" : "Mic On"
                        active: rootState.micMuted
                        activeColor: "#bf616a"
                        onToggled: rootState.toggleMic()
                    }

                    QuickToggle {
                        icon: rootState.dndEnabled ? "󰂛" : "󰂚"
                        title: "DND"
                        active: rootState.dndEnabled
                        activeColor: "#ebcb8b"
                        onToggled: rootState.dndEnabled = !rootState.dndEnabled
                    }
                }
            }

            Row {
                spacing: 15
                
                Repeater {
                    model: [
                        { id: "power-saver", name: "  Power saver" },
                        { id: "balanced",    name: "  Balanced" },
                        { id: "performance", name: "  Performance" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: 160
                        height: 40
                        radius: 10
                        color: rootState.activeProfile === modelData.id ? "#81a1c1" : "transparent"
                        border.color: rootState.activeProfile === modelData.id ? "#81a1c1" : "#4c566a"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: rootState.activeProfile === modelData.id ? "#2e3440" : "#d8dee9"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "GoogleSansM Nerd Font"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootState.setPowerProfile(modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(0.50, 0.63, 0.75, 0.2)
            }

            Item {
                width: parent.width
                height: 20

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: `Notifications (${ccWindow.historyModel.count})`
                    color: "#eceff4"
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "GoogleSansM Nerd Font"
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ccWindow.historyModel.count > 0
                    text: "Clear All"
                    color: "#81a1c1"
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "GoogleSansM Nerd Font"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootState.clearAllNotifications()
                    }
                }
            }

            ListView {
                id: historyListView
                width: parent.width
                height: 120
                clip: true
                spacing: 8
                model: ccWindow.historyModel

                delegate: Rectangle {
                    width: historyListView.width
                    height: 52
                    radius: 10
                    color: "#3b4252"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootState.executeNotification(model.notifId)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Text {
                            text: "󰂚"
                            color: "#81a1c1"
                            font.pixelSize: 16
                            font.family: "GoogleSansM Nerd Font"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - 70
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Row {
                                spacing: 8
                                Text {
                                    text: model.summary || ""
                                    textFormat: Text.PlainText
                                    color: "#eceff4"
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "GoogleSansM Nerd Font"
                                    elide: Text.ElideRight
                                    width: 320
                                }
                                Text {
                                    text: model.time || ""
                                    color: "#4c566a"
                                    font.pixelSize: 10
                                    font.family: "GoogleSansM Nerd Font"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                text: model.body || ""
                                textFormat: Text.PlainText
                                color: "#d8dee9"
                                font.pixelSize: 11
                                font.family: "GoogleSansM Nerd Font"
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        Text {
                            text: "󰅖"
                            color: "#4c566a"
                            font.pixelSize: 14
                            font.family: "GoogleSansM Nerd Font"
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                propagateComposedEvents: false
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    rootState.removeNotification(model.notifId);
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: ccWindow.historyModel.count === 0
                    anchors.centerIn: parent
                    text: "No notifications"
                    color: "#4c566a"
                    font.pixelSize: 13
                    font.family: "GoogleSansM Nerd Font"
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(0.50, 0.63, 0.75, 0.2)
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 30

                Repeater {
                    model: [
                        { icon: "󰌾", action: "pidof hyprlock || hyprlock", color: "#eceff4" },
                        { icon: "󰒲", action: "systemctl suspend", color: "#eceff4" },
                        { icon: "󰍃", action: "uwsm stop", color: "#eceff4" },
                        { icon: "󰑐", action: "systemctl reboot", color: "#eceff4" },
                        { icon: "󰐥", action: "systemctl poweroff", color: "#bf616a" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: 44
                        height: 44
                        radius: 22
                        color: hoverArea.containsMouse ? "#434c5e" : "transparent"
                        
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: modelData.color
                            font.pixelSize: 22
                            font.family: "GoogleSansM Nerd Font"
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                rootState.showControlCenter = false;
                                rootState.runSystemCommand(modelData.action);
                            }
                        }
                    }
                }
            }
        }
    }
}

```

### 3. Notification Toasts (`~/.config/quickshell/NotificationToasts.qml`)



```qml
import QtQuick
import Quickshell

PanelWindow {
    id: toastWindow
    
    required property var rootState
    required property var toastModel

    anchors {
        top: true
        right: true
    }
    margins {
        top: 54
        right: 20
    }
    
    implicitWidth: 360
    implicitHeight: toastCol.implicitHeight + 10
    color: "transparent"
    
    visible: toastModel.count > 0 && !rootState.dndEnabled

    Column {
        id: toastCol
        spacing: 10
        width: parent.width

        Repeater {
            model: toastModel

            delegate: Rectangle {
                id: toastCard
                required property int index
                required property var model

                width: toastCol.width
                height: contentCol.implicitHeight + 24
                radius: 12
                color: "#2e3440"
                border.color: Qt.rgba(0.50, 0.63, 0.75, 0.4)
                border.width: 1

                Timer {
                    interval: toastCard.model.timeoutMs
                    running: toastCard.model.timeoutMs > 0
                    onTriggered: toastWindow.rootState.dismissToast(toastCard.model.notifId)
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 8
                        color: "#3b4252"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰂚"
                            color: "#81a1c1"
                            font.pixelSize: 18
                            font.family: "GoogleSansM Nerd Font"
                        }
                    }

                    Column {
                        id: contentCol
                        width: parent.width - 48
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: toastCard.model.summary || ""
                            color: "#eceff4"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "GoogleSansM Nerd Font"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: toastCard.model.body || ""
                            color: "#d8dee9"
                            font.pixelSize: 12
                            font.family: "GoogleSansM Nerd Font"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toastWindow.rootState.executeToastAction(toastCard.model.notifId)
                }
            }
        }
    }
}

```

### 4. Top Bar Component (`~/.config/quickshell/TopBar.qml`)



```qml
import QtQuick
import Quickshell
import Quickshell.Hyprland

PanelWindow {
    id: topBarRoot
    
    required property var rootState

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 4
        left: 10
        right: 10
    }
    
    implicitHeight: 36
    color: "transparent"
    exclusiveZone: 40 

    Rectangle {
        anchors.fill: parent
        color: "#2e3440" 
        radius: 10
        border.color: Qt.rgba(0.50, 0.63, 0.75, 0.3)
        border.width: 0

        Row {
            anchors {
                left: parent.left
                leftMargin: 18
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Repeater {
                model: [1, 2, 3, 4, 5]

                delegate: Rectangle {
                    required property int modelData
                    readonly property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData
                    readonly property bool exists: {
                        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                            if (Hyprland.workspaces.values[i].id === modelData) return true;
                        }
                        return false;
                    }

                    width: isFocused ? 20 : 8
                    height: 8
                    radius: 4
                    color: isFocused ? "#81a1c1" : (exists ? "#d8dee9" : "#4c566a")

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 180 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`workspace ${modelData}`)
                    }
                }
            }
        }

        Text {
            id: clockText
            anchors.centerIn: parent
            color: "#eceff4"
            font.pixelSize: 15
            font.bold: true
            font.family: "GoogleSansM Nerd Font"
            text: Qt.formatDateTime(clock.date, "hh:mm | ddd, MMM d")
            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }
        }

        Row {
            anchors {
                right: parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 15

            Text {
                visible: rootState.dndEnabled
                text: "󰂛"
                color: "#ebcb8b"
                font.pixelSize: 14
                font.family: "GoogleSansM Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text { 
                text: `${rootState.volumeMuted ? "󰝟" : ""} ${Math.round(rootState.volumeLevel * 100)}%`
                color: rootState.volumeMuted ? "#4c566a" : "#eceff4"
                font.pixelSize: 14
                font.family: "GoogleSansM Nerd Font"
                anchors.verticalCenter: parent.verticalCenter 
            }

            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter

                Text { 
                    text: rootState.wifiIcon
                    color: rootState.wifiEnabled ? "#eceff4" : "#4c566a"
                    font.pixelSize: 14
                    font.family: "GoogleSansM Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter 
                }

                Text {
                    visible: rootState.wifiEnabled && rootState.wifiSsid !== ""
                    text: `${rootState.wifiSsid} ${rootState.wifiSignal}%`
                    color: "#eceff4"
                    font.pixelSize: 13
                    font.family: "GoogleSansM Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text { 
                text: `${rootState.batteryIcon} ${rootState.batteryPercentage}%`
                color: rootState.batteryPercentage <= 20 && !rootState.batteryCharging ? "#bf616a" : (rootState.batteryCharging ? "#a3be8c" : "#eceff4")
                font.pixelSize: 14
                font.family: "GoogleSansM Nerd Font"
                anchors.verticalCenter: parent.verticalCenter 
            }
            
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: rootState.showControlCenter || toggleArea.containsMouse ? "#434c5e" : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    anchors.centerIn: parent
                    text: rootState.showControlCenter ? "" : ""
                    color: "#81a1c1"
                    font.pixelSize: 18
                    font.family: "GoogleSansM Nerd Font"
                }
                
                MouseArea {
                    id: toggleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rootState.showControlCenter = !rootState.showControlCenter
                }
            }
        }
    }
}

```

### 5. Components (`~/.config/quickshell/components/`)



**QuickToggle.qml**

```qml
import QtQuick

Rectangle {
    id: toggleRoot
    
    property string icon: ""
    property string title: ""
    property bool active: false
    property color activeColor: "#81a1c1"
    
    signal toggled()
    signal rightClicked()

    width: 115
    height: 75
    radius: 12
    color: active ? "#434c5e" : "#3b4252"
    border.color: active ? activeColor : "transparent"
    border.width: 1

    Column { 
        anchors.centerIn: parent
        spacing: 4

        Text { 
            text: toggleRoot.icon
            color: toggleRoot.active ? toggleRoot.activeColor : "#d8dee9"
            font.pixelSize: 20
            font.family: "GoogleSansM Nerd Font"
            anchors.horizontalCenter: parent.horizontalCenter 
        }

        Text { 
            text: toggleRoot.title
            color: "#eceff4"
            font.pixelSize: 13
            font.bold: true
            font.family: "GoogleSansM Nerd Font"
            anchors.horizontalCenter: parent.horizontalCenter 
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                toggleRoot.rightClicked();
            } else {
                toggleRoot.toggled();
            }
        }
    }
}

```

**SliderCard.qml**

```qml
import QtQuick

Rectangle {
    id: sliderRoot
    
    property string icon: ""
    property color iconColor: "#81a1c1"
    property string title: ""
    property real value: 0.0
    
    signal valueChangedByUser(real newValue)
    signal rightClicked()

    width: 240
    height: 75
    radius: 12
    color: "#3b4252"

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: sliderRoot.rightClicked()
    }

    Text { 
        text: sliderRoot.icon
        color: sliderRoot.iconColor
        font.pixelSize: 22
        font.family: "GoogleSansM Nerd Font"
        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter 
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 52
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text { 
            text: sliderRoot.title
            color: "#eceff4"
            font.pixelSize: 13
            font.bold: true
            font.family: "GoogleSansM Nerd Font" 
        }

        Rectangle {
            id: track
            width: 165
            height: 8
            radius: 4
            color: "#4c566a"

            Rectangle { 
                width: parent.width * sliderRoot.value
                height: parent.height
                radius: 4
                color: sliderRoot.iconColor 
            }

            MouseArea {
                id: hitArea
                anchors.fill: parent
                anchors.margins: -hitArea.hitMargin
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                readonly property int hitMargin: 6

                function fraction(x) {
                    return Math.min(Math.max((x - hitArea.hitMargin) / track.width, 0.0), 1.0);
                }

                onPositionChanged: mouse => {
                    if (pressed && (mouse.buttons & Qt.LeftButton)) {
                        sliderRoot.valueChangedByUser(hitArea.fraction(mouse.x));
                    }
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        sliderRoot.rightClicked();
                    } else {
                        sliderRoot.valueChangedByUser(hitArea.fraction(mouse.x));
                    }
                }
            }
        }
    }

    Text { 
        text: `${Math.round(sliderRoot.value * 100)}%`
        color: "#d8dee9"
        font.pixelSize: 12
        anchors.right: parent.right
        anchors.rightMargin: 15
        anchors.top: parent.top
        anchors.topMargin: 15
        font.family: "GoogleSansM Nerd Font" 
    }
}

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
```[cite: 2]

```
