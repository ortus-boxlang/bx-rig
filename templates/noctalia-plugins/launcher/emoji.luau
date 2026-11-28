--!nonstrict
-- BxRig Emoji: a grid of emoji with category tabs, a filter and a Recent tab, in the Noctalia look.
--
-- Keys: type to filter, arrows move over the grid, PageUp/PageDown jump three rows, Tab goes to the next category, Enter copies the emoji and
-- closes, Esc closes. Mouse: click an emoji to highlight it, click it again to copy it; the tabs work by click.
-- Data: `bxrig emoji list [QUERY] [--category=C] --limit=N --json` and `bxrig emoji recent --json` (rows: emoji, name, category, keywords);
-- Enter runs `bxrig emoji copy EMOJI`, which puts it on the clipboard and into Recent. One command per keystroke or tab; a counter drops
-- answers that arrive late. Emoji data: gemoji (MIT).
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")

local COLUMNS = 10
local CELL = 56
local GRID_H = 400

-- Window mode: the second [[panel]] entry of this script sets `window = true` and a "fill" size; F3 swaps between the popup and the window.
-- The script cannot ask its own size, so it reads the focused output (noctalia.outputs) and keeps a margin.
local WINDOW = noctalia.getConfig("window") == true

local function screenSize()
	local list = noctalia.outputs() or {}
	local focus = noctalia.focusedOutputName()
	for _, o in ipairs(list) do
		if focus == nil or o.name == focus then
			local scale = tonumber(o.scale) or 1
			if scale <= 0 then
				scale = 1
			end
			return (tonumber(o.width) or 1280) / scale, (tonumber(o.height) or 800) / scale
		end
	end
	return 1280, 800
end

local function swapWindow()
	local base = "bxrig/launcher:emoji"
	panel.close()
	noctalia.togglePanel(WINDOW and base or (base .. "-window"))
end

-- The tab label and the word `emoji list --category` takes (a part of the category name).
local TABS = {
	{ label = "Recent", category = "" },
	{ label = "Smileys", category = "Smileys" },
	{ label = "People", category = "People" },
	{ label = "Nature", category = "Animals" },
	{ label = "Food", category = "Food" },
	{ label = "Travel", category = "Travel" },
	{ label = "Activities", category = "Activities" },
	{ label = "Objects", category = "Objects" },
	{ label = "Symbols", category = "Symbols" },
	{ label = "Flags", category = "Flags" },
}

local rows = {}
local tab = 2
local selected = 1
local query = ""
local inputKey = 0
local errorText = nil
local loading = false
local request = 0
local lastSubmitMs = 0
local tabChosen = false

local function str(v)
	if v == nil then
		return ""
	end
	return tostring(v)
end

local function selectedRow()
	return rows[selected]
end

local function cell(i, e)
	local isSel = i == selected
	return ui.column({
		key = "e-" .. i,
		width = CELL,
		height = CELL,
		radius = 14,
		align = "center",
		justify = "center",
		-- An explicit transparent fill: a nil fill keeps the retained one.
		fill = isSel and "primary/0.18" or "on_surface/0",
		onClick = function()
			if i == selected then
				onSubmit()
			else
				selected = i
				render()
			end
		end,
	}, {
		ui.label({ text = str(e.emoji), fontSize = 28, textAlign = "center" }),
	})
end

function render()
	local search = ui.row({ align = "center", gap = 10, paddingH = 14, paddingV = 6 }, {
		ui.glyph({ name = "search", size = 18, color = "on_surface_variant" }),
		ui.input({
			key = "search-" .. inputKey,
			value = query,
			placeholder = "Search emoji…",
			fontSize = 16,
			frameVisible = false,
			focus = true,
			flexGrow = 1,
			onChange = "onQueryChanged",
			onSubmit = "onSubmit",
		}),
		ui.label({ text = tostring(#rows), fontSize = 11, color = "on_surface_variant" }),
	})

	local chips = {}
	for i, t in ipairs(TABS) do
		table.insert(chips, ui.button({
			key = "tab-" .. t.label,
			text = t.label,
			variant = (query == "" and i == tab) and "secondary" or "ghost",
			controlSize = "sm",
			onClick = function()
				setTab(i)
			end,
		}))
	end
	local tabs = ui.row({ gap = 2, paddingH = 8, paddingV = 2 }, chips)

	local lines = {}
	local current = {}
	for i, e in ipairs(rows) do
		table.insert(current, cell(i, e))
		if #current == COLUMNS then
			table.insert(lines, ui.row({ gap = 2, justify = "center" }, current))
			current = {}
		end
	end
	if #current > 0 then
		table.insert(lines, ui.row({ gap = 2, justify = "start" }, current))
	end
	if loading and #rows == 0 then
		table.insert(lines, ui.label({ text = "Loading…", fontSize = 13, color = "on_surface_variant" }))
	elseif errorText ~= nil then
		table.insert(lines, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 6 }))
	elseif #rows == 0 then
		local why = (query == "" and tab == 1) and "Nothing copied yet" or "No emoji matches"
		table.insert(lines, ui.label({ text = why, fontSize = 13, color = "on_surface_variant" }))
	end
	local sel = selectedRow()
	local grid = ui.column({ height = GRID_H }, {
		ui.scroll({ flexGrow = 1, gap = 2, padding = 8, revealKey = sel and ("e-" .. selected) or nil }, lines),
	})

	local hint = "Arrows move, Enter copies, Tab changes category"
	if sel ~= nil then
		hint = str(sel.emoji) .. "  " .. str(sel.name)
	end
	local footer = ui.row({ align = "center", gap = 8, paddingH = 14, paddingV = 8, fill = "surface_container", radius = 10 }, {
		ui.label({ text = hint, fontSize = 13, color = "on_surface_variant", flexGrow = 1, maxLines = 1 }),
		ui.button({ text = WINDOW and "Popup  F3" or "Window  F3", glyph = "arrows-maximize", variant = "ghost", controlSize = "sm", onClick = "onSwap" }),
		ui.button({ text = "Copy  ↵", variant = "primary", controlSize = "sm", enabled = sel ~= nil, onClick = "onSubmit" }),
	})

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, { search, tabs, ui.separator({}), grid, footer }))
end

-- Loads what the search box and the tab ask for.
local function fetch()
	request += 1
	local mine = request
	loading = true
	local q = noctalia.string.trim(query)
	local args
	if q ~= "" then
		args = { "emoji", "list", q, "--limit=150", "--json" }
	elseif TABS[tab].category == "" then
		args = { "emoji", "recent", "--limit=60", "--json" }
	else
		args = { "emoji", "list", "--category=" .. TABS[tab].category, "--limit=400", "--json" }
	end
	bxrig.json(args, function(result, err)
		if mine ~= request then
			return
		end
		loading = false
		if err ~= nil then
			errorText = err
			rows = {}
		else
			errorText = nil
			rows = type(result.emoji) == "table" and result.emoji or {}
		end
		-- Nothing copied yet: open on the faces instead of an empty page.
		if q == "" and tab == 1 and #rows == 0 and errorText == nil and not tabChosen then
			tab = 2
			fetch()
			return
		end
		selected = 1
		render()
	end, 15000)
end

function setTab(i)
	tabChosen = true
	tab = i
	query = ""
	inputKey += 1
	selected = 1
	fetch()
	render()
end

local function move(delta)
	if #rows == 0 then
		return
	end
	selected = math.max(1, math.min(#rows, selected + delta))
	render()
end

function onQueryChanged(value)
	query = value or ""
	selected = 1
	fetch()
	render()
end

function onSubmit()
	-- Enter can reach us both through the input's onSubmit and onKey("Return").
	local now = noctalia.nowMs()
	if now - lastSubmitMs < 300 then
		return
	end
	lastSubmitMs = now
	local e = selectedRow()
	if e == nil then
		return
	end
	bxrig.run({ "emoji", "copy", str(e.emoji) }, function(ok, message)
		if ok then
			noctalia.notify("Emoji", str(e.emoji) .. "  copied")
		else
			noctalia.notifyError("Emoji", message ~= "" and message or "Could not copy the emoji")
		end
	end, 15000)
	panel.close()
end

function onKey(chord, pressed)
	if not pressed then
		return
	end
	if chord == "Up" then
		move(-COLUMNS)
	elseif chord == "Down" then
		move(COLUMNS)
	elseif chord == "Left" then
		move(-1)
	elseif chord == "Right" then
		move(1)
	elseif chord == "Page_Up" then
		move(-COLUMNS * 3)
	elseif chord == "Page_Down" then
		move(COLUMNS * 3)
	elseif chord == "Tab" then
		setTab((tab % #TABS) + 1)
	elseif chord == "F3" then
		swapWindow()
	elseif chord == "Return" or chord == "KP_Enter" then
		onSubmit()
	end
end

function onSwap()
	swapWindow()
end

function onOpen(_context)
	if WINDOW then
		local w, h = screenSize()
		COLUMNS = math.max(10, math.floor((w - 100) / (CELL + 4)))
		GRID_H = math.max(400, math.floor(h - 220))
	end
	tab = 1
	tabChosen = false
	query = ""
	inputKey += 1
	errorText = nil
	selected = 1
	rows = {}
	render()
	fetch()
end
