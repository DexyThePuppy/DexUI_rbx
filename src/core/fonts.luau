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

-- Built-in family with real per-weight masters (Gotham SSm).
local BUILTIN_FAMILY = TYPO.Family or "rbxasset://fonts/families/GothamSSm.json"

local GLYPH_FILES = {
	regular = {
		file = "Roboto-Regular.ttf",
		url = "https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Regular.ttf",
	},
	medium = {
		file = "Roboto-Medium.ttf",
		url = "https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Medium.ttf",
	},
	bold = {
		file = "Roboto-Bold.ttf",
		url = "https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Bold.ttf",
	},
	black = {
		file = "Roboto-Black.ttf",
		url = "https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Black.ttf",
	},
}

local function glyphSlot(numeric: number): string
	if numeric >= 900 then
		return "black"
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
	return isfolder and makefolder and isfile and writefile and getcustomasset
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

-- Executor path: build a font-family JSON with one TTF per weight tier.
local function loadCustomFamilyUri(): string?
	if not canLoadCustomFamily() then
		return nil
	end

	local folderName = "DexUI Font Assets"
	local jsonName = "dexui-family.json"
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
	for i, role in roleOrder do
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
		name = "DexUI_Roboto",
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

local function fontFromNumeric(weight: number): Font
	return Font.new(familyUri, numericToFontWeight(weight), Enum.FontStyle.Normal)
end

local function fontWeight(weight: Enum.FontWeight): Font
	return Font.new(familyUri, weight, Enum.FontStyle.Normal)
end

local function fontRole(role: "body" | "emphasis" | "title" | "display"): Font
	return fontFromNumeric(NumericWeight[role])
end

local fontBody = fontRole("body")
local fontEmphasis = fontRole("emphasis")
local fontTitle = fontRole("title")
local fontDisplay = fontRole("display")
local m3Font = fontBody
local fontLarge = fontTitle

return {
	familyUri = familyUri,
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
