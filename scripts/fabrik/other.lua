-- Fabrik helper: ReplicatedStorage Scripts.Other (format_value, gem upgrade data).
return function(ctx)
	local RS = game:GetService("ReplicatedStorage")
	local ok, Other = pcall(require, RS.Scripts.Other)
	if ok and Other then
		ctx.other = Other
	else
		ctx.other = nil
	end

	if not ctx.other then
		return false
	end

	ctx.formatGameValue = ctx.other.format_value
	if type(ctx.formatGameValue) ~= "function" then
		ctx.log.warn("Other.format_value missing — using plain number formatting")
		ctx.formatGameValue = function(n)
			return tostring(math.floor((n or 0) + 0.5))
		end
	end

	ctx.getUpgradeData = ctx.other.GetDataBasedOnUpgrade
	if type(ctx.getUpgradeData) ~= "function" then
		ctx.log.warn("Other.GetDataBasedOnUpgrade missing — gem upgrades disabled")
		ctx.getUpgradeData = function()
			return {
				isMaxReached = true,
				nextUpgrade_Price = 0,
				nextUpgrade_ValueBoost = 0,
				currentUpgrade_ValueBoost = 0,
			}
		end
	end

	return true
end
