-- Fabrik-Tycoon: remotes, findPath, then shared Fabrik helpers.
return function(ctx)
	local LP = ctx.lp
	local RS = game:GetService("ReplicatedStorage")

	local FABRIK_PREFIXES = { "scripts/fabrik/", "DexUI/scripts/fabrik/" }

	local function loadHelper(name: string)
		for _, prefix in FABRIK_PREFIXES do
			local path = prefix .. name .. ".lua"
			if isfile(path) then
				local chunk, err = loadstring(readfile(path), "@" .. path)
				if not chunk then
					error("[fabrik] compile " .. path .. ": " .. tostring(err), 0)
				end
				return chunk()
			end
		end
		error("[fabrik] missing helper: " .. name, 0)
	end

	ctx.runStep("waitEvents", function()
		ctx.events = RS:WaitForChild("Events", 15)
	end)
	if not ctx.events then
		ctx.log.error("Events folder missing — wrong game? aborting")
		ctx.shutdown(false)
		return
	end

	ctx.runStep("requireOther", function()
		if not loadHelper("other")(ctx) then
			ctx.log.error("require(Scripts.Other) failed — aborting")
			ctx.shutdown(false)
		end
	end)
	if not ctx.isAlive() then
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

	loadHelper("format")(ctx)
	loadHelper("tycoon")(ctx)
	ctx.cleanupLegacy()
end
