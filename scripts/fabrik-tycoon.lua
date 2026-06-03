--[[
  [UPD] Fabrik-Tycoon — remote + touch auto farmer (DexUI)
  Place: 15197136141

  Modular layout under scripts/fabrik/ (loaded via executor readfile).
  Requires getgenv().DexUI (scripts hub).
]]

local DexUI = (getgenv and getgenv().DexUI) or nil
if not DexUI then
	error("[fabrik-tycoon] DexUI not found. Launch this script from the DexUI scripts hub.")
end

if not (readfile and isfile and loadstring) then
	error("[fabrik-tycoon] Executor must support readfile / isfile / loadstring.")
end

local PREFIXES = { "scripts/fabrik/", "DexUI/scripts/fabrik/" }

local function loadFabrik(name: string)
	for _, prefix in PREFIXES do
		local path = prefix .. name .. ".lua"
		if isfile(path) then
			local chunk, err = loadstring(readfile(path), "@" .. path)
			if not chunk then
				error("[fabrik] " .. tostring(err), 0)
			end
			return chunk()
		end
	end
	error("[fabrik] module not found: " .. name, 0)
end

local ctx = loadFabrik("bootstrap")(DexUI)
loadFabrik("game")(ctx)
if not ctx.isAlive() then
	return
end
loadFabrik("farm")(ctx)
loadFabrik("ads")(ctx)
loadFabrik("ui")(ctx)
loadFabrik("runtime")(ctx)
