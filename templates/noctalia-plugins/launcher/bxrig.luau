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

return M
