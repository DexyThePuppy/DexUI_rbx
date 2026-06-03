--[[
  [UPD] Fabrik-Tycoon — DexUI auto farmer
  Place: 15197136141

  scripts/sdk/                    Universal session, loops, DexUI helpers
  scripts/fabrik/                   Shared Fabrik helpers (format, tycoon API, Other module)
  scripts/games/fabrik-tycoon/      This game's modules (game, farm, ads, ui)
  scripts/fabrik-tycoon.lua         Hub entry: manifest + SDK + startup / loop wiring
]]

local DexUI = (getgenv and getgenv().DexUI) or nil
if not DexUI then
	error("[fabrik-tycoon] DexUI not found. Launch from the DexUI scripts hub.")
end

if not (readfile and isfile and loadstring) then
	error("[fabrik-tycoon] Executor must support readfile / isfile / loadstring.")
end

local SDK_PREFIXES = { "scripts/sdk/", "DexUI/scripts/sdk/" }
local MODULE_PREFIXES = {
	"scripts/games/fabrik-tycoon/",
	"DexUI/scripts/games/fabrik-tycoon/",
}

local function loadFrom(prefixes: { string }, name: string)
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

local function loadModule(name: string, ctx)
	local init = loadFrom(MODULE_PREFIXES, name)
	if type(init) == "function" then
		init(ctx)
	end
end

local manifest = {
	id = "fabrik-tycoon",
	name = "Fabrik Farm",
	windowTitle = "Fabrik-Tycoon Farm",
	logTag = "FabrikFarm",
	placeId = 15197136141,
	placeIds = { 15197136141 },

	prefixes = MODULE_PREFIXES,

	pipeline = { "game", "farm", "ads" },
	abortAfter = { "game" },

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
		message = "Unloaded — farm stopped",
		logMessage = "Unloaded — farm loops stopped, UI removed",
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
		collects = 0,
		buttons = 0,
		upgrades = 0,
		rebirths = 0,
		manualDrops = 0,
		lastMsg = "",
		errors = 0,
		cycles = 0,
	},

	timers = {
		lastRebirthAt = 0,
		lastManualDropAt = 0,
		lastAdCleanAt = 0,
		lastCycleAt = 0,
		lastProgressAt = 0,
		rebirthBusyUntil = 0,
		loopAcc = 0,
		incomeSampleAt = 0,
		incomeSampleTotal = 0,
	},

	caches = {
		rebirth = { bought = 0, needed = 0, canRebirth = false },
	},

	widgets = {
		status = nil,
		progress = nil,
		stats = nil,
	},

	game = {
		incomePerSec = 0,
		gameCashLabel = nil,
		gameCashHooked = false,
	},
}

local SDK = loadFrom(SDK_PREFIXES, "run")
local ctx = SDK(manifest, DexUI)
if not ctx.isAlive() then
	return
end

loadModule("ui", ctx)

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
