--!nonstrict
-- Modular grid layout: card cells (thumb + title), responsive columns, scroll or inline hosts.
-- Reusable anywhere in DexUI (tabs, panels, hubs, game info, etc.).

local Config = require("../config")
local G = Config.Grid or Config.HubGrid or {}

export type GridSpec = {
	cellW: number,
	cellH: number,
	scrollPad: number,
	cellGap: number,
	inset: number,
	nameH: number,
	gapThumbTitle: number,
	cardCorner: number,
	thumbCorner: number,
	maxViewport: number,
	thumbScale: Enum.ScaleType?,
	thumbFillBackground: boolean?,
	thumbFillToken: string?,
	thumbSquare: boolean?,
	thumbPad: number?,
}

export type CardParts = {
	root: TextButton,
	thumb: CanvasGroup,
	image: ImageLabel,
	title: TextLabel,
	state: Frame,
}

export type GridMount = {
	inner: Frame,
	layout: UIGridLayout,
	spec: GridSpec,
	scroll: ScrollingFrame?,
	addCard: (order: number) -> CardParts,
	sync: () -> (),
}

local SPEC: GridSpec = {
	cellW = (G.Cell and G.Cell[1]) or 96,
	cellH = (G.Cell and G.Cell[2]) or 104,
	scrollPad = G.ScrollPad or 6,
	cellGap = G.CellGap or 8,
	inset = G.CardInset or 4,
	nameH = G.NameBand or 20,
	gapThumbTitle = G.GapThumbTitle or 2,
	cardCorner = G.CardCorner or 10,
	thumbCorner = G.ThumbCorner or 8,
	maxViewport = G.MaxViewport or 320,
	thumbFillBackground = G.ThumbFillBackground ~= false,
	thumbFillToken = G.ThumbBackground or "bg",
}

local function thumbHeight(spec: GridSpec): number
	return spec.cellH - spec.inset * 2 - spec.nameH - spec.gapThumbTitle
end

local function columnCount(viewportW: number, spec: GridSpec): number
	local innerW = math.max(0, viewportW - spec.scrollPad * 2)
	return math.max(1, math.floor((innerW + spec.cellGap) / (spec.cellW + spec.cellGap)))
end

export type GridDeps = {
	corner: (Instance, number) -> UICorner,
	reg: (Instance, string, string) -> (),
	fontWeight: (weight: Enum.FontWeight) -> Font,
	textSize: (tier: string) -> number,
}

local function bindLayout(
	mount: GridMount,
	viewport: GuiObject,
	deps: GridDeps
)
	local spec = mount.spec
	local layout = mount.layout
	local inner = mount.inner
	local scroll = mount.scroll
	local pad = spec.scrollPad

	local function applyMetrics()
		local viewW = if scroll then scroll.AbsoluteSize.X else viewport.AbsoluteSize.X
		if viewW < 4 then
			return
		end
		local cols = columnCount(viewW, spec)
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.FillDirectionMaxCells = cols

		local contentY = layout.AbsoluteContentSize.Y
		if contentY < 1 then
			contentY = spec.cellH
		end
		inner.Size = UDim2.new(1, 0, 0, contentY)

		if scroll then
			local totalH = contentY + pad * 2
			scroll.CanvasSize = UDim2.new(0, 0, 0, totalH)
			scroll.Size = UDim2.new(1, 0, 0, math.min(spec.maxViewport, totalH))
		end
	end

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(applyMetrics)
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyMetrics)

	mount.sync = applyMetrics
end

local function createCard(
	parent: Instance,
	spec: GridSpec,
	order: number,
	deps: GridDeps
): CardParts
	local inset = spec.inset
	local innerW = spec.cellW - inset * 2
	local maxThumbH = thumbHeight(spec)
	local thumbW = innerW
	local thumbH = maxThumbH
	if spec.thumbSquare then
		local side = math.min(innerW, maxThumbH)
		thumbW = side
		thumbH = side
	end

	local btn = Instance.new("TextButton")
	btn.Name = "Card"
	btn.LayoutOrder = order
	btn.BackgroundTransparency = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ClipsDescendants = true
	btn.Parent = parent
	deps.corner(btn, spec.cardCorner)

	local thumbX = if spec.thumbSquare then inset + math.floor((innerW - thumbW) / 2) else inset
	local thumb = Instance.new("CanvasGroup")
	thumb.Name = "Thumb"
	thumb.Position = UDim2.fromOffset(thumbX, inset)
	thumb.Size = UDim2.fromOffset(thumbW, thumbH)
	thumb.BackgroundTransparency = 1
	thumb.BorderSizePixel = 0
	thumb.GroupTransparency = 0
	thumb.ZIndex = 1
	thumb.Parent = btn
	deps.corner(thumb, spec.thumbCorner)

	if spec.thumbFillBackground then
		thumb.BackgroundTransparency = 0
		deps.reg(thumb, "BackgroundColor3", spec.thumbFillToken or "bg")
	end

	local thumbPad = spec.thumbPad or 0
	if thumbPad > 0 then
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, thumbPad)
		pad.PaddingBottom = UDim.new(0, thumbPad)
		pad.PaddingLeft = UDim.new(0, thumbPad)
		pad.PaddingRight = UDim.new(0, thumbPad)
		pad.Parent = thumb
	end

	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.ScaleType = spec.thumbScale or Enum.ScaleType.Crop
	image.ZIndex = 2
	image.Parent = thumb

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0, 1)
	title.Position = UDim2.new(0, inset, 1, -inset)
	title.Size = UDim2.new(1, -inset * 2, 0, spec.nameH)
	title.BackgroundTransparency = 1
	title.Text = ""
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 3
	title.Parent = btn

	local state = Instance.new("Frame")
	state.Name = "State"
	state.Size = UDim2.fromScale(1, 1)
	state.BackgroundTransparency = 1
	state.BorderSizePixel = 0
	state.ZIndex = 4
	state.Parent = btn
	deps.corner(state, spec.cardCorner)
	deps.reg(state, "BackgroundColor3", "fg")

	return {
		root = btn,
		thumb = thumb,
		image = image,
		title = title,
		state = state,
	}
end

local function buildScroll(parent: Instance, deps: GridDeps, maxHeight: number?): GridMount
	local spec = table.clone(SPEC) :: GridSpec
	if maxHeight then
		spec.maxViewport = maxHeight
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "GridScroll"
	scroll.Size = UDim2.new(1, 0, 0, spec.cellH + spec.scrollPad * 2)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.ClipsDescendants = true
	scroll.Parent = parent

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, spec.scrollPad)
	pad.PaddingBottom = UDim.new(0, spec.scrollPad)
	pad.PaddingLeft = UDim.new(0, spec.scrollPad)
	pad.PaddingRight = UDim.new(0, spec.scrollPad)
	pad.Parent = scroll

	local inner = Instance.new("Frame")
	inner.Name = "GridInner"
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.BackgroundTransparency = 1
	inner.BorderSizePixel = 0
	inner.Parent = scroll

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(spec.cellW, spec.cellH)
	layout.CellPadding = UDim2.fromOffset(spec.cellGap, spec.cellGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = inner

	local mount: GridMount = {
		inner = inner,
		layout = layout,
		spec = spec,
		scroll = scroll,
		addCard = function(order: number)
			return createCard(inner, spec, order, deps)
		end,
		sync = function() end,
	}

	bindLayout(mount, scroll, deps)
	return mount
end

local function buildInline(parent: Instance, deps: GridDeps): GridMount
	local spec = table.clone(SPEC) :: GridSpec
	spec.thumbScale = Enum.ScaleType.Fit
	spec.thumbSquare = true
	spec.thumbPad = 4

	local layout = Instance.new("UIGridLayout")
	layout.Name = "GridLayout"
	layout.CellSize = UDim2.fromOffset(spec.cellW, spec.cellH)
	layout.CellPadding = UDim2.fromOffset(spec.cellGap, spec.cellGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = parent

	local mount: GridMount = {
		inner = parent,
		layout = layout,
		spec = spec,
		scroll = nil,
		addCard = function(order: number)
			return createCard(parent, spec, order, deps)
		end,
		sync = function() end,
	}

	bindLayout(mount, parent, deps)
	return mount
end

local function buildSection(
	holderParent: Instance,
	deps: GridDeps,
	opts: {
		title: string?,
		maxHeight: number?,
	}
): (Frame, GridMount)
	local holder = Instance.new("Frame")
	holder.Name = "GridSection"
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = holderParent

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder

	local order = 0
	if opts.title and opts.title ~= "" then
		order += 1
		local header = Instance.new("TextLabel")
		header.Name = "Header"
		header.LayoutOrder = order
		header.Size = UDim2.new(1, 0, 0, 0)
		header.AutomaticSize = Enum.AutomaticSize.Y
		header.BackgroundTransparency = 1
		header.Text = opts.title
		header.FontFace = deps.fontWeight(Enum.FontWeight.Medium)
		header.TextSize = deps.textSize("sm")
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextWrapped = true
		header.Parent = holder
		deps.reg(header, "TextColor3", "pri")
	end

	local gridHost = Instance.new("Frame")
	gridHost.Name = "GridHost"
	gridHost.LayoutOrder = order + 1
	gridHost.Size = UDim2.new(1, 0, 0, 0)
	gridHost.AutomaticSize = Enum.AutomaticSize.Y
	gridHost.BackgroundTransparency = 1
	gridHost.Parent = holder

	local mount = buildScroll(gridHost, deps, opts.maxHeight)
	return holder, mount
end

return {
	spec = SPEC,
	thumbHeight = thumbHeight,
	columnCount = columnCount,
	createCard = createCard,
	buildScroll = buildScroll,
	buildInline = buildInline,
	buildSection = buildSection,
}
