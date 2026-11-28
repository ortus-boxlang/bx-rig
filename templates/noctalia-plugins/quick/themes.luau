--!nonstrict
-- BxRig Quick settings, page 2: the theme switcher (Omarchy-style). It is the panel `themes` of bxrig/quick, opened by the "Themes" row of
-- the first page (panel.luau) or with `noctalia msg panel-toggle bxrig/quick:themes`. "Search themes…" box, theme list on the
-- left with the current one marked "✓ Current", the highlighted theme's
-- preview and an Information section on the right, "Apply Theme ↵" footer.
--
-- Keys: type to filter, Up/Down/PageUp/PageDown move, Enter applies, Esc closes.
-- Mouse: click a theme to highlight it, click it again (or the footer button)
-- to apply.
--
-- Data: `bxrig theme list --json` on every open.
-- Apply: `bxrig theme set <name> --yes`, then the panel closes.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")

local themes = {} -- all themes from bxrig
local current = nil -- name of the active theme
local visible = {} -- filtered view: indexes into `themes`
local selected = 1 -- index into `visible`
local query = ""
local inputKey = 0
local errorText = nil
local loading = false
local applying = nil -- name being applied
local lastSubmitMs = 0

local function str(v)
	if v == nil then
		return ""
	end
	return tostring(v)
end

local function displayName(theme)
	local label = str(theme.label)
	if label == "" then
		return str(theme.name)
	end
	return label
end

local function refilter()
	local keepName = nil
	local sel = visible[selected]
	if sel ~= nil and themes[sel] ~= nil then
		keepName = themes[sel].name
	end

	visible = {}
	local q = noctalia.string.trim(query)
	for i, theme in ipairs(themes) do
		if q == "" or noctalia.fuzzyScore(q, displayName(theme)) ~= nil or noctalia.fuzzyScore(q, str(theme.name)) ~= nil then
			table.insert(visible, i)
		end
	end

	selected = 1
	local target = keepName
	if target == nil and q == "" then
		target = current
	end
	if target ~= nil then
		for vi, ti in ipairs(visible) do
			if themes[ti].name == target then
				selected = vi
				break
			end
		end
	end
end

local function selectedTheme()
	local ti = visible[selected]
	if ti == nil then
		return nil
	end
	return themes[ti]
end

-- Preview image, else the theme's wallpaper, else nil (placeholder).
local function previewPath(theme)
	if theme == nil then
		return nil
	end
	for _, field in ipairs({ "preview", "wallpaper" }) do
		local p = str(theme[field])
		if p ~= "" then
			local expanded = p:sub(1, 1) == "~" and noctalia.expandPath(p) or p
			if noctalia.fileExists(expanded) then
				return expanded
			end
		end
	end
	return nil
end

local function infoRow(key, value)
	return ui.row({ align = "center", gap = 8 }, {
		ui.label({ text = key, fontSize = 12, color = "on_surface_variant" }),
		ui.spacer({ flexGrow = 1 }),
		ui.label({ text = value, fontSize = 12, fontWeight = "semibold", maxLines = 1 }),
	})
end

local function render()
	-- Search row.
	local search = ui.row({ align = "center", gap = 10, paddingH = 14, paddingV = 6 }, {
		ui.glyph({ name = "search", size = 18, color = "on_surface_variant" }),
		ui.input({
			key = "search-" .. inputKey,
			value = query,
			placeholder = "Search themes…",
			fontSize = 16,
			frameVisible = false,
			focus = true,
			flexGrow = 1,
			onChange = "onQueryChanged",
			onSubmit = "onSubmit",
		}),
	})

	-- Left: theme list.
	local rows = {}
	if loading and #themes == 0 then
		table.insert(rows, ui.label({ text = "Loading themes…", fontSize = 13, color = "on_surface_variant" }))
	elseif errorText ~= nil and #themes == 0 then
		table.insert(rows, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 6 }))
	elseif #visible == 0 then
		table.insert(rows, ui.label({ text = "No matching themes", fontSize = 13, color = "on_surface_variant" }))
	end
	for vi, ti in ipairs(visible) do
		local theme = themes[ti]
		local isSel = vi == selected
		local children = {
			ui.label({
				text = displayName(theme),
				fontSize = 14,
				fontWeight = isSel and "semibold" or "normal",
				color = isSel and "on_surface" or "on_surface_variant",
				flexGrow = 1,
				maxLines = 1,
			}),
		}
		if theme.name == current then
			table.insert(children, ui.glyph({ name = "check", size = 14, color = "primary" }))
			table.insert(children, ui.label({ text = "Current", fontSize = 12, color = "primary" }))
		end
		table.insert(rows, ui.row({
			key = "theme-" .. str(theme.name),
			align = "center",
			gap = 6,
			paddingH = 12,
			paddingV = 9,
			radius = 8,
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
		}, children))
	end
	local selTheme = selectedTheme()
	local list = ui.scroll({
		width = 300,
		height = 420,
		gap = 2,
		padding = 8,
		revealKey = selTheme and ("theme-" .. str(selTheme.name)) or nil,
	}, rows)

	-- Right: preview + information.
	local preview
	local path = previewPath(selTheme)
	if path ~= nil then
		preview = ui.image({ key = "preview-" .. path, path = path, fit = "cover", radius = 10, height = 380 })
	else
		preview = ui.column({ height = 380, radius = 10, fill = "surface_container", align = "center", justify = "center", gap = 6 }, {
			ui.glyph({ name = "photo-off", size = 32, color = "on_surface_variant" }),
			ui.label({ text = selTheme and "No preview" or "", fontSize = 12, color = "on_surface_variant" }),
		})
	end
	local info = {
		ui.label({ text = "Information", fontSize = 13, fontWeight = "bold" }),
	}
	if selTheme ~= nil then
		table.insert(info, infoRow("Theme", displayName(selTheme)))
		table.insert(info, infoRow("Mode", selTheme.light == true and "Light" or "Dark"))
	end
	-- the theme's name and mode live in the footer (a column under the preview grew past the panel in Noctalia 5.5)
	local right = ui.column({ flexGrow = 1, padding = 14 }, { preview })

	-- Footer.
	local status = "Switch Theme"
	if selTheme ~= nil then status = displayName(selTheme) .. "  ·  " .. (selTheme.light == true and "Light" or "Dark") .. " theme with its own wallpaper" end
	local statusColor = "on_surface_variant"
	if applying ~= nil then
		status = "Applying " .. applying .. "…"
		statusColor = "primary"
	elseif errorText ~= nil and #themes > 0 then
		status = errorText
		statusColor = "error"
	end
	local footer = ui.row({ align = "center", gap = 8, paddingH = 14, paddingV = 8, fill = "surface_container", radius = 10 }, {
		ui.button({ glyph = "arrow-left", text = "Quick settings", variant = "ghost", controlSize = "sm", onClick = "onBack" }),
		ui.label({ text = status, fontSize = 12, color = statusColor, flexGrow = 1, maxLines = 1 }),
		ui.row({ gap = 2 }, bxrig.windowButtons({ plugin = "bxrig/quick", panel = "themes", tui = "themes" })),
		ui.button({
			text = "Apply Theme  ↵",
			variant = "primary",
			controlSize = "sm",
			enabled = selTheme ~= nil and applying == nil,
			onClick = "onSubmit",
		}),
	})

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, {
		search,
		ui.separator({}),
		ui.row({ height = bxrig.isWindow() and 540 or 420, gap = 0, align = "start" }, {
			list,
			ui.separator({ orientation = "vertical" }),
			right,
		}),
		footer,
	}))
end

local function fetch()
	loading = true
	bxrig.json({ "theme", "list", "--json" }, function(result, err)
		loading = false
		if err ~= nil then
			errorText = err
		else
			errorText = nil
			themes = type(result.themes) == "table" and result.themes or {}
			current = type(result.current) == "string" and result.current or nil
			refilter()
		end
		render()
	end)
end

local function move(delta)
	if #visible == 0 then
		return
	end
	selected = math.max(1, math.min(#visible, selected + delta))
	render()
end

function onQueryChanged(value)
	query = value or ""
	refilter()
	render()
end

function onSubmit()
	-- Enter can reach us both through the input's onSubmit and onKey("Return").
	local now = noctalia.nowMs()
	if now - lastSubmitMs < 300 then
		return
	end
	lastSubmitMs = now
	local theme = selectedTheme()
	if theme == nil or applying ~= nil then
		return
	end
	local name = str(theme.name)
	applying = displayName(theme)
	render()
	bxrig.run({ "theme", "set", name, "--yes" }, function(ok, message)
		applying = nil
		if not ok then
			noctalia.notifyError("Theme", message ~= "" and message or ("Could not apply " .. name))
		end
	end, 60000)
	panel.close()
end

-- Back to page 1. Opening a panel replaces the open one (the shell keeps one panel in its slot), so this does not close first.
function onBack()
	noctalia.togglePanel("bxrig/quick:panel")
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
	applying = nil
	errorText = nil
	refilter()
	render()
	fetch()
end
