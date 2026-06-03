--[[
  Advanced DexUI game bootstrap — helpers, logic modules, UI, optional onReady.

  manifest.helperPrefixes + manifest.helpers  → run first (shared game API)
  manifest.prefixes     + manifest.pipeline  → logic modules (abortAfter gates)
  manifest.ui           → DexUI layout module name (after pipeline, if alive)
  manifest.onReady      → function(ctx) startup / loops (hub entry file)
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
local runCore = loadFrom(SDK_PREFIXES, "run")

return function(manifest, DexUI)
	if type(manifest) == "function" then
		manifest = manifest()
	end
	if type(manifest) ~= "table" then
		error("[sdk] manifest must be a table", 0)
	end

	local coreManifest = {}
	for key, value in manifest do
		if key ~= "helperPrefixes" and key ~= "helpers" and key ~= "ui" and key ~= "onReady" then
			coreManifest[key] = value
		end
	end
	coreManifest.pipeline = nil
	coreManifest.abortAfter = nil

	local ctx = runCore(coreManifest, DexUI)
	if not ctx.isAlive() then
		return ctx
	end

	local helperPrefixes = manifest.helperPrefixes
	local helpers = manifest.helpers
	if helperPrefixes and helpers and #helpers > 0 then
		local loadHelper = makeLoader(helperPrefixes)
		for _, name in helpers do
			local init = loadHelper(name)
			if type(init) == "function" then
				local ok, err = init(ctx)
				if ok == false then
					ctx.log.error("helper failed: " .. tostring(name))
					ctx.shutdown(false)
					return ctx
				end
				if not ok and err ~= nil then
					ctx.log.error("helper " .. name .. ": " .. tostring(err))
					ctx.shutdown(false)
					return ctx
				end
			end
			if not ctx.isAlive() then
				return ctx
			end
		end
	end

	local pipeline = manifest.pipeline
	if pipeline and #pipeline > 0 and ctx.isAlive() then
		local partPrefixes = manifest.prefixes or manifest.partPrefixes or manifest.modulePrefixes
		if not partPrefixes then
			error("[sdk] manifest.prefixes required when pipeline is set", 0)
		end
		local loadPart = makeLoader(partPrefixes)
		local abortAfter = manifest.abortAfter or {}
		for _, name in pipeline do
			local init = loadPart(name)
			if type(init) == "function" then
				init(ctx)
			end
			for _, gate in abortAfter do
				if gate == name and not ctx.isAlive() then
					return ctx
				end
			end
		end
	end

	local uiName = manifest.ui
	if type(uiName) == "string" and uiName ~= "" and ctx.isAlive() then
		local partPrefixes = manifest.prefixes or manifest.partPrefixes or manifest.modulePrefixes
		if not partPrefixes then
			error("[sdk] manifest.prefixes required for manifest.ui", 0)
		end
		local loadPart = makeLoader(partPrefixes)
		local init = loadPart(uiName)
		if type(init) == "function" then
			init(ctx)
		end
	end

	local onReady = manifest.onReady
	if type(onReady) == "function" and ctx.isAlive() then
		onReady(ctx)
	end

	return ctx
end
