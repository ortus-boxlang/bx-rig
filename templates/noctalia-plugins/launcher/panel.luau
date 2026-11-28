--!nonstrict
-- BxRig Launcher: one flat search box (Raycast style) with themed icon tiles, and a Boxy mode.
--
-- Launcher mode: rows are what `bxrig launcher search` returns: a calculator answer card, applications, menu actions (with their path as a
-- breadcrumb), themes, "Clipboard history", an "Ask Boxy" row, and web searches last. Every row has a rounded tile tinted with a theme colour
-- role (primary, secondary, tertiary, error) and a glyph, or the application's own picture; the colours follow the Noctalia theme.
-- Boxy mode (Tab, or Enter on the "Ask Boxy" row): a chat with your default agent. Enter sends with `bxrig ai agents ask TEXT --thread=ID --json`,
-- the answer appears below, a tool Boxy wants to run shows Approve and Reject (`ai agents approve|reject THREAD`), Tab goes back.
--
-- Keys: type, Up/Down/PageUp/PageDown move, Enter runs the row (or sends to Boxy), Tab switches Launcher and Boxy, F2 opens the Actions list,
-- Esc closes. Mouse: click a row to highlight it, click again to run it.
-- Data: `bxrig launcher search QUERY --limit=30 --json` on every keystroke (an older answer is dropped when a newer search is running).
-- Run: `bxrig launcher run ID QUERY`, then the panel closes. The "Clipboard history" row opens the clipboard panel.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local mode = "launcher" -- "launcher" or "boxy"

-- launcher state
local results = {}
local selected = 1
local query = ""
local inputKey = 0
local errorText = nil
local latest = kit.sequence()
local actionsOpen = false
local submitOnce = kit.once(300)

-- Boxy state
local messages = {} -- { role = "user" | "boxy" | "note", text }
local thread = nil
local busy = false
local pending = {} -- tools Boxy wants to run: { tool, args }
local boxyError = nil
local boxyAgent = "Boxy"
local draft = ""
local look = nil -- `bxrig boxy --json`

local KIND_LABEL = {
	app = "Application",
	menu = "Menu",
	theme = "Theme",
	web = "Web",
	answer = "Answer",
	mode = "View",
	boxy = "Boxy",
}

local KIND_GLYPH = {
	app = "app-window",
	menu = "list-details",
	theme = "palette",
	web = "world-search",
	answer = "calculator",
	mode = "clipboard-text",
	boxy = "sparkles",
}

local TONES = { primary = true, secondary = true, tertiary = true, error = true }

local str = kit.str

local function current()
	return results[selected]
end

local function toneOf(row)
	local t = str(row.tone)
	if TONES[t] then
		return t
	end
	return "primary"
end

-- A rounded tile tinted with the row's colour role, holding its glyph or, for an application, its own picture.
local function tile(row, size)
	local t = toneOf(row)
	local path = str(row.iconPath)
	local inner
	if path ~= "" and noctalia.fileExists(path) then
		inner = ui.image({ key = "ic-" .. str(row.id), path = path, fit = "contain", width = size - 12, height = size - 12 })
	else
		local name = str(row.glyph)
		if name == "" then
			name = KIND_GLYPH[str(row.kind)] or "search"
		end
		inner = ui.glyph({ name = name, size = size - 16, color = t })
	end
	return ui.column({ width = size, height = size, radius = 10, fill = t .. "/0.16", align = "center", justify = "center" }, { inner })
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
		paddingH = 10,
		paddingV = 7,
		radius = 12,
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
		tile(row, 38),
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
	return ui.row({
		key = "answer",
		align = "center",
		gap = 14,
		paddingH = 16,
		paddingV = 12,
		radius = 14,
		fill = isSel and "primary/0.14" or "surface_container",
		onClick = function()
			selected = 1
			onSubmit()
		end,
	}, {
		tile(row, 48),
		ui.column({ flexGrow = 1, gap = 2 }, {
			ui.label({ text = str(row.subtitle), fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
			ui.label({ text = str(row.title), fontSize = 28, fontWeight = "bold", maxLines = 1 }),
		}),
		ui.label({ text = "Copy  ↵", fontSize = 11, color = "primary" }),
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
	elseif kind == "boxy" then
		table.insert(list, { text = "Ask Boxy", key = "run" })
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

-- ---------------------------------------------------------------- Boxy mode

local function boxyPicture()
	if look ~= nil then
		local p = str(look.image)
		if p ~= "" then
			local expanded = p:sub(1, 1) == "~" and noctalia.expandPath(p) or p
			if noctalia.fileExists(expanded) then
				return expanded
			end
		end
	end
	return nil
end

-- Labels do not wrap on their own inside a row, so long text is broken into lines of about `width` characters.
local function wrapText(text, width)
	local lines = {}
	for para in (str(text) .. "\n"):gmatch("(.-)\n") do
		local line = ""
		for word in para:gmatch("%S+") do
			if line == "" then
				line = word
			elseif #line + 1 + #word <= width then
				line = line .. " " .. word
			else
				table.insert(lines, line)
				line = word
			end
		end
		table.insert(lines, line)
	end
	return table.concat(lines, "\n"), #lines
end

local function bubble(m, index)
	local mine = m.role == "user"
	local note = m.role == "note"
	local wrapped, count = wrapText(m.text, 72)
	local label = ui.label({ text = wrapped, fontSize = 13, color = note and "on_surface_variant" or "on_surface", maxLines = math.max(1, count) })
	local card = ui.column({
		key = "msg-" .. index,
		paddingH = 12,
		paddingV = 8,
		radius = 12,
		fill = mine and "primary/0.16" or (note and "on_surface/0" or "surface_container"),
	}, { label })
	if mine then
		return ui.row({ align = "end" }, { ui.spacer({ flexGrow = 1 }), card })
	end
	return ui.row({ align = "start" }, { card, ui.spacer({ flexGrow = 1 }) })
end

local function renderBoxy()
	local search = ui.row({ align = "center", gap = 10, paddingH = 14, paddingV = 6 }, {
		ui.glyph({ name = "sparkles", size = 18, color = "tertiary" }),
		ui.input({
			key = "search-" .. inputKey,
			value = draft,
			placeholder = "Ask " .. boxyAgent .. "…",
			fontSize = 16,
			frameVisible = false,
			focus = true,
			flexGrow = 1,
			onChange = "onQueryChanged",
			onSubmit = "onSubmit",
		}),
		ui.label({ text = "Boxy", fontSize = 11, color = "tertiary" }),
	})

	local pic = boxyPicture()
	local header = {}
	if pic ~= nil then
		table.insert(header, ui.image({ key = "boxy-img", path = pic, fit = "contain", width = 44, height = 44 }))
	else
		table.insert(header, ui.glyph({ name = "sparkles", size = 30, color = "tertiary" }))
	end
	local status = busy and (boxyAgent .. " is thinking…") or "Ask anything. It can run BxRig commands, and asks before it does."
	table.insert(header, ui.column({ flexGrow = 1, gap = 1 }, {
		ui.label({ text = boxyAgent, fontSize = 14, fontWeight = "semibold" }),
		ui.label({ text = status, fontSize = 11, color = busy and "primary" or "on_surface_variant", maxLines = 2 }),
	}))

	local body = {}
	for i, m in ipairs(messages) do
		table.insert(body, bubble(m, i))
	end
	for i, a in ipairs(pending) do
		local args = ""
		if type(a.args) == "table" then
			local ok, enc = pcall(function()
				return noctalia.json.encode(a.args)
			end)
			args = ok and str(enc) or ""
		end
		table.insert(body, ui.column({ key = "pending-" .. i, gap = 6, paddingH = 12, paddingV = 10, radius = 12, fill = "tertiary/0.14" }, {
			ui.label({ text = boxyAgent .. " wants to run " .. str(a.tool), fontSize = 13, fontWeight = "semibold", maxLines = 2 }),
			ui.label({ text = (wrapText(args, 90)), fontSize = 11, color = "on_surface_variant", maxLines = 6 }),
		}))
	end
	if #pending > 0 then
		table.insert(body, ui.row({ gap = 8, key = "decide" }, {
			ui.button({ text = "Approve", variant = "primary", controlSize = "sm", onClick = "onApprove" }),
			ui.button({ text = "Reject", variant = "ghost", controlSize = "sm", onClick = "onReject" }),
		}))
	end
	if boxyError ~= nil then
		table.insert(body, ui.label({ text = boxyError, fontSize = 12, color = "error", maxLines = 6 }))
		local startName = boxyError:match("ai agents start (%S+)")
		if startName ~= nil then
			table.insert(body, ui.button({ text = "Start " .. startName, variant = "primary", controlSize = "sm", onClick = "onStartBoxy" }))
		elseif boxyError:find("bxrig ai agents setup", 1, true) ~= nil then
			table.insert(body, ui.button({ text = "Make Boxy", glyph = "sparkles", variant = "primary", controlSize = "sm", onClick = "onMakeBoxy" }))
		end
	end
	if #messages == 0 and boxyError == nil then
		table.insert(body, ui.label({ text = "Try: what is using my disk?  or  switch to the nord theme", fontSize = 12, color = "on_surface_variant", maxLines = 3 }))
	end

	local footer = kit.footer({
		hint = "Tab goes back to the launcher",
		buttons = {
			ui.button({ text = "New chat", variant = "ghost", controlSize = "sm", onClick = "onNewChat" }),
			ui.button({ text = "Open full chat", variant = "ghost", controlSize = "sm", onClick = "onOpenChat" }),
			ui.button({ text = busy and "…" or "Send  ↵", variant = "primary", controlSize = "sm", enabled = not busy, onClick = "onSubmit" }),
		},
	})

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, {
		search,
		ui.separator({}),
		ui.row({ align = "center", gap = 10, paddingH = 14, paddingV = 4 }, header),
		ui.column({ height = 330 }, {
			ui.scroll({ flexGrow = 1, gap = 8, padding = 10, revealKey = #messages > 0 and ("msg-" .. #messages) or nil }, body),
		}),
		footer,
	}))
end

local function loadLook()
	bxrig.json({ "boxy", "--json" }, function(result, err)
		if err == nil and type(result) == "table" then
			look = result
			if mode == "boxy" then
				render()
			end
		end
	end, 30000)
end

local function applyAnswer(res)
	if type(res.thread) == "string" and res.thread ~= "" then
		thread = res.thread
	end
	if type(res.agent) == "string" and res.agent ~= "" then
		boxyAgent = res.agent
	end
	local answer = str(res.answer)
	if answer ~= "" then
		table.insert(messages, { role = "boxy", text = answer })
	end
	pending = type(res.pending) == "table" and res.pending or {}
end

local function sendBoxy(text)
	text = noctalia.string.trim(text or "")
	if text == "" or busy then
		return
	end
	table.insert(messages, { role = "user", text = text })
	draft = ""
	inputKey += 1
	busy = true
	boxyError = nil
	pending = {}
	render()
	local args = { "ai", "agents", "ask", text }
	if thread ~= nil then
		table.insert(args, "--thread=" .. thread)
	end
	table.insert(args, "--json")
	bxrig.json(args, function(res, err)
		busy = false
		if err ~= nil then
			boxyError = err
		else
			applyAnswer(res)
		end
		render()
	end, 600000)
end

local function decide(decision)
	if thread == nil or busy then
		return
	end
	busy = true
	boxyError = nil
	render()
	bxrig.json({ "ai", "agents", decision, thread, "--json" }, function(res, err)
		busy = false
		if err ~= nil then
			boxyError = err
		else
			local ran = ""
			if type(res.ran) == "table" and #res.ran > 0 then
				ran = " Ran: " .. table.concat(res.ran, ", ")
			end
			table.insert(messages, { role = "note", text = (decision == "reject" and "Rejected." or "Approved.") .. ran })
			applyAnswer(res)
		end
		render()
	end, 900000)
end

function onApprove()
	decide("approve")
end

function onReject()
	decide("reject")
end

function onNewChat()
	messages = {}
	thread = nil
	pending = {}
	boxyError = nil
	render()
end

function onOpenChat()
	bxrig.run({ "ai", "agents", "chat", "--window" })
	panel.close()
end

function onStartBoxy()
	local name = boxyError and boxyError:match("ai agents start (%S+)") or nil
	if name == nil then
		return
	end
	busy = true
	boxyError = nil
	render()
	bxrig.run({ "ai", "agents", "start", name }, function(ok, message)
		busy = false
		if not ok then
			boxyError = message ~= "" and message or ("Could not start " .. name)
		end
		render()
	end, 120000)
end

function onMakeBoxy()
	busy = true
	boxyError = nil
	render()
	bxrig.run({ "ai", "agents", "setup", "--yes" }, function(ok, message)
		busy = false
		if not ok then
			boxyError = message ~= "" and message or "Could not make Boxy"
		end
		render()
	end, 900000)
end

local function enterBoxy(firstMessage)
	mode = "boxy"
	actionsOpen = false
	draft = ""
	inputKey += 1
	render()
	loadLook()
	if firstMessage ~= nil and noctalia.string.trim(firstMessage) ~= "" then
		sendBoxy(firstMessage)
	end
end

local function enterLauncher()
	mode = "launcher"
	inputKey += 1
	render()
end

-- ---------------------------------------------------------------- Launcher mode

function render()
	if mode == "boxy" then
		renderBoxy()
		return
	end
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
		ui.label({ text = "Tab  Boxy", fontSize = 11, color = "tertiary" }),
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
		table.insert(rows, ui.label({ text = "Start typing: an app, an action, a theme, or a sum. Tab asks Boxy.", fontSize = 13, color = "on_surface_variant" }))
	end
	local sel = current()
	-- A fixed-height box around the scroll, so a long list is clipped and the footer stays on screen (the Actions row takes some of the room).
	local listHeight = (startAt == 2) and 290 or 400
	if actionsOpen then
		listHeight -= 48
	end
	table.insert(body, ui.column({ height = listHeight }, {
		ui.scroll({
			flexGrow = 1,
			gap = 2,
			padding = 8,
			revealKey = sel and ("row-" .. str(sel.id)) or nil,
		}, rows),
	}))

	local list = nil
	if actionsOpen and sel ~= nil then
		local buttons = {}
		for _, a in ipairs(actionsFor(sel)) do
			table.insert(buttons, ui.button({ text = a.text, variant = "ghost", controlSize = "sm", onClick = a.key == "run" and "onSubmit" or "onCopyTitle" }))
		end
		list = ui.row({ gap = 6, paddingH = 14, paddingV = 6, fill = "surface_container", radius = 10, align = "center" }, buttons)
	end

	local hint = "Super+Space opens this launcher"
	if sel ~= nil then
		hint = str(sel.subtitle)
	end
	local footer = ui.row({ align = "center", gap = 8, paddingH = 14, paddingV = 8, fill = "surface_container", radius = 10 }, {
		ui.label({ text = hint, fontSize = 12, color = "on_surface_variant", flexGrow = 1, maxLines = 1 }),
		ui.button({ text = "Actions  F2", variant = "ghost", controlSize = "sm", onClick = "onActions" }),
		ui.button({ text = "Open  ↵", variant = "primary", controlSize = "sm", enabled = sel ~= nil, onClick = "onSubmit" }),
	})

	local children = { search, ui.separator({}), ui.column({ gap = 6 }, body) }
	if list ~= nil then
		table.insert(children, list)
	end
	table.insert(children, footer)
	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, children))
end

-- The "Ask Boxy" row goes in front of the web searches.
local function withBoxyRow(list, q)
	if q == "" then
		return list
	end
	local out = {}
	local added = false
	for _, r in ipairs(list) do
		if not added and str(r.kind) == "web" then
			table.insert(out, { id = "ai:ask", kind = "boxy", title = 'Ask Boxy: "' .. q .. '"', subtitle = "Enter sends it to Boxy, your assistant", glyph = "sparkles", tone = "tertiary", breadcrumb = "", iconPath = "" })
			added = true
		end
		table.insert(out, r)
	end
	if not added then
		table.insert(out, { id = "ai:ask", kind = "boxy", title = 'Ask Boxy: "' .. q .. '"', subtitle = "Enter sends it to Boxy, your assistant", glyph = "sparkles", tone = "tertiary", breadcrumb = "", iconPath = "" })
	end
	return out
end

local function fetch()
	local mine = latest.next()
	local args = { "launcher", "search" }
	local q = noctalia.string.trim(query)
	if q ~= "" then
		table.insert(args, q)
	end
	table.insert(args, "--limit=30")
	table.insert(args, "--json")
	bxrig.json(args, function(result, err)
		if not latest.isCurrent(mine) then
			return -- a newer search is running
		end
		if err ~= nil then
			errorText = err
			results = {}
		else
			errorText = nil
			results = withBoxyRow(type(result.results) == "table" and result.results or {}, q)
		end
		selected = 1
		render()
	end)
end

local function move(delta)
	if #results == 0 then
		return
	end
	selected = kit.clamp(selected, delta, #results)
	render()
end

function onQueryChanged(value)
	if mode == "boxy" then
		draft = value or ""
		return
	end
	query = value or ""
	actionsOpen = false
	fetch()
end

function onActions()
	if mode == "boxy" then
		return
	end
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
	if not submitOnce() then
		return
	end
	if mode == "boxy" then
		sendBoxy(draft)
		return
	end
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
	if kind == "boxy" then
		enterBoxy(noctalia.string.trim(query))
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
	if chord == "Tab" then
		if mode == "boxy" then
			enterLauncher()
		else
			-- Tab with something typed asks Boxy that question, like the "Ask Boxy" row.
			enterBoxy(noctalia.string.trim(query))
		end
		return
	end
	if mode == "boxy" then
		if chord == "Return" or chord == "KP_Enter" then
			onSubmit()
		end
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
	elseif chord == "F2" then
		onActions()
	elseif chord == "Return" or chord == "KP_Enter" then
		onSubmit()
	end
end

-- `noctalia msg panel-open bxrig/launcher:panel boxy` opens straight in Boxy mode; any other context (or none) is the launcher.
local function wantsBoxy(context)
	if context == nil then
		return false
	end
	if type(context) == "string" then
		return context:lower():find("boxy", 1, true) ~= nil
	end
	if type(context) == "table" then
		for _, v in pairs(context) do
			if type(v) == "string" and v:lower():find("boxy", 1, true) ~= nil then
				return true
			end
		end
	end
	return false
end

function onOpen(context)
	mode = "launcher"
	query = ""
	draft = ""
	inputKey += 1
	actionsOpen = false
	errorText = nil
	results = {}
	selected = 1
	if wantsBoxy(context) then
		enterBoxy("")
		return
	end
	render()
	fetch()
end
