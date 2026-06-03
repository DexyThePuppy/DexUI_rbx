-- Generic readfile module loader for DexUI game scripts.
-- Usage: local loadMod = requireLoader({ "scripts/mygame/", "DexUI/scripts/mygame/" })
--        local chunk = loadMod("farm")(); chunk(ctx)

local DEFAULT_SDK_PREFIXES = {
	"scripts/sdk/",
	"DexUI/scripts/sdk/",
}

return function(prefixes: { string }?)
	local search = prefixes or DEFAULT_SDK_PREFIXES

	return function(name: string)
		for _, prefix in search do
			local path = prefix .. name .. ".lua"
			if readfile and isfile and isfile(path) then
				local chunk, err = loadstring(readfile(path), "@" .. path)
				if not chunk then
					error("[sdk] compile " .. path .. ": " .. tostring(err), 0)
				end
				return chunk()
			end
		end
		error("[sdk] module not found: " .. tostring(name), 0)
	end
end
