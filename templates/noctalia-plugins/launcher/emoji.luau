--!nonstrict
-- BxRig Emoji: a grid of emoji with category tabs, a filter and a Recent tab, in the Noctalia look.
--
-- Keys: type to filter, arrows move over the grid, PageUp/PageDown jump three rows, Tab goes to the next category, Enter copies the emoji and
-- closes, Esc closes. Mouse: one click on an emoji copies it and closes the panel; the tabs work by click.
-- Data: `bxrig emoji list [QUERY] [--category=C] --limit=N --json` and `bxrig emoji recent --json` (rows: emoji, name, category, keywords);
-- Enter runs `bxrig emoji copy EMOJI`, which puts it on the clipboard and into Recent. One command per keystroke or tab; a kit.sequence drops
-- answers that arrive late. Built from kit.luau (search row, tabs, grid, footer, guards). Emoji data: gemoji (MIT).
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local PLUGIN = "bxrig/launcher"
local COLUMNS = 12
local CELL = 56
local GRID_H = 400

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

local str = kit.str
local latest = kit.sequence()
local submitOnce = kit.once(300)

local rows = {}
local tab = 2
local selected = 1
local query = ""
local inputKey = 0
local errorText = nil
local loading = false
local tabChosen = false

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
		-- One click copies the emoji and closes the panel.
		onClick = function()
			selected = i
			onSubmit()
		end,
	}, {
		ui.label({ text = str(e.emoji), fontSize = 28, textAlign = "center" }),
	})
end

function render()
	local labels = {}
	for i, t in ipairs(TABS) do
		table.insert(labels, { i, t.label })
	end

	local cells = {}
	for i, e in ipairs(rows) do
		table.insert(cells, cell(i, e))
	end
	local lines = kit.grid({ items = cells, columns = COLUMNS, gap = 2 })
	if loading and #rows == 0 then
		table.insert(lines, ui.label({ text = "Loading…", fontSize = 13, color = "on_surface_variant" }))
	elseif errorText ~= nil then
		table.insert(lines, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 6 }))
	elseif #rows == 0 then
		local why = (query == "" and tab == 1) and "Nothing copied yet" or "No emoji matches"
		table.insert(lines, ui.label({ text = why, fontSize = 13, color = "on_surface_variant" }))
	end
	local sel = selectedRow()

	local hint = "Arrows move, Enter copies, Tab changes category"
	if sel ~= nil then
		hint = str(sel.emoji) .. "  " .. str(sel.name)
	end

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, {
		kit.searchRow({ key = "search-" .. inputKey, value = query, placeholder = "Search emoji…", count = #rows }),
		kit.tabRow({ tabs = labels, current = query == "" and tab or nil, onSelect = setTab, gap = 2, paddingH = 8 }),
		ui.separator({}),
		ui.column({ height = GRID_H }, {
			ui.scroll({ flexGrow = 1, gap = 2, padding = 8, revealKey = sel and ("e-" .. selected) or nil }, lines),
		}),
		kit.footer({
			hint = hint,
			hintSize = 13,
			buttons = {
				kit.windowButton(PLUGIN, "emoji"),
				ui.button({ text = "Copy  ↵", variant = "primary", controlSize = "sm", enabled = sel ~= nil, onClick = "onSubmit" }),
			},
		}),
	}))
end

-- Loads what the search box and the tab ask for.
local function fetch()
	local mine = latest.next()
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
		if not latest.isCurrent(mine) then
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
	selected = kit.clamp(selected, delta, #rows)
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
	if not submitOnce() then
		return
	end
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
		kit.swap(PLUGIN, "emoji")
	elseif chord == "Return" or chord == "KP_Enter" then
		onSubmit()
	end
end

function onOpen(_context)
	if bxrig.isWindow() then
		local w, h = kit.screenSize()
		COLUMNS = math.max(10, math.floor((w - 100) / (CELL + 4)))
		GRID_H = math.max(400, math.floor(h - 340))
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
