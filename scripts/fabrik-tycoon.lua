--[[
  [UPD] Fabrik-Tycoon — DexUI auto farmer
  Place: 15197136141

  Hub entry (this file): manifest + SDK bootstrap only.
  scripts/sdk/              Session, loops, helper loader, module pipeline
  scripts/helpers/          Optional packs (util = generic; fabrik/api = tycoon API)
  scripts/games/fabrik-tycoon/  Game modules (init, farm, ads, ui, runtime)
]]

local PATHS = { "scripts/", "DexUI/scripts/" }

local function loadFile(name)
	for _, prefix in PATHS do
		local path = prefix .. name
		if isfile(path) then
			local chunk, err = loadstring(readfile(path), "@" .. path)
			if not chunk then
				error("[fabrik-tycoon] " .. path .. ": " .. tostring(err), 0)
			end
			return chunk()
		end
	end
	error("[fabrik-tycoon] missing " .. name, 0)
end

local manifest = {
	id = "fabrik-tycoon",
	name = "Fabrik Farm",
	windowTitle = "Fabrik-Tycoon Farm",
	logTag = "FabrikFarm",
	placeId = 15197136141,
	placeIds = { 15197136141 },

	helpers = { "util", "fabrik/api" },

	prefixes = {
		"scripts/games/fabrik-tycoon/",
		"DexUI/scripts/games/fabrik-tycoon/",
	},
	pipeline = { "init", "farm", "ads", "ui", "runtime" },
	abortAfter = { "init" },

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

local runEntry = loadFile("sdk/entry.lua")
local ctx = runEntry(manifest, (getgenv and getgenv().DexUI) or nil)
if not ctx.isAlive() then
	return
end
