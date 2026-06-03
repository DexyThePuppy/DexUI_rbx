--[[
  Template hub entry — copy to scripts/<your-game>.lua

  SDK layout:
    scripts/sdk/entry.lua     — DexUI + readfile bootstrap
    scripts/sdk/run.lua       — session, helpers, optional pipeline
    scripts/helpers/util.lua  — generic (tableCount, etc.)
    scripts/helpers/<pack>/   — optional domain helpers you declare in manifest
    scripts/games/<id>/       — your game modules (pipeline)
]]

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

local manifest = {
	id = "my-game",
	name = "My Game Script",
	windowTitle = "My Game — DexUI",
	logTag = "MyGame",
	placeId = 0,
	helpers = { "util" },
	prefixes = {
		"scripts/games/my-game/",
		"DexUI/scripts/games/my-game/",
	},
	pipeline = { "game", "ui" },
	abortAfter = { "game" },
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
}

local ctx = loadFile("sdk/entry.lua")(manifest, (getgenv and getgenv().DexUI) or nil)
if not ctx.isAlive() then
	return
end

-- Add runtime / loops here or in scripts/games/my-game/runtime.lua via pipeline.
