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

local POPPINS_CLOUD_ID = 11702779409
local BUILTIN_FAMILY = TYPO.Family or ("rbxassetid://" .. POPPINS_CLOUD_ID)

local GLYPH_BASE = "https://github.com/google/fonts/raw/main/ofl/poppins"
local GLYPH_FILES = {
	regular = { file = "Poppins-Regular.ttf", url = GLYPH_BASE .. "/Poppins-Regular.ttf" },
	medium = { file = "Poppins-Medium.ttf", url = GLYPH_BASE .. "/Poppins-Medium.ttf" },
	bold = { file = "Poppins-Bold.ttf", url = GLYPH_BASE .. "/Poppins-Bold.ttf" },
	extrabold = { file = "Poppins-ExtraBold.ttf", url = GLYPH_BASE .. "/Poppins-ExtraBold.ttf" },
	black = { file = "Poppins-Black.ttf", url = GLYPH_BASE .. "/Poppins-Black.ttf" },
}

local function parseCloudFamilyId(uri: string): number?
	local id = string.match(uri, "^rbxassetid://(%d+)$")
	return if id then tonumber(id) else nil
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

local function canLoadCustomFamily(): boolean
	return TYPO.UseCustomFamilyFiles == true
		and isfolder
		and makefolder
		and isfile
		and writefile
		and getcustomasset
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
	if not canLoadCustomFamily() then
		return nil
	end

	local folderName = "DexUI Font Assets"
	local jsonName = "dexui-poppins.json"
	if not isfolder(folderName) then
		makefolder(folderName)
	end

	local assets: { [string]: string } = {}
	for slot, spec in pairs(GLYPH_FILES) do
		local assetId = ensureGlyph(folderName, spec)
		if not assetId then
			return nil
		end
		assets[slot] = assetId
	end

	local faces = {}
	local roleOrder = { "body", "emphasis", "title", "display" }
	for _, role in roleOrder do
		local weight = NumericWeight[role]
		local slot = glyphSlot(weight)
		table.insert(faces, {
			name = string.upper(string.sub(role, 1, 1)) .. string.sub(role, 2),
			weight = weight,
			style = "normal",
			assetId = assets[slot],
		})
	end

	local fontJson = {
		name = "DexUI_Poppins",
		faces = faces,
	}

	local jsonPath = folderName .. "/" .. jsonName
	writefile(jsonPath, HttpService:JSONEncode(fontJson))
	return getcustomasset(jsonPath)
end

local function resolveFamilyUri(): string
	local custom = loadCustomFamilyUri()
	if custom then
		return custom
	end
	return BUILTIN_FAMILY
end

local familyUri = resolveFamilyUri()
local cloudFamilyId = parseCloudFamilyId(BUILTIN_FAMILY) or parseCloudFamilyId(familyUri)

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

-- Dense UI (tabs, lists): Medium at native size — not WeightAdjustment-heavy body.
local fontChrome = makeFont(Enum.FontWeight.Medium)
local fontBody = fontRole("body")
local fontEmphasis = fontRole("emphasis")
local fontTitle = fontRole("title")
local fontDisplay = fontRole("display")
local m3Font = fontChrome
local fontLarge = fontTitle

return {
	familyUri = familyUri,
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
