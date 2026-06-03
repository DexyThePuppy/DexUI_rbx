-- Session lifecycle: ctx shell, logging, DexUI notify/feedback, inject teardown.
return function(manifest, DexUI)
	local plrs = game:GetService("Players")
	local http = game:GetService("HttpService")
	local G = (getgenv and getgenv()) or shared or _G

	local function copyTable(t)
		if not t then
			return {}
		end
		local out = {}
		for k, v in t do
			out[k] = v
		end
		return out
	end

	local logTag = manifest.logTag or manifest.id or "DexUIScript"
	local notifDuration = manifest.notifDuration or 4
	local genv = manifest.genv or {}
	local legacyGuis = manifest.legacyGuis or {}
	local shutdownCopy = manifest.shutdown or {}

	local ctx = {
		manifest = manifest,
		DexUI = DexUI,
		G = G,
		genv = genv,
		id = manifest.id,
		name = manifest.name or manifest.id,
		logTag = logTag,
		placeId = manifest.placeId,
		placeIds = manifest.placeIds,
		config = copyTable(manifest.config),
		stats = copyTable(manifest.stats),
		timers = copyTable(manifest.timers),
		caches = copyTable(manifest.caches),
		widgets = copyTable(manifest.widgets),
		game = copyTable(manifest.game),
		ui = nil,
		startupReady = false,
		injectId = http:GenerateGUID(false),
		session = nil,
		log = { verbose = false, phase = "boot", bootClock = os.clock() },
		notifDuration = notifDuration,
		notify = {},
		feedback = {},
		loop = {},
		dexui = {},
		fmt = {},
	}

	-- Optional extra fields (game-specific handles on ctx root).
	if manifest.ctxExtend then
		for key, value in manifest.ctxExtend do
			ctx[key] = value
		end
	end

	local function logLine(level, msg)
		return string.format(
			"[%s][%s][%6.2fs][%s] %s",
			logTag,
			level,
			os.clock() - ctx.log.bootClock,
			ctx.log.phase,
			tostring(msg)
		)
	end

	function ctx.log.setPhase(phase)
		ctx.log.phase = phase
		if genv.phase then
			G[genv.phase] = phase
		end
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
		for _, guiName in legacyGuis do
			ctx.destroyNamedGui(guiName)
		end
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
		ctx.notify.push({ Content = text, Duration = notifDuration })
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
		local sessionKey = genv.session
		local session = ctx.session or (sessionKey and G[sessionKey])
		local wasActive = session and session.alive
		if session then
			session.alive = false
			stopSessionThreads(session)
		end
		if notifyUser ~= false and wasActive then
			ctx.notify.push({
				Title = shutdownCopy.title or ctx.name,
				Content = shutdownCopy.message or "Unloaded",
				Duration = shutdownCopy.duration or 2.5,
			})
		end
		if ctx.ui then
			pcall(function()
				ctx.ui:Destroy()
			end)
			ctx.ui = nil
			if genv.ui then
				G[genv.ui] = nil
			end
		end
		ctx.cleanupLegacy()
		ctx.log.setPhase("unloaded")
		if notifyUser ~= false and wasActive then
			ctx.log.info(shutdownCopy.logMessage or "Unloaded — session stopped, UI removed")
		end
	end

	function ctx.clearGenv()
		if genv.session then
			G[genv.session] = nil
		end
		if genv.ui then
			G[genv.ui] = nil
		end
		if genv.config then
			G[genv.config] = nil
		end
		if genv.stats then
			G[genv.stats] = nil
		end
		if genv.injectId then
			G[genv.injectId] = nil
		end
	end

	-- Prior inject teardown
	ctx.log.setPhase("killPrevious")
	ctx.log.info("starting injection " .. ctx.injectId)
	if genv.session and G[genv.session] then
		ctx.log.info("found previous session — stopping it")
		G[genv.session].alive = false
		stopSessionThreads(G[genv.session])
	end
	if genv.ui and G[genv.ui] then
		pcall(function()
			G[genv.ui]:Destroy()
		end)
		G[genv.ui] = nil
	end
	ctx.cleanupLegacy()

	ctx.session = { alive = true, connections = {}, threads = {}, injectId = ctx.injectId }
	if genv.session then
		G[genv.session] = ctx.session
	end
	if genv.config then
		G[genv.config] = ctx.config
	end
	if genv.stats then
		G[genv.stats] = ctx.stats
	end
	if genv.injectId then
		G[genv.injectId] = ctx.injectId
	end

	ctx.lp = plrs.LocalPlayer
	ctx.rs = game:GetService("RunService")

	return ctx
end
