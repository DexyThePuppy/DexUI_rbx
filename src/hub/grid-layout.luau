--!nonstrict
-- Shared compact grid metrics for hub-style panels (scripts, tools, icons, badges).

local Config = require("../config")
local H = Config.HubGrid or {}

return {
	SCROLL_PAD = H.ScrollPadding or 6,
	CELL_GAP = H.CellGap or 6,
	SCRIPT_CELL = UDim2.fromOffset(H.ScriptCellW or 108, H.ScriptCellH or 124),
	TOOL_CELL = UDim2.fromOffset(H.ToolCellW or 112, H.ToolCellH or 128),
	ICON_CELL = UDim2.fromOffset(H.IconCellW or 76, H.IconCellH or 70),
	THUMB_INSET = H.ThumbInset or 6,
	BADGE_CELL_W = H.BadgeCellW or 70,
	BADGE_CELL_H = H.BadgeCellH or 78,
	BADGE_ICON = H.BadgeIcon or 44,
	BADGE_GAP = H.BadgeGap or 4,
	BADGE_COLS = H.BadgeCols or 4,
}
