--!nonstrict
-- DexUI notification feed. Terraria / MC-style stacked toasts on the right edge.
-- Styled via Config.Notifications defaults, lib:SetNotificationStyle(), and optional
-- per-call Style overrides on lib:Notify().

export type ColorToken = "bg" | "fg" | "pri" | "onpri" | "inact" | "out"
export type StyleColor = Color3 | ColorToken
export type StyleGradient = "rainbow" | "tint" | ColorSequence | false

export type NotificationStyle = {
	Max: number?,
	Life: number?,
	FadeIn: number?,
	FadeOut: number?,
	Slide: number?,
	Width: number?,
	Height: number?,
	Gap: number?,
	PadRight: number?,
	PadInner: number?,
	TextSize: number?,
	CornerRadius: number?,
	StackAnchor: Vector2?,
	StackPosition: UDim2?,
	StackZIndex: number?,
	Background: {
		Color: StyleColor?,
		Transparency: number?,
	}?,
	Border: {
		Color: StyleColor?,
		Thickness: number?,
		Transparency: number?,
	}?,
	Text: {
		Color: StyleColor?,
		Gradient: StyleGradient?,
	}?,
	TextStroke: {
		Color: StyleColor?,
		Thickness: number?,
		Transparency: number?,
		Gradient: StyleGradient?,
	}?,
	Rainbow: {
		HueStep: number?,
		FillHueSpan: number?,
		FillStops: number?,
	}?,
}

type Palette = { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 }

type ResolvedStyle = {
	Max: number,
	Life: number,
	FadeIn: number,
	FadeOut: number,
	Slide: number,
	Width: number,
	Height: number,
	Gap: number,
	PadRight: number,
	PadInner: number,
	TextSize: number,
	CornerRadius: number,
	StackAnchor: Vector2,
	StackPosition: UDim2,
	StackZIndex: number,
	Background: { Color: StyleColor, Transparency: number },
	Border: { Color: StyleColor, Thickness: number, Transparency: number },
	Text: { Color: StyleColor, Gradient: StyleGradient? },
	TextStroke: { Color: StyleColor, Thickness: number, Transparency: number, Gradient: StyleGradient? },
	Rainbow: { HueStep: number, FillHueSpan: number, FillStops: number },
}

local function deepMerge(into: { any }, from: { any }?)
	if not from then
		return into
	end
	for key, value in from do
		if type(value) == "table" and type(into[key]) == "table" then
			deepMerge(into[key], value)
		else
			into[key] = value
		end
	end
	return into
end

local function cloneStyle(style: ResolvedStyle): ResolvedStyle
	local copy = table.clone(style)
	copy.Background = table.clone(style.Background)
	copy.Border = table.clone(style.Border)
	copy.Text = table.clone(style.Text)
	copy.TextStroke = table.clone(style.TextStroke)
	copy.Rainbow = table.clone(style.Rainbow)
	return copy
end

return function(ctx)
	local lib = ctx.lib
	local curTheme: Palette = ctx.theme
	local regDynamic = ctx.regDynamic
	local tween = ctx.tween
	local corner = ctx.corner
	local fontWeight = ctx.fontWeight
	local playFeedback = ctx.playFeedback
	local playNotificationSound = ctx.playNotificationSound
	local onHeartbeat = ctx.onHeartbeat
	local TweenService = ctx.TweenService
	local gui = ctx.gui
	local Config = ctx.config

	local runtimeStyle: NotificationStyle = {}
	local notifStack: Frame
	local notifEntries: { any } = {}
	local notifRainbowCounter = 0

	local function resolveColor(spec: StyleColor?, theme: Palette): Color3
		if spec == nil then
			return theme.fg
		end
		if typeof(spec) == "Color3" then
			return spec
		end
		return theme[spec] or theme.fg
	end

	local function priHue(theme: Palette): number
		return theme.pri:ToHSV()
	end

	local function rainbowColor(hue: number, sat: number, val: number): Color3
		return Color3.fromHSV(hue % 1, math.clamp(sat, 0, 1), math.clamp(val, 0, 1))
	end

	local function buildDefaults(): ResolvedStyle
		local cfg = Config.Notifications or {}
		return {
			Max = cfg.Max or 8,
			Life = cfg.Life or 4.2,
			FadeIn = cfg.FadeIn or 0.22,
			FadeOut = cfg.FadeOut or 0.3,
			Slide = cfg.Slide or 0.24,
			Width = cfg.Width or 440,
			Height = cfg.Height or 36,
			Gap = cfg.Gap or 5,
			PadRight = cfg.PadRight or 18,
			PadInner = cfg.PadInner or 12,
			TextSize = cfg.TextSize or 22,
			CornerRadius = cfg.CornerRadius or 10,
			StackAnchor = cfg.StackAnchor or Vector2.new(1, 0.5),
			StackPosition = cfg.StackPosition or UDim2.new(1, -16, 0.5, 0),
			StackZIndex = cfg.StackZIndex or 50,
			Background = {
				Color = (cfg.Background and cfg.Background.Color) or "inact",
				Transparency = (cfg.Background and cfg.Background.Transparency) or 0.18,
			},
			Border = {
				Color = (cfg.Border and cfg.Border.Color) or "pri",
				Thickness = (cfg.Border and cfg.Border.Thickness) or 1.5,
				Transparency = (cfg.Border and cfg.Border.Transparency) or 0.35,
			},
			Text = {
				Color = (cfg.Text and cfg.Text.Color) or "fg",
				Gradient = if cfg.Text and cfg.Text.Gradient ~= nil then cfg.Text.Gradient else "rainbow",
			},
			TextStroke = {
				Color = (cfg.TextStroke and cfg.TextStroke.Color) or "pri",
				Thickness = (cfg.TextStroke and cfg.TextStroke.Thickness) or 3.5,
				Transparency = (cfg.TextStroke and cfg.TextStroke.Transparency) or 0,
				Gradient = if cfg.TextStroke and cfg.TextStroke.Gradient ~= nil then cfg.TextStroke.Gradient else "rainbow",
			},
			Rainbow = {
				HueStep = (cfg.Rainbow and cfg.Rainbow.HueStep) or 0.06,
				FillHueSpan = (cfg.Rainbow and cfg.Rainbow.FillHueSpan) or 0.045,
				FillStops = (cfg.Rainbow and cfg.Rainbow.FillStops) or 6,
			},
		}
	end

	local baseDefaults = buildDefaults()

	local function resolveStyle(override: NotificationStyle?): ResolvedStyle
		local merged = cloneStyle(baseDefaults)
		deepMerge(merged, runtimeStyle)
		deepMerge(merged, override)
		return merged
	end

	local function rowStep(style: ResolvedStyle): number
		return style.Height + style.Gap
	end

	local function bottomRow(style: ResolvedStyle): number
		return style.Max - 1
	end

	local function rowY(style: ResolvedStyle, row: number): number
		return row * rowStep(style)
	end

	local function rowPos(style: ResolvedStyle, row: number): UDim2
		return UDim2.new(1, -style.PadRight, 0, rowY(style, row))
	end

	local function baseHue(style: ResolvedStyle, rainbowIndex: number, theme: Palette): number
		return (priHue(theme) - rainbowIndex * style.Rainbow.HueStep) % 1
	end

	local function makeRainbowFillGradient(style: ResolvedStyle, base: number): ColorSequence
		local keypoints = {}
		local stops = math.max(2, style.Rainbow.FillStops)
		for i = 0, stops - 1 do
			local t = i / (stops - 1)
			local h = (base + t * style.Rainbow.FillHueSpan) % 1
			local sat = 0.92 - t * 0.08
			local val = 1 - t * 0.14
			keypoints[#keypoints + 1] = ColorSequenceKeypoint.new(t, rainbowColor(h, sat, val))
		end
		return ColorSequence.new(keypoints)
	end

	local function makeRainbowStrokeGradient(style: ResolvedStyle, base: number): ColorSequence
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, rainbowColor(base + 0.02, 0.85, 0.28)),
			ColorSequenceKeypoint.new(1, rainbowColor(base + style.Rainbow.FillHueSpan, 0.9, 0.14)),
		})
	end

	local function makeTintFillGradient(theme: Palette): ColorSequence
		local h, s, v = theme.pri:ToHSV()
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(h, math.min(s, 0.9), math.min(v + 0.08, 1))),
			ColorSequenceKeypoint.new(1, theme.pri),
		})
	end

	local function makeTintStrokeGradient(theme: Palette): ColorSequence
		local h, s, _v = theme.pri:ToHSV()
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(h, math.min(s + 0.1, 1), 0.28)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(h, math.min(s + 0.15, 1), 0.14)),
		})
	end

	local function resolveGradient(
		mode: StyleGradient?,
		style: ResolvedStyle,
		rainbowIndex: number,
		theme: Palette,
		forStroke: boolean
	): ColorSequence?
		if mode == nil or mode == false then
			return nil
		end
		if typeof(mode) == "ColorSequence" then
			return mode
		end
		if mode == "tint" then
			return if forStroke then makeTintStrokeGradient(theme) else makeTintFillGradient(theme)
		end
		local base = baseHue(style, rainbowIndex, theme)
		return if forStroke then makeRainbowStrokeGradient(style, base) else makeRainbowFillGradient(style, base)
	end

	local function clearGradients(label: TextLabel)
		for _, child in label:GetChildren() do
			if child:IsA("UIGradient") then
				child:Destroy()
			end
		end
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			for _, child in stroke:GetChildren() do
				if child:IsA("UIGradient") then
					child:Destroy()
				end
			end
		end
	end

	local function applyCardTheme(card: Frame, cardStroke: UIStroke, style: ResolvedStyle, theme: Palette)
		card.BackgroundColor3 = resolveColor(style.Background.Color, theme)
		cardStroke.Color = resolveColor(style.Border.Color, theme)
		cardStroke.Thickness = style.Border.Thickness
	end

	local function applyTextTheme(
		label: TextLabel,
		textStroke: UIStroke?,
		style: ResolvedStyle,
		rainbowIndex: number,
		theme: Palette
	)
		clearGradients(label)
		label.FontFace = fontWeight(Enum.FontWeight.Bold)
		label.TextSize = style.TextSize
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextStrokeTransparency = 1
		label.RichText = false

		local fillGradient = resolveGradient(style.Text.Gradient, style, rainbowIndex, theme, false)
		if fillGradient then
			label.TextColor3 = Color3.new(1, 1, 1)
			local grad = Instance.new("UIGradient")
			grad.Rotation = 90
			grad.Color = fillGradient
			grad.Parent = label
		else
			label.TextColor3 = resolveColor(style.Text.Color, theme)
		end

		if not textStroke then
			return
		end
		if style.TextStroke.Thickness <= 0 then
			textStroke:Destroy()
			return
		end
		textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		textStroke.LineJoinMode = Enum.LineJoinMode.Round
		textStroke.Thickness = style.TextStroke.Thickness
		textStroke.Transparency = style.TextStroke.Transparency

		local strokeGradient = resolveGradient(style.TextStroke.Gradient, style, rainbowIndex, theme, true)
		if strokeGradient then
			textStroke.Color = Color3.new(1, 1, 1)
			local grad = Instance.new("UIGradient")
			grad.Rotation = 90
			grad.Color = strokeGradient
			grad.Parent = textStroke
		else
			textStroke.Color = resolveColor(style.TextStroke.Color, theme)
		end
	end

	local function tweenCard(card: Frame, targetPos: UDim2, duration: number?)
		TweenService:Create(
			card,
			TweenInfo.new(duration or resolveStyle(nil).Slide, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = targetPos }
		):Play()
	end

	local function fadeCardEntry(
		entry: any,
		bgTransparency: number,
		borderTransparency: number,
		textTransparency: number,
		strokeTransparency: number,
		duration: number
	)
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(entry.card, info, { BackgroundTransparency = bgTransparency }):Play()
		if entry.cardStroke then
			TweenService:Create(entry.cardStroke, info, { Transparency = borderTransparency }):Play()
		end
		TweenService:Create(entry.label, info, { TextTransparency = textTransparency }):Play()
		if entry.textStroke then
			TweenService:Create(entry.textStroke, info, { Transparency = strokeTransparency }):Play()
		end
	end

	local function fadeOutNotifEntry(entry: any, immediate: boolean?, onDone: (() -> ())?)
		if entry.removing then
			return
		end
		entry.removing = true
		if not entry.card or not entry.card.Parent then
			if onDone then
				onDone()
			end
			return
		end
		local style: ResolvedStyle = entry.style
		local duration = if immediate then 0.08 else style.FadeOut
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fadeTween = TweenService:Create(entry.label, info, { TextTransparency = 1 })
		fadeTween:Play()
		TweenService:Create(entry.card, info, { BackgroundTransparency = 1 }):Play()
		if entry.cardStroke then
			TweenService:Create(entry.cardStroke, info, { Transparency = 1 }):Play()
		end
		if entry.textStroke then
			TweenService:Create(entry.textStroke, info, { Transparency = 1 }):Play()
		end
		fadeTween.Completed:Connect(function()
			if entry.card.Parent then
				entry.card:Destroy()
			end
			if onDone then
				onDone()
			end
		end)
	end

	local function syncNotifRows(animate: boolean, skipEntry: any?)
		local style = resolveStyle(nil)
		local count = #notifEntries
		for j, entry in ipairs(notifEntries) do
			if entry ~= skipEntry and not entry.removing then
				local card = entry.card
				if card and card.Parent then
					local targetRow = bottomRow(style) - (count - j)
					entry.row = targetRow
					local target = rowPos(entry.style, targetRow)
					if animate then
						tweenCard(card, target, entry.style.Slide)
					else
						card.Position = target
					end
				end
			end
		end
	end

	local function refreshNotifStackLayout(style: ResolvedStyle)
		if not notifStack or not notifStack.Parent then
			return
		end
		notifStack.Size = UDim2.fromOffset(style.Width, style.Max * rowStep(style))
		notifStack.AnchorPoint = style.StackAnchor
		notifStack.Position = style.StackPosition
		notifStack.ZIndex = style.StackZIndex
		syncNotifRows(false)
	end

	local function shiftNotifUp(animate: boolean, style: ResolvedStyle)
		local removeIdx = {}
		for i, entry in ipairs(notifEntries) do
			if not entry.removing then
				local card = entry.card
				if card and card.Parent then
					local fromRow = entry.row
					if fromRow == nil then
						fromRow = bottomRow(style) - (#notifEntries - i)
						entry.row = fromRow
					end
					local targetRow = fromRow - 1
					entry.row = targetRow
					if targetRow < 0 then
						removeIdx[#removeIdx + 1] = i
						fadeOutNotifEntry(entry, false)
					elseif animate then
						tweenCard(card, rowPos(entry.style, targetRow), entry.style.Slide)
					else
						card.Position = rowPos(entry.style, targetRow)
					end
				end
			end
		end
		for ri = #removeIdx, 1, -1 do
			table.remove(notifEntries, removeIdx[ri])
		end
	end

	local function trimNotifOverflow(style: ResolvedStyle)
		while #notifEntries > style.Max do
			local oldest = table.remove(notifEntries, 1)
			if oldest then
				fadeOutNotifEntry(oldest, true)
			end
		end
	end

	local function formatNotifText(opts: { Title: string?, Content: string? }): string
		local title = opts.Title
		local content = opts.Content
		if title and content and content ~= "" then
			return title .. " — " .. content
		end
		return title or content or "Notification"
	end

	local function ensureNotifStack(style: ResolvedStyle): Frame
		if notifStack and notifStack.Parent then
			refreshNotifStackLayout(style)
			return notifStack
		end
		notifStack = Instance.new("Frame")
		notifStack.Name = "NotifStack"
		notifStack.BackgroundTransparency = 1
		notifStack.ClipsDescendants = false
		notifStack.Parent = gui
		refreshNotifStackLayout(style)
		return notifStack
	end

	local function pushNotif(text: string, life: number?, styleOverride: NotificationStyle?)
		if text == "" then
			return
		end
		local style = resolveStyle(styleOverride)
		local stack = ensureNotifStack(style)

		local card = Instance.new("Frame")
		card.Name = "Entry"
		card.AnchorPoint = Vector2.new(1, 0)
		card.Size = UDim2.fromOffset(style.Width - style.PadRight, style.Height)
		card.BackgroundTransparency = 1
		card.ClipsDescendants = true
		card.Parent = stack
		corner(card, style.CornerRadius)

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Parent = card
		applyCardTheme(card, cardStroke, style, curTheme)
		cardStroke.Transparency = 1

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.new(1, -style.PadInner * 2, 1, 0)
		label.Position = UDim2.new(0, style.PadInner, 0, 0)
		label.BackgroundTransparency = 1
		label.TextTransparency = 1
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextWrapped = false
		label.Text = text
		label.Parent = card

		local textStroke: UIStroke? = nil
		if style.TextStroke.Thickness > 0 then
			textStroke = Instance.new("UIStroke")
			textStroke.Transparency = 1
			textStroke.Parent = label
		end

		local rainbowIndex = notifRainbowCounter
		notifRainbowCounter += 1
		applyTextTheme(label, textStroke, style, rainbowIndex, curTheme)
		if not label:FindFirstChildOfClass("UIStroke") then
			textStroke = nil
		end

		if #notifEntries > 0 then
			shiftNotifUp(true, style)
		end

		local spawnRow = bottomRow(style)
		local bottomY = rowY(style, spawnRow)
		card.Position = UDim2.new(1, 36, 0, bottomY + 12)

		local entry = {
			card = card,
			cardStroke = cardStroke,
			label = label,
			textStroke = textStroke,
			at = os.clock(),
			life = life or style.Life,
			removing = false,
			row = spawnRow,
			rainbowIndex = rainbowIndex,
			style = style,
		}
		table.insert(notifEntries, entry)
		trimNotifOverflow(style)

		local target = rowPos(style, spawnRow)
		tweenCard(card, target, style.FadeIn)
		fadeCardEntry(entry, style.Background.Transparency, style.Border.Transparency, 0, style.TextStroke.Transparency, style.FadeIn)
	end

	onHeartbeat(function()
		if #notifEntries == 0 then
			return
		end
		local now = os.clock()
		local needsSync = false
		for i = #notifEntries, 1, -1 do
			local entry = notifEntries[i]
			if not entry.removing and now - entry.at >= entry.life then
				fadeOutNotifEntry(entry, false)
				table.remove(notifEntries, i)
				needsSync = true
			elseif entry.removing and (not entry.card or not entry.card.Parent) then
				table.remove(notifEntries, i)
				needsSync = true
			end
		end
		if needsSync then
			syncNotifRows(true)
		end
	end)

	regDynamic(function(theme: Palette, dur: number)
		for _, entry in notifEntries do
			if entry.removing or not entry.card or not entry.card.Parent then
				continue
			end
			local style: ResolvedStyle = entry.style
			local bgTrans = entry.card.BackgroundTransparency
			local borderTrans = entry.cardStroke and entry.cardStroke.Transparency or 1
			local textTrans = entry.label.TextTransparency
			local strokeTrans = entry.textStroke and entry.textStroke.Transparency or 1
			if dur > 0 then
				tween(entry.card, "BackgroundColor3", resolveColor(style.Background.Color, theme), dur)
				if entry.cardStroke then
					tween(entry.cardStroke, "Color", resolveColor(style.Border.Color, theme), dur)
				end
			else
				applyCardTheme(entry.card, entry.cardStroke, style, theme)
			end
			applyTextTheme(entry.label, entry.textStroke, style, entry.rainbowIndex, theme)
			entry.card.BackgroundTransparency = bgTrans
			if entry.cardStroke then
				entry.cardStroke.Transparency = borderTrans
			end
			entry.label.TextTransparency = textTrans
			if entry.textStroke then
				entry.textStroke.Transparency = strokeTrans
			end
		end
	end)

	function lib:SetNotificationStyle(style: NotificationStyle)
		deepMerge(runtimeStyle, style)
		refreshNotifStackLayout(resolveStyle(nil))
	end

	function lib:GetNotificationStyle(): NotificationStyle?
		if next(runtimeStyle) == nil then
			return nil
		end
		local copy: NotificationStyle = {}
		deepMerge(copy, runtimeStyle)
		return copy
	end

	function lib:Notify(opts: { Title: string?, Content: string?, Duration: number?, Style: NotificationStyle? })
		playNotificationSound()
		pushNotif(formatNotifText(opts), opts.Duration, opts.Style)
	end
end
