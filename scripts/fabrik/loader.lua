-- Module loader for Fabrik (executor readfile).
local PREFIXES = { "scripts/fabrik/", "DexUI/scripts/fabrik/" }

return function(name: string)
	for _, prefix in PREFIXES do
		local path = prefix .. name .. ".lua"
		if readfile and isfile and isfile(path) then
			local chunk, err = loadstring(readfile(path), "@" .. path)
			if not chunk then
				error("[fabrik] " .. tostring(err), 0)
			end
			return chunk()
		end
	end
	error("[fabrik] module not found: " .. name, 0)
end
