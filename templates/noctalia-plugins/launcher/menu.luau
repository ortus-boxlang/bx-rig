--!nonstrict
-- BxRig Menu: the drill-down menu as a Noctalia panel, in the style of the Omarchy menu. The top level lists the sections (Trigger, Appearance,
-- System, ...) as icon tiles; Enter or Right goes into a section, Left goes back up, and a leaf runs its action. The header shows where you are
-- ("Trigger › Capture"). Type to filter the entries of the current level.
--
-- Keys: Up/Down/PageUp/PageDown move, Enter or Right opens a section or runs the action, Left goes up a level, Esc closes.
-- Mouse: click an entry to highlight it, click it again to open or run it; the header arrow goes up a level.
-- Data: `bxrig menu level [PATH] --json` on every level; a leaf runs `bxrig launcher run menu:ID` (the same action as in the launcher), then the
-- panel closes. Each entry comes with a glyph and a theme colour role, so the tiles follow the Noctalia theme like the launcher's.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local path = "" -- "Trigger > Capture", "" at the top
local crumbs = {}
local entries = {}
local visible = {}
local selected = 1
local query = ""
local inputKey = 0
local errorText = nil
local loading = false
local latest = kit.sequence()
local submitOnce = kit.once(300)

local TONES = { primary = true, secondary = true, tertiary = true, error = true }

local str = kit.str

local function toneOf(e)
	local t = str(e.tone)
	if TONES[t] then
		return t
	end
	return "primary"
end

local function refilter()
	visible = {}
	local q = noctalia.string.trim(query)
	for i, e in ipairs(entries) do
		if q == "" or noctalia.fuzzyScore(q, str(e.title)) ~= nil then
			table.insert(visible, i)
		end
	end
	selected = 1
end

local function selectedEntry()
	local i = visible[selected]
	if i == nil then
		return nil
	end
	return entries[i]
end

local function tile(e, size)
	local t = toneOf(e)
	return ui.column({ width = size, height = size, radius = 12, fill = t .. "/0.16", align = "center", justify = "center" }, {
		ui.glyph({ name = str(e.glyph) ~= "" and str(e.glyph) or "list-details", size = size - 18, color = t }),
	})
end

local function renderRow(vi, e)
	local isSel = vi == selected
	local children = {
		tile(e, 40),
		ui.label({ text = str(e.title), fontSize = 15, fontWeight = isSel and "semibold" or "normal", flexGrow = 1, maxLines = 1 }),
	}
	if e.checked == true then
		table.insert(children, ui.glyph({ name = "check", size = 16, color = "primary" }))
	end
	if e.hasChildren == true then
		table.insert(children, ui.glyph({ name = "chevron-right", size = 18, color = "on_surface_variant" }))
	end
	return ui.row({
		key = "entry-" .. str(e.id) .. "-" .. str(e.title),
		align = "center",
		gap = 12,
		paddingH = 10,
		paddingV = 6,
		radius = 12,
		-- An explicit transparent fill: a nil fill keeps the retained one.
		fill = isSel and "on_surface/0.08" or "on_surface/0",
		onClick = function()
			if vi == selected then
				onSubmit()
			else
				selected = vi
				render()
			end
		end,
	}, children)
end

function render()
	local title = "BxRig menu"
	if #crumbs > 0 then
		title = table.concat(crumbs, "  ›  ")
	end
	local header = ui.row({ align = "center", gap = 10, paddingH = 10, paddingV = 6 }, {
		ui.button({ glyph = "arrow-left", variant = "ghost", controlSize = "sm", enabled = #crumbs > 0, onClick = "onUp" }),
		ui.label({ text = title, fontSize = 16, fontWeight = "bold", flexGrow = 1, maxLines = 1 }),
		ui.label({ text = #crumbs > 0 and "Left goes back" or "Right opens", fontSize = 11, color = "on_surface_variant" }),
	})
	local filter = kit.searchRow({
		glyphSize = 16,
		key = "search-" .. inputKey,
		value = query,
		placeholder = "Filter this level…",
		fontSize = 14,
		paddingV = 4,
		radius = 10,
		fill = "on_surface/0.05",
	})

	local rows = {}
	if loading and #entries == 0 then
		table.insert(rows, ui.label({ text = "Loading…", fontSize = 13, color = "on_surface_variant" }))
	elseif errorText ~= nil then
		table.insert(rows, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 6 }))
	elseif #visible == 0 then
		table.insert(rows, ui.label({ text = "Nothing matches", fontSize = 13, color = "on_surface_variant" }))
	end
	for vi, ei in ipairs(visible) do
		table.insert(rows, renderRow(vi, entries[ei]))
	end
	local sel = selectedEntry()
	local list = ui.column({ height = 430 }, {
		ui.scroll({
			flexGrow = 1,
			gap = 3,
			padding = 6,
			revealKey = sel and ("entry-" .. str(sel.id) .. "-" .. str(sel.title)) or nil,
		}, rows),
	})

	local hint = "Super+Alt+Space opens this menu"
	if sel ~= nil then
		hint = sel.hasChildren == true and "Opens the section" or str(sel.does)
	end
	local footer = kit.footer({
		hint = hint,
		buttons = {
			ui.button({
				text = (sel ~= nil and sel.hasChildren == true) and "Open  ↵" or "Run  ↵",
				variant = "primary",
				controlSize = "sm",
				enabled = sel ~= nil,
				onClick = "onSubmit",
			}),
		},
	})

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, { header, filter, ui.separator({}), list, footer }))
end

local function fetch()
	local mine = latest.next()
	loading = true
	local args = { "menu", "level" }
	if path ~= "" then
		table.insert(args, path)
	end
	table.insert(args, "--json")
	bxrig.json(args, function(result, err)
		if not latest.isCurrent(mine) then
			return
		end
		loading = false
		if err ~= nil then
			errorText = err
			entries = {}
		else
			errorText = nil
			entries = type(result.entries) == "table" and result.entries or {}
			crumbs = type(result.crumbs) == "table" and result.crumbs or {}
		end
		refilter()
		render()
	end)
end

local function openLevel(newPath)
	path = newPath
	query = ""
	inputKey += 1
	fetch()
end

local function move(delta)
	if #visible == 0 then
		return
	end
	selected = kit.clamp(selected, delta, #visible)
	render()
end

function onQueryChanged(value)
	query = value or ""
	refilter()
	render()
end

-- One level up: the path without its last section.
function onUp()
	if #crumbs == 0 then
		return
	end
	local parent = {}
	for i = 1, #crumbs - 1 do
		table.insert(parent, crumbs[i])
	end
	openLevel(table.concat(parent, " > "))
end

function onSubmit()
	-- Enter can reach us both through the input's onSubmit and onKey("Return").
	if not submitOnce() then
		return
	end
	local e = selectedEntry()
	if e == nil then
		return
	end
	if e.hasChildren == true then
		openLevel(str(e.path))
		return
	end
	if str(e.id) == "" then
		return
	end
	bxrig.run({ "launcher", "run", "menu:" .. str(e.id) }, function(ok, message)
		if not ok then
			noctalia.notifyError("Menu", message ~= "" and message or ("Could not run " .. str(e.title)))
		end
	end, 30000)
	panel.close()
end

function onKey(chord, pressed)
	if not pressed then
		return
	end
	if chord == "Up" then
		move(-1)
	elseif chord == "Down" then
		move(1)
	elseif chord == "Page_Up" then
		move(-8)
	elseif chord == "Page_Down" then
		move(8)
	elseif chord == "Left" then
		onUp()
	elseif chord == "Right" then
		local e = selectedEntry()
		if e ~= nil and e.hasChildren == true then
			openLevel(str(e.path))
		end
	elseif chord == "Return" or chord == "KP_Enter" then
		onSubmit()
	end
end

function onOpen(_context)
	path = ""
	crumbs = {}
	entries = {}
	visible = {}
	query = ""
	inputKey += 1
	errorText = nil
	selected = 1
	render()
	fetch()
end
