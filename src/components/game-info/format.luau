--!nonstrict
local GameMetadata = require("../../hub/game-metadata")

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function formatNumber(n: number?): string
	if not n then
		return "—"
	end
	if n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	end
	if n >= 1_000 then
		return string.format("%.1fK", n / 1_000)
	end
	return tostring(n)
end

local function formatShortDate(iso: string?): string?
	if not iso then
		return nil
	end
	local y, m, d = string.match(iso, "(%d%d%d%d)%-(%d%d)%-(%d%d)")
	if not y or not m or not d then
		return nil
	end
	local mi = tonumber(m)
	if not mi or mi < 1 or mi > 12 then
		return nil
	end
	return MONTHS[mi] .. " " .. tonumber(d) .. ", " .. y
end

local function formatImage(uri: string): string?
	return GameMetadata.resolveLoadableUri(uri)
end

return {
	formatNumber = formatNumber,
	formatShortDate = formatShortDate,
	formatImage = formatImage,
}
