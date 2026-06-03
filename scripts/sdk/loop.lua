-- Heartbeat main loop, stall watchdog, startup steps, remote event drain.
return function(ctx)
	local function resolvePath(root, path: string)
		local cur = root
		for part in string.gmatch(path, "[^%.]+") do
			if not cur then
				return nil
			end
			cur = cur[part]
		end
		return cur
	end

	local function getConfigValue(key: string)
		local cfg = ctx.config
		if not cfg then
			return nil
		end
		if string.find(key, ".", 1, true) then
			return resolvePath(cfg, key)
		end
		return cfg[key]
	end

	function ctx.loop.runSteps(steps)
		for _, step in steps do
			local label, fn
			if type(step) == "table" then
				label = step.name or step[1]
				fn = step.run or step[2]
			else
				label = tostring(step)
				fn = nil
			end
			if type(fn) == "function" then
				ctx.runStep(label, fn)
			elseif type(fn) == "string" then
				local resolved = resolvePath(ctx, fn)
				if type(resolved) == "function" then
					ctx.runStep(label, resolved)
				end
			end
		end
	end

	function ctx.loop.drainRemote(remotePath: string, handler: (any) -> ())
		local remote = resolvePath(game, remotePath)
			or resolvePath(game:GetService("ReplicatedStorage"), remotePath:gsub("^ReplicatedStorage%.", ""))
		if remote and remote:IsA("RemoteEvent") then
			ctx.track(remote.OnClientEvent:Connect(handler))
		end
	end

	function ctx.loop.warnWrongPlace()
		local expected = ctx.placeId or (ctx.placeIds and ctx.placeIds[1])
		if not expected or game.PlaceId == expected then
			return
		end
		local ids = ctx.placeIds
		if ids then
			for _, id in ids do
				if game.PlaceId == id then
					return
				end
			end
		end
		local warnMsg = string.format("PlaceId %s != %s — behavior may differ", game.PlaceId, tostring(expected))
		ctx.log.warn(warnMsg)
		ctx.notify.push({ Title = "Wrong place?", Content = warnMsg, Duration = 6 })
	end

	function ctx.loop.startHeartbeat(opts)
		opts = opts or {}
		local RS = ctx.rs
		local masterKey = opts.masterKey or "Enabled"
		local delayKey = opts.delayKey or "LoopDelay"
		local accKey = opts.accumulatorKey or "loopAcc"
		if not ctx.timers[accKey] then
			ctx.timers[accKey] = 0
		end
		local tickFn = opts.tick
		if type(tickFn) == "string" then
			tickFn = resolvePath(ctx, tickFn)
		end
		if type(tickFn) ~= "function" then
			ctx.log.error("loop.startHeartbeat: tick must be a function")
			return
		end

		ctx.log.info("starting Heartbeat main loop")
		ctx.track(RS.Heartbeat:Connect(function(dt)
			if not ctx.isAlive() then
				return
			end
			if getConfigValue(masterKey) == false then
				return
			end
			ctx.timers[accKey] += dt
			local delay = getConfigValue(delayKey) or 0.4
			if ctx.timers[accKey] < delay then
				return
			end
			ctx.timers[accKey] = 0
			tickFn()
		end))
	end

	function ctx.loop.startWatchdog(opts)
		opts = opts or {}
		local interval = opts.interval or 4
		local masterKey = opts.masterKey or "Enabled"
		local stallSeconds = opts.stallSeconds or 5
		local lastCycleKey = opts.lastCycleKey or "lastCycleAt"
		local onTick = opts.onTick
		local onStall = opts.onStall
		local logLine = opts.logLine

		task.spawn(function()
			ctx.log.info("watchdog started")
			while ctx.isAlive() do
				task.wait(interval)
				if not ctx.isAlive() then
					break
				end
				if type(onTick) == "function" then
					onTick(ctx)
				end
				local lastCycle = ctx.timers[lastCycleKey] or 0
				if getConfigValue(masterKey) and lastCycle > 0 and os.clock() - lastCycle > stallSeconds then
					local stallMsg = string.format(
						"Stalled %.1fs in phase '%s'",
						os.clock() - lastCycle,
						ctx.log.phase
					)
					ctx.log.warn("main loop STALLED — " .. stallMsg)
					if ctx.log.verbose and type(onStall) == "function" then
						onStall(stallMsg)
					elseif ctx.log.verbose then
						ctx.notify.push({ Title = "Script stalled", Content = stallMsg, Duration = 4 })
					end
				end
				if type(logLine) == "function" then
					print(logLine(ctx))
				end
			end
			ctx.log.info("watchdog ended (session inactive)")
		end)
	end

	return ctx
end
