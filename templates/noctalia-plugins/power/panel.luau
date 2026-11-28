--!nonstrict
-- BxRig Power panel: the panel the battery widget opens (left click). Battery and power are one panel.
--
--   battery   percent, state, time remaining, watts, health, cycles (`bxrig power status --json`, on open and every 15 s while open)
--   profile   Saver, Balanced, Performance (`power profile saver|balanced|performance`)
--   lid       what closing the lid does on battery and on AC power (`power lid battery|ac suspend|hibernate|lock|ignore --yes`)
--   session   Suspend (`system suspend`) and Hibernate (`power hibernate --yes`); each asks first. Hibernate is greyed out with the reason when
--             `power hibernate --dry-run` says it is not ready (disk swap, resume=, kernel)
--   limit     a slider for the charge limit, only when the battery has the kernel attribute (`power charge-limit N|off --yes`)
-- The lid and charge limit commands write root files through sudo, which cannot ask for a password here, so they run in a terminal window
-- (the password is asked there) and the panel looks again every 3 s for a minute. Everything else runs directly.
-- "Open Power page" opens the control center Power tab (`noctalia msg panel-toggle control-center power`).
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local REFRESH_MS = 15000
local FAST_MS = 3000

local PROFILES = {
	{ id = "saver", value = "power-saver", label = "Saver", glyph = "leaf", sub = "longer battery" },
	{ id = "balanced", value = "balanced", label = "Balanced", glyph = "scale", sub = "default" },
	{ id = "performance", value = "performance", label = "Performance", glyph = "bolt", sub = "fans up" },
}

local LID = {
	{ id = "suspend", label = "Suspend" },
	{ id = "hibernate", label = "Hibernate" },
	{ id = "lock", label = "Lock" },
	{ id = "ignore", label = "Nothing" },
}

local data = nil -- `power status --json` data
local errorText = nil
local hibernateKnown = false
local hibernateWhy = nil -- nil when ready (or not known yet), else why hibernation is not ready
local lastFetchMs = -REFRESH_MS
local fastUntilMs = 0
local busy = nil -- label of the command that is running
local status = nil -- { text, ok } of the last action
local confirm = nil -- "suspend" or "hibernate" while the panel asks first
local limitDraft = nil -- the slider value while it is dragged
local closeButton = true

local render

local str = kit.str

local function minutesText(m)
	m = tonumber(m) or -1
	if m < 0 then
		return ""
	end
	if m >= 60 then
		return string.format("%d h %d min", math.floor(m / 60), m % 60)
	end
	return string.format("%d min", m)
end

local function firstBattery()
	if data ~= nil and type(data.battery) == "table" then
		return data.battery[1]
	end
	return nil
end

local function batteryGlyph(b)
	if b == nil then
		return "plug"
	end
	if b.state == "charging" then
		return "battery-charging-2"
	end
	local p = tonumber(b.percent) or 0
	if p > 75 then
		return "battery-4"
	elseif p > 50 then
		return "battery-3"
	elseif p > 25 then
		return "battery-2"
	end
	return "battery-1"
end

local function stateLine(b)
	local left = minutesText(b.time_remaining_minutes)
	if b.state == "charging" then
		return left ~= "" and ("Charging, " .. left .. " to full") or "Charging"
	elseif b.state == "discharging" then
		return left ~= "" and ("On battery, " .. left .. " left") or "On battery"
	elseif b.state == "full" then
		return "Fully charged"
	elseif b.state == "not_charging" then
		return "Plugged in, not charging"
	end
	return str(b.status) ~= "" and str(b.status) or "Unknown"
end

-- ---- reads ----

local function fetch()
	lastFetchMs = noctalia.nowMs()
	bxrig.json({ "power", "status", "--json" }, function(result, err)
		if err ~= nil then
			errorText = err
		else
			errorText = nil
			data = result
			limitDraft = nil
		end
		render()
	end)
end

-- Hibernation is ready when the dry run exits 0; otherwise the error says what is missing.
local function checkHibernate()
	bxrig.json({ "power", "hibernate", "--dry-run", "--json" }, function(_result, err)
		hibernateKnown = true
		hibernateWhy = err
		render()
	end)
end

-- ---- actions ----

-- Runs a bxrig command directly and shows its first output line.
local function apply(label, args, onOk)
	if busy ~= nil then
		return
	end
	busy = label
	status = nil
	render()
	bxrig.run(args, function(ok, message)
		busy = nil
		if ok then
			if onOk ~= nil then
				onOk()
			end
			status = { text = label .. ": " .. (message ~= "" and message or "done"), ok = true }
		else
			status = { text = label .. ": " .. (message ~= "" and message or "failed"), ok = false }
		end
		render()
		fetch()
	end, 60000)
end

-- Runs a bxrig command that needs sudo in a terminal window, where the password can be asked. Only fixed words and whole numbers go in.
local function inTerminal(label, args)
	local parts = { "'" .. bxrig.command() .. "'" }
	for _, a in ipairs(args) do
		table.insert(parts, tostring(a))
	end
	local cmd = table.concat(parts, " ") .. '; echo; echo "Press Enter to close."; read _'
	if noctalia.runInTerminal(cmd) then
		fastUntilMs = noctalia.nowMs() + 60000
		status = { text = label .. ": finish in the terminal window (it asks for your password)", ok = true }
	else
		status = { text = label .. ": could not open a terminal", ok = false }
	end
	render()
end

-- ---- drawing helpers ----

local function section(title, children)
	local kids = { ui.label({ text = string.upper(title), fontSize = 11, fontWeight = "bold", color = "on_surface_variant" }) }
	for _, c in ipairs(children) do
		table.insert(kids, c)
	end
	return ui.column({ gap = 6 }, kids)
end

local function stat(value, caption)
	return ui.column({ flexGrow = 1, gap = 1, align = "center" }, {
		ui.label({ text = value, fontSize = 14, fontWeight = "semibold", textAlign = "center", maxLines = 1 }),
		ui.label({ text = string.upper(caption), fontSize = 9, color = "on_surface_variant", textAlign = "center", maxLines = 1 }),
	})
end

local function batteryCard(b)
	local pct = tonumber(b.percent) or 0
	local low = pct <= 20 and b.state == "discharging"
	local stats = {}
	if (tonumber(b.watts) or -1) >= 0 then
		table.insert(stats, stat(string.format("%.1fW", b.watts), "power"))
	end
	if (tonumber(b.health_percent) or -1) >= 0 then
		table.insert(stats, stat(string.format("%d%%", b.health_percent), "health"))
	end
	if (tonumber(b.cycles) or -1) >= 0 then
		table.insert(stats, stat(string.format("%d", b.cycles), "cycles"))
	end
	local kids = {
		ui.row({ align = "center", gap = 12 }, {
			ui.label({ text = string.format("%d%%", pct), fontSize = 30, fontWeight = "bold", color = low and "error" or "on_surface" }),
			ui.column({ flexGrow = 1, gap = 2 }, {
				ui.label({ text = stateLine(b), fontSize = 13, fontWeight = "semibold", maxLines = 2 }),
				ui.label({ text = (data.on_ac == true and "AC power connected" or "Running on the battery") .. "  ·  " .. str(b.name), fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
			}),
		}),
		ui.progress({ progress = math.max(0, math.min(1, pct / 100)), fill = low and "error" or "primary", track = "on_surface/0.12", height = 8, radius = 4 }),
	}
	if #stats > 0 then
		table.insert(kids, ui.row({ gap = 4, paddingV = 2, flexGrow = 1 }, stats))
	end
	return ui.column({ gap = 8, padding = 12, radius = 12, fill = "surface_container", align = "stretch" }, kids)
end

-- Buttons, one per option, the current one filled. perRow (default all in one row) wraps them into rows of that many, so long labels are not cut.
local function picker(key, options, current, onPick, perRow)
	local rows = {}
	local buttons = {}
	local per = perRow or #options
	for i, opt in ipairs(options) do
		local on = current == opt.id
		table.insert(buttons, ui.button({
			key = key .. "-" .. opt.id,
			text = opt.label,
			variant = on and "primary" or "outline",
			selected = on,
			controlSize = "sm",
			flexGrow = 1,
			enabled = busy == nil,
			onClick = function()
				if not on then
					onPick(opt)
				end
			end,
		}))
		if #buttons == per or i == #options then
			table.insert(rows, ui.row({ gap = 4 }, buttons))
			buttons = {}
		end
	end
	if #rows == 1 then
		return rows[1]
	end
	return ui.column({ gap = 4 }, rows)
end

-- The lid action to show as selected: no drop-in means the systemd default, suspend.
local function lidChoice(v)
	if v == nil or v == "default" then
		return "suspend"
	end
	return v
end

local function profileCards()
	local current = data ~= nil and str(data.profile) or ""
	local cards = {}
	for _, p in ipairs(PROFILES) do
		local on = current == p.value
		table.insert(cards, ui.column({
			key = "profile-" .. p.id,
			flexGrow = 1,
			align = "center",
			gap = 2,
			paddingV = 10,
			paddingH = 4,
			radius = 10,
			fill = on and "primary/0.18" or "on_surface/0.06",
			border = on and "primary" or "on_surface/0",
			borderWidth = 1,
			onClick = function()
				if not on then
					apply("Power profile", { "power", "profile", p.id }, nil)
				end
			end,
		}, {
			ui.glyph({ name = p.glyph, size = 22, color = on and "primary" or "on_surface_variant" }),
			ui.label({ text = p.label, fontSize = 12, fontWeight = on and "bold" or "semibold", textAlign = "center" }),
			ui.label({ text = p.sub, fontSize = 10, color = "on_surface_variant", textAlign = "center" }),
		}))
	end
	return ui.row({ gap = 6 }, cards)
end

local function sessionButtons()
	local canHibernate = hibernateKnown and hibernateWhy == nil
	local kids = {
		ui.row({ gap = 6 }, {
			ui.button({
				glyph = "moon",
				text = "Suspend",
				variant = "outline",
				flexGrow = 1,
				enabled = busy == nil,
				onClick = function()
					confirm = "suspend"
					render()
				end,
			}),
			ui.button({
				glyph = "device-floppy",
				text = "Hibernate",
				variant = "outline",
				flexGrow = 1,
				enabled = busy == nil and canHibernate,
				tooltip = canHibernate and "Save to disk and power off" or "Not ready: see the note below",
				onClick = function()
					confirm = "hibernate"
					render()
				end,
			}),
		}),
	}
	if hibernateKnown and hibernateWhy ~= nil then
		table.insert(kids, ui.label({ text = "Hibernate is not ready: " .. str(hibernateWhy), fontSize = 11, color = "on_surface_variant", maxLines = 4 }))
	end
	if confirm ~= nil then
		local word = confirm == "suspend" and "Suspend" or "Hibernate"
		table.insert(kids, ui.column({ gap = 6, padding = 10, radius = 10, fill = "on_surface/0.08" }, {
			ui.label({ text = word .. " now?", fontSize = 13, fontWeight = "bold" }),
			ui.label({ text = confirm == "suspend" and "The screen locks and the computer sleeps." or "Open programs are saved to disk and the computer powers off.", fontSize = 11, color = "on_surface_variant", maxLines = 3 }),
			ui.row({ gap = 6 }, {
				ui.button({
					text = word,
					variant = "destructive",
					flexGrow = 1,
					onClick = function()
						local which = confirm
						confirm = nil
						if which == "suspend" then
							apply("Suspend", { "system", "suspend" }, function()
								panel.close()
							end)
						else
							apply("Hibernate", { "power", "hibernate", "--yes" }, function()
								panel.close()
							end)
						end
					end,
				}),
				ui.button({
					text = "Cancel",
					variant = "outline",
					flexGrow = 1,
					onClick = function()
						confirm = nil
						render()
					end,
				}),
			}),
		}))
	end
	return ui.column({ gap = 6 }, kids)
end

local function limitSection(b)
	local limit = limitDraft or tonumber(b.charge_limit) or 100
	local label = limit >= 100 and "No limit (charge to 100%)" or string.format("Stop charging at %d%%", limit)
	return section("Charge limit", {
		ui.label({ text = label, fontSize = 13, fontWeight = "semibold" }),
		ui.slider({
			min = 40,
			max = 100,
			step = 5,
			value = limit,
			enabled = busy == nil,
			onChange = function(v)
				limitDraft = math.floor((tonumber(v) or limit) + 0.5)
				render()
			end,
			onDragEnd = function()
				local want = limitDraft or limit
				if want >= 100 then
					inTerminal("Charge limit", { "power", "charge-limit", "off", "--yes" })
				else
					inTerminal("Charge limit", { "power", "charge-limit", want, "--yes" })
				end
			end,
		}),
		ui.label({ text = "Keeps the battery healthier. Applying it asks for your password in a terminal.", fontSize = 11, color = "on_surface_variant", maxLines = 3 }),
	})
end

render = function()
	local b = firstBattery()
	local header = {
		ui.glyph({ name = batteryGlyph(b), size = 24, color = "primary" }),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = "Power", fontSize = 16, fontWeight = "bold" }),
		}),
		ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Refresh", onClick = "onRefresh" }),
	}
	if closeButton then
		for _, b in ipairs(bxrig.windowButtons({ plugin = "bxrig/power", panel = "panel", tui = nil })) do
			table.insert(header, b)
		end
table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }))
	end

	local items = {}
	if data == nil then
		table.insert(items, ui.column({ paddingV = 16, align = "center", gap = 6 }, {
			ui.glyph({ name = errorText ~= nil and "alert-triangle" or "loader", size = 20, color = errorText ~= nil and "error" or "on_surface_variant" }),
			ui.label({ text = errorText or "Loading…", fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 4 }),
		}))
	else
		if b ~= nil then
			table.insert(items, batteryCard(b))
		else
			table.insert(items, ui.row({ align = "center", gap = 10, padding = 12, radius = 12, fill = "surface_container" }, {
				ui.glyph({ name = "plug", size = 22, color = "on_surface_variant" }),
				ui.label({ text = "No battery found: this is a desktop.", fontSize = 13, flexGrow = 1, maxLines = 2 }),
			}))
		end
		table.insert(items, section("Power profile", { profileCards() }))
		if b ~= nil then
			table.insert(items, section("When the lid closes", {
				ui.label({ text = "On battery", fontSize = 11, color = "on_surface_variant" }),
				picker("lid-battery", LID, lidChoice(data.lid_battery), function(opt)
					inTerminal("Lid on battery", { "power", "lid", "battery", opt.id, "--yes" })
				end, 2),
				ui.label({ text = "On AC power", fontSize = 11, color = "on_surface_variant" }),
				picker("lid-ac", LID, lidChoice(data.lid_ac), function(opt)
					inTerminal("Lid on AC power", { "power", "lid", "ac", opt.id, "--yes" })
				end, 2),
				ui.label({ text = "Applies from the next login. Asks for your password in a terminal.", fontSize = 11, color = "on_surface_variant", maxLines = 2 }),
			}))
		end
		table.insert(items, section("Session", { sessionButtons() }))
		if b ~= nil and data.charge_limit_supported == true and (tonumber(b.charge_limit) or -1) >= 0 then
			table.insert(items, limitSection(b))
		end
	end

	local line = ui.label({ text = "", fontSize = 11, maxLines = 1 })
	if busy ~= nil then
		line = ui.label({ text = "Working: " .. busy .. "…", fontSize = 11, color = "primary", maxLines = 1 })
	elseif status ~= nil then
		line = ui.label({ text = status.text, fontSize = 11, color = status.ok and "on_surface_variant" or "error", maxLines = 3 })
	end

	panel.render(ui.column({ gap = 8, padding = 12 }, {
		ui.row({ align = "center", gap = 10 }, header),
		ui.separator({}),
		ui.scroll({ flexGrow = 1, gap = 10, padding = 2 }, items),
		line,
		ui.button({
			glyph = "battery-charging-2",
			text = "Open Power page",
			variant = "ghost",
			controlSize = "sm",
			onClick = "onOpenPage",
		}),
	}))
end

function onRefresh()
	fetch()
end

function onCloseClicked()
	panel.close()
end

function onOpenPage()
	noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "power" })
end

function onOpen(_context)
	confirm = nil
	status = nil
	busy = nil
	limitDraft = nil
	closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
	panel.setWantsSecondTicks(true)
	render()
	fetch()
	checkHibernate()
end

function onClose()
	panel.setWantsSecondTicks(false)
end

function update()
	local now = noctalia.nowMs()
	local every = now < fastUntilMs and FAST_MS or REFRESH_MS
	if now - lastFetchMs >= every and limitDraft == nil then
		fetch()
	end
end
