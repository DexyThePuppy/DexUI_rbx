--!nonstrict
-- Role-based FontFace weights. Roblox picks a face by weight from the family JSON;
-- each face must use a different TTF (no synthetic bold). See:
-- https://create.roblox.com/docs/reference/engine/datatypes/Font
local Services = require("../services")
local Config = require("../config")
local Typography = require("./typography")

local HttpService = Services.HttpService
local TYPO = Config.Typography or {}
local NumericWeight = Typography.NumericWeight
local numericToFontWeight = Typography.numericToFontWeight

local BUILTIN_FAMILY = TYPO.Family or "rbxasset://fonts/families/Roboto.json"

-- Full weight ladder (same tiers as Poppins setup). Built-in Roboto ships every master.
local GLYPH_SLOTS = { "regular", "medium", "bold", "extrabold", "black" }
local SLOT_WEIGHT = {
	regular = 400,
	medium = 500,
	bold = 700,
	extrabold = 800,
	black = 900,
}

-- Legacy static TTFs (optional forced download). Google Fonts now ships Roboto as VF only.
local GLYPH_BASE = "https://github.com/google/fonts/raw/main/apache/roboto/static"
local GLYPH_FILES = {
	regular = { file = "Roboto-Regular.ttf", url = GLYPH_BASE .. "/Roboto-Regular.ttf" },
	medium = { file = "Roboto-Medium.ttf", url = GLYPH_BASE .. "/Roboto-Medium.ttf" },
	bold = { file = "Roboto-Bold.ttf", url = GLYPH_BASE .. "/Roboto-Bold.ttf" },
	extrabold = { file = "Roboto-Bold.ttf", url = GLYPH_BASE .. "/Roboto-Bold.ttf" },
	black = { file = "Roboto-Black.ttf", url = GLYPH_BASE .. "/Roboto-Black.ttf" },
}

local function isBuiltinFamily(uri: string): boolean
	return string.sub(uri, 1, 13) == "rbxasset://"
end

local function parseCloudFamilyId(uri: string): number?
	local id = string.match(uri, "^rbxassetid://(%d+)$")
	return if id then tonumber(id) else nil
end

local function hasExecutorFilesystem(): boolean
	return isfolder and makefolder and isfile and writefile and getcustomasset
end

-- Prefer rbxasset:// families (Roboto.json): real Bold / ExtraBold / Heavy masters in-client.
local function wantCustomFamily(): boolean
	if not hasExecutorFilesystem() then
		return false
	end
	if TYPO.UseCustomFamilyFiles == true then
		return true
	end
	if TYPO.UseCustomFamilyFiles == false then
		return false
	end
	return not isBuiltinFamily(BUILTIN_FAMILY)
end

local function glyphSlot(numeric: number): string
	if numeric >= 900 then
		return "black"
	end
	if numeric >= 800 then
		return "extrabold"
	end
	if numeric >= 700 then
		return "bold"
	end
	if numeric >= 500 then
		return "medium"
	end
	return "regular"
end

local function ensureGlyph(folder: string, spec: { file: string, url: string }): string?
	local path = folder .. "/" .. spec.file
	if not isfile(path) then
		local ok, data = pcall(function()
			return game:HttpGet(spec.url)
		end)
		if not ok or type(data) ~= "string" or #data == 0 then
			return nil
		end
		writefile(path, data)
	end
	return getcustomasset(path)
end

local function loadCustomFamilyUri(): string?
	if not wantCustomFamily() then
		return nil
	end

	local folderName = "DexUI Font Assets"
	local jsonName = "dexui-roboto.json"
	if not isfolder(folderName) then
		makefolder(folderName)
	end

	local assets: { [string]: string } = {}
	for _, slot in GLYPH_SLOTS do
		local spec = GLYPH_FILES[slot]
		local assetId = ensureGlyph(folderName, spec)
		if not assetId then
			return nil
		end
		assets[slot] = assetId
	end

	local faces = {}
	for _, slot in GLYPH_SLOTS do
		table.insert(faces, {
			name = string.upper(string.sub(slot, 1, 1)) .. string.sub(slot, 2),
			weight = SLOT_WEIGHT[slot],
			style = "normal",
			assetId = assets[slot],
		})
	end

	local fontJson = {
		name = "DexUI_Roboto",
		faces = faces,
	}

	local jsonPath = folderName .. "/" .. jsonName
	writefile(jsonPath, HttpService:JSONEncode(fontJson))
	return getcustomasset(jsonPath)
end

local customUri = loadCustomFamilyUri()
local familyUri = customUri or BUILTIN_FAMILY
local cloudFamilyId = if customUri then nil else parseCloudFamilyId(BUILTIN_FAMILY)

local function makeFont(weight: Enum.FontWeight): Font
	if cloudFamilyId then
		return Font.fromId(cloudFamilyId, weight, Enum.FontStyle.Normal)
	end
	return Font.new(familyUri, weight, Enum.FontStyle.Normal)
end

local function fontFromNumeric(weight: number): Font
	return makeFont(numericToFontWeight(weight))
end

local function fontWeight(weight: Enum.FontWeight): Font
	return makeFont(weight)
end

local function fontRole(role: "body" | "emphasis" | "title" | "display"): Font
	return fontFromNumeric(NumericWeight[role])
end

-- Android +300 targets: body 700, emphasis 800, title/display 900 (see typography.luau).
local fontBody = fontRole("body")
local fontEmphasis = fontRole("emphasis")
local fontTitle = fontRole("title")
local fontDisplay = fontRole("display")

-- Tabs: lighter chrome; everything else via m3Font uses bold body.
local chromeWeight = TYPO.ChromeWeight
local function resolveChromeFont(): Font
	if chromeWeight == "medium" then
		return makeFont(Enum.FontWeight.Medium)
	end
	if chromeWeight == "bold" then
		return makeFont(Enum.FontWeight.Bold)
	end
	if chromeWeight == "emphasis" then
		return fontEmphasis
	end
	return makeFont(Enum.FontWeight.Regular)
end
local fontChrome = resolveChromeFont()

local m3Font = fontBody
local fontLarge = fontTitle

return {
	familyUri = familyUri,
	usesCustomFamily = customUri ~= nil,
	cloudFamilyId = cloudFamilyId,
	m3Font = m3Font,
	fontChrome = fontChrome,
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
