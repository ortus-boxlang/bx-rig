--!nonstrict
-- BxRig Apps: every installed application as a grid of icon tiles (the "app grid"), in the Noctalia look. A tab row filters by group
-- (Development, Internet, Media, ...), typing filters by name at once, and the arrow keys move over the grid. Two icon styles: "App" shows the
-- application's own icon, "Theme" shows a glyph for its group on a tile tinted with the Noctalia theme colours.
--
-- Keys: type to filter, arrows move over the grid, PageUp/PageDown jump three rows, Tab goes to the next group, F2 switches the icon style,
-- Enter starts the application, Esc closes. Mouse: click an application to highlight it, click it again to start it; the tabs and the
-- "Icons" button work by click.
-- Data: `bxrig apps list --json` on open (id, name, comment, group, glyph, tone, iconPath, uses). Start: `bxrig launcher run app:ID`, which also
-- counts the use, so the "Recent" tab (apps you started, most used first) fills as you go; then the panel closes.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local COLUMNS = 5
local GRID_H = 400

local PLUGIN = "bxrig/launcher"

local apps = {}
local visible = {}
local groups = {}
local group = "All"
local selected = 1
local query = ""
local inputKey = 0
local iconStyle = "app" -- "app" or "theme"
local errorText = nil
local loading = false
local submitOnce = kit.once(300)

local TONES = { primary = true, secondary = true, tertiary = true, error = true }

local str = kit.str

local function toneOf(a)
	local t = str(a.tone)
	if TONES[t] then
		return t
	end
	return "primary"
end

local function recentCount()
	local n = 0
	for _, a in ipairs(apps) do
		if (tonumber(a.uses) or 0) > 0 then
			n += 1
		end
	end
	return n
end

local function buildGroups()
	local seen = {}
	local list = {}
	for _, a in ipairs(apps) do
		local g = str(a.group)
		if g ~= "" and not seen[g] then
			seen[g] = true
			table.insert(list, g)
		end
	end
	table.sort(list)
	local tabs = { "All" }
	if recentCount() > 0 then
		table.insert(tabs, "Recent")
	end
	for _, g in ipairs(list) do
		table.insert(tabs, g)
	end
	groups = tabs
end

local function refilter()
	local q = noctalia.string.trim(query)
	local scored = {}
	for i, a in ipairs(apps) do
		local ok = true
		if group == "Recent" then
			ok = (tonumber(a.uses) or 0) > 0
		elseif group ~= "All" then
			ok = str(a.group) == group
		end
		if ok then
			local score = 0
			if q ~= "" then
				local s = noctalia.fuzzyScore(q, str(a.name))
				if s == nil then
					ok = false
				else
					-- a name that starts with what you typed, or contains it, beats scattered letters
					local lname = str(a.name):lower()
					local lq = q:lower()
					score = s
					if lname:sub(1, #lq) == lq then
						score += 1000
					elseif lname:find(lq, 1, true) ~= nil then
						score += 500
					end
				end
			end
			if ok then
				table.insert(scored, { index = i, score = score })
			end
		end
	end
	if q ~= "" then
		table.sort(scored, function(x, y)
			return x.score > y.score
		end)
	elseif group == "Recent" then
		table.sort(scored, function(x, y)
			return (tonumber(apps[x.index].uses) or 0) > (tonumber(apps[y.index].uses) or 0)
		end)
	end
	visible = {}
	for _, s in ipairs(scored) do
		table.insert(visible, s.index)
	end
	selected = 1
end

local function selectedApp()
	local i = visible[selected]
	if i == nil then
		return nil
	end
	return apps[i]
end

-- The tile: the application's own picture on a neutral tile, or a group glyph on a tile tinted with the theme.
local function tile(a, size)
	local path = str(a.iconPath)
	if iconStyle == "app" and path ~= "" and noctalia.fileExists(path) then
		return ui.column({ width = size, height = size, radius = 16, fill = "on_surface/0.06", align = "center", justify = "center" }, {
			ui.image({ key = "img-" .. str(a.id), path = path, fit = "contain", width = size - 14, height = size - 14 }),
		})
	end
	local t = toneOf(a)
	local name = str(a.glyph)
	if name == "" then
		name = "app-window"
	end
	return ui.column({ width = size, height = size, radius = 16, fill = t .. "/0.16", align = "center", justify = "center" }, {
		ui.glyph({ name = name, size = size - 28, color = t }),
	})
end

local function cell(vi, a)
	local isSel = vi == selected
	return ui.column({
		key = "cell-" .. str(a.id),
		width = 132,
		align = "center",
		gap = 6,
		paddingH = 6,
		paddingV = 10,
		radius = 16,
		-- An explicit transparent fill: a nil fill keeps the retained one.
		fill = isSel and "primary/0.14" or "on_surface/0",
		onClick = function()
			if vi == selected then
				onSubmit()
			else
				selected = vi
				render()
			end
		end,
	}, {
		tile(a, 64),
		ui.label({ text = str(a.name), fontSize = 12, fontWeight = isSel and "semibold" or "normal", textAlign = "center", maxLines = 2 }),
	})
end

function render()
	local search = kit.searchRow({ key = "search-" .. inputKey, value = query, placeholder = "Filter applications…", count = tostring(#visible) .. " apps" })

	local tabs = kit.tabRow({
		tabs = groups,
		current = group,
		onSelect = function(g)
			group = g
			refilter()
			render()
		end,
	})

	local cells = {}
	for vi, ai in ipairs(visible) do
		table.insert(cells, cell(vi, apps[ai]))
	end
	local rows = kit.grid({ items = cells, columns = COLUMNS })
	if loading and #apps == 0 then
		table.insert(rows, ui.label({ text = "Loading applications…", fontSize = 13, color = "on_surface_variant" }))
	elseif errorText ~= nil then
		table.insert(rows, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 6 }))
	elseif #visible == 0 then
		table.insert(rows, ui.label({ text = "No application matches", fontSize = 13, color = "on_surface_variant" }))
	end
	local sel = selectedApp()
	local grid = ui.column({ height = GRID_H }, {
		ui.scroll({ flexGrow = 1, gap = 4, padding = 8, revealKey = sel and ("cell-" .. str(sel.id)) or nil }, rows),
	})

	local hint = "Arrows move, Enter starts, Tab changes group"
	if sel ~= nil then
		hint = str(sel.name)
		local comment = str(sel.comment)
		if comment ~= "" then
			hint = hint .. "  ·  " .. comment
		end
	end
	local footer = kit.footer({
		hint = hint,
		buttons = {
			ui.button({
				text = iconStyle == "app" and "Icons: App  F2" or "Icons: Theme  F2",
				glyph = "palette",
				variant = "ghost",
				controlSize = "sm",
				onClick = "onToggleStyle",
			}),
			kit.windowButton(PLUGIN, "apps"),
			ui.button({ text = "Open  ↵", variant = "primary", controlSize = "sm", enabled = sel ~= nil, onClick = "onSubmit" }),
		},
	})

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, { search, tabs, ui.separator({}), grid, footer }))
end

local function fetch()
	loading = true
	bxrig.json({ "apps", "list", "--json" }, function(result, err)
		loading = false
		if err ~= nil then
			errorText = err
			apps = {}
		else
			errorText = nil
			apps = type(result.apps) == "table" and result.apps or {}
		end
		buildGroups()
		refilter()
		render()
	end, 30000)
end

local function move(delta)
	selected = kit.clamp(selected, delta, #visible)
	render()
end

local function nextGroup()
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
	refilter()
	render()
end

function onToggleStyle()
	iconStyle = iconStyle == "app" and "theme" or "app"
	render()
end

function onSubmit()
	-- Enter can reach us both through the input's onSubmit and onKey("Return").
	if not submitOnce() then
		return
	end
	local a = selectedApp()
	if a == nil then
		return
	end
	bxrig.run({ "launcher", "run", "app:" .. str(a.id) }, function(ok, message)
		if not ok then
			noctalia.notifyError("Apps", message ~= "" and message or ("Could not start " .. str(a.name)))
		end
	end, 30000)
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
		nextGroup()
	elseif chord == "F2" then
		onToggleStyle()
	elseif chord == "F3" then
		kit.swap(PLUGIN, "apps")
	elseif chord == "Return" or chord == "KP_Enter" then
		onSubmit()
	end
end

function onOpen(_context)
	if bxrig.isWindow() then
		local w, h = kit.screenSize()
		COLUMNS = math.max(5, math.floor((w - 120) / 136))
		GRID_H = math.max(400, math.floor(h - 340))
	end
	group = "All"
	query = ""
	inputKey += 1
	errorText = nil
	selected = 1
	render()
	fetch()
end
