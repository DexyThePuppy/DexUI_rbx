--!nonstrict
-- Executes a standalone hub script from the scripts/ folder.

local SCRIPT_PREFIXES = {
	"scripts/",
	"DexUI/scripts/",
}

local function canReadFiles(): boolean
	return readfile ~= nil and isfile ~= nil
end

local function readScriptFile(filename: string): string?
	if not canReadFiles() then
		return nil
	end
	for _, prefix in SCRIPT_PREFIXES do
		local path = prefix .. filename
		if isfile(path) then
			return readfile(path)
		end
	end
	return nil
end

return function(filename: string, dexuiModule: any): (boolean, string?)
	if type(filename) ~= "string" or filename == "" then
		return false, "Invalid script name"
	end
	local source = readScriptFile(filename)
	if not source then
		return false, "Script file not found: " .. filename
	end
	if getgenv then
		getgenv().DexUI = dexuiModule
	elseif _G then
		(_G :: any).DexUI = dexuiModule
	end
	local chunk, err = loadstring(source, "@" .. filename)
	if not chunk then
		return false, err or "Failed to compile script"
	end
	local ok, runErr = pcall(chunk)
	if not ok then
		return false, tostring(runErr)
	end
	return true, nil
end
