--!nonstrict
-- The BoxLang tab of the Agents panel: the bx-agents agents on this machine (Boxy and the rest).
--   each agent: running or not, its address, Start or Stop (`bxrig ai agents start|stop NAME`), Chat (its chat in a terminal:
--   `bxrig ai agents NAME chat`) and its web page when it runs; the default one marked
--   bx-agents missing: Install (`bxrig ai agents install --yes`, the latest snapshot)
--   BoxLang agents page: the Control Center page in a terminal (`bxrig tui ai-boxlang`)
-- Data: `bxrig ai agents --json`. Colors are palette roles only, so the tab follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local M = {}

local data = nil
local errorText = nil
local busy = nil -- the agent being started or stopped, or "install"

local str = kit.str

local function shq(s)
	return "'" .. string.gsub(str(s), "'", "'\\''") .. "'"
end

function M.fetch(render)
	bxrig.json({ "ai", "agents", "--json" }, function(result, err)
		if err ~= nil then
			errorText = err
		else
			data = result
			errorText = nil
		end
		render()
	end, 30000)
end

local function act(render, key, args, timeoutMs)
	busy = key
	render()
	bxrig.run(args, function(ok, msg)
		busy = nil
		if not ok then
			errorText = msg
		end
		M.fetch(render)
	end, timeoutMs)
end

local function agentRow(a, render)
	local running = a.running == true
	local sub = running and str(a.url) or ("stopped · port " .. str(a.port))
	local row = {
		ui.glyph({ name = running and "circle-filled" or "circle", size = 12, color = running and "primary" or "on_surface_variant" }),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.row({ align = "center", gap = 6 }, {
				ui.label({ text = str(a.name), fontSize = 13, fontWeight = "semibold", maxLines = 1 }),
				a.default == true and ui.label({ text = "DEFAULT", fontSize = 10, fontWeight = "bold", color = "primary" }) or ui.spacer({}),
			}),
			ui.label({ text = sub, fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
		}),
		ui.button({ key = "chat-" .. str(a.name), glyph = "message-chatbot", variant = "ghost", controlSize = "sm", tooltip = "Chat in a terminal", onClick = function()
			noctalia.runInTerminal(shq(bxrig.command()) .. " ai agents " .. shq(a.name) .. " chat")
			panel.close()
		end }),
	}
	if running then
		table.insert(row, ui.button({ key = "web-" .. str(a.name), glyph = "world", variant = "ghost", controlSize = "sm", tooltip = "Its web page", onClick = function()
			bxrig.run({ "ai", "agents", "open", str(a.name) }, function() end, 10000)
		end }))
	end
	table.insert(row, ui.button({
		key = "svc-" .. str(a.name),
		text = busy == a.name and "…" or (running and "Stop" or "Start"),
		glyph = running and "player-stop" or "player-play",
		variant = "ghost",
		controlSize = "sm",
		onClick = function()
			act(render, a.name, { "ai", "agents", running and "stop" or "start", str(a.name) }, 120000)
		end,
	}))
	return ui.row({ key = "agent-" .. str(a.name), align = "center", gap = 8 }, row)
end

function M.view(render)
	if data == nil then
		return ui.column({ paddingV = 16, align = "center", gap = 6 }, {
			ui.glyph({ name = errorText ~= nil and "alert-triangle" or "loader", size = 20, color = errorText ~= nil and "error" or "on_surface_variant" }),
			ui.label({ text = errorText or "Loading…", fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 4 }),
		})
	end
	local children = {}
	if data.installed ~= true then
		table.insert(children, ui.row({ align = "center", gap = 8 }, {
			ui.glyph({ name = "download", size = 16, color = "primary" }),
			ui.label({ text = "bx-agents is not installed", fontSize = 12, flexGrow = 1 }),
			ui.button({ key = "install", text = busy == "install" and "…" or "Install", variant = "ghost", controlSize = "sm", onClick = function()
				act(render, "install", { "ai", "agents", "install", "--yes" }, 900000)
			end }),
		}))
	end
	local agents = type(data.agents) == "table" and data.agents or {}
	for _, a in ipairs(agents) do
		if type(a) == "table" then
			table.insert(children, agentRow(a, render))
		end
	end
	if #agents == 0 then
		table.insert(children, ui.label({ text = "No BoxLang agents yet. In a terminal: bxrig ai agents new Boxy", fontSize = 11, color = "on_surface_variant", maxLines = 3 }))
	end
	table.insert(children, ui.label({ text = "Projects in " .. str(data.root), fontSize = 10, color = "on_surface_variant", maxLines = 1 }))
	if errorText ~= nil then
		table.insert(children, ui.label({ text = errorText, fontSize = 10, color = "error", maxLines = 2 }))
	end
	return ui.scroll({ flexGrow = 1, gap = 10 }, children)
end

-- The footer button: the Control Center's BoxLang agents page in a terminal.
function M.openPage()
	noctalia.runInTerminal(shq(bxrig.command()) .. " tui ai-boxlang")
	panel.close()
end

return M
