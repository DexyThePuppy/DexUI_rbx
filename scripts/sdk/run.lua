--[[
  DexUI Script SDK — run any hub game script from a manifest + module pipeline.

  Game folder layout:
    scripts/<entry>.lua               — manifest + SDK.run + UI/loop wiring
    scripts/games/<id>/<module>.lua   — return function(ctx) ... end (logic only)

  See scripts/games/_template/ for a minimal starter.
]]

local SDK_PREFIXES = {
	"scripts/sdk/",
	"DexUI/scripts/sdk/",
}

local function loadFrom(prefixes, name)
	for _, prefix in prefixes do
		local path = prefix .. name .. ".lua"
		if readfile and isfile and isfile(path) then
			local chunk, err = loadstring(readfile(path), "@" .. path)
			if not chunk then
				error("[sdk] " .. tostring(err), 0)
			end
			return chunk()
		end
	end
	error("[sdk] missing: " .. name, 0)
end

local makeLoader = loadFrom(SDK_PREFIXES, "loader")
local createSession = loadFrom(SDK_PREFIXES, "session")
local attachLoop = loadFrom(SDK_PREFIXES, "loop")
local attachDexui = loadFrom(SDK_PREFIXES, "dexui")

return function(manifest, DexUI)
	if type(manifest) == "function" then
		manifest = manifest()
	end
	if type(manifest) ~= "table" then
		error("[sdk] manifest must be a table", 0)
	end

	local modulePrefixes = manifest.prefixes or manifest.modulePrefixes
	if not modulePrefixes then
		error("[sdk] manifest.prefixes required (folders that hold game modules)", 0)
	end

	local loadGame = makeLoader(modulePrefixes)
	local ctx = createSession(manifest, DexUI)
	attachLoop(ctx)
	attachDexui(ctx)

	local pipeline = manifest.pipeline or { "main" }
	local abortAfter = manifest.abortAfter or {}

	for _, moduleName in pipeline do
		local init = loadGame(moduleName)
		if type(init) == "function" then
			init(ctx)
		end
		for _, gate in abortAfter do
			if gate == moduleName and not ctx.isAlive() then
				return ctx
			end
		end
	end

	return ctx
end
