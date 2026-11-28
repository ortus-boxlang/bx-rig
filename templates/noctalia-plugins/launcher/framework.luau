--!nonstrict
-- BxRig panel framework: how a BxRig Noctalia panel is built. A panel is one object made from a definition; the framework owns what every
-- panel had to do by hand: its state and re-render, the lifecycle (open, keys, close), fetching from `bxrig ... --json` without showing a
-- late answer, the double-Enter guard, popup and window (detach) mode, and the standard layout. The panel writes only what is its own:
-- the state it starts with, a view that turns state into a ui tree, its keys, and what to load.
--
--   local framework = require("./framework.luau")
--   local P = framework.panel({
--       plugin = "bxrig/launcher", id = "emoji",       -- the popup entry; its window twin is id .. "-window"
--       state = function() return { rows = {}, selected = 1 } end,   -- the state a panel opens with (a table or a function that returns one)
--       layout = function(self, width, height) end,    -- window mode only: lay the panel out for the screen (width, height are logical px)
--       open = function(self, context) end,            -- after the state is reset, before the first render; start loading here
--       view = function(self) return ui_tree end,      -- required: state in, ui tree out (call framework.stack for the standard column)
--       keys = { Up = function(self) end, F2 = "close" },  -- chord -> function(self) or "swap" / "close" / "submit"
--       submit = function(self) end,                   -- what Enter does (guarded, so it runs once even when Enter arrives twice)
--       swappable = true,                              -- F3 swaps popup and window (default true)
--   })
--   -- the entry script binds the host's global handlers to the panel (the host calls globals by name):
--   function onOpen(context) P:open(context) end
--   function onKey(chord, pressed) P:key(chord, pressed) end
--
-- The panel object:
--   P.state                    the current state table (read it in view and in handlers)
--   P:set(patch)               merge the patch into the state and re-render
--   P:render()                 re-render from the state
--   P:fetch(args, onData)      run `bxrig args` (the framework adds --json); sets state.loading and state.error; calls onData(data) only for
--                              the latest request of its channel, then re-renders. opts: { timeout = ms, channel = "name", onError = fn(err) }
--   P:run(args, onDone)        run a bxrig command without waiting on its data: onDone(ok, message)
--   P:move(delta, count)       move state.selected by delta inside 1..count and re-render
--   P:submitOnce(fn)           run fn unless it ran in the last 300 ms; returns whether it ran
--   P:swap() / P:close()       swap popup and window / close the panel
--   P.window                   true when this is the window entry
--   P:windowButton()           the footer button that swaps popup and window
--
-- State is plain Lua; the framework never reads it except state.loading and state.error. The view never changes state.
-- Colors are palette roles only, so a panel built on the framework follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local M = {}

local Panel = {}
Panel.__index = Panel

local function copyShallow(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

-- Makes a panel from its definition. See the header for the fields.
function M.panel(def)
	assert(type(def) == "table" and type(def.view) == "function", "framework.panel: a definition with a view function")
	local self = setmetatable({}, Panel)
	self.def = def
	self.plugin = def.plugin
	self.id = def.id
	self.window = bxrig.isWindow()
	self.state = {}
	self._channels = {}
	self._once = kit.once(def.submitMs or 300)
	return self
end

-- The state a panel starts with: its `state` table or function, shallow copied so a reopened panel starts fresh.
function Panel:reset()
	local initial = self.def.state
	if type(initial) == "function" then
		initial = initial()
	end
	self.state = copyShallow(initial or {})
end

-- Opens the panel: fresh state, window layout, the panel's own open, the first render.
function Panel:open(context)
	self:reset()
	if self.window and self.def.layout ~= nil then
		local w, h = kit.screenSize()
		self.def.layout(self, w, h)
	end
	if self.def.open ~= nil then
		self.def.open(self, context)
	end
	self:render()
end

-- Draws the view of the current state.
function Panel:render()
	panel.render(self.def.view(self))
end

-- Merges a patch into the state and draws again.
function Panel:set(patch)
	for k, v in pairs(patch) do
		self.state[k] = v
	end
	self:render()
end

-- A late-answer guard per channel: a panel that loads a list and, separately, the detail of one row uses two channels so neither drops the other.
function Panel:_channel(name)
	local ch = self._channels[name]
	if ch == nil then
		ch = kit.sequence()
		self._channels[name] = ch
	end
	return ch
end

-- Runs `bxrig ARGS --json`; the answer reaches onData only while it is the latest request of its channel (opts.channel, default "main").
-- Only the main channel drives state.loading and state.error.
function Panel:fetch(args, onData, opts)
	local channel = self:_channel(opts and opts.channel or "main")
	local isMain = opts == nil or opts.channel == nil or opts.channel == "main"
	local mine = channel.next()
	local full = {}
	for _, a in ipairs(args) do
		table.insert(full, a)
	end
	table.insert(full, "--json")
	if isMain then
		self.state.loading = true
	end
	bxrig.json(full, function(data, err)
		if not channel.isCurrent(mine) then
			return
		end
		if isMain then
			self.state.loading = false
		end
		if err ~= nil then
			if isMain then
				self.state.error = err
			end
			if opts ~= nil and opts.onError ~= nil then
				opts.onError(err)
			end
		else
			if isMain then
				self.state.error = nil
			end
			onData(data)
		end
		self:render()
	end, opts and opts.timeout or 15000)
end

-- Runs a bxrig command that has no data to show: onDone(ok, message) is optional.
function Panel:run(args, onDone, timeout)
	bxrig.run(args, onDone, timeout)
end

-- Moves state.selected by delta, kept inside 1..count, and draws again.
function Panel:move(delta, count)
	self.state.selected = kit.clamp(self.state.selected or 1, delta, count)
	self:render()
end

-- Runs fn at most once per guard window (Enter can reach a panel through the input and through the key handler).
function Panel:submitOnce(fn)
	if not self._once() then
		return false
	end
	fn()
	return true
end

function Panel:swap()
	kit.swap(self.plugin, self.id)
end

function Panel:close()
	panel.close()
end

-- The footer button that swaps popup and window.
function Panel:windowButton()
	return kit.windowButton(self.plugin, self.id)
end

-- Handles a key: the panel's own `keys` first (a function, or "swap", "close", "submit"), then F3 for popup and window.
function Panel:key(chord, pressed)
	if not pressed then
		return
	end
	local handler = self.def.keys and self.def.keys[chord]
	if handler == "swap" then
		self:swap()
	elseif handler == "close" then
		self:close()
	elseif handler == "submit" then
		self:submit()
	elseif type(handler) == "function" then
		handler(self)
	elseif chord == "F3" and self.def.swappable ~= false then
		self:swap()
	elseif (chord == "Return" or chord == "KP_Enter") and self.def.submit ~= nil then
		self:submit()
	end
end

-- Enter: the panel's submit, once.
function Panel:submit()
	if self.def.submit ~= nil then
		self:submitOnce(function()
			self.def.submit(self)
		end)
	end
end

-- The standard panel column: the children stacked with the usual gap and padding.
function M.stack(children)
	return ui.column({ flexGrow = 1, gap = 6, padding = 6 }, children)
end

-- A list body: a fixed-height column around a scroll (a scroll alone would push the footer off the panel).
function M.body(height, scrollOpts, children)
	local opts = copyShallow(scrollOpts or {})
	opts.flexGrow = opts.flexGrow or 1
	return ui.column({ height = height }, { ui.scroll(opts, children) })
end

return M
