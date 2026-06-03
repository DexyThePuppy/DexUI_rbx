--!nonstrict
-- Shared stacked section cards (Game Info, Media, etc.).
export type SectionOpts = {
	title: string?,
	name: string?,
}

export type SectionDeps = {
	corner: (Instance, number) -> (),
	reg: (Instance, string, string) -> (),
	fontWeight: ((Enum.FontWeight) -> Font)?,
	textSize: ((string) -> number)?,
	padding: number?,
	innerGap: number?,
	cornerRadius: number?,
}

local function create(parent: Instance, layoutOrder: number, deps: SectionDeps, opts: SectionOpts?): (Frame, number)
	local pad = deps.padding or 12
	local innerGap = deps.innerGap or 8
	local radius = deps.cornerRadius or 12

	local section = Instance.new("Frame")
	section.Name = if opts and opts.name then opts.name else "Section"
	section.LayoutOrder = layoutOrder
	section.Size = UDim2.new(1, 0, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BorderSizePixel = 0
	section.Parent = parent
	deps.corner(section, radius)
	deps.reg(section, "BackgroundColor3", "inact")

	local sectionPad = Instance.new("UIPadding")
	sectionPad.PaddingTop = UDim.new(0, pad)
	sectionPad.PaddingBottom = UDim.new(0, pad)
	sectionPad.PaddingLeft = UDim.new(0, pad)
	sectionPad.PaddingRight = UDim.new(0, pad)
	sectionPad.Parent = section

	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.Padding = UDim.new(0, innerGap)
	sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sectionLayout.Parent = section

	local layoutBase = 0
	if opts and opts.title and opts.title ~= "" and deps.fontWeight and deps.textSize then
		local heading = Instance.new("TextLabel")
		heading.Name = "SectionTitle"
		heading.LayoutOrder = 0
		heading.Size = UDim2.new(1, 0, 0, 20)
		heading.BackgroundTransparency = 1
		heading.Text = opts.title
		heading.FontFace = deps.fontWeight(Enum.FontWeight.Medium)
		heading.TextSize = deps.textSize("md")
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.Parent = section
		deps.reg(heading, "TextColor3", "pri")
		layoutBase = 1
	end

	return section, layoutBase
end

return {
	create = create,
}
