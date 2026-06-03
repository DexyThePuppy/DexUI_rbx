--!nonstrict
-- Shared compact grid metrics for hub UIs.

local Config = require("../config")
local G = Config.HubGrid or {}

return {
	scrollPad = G.ScrollPad or 8,
	cellGap = G.CellGap or 6,
	scriptsCell = G.ScriptsCell or { 118, 138 },
	toolsCell = G.ToolsCell or { 124, 146 },
	iconsCell = G.IconsCell or { 84, 76 },
	badgeCell = G.BadgeCell or { 72, 86 },
	badgeIcon = G.BadgeIcon or 44,
	badgeCols = G.BadgeCols or 4,
}
