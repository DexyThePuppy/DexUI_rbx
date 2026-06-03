return function(ctx)
	local LP = ctx.lp
	local RS = game:GetService("ReplicatedStorage")

	ctx.runStep("waitEvents", function()
		ctx.events = RS:WaitForChild("Events", 15)
	end)
	if not ctx.events then
		ctx.log.error("Events folder missing — wrong game? aborting")
		ctx.shutdown(false)
		return
	end

	if not ctx.other then
		ctx.log.error("Fabrik API helper did not load Scripts.Other — aborting")
		ctx.shutdown(false)
		return
	end

	ctx.runStep("resolveRemotes", function()
		ctx.remotes = {
			collectMoney = ctx.events:WaitForChild("CollectMoney"),
			buyUpgrade = ctx.events:WaitForChild("BuyUpgrade"),
			requestRebirth = ctx.events:WaitForChild("RequestRebirth"),
		}
	end)

	ctx.runStep("requireFindPath", function()
		local ok, mod = pcall(function()
			return require(
				LP:WaitForChild("PlayerGui")
					:WaitForChild("MainUI")
					:WaitForChild("MainClient")
					:WaitForChild("Rebirth")
					:WaitForChild("findPath")
			)
		end)
		if ok then
			ctx.findPath = mod
		else
			ctx.log.warn("findPath require failed: " .. tostring(mod))
		end
	end)

	ctx.cleanupLegacy()
end
