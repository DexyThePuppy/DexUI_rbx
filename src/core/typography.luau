--!nonstrict
-- M3/MUI-style type scale: sizes + weights from Config.Typography.
local Config = require("../config")

local TYPO = Config.Typography or {}
local W = TYPO.Weight or {}

local WEIGHT_MIN = 1
local WEIGHT_MAX = 1000

local function clampWeight(n: number): number
	return math.max(WEIGHT_MIN, math.min(WEIGHT_MAX, n))
end

-- Android OS: Configuration.fontWeightAdjustment added to each face (0 off, 300 on).
local function adjustedWeight(base: number): number
	local delta = TYPO.WeightAdjustment
	if delta == nil then
		return base
	end
	return clampWeight(base + delta)
end

local TextSizes = {
	sm = TYPO.Small or 12,
	md = TYPO.Medium or 14,
	lg = TYPO.Large or 22,
}

local NumericWeight = {
	body = adjustedWeight(W.Body or 400),
	emphasis = adjustedWeight(W.Emphasis or 500),
	title = adjustedWeight(W.Title or 700),
	display = adjustedWeight(W.Display or 900),
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
