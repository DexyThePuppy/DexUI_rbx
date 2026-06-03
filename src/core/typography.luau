--!nonstrict
-- M3/MUI-style type scale: sizes + weights from Config.Typography.
local Config = require("../config")

local TYPO = Config.Typography or {}
local W = TYPO.Weight or {}

local TextSizes = {
	sm = TYPO.Small or 12,
	md = TYPO.Medium or 14,
	lg = TYPO.Large or 22,
}

local NumericWeight = {
	body = W.Body or 400,
	emphasis = W.Emphasis or 500,
	title = W.Title or 700,
	display = W.Display or 900,
}

local function numericToFontWeight(n: number): Enum.FontWeight
	if n >= 900 then
		return Enum.FontWeight.Heavy
	end
	if n >= 800 then
		return Enum.FontWeight.ExtraBold
	end
	if n >= 700 then
		return Enum.FontWeight.Bold
	end
	if n >= 600 then
		return Enum.FontWeight.SemiBold
	end
	if n >= 500 then
		return Enum.FontWeight.Medium
	end
	if n >= 300 then
		return Enum.FontWeight.Light
	end
	return Enum.FontWeight.Regular
end

return {
	TextSizes = TextSizes,
	NumericWeight = NumericWeight,
	numericToFontWeight = numericToFontWeight,
}
