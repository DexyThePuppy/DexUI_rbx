--[[
  Standard hub entry bootstrap: DexUI check, readfile loader, SDK.run.
  Game scripts: local ctx = loadFile("sdk/entry.lua")(manifest, DexUI)
]]
local SDK_PREFIXES = {
	"scripts/sdk/",
	"DexUI/scripts/sdk/",
}

local WORKSPACE_PREFIXES = {
	"scripts/",
	"DexUI/scripts/",
}

local function loadFrom(prefixes, relPath)
	for _, prefix in prefixes do
		local path = prefix .. relPath
		if readfile and isfile and isfile(path) then
			local chunk, err = loadstring(readfile(path), "@" .. path)
			if not chunk then
				error("[sdk] " .. path .. ": " .. tostring(err), 0)
			end
			return chunk()
		end
	end
	error("[sdk] missing " .. relPath, 0)
end

return function(manifest, DexUI)
	local DexUIRef = DexUI or (getgenv and getgenv().DexUI)
	if not DexUIRef then
		error("[sdk] DexUI not found — launch from the DexUI scripts hub.", 0)
	end
	if not (readfile and isfile and loadstring) then
		error("[sdk] readfile / isfile / loadstring required.", 0)
	end

	local SDK = loadFrom(SDK_PREFIXES, "run.lua")
	return SDK(manifest, DexUIRef)
end
