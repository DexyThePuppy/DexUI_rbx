--!nonstrict
-- TextLabel layout per Roblox docs: fixed TextSize, no TextScaled, avoid Scale-Y=1 squish.
-- https://create.roblox.com/docs/reference/engine/classes/TextLabel
export type TextLabelMode = "autoX" | "autoXY" | "fill"

local function applyTextLabel(
	lbl: TextLabel,
	font: Font,
	size: number,
	mode: TextLabelMode?
)
	local px = math.max(9, math.floor(size + 0.5))
	lbl.BackgroundTransparency = 1
	lbl.FontFace = font
	lbl.TextSize = px
	lbl.TextScaled = false
	lbl.RichText = false
	lbl.TextWrapped = false
	lbl.LineHeight = 1.05

	local layout = mode or "autoX"
	if layout == "autoX" then
		-- Width from text; fixed pixel height (never UDim2 scale Y = 1).
		lbl.AutomaticSize = Enum.AutomaticSize.X
		lbl.Size = UDim2.fromOffset(0, math.ceil(px * 1.3))
		lbl.TextYAlignment = Enum.TextYAlignment.Center
	elseif layout == "autoXY" then
		lbl.AutomaticSize = Enum.AutomaticSize.XY
		lbl.Size = UDim2.fromOffset(0, 0)
	else
		lbl.AutomaticSize = Enum.AutomaticSize.None
	end
end

return {
	applyTextLabel = applyTextLabel,
}
