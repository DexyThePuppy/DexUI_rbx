--!nonstrict
-- Configurable window footer: clock, version, and custom segments.

export type FooterSegmentKind = "text" | "version" | "clock" | "spacer"

export type FooterSegment = {
	id: string?,
	kind: FooterSegmentKind?,
	text: string?,
	align: ("left" | "right")?,
	muted: boolean?,
}

export type FooterClockConfig = {
	Enabled: boolean?,
	Format: string?,
	UseLocalTime: boolean?,
	UpdateInterval: number?,
}

export type FooterVersionConfig = {
	Enabled: boolean?,
	Prefix: string?,
	Text: string?,
}

export type FooterConfig = {
	Enabled: boolean?,
	Height: number?,
	BackgroundTransparency: number?,
	ShowTopDivider: boolean?,
	PaddingX: number?,
	TextSize: number?,
	Layout: ("row" | "split")?,
	Clock: FooterClockConfig?,
	Version: FooterVersionConfig?,
	Left: { FooterSegment }?,
	Right: { FooterSegment }?,
	Segments: { FooterSegment }?,
}

export type FooterController = {
	SetConfig: (partial: FooterConfig?) -> (),
	SetSegmentText: (id: string, text: string) -> (),
	SetSegmentVisible: (id: string, visible: boolean) -> (),
	Refresh: () -> (),
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

return function(ctx)
	local lib = ctx.lib
	local Config = ctx.config
	local curTheme = ctx.theme
	local reg = ctx.reg
	local corner = ctx.corner
	local m3Font = ctx.m3Font
	local winCorner = if type(ctx.WindowCornerRadius) == "number" then ctx.WindowCornerRadius else 16

	type SegmentRow = FooterSegment & { align: string }
	type LabelEntry = { id: string, lbl: TextLabel, kind: string }

	local runtimeConfig: FooterConfig = {}
	local labelById: { [string]: LabelEntry } = {}
	local clockToken = 0
	local footerBar: Frame? = nil
	local topDivider: Frame? = nil

	local function defaultConfig(): FooterConfig
		local base = Config.Footer
		if type(base) == "table" then
			local copy: FooterConfig = {}
			deepMerge(copy, base)
			return copy
		end
		return {
			Enabled = true,
			Height = 28,
			Layout = "split",
			Left = {
				{ id = "brand", kind = "text", text = Config.Brand or "DexUI" },
				{ id = "version", kind = "version" },
			},
			Right = {
				{ id = "clock", kind = "clock" },
			},
		}
	end

	runtimeConfig = defaultConfig()

	local function segmentList(): { SegmentRow }
		if runtimeConfig.Layout == "row" and runtimeConfig.Segments then
			local out: { SegmentRow } = {}
			for _, seg in runtimeConfig.Segments do
				local row = table.clone(seg) :: SegmentRow
				row.align = row.align or "left"
				table.insert(out, row)
			end
			return out
		end
		local out: { SegmentRow } = {}
		for _, seg in runtimeConfig.Left or {} do
			local row = table.clone(seg) :: SegmentRow
			row.align = "left"
			table.insert(out, row)
		end
		for _, seg in runtimeConfig.Right or {} do
			local row = table.clone(seg) :: SegmentRow
			row.align = "right"
			table.insert(out, row)
		end
		return out
	end

	local function formatClock(): string
		local clockCfg = runtimeConfig.Clock or {}
		if clockCfg.Enabled == false then
			return ""
		end
		local fmt = clockCfg.Format or "%H:%M:%S"
		return os.date(fmt)
	end

	local function formatVersion(): string
		local verCfg = runtimeConfig.Version or {}
		if verCfg.Enabled == false then
			return ""
		end
		if type(verCfg.Text) == "string" and verCfg.Text ~= "" then
			return verCfg.Text
		end
		local prefix = verCfg.Prefix or "v"
		return prefix .. (Config.Version or "1.0.0")
	end

	local function resolveSegmentText(seg: SegmentRow): string
		local kind = seg.kind or "text"
		if kind == "spacer" then
			return ""
		end
		if kind == "clock" then
			return formatClock()
		end
		if kind == "version" then
			return formatVersion()
		end
		return seg.text or ""
	end

	local function makeSegmentLabel(seg: SegmentRow, parent: Instance, order: number): TextLabel?
		local kind = seg.kind or "text"
		if kind == "spacer" then
			local flex = Instance.new("Frame")
			flex.Name = "Spacer"
			flex.LayoutOrder = order
			flex.Size = UDim2.new(1, 0, 1, 0)
			flex.BackgroundTransparency = 1
			flex.Parent = parent
			return nil
		end

		local id = seg.id or ("seg_" .. tostring(order))
		local lbl = Instance.new("TextLabel")
		lbl.Name = id
		lbl.LayoutOrder = order
		lbl.Size = UDim2.fromOffset(0, 0)
		lbl.AutomaticSize = Enum.AutomaticSize.XY
		lbl.BackgroundTransparency = 1
		lbl.FontFace = m3Font
		lbl.TextSize = runtimeConfig.TextSize or 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = resolveSegmentText(seg)
		lbl.Parent = parent
		reg(lbl, "TextColor3", if seg.muted then "out" else "fg")
		labelById[id] = { id = id, lbl = lbl, kind = kind }
		return lbl
	end

	local function buildRow(parent: Frame, segments: { SegmentRow }, horizontalAlign: Enum.HorizontalAlignment)
		table.clear(labelById)
		for _, ch in parent:GetChildren() do
			if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
				ch:Destroy()
			end
		end

		local padX = runtimeConfig.PaddingX or 14
		local rowPad = parent:FindFirstChildOfClass("UIPadding")
		if not rowPad then
			rowPad = Instance.new("UIPadding")
			rowPad.Parent = parent
		end
		rowPad.PaddingLeft = UDim.new(0, padX)
		rowPad.PaddingRight = UDim.new(0, padX)

		local rowLayout = parent:FindFirstChildOfClass("UIListLayout")
		if not rowLayout then
			rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
			rowLayout.Parent = parent
		end
		rowLayout.HorizontalAlignment = horizontalAlign
		rowLayout.Padding = UDim.new(0, 10)

		for i, seg in segments do
			makeSegmentLabel(seg, parent, i)
		end
	end

	local function refreshLabels()
		for _, entry in labelById do
			if entry.kind == "clock" then
				entry.lbl.Text = formatClock()
			elseif entry.kind == "version" then
				entry.lbl.Text = formatVersion()
			end
		end
	end

	local function bindClock()
		local clockCfg = runtimeConfig.Clock or {}
		if clockCfg.Enabled == false then
			return
		end
		local interval = math.max(0.25, clockCfg.UpdateInterval or 1)
		local token = clockToken
		task.spawn(function()
			while token == clockToken and footerBar and footerBar.Parent do
				refreshLabels()
				task.wait(interval)
			end
		end)
	end

	local function rebuildFooter()
		local win = ctx.win
		if not win then
			return
		end
		if footerBar then
			footerBar:Destroy()
			footerBar = nil
			topDivider = nil
		end
		clockToken += 1
		table.clear(labelById)

		if runtimeConfig.Enabled == false then
			ctx.FooterHeight = 0
			return
		end

		local height = runtimeConfig.Height or 28
		ctx.FooterHeight = height

		-- CanvasGroup + UICorner clips the footer to the window's bottom curve (a plain
		-- Frame would paint square corners inside the rounded window).
		local wrap = Instance.new("CanvasGroup")
		wrap.Name = "FooterWrap"
		wrap.AnchorPoint = Vector2.new(0, 1)
		wrap.Position = UDim2.new(0, 0, 1, 0)
		wrap.Size = UDim2.new(1, 0, 0, height)
		wrap.BorderSizePixel = 0
		wrap.BackgroundTransparency = 1
		wrap.ZIndex = 68
		wrap.Parent = win
		corner(wrap, winCorner)

		local bar = Instance.new("Frame")
		bar.Name = "Footer"
		bar.Size = UDim2.fromScale(1, 1)
		bar.BorderSizePixel = 0
		bar.ZIndex = 68
		bar.ClipsDescendants = true
		bar.Parent = wrap
		reg(bar, "BackgroundColor3", "inact")
		bar.BackgroundTransparency = runtimeConfig.BackgroundTransparency or 0.35
		footerBar = bar

		if runtimeConfig.ShowTopDivider ~= false then
			local div = Instance.new("Frame")
			div.Name = "TopDivider"
			div.Size = UDim2.new(1, 0, 0, 1)
			div.BorderSizePixel = 0
			div.BackgroundTransparency = 0.55
			div.ZIndex = 69
			div.Parent = bar
			reg(div, "BackgroundColor3", "out")
			topDivider = div
		end

		local layoutMode = runtimeConfig.Layout or "split"
		if layoutMode == "row" then
			buildRow(bar, segmentList(), Enum.HorizontalAlignment.Left)
		else
			local leftSegs: { SegmentRow } = {}
			local rightSegs: { SegmentRow } = {}
			for _, seg in segmentList() do
				if seg.align == "right" then
					table.insert(rightSegs, seg)
				else
					table.insert(leftSegs, seg)
				end
			end

			local left = Instance.new("Frame")
			left.Name = "Left"
			left.Size = UDim2.new(0.5, -8, 1, 0)
			left.Position = UDim2.new(0, 0, 0, 0)
			left.BackgroundTransparency = 1
			left.ZIndex = 70
			left.Parent = bar
			buildRow(left, leftSegs, Enum.HorizontalAlignment.Left)

			local right = Instance.new("Frame")
			right.Name = "Right"
			right.Size = UDim2.new(0.5, -8, 1, 0)
			right.Position = UDim2.new(0.5, 8, 0, 0)
			right.BackgroundTransparency = 1
			right.ZIndex = 70
			right.Parent = bar
			buildRow(right, rightSegs, Enum.HorizontalAlignment.Right)
		end

		bindClock()
		refreshLabels()
	end

	local function setConfig(partial: FooterConfig?)
		if partial then
			deepMerge(runtimeConfig, partial)
		end
		rebuildFooter()
	end

	local function setSegmentText(id: string, text: string)
		local entry = labelById[id]
		if entry then
			entry.lbl.Text = text
		end
		for _, list in { runtimeConfig.Left, runtimeConfig.Right, runtimeConfig.Segments } do
			if list then
				for _, seg in list do
					if seg.id == id then
						seg.text = text
						seg.kind = "text"
					end
				end
			end
		end
	end

	local function setSegmentVisible(id: string, visible: boolean)
		local entry = labelById[id]
		if entry then
			entry.lbl.Visible = visible
		end
	end

	function lib:SetFooterConfig(partial: FooterConfig?)
		setConfig(partial)
	end

	function lib:SetFooterSegmentText(id: string, text: string)
		setSegmentText(id, text)
	end

	function lib:SetFooterSegmentVisible(id: string, visible: boolean)
		setSegmentVisible(id, visible)
	end

	function lib:RefreshFooter()
		refreshLabels()
	end

	ctx.FooterHeight = 0
	ctx.footer = {
		SetConfig = setConfig,
		SetSegmentText = setSegmentText,
		SetSegmentVisible = setSegmentVisible,
		Refresh = refreshLabels,
	} :: FooterController

	rebuildFooter()
end
