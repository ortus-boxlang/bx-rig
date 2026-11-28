--!nonstrict
-- BxRig Shortcuts: every keyboard shortcut in one panel, in the Noctalia look. Tabs by group (Menus and launchers, Apps, Windows, ...) plus
-- "Yours" for the ones you changed, a filter that works as you type, the keys drawn as keycaps, and a Change button that rebinds a shortcut.
--
-- Keys: type to filter, Up/Down/PageUp/PageDown move, Tab goes to the next group, Enter changes the highlighted shortcut, Esc closes (or
-- cancels the change). Mouse: click a row, then Change; the tabs work by click.
-- Change: type the new keys ("Super+Shift+T") and Enter or Save. That runs `bxrig keys set ID KEYS --yes` and then `bxrig keys apply --yes`.
-- BxRig refuses a combo another binding uses and says which, so nothing is bound twice. "Back to default" runs `bxrig keys reset ID --yes`.
-- Shortcuts of the Mac style that xremap rewrites (Cmd+C and friends) show a lock: they are xremap's, not bindings.
-- Data: `bxrig keys show --json` on open (id, group, keys, action, how, custom). The keys shown are those of the style that is on.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")

local rows = {}
local visible = {}
local groups = {}
local group = "All"
local selected = 1
local query = ""
local inputKey = 0
local errorText = nil
local statusText = nil
local loading = false
local busy = false
local editing = false
local editKeys = ""
local lastSubmitMs = 0

local GROUP_GLYPH = {
	["Menus and launchers"] = { "layout-grid", "primary" },
	["Apps"] = { "apps", "tertiary" },
	["Capture and recording"] = { "camera", "secondary" },
	["Notifications and panels"] = { "bell", "secondary" },
	["Windows"] = { "app-window", "primary" },
	["Workspaces"] = { "layout-dashboard", "tertiary" },
	["Hardware and keys"] = { "keyboard", "secondary" },
	["Editing"] = { "pencil", "primary" },
}

local function str(v)
	if v == nil then
		return ""
	end
	return tostring(v)
end

-- Short tab names for the long group names.
local TAB_LABEL = {
	["Menus and launchers"] = "Menus",
	["Capture and recording"] = "Capture",
	["Notifications and panels"] = "Panels",
	["Hardware and keys"] = "Hardware",
	["Control Center pages"] = "Pages",
}

local function glyphOf(r)
	local g = GROUP_GLYPH[str(r.group)]
	if g == nil then
		return "keyboard", "primary"
	end
	return g[1], g[2]
end

local function buildGroups()
	local seen = {}
	local list = {}
	local yours = false
	for _, r in ipairs(rows) do
		local g = str(r.group)
		if g ~= "" and not seen[g] then
			seen[g] = true
			table.insert(list, g)
		end
		if r.custom == true then
			yours = true
		end
	end
	groups = { "All" }
	if yours then
		table.insert(groups, "Yours")
	end
	for _, g in ipairs(list) do
		table.insert(groups, g)
	end
end

local function refilter()
	local q = noctalia.string.trim(query)
	local scored = {}
	for i, r in ipairs(rows) do
		local ok = str(r.keys) ~= ""
		if ok and group == "Yours" then
			ok = r.custom == true
		elseif ok and group ~= "All" then
			ok = str(r.group) == group
		end
		local score = 0
		if ok and q ~= "" then
			local a = noctalia.fuzzyScore(q, str(r.action))
			local k = noctalia.fuzzyScore(q, str(r.keys))
			if a == nil and k == nil then
				ok = false
			else
				score = math.max(a or 0, k or 0)
			end
		end
		if ok then
			table.insert(scored, { index = i, score = score })
		end
	end
	if q ~= "" then
		table.sort(scored, function(x, y)
			return x.score > y.score
		end)
	end
	visible = {}
	for _, s in ipairs(scored) do
		table.insert(visible, s.index)
	end
	selected = 1
end

local function selectedRow()
	local i = visible[selected]
	if i == nil then
		return nil
	end
	return rows[i]
end

-- "Super+Alt+Space" as keycaps: one small rounded cap per key.
local function keycaps(keys)
	local caps = {}
	for token in str(keys):gmatch("[^+]+") do
		table.insert(caps, ui.column({ paddingH = 8, paddingV = 3, radius = 7, fill = "on_surface/0.10" }, {
			ui.label({ text = token, fontSize = 11, fontWeight = "semibold" }),
		}))
	end
	return ui.row({ gap = 4, align = "center" }, caps)
end

local function renderRow(vi, r)
	local isSel = vi == selected
	local glyph, tone = glyphOf(r)
	local locked = str(r.how) == "xremap"
	local trailing = { keycaps(r.keys) }
	if r.custom == true then
		table.insert(trailing, 1, ui.label({ text = "yours", fontSize = 10, color = "primary" }))
	end
	if locked then
		table.insert(trailing, 1, ui.glyph({ name = "lock", size = 14, color = "on_surface_variant" }))
	end
	return ui.row({
		key = "key-" .. str(r.id) .. "-" .. str(r.keys),
		align = "center",
		gap = 12,
		paddingH = 10,
		paddingV = 7,
		radius = 12,
		-- An explicit transparent fill: a nil fill keeps the retained one.
		fill = isSel and "on_surface/0.08" or "on_surface/0",
		onClick = function()
			selected = vi
			render()
		end,
	}, {
		ui.column({ width = 34, height = 34, radius = 10, fill = tone .. "/0.16", align = "center", justify = "center" }, {
			ui.glyph({ name = glyph, size = 18, color = tone }),
		}),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = str(r.action), fontSize = 13, fontWeight = isSel and "semibold" or "normal", maxLines = 2 }),
			ui.label({ text = str(r.group), fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
		}),
		ui.row({ gap = 8, align = "center" }, trailing),
	})
end

function render()
	local search = ui.row({ align = "center", gap = 10, paddingH = 14, paddingV = 6 }, {
		ui.glyph({ name = "search", size = 18, color = "on_surface_variant" }),
		ui.input({
			key = "search-" .. inputKey,
			value = query,
			placeholder = "Filter shortcuts by name or keys…",
			fontSize = 16,
			frameVisible = false,
			focus = not editing,
			flexGrow = 1,
			onChange = "onQueryChanged",
			onSubmit = "onSubmit",
		}),
		ui.label({ text = tostring(#visible) .. " shortcuts", fontSize = 11, color = "on_surface_variant" }),
	})

	local chips = {}
	for _, g in ipairs(groups) do
		table.insert(chips, ui.button({
			key = "tab-" .. g,
			text = TAB_LABEL[g] or g,
			variant = g == group and "secondary" or "ghost",
			controlSize = "sm",
			onClick = function()
				group = g
				refilter()
				render()
			end,
		}))
	end
	local tabs = ui.row({ gap = 4, paddingH = 8, paddingV = 2 }, chips)

	local list = {}
	if loading and #rows == 0 then
		table.insert(list, ui.label({ text = "Loading shortcuts…", fontSize = 13, color = "on_surface_variant" }))
	elseif errorText ~= nil and not editing then
		table.insert(list, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 6 }))
	elseif #visible == 0 then
		table.insert(list, ui.label({ text = "No shortcut matches", fontSize = 13, color = "on_surface_variant" }))
	end
	for vi, ri in ipairs(visible) do
		table.insert(list, renderRow(vi, rows[ri]))
	end
	local sel = selectedRow()
	local body = ui.column({ height = editing and 300 or 380 }, {
		ui.scroll({ flexGrow = 1, gap = 2, padding = 6, revealKey = sel and ("key-" .. str(sel.id) .. "-" .. str(sel.keys)) or nil }, list),
	})

	local bottom
	if editing and sel ~= nil then
		local bar = {
			ui.glyph({ name = "keyboard", size = 18, color = "primary" }),
			ui.input({
				key = "edit-" .. inputKey,
				value = editKeys,
				placeholder = "Super+Shift+T",
				fontSize = 15,
				frameVisible = true,
				focus = true,
				flexGrow = 1,
				onChange = "onEditChanged",
				onSubmit = "onSave",
			}),
			ui.button({ text = busy and "…" or "Save  ↵", variant = "primary", controlSize = "sm", enabled = not busy, onClick = "onSave" }),
		}
		if sel.custom == true then
			table.insert(bar, ui.button({ text = "Back to default", variant = "ghost", controlSize = "sm", enabled = not busy, onClick = "onResetKeys" }))
		end
		table.insert(bar, ui.button({ text = "Cancel", variant = "ghost", controlSize = "sm", onClick = "onCancelEdit" }))
		local children = {
			ui.label({ text = "Change the keys for: " .. str(sel.action), fontSize = 13, fontWeight = "semibold", maxLines = 1 }),
			ui.row({ gap = 8, align = "center" }, bar),
		}
		if errorText ~= nil then
			table.insert(children, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 3 }))
		else
			table.insert(children, ui.label({ text = "Type the keys joined with +, for example Super+Alt+K. BxRig refuses a combo that is already used.", fontSize = 11, color = "on_surface_variant", maxLines = 2 }))
		end
		bottom = ui.column({ gap = 6, paddingH = 14, paddingV = 10, radius = 12, fill = "surface_container" }, children)
	else
		local locked = sel ~= nil and str(sel.how) == "xremap"
		local hint = statusText or "Select a shortcut and press Enter to change its keys"
		if sel ~= nil and statusText == nil then
			hint = locked and "This one is a Cmd-style remap (xremap): it cannot be changed here" or str(sel.action)
		end
		bottom = ui.row({ align = "center", gap = 8, paddingH = 14, paddingV = 8, fill = "surface_container", radius = 10 }, {
			ui.label({ text = hint, fontSize = 12, color = statusText ~= nil and "primary" or "on_surface_variant", flexGrow = 1, maxLines = 1 }),
			ui.button({ text = "Change  ↵", glyph = "pencil", variant = "primary", controlSize = "sm", enabled = sel ~= nil and not locked, onClick = "onChange" }),
		})
	end

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, { search, tabs, ui.separator({}), body, bottom }))
end

local function fetch()
	loading = true
	bxrig.json({ "keys", "show", "--json" }, function(result, err)
		loading = false
		if err ~= nil then
			errorText = err
			rows = {}
		else
			errorText = nil
			rows = type(result.shortcuts) == "table" and result.shortcuts or {}
		end
		buildGroups()
		refilter()
		render()
	end, 30000)
end

local function move(delta)
	if #visible == 0 or editing then
		return
	end
	selected = math.max(1, math.min(#visible, selected + delta))
	render()
end

local function nextGroup()
	if editing then
		return
	end
	local at = 1
	for i, g in ipairs(groups) do
		if g == group then
			at = i
		end
	end
	group = groups[(at % #groups) + 1] or "All"
	refilter()
	render()
end

function onQueryChanged(value)
	query = value or ""
	statusText = nil
	refilter()
	render()
end

function onEditChanged(value)
	editKeys = value or ""
end

function startEdit()
	local sel = selectedRow()
	if sel == nil or str(sel.how) == "xremap" then
		return
	end
	editing = true
	editKeys = str(sel.keys)
	errorText = nil
	statusText = nil
	inputKey += 1
	render()
end

function onChange()
	startEdit()
end

function onCancelEdit()
	editing = false
	errorText = nil
	inputKey += 1
	render()
end

-- Runs `keys set` and then `keys apply`; the first line of an error is shown as it is.
local function finish(ok, message, done)
	busy = false
	if not ok then
		errorText = message ~= "" and message or "BxRig did not accept that"
		render()
		return
	end
	editing = false
	errorText = nil
	statusText = done
	inputKey += 1
	fetch()
end

function onSave()
	local now = noctalia.nowMs()
	if now - lastSubmitMs < 300 then
		return
	end
	lastSubmitMs = now
	local sel = selectedRow()
	local keys = noctalia.string.trim(editKeys)
	if sel == nil or busy or keys == "" then
		return
	end
	busy = true
	errorText = nil
	render()
	bxrig.run({ "keys", "set", str(sel.id), keys, "--yes" }, function(ok, message)
		if not ok then
			finish(false, message, "")
			return
		end
		bxrig.run({ "keys", "apply", "--yes" }, function(ok2, message2)
			finish(ok2, message2, str(sel.action) .. " is now " .. keys .. ". Reload Hyprland to use it.")
		end, 120000)
	end, 60000)
end

function onResetKeys()
	local sel = selectedRow()
	if sel == nil or busy then
		return
	end
	busy = true
	render()
	bxrig.run({ "keys", "reset", str(sel.id), "--yes" }, function(ok, message)
		if not ok then
			finish(false, message, "")
			return
		end
		bxrig.run({ "keys", "apply", "--yes" }, function(ok2, message2)
			finish(ok2, message2, str(sel.action) .. " is back to its default keys.")
		end, 120000)
	end, 60000)
end

function onSubmit()
	-- Enter can reach us both through the input's onSubmit and onKey("Return").
	local now = noctalia.nowMs()
	if now - lastSubmitMs < 300 then
		return
	end
	lastSubmitMs = now
	if editing then
		return
	end
	startEdit()
end

function onKey(chord, pressed)
	if not pressed then
		return
	end
	if editing then
		if chord == "Return" or chord == "KP_Enter" then
			onSave()
		end
		return
	end
	if chord == "Up" then
		move(-1)
	elseif chord == "Down" then
		move(1)
	elseif chord == "Page_Up" then
		move(-6)
	elseif chord == "Page_Down" then
		move(6)
	elseif chord == "Tab" then
		nextGroup()
	elseif chord == "Return" or chord == "KP_Enter" then
		onSubmit()
	end
end

function onOpen(_context)
	group = "All"
	query = ""
	inputKey += 1
	errorText = nil
	statusText = nil
	editing = false
	busy = false
	selected = 1
	render()
	fetch()
end
