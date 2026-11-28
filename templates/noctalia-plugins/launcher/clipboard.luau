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

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local entries = {}
local selected = 1
local query = ""
local inputKey = 0
local errorText = nil
local latest = kit.sequence()
local detail = {} -- id -> { kind, text, details }
local armedClear = false
local submitOnce = kit.once(300)

local str = kit.str

local function current()
	return entries[selected]
end

function render()
	local search = kit.searchRow({ glyph = "clipboard", key = "search-" .. inputKey, value = query, placeholder = "Search the clipboard history…" })

	local rows = {}
	if errorText ~= nil then
		table.insert(rows, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 8 }))
	elseif #entries == 0 then
		table.insert(rows, ui.label({ text = query == "" and "The clipboard history is empty" or "No matching entries", fontSize = 13, color = "on_surface_variant" }))
	end
	for i, e in ipairs(entries) do
		local isSel = i == selected
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
				if i == selected then
					onSubmit()
				else
					selected = i
					loadDetail()
					render()
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
	local sel = current()
	local list = ui.scroll({
		width = 330,
		height = 420,
		gap = 2,
		padding = 8,
		revealKey = sel and ("clip-" .. str(sel.id)) or nil,
	}, rows)

	-- Right: the highlighted entry in full.
	local right = {}
	if sel ~= nil then
		local d = detail[str(sel.id)]
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

	local footer = kit.footer({
		leading = { ui.button({ glyph = "arrow-left", text = "Launcher", variant = "ghost", controlSize = "sm", onClick = "onBack" }) },
		hint = #entries .. " entries",
		buttons = {
			ui.button({
				text = armedClear and "Click again to clear" or "Clear history",
				variant = "ghost",
				controlSize = "sm",
				onClick = "onClear",
			}),
			ui.button({ text = "Copy  ↵", variant = "primary", controlSize = "sm", enabled = sel ~= nil, onClick = "onSubmit" }),
		},
	})

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, {
		search,
		ui.separator({}),
		ui.row({ height = 420, gap = 0, align = "start" }, {
			list,
			ui.separator({ orientation = "vertical" }),
			pane,
		}),
		footer,
	}))
end

function loadDetail()
	local e = current()
	if e == nil or detail[str(e.id)] ~= nil then
		return
	end
	local id = str(e.id)
	bxrig.json({ "clipboard", "show", id, "--json" }, function(result, err)
		if err ~= nil then
			detail[id] = { kind = "text", text = str(e.preview) }
		else
			detail[id] = result
		end
		render()
	end)
end

local function fetch()
	local mine = latest.next()
	local args = { "clipboard", "list" }
	local q = noctalia.string.trim(query)
	if q ~= "" then
		table.insert(args, q)
	end
	table.insert(args, "--limit=60")
	table.insert(args, "--json")
	bxrig.json(args, function(result, err)
		if not latest.isCurrent(mine) then
			return
		end
		if err ~= nil then
			errorText = err
			entries = {}
		else
			errorText = nil
			entries = type(result.entries) == "table" and result.entries or {}
		end
		selected = 1
		render()
		loadDetail()
	end)
end

local function move(delta)
	selected = kit.clamp(selected, delta, #entries)
	loadDetail()
	render()
end

function onQueryChanged(value)
	query = value or ""
	fetch()
end

function onBack()
	noctalia.togglePanel("bxrig/launcher:panel")
end

function onClear()
	if not armedClear then
		armedClear = true
		render()
		return
	end
	armedClear = false
	bxrig.run({ "clipboard", "clear", "--yes" }, function(ok, message)
		if not ok then
			noctalia.notifyError("Clipboard", message ~= "" and message or "Could not clear the history")
		end
	end, 30000)
	panel.close()
end

function onSubmit()
	-- Enter can reach us both through the input's onSubmit and onKey("Return").
	if not submitOnce() then
		return
	end
	local e = current()
	if e == nil then
		return
	end
	bxrig.run({ "clipboard", "copy", str(e.id) }, function(ok, message)
		if not ok then
			noctalia.notifyError("Clipboard", message ~= "" and message or "Could not copy the entry")
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
	elseif chord == "Return" or chord == "KP_Enter" then
		onSubmit()
	end
end

function onOpen(_context)
	query = ""
	inputKey += 1
	armedClear = false
	errorText = nil
	detail = {}
	entries = {}
	selected = 1
	render()
	fetch()
end
