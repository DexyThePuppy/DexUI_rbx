--!nonstrict
-- Loads the Google Sans M3 font (with a graceful fallback) and exposes a weight helper.

local Services = require("../services")
local HttpService = Services.HttpService

local function loadM3Font(): Font
	local folderName = "M3 Lib Assets"
	local jsonName = "m3font.json"
	local ttfName = "GoogleSans.ttf"
	local fontUrl = "https://github.com/fiangg20/Fian_gg-Repo/raw/refs/heads/main/GoogleSansFlex_24pt-Regular.ttf"

	-- Executors expose these globals; bail out gracefully on vanilla clients.
	if not (isfolder and makefolder and isfile and writefile and getcustomasset) then
		return Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	end

	if not isfolder(folderName) then
		makefolder(folderName)
	end

	local ttfPath = folderName .. "/" .. ttfName
	if not isfile(ttfPath) then
		writefile(ttfPath, game:HttpGet(fontUrl))
	end

	local fontJson = {
		name = "CustomFamily_GoogleSans",
		faces = {
			{ name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(ttfPath) },
		},
	}

	local jsonPath = folderName .. "/" .. jsonName
	writefile(jsonPath, HttpService:JSONEncode(fontJson))
	return Font.new(getcustomasset(jsonPath))
end

local m3Font: Font = loadM3Font()

local function fontWeight(weight: Enum.FontWeight): Font
	return Font.new(m3Font.Family, weight, Enum.FontStyle.Normal)
end

return {
	m3Font = m3Font,
	fontWeight = fontWeight,
}
