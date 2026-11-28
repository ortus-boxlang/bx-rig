--!nonstrict
-- What the bar shield and the panel share: `bxrig vpn list --json` read into one table, and the words both show.
-- Each entry loads its own copy of this file (a module is cached per entry).

local bxrig = require("./bxrig.luau")
local kit = require("./kit.luau")

local M = {}

local str = kit.str

-- callback(result): { providers = { item... }, connected = { item... }, allowSeveral = bool, install = { choice... }, error = text or nil }.
-- item: { id, name, group ("profiles" | "apps"), kind, state, connected, location, detail, can_pick, coexist, verified, note }.
-- An empty providers list with no error means no VPN is installed (the bar shield hides itself).
function M.load(callback, timeoutMs)
	bxrig.json({ "vpn", "list", "--json" }, function(data, err)
		if err ~= nil then
			callback({ providers = {}, connected = {}, allowSeveral = false, install = {}, error = err })
			return
		end
		local providers = {}
		local connected = {}
		for _, item in ipairs(type(data.providers) == "table" and data.providers or {}) do
			if type(item) == "table" and str(item.id) ~= "" then
				table.insert(providers, item)
				if item.connected == true then
					table.insert(connected, item)
				end
			end
		end
		callback({
			providers = providers,
			connected = connected,
			allowSeveral = data.allow_several == true,
			install = type(data.install) == "table" and data.install or {},
			error = nil,
		})
	end, timeoutMs or 30000)
end

-- "Connected: Tailscale (exit node home), NordVPN (Berlin, Germany)" or "Not connected".
function M.summary(connected)
	if #connected == 0 then
		return "Not connected"
	end
	local names = {}
	for _, item in ipairs(connected) do
		local where = str(item.location)
		table.insert(names, str(item.name) .. (where ~= "" and (" (" .. where .. ")") or ""))
	end
	return "Connected: " .. table.concat(names, ", ")
end

-- The second line of a row.
function M.subtitle(item)
	local state = str(item.state)
	local text
	if item.connected == true then
		text = "Connected"
		if str(item.location) ~= "" then
			text = text .. " · " .. str(item.location)
		end
	elseif state == "connecting" then
		text = "Connecting…"
	elseif state == "login" then
		text = "Log in first"
		if str(item.detail) ~= "" then
			text = text .. " (" .. str(item.detail) .. ")"
		end
	elseif state == "unavailable" then
		text = "Not running"
	elseif state == "unknown" then
		text = "State unknown"
	else
		text = "Off"
	end
	if str(item.group) == "profiles" and str(item.kind) ~= "" then
		text = text .. " · " .. str(item.kind)
	elseif str(item.group) == "apps" and str(item.verified) ~= "yes" then
		text = text .. " · partly verified"
	end
	return text
end

-- Items of one group, in the order bxrig listed them.
function M.group(providers, name)
	local out = {}
	for _, item in ipairs(providers) do
		if str(item.group) == name then
			table.insert(out, item)
		end
	end
	return out
end

return M
