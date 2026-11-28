--!nonstrict
-- Runs `bxrig <args> --json`-style commands and unwraps BxRig's JSON envelope
-- ({ "ok": true, "data": {...} }). Each entry loads its own copy; the same file
-- ships in every BxRig plugin.
--
-- The executable comes from the plugin-level "command" setting (default
-- "bxrig"), so a user whose shell PATH lacks ~/.local/bin can point it at an
-- absolute path.

local M = {}

local function trim(s)
	return noctalia.string.trim(s or "")
end

function M.command()
	local cmd = noctalia.getConfig("command")
	if type(cmd) ~= "string" or trim(cmd) == "" then
		cmd = "bxrig"
	end
	cmd = trim(cmd)
	if cmd:sub(1, 1) == "~" then
		cmd = noctalia.expandPath(cmd)
	end
	return cmd
end

local function argv(args)
	local out = { M.command() }
	for _, a in ipairs(args) do
		table.insert(out, a)
	end
	return out
end

local function firstLine(s)
	s = trim(s)
	local line = s:match("^[^\n]*") or s
	return line
end

-- callback(data, err): data is the envelope's `data` table on success.
function M.json(args, callback, timeoutMs)
	local started = noctalia.runAsync(argv(args), function(res)
		if res.timedOut then
			callback(nil, "bxrig timed out")
			return
		end
		local decoded = noctalia.json.decode(res.stdout or "")
		if type(decoded) ~= "table" then
			local why = firstLine(res.stderr)
			if why == "" then
				why = `bxrig exited with code {res.exitCode}`
			end
			callback(nil, why)
			return
		end
		if decoded.ok ~= true then
			local why = nil
			if type(decoded.data) == "table" and type(decoded.data.error) == "string" then
				why = decoded.data.error
			elseif type(decoded.error) == "string" then
				why = decoded.error
			end
			callback(nil, why or "bxrig reported an error")
			return
		end
		callback(type(decoded.data) == "table" and decoded.data or {}, nil)
	end, timeoutMs or 15000)
	if not started then
		callback(nil, "could not start " .. M.command())
	end
end

-- Runs a bxrig command; onDone(ok, message) is optional.
function M.run(args, onDone, timeoutMs)
	if onDone == nil then
		return noctalia.runAsync(argv(args))
	end
	return noctalia.runAsync(argv(args), function(res)
		local ok = res.exitCode == 0 and not res.timedOut
		local msg = firstLine(res.stderr)
		if msg == "" then
			msg = firstLine(res.stdout)
		end
		onDone(ok, msg)
	end, timeoutMs or 60000)
end

-- Window mode: a bar popup can detach into a bigger floating window (the plugin's "panel-window" entry, the same script with the panel
-- setting `window = true`) and dock back. Panel size is fixed by the manifest, so the window is a second entry, not a resize.

-- True when this script runs in a window entry.
function M.isWindow()
	return noctalia.getConfig("window") == true
end

local function shellQuote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Swaps the popup and its window: closes this panel and opens the other one.
-- plugin: "bxrig/clock", panel: the popup's entry id ("panel").
function M.swapWindow(plugin, panelId)
	local window = M.isWindow()
	panel.close()
	noctalia.togglePanel(plugin .. ":" .. (window and panelId or (panelId .. "-window")))
end

-- The header buttons of a detachable panel: a terminal button when a `bxrig tui` page matches (opts.tui), and Detach in the popup or Dock in
-- the window. opts: { plugin = "bxrig/clock", panel = "panel", tui = "ai-agents" or nil }. Returns a list of ui nodes.
function M.windowButtons(opts)
	local out = {}
	local window = M.isWindow()
	if opts.tui ~= nil then
		table.insert(out, ui.button({
			key = "bxrig-tui",
			glyph = "terminal-2",
			variant = "ghost",
			controlSize = "sm",
			tooltip = "Open this page in a terminal",
			onClick = function()
				noctalia.runInTerminal(shellQuote(M.command()) .. " tui " .. shellQuote(opts.tui))
			end,
		}))
	end
	table.insert(out, ui.button({
		key = "bxrig-window",
		glyph = window and "arrows-minimize" or "arrows-maximize",
		variant = "ghost",
		controlSize = "sm",
		tooltip = window and "Dock back to the bar" or "Detach into a window",
		onClick = function()
			M.swapWindow(opts.plugin, opts.panel)
		end,
	}))
	return out
end

return M
