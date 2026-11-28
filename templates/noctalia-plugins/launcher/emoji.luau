--!nonstrict
-- BxRig Emoji: a grid of emoji with category tabs, a filter and a Recent tab, in the Noctalia look.
--
-- Keys: type to filter, arrows move over the grid, PageUp/PageDown jump three rows, Tab goes to the next category, Enter copies the emoji and
-- closes, Esc closes. Mouse: one click on an emoji copies it and closes the panel; the tabs work by click.
-- Data: `bxrig emoji list [QUERY] [--category=C] --limit=N --json` and `bxrig emoji recent --json` (rows: emoji, name, category, keywords);
-- Enter runs `bxrig emoji copy EMOJI`, which puts it on the clipboard and into Recent. One command per keystroke or tab; a kit.sequence drops
-- answers that arrive late. Built on framework.luau (state, fetch, keys, popup and window) with the kit (search row, tabs, grid, footer). Emoji data: gemoji (MIT).
-- Colors are palette roles only, so the panel follows the active theme.

local framework = require("./framework.luau")
local kit = require("./kit.luau")

local CELL = 56

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
local P

local function cell(i, e)
	local isSel = i == P.state.selected
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
			P.state.selected = i
			P:submit()
		end,
	}, {
		ui.label({ text = str(e.emoji), fontSize = 28, textAlign = "center" }),
	})
end

-- Loads what the search box and the tab ask for.
local function reloadRows()
	local s = P.state
	local q = noctalia.string.trim(s.query)
	local args
	if q ~= "" then
		args = { "emoji", "list", q, "--limit=150" }
	elseif TABS[s.tab].category == "" then
		args = { "emoji", "recent", "--limit=60" }
	else
		args = { "emoji", "list", "--category=" .. TABS[s.tab].category, "--limit=400" }
	end
	P:fetch(args, function(data)
		s.rows = type(data.emoji) == "table" and data.emoji or {}
		-- Nothing copied yet: open on the faces instead of an empty page.
		if q == "" and s.tab == 1 and #s.rows == 0 and not s.tabChosen then
			s.tab = 2
			reloadRows()
			return
		end
		s.selected = 1
	end)
end

local function setTab(i)
	P:set({ tabChosen = true, tab = i, query = "", inputKey = P.state.inputKey + 1, selected = 1 })
	reloadRows()
end

local function view(self)
	local s = self.state
	local labels = {}
	for i, t in ipairs(TABS) do
		table.insert(labels, { i, t.label })
	end
	local cells = {}
	for i, e in ipairs(s.rows) do
		table.insert(cells, cell(i, e))
	end
	local lines = kit.grid({ items = cells, columns = s.columns, gap = 2 })
	if s.loading and #s.rows == 0 then
		table.insert(lines, ui.label({ text = "Loading…", fontSize = 13, color = "on_surface_variant" }))
	elseif s.error ~= nil then
		table.insert(lines, ui.label({ text = s.error, fontSize = 12, color = "error", maxLines = 6 }))
	elseif #s.rows == 0 then
		local why = (s.query == "" and s.tab == 1) and "Nothing copied yet" or "No emoji matches"
		table.insert(lines, ui.label({ text = why, fontSize = 13, color = "on_surface_variant" }))
	end
	local sel = s.rows[s.selected]
	local hint = "Arrows move, Enter copies, Tab changes category"
	if sel ~= nil then
		hint = str(sel.emoji) .. "  " .. str(sel.name)
	end
	return framework.stack({
		kit.searchRow({ key = "search-" .. s.inputKey, value = s.query, placeholder = "Search emoji…", count = #s.rows }),
		kit.tabRow({ tabs = labels, current = s.query == "" and s.tab or nil, onSelect = setTab, gap = 2, paddingH = 8 }),
		ui.separator({}),
		framework.body(s.gridHeight, { gap = 2, padding = 8, revealKey = sel and ("e-" .. s.selected) or nil }, lines),
		kit.footer({
			hint = hint,
			hintSize = 13,
			buttons = {
				self:windowButton(),
				ui.button({ text = "Copy  ↵", variant = "primary", controlSize = "sm", enabled = sel ~= nil, onClick = "onSubmit" }),
			},
		}),
	})
end

local function step(delta)
	return function(self)
		self:move(delta, #self.state.rows)
	end
end

P = framework.panel({
	plugin = "bxrig/launcher",
	id = "emoji",
	state = function()
		return { rows = {}, tab = 1, tabChosen = false, selected = 1, query = "", inputKey = 0, columns = 12, gridHeight = 400 }
	end,
	-- window mode: more columns and a taller grid for the screen
	layout = function(self, w, h)
		self.state.columns = math.max(10, math.floor((w - 100) / (CELL + 4)))
		self.state.gridHeight = math.max(400, math.floor(h - 340))
	end,
	open = function(self)
		self.state.inputKey = 1
		reloadRows()
	end,
	view = view,
	keys = {
		Up = function(self)
			self:move(-self.state.columns, #self.state.rows)
		end,
		Down = function(self)
			self:move(self.state.columns, #self.state.rows)
		end,
		Left = step(-1),
		Right = step(1),
		Page_Up = function(self)
			self:move(-self.state.columns * 3, #self.state.rows)
		end,
		Page_Down = function(self)
			self:move(self.state.columns * 3, #self.state.rows)
		end,
		Tab = function(self)
			setTab((self.state.tab % #TABS) + 1)
		end,
	},
	submit = function(self)
		local e = self.state.rows[self.state.selected]
		if e == nil then
			return
		end
		self:run({ "emoji", "copy", str(e.emoji) }, function(ok, message)
			if ok then
				noctalia.notify("Emoji", str(e.emoji) .. "  copied")
			else
				noctalia.notifyError("Emoji", message ~= "" and message or "Could not copy the emoji")
			end
		end, 15000)
		self:close()
	end,
})

-- The host calls these globals by name.
function onOpen(context)
	P:open(context)
end

function onKey(chord, pressed)
	P:key(chord, pressed)
end

function onQueryChanged(value)
	P:set({ query = value or "", selected = 1 })
	reloadRows()
end

function onSubmit()
	P:submit()
end
