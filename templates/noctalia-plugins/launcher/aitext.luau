--!nonstrict
-- BxRig AI on the selection: the text you selected (or copied) on the left, six actions on the right (summarize, rewrite, fix spelling and
-- grammar, explain, translate, draft a reply), and the result below them with a Copy button. The model is the local one (`bxrig ai`); nothing
-- leaves the machine.
--
-- Keys: Up/Down choose an action, Left/Right change the language of Translate, Enter runs it, F2 copies the result, F4 switches the text
-- between the selection and the clipboard, Esc closes. Mouse: click an action to run it; the Copy and source buttons work by click.
-- Data: `bxrig ai text source [--from=clipboard] --json` on open (text, from, chars, truncated, actions); an action runs
-- `bxrig ai text ID --text=TEXT [--lang=L] --to=stdout --json` (result). One run at a time; the result stays until you run another.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local LANGUAGES = { "English", "Spanish", "French", "German", "Portuguese", "Italian", "Japanese", "Chinese" }

local GLYPHS = {
	summarize = "list",
	rewrite = "pencil",
	fix = "check",
	explain = "bulb",
	translate = "language",
	reply = "mail-forward",
}

-- The same list `ai text source` returns; shown at once, replaced by the backend's.
local actions = {
	{ id = "summarize", label = "Summarize" },
	{ id = "rewrite", label = "Rewrite clearly" },
	{ id = "fix", label = "Fix spelling and grammar" },
	{ id = "explain", label = "Explain" },
	{ id = "translate", label = "Translate" },
	{ id = "reply", label = "Draft a reply" },
}
local text = ""
local from = ""
local chars = 0
local truncated = false
local sourceKind = "" -- "" the selection first, "clipboard" only the clipboard
local selected = 1
local langIndex = 1
local running = nil -- the action id being run
local resultText = ""
local resultFor = ""
local resultMeta = ""
local errorText = nil
local loading = false
local submitOnce = kit.once(300)

local str = kit.str

local function current()
	return actions[selected]
end

local function sourceName()
	if from == "selection" then
		return "Selection"
	elseif from == "clipboard" then
		return "Clipboard"
	end
	return "No text"
end

local function actionRow(i, a)
	local isSel = i == selected
	local label = str(a.label)
	if str(a.id) == "translate" then
		label = label .. "  ·  " .. LANGUAGES[langIndex]
	end
	return ui.row({
		key = "act-" .. str(a.id),
		align = "center",
		gap = 10,
		paddingH = 12,
		paddingV = 9,
		radius = 10,
		-- An explicit transparent fill: a nil fill keeps the retained one.
		fill = isSel and "primary/0.14" or "on_surface/0",
		onClick = function()
			selected = i
			onSubmit()
		end,
	}, {
		ui.glyph({ name = GLYPHS[str(a.id)] or "sparkles", size = 18, color = isSel and "primary" or "on_surface_variant" }),
		ui.label({
			text = label,
			fontSize = 14,
			fontWeight = isSel and "semibold" or "normal",
			color = isSel and "on_surface" or "on_surface_variant",
			flexGrow = 1,
			maxLines = 1,
		}),
		ui.label({
			text = running == str(a.id) and "working…" or (isSel and "↵" or ""),
			fontSize = 11,
			color = "on_surface_variant",
		}),
	})
end

function render()
	-- Left: the text the action will work on.
	local sourceBody = {}
	if loading then
		table.insert(sourceBody, ui.label({ text = "Reading the selection…", fontSize = 13, color = "on_surface_variant" }))
	elseif text == "" then
		table.insert(sourceBody, ui.label({ text = "No text.", fontSize = 14, fontWeight = "semibold" }))
		table.insert(sourceBody, ui.label({
			text = "Select some text in any app and press Super+Alt+E again, or copy it and switch the source to the clipboard (F4).",
			fontSize = 12,
			color = "on_surface_variant",
			maxLines = 6,
		}))
	else
		table.insert(sourceBody, ui.label({ text = text, fontSize = 13, maxLines = 40 }))
		if truncated then
			table.insert(sourceBody, ui.label({ text = "Only the first 24000 of " .. tostring(chars) .. " characters are used", fontSize = 11, color = "on_surface_variant" }))
		end
	end
	local left = ui.column({ width = 340, gap = 4 }, {
		ui.row({ align = "center", gap = 8, paddingH = 14, paddingV = 6 }, {
			ui.glyph({ name = from == "clipboard" and "clipboard" or "cursor-text", size = 16, color = "on_surface_variant" }),
			ui.label({ text = sourceName(), fontSize = 13, fontWeight = "semibold", flexGrow = 1 }),
			ui.label({ text = chars > 0 and (tostring(chars) .. " chars") or "", fontSize = 11, color = "on_surface_variant" }),
		}),
		ui.scroll({ height = 380, gap = 6, padding = 14 }, sourceBody),
	})

	-- Right: the actions, then the result.
	local list = {}
	for i, a in ipairs(actions) do
		table.insert(list, actionRow(i, a))
	end
	local resultBody = {}
	if errorText ~= nil then
		table.insert(resultBody, ui.label({ text = errorText, fontSize = 12, color = "error", maxLines = 8 }))
	elseif running ~= nil then
		table.insert(resultBody, ui.label({ text = "The local model is working on it…", fontSize = 13, color = "on_surface_variant" }))
	elseif resultText ~= "" then
		table.insert(resultBody, ui.label({ text = resultText, fontSize = 13, maxLines = 30 }))
	else
		table.insert(resultBody, ui.label({ text = "The result shows here.", fontSize = 13, color = "on_surface_variant" }))
	end
	local right = ui.column({ flexGrow = 1, gap = 6 }, {
		ui.column({ gap = 2, padding = 6 }, list),
		ui.separator({}),
		ui.row({ align = "center", gap = 8, paddingH = 14, paddingV = 2 }, {
			ui.label({ text = resultFor ~= "" and ("Result: " .. resultFor) or "Result", fontSize = 12, fontWeight = "semibold", flexGrow = 1 }),
			ui.label({ text = resultMeta, fontSize = 11, color = "on_surface_variant" }),
		}),
		ui.scroll({ height = 170, gap = 6, padding = 14 }, resultBody),
	})

	local footer = kit.footer({
		hint = "Local model, nothing leaves this machine",
		buttons = {
			ui.button({
				text = sourceKind == "clipboard" and "Source: Clipboard  F4" or "Source: Selection  F4",
				glyph = "switch-horizontal",
				variant = "ghost",
				controlSize = "sm",
				onClick = "onToggleSource",
			}),
			ui.button({ text = "Copy result  F2", variant = "primary", controlSize = "sm", enabled = resultText ~= "" and running == nil, onClick = "onCopy" }),
		},
	})

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 6 }, {
		ui.row({ gap = 0, align = "start" }, { left, ui.separator({ orientation = "vertical" }), right }),
		footer,
	}))
end

local function fetch()
	loading = true
	local args = { "ai", "text", "source", "--json" }
	if sourceKind == "clipboard" then
		table.insert(args, "--from=clipboard")
	end
	bxrig.json(args, function(result, err)
		loading = false
		if err ~= nil then
			errorText = err
			text = ""
			from = ""
			chars = 0
		else
			errorText = nil
			text = str(result.text)
			from = str(result.from)
			chars = tonumber(result.chars) or 0
			truncated = result.truncated == true
			if type(result.actions) == "table" and #result.actions > 0 then
				actions = result.actions
			end
		end
		render()
	end, 10000)
end

local function move(delta)
	if #actions == 0 then
		return
	end
	selected = kit.clamp(selected, delta, #actions)
	render()
end

local function changeLanguage(delta)
	local a = current()
	if a == nil or str(a.id) ~= "translate" then
		return
	end
	langIndex = ((langIndex - 1 + delta) % #LANGUAGES) + 1
	render()
end

function onSubmit()
	-- Enter can reach us both through a click and onKey("Return").
	if not submitOnce() then
		return
	end
	local a = current()
	if a == nil or running ~= nil then
		return
	end
	if text == "" then
		errorText = "No text to work on. Select some text first."
		render()
		return
	end
	local id = str(a.id)
	local args = { "ai", "text", id, "--text=" .. text, "--to=stdout", "--json" }
	if id == "translate" then
		table.insert(args, "--lang=" .. LANGUAGES[langIndex])
	end
	running = id
	errorText = nil
	render()
	bxrig.json(args, function(result, err)
		running = nil
		if err ~= nil then
			errorText = err
		else
			resultText = str(result.result)
			resultFor = str(a.label)
			resultMeta = str(result.model) .. " · " .. str(result.reply_s) .. " s"
		end
		render()
	end, 180000)
end

function onCopy()
	if resultText == "" then
		return
	end
	noctalia.copyToClipboard(resultText, "text/plain")
	noctalia.notify("AI on the selection", "Copied the result")
	panel.close()
end

function onToggleSource()
	sourceKind = sourceKind == "clipboard" and "" or "clipboard"
	resultText = ""
	resultFor = ""
	resultMeta = ""
	fetch()
	render()
end

function onKey(chord, pressed)
	if not pressed then
		return
	end
	if chord == "Up" then
		move(-1)
	elseif chord == "Down" then
		move(1)
	elseif chord == "Left" then
		changeLanguage(-1)
	elseif chord == "Right" then
		changeLanguage(1)
	elseif chord == "Return" or chord == "KP_Enter" then
		onSubmit()
	elseif chord == "F2" then
		onCopy()
	elseif chord == "F4" then
		onToggleSource()
	end
end

function onOpen(context)
	sourceKind = context == "clipboard" and "clipboard" or ""
	selected = 1
	resultText = ""
	resultFor = ""
	resultMeta = ""
	errorText = nil
	running = nil
	text = ""
	from = ""
	chars = 0
	render()
	fetch()
end
