--!nonstrict
export type SectionDeps = {
	corner: (Instance, number) -> (),
	reg: (Instance, string, string) -> (),
}

local function create(parent: Instance, layoutOrder: number, deps: SectionDeps): Frame
	local section = Instance.new("Frame")
	section.Name = "Section"
	section.LayoutOrder = layoutOrder
	section.Size = UDim2.new(1, 0, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BorderSizePixel = 0
	section.Parent = parent
	deps.corner(section, 12)
	deps.reg(section, "BackgroundColor3", "inact")

	local sectionPad = Instance.new("UIPadding")
	sectionPad.PaddingTop = UDim.new(0, 12)
	sectionPad.PaddingBottom = UDim.new(0, 12)
	sectionPad.PaddingLeft = UDim.new(0, 12)
	sectionPad.PaddingRight = UDim.new(0, 12)
	sectionPad.Parent = section

	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.Padding = UDim.new(0, 8)
	sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sectionLayout.Parent = section
	return section
end

return {
	create = create,
}
