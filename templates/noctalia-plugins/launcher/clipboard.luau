--!nonstrict
-- BxRig Launcher, clipboard history: the panel `clipboard` of bxrig/launcher. A search box, the history on the left (newest first, text and
-- images), the full text of the highlighted entry on the right, "Copy ↵" and "Clear history" in the footer.
--
-- Keys: type to filter, Up/Down/PageUp/PageDown move, Enter copies the entry back to the clipboard and closes, Esc closes.
-- Mouse: click an entry to highlight it, click it again to copy it.
-- Data: `bxrig clipboard list QUERY --limit=60 --json`; the detail pane runs `bxrig clipboard show ID --json` for the highlighted entry
-- (kept for the session). Copy: `bxrig clipboard copy ID`. Clear history asks twice: the first click arms the button.
-- Needs cliphist and wl-clipboard (`bxrig install cliphist wl-clipboard`); the Hyprland setup of BxRig fills the history at login.
-- Colors are palette roles only, so the panel follows the active theme.

local framework = require("./framework.luau")
local kit = require("./kit.luau")

local str = kit.str
local P

-- The detail of the highlighted entry (kept for the session): `clipboard show ID`, on its own channel so it never drops the list.
local function loadDetail()
	local s = P.state
	local e = s.entries[s.selected]
	if e == nil or s.detail[str(e.id)] ~= nil then
		return
	end
	local id = str(e.id)
	P:fetch({ "clipboard", "show", id }, function(data)
		s.detail[id] = data
	end, {
		channel = "detail",
		onError = function()
			s.detail[id] = { kind = "text", text = str(e.preview) }
		end,
	})
end

local function loadList()
	local args = { "clipboard", "list" }
	local q = noctalia.string.trim(P.state.query)
	if q ~= "" then
		table.insert(args, q)
	end
	table.insert(args, "--limit=60")
	P:fetch(args, function(data)
		P.state.entries = type(data.entries) == "table" and data.entries or {}
		P.state.selected = 1
		loadDetail()
	end)
end

local function highlight(i)
	P.state.selected = i
	loadDetail()
	P:render()
end

local function view(self)
	local s = self.state
	local rows = {}
	if s.error ~= nil then
		table.insert(rows, ui.label({ text = s.error, fontSize = 12, color = "error", maxLines = 8 }))
	elseif #s.entries == 0 then
		table.insert(rows, ui.label({ text = s.query == "" and "The clipboard history is empty" or "No matching entries", fontSize = 13, color = "on_surface_variant" }))
	end
	for i, e in ipairs(s.entries) do
		local isSel = i == s.selected
		table.insert(rows, ui.row({
			key = "clip-" .. str(e.id),
			align = "center",
			gap = 8,
			paddingH = 12,
			paddingV = 9,
			radius = 8,
			-- An explicit transparent fill: a nil fill keeps the retained one.
			fill = isSel and "on_surface/0.08" or "on_surface/0",
			onClick = function()
				if i == s.selected then
					self:submit()
				else
					highlight(i)
				end
			end,
		}, {
			ui.glyph({ name = str(e.kind) == "image" and "photo" or "file-text", size = 16, color = "on_surface_variant" }),
			ui.label({
				text = str(e.preview),
				fontSize = 13,
				fontWeight = isSel and "semibold" or "normal",
				color = isSel and "on_surface" or "on_surface_variant",
				flexGrow = 1,
				maxLines = 1,
			}),
		}))
	end
	local sel = s.entries[s.selected]
	local list = ui.scroll({ width = 330, height = 420, gap = 2, padding = 8, revealKey = sel and ("clip-" .. str(sel.id)) or nil }, rows)

	-- Right: the highlighted entry in full.
	local right = {}
	if sel ~= nil then
		local d = s.detail[str(sel.id)]
		if d == nil then
			table.insert(right, ui.label({ text = "Loading…", fontSize = 12, color = "on_surface_variant" }))
		elseif d.kind == "image" then
			table.insert(right, ui.glyph({ name = "photo", size = 32, color = "on_surface_variant" }))
			table.insert(right, ui.label({ text = "Image", fontSize = 14, fontWeight = "semibold" }))
			table.insert(right, ui.label({ text = str(d.details), fontSize = 12, color = "on_surface_variant", maxLines = 3 }))
		else
			table.insert(right, ui.label({ text = str(d.text), fontSize = 13, maxLines = 24 }))
			if d.truncated == true then
				table.insert(right, ui.label({ text = "Shown up to 4000 characters of " .. str(d.chars), fontSize = 11, color = "on_surface_variant" }))
			end
		end
	end
	local pane = ui.scroll({ flexGrow = 1, height = 420, gap = 6, padding = 14 }, right)

	return framework.stack({
		kit.searchRow({ glyph = "clipboard", key = "search-" .. s.inputKey, value = s.query, placeholder = "Search the clipboard history…" }),
		ui.separator({}),
		ui.row({ height = 420, gap = 0, align = "start" }, { list, ui.separator({ orientation = "vertical" }), pane }),
		kit.footer({
			leading = { ui.button({ glyph = "arrow-left", text = "Launcher", variant = "ghost", controlSize = "sm", onClick = "onBack" }) },
			hint = #s.entries .. " entries",
			buttons = {
				ui.button({
					text = s.armedClear and "Click again to clear" or "Clear history",
					variant = "ghost",
					controlSize = "sm",
					onClick = "onClear",
				}),
				ui.button({ text = "Copy  ↵", variant = "primary", controlSize = "sm", enabled = sel ~= nil, onClick = "onSubmit" }),
			},
		}),
	})
end

P = framework.panel({
	plugin = "bxrig/launcher",
	id = "clipboard",
	state = function()
		return { entries = {}, selected = 1, query = "", inputKey = 1, detail = {}, armedClear = false }
	end,
	open = function()
		loadList()
	end,
	view = view,
	swappable = false,
	keys = {
		Up = function(self)
			self:move(-1, #self.state.entries)
			loadDetail()
		end,
		Down = function(self)
			self:move(1, #self.state.entries)
			loadDetail()
		end,
		Page_Up = function(self)
			self:move(-8, #self.state.entries)
			loadDetail()
		end,
		Page_Down = function(self)
			self:move(8, #self.state.entries)
			loadDetail()
		end,
	},
	submit = function(self)
		local e = self.state.entries[self.state.selected]
		if e == nil then
			return
		end
		self:run({ "clipboard", "copy", str(e.id) }, function(ok, message)
			if not ok then
				noctalia.notifyError("Clipboard", message ~= "" and message or "Could not copy the entry")
			end
		end, 30000)
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
	P.state.query = value or ""
	loadList()
end

function onSubmit()
	P:submit()
end

function onBack()
	noctalia.togglePanel("bxrig/launcher:panel")
end

function onClear()
	if not P.state.armedClear then
		P:set({ armedClear = true })
		return
	end
	P.state.armedClear = false
	P:run({ "clipboard", "clear", "--yes" }, function(ok, message)
		if not ok then
			noctalia.notifyError("Clipboard", message ~= "" and message or "Could not clear the history")
		end
	end, 30000)
	P:close()
end
