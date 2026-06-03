--!nonstrict
-- Stacked section blocks matching AddSection + card rows (Visuals tab layout).
-- Title sits above the inact card, not inside it.
export type SectionOpts = {
	title: string?,
	name: string?,
}

export type SectionDeps = {
	corner: (Instance, number) -> (),
	reg: (Instance, string, string) -> (),
	fontLarge: Font?,
	textSize: ((string) -> number)?,
	padding: number?,
	innerGap: number?,
	cornerRadius: number?,
	titleGap: number?,
}

export type SectionResult = {
	block: Frame,
	card: Frame,
	heading: TextLabel?,
}

local TITLE_HEIGHT = 28

local function create(parent: Instance, layoutOrder: number, deps: SectionDeps, opts: SectionOpts?): SectionResult
	local pad = deps.padding or 12
	local innerGap = deps.innerGap or 8
	local radius = deps.cornerRadius or 12
	local titleGap = deps.titleGap or 6

	local block = Instance.new("Frame")
	block.Name = if opts and opts.name then opts.name else "SectionBlock"
	block.LayoutOrder = layoutOrder
	block.Size = UDim2.new(1, 0, 0, 0)
	block.AutomaticSize = Enum.AutomaticSize.Y
	block.BackgroundTransparency = 1
	block.BorderSizePixel = 0
	block.Parent = parent

	local blockLayout = Instance.new("UIListLayout")
	blockLayout.Padding = UDim.new(0, titleGap)
	blockLayout.SortOrder = Enum.SortOrder.LayoutOrder
	blockLayout.Parent = block

	local heading: TextLabel? = nil
	if opts and opts.title and opts.title ~= "" and deps.fontLarge and deps.textSize then
		heading = Instance.new("TextLabel")
		heading.Name = "SectionTitle"
		heading.LayoutOrder = 0
		heading.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
		heading.BackgroundTransparency = 1
		heading.Text = opts.title
		heading.FontFace = deps.fontLarge
		heading.TextSize = deps.textSize("lg")
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.Parent = block
		deps.reg(heading, "TextColor3", "pri")
	end

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.LayoutOrder = 1
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BorderSizePixel = 0
	card.Parent = block
	deps.corner(card, radius)
	deps.reg(card, "BackgroundColor3", "inact")

	local sectionPad = Instance.new("UIPadding")
	sectionPad.PaddingTop = UDim.new(0, pad)
	sectionPad.PaddingBottom = UDim.new(0, pad)
	sectionPad.PaddingLeft = UDim.new(0, pad)
	sectionPad.PaddingRight = UDim.new(0, pad)
	sectionPad.Parent = card

	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.Padding = UDim.new(0, innerGap)
	sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sectionLayout.Parent = card

	return {
		block = block,
		card = card,
		heading = heading,
	}
end

return {
	create = create,
}
