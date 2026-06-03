--[[
  [UPD] Fabrik-Tycoon — remote + touch auto farmer (DexUI)
  Place: 15197136141

  Remotes (MCP verified):
    CollectMoney:FireServer()
    BuyUpgrade:FireServer(upgradeId)
    RequestRebirth:FireServer(bought, needed, tycoonInstance)
    Tycoon pads: NO buy remote — client Touched handler only (see touchBuy)
    Collect / gems / rebirth: real remotes (no teleport)
    Manual droppers: fireproximityprompt on MBD1 pad (all manual droppers listen to it)

  Requires getgenv().DexUI (set by the DexUI scripts hub before execute).
]]

local DexUI = (getgenv and getgenv().DexUI) or nil
if not DexUI then
	error("[fabrik-tycoon] DexUI not found. Launch this script from the DexUI scripts hub.")
end

local plrs = game:GetService("Players")
local http = game:GetService("HttpService")
local rs = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local G = (getgenv and getgenv()) or shared or _G
local LEGACY_GUI = "M3_FabrikFarm"
local HISTORY_GUI = "M3_FabrikFarmHistory"

local Session
local INJECT_ID = http:GenerateGUID(false)

-- ===================== Logging / crash detection =====================
-- INFO/WARN/ERROR always print. DEBUG only prints when verbose logging is on.
-- `currentPhase` is the last code region we entered; if the farm thread dies
-- or hangs, the watchdog + crash handler report which phase it was in.
local LOG_VERBOSE = false
local currentPhase = "boot"
local bootClock = os.clock()

local function logLine(level, msg)
	return string.format(
		"[FabrikFarm][%s][%6.2fs][%s] %s",
		level,
		os.clock() - bootClock,
		currentPhase,
		tostring(msg)
	)
end

local function logInfo(msg) print(logLine("INFO", msg)) end
local function logWarn(msg) warn(logLine("WARN", msg)) end
local function logError(msg) warn(logLine("ERROR", msg)) end
local function logDebug(msg)
	if LOG_VERBOSE then
		print(logLine("DEBUG", msg))
	end
end

local function setPhase(phase)
	currentPhase = phase
	G.__FabrikFarmPhase = phase
	if LOG_VERBOSE then
		print(logLine("DEBUG", "→ phase"))
	end
end

-- Run a critical/startup step with timing + crash capture so a failure
-- pinpoints exactly which step died instead of silently aborting.
local function runStep(label, fn)
	setPhase(label)
	local startT = os.clock()
	logDebug("step start")
	local ok, errOrResult = pcall(fn)
	if ok then
		logDebug(string.format("step done (%.3fs)", os.clock() - startT))
	else
		logError(string.format("step FAILED after %.3fs: %s", os.clock() - startT, tostring(errOrResult)))
	end
	return ok, errOrResult
end

local function forEachGuiRoot(fn)
	fn(game:GetService("CoreGui"))
	local lp = plrs.LocalPlayer
	if lp then
		local pg = lp:FindFirstChild("PlayerGui")
		if pg then fn(pg) end
	end
	local ok, hui = pcall(function() return gethui() end)
	if ok and hui then fn(hui) end
end

local function destroyNamedGui(name)
	forEachGuiRoot(function(root)
		local g = root:FindFirstChild(name)
		if g then g:Destroy() end
	end)
end

local function destroyLegacyGui()
	destroyNamedGui(LEGACY_GUI)
	destroyNamedGui(HISTORY_GUI)
end

local function stopSessionThreads(session)
	if not session then return end
	local threads = session.threads
	if threads then
		for _, th in threads do
			pcall(task.cancel, th)
		end
		table.clear(threads)
	end
	local connections = session.connections
	if connections then
		for _, conn in connections do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(connections)
	end
end

local function shutdown(notify)
	local s = Session or G.__FabrikFarmSession
	local wasActive = s and s.alive
	if s then
		s.alive = false
		stopSessionThreads(s)
	end
	if G.__FabrikFarmUI then
		pcall(function() G.__FabrikFarmUI:Destroy() end)
		G.__FabrikFarmUI = nil
	end
	destroyLegacyGui()
	setPhase("unloaded")
	if notify ~= false and wasActive then
		logInfo("Unloaded — farm loops stopped, UI removed")
	end
end

local function isAlive()
	return Session and Session.alive and Session.injectId == INJECT_ID
end

local function track(conn)
	if conn and Session then
		table.insert(Session.connections, conn)
	end
	return conn
end

-- Kill previous injection before starting a new one
setPhase("killPrevious")
logInfo("starting injection " .. INJECT_ID)
if G.__FabrikFarmSession then
	logInfo("found previous session — stopping it")
	G.__FabrikFarmSession.alive = false
	stopSessionThreads(G.__FabrikFarmSession)
end
if G.__FabrikFarmUI then
	pcall(function() G.__FabrikFarmUI:Destroy() end)
	G.__FabrikFarmUI = nil
end
destroyLegacyGui()

setPhase("createSession")
Session = { alive = true, connections = {}, threads = {}, injectId = INJECT_ID }
G.__FabrikFarmSession = Session

-- ===================== Farm logic =====================
local EXPECTED_PLACE = 15197136141
local UPGRADE_IDS = { "OreLimit", "OreValue", "DropperSpeed", "ConveyorSpeed", "WalkSpeed", "ShinyOresChance" }

-- Automation toggles default OFF; user opts in via the UI.
-- Smart* are baked in (always on) — they're strictly better, so no UI clutter.
local Config = {
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
}

G.__FabrikFarmConfig = Config

local LP = plrs.LocalPlayer
local RS = game:GetService("ReplicatedStorage")

setPhase("waitEvents")
local Events = RS:WaitForChild("Events", 15)
if not Events then
	logError("Events folder missing — wrong game? aborting")
	shutdown(false)
	return
end
logDebug("Events folder resolved")

setPhase("requireOther")
local otherOk, Other = pcall(require, RS.Scripts.Other)
if not otherOk or not Other then
	logError("require(Scripts.Other) failed — aborting: " .. tostring(Other))
	shutdown(false)
	return
end

local formatGameValue = Other.format_value
if type(formatGameValue) ~= "function" then
	logWarn("Other.format_value missing — using plain number formatting")
	formatGameValue = function(n)
		return tostring(math.floor((n or 0) + 0.5))
	end
end

local getUpgradeData = Other.GetDataBasedOnUpgrade
if type(getUpgradeData) ~= "function" then
	logWarn("Other.GetDataBasedOnUpgrade missing — gem upgrades disabled")
	getUpgradeData = function()
		return {
			isMaxReached = true,
			nextUpgrade_Price = 0,
			nextUpgrade_ValueBoost = 0,
			currentUpgrade_ValueBoost = 0,
		}
	end
end

setPhase("resolveRemotes")
local CollectMoney = Events:WaitForChild("CollectMoney")
local BuyUpgrade = Events:WaitForChild("BuyUpgrade")
local RequestRebirth = Events:WaitForChild("RequestRebirth")
logDebug("remotes resolved: CollectMoney / BuyUpgrade / RequestRebirth")

setPhase("requireFindPath")
local findPath
local findPathOk, findPathErr = pcall(function()
	findPath = require(LP:WaitForChild("PlayerGui"):WaitForChild("MainUI"):WaitForChild("MainClient"):WaitForChild("Rebirth"):WaitForChild("findPath"))
end)
if not findPathOk then
	logWarn("findPath require failed: " .. tostring(findPathErr))
end

local stats = { collects = 0, buttons = 0, upgrades = 0, rebirths = 0, manualDrops = 0, lastMsg = "", errors = 0, cycles = 0 }
G.__FabrikFarmStats = stats

local lastRebirthAt = 0
local lastManualDropAt = 0
local lastAdCleanAt = 0
local lastCycleAt = 0
local startupReady = false
local adHideBusy = false
local adHidePending = false
local adHideDebounceThread
local adCleanerConnections = {}
local AD_HIDE_MIN_INTERVAL = 3
local AD_HIDE_YIELD_EVERY = 20
local rebirthBusyUntil = 0
local rebirthCache = { bought = 0, needed = 0, canRebirth = false }
local statusLabel
local progressLabel
local lastProgressAt = 0
local loopAcc = 0
local incomePerSec = 0
local incomeSampleAt = 0
local incomeSampleTotal = 0
local gameCashLabel
local gameCashHooked = false

local function syncConfigFromFlags()
	LOG_VERBOSE = Config.VerboseLogging
end

local function tableCount(t)
	if not t then return 0 end
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function getClientValues()
	local pg = LP:FindFirstChild("PlayerGui")
	local nr = pg and pg:FindFirstChild("NoResetScripts")
	return nr and nr:FindFirstChild("ClientValues")
end

local function getTycoon()
	local ref = LP:FindFirstChild("TycoonOwned")
	return ref and ref.Value
end

local function getMoney()
	local ls = LP:FindFirstChild("leaderstats")
	local m = ls and ls:FindFirstChild("Money")
	return m and m.Value or 0
end

local function getDataFolderToCollect()
	local df = LP:FindFirstChild("DataFolder")
	local tc = df and df:FindFirstChild("ToCollect")
	return tc and tc.Value or 0
end

local function getClientToCollect()
	local cv = getClientValues()
	local tc = cv and cv:FindFirstChild("ToCollect")
	return tc and tc.Value or 0
end

local function getToCollect()
	return math.max(getDataFolderToCollect(), getClientToCollect())
end

local function getWealthTotal()
	return getMoney() + getToCollect()
end

-- Smoothed $/s from wallet + collector pool growth (handles auto-collect spikes).
local function sampleIncomeRate()
	local now = os.clock()
	local total = getWealthTotal()
	if incomeSampleAt > 0 then
		local dt = now - incomeSampleAt
		if dt >= 0.75 then
			local rate = (total - incomeSampleTotal) / dt
			if incomePerSec <= 0 then
				incomePerSec = math.max(0, rate)
			else
				incomePerSec = incomePerSec * 0.65 + math.max(0, rate) * 0.35
			end
			incomeSampleAt = now
			incomeSampleTotal = total
		end
	else
		incomeSampleAt = now
		incomeSampleTotal = total
	end
end

local function fmtGameMoney(n)
	n = math.floor((n or 0) + 0.5)
	return "$" .. formatGameValue(n)
end

local function fmtIncomeRate(n)
	n = math.floor((n or 0) + 0.5)
	if n <= 0 then return "($0/s)" end
	return "(" .. fmtGameMoney(n) .. "/s)"
end

local function getGameCashLabel()
	if gameCashLabel and gameCashLabel.Parent then return gameCashLabel end
	local pg = LP:FindFirstChild("PlayerGui")
	local hud = pg and pg:FindFirstChild("MainUI") and pg.MainUI:FindFirstChild("HUD")
	local cash = hud
		and hud:FindFirstChild("LeftSidebar")
		and hud.LeftSidebar:FindFirstChild("Currency")
		and hud.LeftSidebar.Currency:FindFirstChild("Cash")
	gameCashLabel = cash and cash:FindFirstChild("Amount")
	return gameCashLabel
end

local function updateGameCashDisplay()
	local label = getGameCashLabel()
	if not label then return end
	label.Text = fmtGameMoney(getMoney()) .. " " .. fmtIncomeRate(incomePerSec)
end

local function hookGameCashDisplay()
	if gameCashHooked then return end
	local label = getGameCashLabel()
	if not label then return end
	gameCashHooked = true
	local ls = LP:FindFirstChild("leaderstats")
	local money = ls and ls:FindFirstChild("Money")
	if money then
		track(money:GetPropertyChangedSignal("Value"):Connect(function()
			task.defer(updateGameCashDisplay)
		end))
	end
	local cv = getClientValues()
	local pool = cv and cv:FindFirstChild("ToCollect")
	if pool then
		track(pool:GetPropertyChangedSignal("Value"):Connect(function()
			sampleIncomeRate()
			updateGameCashDisplay()
		end))
	end
	updateGameCashDisplay()
end

-- Terraria / MC-style feed: every farm action stacks on the right with rainbow text.
-- Scoped in an IIFE so main chunk stays under Luau's 200 local register cap.
local pushFarmHistory, recordPurchaseHistory, startPurchaseHistoryJanitor
;(function()
local HISTORY_MAX = 8
local HISTORY_LIFE = 4.2
local HISTORY_FADE_IN = 0.22
local HISTORY_FADE_OUT = 0.3
local HISTORY_SLIDE = 0.24
local HISTORY_TEXT_SIZE = 22
local HISTORY_ROW = 36
local HISTORY_GAP = 5
local HISTORY_WIDTH = 440
local HISTORY_PAD_RIGHT = 18
local HISTORY_HUE_STEP = 0.06
local HISTORY_FILL_HUE_SPAN = 0.045
local HISTORY_FILL_STOPS = 6
local HISTORY_STROKE_THICKNESS = 3.5
local historyGui
local historyStack
local historyEntries = {}
local historyRainbowCounter = 0
local gameUiTextRef

-- Wipe stuck feed rows from a prior inject (GUI may live under gethui, not PlayerGui).
local function resetPurchaseHistoryFeed()
	destroyNamedGui(HISTORY_GUI)
	if historyGui and historyGui.Parent then
		pcall(function() historyGui:Destroy() end)
	end
	historyGui = nil
	historyStack = nil
	for i = #historyEntries, 1, -1 do
		local entry = historyEntries[i]
		if entry.label and entry.label.Parent then
			pcall(function() entry.label:Destroy() end)
		end
		table.remove(historyEntries, i)
	end
	historyRainbowCounter = 0
end

resetPurchaseHistoryFeed()

local function historyRowStep()
	return HISTORY_ROW + HISTORY_GAP
end

local function getGameUiTextRef()
	if gameUiTextRef and gameUiTextRef.Parent then return gameUiTextRef end
	gameUiTextRef = getGameCashLabel()
	return gameUiTextRef
end

local function cloneColorSequence(seq)
	local keypoints = {}
	for _, kp in seq.Keypoints do
		keypoints[#keypoints + 1] = ColorSequenceKeypoint.new(kp.Time, kp.Value)
	end
	return ColorSequence.new(keypoints)
end

local function cloneNumberSequence(seq)
	local keypoints = {}
	for _, kp in seq.Keypoints do
		keypoints[#keypoints + 1] = NumberSequenceKeypoint.new(kp.Time, kp.Value, kp.Envelope)
	end
	return NumberSequence.new(keypoints)
end

local function cloneUIGradient(source, parent)
	local grad = Instance.new("UIGradient")
	grad.Color = cloneColorSequence(source.Color)
	grad.Transparency = cloneNumberSequence(source.Transparency)
	grad.Rotation = source.Rotation
	grad.Enabled = source.Enabled
	grad.Parent = parent
	return grad
end

-- Walk hue backward from red through magenta into purple, then the rest of the wheel.
local function historyBaseHue(rainbowIndex)
	return (1 - rainbowIndex * HISTORY_HUE_STEP) % 1
end

local function rainbowColor(hue, sat, val)
	return Color3.fromHSV(hue % 1, math.clamp(sat, 0, 1), math.clamp(val, 0, 1))
end

local function makeRainbowFillGradient(baseHue)
	local keypoints = {}
	local stops = math.max(2, HISTORY_FILL_STOPS)
	for i = 0, stops - 1 do
		local t = i / (stops - 1)
		local h = (baseHue + t * HISTORY_FILL_HUE_SPAN) % 1
		local sat = 0.92 - t * 0.08
		local val = 1 - t * 0.14
		keypoints[#keypoints + 1] = ColorSequenceKeypoint.new(t, rainbowColor(h, sat, val))
	end
	return ColorSequence.new(keypoints)
end

local function makeRainbowStrokeGradient(baseHue)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, rainbowColor(baseHue + 0.02, 0.85, 0.28)),
		ColorSequenceKeypoint.new(1, rainbowColor(baseHue + HISTORY_FILL_HUE_SPAN, 0.9, 0.14)),
	})
end

-- Match game font (FredokaOne) but rainbow fill + thin dark-rainbow stroke.
local function applyRainbowHistoryStyle(label, rainbowIndex)
	local ref = getGameUiTextRef()
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 1
	label.RichText = false
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextYAlignment = Enum.TextYAlignment.Center

	if ref then
		label.FontFace = ref.FontFace
	else
		label.Font = Enum.Font.FredokaOne
	end
	label.TextSize = HISTORY_TEXT_SIZE

	local baseHue = historyBaseHue(rainbowIndex)
	local fillGrad = Instance.new("UIGradient")
	fillGrad.Rotation = 90
	fillGrad.Color = makeRainbowFillGradient(baseHue)
	fillGrad.Parent = label

	local refStroke = ref and ref:FindFirstChildOfClass("UIStroke")
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = refStroke and refStroke.ApplyStrokeMode or Enum.ApplyStrokeMode.Contextual
	stroke.LineJoinMode = refStroke and refStroke.LineJoinMode or Enum.LineJoinMode.Round
	stroke.Transparency = 0
	stroke.Thickness = HISTORY_STROKE_THICKNESS
	stroke.Parent = label

	local strokeGrad = Instance.new("UIGradient")
	strokeGrad.Rotation = 90
	strokeGrad.Color = makeRainbowStrokeGradient(baseHue)
	strokeGrad.Parent = stroke
end

-- Match MainUI HUD Cash.Amount: FredokaOne, white fill + vertical green gradient,
-- UIStroke outline with its own dark-green gradient (same as in-game $ display).
local function applyGameCurrencyStyle(label, textSize)
	local ref = getGameUiTextRef()
	local size = textSize or (ref and ref.TextSize) or 14
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 1
	label.RichText = ref and ref.RichText or false
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextYAlignment = Enum.TextYAlignment.Center

	if ref then
		label.FontFace = ref.FontFace
	else
		label.Font = Enum.Font.FredokaOne
	end
	label.TextSize = size

	local scale = size / math.max(1, ref and ref.TextSize or size)
	local refFill = ref and ref:FindFirstChildOfClass("UIGradient")
	if refFill then
		cloneUIGradient(refFill, label)
	end

	local refStroke = ref and ref:FindFirstChildOfClass("UIStroke")
	if refStroke then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = refStroke.ApplyStrokeMode
		stroke.LineJoinMode = refStroke.LineJoinMode
		stroke.Color = refStroke.Color
		stroke.Transparency = refStroke.Transparency
		stroke.Thickness = refStroke.Thickness * scale
		stroke.Parent = label
		local refStrokeGrad = refStroke:FindFirstChildOfClass("UIGradient")
		if refStrokeGrad then
			cloneUIGradient(refStrokeGrad, stroke)
		end
	end
end

local function applyGameUiLabelStyle(label, rainbowIndex)
	applyRainbowHistoryStyle(label, rainbowIndex or 0)
end

local function fadeHistoryLabel(label, textTransparency, strokeTransparency, duration)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { TextTransparency = textTransparency }):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, info, { Transparency = strokeTransparency }):Play()
	end
end

local function getHistoryParent()
	local ok, hui = pcall(function() return gethui() end)
	if ok and hui then return hui end
	return LP:WaitForChild("PlayerGui")
end

local function ensurePurchaseHistoryGui()
	if historyGui and historyGui.Parent and historyStack and historyStack.Parent then
		return historyStack
	end
	historyGui = nil
	historyStack = nil
	local gui = Instance.new("ScreenGui")
	gui.Name = HISTORY_GUI
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = getHistoryParent()

	local stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.BackgroundTransparency = 1
	stack.ClipsDescendants = false
	stack.Size = UDim2.fromOffset(HISTORY_WIDTH, HISTORY_MAX * historyRowStep())
	stack.AnchorPoint = Vector2.new(1, 1)
	stack.Position = UDim2.new(1, -8, 0.58, 0)
	stack.Parent = gui

	historyGui = gui
	historyStack = stack
	return stack
end

local HISTORY_BOTTOM_ROW = HISTORY_MAX - 1

local function historyY(row)
	return row * historyRowStep()
end

local function historyRowPos(row)
	-- Inset from the stack's right edge so thick UIStroke isn't clipped.
	return UDim2.new(1, -HISTORY_PAD_RIGHT, 0, historyY(row))
end

local function tweenHistoryLabel(label, targetPos, duration)
	TweenService:Create(
		label,
		TweenInfo.new(duration or HISTORY_SLIDE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = targetPos }
	):Play()
end

local function fadeOutHistoryEntry(entry, immediate, onDone)
	if entry.removing then return end
	entry.removing = true
	local label = entry.label
	if not label or not label.Parent then
		if onDone then onDone() end
		return
	end
	local duration = immediate and 0.08 or HISTORY_FADE_OUT
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeTween = TweenService:Create(label, info, { TextTransparency = 1 })
	fadeTween:Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end
	fadeTween.Completed:Connect(function()
		if label.Parent then label:Destroy() end
		if onDone then onDone() end
	end)
end

-- Reassign rows so oldest sits highest and newest hugs the bottom slot.
local function syncHistoryRows(animate, skipEntry)
	local count = #historyEntries
	for j, entry in ipairs(historyEntries) do
		if entry ~= skipEntry and not entry.removing then
			local label = entry.label
			if label and label.Parent then
				local targetRow = HISTORY_BOTTOM_ROW - (count - j)
				entry.row = targetRow
				if animate then
					tweenHistoryLabel(label, historyRowPos(targetRow), HISTORY_SLIDE)
				else
					label.Position = historyRowPos(targetRow)
				end
			end
		end
	end
end

-- Before inserting: slide every visible row up one slot; drop anything pushed off the top.
local function shiftHistoryUp(animate)
	local removeIdx = {}
	for i, entry in ipairs(historyEntries) do
		if not entry.removing then
			local label = entry.label
			if label and label.Parent then
				local fromRow = entry.row
				if fromRow == nil then
					fromRow = HISTORY_BOTTOM_ROW - (#historyEntries - i)
					entry.row = fromRow
				end
				local targetRow = fromRow - 1
				entry.row = targetRow
				if targetRow < 0 then
					removeIdx[#removeIdx + 1] = i
					fadeOutHistoryEntry(entry, false)
				elseif animate then
					tweenHistoryLabel(label, historyRowPos(targetRow), HISTORY_SLIDE)
				else
					label.Position = historyRowPos(targetRow)
				end
			end
		end
	end
	for ri = #removeIdx, 1, -1 do
		table.remove(historyEntries, removeIdx[ri])
	end
end

local function trimHistoryOverflow()
	while #historyEntries > HISTORY_MAX do
		local oldest = table.remove(historyEntries, 1)
		if oldest then fadeOutHistoryEntry(oldest, true) end
	end
end
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

pushFarmHistory = function(text)
	if not text or text == "" then return end
	ensurePurchaseHistoryGui()

	local label = Instance.new("TextLabel")
	label.Name = "Entry"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(1, 0)
	label.Size = UDim2.fromOffset(HISTORY_WIDTH - HISTORY_PAD_RIGHT, HISTORY_ROW)
	label.TextTransparency = 1
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextWrapped = false
	label.Text = text
	local rainbowIndex = historyRainbowCounter
	historyRainbowCounter += 1
	applyGameUiLabelStyle(label, rainbowIndex)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Transparency = 1 end

	if #historyEntries > 0 then
		shiftHistoryUp(true)
	end

	local bottomY = historyY(HISTORY_BOTTOM_ROW)
	label.Position = UDim2.new(1, 36, 0, bottomY + 12)
	label.Parent = historyStack

	local entry = {
		label = label,
		at = os.clock(),
		removing = false,
		row = HISTORY_BOTTOM_ROW,
		rainbowIndex = rainbowIndex,
	}
	table.insert(historyEntries, entry)
	trimHistoryOverflow()

	tweenHistoryLabel(label, historyRowPos(HISTORY_BOTTOM_ROW), HISTORY_FADE_IN)
	fadeHistoryLabel(label, 0, 0, HISTORY_FADE_IN)
end

recordPurchaseHistory = function(btnModel)
	if btnModel then
		pushFarmHistory(purchaseHistoryLine(btnModel))
	end
end

startPurchaseHistoryJanitor = function()
	resetPurchaseHistoryFeed()
	track(rs.Heartbeat:Connect(function()
		if #historyEntries == 0 then return end
		local now = os.clock()
		local needsSync = false
		for i = #historyEntries, 1, -1 do
			local entry = historyEntries[i]
			if not entry.removing and now - entry.at >= HISTORY_LIFE then
				fadeOutHistoryEntry(entry, false)
				table.remove(historyEntries, i)
				needsSync = true
			elseif entry.removing and (not entry.label or not entry.label.Parent) then
				table.remove(historyEntries, i)
				needsSync = true
			end
		end
		if needsSync then
			syncHistoryRows(true)
		end
	end))
end
end)()

local function getGems()
	local df = LP:FindFirstChild("DataFolder")
	local g = df and df:FindFirstChild("Gems")
	return g and g.Value or 0
end

local function getRebirths()
	local df = LP:FindFirstChild("DataFolder")
	local r = df and df:FindFirstChild("Rebirths")
	if r then return r.Value end
	local ls = LP:FindFirstChild("leaderstats")
	r = ls and ls:FindFirstChild("Rebirths")
	return r and r.Value or 0
end

local function isMoneyButton(btn)
	return btn:FindFirstChild("Price")
		and not btn:FindFirstChild("RebirthPrice")
		and not btn:FindFirstChild("GamepassPrice")
		and not btn:FindFirstChild("GroupID")
		and not btn:FindFirstChild("IsAnAfterGamepass")
end

local function isRebirthAreaButton(btn)
	return btn:FindFirstChild("RebirthPrice")
		and not btn:FindFirstChild("GamepassPrice")
		and not btn:FindFirstChild("GroupID")
		and not btn:FindFirstChild("IsAnAfterGamepass")
end

local function getBuyableRebirthAreaButtons()
	local tycoon = getTycoon()
	if not tycoon or not tycoon:FindFirstChild("Buttons") then return {} end
	local rebirths = getRebirths()
	local list = {}
	for _, btn in tycoon.Buttons:GetChildren() do
		if btn:FindFirstChild("IsButtonVisible")
			and btn.IsButtonVisible.Value
			and btn:FindFirstChild("Bought")
			and not btn.Bought.Value
			and isRebirthAreaButton(btn)
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
		if a.rebirthPrice == b.rebirthPrice then return a.name < b.name end
		return a.rebirthPrice < b.rebirthPrice
	end)
	return list
end

local function getBuyableButtons()
	local tycoon = getTycoon()
	if not tycoon or not tycoon:FindFirstChild("Buttons") then return {} end
	local list = {}
	for _, btn in tycoon.Buttons:GetChildren() do
		if btn:FindFirstChild("IsButtonVisible")
			and btn.IsButtonVisible.Value
			and btn:FindFirstChild("Bought")
			and not btn.Bought.Value
			and isMoneyButton(btn)
			and btn:FindFirstChild("Button")
		then
			local priceObj = btn:FindFirstChild("Price")
			if priceObj then
				table.insert(list, { model = btn, name = btn.Name, price = priceObj.Value })
			end
		end
	end
	table.sort(list, function(a, b)
		if a.price == b.price then return a.name < b.name end
		return a.price < b.price
	end)
	return list
end

-- Income model (verified in DroppersAndUpgraders / UpgraderFunctions): droppers
-- spawn ore worth their model's `oreValue`; upgraders (Coin Press, Washer, Heater,
-- Cleanser, ...) carry an `Upg` value and ADD it to every ore that passes over them
-- (`block.Value += Up.Upg.Value`). Both numbers are direct per-ore income, so a pad
-- carrying either grows income and beats infrastructure, which beats cosmetics.
local tryCollect, tryCollectForProgress, touchBuy, tryBuyRebirthAreaButton, tryBuyCheapestButton
local tryGemUpgrade, tryGemUpgrades, pressManualDropper
local hideMonetizationAds, setAdHidingEnabled, startAdCleaner
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
				"bought %s (%s) → goal %s",
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

-- What the farm is doing this cycle (for Progress tab — matches tryBuyCheapestButton).
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
				"progress %s (%s) → goal %s",
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

	-- Only cosmetics remain — buy the cheapest affordable one so progression
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
-- billboard's child GuiObjects (which ShowAndHide never touches — it only flips
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
	elseif LOG_VERBOSE then
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
		logInfo("ad hiding ON — scheduling clean pass")
		bindAdCleanerListeners()
		task.spawn(hideMonetizationAdsNow)
	else
		logInfo("ad hiding OFF — listeners disconnected")
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
	return string.format("Built %d / %d pads  ·  %d income pads built", bought, total, incomeBuilt)
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
		lines[#lines + 1] = "No buyable pads right now — rebirth or a gated"
		lines[#lines + 1] = "unlock may be blocking the next area."
		return table.concat(lines, "\n")
	end
	if intent.mode == "cosmetics" then
		lines[#lines + 1] = "Only decor pads left — buying those to unblock chains."
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
		lines[#lines + 1] = "  Close to goal — not buying cheaper pads anymore."
	else
		lines[#lines + 1] = "End goal:  " .. target.name
		lines[#lines + 1] = string.format(
			"  %s of %s  (%d%% toward goal)",
			fmtGameMoney(money), fmtGameMoney(target.price), pct
		)
		if intent.nextPad and intent.nextPad.name ~= target.name then
			lines[#lines + 1] = string.format(
				"  Next step: %s (%s) — need %s more",
				intent.nextPad.name,
				fmtGameMoney(intent.nextPad.price),
				fmtGameMoney(intent.nextShortfall)
			)
			if intent.pool and intent.pool > 0 then
				local combined = money + intent.pool
				if combined >= intent.nextPad.price then
					lines[#lines + 1] = string.format(
						"  Pool %s — collect to afford next pad",
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
			"  → %s  (%s%s)",
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
		"%s %s · pool %s (df %s) · gems %d · R%d · reb %d/%d",
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

local function updateStatusLabel()
	sampleIncomeRate()
	updateGameCashDisplay()
	if statusLabel and statusLabel.Set then
		pcall(function() statusLabel:Set(statusLine()) end)
	end
	updateProgressLabel(false)
end

local function farmOnce()
	if not isAlive() then return end
	setPhase("sync")
	syncConfigFromFlags()
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
		hideMonetizationAds()
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
		stats.lastMsg = string.format("cycle err @%s: %s", currentPhase, tostring(err))
		logError(string.format("CRASH in farm cycle during phase '%s': %s", currentPhase, tostring(err)))
	else
		local elapsed = lastCycleAt - startT
		if elapsed > 1 then
			logWarn(string.format("slow cycle %.2fs (last phase '%s')", elapsed, currentPhase))
		end
		logDebug(string.format("cycle #%d ok (%.3fs)", stats.cycles, elapsed))
	end
end

-- ===================== DexUI =====================
-- Nested function: main chunk was over Luau's 200 local register limit.
local function buildDexUI()
	local function unloadScript()
		Config.Enabled = false
		shutdown(true)
		Session = nil
		G.__FabrikFarmSession = nil
		G.__FabrikFarmInjectId = nil
		G.__FabrikFarmConfig = nil
		G.__FabrikFarmStats = nil
	end

	local ui = DexUI.CreateWindow("Fabrik-Tycoon Farm")
	G.__FabrikFarmUI = ui

	ui:AddTab("Farm", 4483362458)
	ui:AddSection("Auto farm")
	ui:AddSwitch("Master auto farm", Config.Enabled, function(v)
		Config.Enabled = v
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

	ui:AddSection("Live status")
	local statusWidget = ui:AddLabel(statusLine())
	statusLabel = {
		Set = function(_, text)
			statusWidget.SetText(text)
		end,
	}

	ui:AddTab("Progress", 4483362458)
	ui:AddSection("Live progression")
	local progressWidget = ui:AddLabel(progressionContent())
	progressLabel = {
		Set = function(_, opts)
			if type(opts) == "table" then
				progressWidget.SetText(opts.Content or progressionContent())
			else
				progressWidget.SetText(tostring(opts))
			end
		end,
	}
	ui:AddButton("Refresh now", function()
		updateProgressLabel(true)
	end)

	ui:AddTab("Settings", 4483362458)
	ui:AddSection("Tuning")
	ui:AddSlider("Loop speed (s)", 0.15, 2, Config.LoopDelay, function(v)
		Config.LoopDelay = v
	end)
	ui:AddSlider("Rebirth check interval (s)", 3, 30, Config.RebirthInterval, function(v)
		Config.RebirthInterval = v
	end)

	ui:AddSection("Extras")
	ui:AddSwitch("Hide Robux / gamepass ads", Config.HideMonetization, function(v)
		setAdHidingEnabled(v)
	end)
	ui:AddSwitch("Verbose logging", Config.VerboseLogging, function(v)
		Config.VerboseLogging = v
		LOG_VERBOSE = v
		logInfo("verbose logging " .. (v and "ON" or "OFF"))
	end)

	ui:AddSection("Tools")
	ui:AddButton("Collect now", function()
		tryCollect(true)
		updateStatusLabel()
	end)
	ui:AddButton("Buy next building", function()
		tryBuyCheapestButton()
		updateStatusLabel()
	end)
	ui:AddButton("Rebirth now", function()
		tryRebirth()
		updateStatusLabel()
	end)
	ui:AddButton("Print diagnostics", function()
		logInfo(string.format(
			"DIAG | phase:%s | alive:%s | cycles:%d errors:%d | last cycle %.1fs ago | %s",
			currentPhase,
			tostring(isAlive()),
			stats.cycles,
			stats.errors,
			lastCycleAt > 0 and (os.clock() - lastCycleAt) or -1,
			statusLine()
		))
		logInfo(string.format(
			"DIAG counts | buttons:%d drops:%d gems:%d collects:%d rebirths:%d | lastMsg: %s",
			stats.buttons,
			stats.manualDrops,
			stats.upgrades,
			stats.collects,
			stats.rebirths,
			stats.lastMsg ~= "" and stats.lastMsg or "—"
		))
	end)

	ui:AddSection("Danger")
	ui:AddButton("Quit — stop farm & unload", unloadScript)

	ui:Show()
end

runStep("buildDexUI", buildDexUI)
runStep("initSyncConfig", syncConfigFromFlags)
runStep("initRebirthProgress", computeRebirthProgress)
runStep("initStatus", updateStatusLabel)
runStep("hookGameCash", hookGameCashDisplay)
runStep("initPurchaseHistory", startPurchaseHistoryJanitor)
task.spawn(function()
	for _ = 1, 20 do
		if gameCashHooked then break end
		hookGameCashDisplay()
		task.wait(1)
	end
end)

startupReady = true
logInfo("startup complete — ad hiding gated behind toggle")

runStep("startAdCleaner", startAdCleaner)

-- Consume ReplicatedStorage.Events.ServerError. The game broadcasts every
-- server-side error to ALL clients; with no OnClientEvent handler, Roblox spams
-- "Remote event invocation queue exhausted" warnings (doubling 1,2,4,…). We
-- drain it here and only surface it under verbose logging.
runStep("consumeServerError", function()
	local serverErr = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("ServerError")
	if serverErr and serverErr:IsA("RemoteEvent") then
		track(serverErr.OnClientEvent:Connect(function(msg)
			if LOG_VERBOSE then
				logDebug("ServerError: " .. tostring(msg))
			end
		end))
	end
end)

if game.PlaceId ~= EXPECTED_PLACE then
	logWarn(string.format("PlaceId %s != %s — remotes may differ", game.PlaceId, EXPECTED_PLACE))
end

if not findPath then
	logWarn("Rebirth findPath unavailable — auto rebirth progress may be wrong")
end

setPhase("ready")
logInfo("Loaded (DexUI) — all toggles default OFF | " .. statusLine())

logInfo("starting Heartbeat farm loop")
track(rs.Heartbeat:Connect(function(dt)
	if not isAlive() then return end
	loopAcc += dt
	if loopAcc < Config.LoopDelay then return end
	loopAcc = 0
	safeFarmOnce()
end))

-- Watchdog: periodic status + stall/crash detection. Does NOT call setPhase
-- (it runs in parallel) so it can faithfully report the farm thread's phase.
task.spawn(function()
	logInfo("watchdog started")
	while isAlive() do
		task.wait(4)
		if not isAlive() then break end
		syncConfigFromFlags()
		updateStatusLabel()
		if Config.Enabled and lastCycleAt > 0 and os.clock() - lastCycleAt > 5 then
			logWarn(string.format(
				"farm loop STALLED — no cycle for %.1fs (stuck in phase '%s')",
				os.clock() - lastCycleAt,
				currentPhase
			))
		end
		print(string.format(
			"[FabrikFarm] %s | btn:%d drop:%d gem:%d col:%d reb:%d err:%d | %.2fs | phase:%s | %s",
			statusLine(),
			stats.buttons,
			stats.manualDrops,
			stats.upgrades,
			stats.collects,
			stats.rebirths,
			stats.errors,
			Config.LoopDelay,
			currentPhase,
			stats.lastMsg ~= "" and stats.lastMsg or "—"
		))
	end
	logInfo("watchdog ended (session inactive)")
end)
