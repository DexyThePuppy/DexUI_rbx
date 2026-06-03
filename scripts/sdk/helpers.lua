--[[
  Load optional helper packs from scripts/helpers/<name>.lua onto ctx.

  manifest.helpers — list of helper ids, e.g. { "util", "fabrik/api" }
  manifest.helperPrefixes — optional search paths (default: scripts/helpers/)
  Each helper: return function(ctx) ... end
    May return a value stored on ctx.helpers[<id>] (slashes -> dots in key)
]]
local DEFAULT_PREFIXES = {
	"scripts/helpers/",
	"DexUI/scripts/helpers/",
}

local function helperKey(name)
	return (name:gsub("/", "."))
end

local function loadHelperModule(prefixes, name)
	for _, prefix in prefixes do
		local path = prefix .. name .. ".lua"
		if readfile and isfile and isfile(path) then
			local chunk, err = loadstring(readfile(path), "@" .. path)
			if not chunk then
				error("[sdk] helper compile " .. path .. ": " .. tostring(err), 0)
			end
			return chunk()
		end
	end
	return nil
end

return function(ctx, manifest)
	local prefixes = manifest.helperPrefixes or DEFAULT_PREFIXES
	local list = manifest.helpers
	if not list or #list == 0 then
		list = { "util" }
	else
		local hasUtil = false
		for _, id in list do
			if id == "util" then
				hasUtil = true
				break
			end
		end
		if not hasUtil then
			local merged = { "util" }
			for _, id in list do
				table.insert(merged, id)
			end
			list = merged
		end
	end

	ctx.helpers = ctx.helpers or {}
	ctx.loadHelper = function(id)
		local mod = loadHelperModule(prefixes, id)
		if mod == nil then
			error("[sdk] helper not found: " .. tostring(id), 0)
		end
		local attach = type(mod) == "function" and mod or mod.attach
		if type(attach) ~= "function" then
			error("[sdk] helper must return function(ctx) or { attach = fn }: " .. id, 0)
		end
		local result = attach(ctx)
		ctx.helpers[helperKey(id)] = result ~= nil and result or true
		return result
	end

	for _, id in list do
		ctx.loadHelper(id)
	end
end
