--!nonstrict
-- BxRig Clock panel, two pages behind two tabs (each with an icon):
--   Clocks     "It's HH:MM here in <city>", one card per zone (date, big time, abbreviation and offset, a day bar with a sun or moon), the
--              agenda of today and tomorrow, and the next reminders with "+ New" and "All".
--   Reminders  a text input and a time (in 10 min, in 1 h, tonight 20:00, tomorrow 09:00, or at HH:MM), the reminders still to come with Done
--              and Remove, and Clear all (asks twice). Add: `bxrig remind TEXT --in=1h|--at=20:00|--at="tomorrow 09:00"`.
--
-- Data: `bxrig time world --json` every 30 s while open; `calendar agenda --days=2 --json`; `remind list --json`. Done, Remove and Clear all run
-- `remind done|remove ID` and `remind clear --yes`. The Calendar button opens the Noctalia calendar (`noctalia msg panel-toggle control-center calendar`).
-- Opened from the bar it is the attached popup (panel), or its window twin (panel-window). `noctalia msg panel-open bxrig/clock:panel reminders`
-- (the key Super+Ctrl+R) starts on the Reminders page. Built on framework.luau and kit.luau.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")
local framework = require("./framework.luau")

local REFRESH_MS = 30000

-- The times a reminder can be set for. `at`/`delay` are what `bxrig remind` takes; `say` is what the confirmation shows.
local CHOICES = {
	{ id = "10m", label = "in 10 min", delay = "10m", say = "in 10 minutes" },
	{ id = "1h", label = "in 1 h", delay = "1h", say = "in 1 hour" },
	{ id = "tonight", label = "tonight 20:00", at = "20:00", say = "tonight at 20:00" },
	{ id = "tomorrow", label = "tomorrow 09:00", at = "tomorrow 09:00", say = "tomorrow at 09:00" },
	{ id = "custom", label = "at…", custom = true },
}

local str = kit.str
local P

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

-- A section title, with optional buttons on the right.
local function sectionTitle(text, glyph, key, buttons)
	local children = {
		ui.glyph({ name = glyph, size = 14, color = "primary" }),
		ui.label({ text = text, fontSize = 12, fontWeight = "bold", color = "on_surface_variant", flexGrow = 1 }),
	}
	for _, b in ipairs(buttons or {}) do
		table.insert(children, b)
	end
	return ui.row({ key = key, align = "center", gap = 6, paddingH = 4 }, children)
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

local function agendaCards(s)
	local out = {}
	local events = s.agenda and s.agenda.events or nil
	if type(events) ~= "table" or #events == 0 then
		return out
	end
	local shown = ""
	for i, e in ipairs(events) do
		if type(e) == "table" then
			if str(e.day) ~= shown then
				shown = str(e.day)
				table.insert(out, sectionTitle(shown == str(s.agenda.today) and "Today" or "Tomorrow", "calendar", "day-" .. shown))
			end
			table.insert(out, eventRow(e, i))
		end
	end
	return out
end

local function reminderList(s)
	local list = s.reminders and s.reminders.reminders or nil
	if type(list) ~= "table" then
		return {}
	end
	return list
end

local function loadReminders()
	P:fetch({ "remind", "list" }, function(data)
		P.state.reminders = data
	end, { channel = "reminders" })
end

-- One reminder row. `full` adds Remove next to Done (the Reminders page); the Clocks page keeps just Done.
local function reminderRow(s, r, full)
	local id = str(r.id)
	local today = s.agenda ~= nil and string.sub(str(r.at), 1, 10) == str(s.agenda.today)
	local when = today and hm(r.at) or `{string.sub(str(r.at), 6, 10)} {hm(r.at)}`
	local due = r.due == true
	local buttons = {
		ui.button({
			glyph = "check",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Done",
			onClick = function()
				P:run({ "remind", "done", id }, function()
					loadReminders()
				end)
			end,
		}),
	}
	if full then
		table.insert(buttons, ui.button({
			glyph = "x",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Remove",
			onClick = function()
				P:run({ "remind", "remove", id }, function()
					loadReminders()
				end)
			end,
		}))
	end
	local children = {
		ui.glyph({ name = due and "bell-ringing" or "bell", size = 16, color = due and "error" or "secondary" }),
		ui.label({ text = when, fontSize = 12, fontWeight = "bold", width = 82 }),
		ui.label({ text = str(r.text), fontSize = 13, flexGrow = 1, maxLines = 1 }),
	}
	for _, b in ipairs(buttons) do
		table.insert(children, b)
	end
	return ui.row({ key = "reminder-" .. id, align = "center", gap = 8, paddingH = 12, paddingV = 6, radius = 10, fill = due and "error_container" or "surface_container" }, children)
end

local function gotoPage(page)
	P:set({ page = page })
end

-- The reminders section of the Clocks page: the next three, "+ New" and "All".
local function reminderSummary(s)
	local list = reminderList(s)
	local out = {}
	if #list == 0 then
		return out
	end
	table.insert(out, sectionTitle("Reminders", "bell", "reminders-title", {
		ui.button({
			text = "New",
			glyph = "plus",
			variant = "ghost",
			controlSize = "sm",
			onClick = function()
				gotoPage("reminders")
			end,
		}),
		ui.button({
			text = "All",
			variant = "ghost",
			controlSize = "sm",
			onClick = function()
				gotoPage("reminders")
			end,
		}),
	}))
	for i, r in ipairs(list) do
		if i > 3 then
			break
		end
		if type(r) == "table" then
			table.insert(out, reminderRow(s, r, false))
		end
	end
	return out
end

-- The current local hour from "It's HH:MM here", to hide "tonight" once 20:00 has passed (nil when unknown).
local function localHour(s)
	local t = s.data and s.data.here and s.data.here.time or nil
	if t == nil then
		return nil
	end
	return tonumber(string.match(str(t), "^(%d+):"))
end

local function choiceById(id)
	for _, c in ipairs(CHOICES) do
		if c.id == id then
			return c
		end
	end
	return CHOICES[2]
end

local function validTime(text)
	local h, m = string.match(noctalia.string.trim(text), "^(%d%d?):(%d%d)$")
	if h == nil then
		return nil
	end
	if tonumber(h) > 23 or tonumber(m) > 59 then
		return nil
	end
	return noctalia.string.trim(text)
end

-- What the confirmation line says for the chosen time, or nil when the custom time is not valid yet.
local function sayWhen(s)
	local c = choiceById(s.choice)
	if c.custom then
		local t = validTime(s.customTime)
		return t ~= nil and ("at " .. t) or nil
	end
	return c.say
end

local function remindArgs(s, text)
	local c = choiceById(s.choice)
	if c.custom then
		return { "remind", text, "--at=" .. (validTime(s.customTime) or "") }
	elseif c.delay ~= nil then
		return { "remind", text, "--in=" .. c.delay }
	end
	return { "remind", text, "--at=" .. c.at }
end

-- Adds the reminder from the draft and the chosen time (Enter, or the Add button).
local function addReminder(self)
	local s = self.state
	local text = noctalia.string.trim(s.draft)
	if text == "" then
		self:set({ addErr = "Type what to be reminded about", addMsg = nil })
		return
	end
	local when = sayWhen(s)
	if when == nil then
		self:set({ addErr = "Type a time as HH:MM, for example 14:30", addMsg = nil })
		return
	end
	self:run(remindArgs(s, text), function(ok, message)
		if ok then
			P:set({ draft = "", inputKey = P.state.inputKey + 1, addMsg = "Added: " .. text .. " · " .. when, addErr = nil })
			loadReminders()
		else
			P:set({ addErr = message ~= "" and message or "Could not add the reminder", addMsg = nil })
		end
	end)
end

local function remindersPage(s)
	local rows = {}
	local list = reminderList(s)

	-- The input and the time chips.
	local chips = {}
	local hour = localHour(s)
	for _, c in ipairs(CHOICES) do
		if not (c.id == "tonight" and hour ~= nil and hour >= 20) then
			table.insert(chips, ui.button({
				key = "when-" .. c.id,
				text = c.label,
				variant = c.id == s.choice and "primary" or "secondary",
				controlSize = "sm",
				onClick = function()
					P:set({ choice = c.id, addErr = nil })
				end,
			}))
		end
	end
	table.insert(rows, ui.input({
		key = "draft-" .. s.inputKey,
		value = s.draft,
		placeholder = "Remind me to…",
		fontSize = 15,
		focus = true,
		onChange = "onDraftChanged",
		onSubmit = "onSubmit",
	}))
	-- Two rows: the five chips do not fit the 380 px popup on one.
	local firstRow = {}
	local secondRow = {}
	for i, chip in ipairs(chips) do
		table.insert(i <= 3 and firstRow or secondRow, chip)
	end
	table.insert(rows, ui.row({ gap = 6 }, firstRow))
	table.insert(rows, ui.row({ gap = 6, paddingV = 2 }, secondRow))
	if choiceById(s.choice).custom then
		table.insert(rows, ui.input({
			key = "time-" .. s.inputKey,
			value = s.customTime,
			placeholder = "Time, for example 14:30",
			fontSize = 14,
			onChange = "onTimeChanged",
			onSubmit = "onSubmit",
		}))
	end
	local say = sayWhen(s)
	table.insert(rows, ui.row({ align = "center", gap = 8 }, {
		ui.label({ text = say ~= nil and ("Will pop up " .. say) or "Pick a time", fontSize = 11, color = "on_surface_variant", flexGrow = 1 }),
		ui.button({ text = "Add reminder  ↵", variant = "primary", controlSize = "sm", onClick = "onSubmit" }),
	}))
	if s.addMsg ~= nil then
		table.insert(rows, ui.label({ text = s.addMsg, fontSize = 12, color = "primary", maxLines = 2 }))
	end
	if s.addErr ~= nil then
		table.insert(rows, ui.label({ text = s.addErr, fontSize = 12, color = "error", maxLines = 3 }))
	end

	-- The list.
	table.insert(rows, sectionTitle("Coming up", "bell", "coming-title"))
	if #list == 0 then
		table.insert(rows, ui.label({ text = "No reminders yet", fontSize = 12, color = "on_surface_variant" }))
	end
	for _, r in ipairs(list) do
		if type(r) == "table" then
			table.insert(rows, reminderRow(s, r, true))
		end
	end
	return rows
end

local function clocksPage(s)
	local zones = s.data and s.data.zones or nil
	local cards = {}
	if s.data == nil then
		local text = s.error ~= nil and s.error or "Loading…"
		return {
			ui.column({ paddingV = 16, align = "center", gap = 6 }, {
				ui.glyph({ name = s.error ~= nil and "alert-triangle" or "loader", size = 20, color = s.error ~= nil and "error" or "on_surface_variant" }),
				ui.label({ text = text, fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 4 }),
			}),
		}
	end
	if type(zones) ~= "table" or #zones == 0 then
		table.insert(cards, ui.label({ text = "No world clocks configured. Add some with bxrig.", fontSize = 12, color = "on_surface_variant", textAlign = "center" }))
	else
		for i, zone in ipairs(zones) do
			if type(zone) == "table" then
				table.insert(cards, zoneCard(zone, i))
			end
		end
	end
	for _, c in ipairs(agendaCards(s)) do
		table.insert(cards, c)
	end
	for _, c in ipairs(reminderSummary(s)) do
		table.insert(cards, c)
	end
	return cards
end

local function view(self)
	local s = self.state
	local sections = {}

	-- Header: "It's 15:48 here in Fort Lauderdale", then the title with a clock icon and the buttons.
	local here = s.data and s.data.here or nil
	local hereText = ""
	if type(here) == "table" and str(here.time) ~= "" then
		hereText = str(here.city) ~= "" and `It's {here.time} here in {here.city}` or `It's {here.time} here`
	end
	local buttons = {
		ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Refresh", onClick = "onRefresh" }),
	}
	if s.closeButton then
		for _, b in ipairs(bxrig.windowButtons({ plugin = "bxrig/clock", panel = "panel", tui = nil })) do
			table.insert(buttons, b)
		end
		table.insert(buttons, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }))
	end
	-- The buttons sit right of the title; an equal-width spacer on the left keeps the title centered.
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

	-- The two tabs, each with its icon; the Reminders tab shows how many are waiting.
	local count = #reminderList(s)
	table.insert(sections, kit.tabRow({
		tabs = {
			{ "clocks", "Clocks", "clock" },
			{ "reminders", count > 0 and ("Reminders · " .. count) or "Reminders", "bell" },
		},
		current = s.page,
		onSelect = gotoPage,
		gap = 6,
		paddingH = 4,
	}))

	if s.page == "reminders" then
		table.insert(sections, ui.scroll({ flexGrow = 1, gap = 8 }, remindersPage(s)))
		local armed = s.armedClear
		table.insert(sections, kit.footer({
			hint = count == 0 and "Nothing to clear" or (count .. (count == 1 and " reminder" or " reminders")),
			buttons = {
				ui.button({
					text = armed and "Click again to clear all" or "Clear all",
					glyph = "trash",
					variant = "ghost",
					controlSize = "sm",
					enabled = count > 0,
					onClick = "onClearAll",
				}),
			},
		}))
	else
		table.insert(sections, ui.scroll({ flexGrow = 1, gap = 8 }, clocksPage(s)))
		if s.error ~= nil and s.data ~= nil then
			table.insert(sections, ui.label({ text = s.error, fontSize = 10, color = "error", maxLines = 2 }))
		end
		table.insert(sections, ui.button({ text = "Open calendar", glyph = "calendar", variant = "secondary", contentAlign = "center", onClick = "onCalendar" }))
	end

	return ui.column({ flexGrow = 1, gap = 10, padding = 10 }, sections)
end

-- Everything the panel shows: the zones (main channel, drives loading and error), the agenda and the reminders (a failure leaves the section out).
local function loadAll()
	P.state.lastFetchMs = noctalia.nowMs()
	P:fetch({ "calendar", "agenda", "--days=2" }, function(data)
		P.state.agenda = data
	end, { channel = "agenda", onError = function() P.state.agenda = nil end })
	loadReminders()
	P:fetch({ "time", "world" }, function(data)
		P.state.data = data
	end)
end

P = framework.panel({
	plugin = "bxrig/clock",
	id = "panel",
	state = function()
		return {
			page = "clocks",
			data = nil,
			agenda = nil,
			reminders = nil,
			closeButton = true,
			draft = "",
			customTime = "",
			choice = "1h",
			inputKey = 1,
			addMsg = nil,
			addErr = nil,
			armedClear = false,
			lastFetchMs = 0,
		}
	end,
	open = function(self, context)
		self.state.closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
		if context == "reminders" then
			self.state.page = "reminders"
		end
		panel.setWantsSecondTicks(true)
		loadAll()
	end,
	view = view,
	submit = addReminder,
})

-- The host calls these globals by name.
function onOpen(context)
	P:open(context)
end

function onClose()
	panel.setWantsSecondTicks(false)
end

function onKey(chord, pressed)
	P:key(chord, pressed)
end

function update()
	if P.state.lastFetchMs ~= nil and noctalia.nowMs() - P.state.lastFetchMs >= REFRESH_MS then
		loadAll()
	end
end

function onRefresh()
	loadAll()
end

function onDraftChanged(value)
	P.state.draft = value or ""
	P.state.addMsg = nil
	P.state.addErr = nil
end

function onTimeChanged(value)
	P.state.customTime = value or ""
	P.state.addErr = nil
end

function onSubmit()
	P:submit()
end

function onClearAll()
	if not P.state.armedClear then
		P:set({ armedClear = true })
		return
	end
	P.state.armedClear = false
	P:run({ "remind", "clear", "--yes" }, function()
		loadReminders()
	end)
	P:render()
end

function onCalendar()
	panel.close()
	noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "calendar" })
end

function onCloseClicked()
	panel.close()
end
