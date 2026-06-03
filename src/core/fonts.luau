--!nonstrict
-- Google Sans M3 font + role-based weights (MUI-style theme typography).
local Services = require("../services")
local Typography = require("./typography")

local HttpService = Services.HttpService
local NumericWeight = Typography.NumericWeight
local numericToFontWeight = Typography.numericToFontWeight

local function loadM3Font(): Font
	local folderName = "M3 Lib Assets"
	local jsonName = "m3font.json"
	local ttfName = "GoogleSans.ttf"
	local fontUrl = "https://github.com/fiangg20/Fian_gg-Repo/raw/refs/heads/main/GoogleSansFlex_24pt-Regular.ttf"

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

	local assetId = getcustomasset(ttfPath)
	local faces = {
		{ name = "Regular", weight = NumericWeight.body, style = "normal", assetId = assetId },
		{ name = "Medium", weight = NumericWeight.emphasis, style = "normal", assetId = assetId },
		{ name = "Bold", weight = NumericWeight.title, style = "normal", assetId = assetId },
		{ name = "Heavy", weight = NumericWeight.display, style = "normal", assetId = assetId },
	}

	local fontJson = {
		name = "CustomFamily_GoogleSans",
		faces = faces,
	}

	local jsonPath = folderName .. "/" .. jsonName
	writefile(jsonPath, HttpService:JSONEncode(fontJson))
	return Font.new(getcustomasset(jsonPath))
end

local m3Font: Font = loadM3Font()

local function fontFromNumeric(weight: number): Font
	return Font.new(m3Font.Family, numericToFontWeight(weight), Enum.FontStyle.Normal)
end

local function fontWeight(weight: Enum.FontWeight): Font
	return Font.new(m3Font.Family, weight, Enum.FontStyle.Normal)
end

local function fontRole(role: "body" | "emphasis" | "title" | "display"): Font
	return fontFromNumeric(NumericWeight[role])
end

local fontBody = fontRole("body")
local fontEmphasis = fontRole("emphasis")
local fontTitle = fontRole("title")
local fontDisplay = fontRole("display")

-- Back-compat alias for section / paragraph headings.
local fontLarge = fontTitle

return {
	m3Font = m3Font,
	fontWeight = fontWeight,
	fontFromNumeric = fontFromNumeric,
	fontRole = fontRole,
	fontBody = fontBody,
	fontEmphasis = fontEmphasis,
	fontTitle = fontTitle,
	fontDisplay = fontDisplay,
	fontLarge = fontLarge,
	Typography = Typography,
}
