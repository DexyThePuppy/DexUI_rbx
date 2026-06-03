--!nonstrict
-- Shared hub grid: scroll host, UIGridLayout, and card interior layout (thumb + title band).

local Config = require("../config")
local G = Config.HubGrid or {}

export type GridSpec = {
	cellW: number,
	cellH: number,
	scrollPad: number,
	cellGap: number,
	inset: number,
	nameH: number,
	listGap: number,
	cardCorner: number,
	thumbCorner: number,
}

export type GridHost = {
	scroll: ScrollingFrame,
	inner: Frame,
	layout: UIGridLayout,
	pad: number,
	maxHeight: number,
	setCount: (n: number) -> (),
}

local DEFAULTS = {
	scrollPad = G.ScrollPad or 8,
	cellGap = G.CellGap or 6,
	inset = G.CardInset or 5,
	nameH = G.NameBand or 22,
	listGap = G.ListGap or 3,
	cardCorner = 10,
	thumbCorner = 8,
}

local function specForCell(cell: { number }): GridSpec
	return {
		cellW = cell[1],
		cellH = cell[2],
		scrollPad = DEFAULTS.scrollPad,
		cellGap = DEFAULTS.cellGap,
		inset = DEFAULTS.inset,
		nameH = DEFAULTS.nameH,
		listGap = DEFAULTS.listGap,
		cardCorner = DEFAULTS.cardCorner,
		thumbCorner = DEFAULTS.thumbCorner,
	}
end

local function thumbHeight(spec: GridSpec): number
	return spec.cellH - spec.inset * 2 - spec.nameH - spec.listGap
end

local function columnCount(innerWidth: number, spec: GridSpec): number
	return math.max(1, math.floor((innerWidth + spec.cellGap) / (spec.cellW + spec.cellGap)))
end

local function estimatedCanvasHeight(count: number, cols: number, spec: GridSpec): number
	local rows = math.max(1, math.ceil(count / cols))
	return spec.scrollPad * 2 + rows * spec.cellH + math.max(0, rows - 1) * spec.cellGap
end

local function createGridHost(
	parent: Instance,
	spec: GridSpec,
	maxHeight: number?,
	corner: (Instance, number) -> UICorner,
	reg: (Instance, string) -> ()
): GridHost
	local pad = spec.scrollPad
	local maxH = maxHeight or 420

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "GridScroll"
	scroll.Size = UDim2.new(1, 0, 0, maxH)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.Parent = parent
	corner(scroll, 12)
	reg(scroll, "BackgroundColor3", "bg")

	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, pad)
	gridPad.PaddingBottom = UDim.new(0, pad)
	gridPad.PaddingLeft = UDim.new(0, pad)
	gridPad.PaddingRight = UDim.new(0, pad)
	gridPad.Parent = scroll

	local inner = Instance.new("Frame")
	inner.Name = "GridInner"
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	inner.BackgroundTransparency = 1
	inner.Parent = scroll

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(spec.cellW, spec.cellH)
	layout.CellPadding = UDim2.fromOffset(spec.cellGap, spec.cellGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = inner

	local function syncViewport(count: number)
		local innerW = math.max(inner.AbsoluteSize.X, spec.cellW)
		local cols = columnCount(innerW, spec)
		local contentH = estimatedCanvasHeight(count, cols, spec)
		scroll.CanvasSize = UDim2.new(0, 0, 0, contentH)
		scroll.Size = UDim2.new(1, 0, 0, math.min(maxH, contentH))
	end

	local host: GridHost = {
		scroll = scroll,
		inner = inner,
		layout = layout,
		pad = pad,
		maxHeight = maxH,
		setCount = syncViewport,
	}

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local h = layout.AbsoluteContentSize.Y + pad * 2
		scroll.CanvasSize = UDim2.new(0, 0, 0, h)
		scroll.Size = UDim2.new(1, 0, 0, math.min(maxH, h))
	end)

	inner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		-- Re-sync when width changes (column wrap).
		local h = layout.AbsoluteContentSize.Y + pad * 2
		if h > 0 then
			scroll.CanvasSize = UDim2.new(0, 0, 0, h)
			scroll.Size = UDim2.new(1, 0, 0, math.min(maxH, h))
		end
	end)

	return host
end

-- Card button sized to the grid cell; returns thumb frame (for image) and name label.
local function createCard(
	parent: Instance,
	spec: GridSpec,
	order: number,
	corner: (Instance, number) -> UICorner
): (TextButton, Frame, ImageLabel, TextLabel)
	local btn = Instance.new("TextButton")
	btn.Name = "Card"
	btn.LayoutOrder = order
	btn.Size = UDim2.fromOffset(spec.cellW, spec.cellH)
	btn.BackgroundTransparency = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ClipsDescendants = true
	btn.Parent = parent
	corner(btn, spec.cardCorner)

	local cardPad = Instance.new("UIPadding")
	cardPad.PaddingTop = UDim.new(0, spec.inset)
	cardPad.PaddingBottom = UDim.new(0, spec.inset)
	cardPad.PaddingLeft = UDim.new(0, spec.inset)
	cardPad.PaddingRight = UDim.new(0, spec.inset)
	cardPad.Parent = btn

	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, spec.listGap)
	stack.Parent = btn

	local thumbH = thumbHeight(spec)
	local thumbWrap = Instance.new("Frame")
	thumbWrap.Name = "Thumb"
	thumbWrap.LayoutOrder = 1
	thumbWrap.Size = UDim2.new(1, 0, 0, thumbH)
	thumbWrap.BackgroundTransparency = 1
	thumbWrap.BorderSizePixel = 0
	thumbWrap.ClipsDescendants = true
	thumbWrap.Parent = btn
	corner(thumbWrap, spec.thumbCorner)

	local thumb = Instance.new("ImageLabel")
	thumb.Name = "Image"
	thumb.Size = UDim2.fromScale(1, 1)
	thumb.BackgroundTransparency = 1
	thumb.ScaleType = Enum.ScaleType.Crop
	thumb.Parent = thumbWrap

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "Title"
	nameLbl.LayoutOrder = 2
	nameLbl.Size = UDim2.new(1, 0, 0, spec.nameH)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextWrapped = false
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.TextYAlignment = Enum.TextYAlignment.Center
	nameLbl.TextXAlignment = Enum.TextXAlignment.Center
	nameLbl.Parent = btn

	return btn, thumbWrap, thumb, nameLbl
end

local function addStateLayer(btn: TextButton, spec: GridSpec, corner: (Instance, number) -> UICorner, reg: (Instance, string) -> ()): Frame
	local state = Instance.new("Frame")
	state.Name = "State"
	state.Size = UDim2.fromScale(1, 1)
	state.BackgroundTransparency = 1
	state.BorderSizePixel = 0
	state.ZIndex = 2
	state.Parent = btn
	corner(state, spec.cardCorner)
	reg(state, "BackgroundColor3", "fg")
	return state
end

return {
	scrollPad = DEFAULTS.scrollPad,
	cellGap = DEFAULTS.cellGap,
	scriptsCell = G.ScriptsCell or { 106, 118 },
	toolsCell = G.ToolsCell or { 110, 120 },
	iconsCell = G.IconsCell or { 76, 70 },
	badgeCell = G.BadgeCell or { 64, 78 },
	badgeIcon = G.BadgeIcon or 40,
	badgeCols = G.BadgeCols or 4,
	inset = DEFAULTS.inset,
	nameH = DEFAULTS.nameH,
	specForCell = specForCell,
	thumbHeight = thumbHeight,
	createGridHost = createGridHost,
	createCard = createCard,
	addStateLayer = addStateLayer,
}
