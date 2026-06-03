--!nonstrict
-- Shared hover tooltip layer for DexUI windows. Supports plain text or modular block layouts.

export type TooltipTextBlock = {
	kind: "text",
	text: string,
	muted: boolean?,
}

export type TooltipTitleBlock = {
	kind: "title",
	text: string,
}

export type TooltipDividerBlock = {
	kind: "divider",
}

export type TooltipStatBlock = {
	kind: "stat",
	label: string,
	value: string,
	muted: boolean?,
}

export type TooltipRowBlock = {
	kind: "row",
	label: string,
	value: string,
	muted: boolean?,
}

export type TooltipBlock = TooltipTextBlock | TooltipTitleBlock | TooltipDividerBlock | TooltipStatBlock | TooltipRowBlock

export type TooltipContent = {
	blocks: { TooltipBlock },
	maxWidth: number?,
}

export type TooltipAttachOptions = {
	delay: number?,
	maxWidth: number?,
}

export type TooltipInput = string | TooltipContent | (() -> string | TooltipContent?)

export type TooltipController = {
	attach: (target: GuiObject, content: TooltipInput, opts: TooltipAttachOptions?) -> (),
	detach: (target: GuiObject) -> (),
	hide: () -> (),
}

return function(ctx)
	local reg = ctx.reg
	local corner = ctx.corner
	local m3Font = ctx.m3Font
	local fontWeight = ctx.fontWeight
	local popupLayer = ctx.popupLayer
	local track = ctx.track
	local onHeartbeat = ctx.onHeartbeat

	type Attached = {
		content: TooltipInput,
		opts: TooltipAttachOptions?,
		conns: { RBXScriptConnection },
	}

	local DEFAULT_DELAY = 0.42
	local DEFAULT_MAX_W = 280
	local VIEWPORT_PAD = 10

	local layer = Instance.new("Frame")
	layer.Name = "TooltipLayer"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.Active = false
	layer.ZIndex = 96
	layer.Parent = popupLayer

	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Visible = false
	bubble.BorderSizePixel = 0
	bubble.AutomaticSize = Enum.AutomaticSize.Y
	bubble.AnchorPoint = Vector2.new(0.5, 1)
	bubble.ZIndex = 97
	bubble.Parent = layer
	corner(bubble, 8)
	reg(bubble, "BackgroundColor3", "inact")

	local bubbleStroke = Instance.new("UIStroke")
	bubbleStroke.Thickness = 1
	bubbleStroke.Transparency = 0.55
	bubbleStroke.Parent = bubble
	reg(bubbleStroke, "Color", "out")

	local bubblePad = Instance.new("UIPadding")
	bubblePad.PaddingLeft = UDim.new(0, 10)
	bubblePad.PaddingRight = UDim.new(0, 10)
	bubblePad.PaddingTop = UDim.new(0, 8)
	bubblePad.PaddingBottom = UDim.new(0, 8)
	bubblePad.Parent = bubble

	local contentRoot = Instance.new("Frame")
	contentRoot.Name = "Content"
	contentRoot.Size = UDim2.new(1, 0, 0, 0)
	contentRoot.AutomaticSize = Enum.AutomaticSize.Y
	contentRoot.BackgroundTransparency = 1
	contentRoot.BorderSizePixel = 0
	contentRoot.Parent = bubble

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 6)
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = contentRoot

	local attached: { [GuiObject]: Attached } = {}
	local activeTarget: GuiObject? = nil
	local showToken = 0
	local currentMaxW = DEFAULT_MAX_W

	local function normalizeContent(input: TooltipInput?): TooltipContent?
		if input == nil then
			return nil
		end
		if type(input) == "function" then
			return normalizeContent(input())
		end
		if type(input) == "string" then
			if input == "" then
				return nil
			end
			return { blocks = { { kind = "text", text = input } } }
		end
		if type(input) == "table" then
			if type(input.blocks) == "table" and #input.blocks > 0 then
				return input :: TooltipContent
			end
		end
		return nil
	end

	local function clearContent()
		for _, ch in contentRoot:GetChildren() do
			if not ch:IsA("UIListLayout") then
				ch:Destroy()
			end
		end
	end

	local function addTextBlock(order: number, text: string, size: number, token: string, wrapped: boolean?)
		local lbl = Instance.new("TextLabel")
		lbl.Name = "Block"
		lbl.LayoutOrder = order
		lbl.Size = UDim2.new(1, 0, 0, 0)
		lbl.AutomaticSize = Enum.AutomaticSize.Y
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.FontFace = if token == "fg" then fontWeight(Enum.FontWeight.Medium) else m3Font
		lbl.TextSize = size
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Top
		lbl.TextWrapped = wrapped == true
		lbl.Parent = contentRoot
		reg(lbl, "TextColor3", token)
		return lbl
	end

	local function renderContent(content: TooltipContent)
		clearContent()
		local order = 0
		for _, block in content.blocks do
			order += 1
			if block.kind == "text" then
				addTextBlock(order, block.text, 12, if block.muted then "out" else "fg", true)
			elseif block.kind == "title" then
				addTextBlock(order, block.text, 13, "fg", false)
			elseif block.kind == "divider" then
				local div = Instance.new("Frame")
				div.Name = "Divider"
				div.LayoutOrder = order
				div.Size = UDim2.new(1, 0, 0, 1)
				div.BorderSizePixel = 0
				div.BackgroundTransparency = 0.55
				div.Parent = contentRoot
				reg(div, "BackgroundColor3", "out")
			elseif block.kind == "stat" then
				local group = Instance.new("Frame")
				group.Name = "Stat"
				group.LayoutOrder = order
				group.Size = UDim2.new(1, 0, 0, 0)
				group.AutomaticSize = Enum.AutomaticSize.Y
				group.BackgroundTransparency = 1
				group.Parent = contentRoot

				local groupLayout = Instance.new("UIListLayout")
				groupLayout.Padding = UDim.new(0, 2)
				groupLayout.SortOrder = Enum.SortOrder.LayoutOrder
				groupLayout.Parent = group

				local labelLbl = Instance.new("TextLabel")
				labelLbl.LayoutOrder = 0
				labelLbl.Size = UDim2.new(1, 0, 0, 0)
				labelLbl.AutomaticSize = Enum.AutomaticSize.Y
				labelLbl.BackgroundTransparency = 1
				labelLbl.Text = block.label
				labelLbl.FontFace = m3Font
				labelLbl.TextSize = 10
				labelLbl.TextXAlignment = Enum.TextXAlignment.Left
				labelLbl.Parent = group
				reg(labelLbl, "TextColor3", "out")

				local valueLbl = Instance.new("TextLabel")
				valueLbl.LayoutOrder = 1
				valueLbl.Size = UDim2.new(1, 0, 0, 0)
				valueLbl.AutomaticSize = Enum.AutomaticSize.Y
				valueLbl.BackgroundTransparency = 1
				valueLbl.Text = block.value
				valueLbl.FontFace = fontWeight(Enum.FontWeight.Medium)
				valueLbl.TextSize = 12
				valueLbl.TextWrapped = true
				valueLbl.TextXAlignment = Enum.TextXAlignment.Left
				valueLbl.Parent = group
				reg(valueLbl, "TextColor3", if block.muted then "out" else "fg")
			elseif block.kind == "row" then
				local row = Instance.new("Frame")
				row.Name = "Row"
				row.LayoutOrder = order
				row.Size = UDim2.new(1, 0, 0, 0)
				row.AutomaticSize = Enum.AutomaticSize.Y
				row.BackgroundTransparency = 1
				row.Parent = contentRoot

				local rowLayout = Instance.new("UIListLayout")
				rowLayout.FillDirection = Enum.FillDirection.Horizontal
				rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
				rowLayout.Padding = UDim.new(0, 8)
				rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
				rowLayout.Parent = row

				local labelLbl = Instance.new("TextLabel")
				labelLbl.LayoutOrder = 0
				labelLbl.Size = UDim2.new(0.42, 0, 0, 0)
				labelLbl.AutomaticSize = Enum.AutomaticSize.Y
				labelLbl.BackgroundTransparency = 1
				labelLbl.Text = block.label
				labelLbl.FontFace = m3Font
				labelLbl.TextSize = 11
				labelLbl.TextXAlignment = Enum.TextXAlignment.Left
				labelLbl.TextWrapped = true
				labelLbl.Parent = row
				reg(labelLbl, "TextColor3", "out")

				local valueLbl = Instance.new("TextLabel")
				valueLbl.LayoutOrder = 1
				valueLbl.Size = UDim2.new(0.58, -8, 0, 0)
				valueLbl.AutomaticSize = Enum.AutomaticSize.Y
				valueLbl.BackgroundTransparency = 1
				valueLbl.Text = block.value
				valueLbl.FontFace = fontWeight(Enum.FontWeight.Medium)
				valueLbl.TextSize = 11
				valueLbl.TextWrapped = true
				valueLbl.TextXAlignment = Enum.TextXAlignment.Right
				valueLbl.Parent = row
				reg(valueLbl, "TextColor3", if block.muted then "out" else "fg")
			end
		end
	end

	local function hide()
		showToken += 1
		activeTarget = nil
		bubble.Visible = false
		clearContent()
	end

	local function clampX(centerX: number, halfW: number): number
		local layerPos = layer.AbsolutePosition
		local layerW = math.max(layer.AbsoluteSize.X, 1)
		local minX = layerPos.X + VIEWPORT_PAD + halfW
		local maxX = layerPos.X + layerW - VIEWPORT_PAD - halfW
		return math.clamp(centerX, minX, maxX)
	end

	local function positionBubble(target: GuiObject)
		if not target.Parent then
			hide()
			return
		end

		local targetPos = target.AbsolutePosition
		local targetSize = target.AbsoluteSize
		local layerPos = layer.AbsolutePosition

		bubble.Size = UDim2.fromOffset(currentMaxW, 0)
		local bubbleH = math.max(bubble.AbsoluteSize.Y, 1)
		local bubbleW = math.max(bubble.AbsoluteSize.X, 1)
		local halfW = bubbleW * 0.5

		local centerX = targetPos.X + targetSize.X * 0.5
		centerX = clampX(centerX, halfW)

		local gap = 8
		local aboveY = targetPos.Y - gap
		local relX = centerX - layerPos.X
		local relY = aboveY - layerPos.Y

		if relY - bubbleH < VIEWPORT_PAD then
			bubble.AnchorPoint = Vector2.new(0.5, 0)
			relY = targetPos.Y + targetSize.Y + gap - layerPos.Y
		else
			bubble.AnchorPoint = Vector2.new(0.5, 1)
		end

		bubble.Position = UDim2.fromOffset(relX, relY)
	end

	local function showFor(target: GuiObject, content: TooltipContent)
		activeTarget = target
		currentMaxW = content.maxWidth or currentMaxW
		renderContent(content)
		bubble.Visible = true
		task.defer(function()
			if activeTarget == target and bubble.Visible then
				positionBubble(target)
			end
		end)
	end

	local function attach(target: GuiObject, content: TooltipInput, opts: TooltipAttachOptions?)
		if attached[target] then
			for _, c in attached[target].conns do
				c:Disconnect()
			end
		end

		local delay = if opts and opts.delay then opts.delay else DEFAULT_DELAY
		local maxW = if opts and opts.maxWidth then opts.maxWidth else DEFAULT_MAX_W
		local conns: { RBXScriptConnection } = {}

		table.insert(
			conns,
			target.MouseEnter:Connect(function()
				local token = showToken + 1
				showToken = token
				task.delay(delay, function()
					if showToken ~= token then
						return
					end
					if not target.Parent then
						return
					end
					local resolved = normalizeContent(content)
					if not resolved then
						return
					end
					resolved.maxWidth = resolved.maxWidth or maxW
					currentMaxW = resolved.maxWidth or maxW
					showFor(target, resolved)
				end)
			end)
		)

		table.insert(
			conns,
			target.MouseLeave:Connect(function()
				if activeTarget == target then
					hide()
				else
					showToken += 1
				end
			end)
		)

		table.insert(
			conns,
			target.Destroying:Connect(function()
				if activeTarget == target then
					hide()
				end
				attached[target] = nil
			end)
		)

		attached[target] = { content = content, opts = opts, conns = conns }
	end

	local function detach(target: GuiObject)
		local entry = attached[target]
		if not entry then
			return
		end
		for _, c in entry.conns do
			c:Disconnect()
		end
		attached[target] = nil
		if activeTarget == target then
			hide()
		end
	end

	track(
		onHeartbeat(function()
			if bubble.Visible and activeTarget and activeTarget.Parent then
				positionBubble(activeTarget)
			elseif bubble.Visible then
				hide()
			end
		end)
	)

	ctx.tooltip = {
		attach = attach,
		detach = detach,
		hide = hide,
	} :: TooltipController
end
