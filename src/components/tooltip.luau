--!nonstrict
-- Shared hover tooltip layer for DexUI windows.

export type TooltipAttachOptions = {
	delay: number?,
	maxWidth: number?,
}

export type TooltipController = {
	attach: (target: GuiObject, text: string | (() -> string?), opts: TooltipAttachOptions?) -> (),
	detach: (target: GuiObject) -> (),
	hide: () -> (),
}

return function(ctx)
	local curTheme = ctx.theme
	local reg = ctx.reg
	local corner = ctx.corner
	local m3Font = ctx.m3Font
	local popupLayer = ctx.popupLayer
	local win = ctx.win
	local track = ctx.track
	local onHeartbeat = ctx.onHeartbeat

	type Palette = { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 }
	type Attached = {
		text: string | (() -> string?),
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

	local bodyLbl = Instance.new("TextLabel")
	bodyLbl.Name = "Body"
	bodyLbl.Size = UDim2.new(1, 0, 0, 0)
	bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
	bodyLbl.BackgroundTransparency = 1
	bodyLbl.TextWrapped = true
	bodyLbl.FontFace = m3Font
	bodyLbl.TextSize = 12
	bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
	bodyLbl.TextYAlignment = Enum.TextYAlignment.Top
	bodyLbl.Parent = bubble
	reg(bodyLbl, "TextColor3", "fg")

	local attached: { [GuiObject]: Attached } = {}
	local activeTarget: GuiObject? = nil
	local showToken = 0
	local currentMaxW = DEFAULT_MAX_W

	local function resolveText(source: string | (() -> string?)): string?
		if type(source) == "function" then
			return source()
		end
		local t = source
		if t == "" then
			return nil
		end
		return t
	end

	local function hide()
		showToken += 1
		activeTarget = nil
		bubble.Visible = false
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

	local function showFor(target: GuiObject, text: string)
		activeTarget = target
		bodyLbl.Text = text
		bubble.Visible = true
		task.defer(function()
			if activeTarget == target and bubble.Visible then
				positionBubble(target)
			end
		end)
	end

	local function attach(target: GuiObject, text: string | (() -> string?), opts: TooltipAttachOptions?)
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
					local resolved = resolveText(text)
					if not resolved then
						return
					end
					currentMaxW = maxW
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

		attached[target] = { text = text, opts = opts, conns = conns }
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
