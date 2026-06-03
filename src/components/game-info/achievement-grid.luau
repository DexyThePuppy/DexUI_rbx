--!nonstrict
local GameMetadata = require("../../hub/game-metadata")

export type AchievementGridDeps = {
	section: Frame,
	block: Frame,
	heading: TextLabel?,
	Grid: any,
	gridDeps: any,
	curTheme: { fg: Color3, out: Color3 },
	m3Font: Font,
	fontWeight: (Enum.FontWeight) -> Font,
	textSize: (string) -> number,
	reg: (Instance, string, string) -> (),
	corner: (Instance, number) -> (),
	tooltip: any?,
}

local CLAIMED_GREEN = Color3.fromRGB(56, 170, 92)
local VIP_BADGE_ON = Color3.fromRGB(255, 255, 255)

local function build(deps: AchievementGridDeps)
	local card = deps.section
	local block = deps.block
	block.Visible = false

	local badgesStatusLbl = Instance.new("TextLabel")
	badgesStatusLbl.LayoutOrder = 0
	badgesStatusLbl.Size = UDim2.new(1, 0, 0, 0)
	badgesStatusLbl.AutomaticSize = Enum.AutomaticSize.Y
	badgesStatusLbl.BackgroundTransparency = 1
	badgesStatusLbl.Text = ""
	badgesStatusLbl.FontFace = deps.m3Font
	badgesStatusLbl.TextSize = deps.textSize("sm")
	badgesStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
	badgesStatusLbl.TextWrapped = true
	badgesStatusLbl.Visible = false
	badgesStatusLbl.Parent = card
	deps.reg(badgesStatusLbl, "TextColor3", "out")

	local badgeGrid = Instance.new("Frame")
	badgeGrid.Name = "BadgeGrid"
	badgeGrid.LayoutOrder = 1
	badgeGrid.Size = UDim2.new(1, 0, 0, 0)
	badgeGrid.AutomaticSize = Enum.AutomaticSize.Y
	badgeGrid.BackgroundTransparency = 1
	badgeGrid.Parent = card

	local badgeMount = deps.Grid.buildInline(badgeGrid, deps.gridDeps)

	local function badgeThumbUri(badge: any): string?
		if type(badge.iconUri) == "string" and badge.iconUri ~= "" then
			return badge.iconUri
		end
		if type(badge.id) == "number" then
			return GameMetadata.resolveLoadableUri(
				string.format("rbxthumb://type=BadgeIcon&id=%d&w=150&h=150", badge.id)
			)
		end
		return nil
	end

	local function clearBadgeGrid()
		for _, ch in badgeGrid:GetChildren() do
			if ch:IsA("TextButton") then
				if deps.tooltip then
					deps.tooltip.detach(ch)
				end
				ch:Destroy()
			end
		end
	end

	local function renderBadgeGrid(badges: { any }, badgeAtLeast: boolean?)
		clearBadgeGrid()
		local count = if badges then #badges else 0
		if count == 0 then
			block.Visible = false
			return
		end
		block.Visible = true

		local claimed = 0
		for _, badge in badges do
			if badge.claimed then
				claimed += 1
			end
		end

		local totalLabel = if badgeAtLeast then tostring(count) .. "+" else tostring(count)
		local headingText = string.format("Badges · %d / %s claimed", claimed, totalLabel)
		if deps.heading then
			deps.heading.Text = headingText
		end

		for i, badge in badges do
			local gridCard = badgeMount.addCard(i)
			gridCard.root.Name = "Badge" .. tostring(badge.id)
			gridCard.root.BackgroundTransparency = if badge.claimed then 0.35 else 0.55
			deps.reg(gridCard.root, "BackgroundColor3", "bg")

			gridCard.image.ImageTransparency = if badge.claimed then 0 else 0.45
			gridCard.image.Active = false
			gridCard.image.Selectable = false
			local uri = badgeThumbUri(badge)
			if uri then
				gridCard.image.Image = uri
			end

			if badge.claimed then
				local tick = Instance.new("TextLabel")
				tick.Name = "Claimed"
				tick.Size = UDim2.fromOffset(16, 16)
				tick.Position = UDim2.new(1, -3, 0, 3)
				tick.AnchorPoint = Vector2.new(1, 0)
				tick.BackgroundColor3 = CLAIMED_GREEN
				tick.Text = "✓"
				tick.FontFace = deps.fontWeight(Enum.FontWeight.Bold)
				tick.TextSize = deps.textSize("sm")
				tick.TextColor3 = VIP_BADGE_ON
				tick.ZIndex = 5
				tick.Active = false
				tick.Selectable = false
				tick.Parent = gridCard.thumb
				deps.corner(tick, 999)
			end

			gridCard.title.Text = badge.name
			gridCard.title.FontFace = deps.m3Font
			gridCard.title.TextSize = deps.textSize("sm")
			gridCard.title.TextWrapped = true
			gridCard.title.TextTruncate = Enum.TextTruncate.AtEnd
			gridCard.title.TextColor3 = if badge.claimed then deps.curTheme.fg else deps.curTheme.out
			gridCard.title.Active = false
			gridCard.title.Selectable = false

			if deps.tooltip then
				deps.tooltip.attach(gridCard.root, function()
					return GameMetadata.buildBadgeTooltipContent(badge)
				end)
			end
		end

		task.defer(badgeMount.sync)
	end

	return {
		block = block,
		renderBadgeGrid = renderBadgeGrid,
	}
end

return {
	build = build,
}
