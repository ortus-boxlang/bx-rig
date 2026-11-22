--!nonstrict
-- BxRig System bar widget: a bare Tabler glyph (palette role secondary, no plate) with the number of waiting updates beside it.
-- The number is hidden when there are none, or when the count is not known yet or could not be read.
--
-- Data: `bxrig system updates --json` (data.total, data.needs_reboot), read at load and every 10 minutes in the background. The panel
-- refreshes the same data every 60 s while it is open and publishes it with noctalia.state, which this widget watches, so the badge
-- follows the panel without a second command.
-- A red dot follows the glyph while a scheduled task is failing (`bxrig scheduler --json`, data.failing, read with the updates; the
-- panel's Tasks tab publishes taskFailures with noctalia.state too).
-- Click opens the panel, right click checks again now.

local bxrig = require("./bxrig.luau")

local REFRESH_MS = 600000

local count = nil -- number of waiting updates, nil when unknown
local reboot = false
local failure = nil
local loading = false
local taskFailures = 0

local function draw()
	local kids = { ui.glyph({ name = "device-desktop-cog", color = reboot and "tertiary" or "secondary" }) }
	if taskFailures > 0 then
		table.insert(kids, ui.box({ width = 7, height = 7, radius = 4, fill = "error" }))
	end
	if count ~= nil and count > 0 then
		local text = count > 99 and "99+" or tostring(count)
		table.insert(kids, ui.label({ text = text, fontWeight = "bold", color = "primary" }))
	end
	local container = barWidget.isVertical() and ui.column or ui.row
	barWidget.render(container({ gap = 4, align = "center" }, kids))

	local tip = "System"
	if count ~= nil then
		tip = count == 0 and "System: up to date" or (count == 1 and "System: 1 update" or "System: " .. count .. " updates")
		if reboot then
			tip = tip .. " - restart needed"
		end
	elseif failure ~= nil then
		tip = "System: updates unknown (" .. failure .. ")"
	end
	if taskFailures > 0 then
		tip = tip .. " - " .. (taskFailures == 1 and "1 scheduled task is failing" or (taskFailures .. " scheduled tasks are failing"))
	end
	barWidget.setTooltip(tip)
end

local function fetch()
	if loading then
		return
	end
	loading = true
	bxrig.json({ "system", "updates", "--json" }, function(data, err)
		loading = false
		if err ~= nil then
			failure = err
			count = nil
		else
			failure = nil
			count = tonumber(data.total) or 0
			reboot = data.needs_reboot == true
			noctalia.state.set("updates", count)
			noctalia.state.set("reboot", reboot)
		end
		draw()
	end, 240000)
	bxrig.json({ "scheduler", "--json" }, function(data, err)
		if err == nil then
			taskFailures = tonumber(data.failing) or 0
			noctalia.state.set("taskFailures", taskFailures)
			draw()
		end
	end, 30000)
end

-- the panel publishes its fresher numbers
noctalia.state.watch("updates", function(value)
	if type(value) == "number" then
		count = value
		failure = nil
		draw()
	end
end)
noctalia.state.watch("taskFailures", function(value)
	if type(value) == "number" then
		taskFailures = value
		draw()
	end
end)
noctalia.state.watch("reboot", function(value)
	reboot = value == true
	draw()
end)

function update()
	fetch()
end

function onClick()
	noctalia.togglePanel("bxrig/system:panel")
end

function onRightClick()
	fetch()
end

noctalia.setUpdateInterval(REFRESH_MS)
draw()
fetch()
