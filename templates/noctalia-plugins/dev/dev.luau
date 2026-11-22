--!nonstrict
-- BxRig Developer: the data side shared by the bar widget and the panel (each entry loads its own copy).
-- Reads the three lists the popover shows and counts what is running:
--   bxrig db list --json          data.databases[]  { container, status, state, image, engine, name, port }
--   bxrig containers list --json  data.containers[] { name, image, state, ports (numbers), ports_text, created, kind }
--   bxrig vm list --json          data.vms[]        { name, kind, what, state, ports { web, rdp? }, url, size_kb }
--   bxrig boxlang servers list --json  data.servers[] { name, kind (miniserver|commandbox), port, state, url, path, webroot }
--   bxrig tui ports --json        data.items[]      { port, process, pid, user, up, command, dev, system, conflict } (the system ones are left out)
-- A container made by `bxrig db` or `bxrig vm` has kind "database" or "vm" in the containers list; it is shown on its own tab, so the
-- Containers tab and the running count only take kind "container".

local bxrig = require("./bxrig.luau")

local M = {}

-- true when the error text says the container engine is not installed ("podman was not found ...")
function M.engineMissing(err)
	return type(err) == "string" and err:find("was not found", 1, true) ~= nil
end

local function isUp(state)
	return state == "running"
end

-- Number of running databases, plain containers and VMs.
function M.countRunning(result)
	local n = 0
	for _, d in ipairs(result.databases or {}) do
		if isUp(d.state) then
			n = n + 1
		end
	end
	for _, c in ipairs(result.containers or {}) do
		if isUp(c.state) then
			n = n + 1
		end
	end
	for _, v in ipairs(result.vms or {}) do
		if isUp(v.state) then
			n = n + 1
		end
	end
	for _, s in ipairs(result.servers or {}) do
		if isUp(s.state) then
			n = n + 1
		end
	end
	return n
end

-- "docker.io/library/postgres:17" -> "postgres:17"
function M.shortImage(image)
	local s = tostring(image or "")
	return s:match("([^/]+)$") or s
end

-- Keeps the ports a developer cares about: not the system's own (sshd, cups, systemd-resolved...).
local function userPorts(list)
	local out = {}
	for _, p in ipairs(list or {}) do
		if type(p) == "table" and p.system ~= true then
			table.insert(out, p)
		end
	end
	return out
end

-- Keeps the plain containers (the ones bxrig db and bxrig vm made have their own tabs).
local function plainContainers(list)
	local out = {}
	for _, c in ipairs(list or {}) do
		if type(c) == "table" and c.kind == "container" then
			table.insert(out, c)
		end
	end
	return out
end

-- callback(result): { databases, containers, vms, servers, ports (each a list, or nil when its command failed), errors = { the same keys },
-- engineMissing (bool), running (number) }. The five commands run at the same time.
function M.load(callback, timeoutMs)
	local result = { databases = nil, containers = nil, vms = nil, servers = nil, ports = nil, errors = {}, engineMissing = false, running = 0 }
	local pending = 5
	local function finished()
		pending = pending - 1
		if pending > 0 then
			return
		end
		result.running = M.countRunning(result)
		callback(result)
	end
	local function take(key, field, filter)
		return function(data, err)
			if err ~= nil then
				result.errors[key] = err
				if M.engineMissing(err) and (key == "databases" or key == "containers") then
					result.engineMissing = true
				end
			else
				local list = type(data[field]) == "table" and data[field] or {}
				result[key] = filter and filter(list) or list
			end
			finished()
		end
	end
	bxrig.json({ "db", "list", "--json" }, take("databases", "databases"), timeoutMs)
	bxrig.json({ "containers", "list", "--json" }, take("containers", "containers", plainContainers), timeoutMs)
	bxrig.json({ "vm", "list", "--json" }, take("vms", "vms"), timeoutMs)
	bxrig.json({ "boxlang", "servers", "list", "--json" }, take("servers", "servers"), timeoutMs)
	bxrig.json({ "tui", "ports", "--json" }, take("ports", "items", userPorts), timeoutMs)
end

return M
