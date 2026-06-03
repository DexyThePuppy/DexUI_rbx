--!nonstrict
local Registry = require("../../hub/registry")
local Format = require("./format")

export type HeaderDeps = {
	section: Frame,
	chip: any,
	entry: any?,
	fontWeight: (Enum.FontWeight) -> Font,
	fontLarge: Font,
	textSize: (string) -> number,
	reg: (Instance, string, string) -> (),
	corner: (Instance, number) -> (),
	playFeedback: (string) -> (),
	Players: Players,
	TeleportService: TeleportService,
}

local function build(deps: HeaderDeps)
	local headerSection = deps.section

	local headerRow = Instance.new("Frame")
	headerRow.LayoutOrder = 0
	headerRow.Size = UDim2.new(1, 0, 0, 0)
	headerRow.AutomaticSize = Enum.AutomaticSize.Y
	headerRow.BackgroundTransparency = 1
	headerRow.Parent = headerSection

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "Title"
	titleLbl.Size = UDim2.new(1, -96, 0, 0)
	titleLbl.AutomaticSize = Enum.AutomaticSize.Y
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "Loading experience…"
	titleLbl.FontFace = deps.fontLarge
	titleLbl.TextSize = deps.textSize("lg")
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextWrapped = true
	titleLbl.Parent = headerRow
	deps.reg(titleLbl, "TextColor3", "fg")

	local rejoinBtn = Instance.new("TextButton")
	rejoinBtn.Name = "Rejoin"
	rejoinBtn.Size = UDim2.fromOffset(88, 32)
	rejoinBtn.AnchorPoint = Vector2.new(1, 0)
	rejoinBtn.Position = UDim2.new(1, 0, 0, 0)
	rejoinBtn.Text = "Rejoin"
	rejoinBtn.FontFace = deps.fontWeight(Enum.FontWeight.Medium)
	rejoinBtn.TextSize = deps.textSize("sm")
	rejoinBtn.AutoButtonColor = false
	rejoinBtn.Parent = headerRow
	deps.corner(rejoinBtn, 10)
	deps.reg(rejoinBtn, "BackgroundColor3", "pri")
	deps.reg(rejoinBtn, "TextColor3", "onpri")

	rejoinBtn.MouseButton1Click:Connect(function()
		deps.playFeedback("light")
		local player = deps.Players.LocalPlayer
		if not player then
			return
		end
		pcall(function()
			deps.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
		end)
	end)

	local metaBadgeRow = deps.chip.makeBadgeRow(headerSection, 1, "MetaBadges")

	local function renderMetaBadges(meta: any)
		deps.chip.clearBadgeRow(metaBadgeRow)
		deps.chip.addInfoBadge(metaBadgeRow, string.format("Place %d", meta.placeId))
		deps.chip.addInfoBadge(metaBadgeRow, string.format("Universe %d", meta.universeId))
		if meta.rootPlaceId then
			deps.chip.addInfoBadge(metaBadgeRow, "Root place " .. tostring(meta.rootPlaceId))
		end
		if meta.creatorName then
			deps.chip.addInfoBadge(metaBadgeRow, "By " .. meta.creatorName)
		end
		if meta.playing then
			deps.chip.addInfoBadge(metaBadgeRow, Format.formatNumber(meta.playing) .. " playing")
		end
		if meta.visits then
			deps.chip.addInfoBadge(metaBadgeRow, Format.formatNumber(meta.visits) .. " visits")
		end
		if meta.creatorType then
			deps.chip.addInfoBadge(metaBadgeRow, meta.creatorType)
		end
		if deps.entry and Registry.entryMatchesCurrent(deps.entry) then
			deps.chip.addInfoBadge(metaBadgeRow, "Recognised in hub")
		end
		metaBadgeRow.Visible = metaBadgeRow:FindFirstChild("Badge") ~= nil
	end

	return {
		titleLbl = titleLbl,
		renderMetaBadges = renderMetaBadges,
	}
end

return {
	build = build,
}
