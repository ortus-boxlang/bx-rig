--!nonstrict
-- BxRig Launcher: one flat search box (Raycast style). Rows are what `bxrig launcher search` returns: a calculator answer card first, then
-- applications, menu actions (with their path as a breadcrumb), themes, "Clipboard history", and web searches last.
--
-- Keys: type to search, Up/Down/PageUp/PageDown move, Enter runs the row, Tab opens the Actions list for the row, Esc closes.
-- Mouse: click a row to highlight it, click it again to run it. "Actions" in the footer is the same list as Tab.
-- Data: `bxrig launcher search QUERY --limit=30 --json` on every keystroke (an older answer is dropped when a newer search is running).
-- Run: `bxrig launcher run ID QUERY`, then the panel closes. The "Clipboard history" row opens the clipboard panel.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")

local results = {}
local selected = 1
local query = ""
local inputKey = 0
local errorText = nil
local seq = 0
local actionsOpen = false
local lastSubmitMs = 0

local KIND_LABEL = {
	app = "Application",
	menu = "Menu",
	theme = "Theme",
	web = "Web",
	answer = "Answer",
	mode = "View",
}

local KIND_GLYPH = {
	app = "apps",
	menu = "list-details",
	theme = "palette",
	web = "world",
	answer = "calculator",
	mode = "clipboard",
}

local function str(v)
	if v == nil then
		return ""
	end
	return tostring(v)
end

local function current()
	return results[selected]
end

local function rowIcon(row, size)
	local path = str(row.iconPath)
	if path ~= "" and noctalia.fileExists(path) then
		return ui.image({ key = "ic-" .. str(row.id), path = path, fit = "contain", width = size, height = size })
	end
	return ui.glyph({ name = KIND_GLYPH[str(row.kind)] or "search", size = size - 6, color = "on_surface_variant" })
end

local function renderRow(index, row)
	local isSel = index == selected
	local sub = str(row.breadcrumb)
	if sub == "" then
		sub = str(row.subtitle)
	end
	return ui.row({
		key = "row-" .. str(row.id),
		align = "center",
		gap = 12,
		paddingH = 12,
		paddingV = 8,
		radius = 10,
		-- An explicit transparent fill: a nil fill keeps the retained one.
		fill = isSel and "on_surface/0.08" or "on_surface/0",
		onClick = function()
			if index == selected then
				onSubmit()
			else
				selected = index
				render()
			end
		end,
	}, {
		rowIcon(row, 28),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = str(row.title), fontSize = 14, fontWeight = isSel and "semibold" or "normal", maxLines = 1 }),
			ui.label({ text = sub, fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
		}),
		ui.label({ text = KIND_LABEL[str(row.kind)] or "", fontSize = 11, color = "on_surface_variant" }),
	})
end

-- The calculator answer: a big card, not a list row.
local function renderAnswer(row)
	local isSel = selected == 1
	return ui.column({
		key = "answer",
		gap = 2,
		paddingH = 18,
		paddingV = 12,
		radius = 12,
		fill = isSel and "primary/0.14" or "surface_container",
		onClick = function()
			selected = 1
			onSubmit()
		end,
	}, {
		ui.label({ text = str(row.subtitle), fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
		ui.label({ text = str(row.title), fontSize = 30, fontWeight = "bold", maxLines = 1 }),
		ui.label({ text = "Copy result  ↵", fontSize = 11, color = "primary" }),
	})
end

local function actionsFor(row)
	local list = {}
	if row == nil then
		return list
	end
	local kind = str(row.kind)
	if kind == "answer" then
		table.insert(list, { text = "Copy result", key = "run" })
	elseif kind == "mode" then
		table.insert(list, { text = "Open clipboard history", key = "run" })
	elseif kind == "web" then
		table.insert(list, { text = "Open in the browser", key = "run" })
	elseif kind == "theme" then
		table.insert(list, { text = "Apply theme", key = "run" })
	else
		table.insert(list, { text = "Run", key = "run" })
	end
	table.insert(list, { text = "Copy title", key = "copy" })
	return list
end

function render()
	local search = ui.row({ align = "center", gap = 10, paddingH = 14, paddingV = 6 }, {
		ui.glyph({ name = "search", size = 18, color = "on_surface_variant" }),
		ui.input({
			key = "search-" .. inputKey,
			value = query,
			placeholder = "Search apps, actions, themes… or calculate",
			fontSize = 16,
			frameVisible = false,
			focus = true,
			flexGrow = 1,
			onChange = "onQueryChanged",
			onSubmit = "onSubmit",
		}),
	})

	local body = {}
	local first = results[1]
	local rows = {}
	if first ~= nil and str(first.kind) == "answer" then
		table.insert(body, renderAnswer(first))
	end
	local startAt = (first ~= nil and str(first.kind) == "answer") and 2 or 1
	for i = startAt, #results do
		table.insert(rows, renderRow(i, results[i]))
	end
	if errorText ~= nil then
		table.insert(rows, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 6 }))
	elseif #results == 0 then
		table.insert(rows, ui.label({ text = "Type to search", fontSize = 13, color = "on_surface_variant" }))
	end
	local sel = current()
	table.insert(body, ui.scroll({
		height = (startAt == 2) and 310 or 400,
		gap = 2,
		padding = 8,
		revealKey = sel and ("row-" .. str(sel.id)) or nil,
	}, rows))

	local list = nil
	if actionsOpen and sel ~= nil then
		local buttons = {}
		for _, a in ipairs(actionsFor(sel)) do
			table.insert(buttons, ui.button({ text = a.text, variant = "ghost", controlSize = "sm", onClick = a.key == "run" and "onSubmit" or "onCopyTitle" }))
		end
		list = ui.row({ gap = 6, paddingH = 14, paddingV = 6, fill = "surface_container", radius = 10, align = "center" }, buttons)
	end

	local hint = "Type to search"
	if sel ~= nil then
		hint = str(sel.subtitle)
	end
	local footer = ui.row({ align = "center", gap = 8, paddingH = 14, paddingV = 8, fill = "surface_container", radius = 10 }, {
		ui.label({ text = hint, fontSize = 12, color = "on_surface_variant", flexGrow = 1, maxLines = 1 }),
		ui.button({ text = "Actions  Tab", variant = "ghost", controlSize = "sm", onClick = "onActions" }),
		ui.button({ text = "Open  ↵", variant = "primary", controlSize = "sm", enabled = sel ~= nil, onClick = "onSubmit" }),
	})

	local children = { search, ui.separator({}), ui.column({ gap = 6 }, body) }
	if list ~= nil then
		table.insert(children, list)
	end
	table.insert(children, footer)
	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, children))
end

local function fetch()
	seq += 1
	local mine = seq
	local args = { "launcher", "search" }
	local q = noctalia.string.trim(query)
	if q ~= "" then
		table.insert(args, q)
	end
	table.insert(args, "--limit=30")
	table.insert(args, "--json")
	bxrig.json(args, function(result, err)
		if mine ~= seq then
			return -- a newer search is running
		end
		if err ~= nil then
			errorText = err
			results = {}
		else
			errorText = nil
			results = type(result.results) == "table" and result.results or {}
		end
		selected = 1
		render()
	end)
end

local function move(delta)
	if #results == 0 then
		return
	end
	selected = math.max(1, math.min(#results, selected + delta))
	render()
end

function onQueryChanged(value)
	query = value or ""
	actionsOpen = false
	fetch()
end

function onActions()
	actionsOpen = not actionsOpen
	render()
end

function onCopyTitle()
	local row = current()
	if row ~= nil and noctalia.copyToClipboard(str(row.title), "text/plain") then
		noctalia.notify("Copied", str(row.title))
	end
	panel.close()
end

function onSubmit()
	-- Enter can reach us both through the input's onSubmit and onKey("Return").
	local now = noctalia.nowMs()
	if now - lastSubmitMs < 300 then
		return
	end
	lastSubmitMs = now
	local row = current()
	if row == nil then
		return
	end
	local kind = str(row.kind)
	if kind == "mode" then
		-- Opening a panel replaces the open one, so this does not close first.
		noctalia.togglePanel("bxrig/launcher:clipboard")
		return
	end
	local args = { "launcher", "run", str(row.id) }
	local q = noctalia.string.trim(query)
	if q ~= "" and (kind == "answer" or kind == "web") then
		table.insert(args, q)
	end
	bxrig.run(args, function(ok, message)
		if not ok then
			noctalia.notifyError("Launcher", message ~= "" and message or ("Could not run " .. str(row.title)))
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
	elseif chord == "Tab" then
		onActions()
	elseif chord == "Return" or chord == "KP_Enter" then
		onSubmit()
	end
end

function onOpen(_context)
	query = ""
	inputKey += 1
	actionsOpen = false
	errorText = nil
	results = {}
	selected = 1
	render()
	fetch()
end
