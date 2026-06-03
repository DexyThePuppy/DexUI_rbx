--!nonstrict
-- TextLabel layout per Roblox docs: fixed TextSize, TextScaled off, FontFace only.
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
	lbl.BorderSizePixel = 0
	lbl.FontFace = font
	lbl.TextSize = px
	lbl.TextScaled = false
	lbl.RichText = false
	lbl.TextWrapped = false
	lbl.LineHeight = 1
	lbl.TextStrokeTransparency = 1

	local layout = mode or "autoX"
	if layout == "autoX" then
		lbl.AutomaticSize = Enum.AutomaticSize.X
		lbl.Size = UDim2.fromOffset(0, px + 4)
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
