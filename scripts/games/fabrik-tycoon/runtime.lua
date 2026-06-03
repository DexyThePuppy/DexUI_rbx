-- Startup loops and hooks (after init / farm / ads / ui).
return function(ctx)
	local Config = ctx.config
	local stats = ctx.stats

	ctx.loop.runSteps({
		{ name = "initSyncConfig", run = function()
			ctx.log.verbose = Config.VerboseLogging
		end },
		{ name = "initRebirthProgress", run = function()
			ctx.progress.update(true)
		end },
		{ name = "initStatus", run = ctx.status.update },
		{ name = "hookGameCash", run = ctx.game.hookCashHud },
	})

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
		local RS = ctx.rs
		local serverErr = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("ServerError")
		if serverErr and serverErr:IsA("RemoteEvent") then
			ctx.track(serverErr.OnClientEvent:Connect(function(msg)
				if ctx.log.verbose then
					ctx.log.debug("ServerError: " .. tostring(msg))
				end
			end))
		end
	end)

	ctx.loop.warnWrongPlace()

	if not ctx.findPath then
		ctx.log.warn("Rebirth findPath unavailable — auto rebirth progress may be wrong")
	end

	ctx.log.setPhase("ready")
	ctx.log.info("Loaded (DexUI) — all toggles default OFF | " .. ctx.status.line())

	ctx.loop.startHeartbeat({
		masterKey = "Enabled",
		delayKey = "LoopDelay",
		tick = ctx.farm.safeOnce,
	})

	ctx.loop.startWatchdog({
		masterKey = "Enabled",
		onTick = function()
			ctx.log.verbose = Config.VerboseLogging
			ctx.status.update()
		end,
		logLine = function()
			return string.format(
				"[%s] %s | btn:%d drop:%d gem:%d col:%d reb:%d err:%d | %.2fs | phase:%s | %s",
				ctx.logTag,
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
			)
		end,
	})
end
