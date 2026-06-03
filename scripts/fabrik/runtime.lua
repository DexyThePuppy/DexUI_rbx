-- Heartbeat loop, watchdog, ServerError drain, startup hooks.
return function(ctx)
	local Config = ctx.config
	local stats = ctx.stats
	local LP = ctx.lp
	local RS = ctx.rs
	local track = ctx.track
	local farmNotify = ctx.notify.push
	local findPath = ctx.findPath

	ctx.runStep("initSyncConfig", function()
		ctx.log.verbose = Config.VerboseLogging
	end)
	ctx.runStep("initRebirthProgress", function()
		ctx.progress.update(true)
	end)

	ctx.runStep("initStatus", ctx.status.update)
	ctx.runStep("hookGameCash", ctx.game.hookCashHud)
	task.spawn(function()
		for _ = 1, 20 do
			if ctx.game.gameCashHooked then
				break
			end
			ctx.game.hookCashHud()
			task.wait(1)
		end
	end)

	ctx.startupReady = true
	ctx.log.info("startup complete — ad hiding gated behind toggle")

	ctx.runStep("startAdCleaner", ctx.ads.start)

	ctx.runStep("consumeServerError", function()
		local serverErr = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("ServerError")
		if serverErr and serverErr:IsA("RemoteEvent") then
			track(serverErr.OnClientEvent:Connect(function(msg)
				if ctx.log.verbose then
					ctx.log.debug("ServerError: " .. tostring(msg))
				end
			end))
		end
	end)

	if game.PlaceId ~= ctx.placeId then
		local warnMsg = string.format("PlaceId %s != %s — remotes may differ", game.PlaceId, ctx.placeId)
		ctx.log.warn(warnMsg)
		farmNotify({ Title = "Wrong place?", Content = warnMsg, Duration = 6 })
	end

	if not findPath then
		ctx.log.warn("Rebirth findPath unavailable — auto rebirth progress may be wrong")
	end

	ctx.log.setPhase("ready")
	ctx.log.info("Loaded (DexUI) — all toggles default OFF | " .. ctx.status.line())

	ctx.log.info("starting Heartbeat farm loop")
	track(RS.Heartbeat:Connect(function(dt)
		if not ctx.isAlive() then
			return
		end
		ctx.timers.loopAcc += dt
		if ctx.timers.loopAcc < Config.LoopDelay then
			return
		end
		ctx.timers.loopAcc = 0
		ctx.farm.safeOnce()
	end))

	task.spawn(function()
		ctx.log.info("watchdog started")
		while ctx.isAlive() do
			task.wait(4)
			if not ctx.isAlive() then
				break
			end
			ctx.log.verbose = Config.VerboseLogging
			ctx.status.update()
			if Config.Enabled and ctx.timers.lastCycleAt > 0 and os.clock() - ctx.timers.lastCycleAt > 5 then
				local stallMsg = string.format(
					"Stalled %.1fs in phase '%s'",
					os.clock() - ctx.timers.lastCycleAt,
					ctx.log.phase
				)
				ctx.log.warn("farm loop STALLED — " .. stallMsg)
				if ctx.log.verbose then
					farmNotify({ Title = "Farm stalled", Content = stallMsg, Duration = 4 })
				end
			end
			print(string.format(
				"[FabrikFarm] %s | btn:%d drop:%d gem:%d col:%d reb:%d err:%d | %.2fs | phase:%s | %s",
				ctx.status.line(),
				stats.buttons,
				stats.manualDrops,
				stats.upgrades,
				stats.collects,
				stats.rebirths,
				stats.errors,
				Config.LoopDelay,
				ctx.log.phase,
				stats.lastMsg ~= "" and stats.lastMsg or "—"
			))
		end
		ctx.log.info("watchdog ended (session inactive)")
	end)
end
