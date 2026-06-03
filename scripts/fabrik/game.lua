-- Remotes, player/tycoon accessors, HUD cash mirror.
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

	ctx.runStep("requireOther", function()
		local ok, Other = pcall(require, RS.Scripts.Other)
		if ok and Other then
			ctx.other = Other
		end
	end)
	if not ctx.other then
		ctx.log.error("require(Scripts.Other) failed — aborting")
		ctx.shutdown(false)
		return
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

	function ctx.fmt.money(n)
		n = math.floor((n or 0) + 0.5)
		return "$" .. ctx.formatGameValue(n)
	end

	function ctx.fmt.incomeRate(n)
		n = math.floor((n or 0) + 0.5)
		if n <= 0 then
			return "($0/s)"
		end
		return "(" .. ctx.fmt.money(n) .. "/s)"
	end

	function ctx.game.getClientValues()
		local pg = LP:FindFirstChild("PlayerGui")
		local nr = pg and pg:FindFirstChild("NoResetScripts")
		return nr and nr:FindFirstChild("ClientValues")
	end

	function ctx.game.getTycoon()
		local ref = LP:FindFirstChild("TycoonOwned")
		return ref and ref.Value
	end

	function ctx.game.getMoney()
		local ls = LP:FindFirstChild("leaderstats")
		local m = ls and ls:FindFirstChild("Money")
		return m and m.Value or 0
	end

	function ctx.game.getDataFolderToCollect()
		local df = LP:FindFirstChild("DataFolder")
		local tc = df and df:FindFirstChild("ToCollect")
		return tc and tc.Value or 0
	end

	function ctx.game.getClientToCollect()
		local cv = ctx.game.getClientValues()
		local tc = cv and cv:FindFirstChild("ToCollect")
		return tc and tc.Value or 0
	end

	function ctx.game.getToCollect()
		return math.max(ctx.game.getDataFolderToCollect(), ctx.game.getClientToCollect())
	end

	function ctx.game.getWealthTotal()
		return ctx.game.getMoney() + ctx.game.getToCollect()
	end

	function ctx.game.sampleIncomeRate()
		local now = os.clock()
		local total = ctx.game.getWealthTotal()
		if ctx.timers.incomeSampleAt > 0 then
			local dt = now - ctx.timers.incomeSampleAt
			if dt >= 0.75 then
				local rate = (total - ctx.timers.incomeSampleTotal) / dt
				if ctx.game.incomePerSec <= 0 then
					ctx.game.incomePerSec = math.max(0, rate)
				else
					ctx.game.incomePerSec = ctx.game.incomePerSec * 0.65 + math.max(0, rate) * 0.35
				end
				ctx.timers.incomeSampleAt = now
				ctx.timers.incomeSampleTotal = total
			end
		else
			ctx.timers.incomeSampleAt = now
			ctx.timers.incomeSampleTotal = total
		end
	end

	function ctx.game.getGems()
		local df = LP:FindFirstChild("DataFolder")
		local g = df and df:FindFirstChild("Gems")
		return g and g.Value or 0
	end

	function ctx.game.getRebirths()
		local df = LP:FindFirstChild("DataFolder")
		local r = df and df:FindFirstChild("Rebirths")
		if r then
			return r.Value
		end
		local ls = LP:FindFirstChild("leaderstats")
		r = ls and ls:FindFirstChild("Rebirths")
		return r and r.Value or 0
	end

	function ctx.game.isMoneyButton(btn)
		return btn:FindFirstChild("Price")
			and not btn:FindFirstChild("RebirthPrice")
			and not btn:FindFirstChild("GamepassPrice")
			and not btn:FindFirstChild("GroupID")
			and not btn:FindFirstChild("IsAnAfterGamepass")
	end

	function ctx.game.isRebirthAreaButton(btn)
		return btn:FindFirstChild("RebirthPrice")
			and not btn:FindFirstChild("GamepassPrice")
			and not btn:FindFirstChild("GroupID")
			and not btn:FindFirstChild("IsAnAfterGamepass")
	end

	function ctx.game.getBuyableRebirthAreaButtons()
		local tycoon = ctx.game.getTycoon()
		if not tycoon or not tycoon:FindFirstChild("Buttons") then
			return {}
		end
		local rebirths = ctx.game.getRebirths()
		local list = {}
		for _, btn in tycoon.Buttons:GetChildren() do
			if btn:FindFirstChild("IsButtonVisible")
				and btn.IsButtonVisible.Value
				and btn:FindFirstChild("Bought")
				and not btn.Bought.Value
				and ctx.game.isRebirthAreaButton(btn)
				and btn:FindFirstChild("Button")
			then
				local rebirthPrice = btn.RebirthPrice
				if rebirths >= rebirthPrice.Value then
					table.insert(list, {
						model = btn,
						name = btn.Name,
						rebirthPrice = rebirthPrice.Value,
					})
				end
			end
		end
		table.sort(list, function(a, b)
			if a.rebirthPrice == b.rebirthPrice then
				return a.name < b.name
			end
			return a.rebirthPrice < b.rebirthPrice
		end)
		return list
	end

	function ctx.game.getBuyableButtons()
		local tycoon = ctx.game.getTycoon()
		if not tycoon or not tycoon:FindFirstChild("Buttons") then
			return {}
		end
		local list = {}
		for _, btn in tycoon.Buttons:GetChildren() do
			if btn:FindFirstChild("IsButtonVisible")
				and btn.IsButtonVisible.Value
				and btn:FindFirstChild("Bought")
				and not btn.Bought.Value
				and ctx.game.isMoneyButton(btn)
				and btn:FindFirstChild("Button")
			then
				local priceObj = btn:FindFirstChild("Price")
				if priceObj then
					table.insert(list, { model = btn, name = btn.Name, price = priceObj.Value })
				end
			end
		end
		table.sort(list, function(a, b)
			if a.price == b.price then
				return a.name < b.name
			end
			return a.price < b.price
		end)
		return list
	end

	local function getGameCashLabel()
		if ctx.game.gameCashLabel and ctx.game.gameCashLabel.Parent then
			return ctx.game.gameCashLabel
		end
		local pg = LP:FindFirstChild("PlayerGui")
		local hud = pg and pg:FindFirstChild("MainUI") and pg.MainUI:FindFirstChild("HUD")
		local cash = hud
			and hud:FindFirstChild("LeftSidebar")
			and hud.LeftSidebar:FindFirstChild("Currency")
			and hud.LeftSidebar.Currency:FindFirstChild("Cash")
		ctx.game.gameCashLabel = cash and cash:FindFirstChild("Amount")
		return ctx.game.gameCashLabel
	end

	function ctx.game.updateCashHud()
		local label = getGameCashLabel()
		if not label then
			return
		end
		label.Text = ctx.fmt.money(ctx.game.getMoney()) .. " " .. ctx.fmt.incomeRate(ctx.game.incomePerSec)
	end

	function ctx.game.hookCashHud()
		if ctx.game.gameCashHooked then
			return
		end
		local label = getGameCashLabel()
		if not label then
			return
		end
		ctx.game.gameCashHooked = true
		local ls = LP:FindFirstChild("leaderstats")
		local money = ls and ls:FindFirstChild("Money")
		if money then
			ctx.track(money:GetPropertyChangedSignal("Value"):Connect(function()
				task.defer(ctx.game.updateCashHud)
			end))
		end
		local cv = ctx.game.getClientValues()
		local pool = cv and cv:FindFirstChild("ToCollect")
		if pool then
			ctx.track(pool:GetPropertyChangedSignal("Value"):Connect(function()
				ctx.game.sampleIncomeRate()
				ctx.game.updateCashHud()
			end))
		end
		ctx.game.updateCashHud()
	end

	ctx.cleanupLegacy()
end
