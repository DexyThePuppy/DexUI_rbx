-- Resolve remotes / game APIs. Return early via ctx.shutdown(false) on failure.
return function(ctx)
	ctx.runStep("waitPlayer", function()
		ctx.lp = ctx.lp or game:GetService("Players").LocalPlayer
	end)

	-- Example: require game modules, wait for folders, etc.
	-- ctx.runStep("waitEvents", function()
	--   ctx.events = game:GetService("ReplicatedStorage"):WaitForChild("Events", 15)
	-- end)
	-- if not ctx.events then
	--   ctx.log.error("Events missing")
	--   ctx.shutdown(false)
	--   return
	-- end

	ctx.log.info("game module ready")
end
