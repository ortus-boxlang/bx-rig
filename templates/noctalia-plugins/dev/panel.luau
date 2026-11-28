--!nonstrict
-- BxRig Developer panel: five tabs (Databases, Containers, VMs, BoxLang, Ports). Every row has a state dot, its name, the host ports as chips and
-- buttons: start or stop, copy the connection string (databases and VMs), restart (containers), logs, open (VMs).
-- Stop and restart need a second click (the button turns into "Sure?" for 4 seconds).
--
-- BoxLang: the web apps of `bxrig boxlang servers` (MiniServer and CommandBox): start or stop, open in the browser, the folder, the log.
-- Ports: what listens on this machine, the system's own left out (`bxrig tui ports --json`): open a web port, the Ports page.
-- Data: dev.luau (bxrig db list, containers list, vm list, boxlang servers list and tui ports, all --json), fetched on open and every 15 s.
-- Actions: bxrig db start|stop, containers start|stop|restart, vm start|stop|open, run with runAsync (never through a shell).
-- Logs and the Machines page open in a terminal with noctalia.runInTerminal (`bxrig containers logs NAME`, `bxrig tui machines`).
-- Copy: the connection string comes from `bxrig db info ENGINE --show-password --json` and goes to the clipboard through the shell
-- (noctalia.copyToClipboard, so the password is on no command line); wl-copy is the fallback when the shell cannot.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")
local dev = require("./dev.luau")

local REFRESH_MS = 15000
local CONFIRM_MS = 4000

local TABS = {
	{ id = "databases", label = "Databases" },
	{ id = "containers", label = "Containers" },
	{ id = "vms", label = "VMs" },
	{ id = "servers", label = "BoxLang" },
	{ id = "ports", label = "Ports" },
}

local data = nil -- last answer of dev.load
local actionError = nil
local loading = false
local lastFetchMs = -REFRESH_MS
local closeButton = true
local tab = "databases"
local busyKey = nil
local confirmKey = nil
local confirmUntil = 0

local fetch

local str = kit.str

-- ---- small helpers ----

-- a name safe to put in a shell command (the logs command goes through a terminal shell)
local function safeName(name)
	return type(name) == "string" and name:match("^[%w][%w_.%-]*$") ~= nil
end

local function shq(s)
	return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

local function stateColor(state)
	if state == "running" then
		return "primary"
	elseif state == "paused" then
		return "tertiary"
	elseif state == "missing" then
		return "error/0.6"
	end
	return "on_surface_variant/0.5"
end

local function isUp(state)
	return state == "running" or state == "paused"
end

local function portList(...)
	local out = {}
	for _, p in ipairs({ ... }) do
		local n = tonumber(p)
		if n ~= nil and n > 0 then
			table.insert(out, math.floor(n))
		end
	end
	return out
end

-- ---- running actions ----

local function render() end -- replaced below (the callbacks need it)

local function perform(key, args)
	if busyKey ~= nil then
		return
	end
	busyKey = key
	actionError = nil
	confirmKey = nil
	render()
	bxrig.run(args, function(ok, msg)
		busyKey = nil
		if not ok then
			actionError = msg ~= "" and msg or "The command failed"
		end
		fetch()
		render()
	end, 240000)
end

-- the first click of a destructive button arms it, the second (within CONFIRM_MS) is the answer
local function confirmed(key)
	local now = noctalia.nowMs()
	if confirmKey == key and now < confirmUntil then
		confirmKey = nil
		return true
	end
	confirmKey = key
	confirmUntil = now + CONFIRM_MS
	render()
	return false
end

local function copyText(text, what)
	if noctalia.copyToClipboard(text, "text/plain") then
		noctalia.notify("Copied", what)
		return
	end
	if noctalia.commandExists("wl-copy") then
		noctalia.runAsync({ "wl-copy", "--", text })
		noctalia.notify("Copied", what)
		return
	end
	actionError = "Could not reach the clipboard"
	render()
end

local function copyDatabaseUrl(item, title)
	if busyKey ~= nil then
		return
	end
	bxrig.json({ "db", "info", item.engine, "--name=" .. str(item.name), "--show-password", "--json" }, function(info, err)
		if err ~= nil then
			actionError = err
			render()
			return
		end
		local url = str(info.url)
		if url == "" then
			actionError = "No connection string for " .. title
			render()
			return
		end
		copyText(url, "Connection string for " .. title)
	end, 30000)
end

local function openLogs(container)
	if not safeName(container) then
		actionError = "Not a container name: " .. str(container)
		render()
		return
	end
	local cmd = shq(bxrig.command()) .. " containers logs " .. shq(container) .. " --lines=500"
	-- the pager keeps the terminal open; without less the output is followed by a prompt (read from the tty: stdin is the pipe, already at its end)
	noctalia.runInTerminal(cmd .. " | { command -v less >/dev/null 2>&1 && less -R +G || { cat; printf '\\nPress Enter to close '; read -r _ </dev/tty; }; }")
	panel.close()
end

-- A server's or a port's log or page, run in a terminal through the shell (names are checked first).
local function openServerLog(name)
	if not safeName(name) then
		actionError = "Not an app name: " .. str(name)
		render()
		return
	end
	noctalia.runInTerminal(shq(bxrig.command()) .. " boxlang servers log " .. shq(name) .. " --follow")
	panel.close()
end

local function openInBrowser(url)
	if type(url) == "string" and url:match("^https?://[%w%.%-:]+/?$") ~= nil then
		noctalia.runAsync({ "xdg-open", url })
	end
end

local function openMachines()
	noctalia.runInTerminal(shq(bxrig.command()) .. " tui machines")
	panel.close()
end

-- ---- rows ----

local function iconButton(opts)
	return ui.button({
		key = opts.key,
		glyph = opts.glyph,
		variant = opts.variant or "ghost",
		controlSize = "sm",
		tooltip = opts.tooltip,
		enabled = opts.enabled ~= false and busyKey == nil,
		onClick = opts.onClick,
	})
end

-- A button that needs a second click. key identifies it in the row.
local function confirmButton(key, glyph, tooltip, run)
	local armed = confirmKey == key and noctalia.nowMs() < confirmUntil
	return ui.button({
		key = key,
		glyph = glyph,
		text = armed and "Sure?" or nil,
		variant = armed and "destructive" or "ghost",
		controlSize = "sm",
		tooltip = armed and "Click again to confirm" or tooltip,
		enabled = busyKey == nil,
		onClick = function()
			if confirmed(key) then
				run()
			end
		end,
	})
end

local function portChips(ports)
	local chips = {}
	for i, p in ipairs(ports) do
		if i > 3 then
			table.insert(chips, ui.label({ text = "+" .. tostring(#ports - 3), fontSize = 10, color = "on_surface_variant" }))
			break
		end
		table.insert(chips, ui.row({ paddingH = 6, paddingV = 1, radius = 8, fill = "on_surface/0.08", align = "center" }, {
			ui.label({ text = ":" .. tostring(p), fontSize = 10, color = "on_surface_variant" }),
		}))
	end
	return chips
end

-- spec: key, title, subtitle, state, ports (numbers), buttons (ui nodes)
local function machineRow(spec)
	local titleLine = { ui.label({ text = spec.title, fontSize = 13, fontWeight = "semibold", maxLines = 1 }) }
	for _, chip in ipairs(portChips(spec.ports)) do
		table.insert(titleLine, chip)
	end
	local children = {
		ui.box({ width = 8, height = 8, radius = 4, fill = stateColor(spec.state), tooltip = spec.state }),
		ui.column({ flexGrow = 1, gap = 2 }, {
			ui.row({ align = "center", gap = 6 }, titleLine),
			ui.label({ text = spec.subtitle, fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
		}),
	}
	for _, b in ipairs(spec.buttons) do
		table.insert(children, b)
	end
	return ui.row({
		key = spec.key,
		align = "center",
		gap = 8,
		paddingH = 10,
		paddingV = 8,
		radius = 12,
		fill = "surface_container",
		opacity = busyKey == spec.key and 0.6 or 1,
	}, children)
end

local function startStopButton(key, item, startArgs, stopArgs, what)
	if isUp(item.state) then
		return confirmButton(key .. "-stop", "player-stop", "Stop " .. what, function()
			perform(key, stopArgs)
		end)
	end
	return iconButton({
		key = key .. "-start",
		glyph = "player-play",
		tooltip = "Start " .. what,
		enabled = item.state ~= "missing",
		onClick = function()
			perform(key, startArgs)
		end,
	})
end

local function databaseRow(d, index)
	local engine = str(d.engine)
	local known = engine ~= ""
	local title = known and engine or str(d.container)
	if known and str(d.name) ~= "" and str(d.name) ~= "default" then
		title = engine .. " · " .. str(d.name)
	end
	local key = "db-" .. index .. "-" .. str(d.container)
	local name = str(d.name) ~= "" and str(d.name) or "default"
	local buttons = {
		startStopButton(key, d, { "db", "start", engine, "--name=" .. name, "--yes" }, { "db", "stop", engine, "--name=" .. name }, title),
		iconButton({
			key = key .. "-copy",
			glyph = "copy",
			tooltip = "Copy connection string",
			enabled = known,
			onClick = function()
				copyDatabaseUrl({ engine = engine, name = name }, title)
			end,
		}),
		iconButton({
			key = key .. "-logs",
			glyph = "file-text",
			tooltip = "Open logs",
			onClick = function()
				openLogs(str(d.container))
			end,
		}),
	}
	return machineRow({
		key = key,
		title = title,
		subtitle = str(d.state) .. " · " .. dev.shortImage(d.image),
		state = str(d.state),
		ports = portList(d.port),
		buttons = known and buttons or { buttons[3] },
	})
end

local function containerRow(c, index)
	local name = str(c.name)
	local key = "ct-" .. index .. "-" .. name
	local buttons = {
		startStopButton(key, c, { "containers", "start", name }, { "containers", "stop", name }, name),
	}
	if isUp(c.state) then
		table.insert(buttons, confirmButton(key .. "-restart", "refresh", "Restart " .. name, function()
			perform(key, { "containers", "restart", name })
		end))
	end
	table.insert(buttons, iconButton({
		key = key .. "-logs",
		glyph = "file-text",
		tooltip = "Open logs",
		onClick = function()
			openLogs(name)
		end,
	}))
	return machineRow({
		key = key,
		title = name,
		subtitle = str(c.state) .. " · " .. dev.shortImage(c.image),
		state = str(c.state),
		ports = type(c.ports) == "table" and c.ports or {},
		buttons = buttons,
	})
end

local function vmRow(v, index)
	local name = str(v.name)
	local key = "vm-" .. index .. "-" .. name
	local ports = type(v.ports) == "table" and v.ports or {}
	local what = str(v.kind)
	if str(v.what) ~= "" then
		what = what .. " " .. str(v.what)
	end
	local buttons = {
		startStopButton(key, v, { "vm", "start", name }, { "vm", "stop", name }, name),
	}
	if str(v.url) ~= "" then
		table.insert(buttons, iconButton({
			key = key .. "-copy",
			glyph = "copy",
			tooltip = "Copy address",
			onClick = function()
				copyText(str(v.url), "Address of " .. name)
			end,
		}))
	end
	if v.state == "running" then
		table.insert(buttons, iconButton({
			key = key .. "-open",
			glyph = "external-link",
			tooltip = "Open in the browser",
			onClick = function()
				bxrig.run({ "vm", "open", name, "--web" })
			end,
		}))
	end
	table.insert(buttons, iconButton({
		key = key .. "-logs",
		glyph = "file-text",
		tooltip = "Open logs",
		onClick = function()
			openLogs("bxrig-vm-" .. name)
		end,
	}))
	return machineRow({
		key = key,
		title = name,
		subtitle = str(v.state) .. " · " .. what,
		state = str(v.state),
		ports = portList(ports.web, ports.rdp),
		buttons = buttons,
	})
end

-- ---- tabs ----

local function messageBlock(glyph, color, title, hint)
	local kids = {
		ui.glyph({ name = glyph, size = 22, color = color }),
		ui.label({ text = title, fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 4 }),
	}
	if hint ~= nil and hint ~= "" then
		table.insert(kids, ui.label({ text = hint, fontSize = 11, color = "on_surface_variant/0.7", textAlign = "center", maxLines = 3 }))
	end
	return ui.column({ paddingV = 20, align = "center", gap = 6 }, kids)
end

local function noEngineBlock()
	return messageBlock("alert-triangle", "on_surface_variant", "No container engine installed", "Install Podman with: bxrig profile-install containers")
end

local function serverRow(item, i)
	local name = str(item.name)
	local key = "srv-" .. name .. "-" .. i
	local up = item.state == "running"
	local buttons = {}
	if item.state ~= "missing" then
		if up then
			table.insert(buttons, confirmButton(key .. "-stop", "player-stop", "Stop", function()
				perform(key, { "boxlang", "servers", "stop", name })
			end))
			table.insert(buttons, iconButton({ key = key .. "-open", glyph = "external-link", tooltip = "Open " .. str(item.url), onClick = function()
				openInBrowser(item.url)
			end }))
		else
			table.insert(buttons, iconButton({ key = key .. "-start", glyph = "player-play", tooltip = "Start", onClick = function()
				perform(key, { "boxlang", "servers", "start", name })
			end }))
		end
		table.insert(buttons, iconButton({ key = key .. "-folder", glyph = "folder", tooltip = "Open the folder", onClick = function()
			perform(key, { "boxlang", "servers", "folder", name })
		end }))
	end
	table.insert(buttons, iconButton({ key = key .. "-log", glyph = "file-text", tooltip = "Log", onClick = function()
		openServerLog(name)
	end }))
	return machineRow({
		key = key,
		title = name,
		subtitle = (item.kind == "miniserver" and "MiniServer" or "CommandBox") .. " · " .. str(item.path),
		state = item.state,
		ports = portList(item.port),
		buttons = buttons,
	})
end

local function portRow(item, i)
	local port = tonumber(item.port) or 0
	local key = "port-" .. tostring(port) .. "-" .. i
	local buttons = {}
	if item.dev == true then
		table.insert(buttons, iconButton({ key = key .. "-open", glyph = "external-link", tooltip = "Open http://localhost:" .. tostring(port), onClick = function()
			openInBrowser("http://localhost:" .. tostring(port) .. "/")
		end }))
	end
	return machineRow({
		key = key,
		title = str(item.process) ~= "" and str(item.process) or "unknown",
		subtitle = (item.conflict == true and "conflict · " or "") .. str(item.user) .. " · up " .. str(item.up) .. " · " .. str(item.command),
		state = item.conflict == true and "missing" or "running",
		ports = portList(port),
		buttons = buttons,
	})
end

local TAB_EMPTY = {
	databases = { "database-off", "No databases yet", "Start one with: bxrig db start postgres --yes" },
	containers = { "box", "No containers", "Containers made with podman or docker run show up here" },
	vms = { "device-desktop-off", "No virtual machines yet", "Create one with: bxrig vm create linux NAME" },
	servers = { "world-off", "No BoxLang apps yet", "Add one with: bxrig boxlang servers scan ~/code --yes" },
	ports = { "plug-off", "Nothing of yours is listening", "Dev servers, databases and apps show up here with their port" },
}

local function tabBody()
	if data == nil then
		return messageBlock("loader", "on_surface_variant", "Loading…", nil)
	end
	local list = data[tab]
	if list == nil then
		if data.engineMissing and (tab == "databases" or tab == "containers") then
			return noEngineBlock()
		end
		return messageBlock("alert-triangle", "error", str(data.errors[tab]) ~= "" and str(data.errors[tab]) or "Could not read the list", nil)
	end
	if #list == 0 then
		if data.engineMissing and (tab == "databases" or tab == "containers") then
			return noEngineBlock()
		end
		local e = TAB_EMPTY[tab]
		return messageBlock(e[1], "on_surface_variant", e[2], e[3])
	end
	local rows = {}
	for i, item in ipairs(list) do
		if type(item) == "table" then
			if tab == "databases" then
				table.insert(rows, databaseRow(item, i))
			elseif tab == "containers" then
				table.insert(rows, containerRow(item, i))
			elseif tab == "servers" then
				table.insert(rows, serverRow(item, i))
			elseif tab == "ports" then
				table.insert(rows, portRow(item, i))
			else
				table.insert(rows, vmRow(item, i))
			end
		end
	end
	return ui.scroll({ flexGrow = 1, gap = 8 }, rows)
end

local function runningIn(list)
	local n = 0
	for _, item in ipairs(list or {}) do
		if type(item) == "table" and item.state == "running" then
			n = n + 1
		end
	end
	return n
end

local function tabBar()
	local buttons = {}
	for _, t in ipairs(TABS) do
		local label = t.label
		local n = data ~= nil and runningIn(data[t.id]) or 0
		if n > 0 then
			label = label .. " · " .. tostring(n)
		end
		table.insert(buttons, ui.button({
			key = "tab-" .. t.id,
			text = label,
			variant = tab == t.id and "secondary" or "ghost",
			selected = tab == t.id,
			controlSize = "sm",
			flexGrow = 1,
			onClick = function()
				tab = t.id
				actionError = nil
				confirmKey = nil
				render()
			end,
		}))
	end
	return ui.row({ align = "center", gap = 4 }, buttons)
end

render = function()
	local header = {
		ui.glyph({ name = "code", size = 24, color = "primary" }),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = "Developer", fontSize = 16, fontWeight = "bold" }),
			ui.label({
				text = data ~= nil and string.upper(tostring(data.running) .. " running") or "",
				fontSize = 10,
				fontWeight = "semibold",
				color = "on_surface_variant",
			}),
		}),
		ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Refresh", onClick = "onRefresh" }),
	}
	if closeButton then
		for _, b in ipairs(bxrig.windowButtons({ plugin = "bxrig/dev", panel = "panel", tui = nil })) do
			table.insert(header, b)
		end
table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }))
	end

	local sections = {
		ui.row({ align = "center", gap = 10 }, header),
		tabBar(),
		ui.separator({}),
		tabBody(),
	}
	local refreshError = data ~= nil and data[tab] ~= nil and data.errors[tab] or nil
	if actionError ~= nil then
		table.insert(sections, ui.label({ text = actionError, fontSize = 10, color = "error", maxLines = 3 }))
	elseif refreshError ~= nil then
		table.insert(sections, ui.label({ text = "Could not refresh: " .. str(refreshError), fontSize = 10, color = "error", maxLines = 3 }))
	end
	table.insert(sections, ui.separator({}))
	table.insert(sections, ui.row({ align = "center", gap = 8 }, {
		ui.spacer({ flexGrow = 1 }),
		ui.button({ text = tab == "servers" and "Open Servers page" or (tab == "ports" and "Open Ports page" or "Open Machines page"), glyph = "terminal-2", variant = "ghost", controlSize = "sm", onClick = function()
			noctalia.runInTerminal(shq(bxrig.command()) .. " tui " .. (tab == "servers" and "servers" or (tab == "ports" and "ports" or "machines")))
			panel.close()
		end }),
	}))
	panel.render(ui.column({ flexGrow = 1, gap = 10, padding = 12 }, sections))
end

fetch = function()
	if loading then
		return
	end
	loading = true
	lastFetchMs = noctalia.nowMs()
	dev.load(function(result)
		loading = false
		-- a list that could not be read this time keeps its last good rows (the error shows under the list), unless the engine is gone
		if data ~= nil and not result.engineMissing then
			for _, key in ipairs({ "databases", "containers", "vms", "servers", "ports" }) do
				if result[key] == nil and data[key] ~= nil then
					result[key] = data[key]
				end
			end
		end
		data = result
		noctalia.state.set("running", result.running)
		render()
	end, 30000)
end

function onRefresh()
	fetch()
end

function onCloseClicked()
	panel.close()
end

function onOpen(_context)
	closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
	actionError = nil
	confirmKey = nil
	panel.setWantsSecondTicks(true)
	render()
	fetch()
end

function onClose()
	panel.setWantsSecondTicks(false)
end

function update()
	local now = noctalia.nowMs()
	if confirmKey ~= nil and now >= confirmUntil then
		confirmKey = nil
		render()
	end
	if now - lastFetchMs >= REFRESH_MS then
		fetch()
	end
end
