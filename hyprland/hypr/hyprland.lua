--------------------------------------------------------------------------------
-- HYPRLAND CONFIGURATION (LUA)
--------------------------------------------------------------------------------

-- 1. Define Laptop Panel Settings (Single Source of Truth)
local eDP1_config = {
	output        = "eDP-1",
	mode          = "2560x1600@60",
	position      = "0x1440",
	scale         = "1.25",
	bitdepth      = 10,
	cm            = "hdr",
	sdrbrightness = 1.2,
	sdrsaturation = 0.98,
}

-- 2. Read hardware states from the Linux kernel
-- Read physical lid state
local handle_lid = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
local lid_state = handle_lid:read("*a") or ""
handle_lid:close()

-- Read external monitor connection state directly from the DRM subsystem
local handle_dp = io.popen("cat /sys/class/drm/card*-DP-*/status 2>/dev/null | grep -w 'connected'")
local dp_state = handle_dp:read("*a") or ""
handle_dp:close()

local is_closed = string.find(string.lower(lid_state), "closed")

-- 3. Dynamically configure eDP-1 based on both variables
if is_closed then
	-- True Clamshell: Lid is shut AND external monitor is present
	hl.monitor({
		output   = eDP1_config.output,
		disabled = true,
	})
else
	-- Mobile or Open: Ensure the laptop screen stays on to prevent zero-monitor segfaults
	hl.monitor(eDP1_config)
end

-- External Samsung OLED (Always On)
hl.monitor({
	output        = "DP-1",
	mode          = "highres@highrr",
	position      = "0x0",
	scale         = "1.0",
	bitdepth      = 10,
	cm            = "hdr",
	sdrbrightness = 1.2,
	sdrsaturation = 0.98,
})

-- Default Applications & Variables
local terminal    = "uwsm app -- alacritty"
local menu        = "walker"
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
	-- 0. Force keyring daemon
	hl.exec_cmd("gnome-keyring-daemon --start --components=pkcs11,secrets,ssh")

	-- 1. Sync authentication and display environments to D-Bus and systemd
	hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SSH_AUTH_SOCK")
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SSH_AUTH_SOCK")

	-- 2. Core daemons
	hl.exec_cmd("systemctl --user start hypridle.service")
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
	hl.exec_cmd("systemctl --user start hyprsunset.service")
	hl.exec_cmd("uwsm app -- quickshell")

	-- Start Walker's backend and frontend daemon
	hl.exec_cmd("uwsm app -- elephant")
	hl.exec_cmd("uwsm app -- walker --gapplication-service")

	-- 3. Background apps
	hl.exec_cmd("uwsm app -- hyprpaper")
	hl.exec_cmd("uwsm app -- nm-applet --indicator")
	hl.exec_cmd("uwsm app -- blueman-applet")

	-- 4. GTK Theme Properties
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
		-- col              = {
		-- 	active_border   = { colors = { "#81a1c1", "#2e3440" }, angle = 45 },
		-- 	inactive_border = "#2e3440",
		-- },
		layout           = "dwindle",
		resize_on_border = true, -- Enables mouse-dragging on inner split borders
		allow_tearing    = false,
	},

	cursor = {
		no_warps = true,
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
		focus_on_activate               = true,
		disable_hyprland_logo           = true,
		disable_hyprland_guiutils_check = false,
		disable_splash_rendering        = true,
	},

	input = {
		kb_layout    = "us",
		follow_mouse = 0,
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
	-- { mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock") },

	-- Graceful session termination via UWSM
	-- { mainMod .. " + M",         hl.dsp.exec_cmd("uwsm stop") },
	--
	-- Media Capture
	{ mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh") },
	{ mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh") },
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

-- Floating Window Movement (SUPER + ALT + Arrow Keys)
local floatStep = 50
local float_move_binds = {
	{ mainMod .. " + ALT + right", hl.dsp.window.move({ x = floatStep, y = 0, relative = true }) },
	{ mainMod .. " + ALT + left",  hl.dsp.window.move({ x = -floatStep, y = 0, relative = true }) },
	{ mainMod .. " + ALT + up",    hl.dsp.window.move({ x = 0, y = -floatStep, relative = true }) },
	{ mainMod .. " + ALT + down",  hl.dsp.window.move({ x = 0, y = floatStep, relative = true }) },
}

for _, b in ipairs(float_move_binds) do
	-- 'repeating = true' allows holding the key down for smooth gliding
	hl.bind(b[1], b[2], { repeating = true })
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

-- Clamshell Mode (Smart Hardware Listener)
-- Construct the wake command dynamically and explicitly unset the disabled flag
-- local wake_eDP1_cmd = string.format(
-- 	[[hyprctl eval 'hl.monitor({output="%s", mode="%s", position="%s", scale="%s", bitdepth=%d, cm="%s", disabled=false})']],
-- 	eDP1_config.output, eDP1_config.mode, eDP1_config.position, eDP1_config.scale, eDP1_config.bitdepth, eDP1_config.cm
-- )

-- Safe Hardware Clamshell Listener
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
