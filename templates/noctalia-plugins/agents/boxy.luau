--!nonstrict
-- The Boxy tab of the Agents panel: your default BoxLang agent (Boxy unless you picked another).
--   the agent: running or not, Start or Stop (`bxrig ai agents start|stop NAME`), Chat in a terminal (`bxrig ai agents chat`) and
--   its web page (`bxrig ai agents open`)
--   Ask: one question, the answer below (`bxrig ai agents ask TEXT --json`); when the agent wants to change something it waits,
--   and Approve or Reject answers it (`bxrig ai agents approve|reject THREAD --json`)
--   new skills it saved for itself, not reviewed yet, with Review (`bxrig ai agents skills` in a terminal)
--   no agent yet: Make Boxy (`bxrig ai agents setup --yes`)
-- Data: `bxrig ai agents --json`. Colors are palette roles only, so the tab follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local M = {}

local data = nil
local look = nil -- `bxrig boxy --json`: { name, state, image, outfit, voice = { enabled } }
local errorText = nil
local busy = nil -- "ask", "decide", "service", "make"
local question = ""
local reply = nil -- { text, thread, pending = { { tool, args } } }

local str = kit.str

local function shq(s)
	return "'" .. string.gsub(str(s), "'", "'\\''") .. "'"
end

-- The default agent's row, or nil.
local function agent()
	if data == nil or type(data.agents) ~= "table" then
		return nil
	end
	for _, a in ipairs(data.agents) do
		if type(a) == "table" and a.default == true then
			return a
		end
	end
	return nil
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
	M.fetchLook(render)
end

local lastLookMs = 0

-- How Boxy looks and what it is doing now (`bxrig boxy --json`); renders only when the picture or the state changed. The tab works without it.
function M.fetchLook(render)
	bxrig.json({ "boxy", "--json" }, function(result, err)
		if err == nil and type(result) == "table" then
			local changed = look == nil or str(look.state) ~= str(result.state) or str(look.image) ~= str(result.image)
			look = result
			if changed then
				render()
			end
		end
	end, 30000)
end

-- Called once a second while the panel is open: follows Boxy's state (the hold-to-talk key changes it from outside) and turns the swirl.
function M.tick(render)
	local now = noctalia.nowMs()
	if now - lastLookMs >= 3000 then
		lastLookMs = now
		M.fetchLook(render)
	end
	if look ~= nil and type(look.frames) == "table" and #look.frames > 1 then
		render()
	end
end

-- The picture to draw: the one for the state, or the frame of the turning swirl for this moment.
local function picture()
	if look == nil then
		return ""
	end
	if type(look.frames) == "table" and #look.frames > 1 then
		return str(look.frames[(math.floor(noctalia.nowMs() / 700) % #look.frames) + 1])
	end
	return str(look.image)
end

-- Boxy's picture for what it is doing (the antenna swirl turns while it works), with a Talk button (hold-to-talk by key is Super+Comma): `bxrig boxy listen toggle`.
local function portrait(render)
	if look == nil or picture() == "" then
		return ui.spacer({})
	end
	local listening = str(look.state) == "listening"
	return ui.row({ align = "center", gap = 10 }, {
		ui.image({ key = "boxy-img", path = picture(), fit = "contain", height = 72, width = 72 }),
		ui.column({ flexGrow = 1, gap = 2 }, {
			ui.label({ text = str(look.name) .. " is " .. str(look.state), fontSize = 12, fontWeight = "semibold", maxLines = 1 }),
			ui.label({ text = "Hold Super+Comma to talk", fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
		}),
		ui.button({ key = "talk", glyph = listening and "player-stop" or "microphone", text = listening and "Send" or "Talk", variant = listening and "secondary" or "ghost", controlSize = "sm", tooltip = "Talk to Boxy (needs Voxtype)", onClick = function()
			bxrig.run({ "boxy", "listen", "toggle" }, function(ok, msg)
				if not ok then
					errorText = msg
				end
				M.fetch(render)
			end, 120000)
		end }),
	})
end

local function takeReply(result, err)
	if err ~= nil then
		reply = { text = err, thread = "", pending = {} }
		return
	end
	local text = str(result.answer)
	if text == "" and type(result.ran) == "table" and #result.ran > 0 then
		text = "Done: " .. table.concat(result.ran, ", ")
	end
	reply = { text = text, thread = str(result.thread), pending = type(result.pending) == "table" and result.pending or {} }
end

function M.ask(render)
	if busy ~= nil or question == "" then
		return
	end
	busy = "ask"
	reply = nil
	render()
	bxrig.json({ "ai", "agents", "ask", question, "--json" }, function(result, err)
		busy = nil
		takeReply(result, err)
		render()
	end, 600000)
end

local function decide(render, verb)
	if reply == nil or reply.thread == "" then
		return
	end
	busy = "decide"
	local thread = reply.thread
	render()
	bxrig.json({ "ai", "agents", verb, thread, "--json" }, function(result, err)
		busy = nil
		takeReply(result, err)
		if reply ~= nil and reply.thread == "" then
			reply.thread = thread
		end
		render()
	end, 900000)
end

local function header(a, render)
	local running = a.running == true
	return ui.row({ align = "center", gap = 8 }, {
		ui.glyph({ name = running and "circle-filled" or "circle", size = 12, color = running and "primary" or "on_surface_variant" }),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = str(a.name), fontSize = 14, fontWeight = "semibold", maxLines = 1 }),
			ui.label({ text = running and str(a.url) or "stopped", fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
		}),
		ui.button({ key = "svc", text = busy == "service" and "…" or (running and "Stop" or "Start"), glyph = running and "player-stop" or "player-play", variant = "ghost", controlSize = "sm", onClick = function()
			busy = "service"
			render()
			bxrig.run({ "ai", "agents", running and "stop" or "start", str(a.name) }, function(ok, msg)
				busy = nil
				if not ok then
					errorText = msg
				end
				M.fetch(render)
			end, 120000)
		end }),
	})
end

-- Past chats and logs are bx-agents' own: its chat in a terminal (`bxrig ai agents chat`), its web page (`bxrig ai agents open`) and
-- its log viewer (`bxrig ai agents NAME logs --ui`). BxRig keeps no copy of your conversations.
local function links(a)
	local running = a.running == true
	return ui.row({ align = "center", gap = 6 }, {
		ui.button({ key = "chat", text = "Chat", glyph = "message-chatbot", variant = "ghost", controlSize = "sm", tooltip = "Chat in a terminal, with your past chats (Super+Period)", onClick = function()
			noctalia.runInTerminal(shq(bxrig.command()) .. " ai agents chat")
			panel.close()
		end }),
		running and ui.button({ key = "web", text = "Web", glyph = "world", variant = "ghost", controlSize = "sm", tooltip = "bx-agents' web page: past chats, files, skills (Super+Shift+Period)", onClick = function()
			bxrig.run({ "ai", "agents", "open" }, function() end, 10000)
		end }) or ui.spacer({}),
		ui.button({ key = "logs", text = "Logs", glyph = "file-text", variant = "ghost", controlSize = "sm", tooltip = "bx-agents' log viewer", onClick = function()
			noctalia.runInTerminal(shq(bxrig.command()) .. " ai agents " .. shq(str(a.name)) .. " logs --ui")
			panel.close()
		end }),
	})
end

local function askBox(a, render)
	local children = {
		ui.row({ align = "center", gap = 6 }, {
			ui.input({ key = "ask", placeholder = "Ask " .. str(a.name), controlSize = "sm", flexGrow = 1, onChange = function(text)
				question = str(text)
			end, onSubmit = function()
				M.ask(render)
			end }),
			ui.button({ key = "ask-go", glyph = busy == "ask" and "loader" or "send", variant = "ghost", controlSize = "sm", tooltip = "Ask", onClick = function()
				M.ask(render)
			end }),
		}),
	}
	if reply ~= nil then
		if reply.text ~= "" then
			table.insert(children, ui.label({ text = reply.text, fontSize = 12, maxLines = 14 }))
		end
		for i, p in ipairs(reply.pending) do
			table.insert(children, ui.label({ key = "want-" .. i, text = str(a.name) .. " wants to: " .. str(p.tool), fontSize = 11, fontWeight = "semibold", color = "primary", maxLines = 2 }))
		end
		if #reply.pending > 0 then
			table.insert(children, ui.row({ align = "center", gap = 6 }, {
				ui.button({ key = "approve", text = busy == "decide" and "…" or "Approve", glyph = "check", variant = "secondary", controlSize = "sm", onClick = function()
					decide(render, "approve")
				end }),
				ui.button({ key = "reject", text = "Reject", glyph = "x", variant = "ghost", controlSize = "sm", onClick = function()
					decide(render, "reject")
				end }),
			}))
		end
	end
	return ui.column({ gap = 6 }, children)
end

function M.view(render)
	if data == nil then
		return ui.column({ paddingV = 16, align = "center", gap = 6 }, {
			ui.glyph({ name = errorText ~= nil and "alert-triangle" or "loader", size = 20, color = errorText ~= nil and "error" or "on_surface_variant" }),
			ui.label({ text = errorText or "Loading…", fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 4 }),
		})
	end
	local a = agent()
	if a == nil then
		return ui.column({ paddingV = 16, align = "center", gap = 8 }, {
			portrait(render),
			ui.glyph({ name = "message-chatbot", size = 24, color = "on_surface_variant" }),
			ui.label({ text = "Boxy, your desktop assistant, is not set up yet", fontSize = 12, textAlign = "center", maxLines = 3 }),
			ui.button({ key = "make", text = busy == "make" and "…" or "Make Boxy", glyph = "sparkles", variant = "secondary", controlSize = "sm", onClick = function()
				busy = "make"
				render()
				bxrig.run({ "ai", "agents", "setup", "--yes" }, function(ok, msg)
					busy = nil
					if not ok then
						errorText = msg
					end
					M.fetch(render)
				end, 900000)
			end }),
		})
	end
	local children = { header(a, render), portrait(render), links(a), ui.separator({}) }
	if a.running == true then
		table.insert(children, askBox(a, render))
	else
		table.insert(children, ui.label({ text = "Start " .. str(a.name) .. " to ask it something here.", fontSize = 11, color = "on_surface_variant", maxLines = 2 }))
	end
	local fresh = tonumber(a.unreviewed) or 0
	if fresh > 0 then
		table.insert(children, ui.separator({}))
		table.insert(children, ui.row({ align = "center", gap = 8 }, {
			ui.glyph({ name = "bulb", size = 14, color = "primary" }),
			ui.label({ text = str(fresh) .. (fresh == 1 and " new skill" or " new skills") .. " to review", fontSize = 11, flexGrow = 1 }),
			ui.button({ key = "review", text = "Review", variant = "ghost", controlSize = "sm", onClick = function()
				noctalia.runInTerminal(shq(bxrig.command()) .. " ai agents skills")
				panel.close()
			end }),
		}))
	end
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
