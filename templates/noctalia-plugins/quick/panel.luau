--!nonstrict
-- BxRig Quick settings, page 1: switches and pickers. A popover from the bar widget.
--
-- Every control runs a bxrig command with --yes through noctalia.runAsync (argument array, no shell) and shows the command's first output
-- line as the result at the bottom. The current values are read on every open:
--   theme status --json                       data.mode (theme | dark | light | auto), data.name
--   notify dnd status --json                  data.output ("on" | "off")
--   appearance dock status --json             data.dock
--   appearance appgrid status --json          data.appgrid
--   appearance bar layout status --json       data.layout
--   appearance battery-percent status --json  data.battery_percent, data.battery_found (the row is shown on a laptop only)
--   time format status --json                 data.format
--   accessibility zoom status --json          data.zoom ("on" | "off")
-- Writes: toggle stay-awake on|off, notify dnd on|off, theme mode MODE, appearance dock on|off, appearance appgrid launchpad|terminal,
--   appearance bar layout minimal|standard|dense, appearance battery-percent on|off, time format FORMAT, accessibility zoom on|off.
-- Caffeine: Noctalia has IPC to switch it (`noctalia msg caffeine-enable|disable|toggle`, which `bxrig toggle stay-awake` runs) but no
-- command that reports its state, so the switch shows what this panel last set (kept in noctalia.state until the shell restarts).
-- Night light is not a command here: it lives in the control center Home tile, so a button opens that tab.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")

local PRESETS = {
	{ id = "short", label = "Nov 5 - 04:00", format = "%b %-d - %H:%M" },
	{ id = "time", label = "04:00", format = "%H:%M" },
	{ id = "ampm", label = "04:00 AM", format = "%I:%M %p" },
	{ id = "iso", label = "ISO", format = "%Y-%m-%d %H:%M" },
}

local MODES = {
	{ id = "theme", label = "Theme" },
	{ id = "dark", label = "Dark" },
	{ id = "light", label = "Light" },
	{ id = "auto", label = "Auto" },
}

local GRIDS = {
	{ id = "launchpad", label = "Launchpad" },
	{ id = "terminal", label = "Terminal" },
}

local LAYOUTS = {
	{ id = "minimal", label = "Minimal" },
	{ id = "standard", label = "Standard" },
	{ id = "dense", label = "Dense" },
}

local S = {} -- the values read from bxrig; nil means unknown (not read yet, or the read failed)
local loaded = false
local busy = nil -- label of the command that is running
local status = nil -- { text, ok } of the last command or read

local function str(v)
	if v == nil then
		return ""
	end
	return tostring(v)
end

local function caffeineOn()
	return noctalia.state.get("caffeine") == true
end

local function presetFor(format)
	for _, p in ipairs(PRESETS) do
		if p.format == format then
			return p.id
		end
	end
	return nil
end

local render

local function fail(label, err)
	status = { text = label .. ": " .. str(err), ok = false }
end

-- Reads one value: key into S through pick(data), then redraws.
local function read(label, args, pick)
	bxrig.json(args, function(data, err)
		if err ~= nil then
			fail(label, err)
		else
			pick(data)
		end
		render()
	end)
end

local function fetchAll()
	read("Theme", { "theme", "status", "--json" }, function(d)
		S.mode = d.mode
		S.theme = d.name
	end)
	read("Do Not Disturb", { "notify", "dnd", "status", "--json" }, function(d)
		S.dnd = str(d.output) == "on"
	end)
	read("Dock", { "appearance", "dock", "status", "--json" }, function(d)
		S.dock = d.dock == "on"
	end)
	read("App grid", { "appearance", "appgrid", "status", "--json" }, function(d)
		S.appgrid = d.appgrid
	end)
	read("Top bar layout", { "appearance", "bar", "layout", "status", "--json" }, function(d)
		S.layout = d.layout
	end)
	read("Battery percentage", { "appearance", "battery-percent", "status", "--json" }, function(d)
		S.percent = d.battery_percent == "on"
		S.laptop = d.battery_found == true
	end)
	read("Clock format", { "time", "format", "status", "--json" }, function(d)
		S.format = d.format
	end)
	read("Zoom", { "accessibility", "zoom", "status", "--json" }, function(d)
		S.zoom = d.zoom == "on"
	end)
end

-- Runs `bxrig <args> --yes`; onOk() updates the local value when it worked. A failed command reads everything again, so the panel shows the truth.
local function apply(label, args, onOk)
	if busy ~= nil then
		return
	end
	busy = label
	status = nil
	render()
	local argv = {}
	for _, a in ipairs(args) do
		table.insert(argv, a)
	end
	table.insert(argv, "--yes")
	bxrig.run(argv, function(ok, message)
		busy = nil
		if ok then
			onOk()
			status = { text = label .. ": " .. (message ~= "" and message or "done"), ok = true }
		else
			fail(label, message ~= "" and message or "failed")
			fetchAll()
		end
		render()
	end, 60000)
end

-- ---- drawing helpers ----

local function section(title, children)
	local kids = { ui.label({ text = string.upper(title), fontSize = 11, fontWeight = "bold", color = "on_surface_variant" }) }
	for _, c in ipairs(children) do
		table.insert(kids, c)
	end
	return ui.column({ gap = 6 }, kids)
end

local function titleBlock(title, sub)
	return ui.column({ flexGrow = 1, gap = 1 }, {
		ui.label({ text = title, fontSize = 13, fontWeight = "semibold", maxLines = 1 }),
		ui.label({ text = sub, fontSize = 11, color = "on_surface_variant", maxLines = 2 }),
	})
end

local function switchRow(key, glyph, title, sub, checked, onChange)
	return ui.row({ key = key, align = "center", gap = 10 }, {
		ui.glyph({ name = glyph, size = 20, color = checked == true and "primary" or "on_surface_variant" }),
		titleBlock(title, sub),
		ui.toggle({ checked = checked == true, enabled = loaded and busy == nil, onChange = onChange }),
	})
end

-- A row of buttons, one per option, the current one filled. perRow splits a long list over several rows.
local function picker(key, options, current, perRow, onPick)
	local rows = {}
	local row = {}
	local function flush()
		if #row > 0 then
			table.insert(rows, ui.row({ gap = 4 }, row))
			row = {}
		end
	end
	for _, opt in ipairs(options) do
		local on = current == opt.id
		table.insert(row, ui.button({
			key = key .. "-" .. opt.id,
			text = opt.label,
			variant = on and "primary" or "outline",
			selected = on,
			controlSize = "sm",
			flexGrow = 1,
			enabled = loaded and busy == nil,
			onClick = function()
				if not on then
					onPick(opt)
				end
			end,
		}))
		if #row >= perRow then
			flush()
		end
	end
	flush()
	return ui.column({ gap = 4 }, rows)
end

local function linkRow(key, glyph, title, sub, onClick)
	return ui.row({ key = key, align = "center", gap = 10, paddingH = 8, paddingV = 8, radius = 8, fill = "on_surface/0.06", onClick = onClick }, {
		ui.glyph({ name = glyph, size = 20, color = "tertiary" }),
		titleBlock(title, sub),
		ui.glyph({ name = "chevron-right", size = 16, color = "on_surface_variant" }),
	})
end

-- ---- Share Wi-Fi ----
local wifiQr = nil
local wifiQrStamp = 0
local wifiQrBusy = false
local wifiQrError = nil

-- bxrig writes the QR code of the Wi-Fi you are on to a file in the cache (`bxrig wifi qr --out=FILE`); the panel shows it. Again hides it.
local function shareWifi()
	if wifiQr ~= nil then
		wifiQr = nil
		render()
		return
	end
	local path = noctalia.expandPath("~/.cache/bxrig/wifi-qr.png")
	wifiQrBusy = true
	wifiQrError = nil
	bxrig.run({ "wifi", "qr", "--out=" .. path }, function(ok, msg)
		wifiQrBusy = false
		if ok then
			wifiQr = path
			wifiQrStamp = noctalia.nowMs()
		else
			wifiQrError = msg ~= "" and msg or "Could not make the code"
		end
		render()
	end, 30000)
	render()
end

render = function()
	local items = {}
	-- on top: Share Wi-Fi (the QR code of the network you are on, shown here) and the BxRig Control Center (`bxrig tui` in a terminal)
	table.insert(items, ui.row({ key = "top-actions", gap = 6 }, {
		ui.button({ glyph = "qrcode", text = wifiQr ~= nil and "Hide code" or "Share Wi-Fi", variant = "primary", flexGrow = 1,
			enabled = not wifiQrBusy, onClick = shareWifi }),
		ui.button({ glyph = "layout-dashboard", text = "Control Center", variant = "outline", flexGrow = 1,
			onClick = function()
				-- a shell string: the executable may be a path, so it is quoted
				noctalia.runInTerminal("'" .. bxrig.command() .. "' tui")
				panel.close()
			end }),
	}))
	if wifiQr ~= nil then
		table.insert(items, ui.column({ key = "wifi-qr", align = "center", gap = 6, paddingV = 6 }, {
			ui.image({ key = "qr-" .. wifiQrStamp, path = wifiQr, fit = "contain", radius = 10, height = 220 }),
			ui.label({ text = "Point a phone camera at the code to join", fontSize = 11, color = "on_surface_variant" }),
		}))
	end
	if wifiQrError ~= nil then
		table.insert(items, ui.label({ key = "wifi-qr-error", text = wifiQrError, fontSize = 11, color = "error", maxLines = 3 }))
	end

	-- Switches.
	table.insert(items, switchRow("caffeine", "coffee", "Caffeine", "Keeps the screen awake. Noctalia cannot report it, so this shows what you last set here.", caffeineOn(), function(v)
		local want = v == "true"
		apply("Caffeine", { "toggle", "stay-awake", want and "on" or "off" }, function()
			noctalia.state.set("caffeine", want)
		end)
	end))
	table.insert(items, switchRow("dnd", "bell-off", "Do Not Disturb", "Hides notification popups.", S.dnd, function(v)
		local want = v == "true"
		apply("Do Not Disturb", { "notify", "dnd", want and "on" or "off" }, function()
			S.dnd = want
		end)
	end))
	table.insert(items, switchRow("dock", "layout-bottombar", "Dock", "The dock holds your apps; the Launchpad grid is its first button.", S.dock, function(v)
		local want = v == "true"
		apply("Dock", { "appearance", "dock", want and "on" or "off" }, function()
			S.dock = want
		end)
	end))
	table.insert(items, switchRow("zoom", "zoom-in", "Zoom", "Option+Cmd+8 zooms in and out, Option+Cmd+= and - change how much.", S.zoom, function(v)
		local want = v == "true"
		apply("Zoom", { "accessibility", "zoom", want and "on" or "off" }, function()
			S.zoom = want
		end)
	end))
	if S.laptop == true then
		table.insert(items, switchRow("percent", "battery-charging", "Battery percentage", "Shows the charge next to the battery icon.", S.percent, function(v)
			local want = v == "true"
			apply("Battery percentage", { "appearance", "battery-percent", want and "on" or "off" }, function()
				S.percent = want
			end)
		end))
	end

	table.insert(items, ui.separator({}))

	-- Pickers.
	table.insert(items, section("Dark or light", {
		picker("mode", MODES, S.mode, 4, function(opt)
			apply("Theme mode", { "theme", "mode", opt.id }, function()
				S.mode = opt.id
			end)
		end),
	}))
	table.insert(items, section("Top bar layout", {
		picker("layout", LAYOUTS, S.layout, 3, function(opt)
			apply("Top bar layout", { "appearance", "bar", "layout", opt.id }, function()
				S.layout = opt.id
			end)
		end),
	}))
	table.insert(items, section("App grid style", {
		picker("grid", GRIDS, S.appgrid, 2, function(opt)
			apply("App grid style", { "appearance", "appgrid", opt.id }, function()
				S.appgrid = opt.id
			end)
		end),
	}))
	local clockChildren = {
		picker("clock", PRESETS, S.format ~= nil and presetFor(S.format) or nil, 2, function(opt)
			apply("Clock format", { "time", "format", opt.format }, function()
				S.format = opt.format
			end)
		end),
	}
	if S.format ~= nil and presetFor(S.format) == nil then
		table.insert(clockChildren, ui.label({ text = "Custom format: " .. S.format .. "  (bxrig time format)", fontSize = 11, color = "on_surface_variant", maxLines = 2 }))
	end
	table.insert(items, section("Clock format", clockChildren))

	table.insert(items, ui.separator({}))

	-- Night light, themes, control center.
	table.insert(items, ui.row({ align = "center", gap = 10 }, {
		ui.glyph({ name = "moon-stars", size = 20, color = "on_surface_variant" }),
		titleBlock("Night light", "Lives in the control center Home tile."),
		ui.button({
			text = "Open",
			variant = "outline",
			controlSize = "sm",
			onClick = function()
				noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "home" })
			end,
		}),
	}))
	table.insert(items, linkRow("themes", "palette", "Themes", "Search, preview and apply" .. (S.theme ~= nil and S.theme ~= "" and (" (now " .. str(S.theme) .. ")") or ""), function()
		-- opening a panel replaces the open one, so there is no close first
		noctalia.togglePanel("bxrig/quick:themes")
	end))

	-- Result line.
	local line = ui.label({ text = "", fontSize = 11, maxLines = 1 })
	if busy ~= nil then
		line = ui.label({ text = "Working: " .. busy .. "...", fontSize = 11, color = "primary", maxLines = 1 })
	elseif status ~= nil then
		line = ui.label({ text = status.text, fontSize = 11, color = status.ok and "on_surface_variant" or "error", maxLines = 3 })
	elseif not loaded then
		line = ui.label({ text = "Reading the current settings...", fontSize = 11, color = "on_surface_variant", maxLines = 1 })
	end

	panel.render(ui.column({ gap = 8, padding = 12 }, {
		ui.row({ align = "center", gap = 8 }, {
			ui.glyph({ name = "adjustments-horizontal", size = 18, color = "tertiary" }),
			ui.label({ text = "Quick settings", fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
		}),
		ui.scroll({ flexGrow = 1, gap = 10, padding = 2 }, items),
		line,
	}))
end

function onOpen(_context)
	status = nil
	busy = nil
	loaded = true
	render()
	fetchAll()
end
