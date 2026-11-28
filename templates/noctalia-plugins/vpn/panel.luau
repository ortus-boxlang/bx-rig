--!nonstrict
-- BxRig VPN panel: one pick-one list in two groups, "Network profiles" (saved NetworkManager vpn and wireguard connections) and
-- "VPN apps" (NordVPN, NordLayer, Tailscale, Mullvad, whatever is installed). A row has a state dot, the name, one line of state
-- ("Connected · Berlin, Germany", "Off", "Log in first"), a place button where the provider can pick one (country, exit node,
-- gateway) and a switch. Switching one on disconnects the VPN that is connected first, unless "Allow more than one at the same time"
-- (the switch at the bottom, advanced) is on; then a line warns that two VPNs can clash on routes and DNS.
-- The place button opens a second page: a search box and the places of that provider; a click connects there.
-- When nothing is installed the panel says so and offers the install commands (it can be opened from a keybind, the shield hides itself).
--
-- Data: `bxrig vpn list --json` (vpn.luau), fetched on open and every 10 s while open; places: `bxrig vpn locations NAME --json`.
-- Actions (runAsync with an argument list, never a shell): `bxrig vpn connect NAME [--location=VALUE]`, `bxrig vpn disconnect NAME`,
-- `bxrig vpn set allow_several=true|false --yes`. The install buttons open a terminal with `bxrig install NAME --yes`.
-- Colors are palette roles only, so the panel follows the active theme (there is no success role: primary, the brand green, is "connected").

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")
local vpn = require("./vpn.luau")

local REFRESH_MS = 10000

local data = nil -- last answer of vpn.load
local actionError = nil
local loading = false
local lastFetchMs = -REFRESH_MS
local closeButton = true
local busyId = nil -- the id an action is running for ("*settings" for the switch at the bottom)
local busyText = nil
local page = "list" -- "list" or "places"
local placesItem = nil -- the item whose places are shown
local places = nil -- the answer of `vpn locations`, nil while loading
local placesError = nil
local filter = ""

local fetch
local render = function() end -- replaced below (the callbacks need it)

local str = kit.str

local function shq(s)
	return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

-- a name safe to put in a shell command (the install buttons go through a terminal shell)
local function safeName(name)
	return type(name) == "string" and name:match("^[%w][%w_.%-]*$") ~= nil
end

-- ---- running actions ----

local function perform(id, text, args)
	if busyId ~= nil then
		return
	end
	busyId = id
	busyText = text
	actionError = nil
	render()
	bxrig.run(args, function(ok, msg)
		busyId = nil
		busyText = nil
		if not ok then
			actionError = msg ~= "" and msg or "The command failed"
		end
		fetch()
		render()
	end, 120000)
end

local function connect(item, location)
	local args = { "vpn", "connect", str(item.id) }
	if location ~= nil then
		table.insert(args, "--location=" .. location)
	end
	perform(str(item.id), "Connecting…", args)
end

local function disconnect(item)
	perform(str(item.id), "Disconnecting…", { "vpn", "disconnect", str(item.id) })
end

local function setAllowSeveral(on)
	perform("*settings", "Saving…", { "vpn", "set", "allow_several=" .. (on and "true" or "false"), "--yes" })
end

local function openInstall(choice)
	local id = str(choice.install)
	if not safeName(id) then
		actionError = "Not a package name: " .. id
		render()
		return
	end
	-- --yes: without it `bxrig install` only prints its plan and the terminal closes at once; the window waits for Enter so the result can be read (sudo asks for the password there)
	noctalia.runInTerminal(shq(bxrig.command()) .. " install " .. shq(id) .. " --yes; echo; printf 'Done. Press Enter to close. '; read -r _")
	panel.close()
end

-- ---- drawing helpers ----

local function dotColor(item)
	if item.connected == true then
		return "primary"
	elseif str(item.state) == "connecting" then
		return "tertiary"
	elseif str(item.state) == "login" or str(item.state) == "unavailable" then
		return "error/0.6"
	end
	return "on_surface_variant/0.5"
end

local function messageBlock(glyph, color, title, hint)
	local kids = {
		ui.glyph({ name = glyph, size = 22, color = color }),
		ui.label({ text = title, fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 4 }),
	}
	if hint ~= nil and hint ~= "" then
		table.insert(kids, ui.label({ text = hint, fontSize = 11, color = "on_surface_variant/0.7", textAlign = "center", maxLines = 4 }))
	end
	return ui.column({ paddingV = 20, align = "center", gap = 6 }, kids)
end

local function groupLabel(title)
	return ui.label({ text = string.upper(title), fontSize = 10, fontWeight = "bold", color = "on_surface_variant" })
end

local function openPlaces(item)
	if busyId ~= nil then
		return
	end
	page = "places"
	placesItem = item
	places = nil
	placesError = nil
	filter = ""
	render()
	bxrig.json({ "vpn", "locations", str(item.id), "--json" }, function(answer, err)
		if err ~= nil then
			placesError = err
		else
			places = answer
		end
		render()
	end, 60000)
end

-- One row: dot, name and state, the place button, the switch.
local function providerRow(item, index)
	local id = str(item.id)
	local busyHere = busyId == id
	local state = str(item.state)
	local usable = state ~= "unavailable" and state ~= "login"
	local sub = busyHere and busyText or vpn.subtitle(item)
	local children = {
		ui.box({ width = 8, height = 8, radius = 4, fill = dotColor(item), tooltip = state }),
		ui.column({ flexGrow = 1, gap = 1, tooltip = str(item.note) ~= "" and str(item.note) or nil }, {
			ui.label({ text = str(item.name), fontSize = 13, fontWeight = "semibold", maxLines = 1 }),
			ui.label({ text = sub, fontSize = 11, color = "on_surface_variant", maxLines = 2 }),
		}),
	}
	if item.can_pick == true then
		table.insert(children, ui.button({
			key = "pick-" .. index .. "-" .. id,
			glyph = "map-pin",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Choose a place",
			enabled = busyId == nil and usable,
			onClick = function()
				openPlaces(item)
			end,
		}))
	end
	table.insert(children, ui.toggle({
		key = "switch-" .. index .. "-" .. id,
		checked = item.connected == true or state == "connecting",
		enabled = busyId == nil and usable,
		onChange = function(value)
			if value == "true" then
				connect(item, nil)
			else
				disconnect(item)
			end
		end,
	}))
	return ui.row({
		key = "row-" .. index .. "-" .. id,
		align = "center",
		gap = 10,
		paddingH = 10,
		paddingV = 8,
		radius = 12,
		fill = item.connected == true and "primary/0.1" or "surface_container",
		opacity = busyHere and 0.7 or 1,
	}, children)
end

local function groupBlock(title, items, startIndex)
	local kids = { groupLabel(title) }
	for i, item in ipairs(items) do
		table.insert(kids, providerRow(item, startIndex + i))
	end
	return ui.column({ gap = 6 }, kids)
end

local function installBlock()
	local kids = { messageBlock("shield-off", "on_surface_variant", "No VPN is installed", "Install a VPN app, or import a VPN or WireGuard profile into NetworkManager.") }
	for i, choice in ipairs(data.install or {}) do
		if type(choice) == "table" then
			table.insert(kids, ui.button({
				key = "install-" .. i,
				text = "Install " .. str(choice.name),
				glyph = "download",
				variant = "ghost",
				controlSize = "sm",
				enabled = safeName(str(choice.install)),
				onClick = function()
					openInstall(choice)
				end,
			}))
		end
	end
	return ui.column({ gap = 4, align = "center" }, kids)
end

local function severalRow()
	return ui.row({ key = "allow-several", align = "center", gap = 10 }, {
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = "Allow more than one at the same time", fontSize = 12, fontWeight = "semibold", maxLines = 1 }),
			ui.label({ text = "Advanced. Off: choosing one disconnects the current one first.", fontSize = 10, color = "on_surface_variant", maxLines = 2 }),
		}),
		ui.toggle({
			checked = data ~= nil and data.allowSeveral == true,
			enabled = data ~= nil and busyId == nil,
			onChange = function(value)
				setAllowSeveral(value == "true")
			end,
		}),
	})
end

local function listBody()
	if data == nil then
		return messageBlock("loader", "on_surface_variant", "Loading…", nil)
	end
	if data.error ~= nil and #data.providers == 0 then
		return messageBlock("alert-triangle", "error", data.error, nil)
	end
	if #data.providers == 0 then
		return installBlock()
	end
	local profiles = vpn.group(data.providers, "profiles")
	local apps = vpn.group(data.providers, "apps")
	local blocks = {}
	if #profiles > 0 then
		table.insert(blocks, groupBlock("Network profiles", profiles, 0))
	end
	if #apps > 0 then
		table.insert(blocks, groupBlock("VPN apps", apps, #profiles))
	end
	return ui.scroll({ flexGrow = 1, gap = 12 }, blocks)
end

local function listPage()
	local header = {
		ui.glyph({ name = (data ~= nil and #data.connected > 0) and "shield-check" or "shield", size = 24, color = (data ~= nil and #data.connected > 0) and "primary" or "on_surface_variant" }),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = "VPN", fontSize = 16, fontWeight = "bold" }),
			ui.label({
				text = data ~= nil and string.upper(vpn.summary(data.connected)) or "",
				fontSize = 10,
				fontWeight = "semibold",
				color = "on_surface_variant",
				maxLines = 1,
			}),
		}),
		ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Refresh", onClick = "onRefresh" }),
	}
	if closeButton then
		for _, b in ipairs(bxrig.windowButtons({ plugin = "bxrig/vpn", panel = "panel", tui = nil })) do
			table.insert(header, b)
		end
table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }))
	end
	local sections = {
		ui.row({ align = "center", gap = 10 }, header),
		ui.separator({}),
		listBody(),
	}
	if data ~= nil and #data.providers > 0 then
		if data.allowSeveral and #data.connected > 1 then
			table.insert(sections, ui.label({ text = "More than one VPN is connected. Two VPNs can clash on routes and DNS.", fontSize = 10, color = "tertiary", maxLines = 3 }))
		end
		table.insert(sections, ui.separator({}))
		table.insert(sections, severalRow())
	end
	if actionError ~= nil then
		table.insert(sections, ui.label({ text = actionError, fontSize = 10, color = "error", maxLines = 3 }))
	elseif data ~= nil and data.error ~= nil and #data.providers > 0 then
		table.insert(sections, ui.label({ text = "Could not refresh: " .. data.error, fontSize = 10, color = "error", maxLines = 3 }))
	end
	return ui.column({ flexGrow = 1, gap = 10, padding = 12 }, sections)
end

-- ---- the places page ----

local function placeRows()
	local rows = {}
	local needle = string.lower(filter)
	local shown = 0
	for i, place in ipairs(places.locations or {}) do
		if type(place) == "table" and (needle == "" or string.find(string.lower(str(place.label)), needle, 1, true) ~= nil) then
			shown = shown + 1
			if shown > 200 then
				break
			end
			table.insert(rows, ui.button({
				key = "place-" .. i .. "-" .. str(place.value),
				text = str(place.label),
				variant = "ghost",
				controlSize = "sm",
				contentAlign = "start",
				enabled = busyId == nil,
				onClick = function()
					local item = placesItem
					page = "list"
					connect(item, str(place.value))
				end,
			}))
		end
	end
	if #rows == 0 then
		table.insert(rows, ui.label({ text = "No place matches", fontSize = 12, color = "on_surface_variant" }))
	end
	return rows
end

local function placesBody()
	if placesError ~= nil then
		return messageBlock("alert-triangle", "error", placesError, nil)
	end
	if places == nil then
		return messageBlock("loader", "on_surface_variant", "Loading…", nil)
	end
	if places.can_pick ~= true or #(places.locations or {}) == 0 then
		return messageBlock("map-pin-off", "on_surface_variant", str(placesItem.name) .. " has no places to choose", nil)
	end
	return ui.scroll({ flexGrow = 1, gap = 2 }, placeRows())
end

local function placesPage()
	local now = str(placesItem.location)
	local header = {
		ui.button({
			glyph = "arrow-left",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Back",
			onClick = function()
				page = "list"
				render()
			end,
		}),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = str(placesItem.name), fontSize = 16, fontWeight = "bold", maxLines = 1 }),
			ui.label({ text = now ~= "" and string.upper("Now: " .. now) or "CHOOSE A PLACE", fontSize = 10, fontWeight = "semibold", color = "on_surface_variant", maxLines = 1 }),
		}),
	}
	if closeButton then
		for _, b in ipairs(bxrig.windowButtons({ plugin = "bxrig/vpn", panel = "panel", tui = nil })) do
			table.insert(header, b)
		end
table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }))
	end
	return ui.column({ flexGrow = 1, gap = 10, padding = 12 }, {
		ui.row({ align = "center", gap = 10 }, header),
		ui.input({
			key = "places-filter",
			placeholder = "Search places",
			controlSize = "sm",
			focus = true,
			onChange = function(text)
				filter = str(text)
				render()
			end,
		}),
		ui.separator({}),
		placesBody(),
	})
end

render = function()
	if page == "places" and placesItem ~= nil then
		panel.render(placesPage())
	else
		panel.render(listPage())
	end
end

fetch = function()
	if loading then
		return
	end
	loading = true
	lastFetchMs = noctalia.nowMs()
	vpn.load(function(answer)
		loading = false
		data = answer
		noctalia.state.set("list", { providers = answer.providers, connected = answer.connected })
		render()
	end, 60000)
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
	page = "list"
	placesItem = nil
	panel.setWantsSecondTicks(true)
	render()
	fetch()
end

function onClose()
	panel.setWantsSecondTicks(false)
end

function update()
	if page == "list" and busyId == nil and noctalia.nowMs() - lastFetchMs >= REFRESH_MS then
		fetch()
	end
end
