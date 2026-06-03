-- Session, logging, legacy cleanup, shared ctx shell.
local EXPECTED_PLACE = 15197136141
local LEGACY_GUI = "M3_FabrikFarm"
local HISTORY_GUI = "M3_FabrikFarmHistory"
local FARM_NOTIF_DURATION = 4.2

return function(DexUI)
	local plrs = game:GetService("Players")
	local http = game:GetService("HttpService")
	local G = (getgenv and getgenv()) or shared or _G

	local ctx = {
		DexUI = DexUI,
		G = G,
		placeId = EXPECTED_PLACE,
		upgradeIds = { "OreLimit", "OreValue", "DropperSpeed", "ConveyorSpeed", "WalkSpeed", "ShinyOresChance" },
		config = {
			Enabled = false,
			AutoCollect = false,
			AutoButtons = false,
			AutoGemUpgrades = false,
			AutoRebirth = false,
			AutoManualDropper = false,
			HideMonetization = false,
			VerboseLogging = false,
			SmartCollect = true,
			SmartBuyPriority = true,
			SmartGemValue = true,
			LoopDelay = 0.4,
			CollectMin = 50,
			RebirthInterval = 8,
		},
		stats = { collects = 0, buttons = 0, upgrades = 0, rebirths = 0, manualDrops = 0, lastMsg = "", errors = 0, cycles = 0 },
		timers = {
			lastRebirthAt = 0,
			lastManualDropAt = 0,
			lastAdCleanAt = 0,
			lastCycleAt = 0,
			lastProgressAt = 0,
			rebirthBusyUntil = 0,
			loopAcc = 0,
			incomeSampleAt = 0,
			incomeSampleTotal = 0,
		},
		game = { incomePerSec = 0, gameCashLabel = nil, gameCashHooked = false },
		caches = { rebirth = { bought = 0, needed = 0, canRebirth = false } },
		widgets = { status = nil, progress = nil, stats = nil },
		ui = nil,
		startupReady = false,
		injectId = http:GenerateGUID(false),
		session = nil,
		log = { verbose = false, phase = "boot", bootClock = os.clock() },
	}

	local function logLine(level, msg)
		return string.format(
			"[FabrikFarm][%s][%6.2fs][%s] %s",
			level,
			os.clock() - ctx.log.bootClock,
			ctx.log.phase,
			tostring(msg)
		)
	end

	function ctx.log.setPhase(phase)
		ctx.log.phase = phase
		ctx.G.__FabrikFarmPhase = phase
		if ctx.log.verbose then
			print(logLine("DEBUG", "→ phase"))
		end
	end

	function ctx.log.info(msg)
		print(logLine("INFO", msg))
	end
	function ctx.log.warn(msg)
		warn(logLine("WARN", msg))
	end
	function ctx.log.error(msg)
		warn(logLine("ERROR", msg))
	end
	function ctx.log.debug(msg)
		if ctx.log.verbose then
			print(logLine("DEBUG", msg))
		end
	end

	function ctx.runStep(label, fn)
		ctx.log.setPhase(label)
		local startT = os.clock()
		ctx.log.debug("step start")
		local ok, errOrResult = pcall(fn)
		if ok then
			ctx.log.debug(string.format("step done (%.3fs)", os.clock() - startT))
		else
			ctx.log.error(string.format("step FAILED after %.3fs: %s", os.clock() - startT, tostring(errOrResult)))
		end
		return ok, errOrResult
	end

	local function forEachGuiRoot(fn)
		fn(game:GetService("CoreGui"))
		local lp = plrs.LocalPlayer
		if lp then
			local pg = lp:FindFirstChild("PlayerGui")
			if pg then
				fn(pg)
			end
		end
		local ok, hui = pcall(function()
			return gethui()
		end)
		if ok and hui then
			fn(hui)
		end
	end

	function ctx.destroyNamedGui(name)
		forEachGuiRoot(function(root)
			local g = root:FindFirstChild(name)
			if g then
				g:Destroy()
			end
		end)
	end

	function ctx.cleanupLegacy()
		ctx.destroyNamedGui(LEGACY_GUI)
		ctx.destroyNamedGui(HISTORY_GUI)
	end

	local function stopSessionThreads(session)
		if not session then
			return
		end
		for _, th in session.threads or {} do
			pcall(task.cancel, th)
		end
		table.clear(session.threads)
		for _, conn in session.connections or {} do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(session.connections)
	end

	function ctx.getUi()
		return ctx.ui
	end

	function ctx.notify.push(opts)
		local ui = ctx.getUi()
		if ui and ui.Notify then
			ui:Notify(opts)
		end
	end

	function ctx.notify.action(text)
		if not text or text == "" then
			return
		end
		ctx.notify.push({ Content = text, Duration = FARM_NOTIF_DURATION })
	end

	function ctx.feedback.play(pattern)
		local ui = ctx.getUi()
		if ui and ui.PlayFeedback then
			ui:PlayFeedback(pattern)
		end
	end

	function ctx.track(conn)
		if conn and ctx.session then
			table.insert(ctx.session.connections, conn)
		end
		return conn
	end

	function ctx.isAlive()
		return ctx.session and ctx.session.alive and ctx.session.injectId == ctx.injectId
	end

	function ctx.shutdown(notifyUser)
		local session = ctx.session or ctx.G.__FabrikFarmSession
		local wasActive = session and session.alive
		local ui = ctx.getUi()
		if session then
			session.alive = false
			stopSessionThreads(session)
		end
		if notifyUser ~= false and wasActive then
			ctx.notify.push({ Title = "Fabrik Farm", Content = "Unloaded — farm stopped", Duration = 2.5 })
		end
		if ctx.ui then
			pcall(function()
				ctx.ui:Destroy()
			end)
			ctx.ui = nil
			ctx.G.__FabrikFarmUI = nil
		end
		ctx.cleanupLegacy()
		ctx.log.setPhase("unloaded")
		if notifyUser ~= false and wasActive then
			ctx.log.info("Unloaded — farm loops stopped, UI removed")
		end
	end

	-- Prior inject teardown
	ctx.log.setPhase("killPrevious")
	ctx.log.info("starting injection " .. ctx.injectId)
	if ctx.G.__FabrikFarmSession then
		ctx.log.info("found previous session — stopping it")
		ctx.G.__FabrikFarmSession.alive = false
		stopSessionThreads(ctx.G.__FabrikFarmSession)
	end
	if ctx.G.__FabrikFarmUI then
		pcall(function()
			ctx.G.__FabrikFarmUI:Destroy()
		end)
		ctx.G.__FabrikFarmUI = nil
	end
	ctx.cleanupLegacy()

	ctx.session = { alive = true, connections = {}, threads = {}, injectId = ctx.injectId }
	ctx.G.__FabrikFarmSession = ctx.session
	ctx.G.__FabrikFarmConfig = ctx.config
	ctx.G.__FabrikFarmStats = ctx.stats

	ctx.lp = plrs.LocalPlayer
	ctx.rs = game:GetService("RunService")
	ctx.FARM_NOTIF_DURATION = FARM_NOTIF_DURATION

	return ctx
end
