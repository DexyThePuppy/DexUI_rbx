--!nonstrict
export type ChipDeps = {
	lib: any,
	curTheme: { bg: Color3, fg: Color3, out: Color3, pri: Color3, onpri: Color3, inact: Color3 },
	corner: (Instance, number) -> (),
	fontWeight: (Enum.FontWeight) -> Font,
	textSize: (string) -> number,
	playFeedback: (string) -> (),
	trySetClipboard: ((string) -> boolean)?,
	tooltip: any?,
}

local function create(deps: ChipDeps)
	local function notifyCopied(text: string, subtitle: string?)
		if deps.trySetClipboard and deps.trySetClipboard(text) then
			deps.lib:Notify({
				Title = "Copied",
				Content = subtitle or text,
				Duration = 2,
			})
			deps.playFeedback("selection")
		else
			deps.lib:Notify({
				Title = "Copy",
				Content = text,
				Duration = 5,
			})
		end
	end

	local function makeBadgeRow(parent: Frame, layoutOrder: number, name: string): Frame
		local row = Instance.new("Frame")
		row.Name = name
		row.LayoutOrder = layoutOrder
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 1
		row.Parent = parent
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Wraps = true
		rowLayout.Parent = row
		return row
	end

	local function clearBadgeRow(row: Frame)
		for _, ch in row:GetChildren() do
			if ch.Name == "Badge" and (ch:IsA("TextButton") or ch:IsA("Frame")) then
				ch:Destroy()
			end
		end
	end

	local function addInfoBadge(row: Frame, label: string, bg: Color3?, fg: Color3?)
		local badge = Instance.new("TextButton")
		badge.Name = "Badge"
		badge.Text = ""
		badge.AutoButtonColor = false
		badge.Size = UDim2.fromOffset(0, 22)
		badge.AutomaticSize = Enum.AutomaticSize.X
		badge.BackgroundColor3 = bg or deps.curTheme.bg
		badge.BorderSizePixel = 0
		badge.Parent = row
		deps.corner(badge, 6)

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = badge

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromOffset(0, 22)
		lbl.AutomaticSize = Enum.AutomaticSize.X
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.FontFace = deps.fontWeight(Enum.FontWeight.Medium)
		lbl.TextSize = deps.textSize("sm")
		lbl.TextColor3 = fg or deps.curTheme.out
		lbl.Active = false
		lbl.Selectable = false
		lbl.Parent = badge

		badge.MouseButton1Click:Connect(function()
			notifyCopied(label)
		end)

		if deps.tooltip then
			deps.tooltip.attach(badge, label, { delay = 0.35, maxWidth = 260 })
		end
	end

	return {
		notifyCopied = notifyCopied,
		makeBadgeRow = makeBadgeRow,
		clearBadgeRow = clearBadgeRow,
		addInfoBadge = addInfoBadge,
	}
end

return {
	create = create,
}
