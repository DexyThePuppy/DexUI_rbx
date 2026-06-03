--[[
  Template hub entry — copy to scripts/<your-game>.lua

  Uses sdk/bootstrap.lua:
    helpers/     optional shared API (manifest.helperPrefixes + helpers)
    games/<id>/  logic modules (manifest.prefixes + pipeline)
    ui           layout module name (manifest.ui)
    onReady      startup / loops in the hub entry file
]]

local DexUI = (getgenv and getgenv().DexUI) or nil
if not DexUI then
	error("[my-game] DexUI not found — launch from the scripts hub.")
end

if not (readfile and isfile and loadstring) then
	error("[my-game] readfile / isfile / loadstring required.")
end

local PATHS = { "scripts/", "DexUI/scripts/" }

local function loadFile(name)
	for _, prefix in PATHS do
		local path = prefix .. name
		if isfile(path) then
			local chunk, err = loadstring(readfile(path), "@" .. path)
			if not chunk then
				error(tostring(err), 0)
			end
			return chunk()
		end
	end
	error("missing: " .. name, 0)
end

local PART_PREFIXES = {
	"scripts/games/my-game/",
	"DexUI/scripts/games/my-game/",
}

local manifest = {
	id = "my-game",
	name = "My Game Script",
	windowTitle = "My Game — DexUI",
	logTag = "MyGame",
	placeId = 0,
	prefixes = PART_PREFIXES,
	pipeline = { "game" },
	abortAfter = { "game" },
	ui = "ui",
	genv = {
		session = "__MyGameSession",
		ui = "__MyGameUI",
		config = "__MyGameConfig",
		stats = "__MyGameStats",
		phase = "__MyGamePhase",
	},
	config = { Enabled = false, LoopDelay = 0.5, VerboseLogging = false },
	stats = { cycles = 0, errors = 0, lastMsg = "" },
	timers = { lastCycleAt = 0, loopAcc = 0 },
	widgets = {},
	game = {},

	onReady = function(ctx)
		ctx.main = {
			tick = function()
				if not ctx.config.Enabled then
					return
				end
				ctx.stats.cycles += 1
				ctx.stats.lastMsg = "tick " .. ctx.stats.cycles
			end,
			safeTick = function()
				local ok, err = pcall(ctx.main.tick)
				ctx.timers.lastCycleAt = os.clock()
				if not ok then
					ctx.stats.errors += 1
					ctx.stats.lastMsg = tostring(err)
					ctx.log.error(err)
				end
			end,
		}

		ctx.log.setPhase("ready")
		ctx.loop.startHeartbeat({ masterKey = "Enabled", delayKey = "LoopDelay", tick = ctx.main.safeTick })
		ctx.loop.startWatchdog({
			masterKey = "Enabled",
			onTick = function()
				ctx.log.verbose = ctx.config.VerboseLogging
			end,
			logLine = function()
				return string.format("[%s] cycles=%d phase=%s", ctx.logTag, ctx.stats.cycles, ctx.log.phase)
			end,
		})
	end,
}

local bootstrap = loadFile("sdk/bootstrap.lua")
local ctx = bootstrap(manifest, DexUI)
