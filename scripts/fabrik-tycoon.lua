--[[
  Fabrik-Tycoon auto farm (place 15197136141)
  Hub runs this file only.

  scripts/sdk/              DexUI session, loops, window helpers
  scripts/helpers/fabrik/   Optional Fabrik shared API (tycoon getters, formatting)
local DexUI = (getgenv and getgenv().DexUI) or nil
if not DexUI then
	error("[fabrik-tycoon] DexUI not found. Launch from the DexUI scripts hub.")
end
if not (readfile and isfile and loadstring) then
	error("[fabrik-tycoon] Executor must support readfile / isfile / loadstring.")
end
--[[ Fabrik-Tycoon â€” all game logic. Hub: scripts/fabrik-tycoon.lua ]]

return function(DexUI)
	local SDK_PREFIXES = { "scripts/sdk/", "DexUI/scripts/sdk/" }
	local API_PREFIXES = { "scripts/helpers/fabrik/", "DexUI/scripts/helpers/fabrik/" }

	local function loadFrom(prefixes, name)
		for _, prefix in prefixes do
			local path = prefix .. name .. ".lua"
			if isfile(path) then
				local chunk, err = loadstring(readfile(path), "@" .. path)
				if not chunk then
					error("[fabrik-tycoon] compile " .. path .. ": " .. tostring(err), 0)
				end
				return chunk()
			end
		end
		error("[fabrik-tycoon] missing: " .. name, 0)
	end

	local manifest = {
		id = "fabrik-tycoon",
		name = "Fabrik Farm",
		windowTitle = "Fabrik-Tycoon Farm",
		logTag = "FabrikFarm",
		placeId = 15197136141,
		placeIds = { 15197136141 },
		prefixes = { "scripts/games/fabrik-tycoon/", "DexUI/scripts/games/fabrik-tycoon/" },
		pipeline = {},
		abortAfter = {},
		legacyGuis = { "M3_FabrikFarm", "M3_FabrikFarmHistory" },
		genv = {
			session = "__FabrikFarmSession",
			ui = "__FabrikFarmUI",
			config = "__FabrikFarmConfig",
			stats = "__FabrikFarmStats",
			phase = "__FabrikFarmPhase",
		},
		shutdown = {
			title = "Fabrik Farm",
			message = "Unloaded â€” farm stopped",
			logMessage = "Unloaded â€” farm loops stopped, UI removed",
		},
		notifDuration = 4.2,
		notifyStyle = {
			Life = 4.2,
			Text = { Gradient = "rainbow" },
			TextStroke = { Gradient = "rainbow", Thickness = 3.5 },
			StackPosition = UDim2.new(1, -16, 0.58, 0),
		},
		ctxExtend = {
			upgradeIds = { "OreLimit", "OreValue", "DropperSpeed", "ConveyorSpeed", "WalkSpeed", "ShinyOresChance" },
		},
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
		stats = {
			collects = 0, buttons = 0, upgrades = 0, rebirths = 0, manualDrops = 0,
			lastMsg = "", errors = 0, cycles = 0,
		},
		timers = {
			lastRebirthAt = 0, lastManualDropAt = 0, lastAdCleanAt = 0, lastCycleAt = 0,
			lastProgressAt = 0, rebirthBusyUntil = 0, loopAcc = 0,
			incomeSampleAt = 0, incomeSampleTotal = 0,
		},
		caches = { rebirth = { bought = 0, needed = 0, canRebirth = false } },
		widgets = { status = nil, progress = nil, stats = nil },
		game = { incomePerSec = 0, gameCashLabel = nil, gameCashHooked = false },
	}

	local SDK = loadFrom(SDK_PREFIXES, "run")
	local ctx = SDK(manifest, DexUI)
	if not ctx.isAlive() then return end

	if not loadFrom(API_PREFIXES, "api")(ctx) then
		ctx.log.error("Fabrik API failed (Scripts.Other) â€” aborting")
		ctx.shutdown(false)
		return
	end

	-- init
		local LP = ctx.lp
		local RS = game:GetService("ReplicatedStorage")

		ctx.runStep("waitEvents", function()
			ctx.events = RS:WaitForChild("Events", 15)
		end)
		if not ctx.events then
			ctx.log.error("Events folder missing Ã¢â‚¬â€ wrong game? aborting")
			ctx.shutdown(false)
			return
		end

		if not ctx.other then
			ctx.log.error("Fabrik API helper did not load Scripts.Other Ã¢â‚¬â€ aborting")
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
	if not ctx.isAlive() then return end

	-- farm
		local Config = ctx.config
		local stats = ctx.stats
		local LP = ctx.lp
		local RS = ctx.rs
		local CollectMoney = ctx.remotes.collectMoney
		local BuyUpgrade = ctx.remotes.buyUpgrade
		local RequestRebirth = ctx.remotes.requestRebirth
		local findPath = ctx.findPath
		local formatGameValue = ctx.formatGameValue
		local getUpgradeData = ctx.getUpgradeData
		local UPGRADE_IDS = ctx.upgradeIds
		local track = ctx.track
		local logInfo, logWarn, logError, logDebug = ctx.log.info, ctx.log.warn, ctx.log.error, ctx.log.debug
		local setPhase = ctx.log.setPhase
		local pushFarmHistory = ctx.notify.action
		local fmtGameMoney = ctx.fmt.money
		local fmtIncomeRate = ctx.fmt.incomeRate
		local getTycoon = ctx.game.getTycoon
		local getMoney = ctx.game.getMoney
		local getGems = ctx.game.getGems
		local getRebirths = ctx.game.getRebirths
		local getToCollect = ctx.game.getToCollect
		local getClientToCollect = ctx.game.getClientToCollect
		local getDataFolderToCollect = ctx.game.getDataFolderToCollect
		local getClientValues = ctx.game.getClientValues
		local getWealthTotal = ctx.game.getWealthTotal
		local sampleIncomeRate = ctx.game.sampleIncomeRate
		local getBuyableButtons = ctx.game.getBuyableButtons
		local getBuyableRebirthAreaButtons = ctx.game.getBuyableRebirthAreaButtons
		local isAlive = ctx.isAlive
		local startupReady = ctx.startupReady
		local incomePerSec = ctx.game.incomePerSec
		local gameCashHooked = ctx.game.gameCashHooked
		local updateGameCashDisplay = ctx.game.updateCashHud
		local hookGameCashDisplay = ctx.game.hookCashHud
		local lastRebirthAt = ctx.timers.lastRebirthAt
		local lastManualDropAt = ctx.timers.lastManualDropAt
		local lastAdCleanAt = ctx.timers.lastAdCleanAt
		local lastCycleAt = ctx.timers.lastCycleAt
		local lastProgressAt = ctx.timers.lastProgressAt
		local rebirthBusyUntil = ctx.timers.rebirthBusyUntil
		local loopAcc = ctx.timers.loopAcc
		local rebirthCache = ctx.caches.rebirth
		local statusLabel = ctx.widgets.status
		local progressLabel = ctx.widgets.progress
		local statsLabel = ctx.widgets.stats
		local farmNotify = ctx.notify.push
		local farmPlayFeedback = ctx.feedback.play

		local function purchaseHistoryLine(btnModel)
			local name = btnModel.Name
			if btnModel:FindFirstChild("RebirthPrice") then
				return string.format("+ %s  (%d R)", name, btnModel.RebirthPrice.Value)
			end
			if btnModel:FindFirstChild("Price") then
				return string.format("+ %s  (%s)", name, fmtGameMoney(btnModel.Price.Value))
			end
			return "+ " .. name
		end

		local function recordPurchaseHistory(btnModel)
			if btnModel then
				pushFarmHistory(purchaseHistoryLine(btnModel))
			end
		end

	-- Income model (verified in DroppersAndUpgraders / UpgraderFunctions): droppers
	-- spawn ore worth their model's `oreValue`; upgraders (Coin Press, Washer, Heater,
	-- Cleanser, ...) carry an `Upg` value and ADD it to every ore that passes over them
	-- (`block.Value += Up.Upg.Value`). Both numbers are direct per-ore income, so a pad
	-- carrying either grows income and beats infrastructure, which beats cosmetics.
	local tryCollect, tryCollectForProgress, touchBuy, tryBuyRebirthAreaButton, tryBuyCheapestButton
	local tryGemUpgrade, tryGemUpgrades, pressManualDropper
	local computeRebirthProgress, progressionContent
	;(function()
	local COSMETIC_KEYWORDS = {
		"Roof", "Light", "Railing", "Path", "Platform", "Wall", "Floor",
		"Window", "Sign", "Fence", "Bench", "Tree", "Door", "Support", "Barrel",
	}
	local CATEGORY_KEYWORDS = {
		{ "Refiner", 92 },
		{ "Upgrader", 90 },
		{ "Dropper", 88 },
		{ "Grinder", 85 },
		{ "Conveyor", 80 },
		{ "Catcher", 78 },
		{ "Factory", 75 },
		{ "Generator", 74 },
		{ "Wormhole", 74 },
		{ "Incinerator", 74 },
		{ "Unlock", 70 },
		{ "Lab", 68 },
		{ "Manual", 60 },
	}

	local function tableCount(t)
		if not t then
			return 0
		end
		local n = 0
		for _ in t do
			n += 1
		end
		return n
	end

	-- Cache per-ore income worth per button model (weak keys so destroyed pads are GC'd).
	-- We count BOTH `oreValue` (droppers) and `Upg` (upgraders / the factory line), since
	-- each adds directly to ore value. Without `Upg`, the whole Coin Press -> Washer ->
	-- Roller -> Bar Press -> Cleanser line reads as "0 ore" even though it boosts income.
	local oreValueCache = setmetatable({}, { __mode = "k" })
	local function getButtonOreValue(btnModel)
		if not btnModel then return 0 end
		local cached = oreValueCache[btnModel]
		if cached ~= nil then return cached end
		local best = 0
		local m = btnModel:FindFirstChild("Model")
		if m then
			for _, d in m:GetDescendants() do
				if (d.Name == "oreValue" or d.Name == "Upg")
					and d:IsA("ValueBase") and type(d.Value) == "number" and d.Value > best then
					best = d.Value
				end
			end
		end
		oreValueCache[btnModel] = best
		return best
	end

	local function isCosmeticButton(name)
		for _, kw in COSMETIC_KEYWORDS do
			if name:find(kw, 1, true) then return true end
		end
		return false
	end

	-- A pad "advances a chain" when its UnlockNext points at a pad that isn't bought
	-- yet. Buying it reveals the next pad (often the machine the deco is gating), so
	-- these are worth purchasing even when their own ore reads 0 -- both to unlock the
	-- machine behind them and because every reachable pad must be bought to rebirth.
	local function padAdvancesChain(btn)
		local nx = btn:FindFirstChild("UnlockNext")
		local target = nx and nx.Value
		if not target then return false end
		local bought = target:FindFirstChild("Bought")
		return bought ~= nil and not bought.Value
	end

	-- Look-ahead: a pad's real worth includes the income it UNLOCKS. We walk the
	-- UnlockNext chain and take the best ore value reachable, discounted per step,
	-- so a cheap gate (lights, path, conveyor) that opens a rich wing outranks a
	-- lone small dropper. We stop at gates the farm can't pass on its own
	-- (Robux / group / after-gamepass) so we never chase income behind a paywall.
	local CHAIN_DISCOUNT = 0.85
	local CHAIN_MAX_DEPTH = 30
	local function isBlockedGate(btn)
		return btn:FindFirstChild("GamepassPrice")
			or btn:FindFirstChild("GroupID")
			or btn:FindFirstChild("IsAnAfterGamepass")
	end

	-- Best discounted ore reachable from this pad forward (including itself).
	-- Cached per model (weak keys); the chain is structural so the value is stable.
	local chainOreCache = setmetatable({}, { __mode = "k" })
	local function getChainOre(btn, depth)
		if not btn then return 0 end
		local cached = chainOreCache[btn]
		if cached ~= nil then return cached end
		local best = getButtonOreValue(btn)
		if depth < CHAIN_MAX_DEPTH then
			local nx = btn:FindFirstChild("UnlockNext")
			local nextBtn = nx and nx.Value
			if nextBtn and not isBlockedGate(nextBtn) then
				local future = getChainOre(nextBtn, depth + 1) * CHAIN_DISCOUNT
				if future > best then best = future end
			end
		end
		chainOreCache[btn] = best
		return best
	end

	-- Score scale: any pad that leads (eventually) to income scores 100 + reachable
	-- ore, so income-bearing pads and the gates feeding them always beat pure
	-- infrastructure (40..92) and dead-end cosmetics (5).
	local function scoreMoneyButton(name, model)
		local chainOre = model and getChainOre(model, 0) or 0
		if chainOre > 0 then
			return 100 + math.min(chainOre, 5000)
		end
		if isCosmeticButton(name) then return 5 end
		local best = 40
		for _, entry in CATEGORY_KEYWORDS do
			if name:find(entry[1], 1, true) then
				best = math.max(best, entry[2])
			end
		end
		return best
	end

	local GEM_UPGRADE_WEIGHT = {
		OreValue = 1.5,
		DropperSpeed = 1.35,
		OreLimit = 1.2,
		ConveyorSpeed = 1.15,
		ShinyOresChance = 1.0,
		WalkSpeed = 0.6,
	}

	local function getGemUpgradeScore(id)
		local data = getUpgradeData(LP, id)
		if data.isMaxReached then return -1 end
		local delta = math.abs((data.nextUpgrade_ValueBoost or 0) - (data.currentUpgrade_ValueBoost or 0))
		if delta <= 0 then return -1 end
		local base = delta / math.max(1, data.nextUpgrade_Price)
		return base * (GEM_UPGRADE_WEIGHT[id] or 1)
	end

	-- Resolve the tycoon's physical collector pad (the part with a TouchInterest).
	local collectorPartCache
	local function getCollectorPart()
		if collectorPartCache and collectorPartCache.Parent then
			return collectorPartCache
		end
		collectorPartCache = nil
		local tycoon = getTycoon()
		if typeof(tycoon) ~= "Instance" then return nil end
		local build = tycoon:FindFirstChild("Build")
		if typeof(build) ~= "Instance" then return nil end
		local collect = build:FindFirstChild("Collect")
		if not collect then return nil end
		for _, d in collect:GetDescendants() do
			if d:IsA("BasePart") and (d:FindFirstChild("TouchInterest") or d:FindFirstChildOfClass("TouchTransmitter")) then
				collectorPartCache = d
				break
			end
		end
		collectorPartCache = collectorPartCache or collect:FindFirstChild("Part")
		return collectorPartCache
	end

	-- Collect by faking a touch on the collector pad (firetouchinterest works from
	-- any distance, no teleport). This is the game's intended path: firing
	-- CollectMoney:FireServer() raw makes the server error (Events:339 indexes a nil
	-- touched-part) and spams ServerError to every client, even though it collects.
	tryCollect = function(force)
		if not Config.AutoCollect and not force then return false end
		local amount = getToCollect()
		if not force and amount < Config.CollectMin then return false end
		if amount <= 0 and not force then return false end

		local part = getCollectorPart()
		local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if part and hrp and firetouchinterest then
			local ok, err = pcall(function()
				firetouchinterest(hrp, part, 0)
				task.wait(0.03)
				firetouchinterest(hrp, part, 1)
			end)
			if ok then
				stats.collects += 1
				stats.lastMsg = "collect $" .. tostring(amount)
				logDebug("touch-collected pool $" .. tostring(amount))
				return true
			end
			stats.lastMsg = "collect touch err: " .. tostring(err)
			logWarn("collector touch failed: " .. tostring(err))
			-- fall through to remote fallback
		end

		-- Fallback (no firetouchinterest / collector missing): the remote still
		-- collects, just noisily.
		local ok, err = pcall(function() CollectMoney:FireServer() end)
		if ok then
			stats.collects += 1
			stats.lastMsg = "collect $" .. tostring(amount) .. " (remote)"
			logDebug("collected pool $" .. tostring(amount) .. " via remote fallback")
			return true
		end
		stats.lastMsg = "collect err: " .. tostring(err)
		logWarn("CollectMoney:FireServer failed: " .. tostring(err))
		return false
	end

	-- Always collect: money in the wallet is just as usable for the next purchase
	-- as money in the pool, and withholding risks the pool capping (lost ore).
	-- The buy step does its own on-demand collect right before a purchase.
	tryCollectForProgress = function(force)
		return tryCollect(force)
	end

	-- Tycoon pads have no FireServer buy remote. Purchases run in TycoonSetup's
	-- Part.Touched handler (local Bought flag, models, UpdateNormalData bindable).
	-- Firing UpdateNormalData alone does NOT complete a buy (MCP-tested).
	-- firetouchinterest requires overlap, so we micro-teleport then restore position.
	touchBuy = function(btnModel)
		logDebug("touchBuy: " .. tostring(btnModel and btnModel.Name))
		if not firetouchinterest then
			stats.lastMsg = "no firetouchinterest"
			logWarn("touchBuy unavailable: executor lacks firetouchinterest")
			return false
		end
		local char = LP.Character
		if not char then
			stats.lastMsg = "no character"
			return false
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local part = btnModel:FindFirstChild("Button") and btnModel.Button:FindFirstChild("Part")
		if not hrp or not part then
			stats.lastMsg = "no button part"
			return false
		end
		local savedCFrame = hrp.CFrame
		local needMove = (hrp.Position - part.Position).Magnitude > 8
		local ok, err = pcall(function()
			if needMove then
				hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
			end
			firetouchinterest(hrp, part, 0)
			task.wait(0.08)
			firetouchinterest(hrp, part, 1)
			if needMove then
				hrp.CFrame = savedCFrame
			end
		end)
		if not ok then
			pcall(function() hrp.CFrame = savedCFrame end)
			stats.lastMsg = "touch err: " .. tostring(err)
			logWarn(string.format("touchBuy '%s' errored: %s", btnModel.Name, tostring(err)))
			return false
		end
		task.wait(0.25)
		if btnModel:FindFirstChild("Bought") and btnModel.Bought.Value then
			stats.buttons += 1
			local priceObj = btnModel:FindFirstChild("Price")
			local price = priceObj and priceObj.Value or 0
			if stats.buyGoal and stats.buyGoal ~= btnModel.Name then
				stats.lastMsg = string.format(
					"bought %s (%s) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ goal %s",
					btnModel.Name,
					fmtGameMoney(price),
					stats.buyGoal
				)
			else
				stats.lastMsg = "bought " .. btnModel.Name .. " (" .. fmtGameMoney(price) .. ")"
			end
			stats.buyGoal = nil
			logInfo("bought button: " .. btnModel.Name)
			recordPurchaseHistory(btnModel)
			return true
		end
		stats.lastMsg = "touch failed " .. btnModel.Name
		logDebug("touchBuy did not register a purchase for " .. btnModel.Name)
		return false
	end

	tryBuyRebirthAreaButton = function()
		if not Config.AutoButtons then return false end
		local buyable = getBuyableRebirthAreaButtons()
		local nextBtn = buyable[1]
		if not nextBtn then return false end
		if touchBuy(nextBtn.model) then
			stats.lastMsg = "rebirth area " .. nextBtn.name
			return true
		end
		return false
	end

	-- Buy the best income pad we can AFFORD (not just the single top target).
	-- This keeps income growing instead of stalling for one expensive pad, while
	-- the wallet keeps accumulating toward pads we can't yet afford.
	local COSMETIC_MAX_SCORE = 5
	-- How close (fraction of the target price) we must be before we stop buying cheaper
	-- pads and purely hoard for the top income pad. Below this we keep progressing.
	local SAVE_THRESHOLD = 0.6

	local function rankIncomePads(buyable)
		local income = {}
		for _, btn in buyable do
			btn.score = scoreMoneyButton(btn.name, btn.model)
			if btn.score > COSMETIC_MAX_SCORE then
				income[#income + 1] = btn
			end
		end
		table.sort(income, function(a, b)
			if a.score ~= b.score then return a.score > b.score end
			if a.price ~= b.price then return a.price < b.price end
			return a.name < b.name
		end)
		return income
	end

	local function pickProgressPad(money, buyable, top)
		if money >= top.price * SAVE_THRESHOLD then return nil end
		local pick
		for _, btn in buyable do
			if btn.price <= money and btn.price < top.price then
				if not pick then pick = btn end
				if padAdvancesChain(btn.model) then return btn end
			end
		end
		return pick
	end

	-- Cheapest income pad above wallet (what the farm buys before the end goal).
	local function nextStepIncomePad(income, money)
		local step
		for _, btn in income do
			if btn.price > money then
				if not step or btn.price < step.price then
					step = btn
				end
			end
		end
		if not step then return nil end
		return step, step.price - money
	end

	-- What the farm is doing this cycle (for Progress tab ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â matches tryBuyCheapestButton).
	local function describeBuyIntent()
		local buyable = getBuyableButtons()
		if #buyable == 0 then
			return { mode = "none" }
		end
		local income = rankIncomePads(buyable)
		if #income == 0 then
			return { mode = "cosmetics" }
		end
		local top = income[1]
		local money = getMoney()
		local pct = math.min(100, math.floor(money / math.max(1, top.price) * 100))

		for _, btn in income do
			if money >= btn.price then
				return {
					mode = "buy_now",
					top = top,
					now = btn,
					money = money,
					pct = pct,
				}
			end
		end

		local progress = pickProgressPad(money, buyable, top)
		if progress then
			return {
				mode = "progress",
				top = top,
				now = progress,
				money = money,
				pct = pct,
			}
		end

		if money >= top.price * SAVE_THRESHOLD then
			return {
				mode = "hoard",
				top = top,
				money = money,
				pct = pct,
			}
		end

		local nextPad, shortfall = nextStepIncomePad(income, money)
		return {
			mode = "save",
			top = top,
			money = money,
			pct = pct,
			nextPad = nextPad,
			nextShortfall = shortfall,
			pool = getToCollect(),
		}
	end

	tryBuyCheapestButton = function()
		if not Config.AutoButtons then return false end
		local buyable = getBuyableButtons()
		if #buyable == 0 then return false end

		local income = rankIncomePads(buyable)
		local cosmetics = {}
		for _, btn in buyable do
			if btn.score <= COSMETIC_MAX_SCORE then
				cosmetics[#cosmetics + 1] = btn
			end
		end

		if #income > 0 then
			-- Pull the pool into the wallet if it lets us afford the top target now.
			local top = income[1]
			local money = getMoney()
			if money < top.price and money + getToCollect() >= top.price then
				tryCollect(true)
			end
			money = getMoney()

			for _, btn in income do
				if money >= btn.price then
					stats.buyGoal = top.name
					logDebug(string.format(
						"buy %s ($%d, score %d, ore %d) toward %s",
						btn.name, btn.price, btn.score, getButtonOreValue(btn.model), top.name
					))
					return touchBuy(btn.model)
				end
			end

			-- Can't afford the top income pad. When we're already close (>= SAVE_THRESHOLD
			-- of the price) keep saving so we don't derail a big earner. Otherwise don't sit
			-- idle: buy the cheapest affordable pad that's cheaper than the target, PREFERRING
			-- one that advances a chain (reveals the next machine). This keeps machines
			-- unlocking and pushes the rebirth requirement (buy-everything-reachable) forward
			-- instead of hoarding behind one unaffordable pad.
			local pick = pickProgressPad(money, buyable, top)
			if pick then
				stats.buyGoal = top.name
				stats.lastMsg = string.format(
					"progress %s (%s) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ goal %s",
					pick.name,
					fmtGameMoney(pick.price),
					top.name
				)
				logDebug(string.format(
					"progress-buy %s ($%d) toward %s",
					pick.name, pick.price, top.name
				))
				return touchBuy(pick.model)
			end

			stats.lastMsg = string.format("hoarding %s/%s for %s", fmtGameMoney(money), fmtGameMoney(top.price), top.name)
			return false
		end

		-- Only cosmetics remain ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â buy the cheapest affordable one so progression
		-- (their UnlockNext chains) isn't permanently blocked.
		table.sort(cosmetics, function(a, b) return a.price < b.price end)
		local money = getMoney()
		for _, btn in cosmetics do
			if money >= btn.price then
				logDebug("buy cosmetic (only option left): " .. btn.name)
				return touchBuy(btn.model)
			end
		end
		return false
	end

	tryGemUpgrade = function(id)
		local data = getUpgradeData(LP, id)
		if data.isMaxReached then return false end
		if getGems() < data.nextUpgrade_Price then return false end
		local ok, err = pcall(function() BuyUpgrade:FireServer(id) end)
		if ok then
			stats.upgrades += 1
			stats.lastMsg = "gem " .. id
			pushFarmHistory(string.format("+ %s  (%d gems)", id, data.nextUpgrade_Price))
			logDebug("gem upgrade bought: " .. id)
			return true
		end
		stats.lastMsg = "gem err: " .. tostring(err)
		logWarn(string.format("BuyUpgrade:FireServer('%s') failed: %s", id, tostring(err)))
		return false
	end

	-- Buy the single best-value gem upgrade per cycle (delta value / price, weighted).
	tryGemUpgrades = function()
		if not Config.AutoGemUpgrades then return false end
		local order = {}
		for _, id in UPGRADE_IDS do
			table.insert(order, id)
		end
		table.sort(order, function(a, b)
			local sa, sb = getGemUpgradeScore(a), getGemUpgradeScore(b)
			if sa ~= sb then return sa > sb end
			return a < b
		end)
		for _, id in order do
			if tryGemUpgrade(id) then return true end
		end
		return false
	end

	local function buildRebirthMaps(tycoon)
		local unlockTree = {}
		local rebirthTbl = {}
		for _, btn in tycoon.Buttons:GetChildren() do
			if btn:FindFirstChild("Bought")
				and not btn:FindFirstChild("GamepassPrice")
				and not btn:FindFirstChild("IsAnAfterGamepass")
				and not btn:FindFirstChild("GroupID")
			then
				unlockTree[btn.Name] = {}
				for _, child in btn:GetChildren() do
					if child.Name == "UnlockNext" and child.Value then
						if btn:FindFirstChild("Price") or btn:FindFirstChild("RebirthPrice") then
							table.insert(unlockTree[btn.Name], child.Value.Name)
						end
					end
				end
				if btn:FindFirstChild("RebirthPrice") then
					table.insert(rebirthTbl, { btn.Name, btn.RebirthPrice.Value })
				end
			end
		end
		table.sort(rebirthTbl, function(a, b) return a[2] < b[2] end)
		return unlockTree, rebirthTbl
	end

	local function countBoughtMoneyButtons(tycoon)
		local n = 0
		for _, btn in tycoon.Buttons:GetChildren() do
			if btn:FindFirstChild("Bought")
				and btn:FindFirstChild("Price")
				and not btn:FindFirstChild("GamepassPrice")
				and not btn:FindFirstChild("RebirthPrice")
				and not btn:FindFirstChild("IsAnAfterGamepass")
				and not btn:FindFirstChild("GroupID")
				and btn.Bought.Value
			then
				n += 1
			end
		end
		return n
	end

	local function computeRebirthProgressUnsafe()
		local tycoon = getTycoon()
		if not tycoon or not findPath or not findPath.getDescendants then return nil end
		local unlockTree, rebirthTbl = buildRebirthMaps(tycoon)
		local rebirths = getRebirths()
		local rebirthGateCount = tableCount(rebirthTbl)
		local needed
		local bought

		local atMaxRebirthTier = false
		if rebirthGateCount > 0 and rebirthTbl[rebirthGateCount] then
			atMaxRebirthTier = rebirths >= rebirthTbl[rebirthGateCount][2]
		end

		if atMaxRebirthTier then
			needed = tableCount(unlockTree) - rebirthGateCount
			bought = countBoughtMoneyButtons(tycoon)
		else
			local blocked = {}
			for _, entry in rebirthTbl do
				if rebirths < entry[2] then
					local ok, descendants = pcall(findPath.getDescendants, unlockTree, entry[1], {})
					if ok and typeof(descendants) == "table" then
						for _, name in descendants do
							if not table.find(blocked, name) then
								table.insert(blocked, name)
							end
						end
					end
				end
			end
			needed = tableCount(unlockTree) - tableCount(blocked) - rebirthGateCount
			bought = countBoughtMoneyButtons(tycoon)
		end

		needed -= 1
		local canRebirth = needed > 0 and bought >= needed
		return {
			bought = bought,
			needed = needed,
			canRebirth = canRebirth,
		}
	end

	computeRebirthProgress = function()
		local ok, result = pcall(computeRebirthProgressUnsafe)
		if ok and result then
			rebirthCache = result
			return result
		end
		if not ok then
			logWarn("computeRebirthProgress crashed: " .. tostring(result))
		end
		return rebirthCache
	end

	local function getManualDropPrompt()
		local tycoon = getTycoon()
		if not tycoon then return nil end
		local btn = tycoon.Buttons:FindFirstChild("Manual Block Dropper1")
		if not btn or not btn:FindFirstChild("Bought") or not btn.Bought.Value then return nil end
		local model = btn:FindFirstChild("Model")
		local button = model and model:FindFirstChild("Button")
		return button and button:FindFirstChild("ProximityPrompt")
	end

	local function anyManualDropperRunning()
		local tycoon = getTycoon()
		if not tycoon then return false end
		for _, btn in tycoon.Buttons:GetChildren() do
			if btn.Name:find("Manual Block Dropper", 1, true)
				and btn:FindFirstChild("Bought") and btn.Bought.Value
				and btn:FindFirstChild("IsAManualDropper")
				and btn:FindFirstChild("Running") and btn.Running.Value
			then
				return true
			end
		end
		return false
	end

	local function getManualDropCooldown()
		local data = getUpgradeData(LP, "DropperSpeed")
		return math.max(0.15, data.currentUpgrade_ValueBoost or 1)
	end

	pressManualDropper = function(force)
		if not Config.AutoManualDropper and not force then return false end
		local prompt = getManualDropPrompt()
		if not prompt then
			stats.lastMsg = "no manual dropper pad"
			return false
		end
		if not anyManualDropperRunning() then
			stats.lastMsg = "manual droppers idle"
			return false
		end
		local cd = getManualDropCooldown()
		if not force and os.clock() - lastManualDropAt < cd then return false end
		local ok, err = pcall(function()
			if fireproximityprompt then
				fireproximityprompt(prompt, 1)
			else
				prompt.Triggered:Fire(LP)
			end
		end)
		if ok then
			lastManualDropAt = os.clock()
			stats.manualDrops += 1
			stats.lastMsg = "manual drop"
			pushFarmHistory("+ Manual drop")
			logDebug("manual dropper triggered")
			return true
		end
		stats.lastMsg = "manual drop err: " .. tostring(err)
		logWarn("manual dropper trigger failed: " .. tostring(err))
		return false
	end

	local function buttonCostLabel(btn)
		if btn:FindFirstChild("Price") then return fmtGameMoney(btn.Price.Value) end
		if btn:FindFirstChild("RebirthPrice") then return btn.RebirthPrice.Value .. " rebirth" end
		if btn:FindFirstChild("GamepassPrice") then return "Robux pass" end
		if btn:FindFirstChild("GroupID") then return "group" end
		return "free"
	end

	local function getTopTarget()
		local buyable = getBuyableButtons()
		if #buyable == 0 then return nil end
		local best, bestScore
		for _, btn in buyable do
			local s = scoreMoneyButton(btn.name, btn.model)
			if s > COSMETIC_MAX_SCORE then
				if not best or s > bestScore or (s == bestScore and btn.price < best.price) then
					best, bestScore = btn, s
				end
			end
		end
		if not best then
			table.sort(buyable, function(a, b) return a.price < b.price end)
			best = buyable[1]
			bestScore = scoreMoneyButton(best.name, best.model)
		end
		best.score = bestScore
		return best
	end

	local function builtSummary()
		local tycoon = getTycoon()
		if not tycoon or not tycoon:FindFirstChild("Buttons") then return "Tycoon not loaded." end
		local bought, total, incomeBuilt = 0, 0, 0
		for _, b in tycoon.Buttons:GetChildren() do
			if b:FindFirstChild("Bought") then
				total += 1
				if b.Bought.Value then
					bought += 1
					if getButtonOreValue(b) > 0 then incomeBuilt += 1 end
				end
			end
		end
		return string.format("Built %d / %d pads  ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·  %d income pads built", bought, total, incomeBuilt)
	end

	progressionContent = function()
		local lines = { builtSummary() }
		local prog = computeRebirthProgress()
		if prog and prog.needed > 0 then
			lines[#lines + 1] = string.format(
				"Rebirth:  %d / %d money pads%s",
				prog.bought,
				prog.needed,
				prog.canRebirth and "  (ready)" or ""
			)
		end
		lines[#lines + 1] = ""
		if not Config.AutoButtons then
			lines[#lines + 1] = "Enable \"Buy buildings\" to auto-progress."
			return table.concat(lines, "\n")
		end
		local intent = describeBuyIntent()
		if intent.mode == "none" then
			lines[#lines + 1] = "No buyable pads right now ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â rebirth or a gated"
			lines[#lines + 1] = "unlock may be blocking the next area."
			return table.concat(lines, "\n")
		end
		if intent.mode == "cosmetics" then
			lines[#lines + 1] = "Only decor pads left ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â buying those to unblock chains."
			return table.concat(lines, "\n")
		end

		if stats.lastMsg and stats.lastMsg ~= "" then
			lines[#lines + 1] = "Last action:  " .. stats.lastMsg
			lines[#lines + 1] = ""
		end

		local target = intent.top
		local money = intent.money
		local pct = intent.pct

		if intent.mode == "buy_now" then
			lines[#lines + 1] = "Buying now:  " .. intent.now.name
			lines[#lines + 1] = string.format("  %s  (can afford)", fmtGameMoney(intent.now.price))
			lines[#lines + 1] = "End goal after this:  " .. target.name
			lines[#lines + 1] = string.format(
				"  %s of %s  (%d%% toward goal)",
				fmtGameMoney(money), fmtGameMoney(target.price), pct
			)
		elseif intent.mode == "progress" then
			lines[#lines + 1] = "End goal:  " .. target.name
			lines[#lines + 1] = string.format(
				"  %s of %s  (%d%% toward goal)",
				fmtGameMoney(money), fmtGameMoney(target.price), pct
			)
			lines[#lines + 1] = string.format(
				"Buying now:  %s (%s)",
				intent.now.name,
				fmtGameMoney(intent.now.price)
			)
			lines[#lines + 1] = "  Cheaper pads first until 60% of goal, then hoard."
		elseif intent.mode == "hoard" then
			lines[#lines + 1] = "Hoarding for:  " .. target.name
			lines[#lines + 1] = string.format(
				"  %s of %s  (%d%%)",
				fmtGameMoney(money), fmtGameMoney(target.price), pct
			)
			lines[#lines + 1] = "  Close to goal ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â not buying cheaper pads anymore."
		else
			lines[#lines + 1] = "End goal:  " .. target.name
			lines[#lines + 1] = string.format(
				"  %s of %s  (%d%% toward goal)",
				fmtGameMoney(money), fmtGameMoney(target.price), pct
			)
			if intent.nextPad and intent.nextPad.name ~= target.name then
				lines[#lines + 1] = string.format(
					"  Next step: %s (%s) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â need %s more",
					intent.nextPad.name,
					fmtGameMoney(intent.nextPad.price),
					fmtGameMoney(intent.nextShortfall)
				)
				if intent.pool and intent.pool > 0 then
					local combined = money + intent.pool
					if combined >= intent.nextPad.price then
						lines[#lines + 1] = string.format(
							"  Pool %s ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â collect to afford next pad",
							fmtGameMoney(intent.pool)
						)
					else
						lines[#lines + 1] = string.format("  Pool %s", fmtGameMoney(intent.pool))
					end
				end
			else
				lines[#lines + 1] = "  Waiting for cash."
			end
			lines[#lines + 1] = "  Buys best affordable pad first, then works toward goal."
		end

		local ownOre = getButtonOreValue(target.model)
		if ownOre > 0 then
			lines[#lines + 1] = string.format("  Goal adds +%d ore value", ownOre)
		else
			lines[#lines + 1] = string.format(
				"  Goal unlocks ~+%d ore value", math.floor(getChainOre(target.model, 0))
			)
		end

		lines[#lines + 1] = ""
		lines[#lines + 1] = "After goal, unlocks:"
		local cur, shown = target.model, 0
		for _ = 1, 6 do
			local nx = cur:FindFirstChild("UnlockNext")
			local nb = nx and nx.Value
			if not nb then break end
			local oreN = getButtonOreValue(nb)
			lines[#lines + 1] = string.format(
				"  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ %s  (%s%s)",
				nb.Name, buttonCostLabel(nb), oreN > 0 and (", +" .. oreN .. " ore") or ""
			)
			cur, shown = nb, shown + 1
		end
		if shown == 0 then
			lines[#lines + 1] = "  (end of this chain)"
		end
		return table.concat(lines, "\n")
	end
	end)()

	local function tryRebirth()
		if not Config.AutoRebirth then return false end
		if os.clock() < rebirthBusyUntil then return false end
		if os.clock() - lastRebirthAt < Config.RebirthInterval then return false end
		local prog = computeRebirthProgress()
		if not prog or not prog.canRebirth then return false end
		local tycoon = getTycoon()
		if not tycoon then return false end
		local ok, err = pcall(function()
			RequestRebirth:FireServer(prog.bought, prog.needed, tycoon)
		end)
		if ok then
			stats.rebirths += 1
			stats.lastMsg = string.format("rebirth %d/%d", prog.bought, prog.needed)
			pushFarmHistory(string.format("+ Rebirth  (%d/%d)", prog.bought, prog.needed))
			lastRebirthAt = os.clock()
			rebirthBusyUntil = os.clock() + 15
			logInfo(string.format("rebirth fired (%d/%d buttons)", prog.bought, prog.needed))
			return true
		end
		stats.lastMsg = "rebirth err: " .. tostring(err)
		logWarn("RequestRebirth:FireServer failed: " .. tostring(err))
		return false
	end

	local function updateProgressLabel(force)
		if not (progressLabel and progressLabel.Set) then return end
		if not force and os.clock() - lastProgressAt < 1 then return end
		lastProgressAt = os.clock()
		pcall(function()
			progressLabel:Set({ Title = "Progression", Content = progressionContent() })
		end)
	end

	local function statusLine()
		local prog = rebirthCache
		return string.format(
			"%s %s ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· pool %s (df %s) ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· gems %d ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· R%d ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· reb %d/%d",
			fmtGameMoney(getMoney()),
			fmtIncomeRate(incomePerSec),
			tostring(getClientToCollect()),
			tostring(getDataFolderToCollect()),
			getGems(),
			getRebirths(),
			prog.bought,
			prog.needed
		)
	end

	local function statsLine()
		local msg = stats.lastMsg
		if msg and msg ~= "" then
			return string.format("Cycles %d ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· Errors %d ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· %s", stats.cycles, stats.errors, msg)
		end
		return string.format("Cycles %d ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· Errors %d ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· phase %s", stats.cycles, stats.errors, ctx.log.phase)
	end

	local function updateStatusLabel()
		sampleIncomeRate()
		updateGameCashDisplay()
		if statusLabel and statusLabel.Set then
			pcall(function() statusLabel:Set(statusLine()) end)
		end
		if statsLabel and statsLabel.Set then
			pcall(function() statsLabel:Set(statsLine()) end)
		end
		updateProgressLabel(false)
	end

	local function farmOnce()
		if not isAlive() then return end
		setPhase("sync")
		ctx.log.verbose = ctx.config.VerboseLogging
		if not Config.Enabled then
			stats.lastMsg = "master off"
			setPhase("idle")
			return
		end

		stats.cycles += 1
		if Config.AutoManualDropper then
			setPhase("manualDropper")
			pressManualDropper(false)
		end
		if Config.AutoCollect then
			setPhase("collect")
			tryCollectForProgress(false)
		end
		if Config.AutoGemUpgrades then
			setPhase("gemUpgrades")
			tryGemUpgrades()
		end
		if Config.AutoButtons then
			setPhase("buyRebirthArea")
			tryBuyRebirthAreaButton()
			setPhase("buyButton")
			tryBuyCheapestButton()
		end
		if Config.AutoRebirth then
			setPhase("rebirth")
			tryRebirth()
		end

		if stats.cycles % 8 == 0 then
			setPhase("rebirthProgress")
			computeRebirthProgress()
		end
		if Config.HideMonetization and os.clock() - lastAdCleanAt >= 2 then
			lastAdCleanAt = os.clock()
			setPhase("adClean")
			ctx.ads.hide()
		end
		setPhase("status")
		updateStatusLabel()
		setPhase("cycleEnd")
	end

	local function safeFarmOnce()
		local startT = os.clock()
		local ok, err = pcall(farmOnce)
		lastCycleAt = os.clock()
		if not ok then
			stats.errors += 1
			stats.lastMsg = string.format("cycle err @%s: %s", ctx.log.phase, tostring(err))
			logError(string.format("CRASH in farm cycle during phase '%s': %s", ctx.log.phase, tostring(err)))
			farmNotify({
				Title = "Farm error",
				Content = string.format("%s: %s", ctx.log.phase, tostring(err)),
				Duration = 5,
			})
		else
			local elapsed = lastCycleAt - startT
			if elapsed > 1 then
				logWarn(string.format("slow cycle %.2fs (last phase '%s')", elapsed, ctx.log.phase))
			end
			logDebug(string.format("cycle #%d ok (%.3fs)", stats.cycles, elapsed))
		end
	end


		ctx.farm = {
			tryCollect = tryCollect,
			tryCollectForProgress = tryCollectForProgress,
			touchBuy = touchBuy,
			tryBuyRebirthAreaButton = tryBuyRebirthAreaButton,
			tryBuyCheapestButton = tryBuyCheapestButton,
			tryGemUpgrades = tryGemUpgrades,
			pressManualDropper = pressManualDropper,
			tryRebirth = tryRebirth,
			once = farmOnce,
			safeOnce = safeFarmOnce,
		}
		ctx.progress = {
			content = progressionContent,
			update = updateProgressLabel,
		}
		ctx.status = {
			line = statusLine,
			statsLine = statsLine,
			update = updateStatusLabel,
		}

	-- ads
		local Config = ctx.config
		local LP = ctx.lp
		local track = ctx.track
		local logInfo, logWarn, logDebug = ctx.log.info, ctx.log.warn, ctx.log.debug
		local setPhase = ctx.log.setPhase
		local getTycoon = ctx.game.getTycoon
		local startupReady = ctx.startupReady
		local lastAdCleanAt = ctx.timers.lastAdCleanAt

		local AD_HIDE_YIELD_EVERY = 40
		local AD_HIDE_MIN_INTERVAL = 2
		local adHideBusy = false
		local adHidePending = false
		local adHideDebounceThread = nil
		local adCleanerConnections = {}

		local function stripGuiAd(obj)
		if obj:IsA("GuiObject") then
			if not obj.Visible then return end
			obj.Visible = false
			if obj:IsA("GuiButton") then
				obj.Active = false
			end
		end
	end

	local BUILD_MONETIZATION_PROPS = {
		VIPBTN = true,
		["2XMONEYBTN"] = true,
		AUTOCOLLECTBTN = true,
		SHINYBTN = true,
	}

	local function isBuildMonetizationProp(inst)
		return BUILD_MONETIZATION_PROPS[inst.Name] == true
	end

	-- The game's ShowAndHide script constantly RESTORES button visuals: parts get
	-- Transparency = NumberValue_Transparency.Value and BillboardGuis get Enabled = true.
	-- So a one-shot hide gets reverted. We instead neutralize the *restore targets*
	-- (NumberValue_Transparency -> 1, BoolValue_Collision -> false) and hide the
	-- billboard's child GuiObjects (which ShowAndHide never touches Ã¢â‚¬â€ it only flips
	-- .Enabled). Result: the pad stays invisible even when the game re-shows it.
	local function disableWorldAdInstance(inst)
		if inst:IsA("BasePart") or inst:IsA("UnionOperation") or inst:IsA("MeshPart") then
			local nt = inst:FindFirstChild("NumberValue_Transparency")
			if nt and nt:IsA("ValueBase") then nt.Value = 1 end
			local col = inst:FindFirstChild("BoolValue_Collision")
			if col and col:IsA("ValueBase") then col.Value = false end
			inst.Transparency = 1
			inst.LocalTransparencyModifier = 1
			inst.CanCollide = false
			inst.CanTouch = false
			inst.CanQuery = false
			inst:SetAttribute("__FabrikAdHidden2", true)
		elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
			-- Hide the actual ad content permanently; ShowAndHide only resets .Enabled.
			for _, g in inst:GetDescendants() do
				if g:IsA("GuiObject") then g.Visible = false end
			end
			inst.Enabled = false
			inst:SetAttribute("__FabrikAdHidden2", true)
		elseif inst:IsA("ProximityPrompt") then
			inst.Enabled = false
			inst:SetAttribute("__FabrikAdHidden2", true)
		elseif inst:IsA("ClickDetector") then
			inst.MaxActivationDistance = 0
			inst:SetAttribute("__FabrikAdHidden2", true)
		elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
			inst.Enabled = false
			inst:SetAttribute("__FabrikAdHidden2", true)
		elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
			inst.Enabled = false
			inst:SetAttribute("__FabrikAdHidden2", true)
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			local nt = inst:FindFirstChild("NumberValue_Transparency")
			if nt and nt:IsA("ValueBase") then nt.Value = 1 end
			inst.Transparency = 1
			inst:SetAttribute("__FabrikAdHidden2", true)
		elseif inst:IsA("SpecialMesh") then
			inst.Scale = Vector3.zero
			inst:SetAttribute("__FabrikAdHidden2", true)
		end
	end

	local function isMonetizationButton(btn)
		return btn:FindFirstChild("GamepassPrice")
			or btn:FindFirstChild("GroupID")
			or btn:FindFirstChild("IsAnAfterGamepass")
	end

	local function hideMonetizationButton(btn)
		if btn:GetAttribute("__FabrikAdHidden2") then return end
		local vis = btn:FindFirstChild("IsButtonVisible")
		if vis and vis.Value then
			vis.Value = false
		end
		local n = 0
		for _, d in btn:GetDescendants() do
			disableWorldAdInstance(d)
			n += 1
			if n % AD_HIDE_YIELD_EVERY == 0 then
				task.wait()
			end
		end
		btn:SetAttribute("__FabrikAdHidden2", true)
	end

	local function hideBuildMonetizationProp(inst)
		if inst:GetAttribute("__FabrikAdHidden2") then return end
		local n = 0
		for _, d in inst:GetDescendants() do
			disableWorldAdInstance(d)
			n += 1
			if n % AD_HIDE_YIELD_EVERY == 0 then
				task.wait()
			end
		end
		disableWorldAdInstance(inst)

		local parent = inst.Parent
		if parent then
			for _, sib in parent:GetChildren() do
				if sib ~= inst and sib.Name == "Meshes/pedestal" then
					disableWorldAdInstance(sib)
				end
			end
		end
		inst:SetAttribute("__FabrikAdHidden2", true)
	end

	local function hideTycoonMonetization(tycoon)
		if not tycoon then return end

		if tycoon:FindFirstChild("Buttons") then
			for _, btn in tycoon.Buttons:GetChildren() do
				if isMonetizationButton(btn) then
					hideMonetizationButton(btn)
				end
			end
		end

		local buildProps = {}
		local pedestals = {}
		local n = 0
		for _, d in tycoon:GetDescendants() do
			n += 1
			if isBuildMonetizationProp(d) then
				buildProps[#buildProps + 1] = d
			elseif d.Name == "Meshes/pedestal"
				and (d:IsA("MeshPart") or d:IsA("BasePart") or d:IsA("UnionOperation"))
			then
				local parent = d.Parent
				if parent
					and (
						parent:FindFirstChild("VIPBTN")
						or parent:FindFirstChild("2XMONEYBTN")
						or parent:FindFirstChild("AUTOCOLLECTBTN")
						or parent:FindFirstChild("SHINYBTN")
					)
				then
					pedestals[#pedestals + 1] = d
				end
			end
			if n % 200 == 0 then
				task.wait()
			end
		end

		for i, inst in buildProps do
			hideBuildMonetizationProp(inst)
			if i % 4 == 0 then
				task.wait()
			end
		end
		for i, inst in pedestals do
			disableWorldAdInstance(inst)
			if i % AD_HIDE_YIELD_EVERY == 0 then
				task.wait()
			end
		end
	end

	local function hideWorldMonetization()
		local playerTycoon = getTycoon()
		if playerTycoon then
			hideTycoonMonetization(playerTycoon)
			task.wait(0.15)
		end

		local tycoonsFolder = workspace:FindFirstChild("Tycoons")
		if not tycoonsFolder then return end
		for _, tycoon in tycoonsFolder:GetChildren() do
			if tycoon ~= playerTycoon then
				hideTycoonMonetization(tycoon)
				task.wait(0.25)
			end
		end
	end

	local UI_MONETIZATION_SECTIONS = {
		Gamepass = true,
		Gamepasses = true,
		Diamond = true,
		Cash = true,
		["Starter Pack"] = true,
	}

	local function hideStoreScrollingAds(scroll)
		if not scroll then return end
		for _, child in scroll:GetChildren() do
			if UI_MONETIZATION_SECTIONS[child.Name] then
				stripGuiAd(child)
			end
		end
	end

	local function hideMainUiAds(main)
		if not main then return end

		for _, name in { "Starter Pack", "Store", "Not Enough Cash" } do
			local frame = main:FindFirstChild(name)
			if frame then stripGuiAd(frame) end
		end

		local hud = main:FindFirstChild("HUD")
		if hud then
			local shop = hud:FindFirstChild("LeftSidebar")
				and hud.LeftSidebar:FindFirstChild("Buttons")
				and hud.LeftSidebar.Buttons:FindFirstChild("Row1")
				and hud.LeftSidebar.Buttons.Row1:FindFirstChild("Shop")
			if shop then stripGuiAd(shop) end

			local footer = hud:FindFirstChild("Footer")
			if footer then
				local boost = footer:FindFirstChild("5xMoney")
				if boost then stripGuiAd(boost) end
			end
		end

		for _, menuName in { "Upgrades", "Store" } do
			local menu = main:FindFirstChild(menuName)
			local scroll = menu
				and menu:FindFirstChild("ImageLabel")
				and menu.ImageLabel:FindFirstChild("MainFrame")
				and menu.ImageLabel.MainFrame:FindFirstChild("ScrollingFrame")
			hideStoreScrollingAds(scroll)
		end
	end

	local scheduleAdHide

	local function hideMonetizationAdsNow()
		if not Config.HideMonetization then return end
		if adHideBusy then
			adHidePending = true
			return
		end
		adHideBusy = true
		setPhase("adClean")
		local ok, err = pcall(function()
			local pg = LP:FindFirstChild("PlayerGui")
			local main = pg and pg:FindFirstChild("MainUI")
			hideMainUiAds(main)
			hideWorldMonetization()
		end)
		adHideBusy = false
		lastAdCleanAt = os.clock()
		if not ok then
			logWarn("hideMonetizationAds crashed: " .. tostring(err))
		elseif ctx.log.verbose then
			logDebug("ad hide pass complete")
		end
		if adHidePending then
			adHidePending = false
			scheduleAdHide()
		end
	end

	scheduleAdHide = function()
		if not Config.HideMonetization or not startupReady then return end
		adHidePending = true
		if adHideDebounceThread then return end
		adHideDebounceThread = task.spawn(function()
			while adHidePending and Config.HideMonetization do
				adHidePending = false
				local waitFor = AD_HIDE_MIN_INTERVAL - (os.clock() - lastAdCleanAt)
				if waitFor > 0 then
					task.wait(waitFor)
				end
				if Config.HideMonetization then
					hideMonetizationAdsNow()
				end
			end
			adHideDebounceThread = nil
		end)
	end

	hideMonetizationAds = function()
		if not Config.HideMonetization then return end
		scheduleAdHide()
	end

	local function disconnectAdCleanerListeners()
		for _, conn in adCleanerConnections do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(adCleanerConnections)
	end

	local function bindAdCleanerListeners()
		disconnectAdCleanerListeners()
		if not Config.HideMonetization then return end

		local tycoonRef = LP:FindFirstChild("TycoonOwned")
		if not tycoonRef then return end

		local conn = tycoonRef:GetPropertyChangedSignal("Value"):Connect(function()
			scheduleAdHide()
		end)
		table.insert(adCleanerConnections, conn)
		track(conn)
	end

	setAdHidingEnabled = function(enabled)
		Config.HideMonetization = enabled
		if not startupReady then return end
		if enabled then
			logInfo("ad hiding ON Ã¢â‚¬â€ scheduling clean pass")
			bindAdCleanerListeners()
			task.spawn(hideMonetizationAdsNow)
		else
			logInfo("ad hiding OFF Ã¢â‚¬â€ listeners disconnected")
			disconnectAdCleanerListeners()
			if adHideDebounceThread then
				adHidePending = false
			end
		end
	end

	startAdCleaner = function()
		-- Listeners attach only when the toggle is turned on (setAdHidingEnabled).
		-- Avoids DescendantAdded feedback loops while ads are meant to stay visible.
	end

		ctx.ads = {
			hide = hideMonetizationAds,
			setEnabled = setAdHidingEnabled,
			start = startAdCleaner,
		}

	-- ui
		local Config = ctx.config
		local stats = ctx.stats
		local unloadScript = ctx.dexui.bindUnload({
			masterKey = "Enabled",
			clearWidgets = true,
		})

		local ui = ctx.DexUI.CreateWindow(ctx.manifest.windowTitle or "Fabrik-Tycoon Farm")
		ctx.dexui.publishUi(ui)
		ctx.dexui.applyNotifyStyle(ui)

		ui:AddTab("Farm", 4483362458)
		ui:AddSection("Auto farm")
		ui:AddSwitch("Master auto farm", Config.Enabled, function(v)
			Config.Enabled = v
			ctx.feedback.play(v and "toggleOn" or "toggleOff")
		end)

		ui:AddSection("Include")
		ui:AddSwitch("Collect money", Config.AutoCollect, function(v)
			Config.AutoCollect = v
		end)
		ui:AddSwitch("Buy buildings", Config.AutoButtons, function(v)
			Config.AutoButtons = v
		end)
		ui:AddSwitch("Gem upgrades", Config.AutoGemUpgrades, function(v)
			Config.AutoGemUpgrades = v
		end)
		ui:AddSwitch("Rebirth", Config.AutoRebirth, function(v)
			Config.AutoRebirth = v
		end)
		ui:AddSwitch("Manual droppers", Config.AutoManualDropper, function(v)
			Config.AutoManualDropper = v
		end)

		ui:AddDivider()
		ui:AddSection("Live status")
		local statusWidget = ui:AddLabel(ctx.status.line())
		ctx.widgets.status = {
			Set = function(_, text)
				statusWidget.SetText(text)
			end,
		}
		local statsWidget = ui:AddLabel(ctx.status.statsLine())
		ctx.widgets.stats = {
			Set = function(_, text)
				statsWidget.SetText(text)
			end,
		}

		ui:AddTab("Progress", 4483362458)
		ui:AddSection("Live progression")
		local progressPara = ui:AddParagraph("Progression", ctx.progress.content())
		ctx.widgets.progress = progressPara
		ui:AddButton("Refresh now", function()
			ctx.progress.update(true)
			ctx.feedback.play("selection")
		end)

		ui:AddTab("Settings", 4483362458)
		ui:AddSection("Tuning")
		ui:AddSlider("Loop speed (s)", 0.15, 2, Config.LoopDelay, function(v)
			Config.LoopDelay = v
		end)
		ui:AddSlider("Rebirth check interval (s)", 3, 30, Config.RebirthInterval, function(v)
			Config.RebirthInterval = v
		end)
		ui:AddSlider("Min collect amount", 0, 500, Config.CollectMin, function(v)
			Config.CollectMin = math.floor(v + 0.5)
		end)

		ui:AddDivider()
		ui:AddSection("Extras")
		ui:AddSwitch("Hide Robux / gamepass ads", Config.HideMonetization, function(v)
			ctx.ads.setEnabled(v)
		end)
		ui:AddSwitch(
			"Verbose logging",
			Config.VerboseLogging,
			function(v)
				Config.VerboseLogging = v
				ctx.log.verbose = v
				ctx.log.info("verbose logging " .. (v and "ON" or "OFF"))
			end,
			"Console DEBUG lines + ServerError drain"
		)

		ui:AddDivider()
		ui:AddSection("Tools")
		ui:AddButton("Collect now", function()
			ctx.farm.tryCollect(true)
			ctx.status.update()
			ctx.feedback.play("selection")
		end)
		ui:AddButton("Buy next building", function()
			ctx.farm.tryBuyCheapestButton()
			ctx.status.update()
			ctx.feedback.play("selection")
		end)
		ui:AddButton("Rebirth now", function()
			if ctx.farm.tryRebirth() then
				ctx.feedback.play("toggleOn")
			else
				ctx.notify.push({
					Title = "Rebirth",
					Content = stats.lastMsg ~= "" and stats.lastMsg or "Not ready",
					Duration = 3,
				})
			end
			ctx.status.update()
		end)
		ui:AddButton("Print diagnostics", function()
			local diag = string.format(
				"phase %s Ã‚Â· alive %s Ã‚Â· cycles %d Ã‚Â· errors %d Ã‚Â· last %.1fs Ã‚Â· %s",
				ctx.log.phase,
				tostring(ctx.isAlive()),
				stats.cycles,
				stats.errors,
				ctx.timers.lastCycleAt > 0 and (os.clock() - ctx.timers.lastCycleAt) or -1,
				ctx.status.line()
			)
			ctx.log.info("DIAG | " .. diag)
			ctx.log.info(string.format(
				"DIAG counts | buttons:%d drops:%d gems:%d collects:%d rebirths:%d",
				stats.buttons,
				stats.manualDrops,
				stats.upgrades,
				stats.collects,
				stats.rebirths
			))
			ctx.notify.push({ Title = "Diagnostics", Content = diag, Duration = 6 })
		end)

		ui:AddDivider()
		ui:AddSection("Danger")
		ui:AddButton("Quit Ã¢â‚¬â€ stop farm & unload", unloadScript)

		ctx.dexui.addAboutTab(ui)

		ui:Show()
		ctx.notify.push({
			Title = ctx.name,
			Content = "Loaded Ã¢â‚¬â€ enable Master auto farm when ready.",
			Duration = 3,
		})

	local Config = ctx.config
	local stats = ctx.stats

	ctx.loop.runSteps({
		{ name = "initSyncConfig", run = function() ctx.log.verbose = Config.VerboseLogging end },
		{ name = "initRebirthProgress", run = function() ctx.progress.update(true) end },
		{ name = "initStatus", run = ctx.status.update },
		{ name = "hookGameCash", run = ctx.game.hookCashHud },
	})

	task.spawn(function()
		for _ = 1, 20 do
			if ctx.game.gameCashHooked then break end
			ctx.game.hookCashHud()
			task.wait(1)
		end
	end)

	ctx.startupReady = true
	ctx.log.info("startup complete â€” ad hiding gated behind toggle")
	ctx.runStep("startAdCleaner", ctx.ads.start)
	ctx.runStep("consumeServerError", function()
		local RS = ctx.rs
		local serverErr = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("ServerError")
		if serverErr and serverErr:IsA("RemoteEvent") then
			ctx.track(serverErr.OnClientEvent:Connect(function(msg)
				if ctx.log.verbose then ctx.log.debug("ServerError: " .. tostring(msg)) end
			end))
		end
	end)
	ctx.loop.warnWrongPlace()
	if not ctx.findPath then
		ctx.log.warn("Rebirth findPath unavailable â€” auto rebirth progress may be wrong")
	end
	ctx.log.setPhase("ready")
	ctx.log.info("Loaded (DexUI) â€” all toggles default OFF | " .. ctx.status.line())
	ctx.loop.startHeartbeat({ masterKey = "Enabled", delayKey = "LoopDelay", tick = ctx.farm.safeOnce })
	ctx.loop.startWatchdog({
		masterKey = "Enabled",
		onTick = function()
			ctx.log.verbose = Config.VerboseLogging
			ctx.status.update()
		end,
		logLine = function()
			return string.format(
				"[%s] %s | btn:%d drop:%d gem:%d col:%d reb:%d err:%d | %.2fs | phase:%s | %s",
				ctx.logTag, ctx.status.line(), stats.buttons, stats.manualDrops, stats.upgrades,
				stats.collects, stats.rebirths, stats.errors, Config.LoopDelay, ctx.log.phase,
				stats.lastMsg ~= "" and stats.lastMsg or "â€”"
			)
		end,
	})