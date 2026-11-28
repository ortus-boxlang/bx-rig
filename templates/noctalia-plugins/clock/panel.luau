--!nonstrict
-- BxRig Clock panel: "It's HH:MM here in <city>", then one card per zone
-- with its date, big time, abbreviation + offset from local, and a day bar
-- whose sun/moon marker shows where in its day that zone is.
--
-- Below the zones: the agenda of today and tomorrow (`bxrig calendar agenda --days=2 --json`) and the reminders still to come
-- (`bxrig remind list --json`), each with a check button that marks it done. Each section is left out when there is nothing in it.
--
-- Data: `bxrig time world --json`, fetched on open and every 30 s while open. The Calendar button opens the Noctalia calendar
-- (`noctalia msg panel-toggle control-center calendar`, the same route as right click on the bar clock).
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")

local REFRESH_MS = 30000

local data = nil -- last good `data` table
local errorText = nil
local loading = false
local lastFetchMs = -REFRESH_MS
local closeButton = true
local agenda = nil -- `calendar agenda` data
local reminders = nil -- `remind list` data

local function str(v)
	if v == nil then
		return ""
	end
	return tostring(v)
end

local function clamp01(x)
	x = tonumber(x) or 0
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end

local function dateLine(zone)
	local text = str(zone.date)
	local rel = str(zone.relative_day)
	local suffix = nil
	if rel == "tomorrow" then
		suffix = "Tomorrow"
	elseif rel == "yesterday" then
		suffix = "Yesterday"
	end
	if suffix ~= nil then
		if text == "" then
			return suffix
		end
		return `{text} · {suffix}`
	end
	return text
end

-- Thin track with a sun/moon marker at day_fraction (0 = local midnight).
local function dayBar(zone, key)
	local f = clamp01(zone.day_fraction)
	local isDay = zone.is_day == true
	return ui.row({ key = key, align = "center", gap = 0, height = 14 }, {
		ui.box({ flexGrow = f, height = 2, radius = 1, fill = "on_surface_variant/0.35" }),
		ui.glyph({
			name = isDay and "sun" or "moon",
			size = 14,
			color = isDay and "tertiary" or "secondary",
		}),
		ui.box({ flexGrow = 1 - f, height = 2, radius = 1, fill = "on_surface_variant/0.35" }),
	})
end

local function zoneCard(zone, index)
	local sub = str(zone.abbrev)
	local offset = str(zone.offset)
	if offset ~= "" and offset ~= "+0h" and offset ~= "0h" then
		sub = sub == "" and offset or `{sub} {offset}`
	end
	local key = "zone-" .. index .. "-" .. str(zone.tz)
	return ui.column({
		key = key,
		gap = 6,
		paddingH = 14,
		paddingV = 12,
		radius = 12,
		fill = "surface_container",
	}, {
		ui.row({ align = "center", gap = 8 }, {
			ui.column({ flexGrow = 1, gap = 3 }, {
				ui.label({ text = str(zone.label ~= nil and zone.label or zone.tz), fontSize = 15, fontWeight = "bold", maxLines = 1 }),
				ui.label({ text = dateLine(zone), fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
			}),
			ui.column({ align = "end", gap = 2 }, {
				ui.label({ text = str(zone.time), fontSize = 22, fontWeight = "bold", color = "on_surface" }),
				ui.label({ text = sub, fontSize = 11, color = "on_surface_variant" }),
			}),
		}),
		dayBar(zone, key .. "-bar"),
	})
end


local function sectionTitle(text, glyph, key)
	return ui.row({ key = key, align = "center", gap = 6, paddingH = 4 }, {
		ui.glyph({ name = glyph, size = 14, color = "primary" }),
		ui.label({ text = text, fontSize = 12, fontWeight = "bold", color = "on_surface_variant" }),
	})
end

-- "2026-11-23T09:30" -> "09:30"
local function hm(iso)
	return string.sub(str(iso), 12, 16)
end

local function eventRow(e, i)
	local when = e.all_day == true and "all day" or `{hm(e.start)}-{hm(e["end"])}`
	local lines = {
		ui.label({ text = str(e.summary), fontSize = 13, maxLines = 1 }),
	}
	if str(e.location) ~= "" then
		table.insert(lines, ui.label({ text = str(e.location), fontSize = 10, color = "on_surface_variant", maxLines = 1 }))
	end
	return ui.row({ key = "event-" .. i, align = "center", gap = 10, paddingH = 12, paddingV = 8, radius = 10, fill = "surface_container" }, {
		ui.box({ width = 3, height = 28, radius = 2, fill = e.all_day == true and "tertiary" or "primary" }),
		ui.label({ text = when, fontSize = 12, fontWeight = "bold", color = "on_surface", width = 82 }),
		ui.column({ flexGrow = 1, gap = 1 }, lines),
	})
end

local function agendaCards()
	local out = {}
	local events = agenda and agenda.events or nil
	if type(events) ~= "table" or #events == 0 then
		return out
	end
	local shown = ""
	for i, e in ipairs(events) do
		if type(e) == "table" then
			if str(e.day) ~= shown then
				shown = str(e.day)
				table.insert(out, sectionTitle(shown == str(agenda.today) and "Today" or "Tomorrow", "calendar", "day-" .. shown))
			end
			table.insert(out, eventRow(e, i))
		end
	end
	return out
end

local function reminderCards()
	local out = {}
	local list = reminders and reminders.reminders or nil
	if type(list) ~= "table" or #list == 0 then
		return out
	end
	table.insert(out, sectionTitle("Reminders", "bell", "reminders-title"))
	for _, r in ipairs(list) do
		if type(r) == "table" then
			local id = str(r.id)
			local today = agenda ~= nil and string.sub(str(r.at), 1, 10) == str(agenda.today)
			local when = today and hm(r.at) or `{string.sub(str(r.at), 6, 10)} {hm(r.at)}`
			table.insert(out, ui.row({ key = "reminder-" .. id, align = "center", gap = 10, paddingH = 12, paddingV = 6, radius = 10, fill = r.due == true and "error_container" or "surface_container" }, {
				ui.glyph({ name = r.due == true and "bell-ringing" or "bell", size = 16, color = r.due == true and "error" or "secondary" }),
				ui.label({ text = when, fontSize = 12, fontWeight = "bold", width = 82 }),
				ui.label({ text = str(r.text), fontSize = 13, flexGrow = 1, maxLines = 1 }),
				ui.button({
					glyph = "check",
					variant = "ghost",
					controlSize = "sm",
					tooltip = "Done",
					onClick = function()
						bxrig.run({ "remind", "done", id }, function()
							fetchExtras()
						end)
					end,
				}),
			}))
		end
	end
	return out
end

local function render()
	local sections = {}

	-- Header: "It's 15:48 here in Fort Lauderdale", then the title with a globe.
	local here = data and data.here or nil
	local hereText = ""
	if type(here) == "table" and str(here.time) ~= "" then
		hereText = str(here.city) ~= "" and `It's {here.time} here in {here.city}` or `It's {here.time} here`
	end
	local buttons = {
		ui.button({
			glyph = "refresh",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Refresh",
			onClick = "onRefresh",
		}),
	}
	if closeButton then
		for _, b in ipairs(bxrig.windowButtons({ plugin = "bxrig/clock", panel = "panel", tui = nil })) do
			table.insert(buttons, b)
		end
table.insert(buttons, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }))
	end
	-- The buttons sit right of the title; an equal-width spacer on the left
	-- keeps the title centered.
	local buttonsWidth = #buttons * 36
	table.insert(sections, ui.column({ align = "stretch", gap = 2, paddingV = 2 }, {
		ui.label({ text = hereText, fontSize = 12, color = "on_surface_variant", maxLines = 1, textAlign = "center" }),
		ui.row({ align = "center", gap = 8 }, {
			ui.spacer({ width = buttonsWidth }),
			ui.spacer({ flexGrow = 1 }),
			ui.glyph({ name = "clock", size = 22, color = "primary" }),
			ui.label({ text = "Clock", fontSize = 18, fontWeight = "bold" }),
			ui.spacer({ flexGrow = 1 }),
			ui.row({ width = buttonsWidth, gap = 4, justify = "end", align = "center" }, buttons),
		}),
	}))

	local zones = data and data.zones or nil
	if data == nil then
		local text = errorText ~= nil and errorText or "Loading…"
		table.insert(sections, ui.column({ paddingV = 16, align = "center", gap = 6 }, {
			ui.glyph({ name = errorText ~= nil and "alert-triangle" or "loader", size = 20, color = errorText ~= nil and "error" or "on_surface_variant" }),
			ui.label({ text = text, fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 4 }),
		}))
	elseif type(zones) ~= "table" or #zones == 0 then
		table.insert(sections, ui.label({
			text = "No world clocks configured. Add some with bxrig.",
			fontSize = 12,
			color = "on_surface_variant",
			textAlign = "center",
		}))
		local extras = agendaCards()
		for _, c in ipairs(reminderCards()) do
			table.insert(extras, c)
		end
		if #extras > 0 then
			table.insert(sections, ui.scroll({ flexGrow = 1, gap = 8 }, extras))
		end
	else
		local cards = {}
		for i, zone in ipairs(zones) do
			if type(zone) == "table" then
				table.insert(cards, zoneCard(zone, i))
			end
		end
		for _, c in ipairs(agendaCards()) do
			table.insert(cards, c)
		end
		for _, c in ipairs(reminderCards()) do
			table.insert(cards, c)
		end
		table.insert(sections, ui.scroll({ flexGrow = 1, gap = 8 }, cards))
		if errorText ~= nil then
			table.insert(sections, ui.label({ text = errorText, fontSize = 10, color = "error", maxLines = 2 }))
		end
	end

	table.insert(sections, ui.button({
		text = "Open calendar",
		glyph = "calendar",
		variant = "secondary",
		contentAlign = "center",
		onClick = "onCalendar",
	}))

	panel.render(ui.column({ flexGrow = 1, gap = 10, padding = 10 }, sections))
end

-- The agenda and the reminders: a failure leaves the section out (no calendars, an older bxrig).
function fetchExtras()
	bxrig.json({ "calendar", "agenda", "--days=2", "--json" }, function(result, err)
		agenda = err == nil and result or nil
		render()
	end)
	bxrig.json({ "remind", "list", "--json" }, function(result, err)
		reminders = err == nil and result or nil
		render()
	end)
end

local function fetch()
	if loading then
		return
	end
	loading = true
	lastFetchMs = noctalia.nowMs()
	fetchExtras()
	bxrig.json({ "time", "world", "--json" }, function(result, err)
		loading = false
		if err ~= nil then
			errorText = err
		else
			data = result
			errorText = nil
		end
		render()
	end)
end

function onRefresh()
	fetch()
end

function onCalendar()
	panel.close()
	noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "calendar" })
end

function onCloseClicked()
	panel.close()
end

function onOpen(_context)
	closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
	panel.setWantsSecondTicks(true)
	render()
	fetch()
end

function onClose()
	panel.setWantsSecondTicks(false)
end

function update()
	if noctalia.nowMs() - lastFetchMs >= REFRESH_MS then
		fetch()
	end
end
