-- BxRig starter Hyprland config (Hyprland 0.55+, Lua). Written once by `bxrig setup hyprland`; from here on it is yours.
-- Based on Hyprland's own example config. Reference: https://wiki.hypr.land/configuring/
-- The managed part (Noctalia autostart, every key binding) lives in bxrig.lua, loaded at the bottom.

------------------
---- MONITORS ----
------------------
-- BXRIG-MONITORS
-- Any other screen. Change a scale with: bxrig display scale NAME 1.5 --yes   (1 to 2; list screens with: bxrig display list)
hl.monitor({
	output   = "",
	mode     = "preferred",
	position = "auto",
	scale    = "auto",
})

---------------------
---- MY PROGRAMS ----
---------------------
local terminal    = "kitty"
local browser     = "brave"
local fileManager = "dolphin"

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
	general = {
		gaps_in     = 5,
		gaps_out    = 12,
		border_size = 2,
		col = {
			-- BoxLang green to cyan on the focused window
			active_border   = { colors = {"rgba(00ff78ee)", "rgba(00dbffee)"}, angle = 45 },
			inactive_border = "rgba(626880aa)",
		},
		resize_on_border = true,
		allow_tearing    = false,
		layout           = "dwindle",
	},

	decoration = {
		rounding       = 14,
		rounding_power = 2,
		active_opacity   = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled      = true,
			range        = 4,
			render_power = 3,
			color        = 0xee1a1a1a,
		},
		blur = {
			enabled  = true,
			xray     = true,
			size     = 3,
			passes   = 2,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},
})

-- Animations from the Hyprland defaults
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- BXRIG-WORKSPACES

hl.config({ dwindle   = { preserve_split = true } })
hl.config({ master    = { new_status = "master" } })
hl.config({ scrolling = { fullscreen_on_one_column = true } })

hl.config({
	misc = {
		force_default_wallpaper = 0,    -- Noctalia draws the wallpaper
		disable_hyprland_logo   = true,
	},
})

hl.config({
	layers = {
		allow_new_top_layers_over_existing_fullscreen = true,
	},
})

---------------
---- INPUT ----
---------------
hl.config({
	input = {
		kb_layout    = "us",
		follow_mouse = 1,
		sensitivity  = 0,
		touchpad = {
			natural_scroll = false,   -- true gives the macOS direction
			tap_to_click   = true,
		},
	},
})

hl.gesture({
	fingers   = 3,
	direction = "horizontal",
	action    = "workspace",
})

---------------------
---- KEYBINDINGS ----
---------------------
-- Every key (windows, workspaces, arrows, mouse, volume, screenshots, the menu) is a row of the BxRig shortcut table, in bxrig.lua below.
-- See them with `bxrig keys show`, change one with `bxrig keys set ID KEYS --yes`, check clashes with `bxrig keys conflicts`.
-- Keys you add here are yours; `bxrig keys conflicts` tells you when one is also used by the table.

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
-- BXRIG-FLOATING-RULE
hl.window_rule({
	name  = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name  = "fix-xwayland-drags",
	match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
	no_focus = true,
})

------------------------
---- BXRIG MODULE ----
------------------------
-- Noctalia autostart and every key binding. Managed by `bxrig keys apply`. It reads the programs chosen above.
BXRIG_PROGRAMS = { terminal = terminal, browser = browser, fileManager = fileManager }
require("bxrig")
