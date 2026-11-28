--!nonstrict
-- The Local tab of the Agents panel: BxRig's local AI on llama.cpp.
--   the server (running or not, where its OpenAI API is) with Start or Stop: `bxrig ai serve start|stop`
--   the models on this machine, the active one marked, Use on the others: `bxrig ai models use ID`
--   Try it: a question to the active model, the answer below: `bxrig ai ask TEXT --json`
--   Downloads: the models downloading or queued, with their share (`bxrig ai downloads --json`)
--   AI page: the Control Center's AI page in a terminal (`bxrig tui ai`): picks, downloads, tune, remove
-- Data: `bxrig ai status --json`. Colors are palette roles only, so the tab follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local M = {}

local status = nil
local errorText = nil
local busy = nil -- what is running: "server", a model id, "ask"
local question = ""
local answer = nil -- { text, meta } or nil
local downloads = {} -- the active downloads

local str = kit.str

local function shq(s)
	return "'" .. string.gsub(str(s), "'", "'\\''") .. "'"
end

function M.fetch(render)
	bxrig.json({ "ai", "downloads", "--json" }, function(result, err)
		downloads = {}
		if err == nil and type(result.downloads) == "table" then
			for _, d in ipairs(result.downloads) do
				if type(d) == "table" and (d.status == "downloading" or d.status == "queued" or d.status == "checking") then
					table.insert(downloads, d)
				end
			end
		end
		render()
	end, 15000)
	bxrig.json({ "ai", "status", "--json" }, function(result, err)
		if err ~= nil then
			errorText = err
		else
			status = result
			errorText = nil
		end
		render()
	end, 30000)
end

local function serverRow(render)
	local s = status.server or {}
	local running = s.running == true
	return ui.row({ align = "center", gap = 8 }, {
		ui.glyph({ name = running and "circle-filled" or "circle", size = 12, color = running and "primary" or "on_surface_variant" }),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = running and "AI server running" or "AI server stopped", fontSize = 13, fontWeight = "semibold" }),
			ui.label({ text = running and str(s.base_url) or "OpenAI and Anthropic APIs on this machine", fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
		}),
		ui.button({
			key = "server",
			text = busy == "server" and "…" or (running and "Stop" or "Start"),
			glyph = running and "player-stop" or "player-play",
			variant = "ghost",
			controlSize = "sm",
			onClick = function()
				busy = "server"
				render()
				bxrig.run({ "ai", "serve", running and "stop" or "start" }, function(ok, msg)
					busy = nil
					if not ok then
						errorText = msg
					end
					M.fetch(render)
				end, 60000)
			end,
		}),
	})
end

local function modelRows(render)
	local rows = {}
	local models = type(status.models) == "table" and status.models or {}
	local loaded = type(status.loaded) == "table" and status.loaded or {}
	local ids = {}
	for id, _ in pairs(models) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local m = models[id]
		local chat = (m.kind or "chat") == "chat"
		local active = status.active == id
		local meas = type(m.measured) == "table" and m.measured or {}
		local info = chat and (meas.tps and (str(meas.tps) .. " tok/s") or "not tested") or "embeddings"
		if loaded[id] == "loaded" then
			info = info .. " · in memory"
		end
		local row = {
			ui.glyph({ name = chat and "message-chatbot" or "vector", size = 16, color = active and "primary" or "on_surface_variant" }),
			ui.column({ flexGrow = 1, gap = 1 }, {
				ui.label({ text = id, fontSize = 12, fontWeight = active and "bold" or "normal", maxLines = 1 }),
				ui.label({ text = info, fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
			}),
		}
		if active then
			table.insert(row, ui.label({ text = "ACTIVE", fontSize = 10, fontWeight = "bold", color = "primary" }))
		elseif chat then
			table.insert(row, ui.button({
				key = "use-" .. id,
				text = busy == id and "…" or "Use",
				variant = "ghost",
				controlSize = "sm",
				onClick = function()
					busy = id
					render()
					bxrig.run({ "ai", "models", "use", id }, function(ok, msg)
						busy = nil
						if not ok then
							errorText = msg
						end
						M.fetch(render)
					end, 30000)
				end,
			}))
		end
		table.insert(rows, ui.row({ key = "model-" .. id, align = "center", gap = 8 }, row))
	end
	if #rows == 0 then
		table.insert(rows, ui.label({ text = "No models yet. AI page or bxrig ai setup picks them for this machine.", fontSize = 11, color = "on_surface_variant", maxLines = 3 }))
	end
	return ui.column({ gap = 6 }, rows)
end

local function downloadRows()
	local rows = {}
	for i, d in ipairs(downloads) do
		local what = d.status == "downloading" and (str(d.percent) .. "%") or str(d.status)
		table.insert(rows, ui.row({ key = "dl-" .. i, align = "center", gap = 8 }, {
			ui.glyph({ name = "download", size = 14, color = "primary" }),
			ui.label({ text = str(d.label), fontSize = 11, flexGrow = 1, maxLines = 1 }),
			ui.label({ text = what, fontSize = 10, color = "on_surface_variant" }),
		}))
	end
	return ui.column({ gap = 4 }, rows)
end

local function askBox(render)
	local children = {
		ui.row({ align = "center", gap = 6 }, {
			ui.input({
				key = "ask",
				placeholder = "Try it: ask your local model",
				controlSize = "sm",
				flexGrow = 1,
				onChange = function(text)
					question = str(text)
				end,
				onSubmit = function()
					M.ask(render)
				end,
			}),
			ui.button({ key = "ask-go", glyph = busy == "ask" and "loader" or "send", variant = "ghost", controlSize = "sm", tooltip = "Ask", onClick = function()
				M.ask(render)
			end }),
		}),
	}
	if answer ~= nil then
		table.insert(children, ui.label({ text = answer.text, fontSize = 12, maxLines = 12 }))
		table.insert(children, ui.label({ text = answer.meta, fontSize = 10, color = "on_surface_variant", maxLines = 1 }))
	end
	return ui.column({ gap = 6 }, children)
end

function M.ask(render)
	if busy == "ask" or question == "" then
		return
	end
	busy = "ask"
	answer = nil
	render()
	bxrig.json({ "ai", "ask", question, "--json" }, function(result, err)
		busy = nil
		if err ~= nil then
			answer = { text = err, meta = "no answer" }
		else
			answer = { text = str(result.answer), meta = str(result.model) .. " · " .. str(result.reply_s) .. " s · " .. str(result.tps) .. " tok/s" }
		end
		render()
	end, 120000)
end

function M.view(render)
	if status == nil then
		return ui.column({ paddingV = 16, align = "center", gap = 6 }, {
			ui.glyph({ name = errorText ~= nil and "alert-triangle" or "loader", size = 20, color = errorText ~= nil and "error" or "on_surface_variant" }),
			ui.label({ text = errorText or "Loading…", fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 4 }),
		})
	end
	local hw = type(status.hardware) == "table" and status.hardware or {}
	local children = {
		ui.label({ text = str(hw.summary), fontSize = 10, color = "on_surface_variant", maxLines = 2 }),
		serverRow(render),
		ui.separator({}),
		modelRows(render),
		ui.separator({}),
		askBox(render),
	}
	if #downloads > 0 then
		table.insert(children, 4, downloadRows())
	end
	if errorText ~= nil then
		table.insert(children, ui.label({ text = errorText, fontSize = 10, color = "error", maxLines = 2 }))
	end
	return ui.scroll({ flexGrow = 1, gap = 10 }, children)
end

-- The footer button: the Control Center's AI page in a terminal.
function M.openPage()
	noctalia.runInTerminal(shq(bxrig.command()) .. " tui ai")
	panel.close()
end

return M
