--!nonstrict
-- BxRig System panel: four tabs, Updates, Backups, Network and BoxLang.
--
-- Updates (`bxrig system updates --json`, every 60 s while open): the number waiting and the repo / AUR split, a banner when a restart is
--   needed (a pending kernel, systemd or glibc update, or a kernel that was already replaced), a filter (All, Repo, AUR), the package list
--   (name, old -> new, repo or aur) and "Update all". That button opens a terminal that runs `bxrig system update --yes`, so the snapshot
--   that comes first and the progress are on screen. Without `checkupdates` (pacman-contrib) the tab says so and offers to install it.
-- Backups (`bxrig backup status --json`, every 60 s while open): a row per kind (config snapshots, system snapshots, files) with its last run,
--   next run, size and health; a play button on a row and "Back up now" (all rows that can) run the rows' own commands in a terminal;
--   "Open Time Machine" runs `bxrig timemachine` there.
-- Network: the Wi-Fi you are on (`bxrig wifi status --json`) with Share Wi-Fi (`bxrig wifi qr --out FILE`, shown here as an image), the last
--   speed, disk and DNS results (`bxrig system speedtest last --json`) with a Test button each (`system speedtest network|disk --json`,
--   `dns bench --json`), the DNS providers as a pick-one list (`bxrig dns --json` for the one in use; picking runs `bxrig dns NAME --yes`)
--   and "Open in Control Center" (`bxrig tui network` in a terminal). A running test shows a spinner label; it cannot be cancelled here.
-- BoxLang (`bxrig boxlang check --json`, every 10 minutes while open, since it asks ForgeBox): the BoxLang you run and the latest release
--   with "Update BoxLang" (`bxrig boxlang update --yes` in a terminal), the modules with the ForgeBox version of each outdated one and
--   "Update modules" (`bxrig boxlang modules update`), "Open home folder" (`bxrig boxlang home --open`) and the Modules page in the Control Center.
-- The Updates count and the restart flag are published with noctalia.state for the bar widget.
-- Colors are palette roles only, so the panel follows the active theme.

local bxrig = require("./bxrig.luau")

local REFRESH_MS = 60000
local UPDATES_TIMEOUT_MS = 240000
local BACKUPS_TIMEOUT_MS = 60000
local LIST_CAP = 300

local tab = "updates"
local filter = "all"
local closeButton = true

local upd = nil -- data of `system updates --json`
local updErr = nil
local updLoading = false
local updFetchedMs = -REFRESH_MS

local bk = nil -- data of `backup status --json`
local bkErr = nil
local bkLoading = false
local bkFetchedMs = -REFRESH_MS

local net = { wifi = nil, last = nil, dnsCurrent = "", busy = {}, err = nil, qr = nil, qrStamp = 0 }
local netFetchedMs = -REFRESH_MS
local DNS_ORDER = { { id = "cloudflare", name = "Cloudflare" }, { id = "quad9", name = "Quad9" }, { id = "google", name = "Google" }, { id = "dhcp", name = "Your router" } }

local bl = nil -- data of `boxlang check --json`
local blErr = nil
local blLoading = false
local BL_REFRESH_MS = 600000
local blFetchedMs = -BL_REFRESH_MS

local TYPE_GLYPH = { config = "adjustments", system = "device-desktop", data = "folders" }

local function str(v)
	if v == nil then
		return ""
	end
	return tostring(v)
end

local function num(v)
	return tonumber(v) or 0
end

local function list(v)
	if type(v) == "table" then
		return v
	end
	return {}
end

local render

-- ---- terminal launch ----

-- One word of a shell command line, single quoted.
local function shq(s)
	return "'" .. (string.gsub(s, "'", "'\\''")) .. "'"
end

-- The shell text that runs `bxrig <args>`; the executable comes from the plugin setting and may be a path, so it is quoted too.
local function bx(args)
	local words = { shq(bxrig.command()) }
	for _, a in ipairs(args) do
		table.insert(words, shq(a))
	end
	return table.concat(words, " ")
end

-- Runs shell lines one after the other in a terminal and waits for Enter, so the output can be read.
local function inTerminal(lines)
	local script = table.concat(lines, "; ") .. "; echo; printf 'Done. Press Enter to close. '; read -r _"
	noctalia.runInTerminal(script)
end

-- ---- data ----

local function fetchUpdates()
	if updLoading then
		return
	end
	updLoading = true
	updFetchedMs = noctalia.nowMs()
	bxrig.json({ "system", "updates", "--json" }, function(data, err)
		updLoading = false
		if err ~= nil then
			updErr = err
		else
			upd = data
			updErr = nil
			noctalia.state.set("updates", num(data.total))
			noctalia.state.set("reboot", data.needs_reboot == true)
		end
		render()
	end, UPDATES_TIMEOUT_MS)
end

local function fetchBackups()
	if bkLoading then
		return
	end
	bkLoading = true
	bkFetchedMs = noctalia.nowMs()
	bxrig.json({ "backup", "status", "--json" }, function(data, err)
		bkLoading = false
		if err ~= nil then
			bkErr = err
		else
			bk = data
			bkErr = nil
		end
		render()
	end, BACKUPS_TIMEOUT_MS)
end

local function fetchNetwork()
	netFetchedMs = noctalia.nowMs()
	bxrig.json({ "wifi", "status", "--json" }, function(data, err)
		net.wifi = err == nil and data or nil
		render()
	end, 20000)
	bxrig.json({ "system", "speedtest", "last", "--json" }, function(data, err)
		if err == nil then
			net.last = data
		end
		render()
	end, 15000)
	bxrig.json({ "dns", "--json" }, function(data, err)
		if err == nil then
			net.dnsCurrent = str(data.provider)
		end
		render()
	end, 20000)
end

local function fetchBoxlang()
	if blLoading then
		return
	end
	blLoading = true
	blFetchedMs = noctalia.nowMs()
	-- `boxlang check` exits 10 (ok false) when something is behind, and its data is still the answer, so it is read here and not with bxrig.json
	local started = noctalia.runAsync({ bxrig.command(), "boxlang", "check", "--json" }, function(res)
		blLoading = false
		local decoded = noctalia.json.decode(res.stdout or "")
		if res.timedOut then
			blErr = "bxrig timed out"
		elseif type(decoded) == "table" and type(decoded.data) == "table" and decoded.data.boxlang ~= nil then
			bl = decoded.data
			blErr = nil
		else
			blErr = (type(decoded) == "table" and type(decoded.data) == "table" and decoded.data.error) or "could not check BoxLang"
		end
		render()
	end, 360000)
	if not started then
		blLoading = false
		blErr = "could not start " .. bxrig.command()
	end
	render()
end

local function fetchCurrent()
	if tab == "updates" then
		fetchUpdates()
	elseif tab == "backups" then
		fetchBackups()
	elseif tab == "boxlang" then
		fetchBoxlang()
	else
		fetchNetwork()
	end
end

local function fetchedFor(name)
	if name == "updates" then
		return updFetchedMs
	elseif name == "backups" then
		return bkFetchedMs
	elseif name == "boxlang" then
		-- the BoxLang check asks ForgeBox, so it is refreshed every 10 minutes, not every minute
		return blFetchedMs + BL_REFRESH_MS - REFRESH_MS
	end
	return netFetchedMs
end

local function selectTab(name)
	if tab == name then
		return
	end
	tab = name
	if noctalia.nowMs() - fetchedFor(name) >= REFRESH_MS then
		fetchCurrent()
	end
	render()
end

-- ---- drawing helpers ----

local function notice(glyph, color, title, sub, key)
	local texts = { ui.label({ text = title, fontSize = 13, fontWeight = "semibold", maxLines = 1 }) }
	if sub ~= nil and sub ~= "" then
		table.insert(texts, ui.label({ text = sub, fontSize = 11, color = "on_surface_variant", maxLines = 4 }))
	end
	return ui.row({ key = key, align = "center", gap = 10, paddingH = 12, paddingV = 10, radius = 12, fill = color .. "/0.14" }, {
		ui.glyph({ name = glyph, size = 20, color = color }),
		ui.column({ flexGrow = 1, gap = 2 }, texts),
	})
end

local function centered(glyph, color, text, key)
	return ui.column({ key = key, paddingV = 16, align = "center", gap = 6 }, {
		ui.glyph({ name = glyph, size = 20, color = color }),
		ui.label({ text = text, fontSize = 12, color = "on_surface_variant", textAlign = "center", maxLines = 5 }),
	})
end

local function chipButton(key, text, on, onClick)
	return ui.button({
		key = key,
		text = text,
		variant = on and "primary" or "outline",
		selected = on,
		controlSize = "sm",
		flexGrow = 1,
		onClick = onClick,
	})
end

-- ---- the Updates tab ----

local function packageRow(p, index)
	local isAur = str(p.repo) == "aur"
	return ui.column({ key = "pkg-" .. index .. "-" .. str(p.name), gap = 1, paddingH = 10, paddingV = 6, radius = 8, fill = "surface_container" }, {
		ui.row({ align = "center", gap = 6 }, {
			ui.label({ text = str(p.name), fontSize = 12, fontWeight = "semibold", maxLines = 1, flexGrow = 1 }),
			ui.label({ text = isAur and "AUR" or "repo", fontSize = 10, fontWeight = "bold", color = isAur and "tertiary" or "on_surface_variant" }),
		}),
		ui.label({ text = str(p.old) .. " -> " .. str(p.new), fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
	})
end

local function rebootBanner()
	if upd.needs_reboot ~= true then
		return nil
	end
	local stale = upd.reboot_stale == true
	local reasons = {}
	for _, r in ipairs(list(upd.reboot_reasons)) do
		table.insert(reasons, str(r))
	end
	local sub = table.concat(reasons, "; ")
	if stale and sub == "" then
		sub = "The running kernel was replaced by an update."
	end
	return notice("refresh-alert", "tertiary", stale and "Restart needed" or "Restart after updating", sub, "reboot")
end

local function updatesBody(items)
	if upd == nil then
		if updErr ~= nil then
			table.insert(items, centered("alert-triangle", "error", updErr, "upd-error"))
			if string.find(updErr, "pacman-contrib", 1, true) ~= nil then
				table.insert(items, ui.button({
					text = "Install pacman-contrib",
					glyph = "package",
					variant = "outline",
					onClick = function()
						inTerminal({ "sudo pacman -S pacman-contrib" })
						panel.close()
					end,
				}))
			end
		else
			table.insert(items, centered("loader", "on_surface_variant", "Checking for updates... this can take a few seconds", "upd-loading"))
		end
		return
	end

	local total = num(upd.total)
	local repoCount = num(upd.repo_count)
	local aurCount = num(upd.aur_count)

	-- summary
	local sub = total == 0 and "Nothing is waiting." or (repoCount .. " repo - " .. aurCount .. " AUR")
	local last = str(upd.last_update_ago) ~= "" and ("Last upgrade " .. str(upd.last_update_ago)) or "No upgrade found in the pacman log"
	table.insert(items, ui.row({ key = "summary", align = "center", gap = 10 }, {
		ui.glyph({ name = total == 0 and "circle-check" or "package", size = 28, color = total == 0 and "primary" or "secondary" }),
		ui.column({ flexGrow = 1, gap = 1 }, {
			ui.label({ text = total == 0 and "Up to date" or (total == 1 and "1 update" or (total .. " updates")), fontSize = 16, fontWeight = "bold" }),
			ui.label({ text = sub .. "  ·  " .. last, fontSize = 11, color = "on_surface_variant", maxLines = 2 }),
		}),
	}))

	local banner = rebootBanner()
	if banner ~= nil then
		table.insert(items, banner)
	end
	if str(upd.aur_error) ~= "" then
		table.insert(items, notice("alert-triangle", "error", "The AUR check failed", str(upd.aur_error), "aur-error"))
	end
	if updErr ~= nil then
		table.insert(items, ui.label({ key = "stale-error", text = "Could not refresh: " .. updErr, fontSize = 10, color = "error", maxLines = 2 }))
	end

	if total == 0 then
		return
	end

	-- filter and list
	table.insert(items, ui.row({ key = "filter", gap = 4 }, {
		chipButton("f-all", "All " .. total, filter == "all", function()
			filter = "all"
			render()
		end),
		chipButton("f-repo", "Repo " .. repoCount, filter == "repo", function()
			filter = "repo"
			render()
		end),
		chipButton("f-aur", "AUR " .. aurCount, filter == "aur", function()
			filter = "aur"
			render()
		end),
	}))
	local rows = {}
	local shown = 0
	local hidden = 0
	for i, p in ipairs(list(upd.packages)) do
		if type(p) == "table" and (filter == "all" or str(p.repo) == filter) then
			if shown < LIST_CAP then
				shown = shown + 1
				table.insert(rows, packageRow(p, i))
			else
				hidden = hidden + 1
			end
		end
	end
	if hidden > 0 then
		table.insert(rows, ui.label({ key = "more", text = "and " .. hidden .. " more", fontSize = 11, color = "on_surface_variant" }))
	end
	if #rows == 0 then
		table.insert(rows, ui.label({ key = "none", text = "Nothing in this list.", fontSize = 11, color = "on_surface_variant" }))
	end
	table.insert(items, ui.scroll({ key = "packages", flexGrow = 1, gap = 4 }, rows))
end

local function updatesFooter(items)
	if upd == nil then
		return
	end
	local total = num(upd.total)
	if total == 0 then
		return
	end
	local snapshot = str(upd.snapshot_tool)
	local note = snapshot ~= "" and ("A " .. snapshot .. " snapshot is taken first, then pacman, then the AUR. A terminal shows the progress.")
		or "No snapshot tool found (snapper or timeshift): the update runs without one. A terminal shows the progress."
	table.insert(items, ui.button({
		key = "update-all",
		text = "Update all",
		glyph = "circle-arrow-up",
		variant = "primary",
		onClick = function()
			inTerminal({ bx({ "system", "update", "--yes" }) })
			panel.close()
		end,
	}))
	table.insert(items, ui.label({ key = "update-note", text = note, fontSize = 10, color = "on_surface_variant", maxLines = 3 }))
end

-- ---- the Backups tab ----

local HEALTH = {
	ok = { glyph = "circle-check", color = "primary" },
	warn = { glyph = "alert-triangle", color = "error" },
	none = { glyph = "circle-dashed", color = "on_surface_variant" },
}

local function backupRow(r, index)
	local kind = str(r.kind)
	local health = HEALTH[str(r.health)] or HEALTH.none
	local action = list(r.action)
	local when = str(r.last_ago) ~= "" and str(r.last_ago) or "never"
	local detail = "Last " .. when .. "  ·  next " .. str(r.next)
	if str(r.size_text) ~= "" then
		detail = detail .. "  ·  " .. str(r.size_text)
	end
	local texts = {
		ui.label({ text = str(r.label), fontSize = 13, fontWeight = "semibold", maxLines = 1 }),
		ui.label({ text = detail, fontSize = 11, color = "on_surface_variant", maxLines = 2 }),
	}
	if str(r.note) ~= "" then
		table.insert(texts, ui.label({ text = str(r.note), fontSize = 10, color = str(r.health) == "warn" and "error" or "on_surface_variant", maxLines = 3 }))
	end
	return ui.row({ key = "bk-" .. index .. "-" .. str(r.id), align = "center", gap = 10, paddingH = 12, paddingV = 10, radius = 12, fill = "surface_container" }, {
		ui.glyph({ name = TYPE_GLYPH[kind] or "folders", size = 20, color = "secondary" }),
		ui.column({ flexGrow = 1, gap = 2 }, texts),
		ui.glyph({ name = health.glyph, size = 18, color = health.color }),
		ui.button({
			glyph = "player-play",
			variant = "ghost",
			controlSize = "sm",
			enabled = #action > 0,
			tooltip = #action > 0 and "Back up now" or "Not set up yet",
			onClick = function()
				inTerminal({ bx(action) })
			end,
		}),
	})
end

local function backupsBody(items)
	if bk == nil then
		if bkErr ~= nil then
			table.insert(items, centered("alert-triangle", "error", bkErr, "bk-error"))
		else
			table.insert(items, centered("loader", "on_surface_variant", "Reading your backups...", "bk-loading"))
		end
		return
	end
	local rows = {}
	for i, r in ipairs(list(bk.rows)) do
		if type(r) == "table" then
			table.insert(rows, backupRow(r, i))
		end
	end
	if #rows == 0 then
		table.insert(items, centered("folders", "on_surface_variant", "No backup information", "bk-empty"))
	else
		table.insert(items, ui.column({ key = "bk-rows", gap = 8 }, rows))
	end
	if bkErr ~= nil then
		table.insert(items, ui.label({ key = "bk-stale", text = "Could not refresh: " .. bkErr, fontSize = 10, color = "error", maxLines = 2 }))
	end
end

local function backupsFooter(items)
	local lines = {}
	if bk ~= nil then
		for _, r in ipairs(list(bk.rows)) do
			local action = type(r) == "table" and list(r.action) or {}
			if #action > 0 then
				table.insert(lines, bx(action))
			end
		end
	end
	table.insert(items, ui.row({ key = "bk-actions", gap = 6 }, {
		ui.button({
			text = "Back up now",
			glyph = "device-floppy",
			variant = "primary",
			flexGrow = 1,
			enabled = #lines > 0,
			onClick = function()
				inTerminal(lines)
			end,
		}),
		ui.button({
			text = "Open Time Machine",
			glyph = "history",
			variant = "outline",
			flexGrow = 1,
			onClick = function()
				inTerminal({ bx({ "timemachine" }) })
				panel.close()
			end,
		}),
	}))
end

-- ---- network ----

-- "12:38" from an ISO time ("2026-11-21T12:38:04").
local function hhmm(at)
	local t = str(at)
	if #t >= 16 then
		return t:sub(12, 16)
	end
	return t
end

-- Runs one test (kind: network, disk or dns) in the background, then reads the last results again.
local function runTest(kind)
	if net.busy[kind] then
		return
	end
	net.busy[kind] = true
	net.err = nil
	local args = kind == "dns" and { "dns", "bench", "--json" } or { "system", "speedtest", kind, "--json" }
	bxrig.json(args, function(_data, err)
		net.busy[kind] = false
		if err ~= nil then
			net.err = err
		end
		fetchNetwork()
	end, kind == "network" and 180000 or 300000)
	render()
end

local function useDns(id)
	net.busy.switch = true
	bxrig.run({ "dns", id, "--yes" }, function(ok, msg)
		net.busy.switch = false
		if not ok then
			net.err = msg
		end
		fetchNetwork()
	end, 60000)
	render()
end

-- Share Wi-Fi: bxrig writes the QR code of the network you are on to a file in the cache, and the panel shows it.
local function shareWifi()
	if net.qr ~= nil then
		net.qr = nil
		render()
		return
	end
	local path = noctalia.expandPath("~/.cache/bxrig/wifi-qr.png")
	net.busy.qr = true
	bxrig.run({ "wifi", "qr", "--out=" .. path }, function(ok, msg)
		net.busy.qr = false
		if ok then
			net.qr = path
			net.qrStamp = noctalia.nowMs()
		else
			net.err = msg
		end
		render()
	end, 30000)
	render()
end

local function card(key, children)
	return ui.column({ key = key, gap = 8, paddingH = 12, paddingV = 10, radius = 12, fill = "on_surface/0.05" }, children)
end

local function cardHeader(title, sub, kind)
	local busy = net.busy[kind] == true
	return ui.row({ align = "center", gap = 8 }, {
		ui.label({ text = title, fontSize = 13, fontWeight = "semibold" }),
		ui.label({ text = busy and "Testing…" or sub, fontSize = 11, color = busy and "primary" or "on_surface_variant", flexGrow = 1, maxLines = 1 }),
		ui.button({ text = "Test", glyph = busy and "loader" or "player-play", variant = "outline", controlSize = "sm", enabled = not busy,
			onClick = function()
				runTest(kind)
			end }),
	})
end

local function bigNumber(label, value, unit, color)
	return ui.column({ flexGrow = 1, gap = 1, paddingH = 10, paddingV = 8, radius = 10, fill = "surface_container" }, {
		ui.label({ text = label, fontSize = 10, color = "on_surface_variant" }),
		ui.label({ text = value ~= "" and value or "–", fontSize = 18, fontWeight = "bold", color = color }),
		ui.label({ text = unit, fontSize = 10, color = "on_surface_variant" }),
	})
end

-- "412.67 Mbit/s" -> "412.67", "Mbit/s"
local function splitUnit(v)
	local n, u = string.match(str(v), "^(%S+)%s+(.+)$")
	if n == nil then
		return str(v), ""
	end
	return n, u
end

local function networkBody(items)
	local w = net.wifi
	local ssid = w ~= nil and str(w.ssid) or ""
	table.insert(items, card("wifi", {
		ui.row({ align = "center", gap = 10 }, {
			ui.glyph({ name = ssid ~= "" and "wifi" or "wifi-off", size = 22, color = "secondary" }),
			ui.column({ flexGrow = 1, gap = 1 }, {
				ui.label({ text = ssid ~= "" and ssid or "Not on Wi-Fi", fontSize = 13, fontWeight = "semibold", maxLines = 1 }),
				ui.label({ text = (w ~= nil and num(w.signal) >= 0) and ("Signal " .. num(w.signal) .. "%") or "", fontSize = 11, color = "on_surface_variant" }),
			}),
			ui.button({ text = net.qr ~= nil and "Hide" or "Share Wi-Fi", glyph = "qrcode", variant = "primary", controlSize = "sm",
				enabled = ssid ~= "" and net.busy.qr ~= true, onClick = shareWifi }),
		}),
	}))
	if net.qr ~= nil then
		table.insert(items, ui.column({ key = "qr", align = "center", gap = 6, paddingV = 8 }, {
			ui.image({ key = "qr-" .. net.qrStamp, path = net.qr, fit = "contain", radius = 10, height = 240 }),
			ui.label({ text = "Point a phone camera at the code to join " .. ssid, fontSize = 11, color = "on_surface_variant" }),
		}))
	end

	local last = net.last or {}
	local sp = last.network or {}
	local d1, u1 = splitUnit(sp.download)
	local d2, u2 = splitUnit(sp.upload)
	local d3, u3 = splitUnit(sp.ping)
	table.insert(items, card("speed", {
		cardHeader("Speed", sp.at and ("last run " .. hhmm(sp.at)) or "not tested yet", "network"),
		ui.row({ gap = 6 }, {
			bigNumber("Download", d1, u1 ~= "" and u1 or "Mbit/s", "primary"),
			bigNumber("Upload", d2, u2 ~= "" and u2 or "Mbit/s", "secondary"),
			bigNumber("Ping", d3, u3 ~= "" and u3 or "ms", "tertiary"),
		}),
	}))

	local dk = last.disk or {}
	table.insert(items, card("disk", {
		cardHeader("Disk", dk.at and ("last run " .. hhmm(dk.at)) or "not tested yet", "disk"),
		ui.row({ gap = 6 }, {
			bigNumber("Write", splitUnit(dk.write), select(2, splitUnit(dk.write)), "primary"),
			bigNumber("Read", splitUnit(dk.read), select(2, splitUnit(dk.read)), "primary"),
		}),
	}))

	local bench = last.dns or {}
	local times = {}
	local worst = 1
	for _, p in ipairs(list(bench.providers)) do
		times[str(p.id)] = { ms = tonumber(p.ms) or -1, fastest = p.fastest == true }
		if (tonumber(p.ms) or 0) > worst then
			worst = tonumber(p.ms)
		end
	end
	local rows = { cardHeader("DNS", bench.at and ("lookup time, tested " .. hhmm(bench.at)) or "pick one; Test times them", "dns") }
	for _, p in ipairs(DNS_ORDER) do
		local t = times[p.id]
		local using = net.dnsCurrent == p.id
		local timeText = ""
		if t ~= nil then
			timeText = t.ms >= 0 and (string.format("%d", math.floor(t.ms + 0.5)) .. " ms") or "no answer"
		end
		-- the radio: a small button, so picking a row switches to it (the one in use is not clickable)
		local rowChildren = {
			ui.button({ glyph = using and "circle-dot" or "circle", variant = "ghost", controlSize = "sm", selected = using,
				enabled = not using and net.busy.switch ~= true, tooltip = using and "In use" or ("Use " .. p.name),
				onClick = function()
					useDns(p.id)
				end }),
			ui.label({ text = p.name, fontSize = 12, fontWeight = using and "semibold" or nil, width = 96, maxLines = 1 }),
		}
		if t ~= nil and t.ms >= 0 then
			table.insert(rowChildren, ui.progress({ progress = math.min(1, t.ms / worst), flexGrow = 1, height = 6, radius = 3, fill = t.fastest and "primary" or "secondary", track = "on_surface/0.12" }))
		else
			table.insert(rowChildren, ui.spacer({ flexGrow = 1 }))
		end
		table.insert(rowChildren, ui.label({ text = timeText, fontSize = 11, color = (t ~= nil and t.fastest) and "primary" or "on_surface_variant", width = 64, textAlign = "end", maxLines = 1 }))
		if t ~= nil and t.fastest then
			table.insert(rowChildren, ui.label({ text = "Fastest", fontSize = 10, fontWeight = "bold", color = "primary" }))
		end
		table.insert(rows, ui.row({ key = "dns-" .. p.id, align = "center", gap = 8, paddingH = 4, radius = 8, fill = using and "primary/0.10" or nil }, rowChildren))
	end
	table.insert(items, card("dns", rows))

	if net.err ~= nil then
		table.insert(items, ui.label({ key = "net-err", text = net.err, fontSize = 11, color = "error", maxLines = 3 }))
	end
	table.insert(items, ui.button({ key = "open-cc", text = "Open in Control Center", glyph = "terminal-2", variant = "ghost",
		onClick = function()
			noctalia.runInTerminal(shq(bxrig.command()) .. " tui network")
			panel.close()
		end }))
end

-- ---- the BoxLang tab ----

local function boxlangBody(items)
	if bl == nil then
		if blErr ~= nil then
			table.insert(items, notice("alert-triangle", "error", "Could not check BoxLang", blErr, "bl-err"))
		else
			table.insert(items, centered("loader", "primary", "Checking BoxLang and its modules (asks ForgeBox)…", "bl-loading"))
		end
		return
	end
	local b = bl.boxlang or {}
	local installed = str(b.installed)
	local latest = str(b.latest)
	local verRows = {
		ui.row({ align = "center", gap = 8 }, {
			ui.glyph({ name = "brand-java", size = 20, color = "primary" }),
			ui.label({ text = installed ~= "" and ("BoxLang " .. installed) or "BoxLang is not installed", fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
			ui.label({ text = b.update == true and ("→ " .. latest) or (latest ~= "" and "latest" or ""), fontSize = 12, fontWeight = "semibold", color = b.update == true and "tertiary" or "primary" }),
		}),
	}
	if b.update == true or installed == "" then
		table.insert(verRows, ui.button({ key = "bl-update", text = installed == "" and "Install BoxLang" or ("Update to " .. latest), glyph = "download", variant = "primary", controlSize = "sm",
			onClick = function()
				inTerminal({ bx({ "boxlang", "update", "--yes" }) })
				panel.close()
			end }))
	end
	table.insert(items, card("bl-version", verRows))

	local mods = list(bl.modules)
	local behind = num(bl.outdated)
	local modRows = {
		ui.row({ align = "center", gap = 8 }, {
			ui.label({ text = "Modules", fontSize = 13, fontWeight = "semibold" }),
			ui.label({ text = behind > 0 and (behind .. " outdated") or (#mods .. " up to date"), fontSize = 11, color = behind > 0 and "tertiary" or "on_surface_variant", flexGrow = 1 }),
		}),
	}
	local shown = 0
	for _, m in ipairs(mods) do
		if shown >= 12 then
			break
		end
		shown = shown + 1
		local old = m.outdated == true
		table.insert(modRows, ui.row({ key = "mod-" .. str(m.name), align = "center", gap = 8, paddingH = 4 }, {
			ui.glyph({ name = old and "circle-arrow-up" or "circle-check", size = 14, color = old and "tertiary" or "primary" }),
			ui.label({ text = (m.nested == true and "↳ " or "") .. str(m.name), fontSize = 12, flexGrow = 1, maxLines = 1, color = m.nested == true and "on_surface_variant" or nil }),
			ui.label({ text = str(m.current) .. (old and (" → " .. str(m.latest)) or ""), fontSize = 11, color = old and "tertiary" or "on_surface_variant", maxLines = 1 }),
		}))
	end
	if #mods == 0 then
		table.insert(modRows, ui.label({ text = "No modules installed. bx-ai, bx-orm and more are on ForgeBox.", fontSize = 11, color = "on_surface_variant" }))
	end
	if behind > 0 then
		table.insert(modRows, ui.button({ key = "bl-mod-update", text = "Update modules", glyph = "refresh", variant = "outline", controlSize = "sm",
			onClick = function()
				inTerminal({ bx({ "boxlang", "modules", "update" }) })
				panel.close()
			end }))
	end
	table.insert(items, card("bl-modules", modRows))

	table.insert(items, ui.row({ gap = 6 }, {
		ui.button({ key = "bl-home", text = "Open home folder", glyph = "folder", variant = "ghost", flexGrow = 1,
			onClick = function()
				bxrig.run({ "boxlang", "home", "--open" }, function() end, 10000)
				panel.close()
			end }),
		ui.button({ key = "bl-cc", text = "Modules page", glyph = "terminal-2", variant = "ghost", flexGrow = 1,
			onClick = function()
				noctalia.runInTerminal(shq(bxrig.command()) .. " tui modules")
				panel.close()
			end }),
	}))
end

-- ---- the panel ----

render = function()
	local badge = nil
	if bk ~= nil and num(bk.warn_count) > 0 then
		badge = "alert-triangle"
	end
	local header = {
		ui.glyph({ name = "device-desktop-cog", size = 24, color = "secondary" }),
		ui.label({ text = "System", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
		ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Check again", onClick = "onRefresh" }),
	}
	if closeButton then
		table.insert(header, ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }))
	end

	local updatesLabel = "Updates"
	if upd ~= nil and num(upd.total) > 0 then
		updatesLabel = "Updates " .. num(upd.total)
	end
	local sections = {
		ui.row({ align = "center", gap = 10 }, header),
		ui.row({ gap = 4 }, {
			ui.button({
				key = "tab-updates",
				text = updatesLabel,
				glyph = "package",
				variant = tab == "updates" and "primary" or "outline",
				selected = tab == "updates",
				controlSize = "sm",
				flexGrow = 1,
				onClick = function()
					selectTab("updates")
				end,
			}),
			ui.button({
				key = "tab-backups",
				text = "Backups",
				glyph = badge or "device-floppy",
				variant = tab == "backups" and "primary" or "outline",
				selected = tab == "backups",
				controlSize = "sm",
				flexGrow = 1,
				onClick = function()
					selectTab("backups")
				end,
			}),
			ui.button({
				key = "tab-boxlang",
				text = (bl ~= nil and (bl.boxlang or {}).update == true or num((bl or {}).outdated) > 0) and "BoxLang •" or "BoxLang",
				glyph = "brand-java",
				variant = tab == "boxlang" and "primary" or "outline",
				selected = tab == "boxlang",
				controlSize = "sm",
				flexGrow = 1,
				onClick = function()
					selectTab("boxlang")
				end,
			}),
			ui.button({
				key = "tab-network",
				text = "Network",
				glyph = "wifi",
				variant = tab == "network" and "primary" or "outline",
				selected = tab == "network",
				controlSize = "sm",
				flexGrow = 1,
				onClick = function()
					selectTab("network")
				end,
			}),
		}),
		ui.separator({}),
	}
	if tab == "updates" then
		updatesBody(sections)
		updatesFooter(sections)
	elseif tab == "backups" then
		backupsBody(sections)
		backupsFooter(sections)
	elseif tab == "boxlang" then
		boxlangBody(sections)
	else
		networkBody(sections)
	end
	panel.render(ui.column({ flexGrow = 1, gap = 10, padding = 12 }, sections))
end

function onRefresh()
	fetchCurrent()
end

function onCloseClicked()
	panel.close()
end

function onOpen(context)
	closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
	-- `noctalia msg panel-toggle bxrig/system:panel network` opens straight on a tab
	if type(context) == "string" and (context == "updates" or context == "backups" or context == "network" or context == "boxlang") then
		tab = context
	end
	panel.setWantsSecondTicks(true)
	render()
	fetchCurrent()
end

function onClose()
	panel.setWantsSecondTicks(false)
end

function update()
	if noctalia.nowMs() - fetchedFor(tab) >= REFRESH_MS then
		fetchCurrent()
	end
end
