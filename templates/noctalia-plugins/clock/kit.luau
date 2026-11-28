--!nonstrict
-- BxRig panel kit: the small pieces every panel of the BxRig Noctalia plugins builds the same way (a nil-safe string, a search row, tab chips, a
-- footer bar, a grid of tiles, a guard against a double Enter, a guard against a late answer). Each piece is a plain function that takes a table
-- of options and returns what it makes; the kit keeps no state of its own except the closures `sequence` and `once` hand back, so a panel owns
-- its state and its render() and uses the kit only to build and guard. The same file ships in every plugin (the test keeps the copies identical).
--
--   kit.str(v)                       tostring that gives "" for nil
--   kit.sequence()                   { next() -> token, isCurrent(token) -> bool }: take a token before an async call, drop the answer when it is stale
--   kit.once(ms)                     a guard function: true the first time, then false until ms have passed (Enter reaches a panel twice)
--   kit.clamp(index, delta, count)   a selection moved by delta and kept inside 1..count (stays 1 when count is 0)
--   kit.searchRow(opts)              { glyph, key, value, placeholder, count, fontSize, glyphSize, paddingH, paddingV, radius, fill, focus (default true), onChange, onSubmit } -> the search row
--   kit.tabRow(opts)                 { tabs = {id | {id, label}}, current, onSelect(id), keyPrefix, gap, paddingH, paddingV } -> a row of chips
--   kit.footer(opts)                 { hint, hintColor, hintSize, leading = {nodes}, buttons = {nodes} } -> the bar at the bottom of a panel
--   kit.grid(opts)                   { items = {nodes}, columns, gap, justify } -> a list of rows to put in a scroll
--   kit.screenSize()                 the focused output's logical width and height (a window-mode panel lays itself out from it)
--   kit.windowButton(plugin, panel)  the footer button that swaps a popup and its window ("Window  F3" / "Popup  F3"); F3 calls kit.swap too
--   kit.swap(plugin, panel)          swaps the popup and its window (bxrig.swapWindow)
-- Colors are palette roles only, so a panel built from the kit follows the active theme.

local bxrig = require("./bxrig.luau")

local M = {}

-- tostring that gives "" for nil.
function M.str(v)
	if v == nil then
		return ""
	end
	return tostring(v)
end

-- A late-answer guard: `local seq = kit.sequence()`, `local mine = seq.next()` before an async call, and in its callback
-- `if not seq.isCurrent(mine) then return end`.
function M.sequence()
	local n = 0
	return {
		next = function()
			n += 1
			return n
		end,
		isCurrent = function(token)
			return token == n
		end,
	}
end

-- A double-submit guard: `local once = kit.once(300)`, then `if not once() then return end`.
function M.once(ms)
	local last = -ms
	return function()
		local now = noctalia.nowMs()
		if now - last < ms then
			return false
		end
		last = now
		return true
	end
end

-- A selection moved by delta and kept inside 1..count.
function M.clamp(index, delta, count)
	if count <= 0 then
		return 1
	end
	return math.max(1, math.min(count, index + delta))
end

-- The search row: a glyph, the input (focused, frameless, grows) and an optional count on the right.
-- opts.key must change to reset the input (panels bump a counter when they open).
function M.searchRow(opts)
	local children = {
		ui.glyph({ name = opts.glyph or "search", size = opts.glyphSize or 18, color = "on_surface_variant" }),
		ui.input({
			key = opts.key,
			value = opts.value or "",
			placeholder = opts.placeholder or "",
			fontSize = opts.fontSize or 16,
			frameVisible = false,
			focus = opts.focus ~= false,
			flexGrow = 1,
			onChange = opts.onChange or "onQueryChanged",
			onSubmit = opts.onSubmit or "onSubmit",
		}),
	}
	if opts.count ~= nil then
		table.insert(children, ui.label({ text = M.str(opts.count), fontSize = 11, color = "on_surface_variant" }))
	end
	return ui.row({
		align = "center",
		gap = 10,
		paddingH = opts.paddingH or 14,
		paddingV = opts.paddingV or 6,
		radius = opts.radius,
		fill = opts.fill,
	}, children)
end

-- A row of tab chips. A tab is an id or { id, label }; the current one is highlighted (nil highlights none); a click calls onSelect(id).
function M.tabRow(opts)
	local chips = {}
	for _, tab in ipairs(opts.tabs) do
		local id = tab
		local label = tab
		if type(tab) == "table" then
			id = tab[1]
			label = tab[2] or tab[1]
		end
		table.insert(chips, ui.button({
			key = (opts.keyPrefix or "tab-") .. M.str(id),
			text = M.str(label),
			variant = id == opts.current and "secondary" or "ghost",
			controlSize = "sm",
			onClick = function()
				opts.onSelect(id)
			end,
		}))
	end
	return ui.row({ gap = opts.gap or 4, paddingH = opts.paddingH or 10, paddingV = opts.paddingV or 2 }, chips)
end

-- The footer bar: a hint that grows, then the buttons.
function M.footer(opts)
	local children = {}
	for _, b in ipairs(opts.leading or {}) do
		table.insert(children, b)
	end
	table.insert(
		children,
		ui.label({
			text = M.str(opts.hint),
			fontSize = opts.hintSize or 12,
			color = opts.hintColor or "on_surface_variant",
			flexGrow = 1,
			maxLines = 1,
		})
	)
	for _, b in ipairs(opts.buttons or {}) do
		table.insert(children, b)
	end
	return ui.row({ align = "center", gap = 8, paddingH = 14, paddingV = 8, fill = "surface_container", radius = 10 }, children)
end

-- Items chunked into rows of `columns` (the last row may be short), left aligned by default.
function M.grid(opts)
	local rows = {}
	local current = {}
	for _, item in ipairs(opts.items) do
		table.insert(current, item)
		if #current == opts.columns then
			table.insert(rows, ui.row({ gap = opts.gap or 4, justify = opts.justify or "start" }, current))
			current = {}
		end
	end
	if #current > 0 then
		table.insert(rows, ui.row({ gap = opts.gap or 4, justify = opts.justify or "start" }, current))
	end
	return rows
end

-- The focused output's logical size; 1280x800 when Noctalia does not say.
function M.screenSize()
	local list = noctalia.outputs() or {}
	local focus = noctalia.focusedOutputName()
	for _, o in ipairs(list) do
		if focus == nil or o.name == focus then
			local scale = tonumber(o.scale) or 1
			if scale <= 0 then
				scale = 1
			end
			return (tonumber(o.width) or 1280) / scale, (tonumber(o.height) or 800) / scale
		end
	end
	return 1280, 800
end

-- Swaps a popup and its window: plugin "bxrig/launcher", panel "emoji" (the popup's entry id).
function M.swap(plugin, panelId)
	bxrig.swapWindow(plugin, panelId)
end

-- The footer button that swaps popup and window.
function M.windowButton(plugin, panelId)
	local window = bxrig.isWindow()
	return ui.button({
		key = "kit-window",
		text = window and "Popup  F3" or "Window  F3",
		glyph = window and "arrows-minimize" or "arrows-maximize",
		variant = "ghost",
		controlSize = "sm",
		onClick = function()
			M.swap(plugin, panelId)
		end,
	})
end

return M
