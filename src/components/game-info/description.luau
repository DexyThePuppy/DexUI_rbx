--!nonstrict
local Format = require("./format")

export type DescriptionDeps = {
	section: Frame,
	chip: any,
	entry: any?,
	curTheme: { bg: Color3, fg: Color3, out: Color3, inact: Color3 },
	m3Font: Font,
	fontWeight: (Enum.FontWeight) -> Font,
	textSize: (string) -> number,
	reg: (Instance, string, string) -> (),
}

local VIP_BADGE_RED = Color3.fromRGB(210, 48, 48)
local VIP_BADGE_ON = Color3.fromRGB(255, 255, 255)
local BADGE_VERIFIED = Color3.fromRGB(0, 162, 255)

local function build(deps: DescriptionDeps)
	local descSection = deps.section

	local settingsRow = deps.chip.makeBadgeRow(descSection, 0, "Settings")

	local function addSettingBadge(label: string, bg: Color3, fg: Color3)
		deps.chip.addInfoBadge(settingsRow, label, bg, fg)
	end

	local function renderGameSettings(meta: any)
		deps.chip.clearBadgeRow(settingsRow)
		if meta.createVipServersAllowed == true or meta.privateServersEnabled == true then
			addSettingBadge("VIP server", VIP_BADGE_RED, VIP_BADGE_ON)
		end
		if meta.copyingAllowed == true then
			addSettingBadge("Copying on", deps.curTheme.inact, deps.curTheme.fg)
		end
		if meta.creatorVerified == true then
			addSettingBadge("Verified", BADGE_VERIFIED, VIP_BADGE_ON)
		end
		if meta.universeAvatarType == "MorphToR15" then
			addSettingBadge("R15", deps.curTheme.bg, deps.curTheme.out)
		elseif meta.universeAvatarType == "MorphToR6" then
			addSettingBadge("R6", deps.curTheme.bg, deps.curTheme.out)
		end
		settingsRow.Visible = settingsRow:FindFirstChild("Badge") ~= nil
	end

	local statsBadgeRow = deps.chip.makeBadgeRow(descSection, 1, "StatsBadges")

	local function addStatBadges(meta: any)
		deps.chip.clearBadgeRow(statsBadgeRow)
		if meta.genre then
			for segment in string.gmatch(meta.genre, "([^·]+)") do
				local trimmed = string.match(segment, "^%s*(.-)%s*$")
				if trimmed and trimmed ~= "" then
					deps.chip.addInfoBadge(statsBadgeRow, trimmed)
				end
			end
		end
		if meta.maxPlayers then
			deps.chip.addInfoBadge(statsBadgeRow, meta.maxPlayers .. " players / server")
		end
		if meta.upVotes then
			local down = meta.downVotes or 0
			local total = meta.upVotes + down
			local pct = if total > 0 then math.floor(meta.upVotes / total * 100 + 0.5) else 0
			deps.chip.addInfoBadge(statsBadgeRow, string.format("%s likes (%d%%)", Format.formatNumber(meta.upVotes), pct))
		end
		if meta.favoritedCount then
			deps.chip.addInfoBadge(statsBadgeRow, Format.formatNumber(meta.favoritedCount) .. " favorites")
		end
		if meta.badgeCount and meta.badgeCount > 0 then
			local label = if meta.badgeCountAtLeast
				then tostring(meta.badgeCount) .. "+ badges"
				else tostring(meta.badgeCount) .. " badges"
			if meta.badgesClaimed then
				label ..= string.format(" (%d claimed)", meta.badgesClaimed)
			end
			deps.chip.addInfoBadge(statsBadgeRow, label)
		end
		if meta.groupMemberCount then
			deps.chip.addInfoBadge(statsBadgeRow, Format.formatNumber(meta.groupMemberCount) .. " group members")
		end
		local created = Format.formatShortDate(meta.created)
		if created then
			deps.chip.addInfoBadge(statsBadgeRow, "Created " .. created)
		end
		local updated = Format.formatShortDate(meta.updated)
		if updated and updated ~= created then
			deps.chip.addInfoBadge(statsBadgeRow, "Updated " .. updated)
		end
		statsBadgeRow.Visible = statsBadgeRow:FindFirstChild("Badge") ~= nil
	end

	local bodyLbl = Instance.new("TextLabel")
	bodyLbl.LayoutOrder = 2
	bodyLbl.Size = UDim2.new(1, 0, 0, 0)
	bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
	bodyLbl.BackgroundTransparency = 1
	bodyLbl.Text = "Fetching name, description, and thumbnails from Roblox…"
	bodyLbl.FontFace = deps.m3Font
	bodyLbl.TextSize = deps.textSize("md")
	bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
	bodyLbl.TextWrapped = true
	bodyLbl.LineHeight = 1.15
	bodyLbl.Parent = descSection
	deps.reg(bodyLbl, "TextColor3", "fg")

	local extraBadgeRow = deps.chip.makeBadgeRow(descSection, 3, "ExtraBadges")

	local function renderExtraBadges(meta: any)
		deps.chip.clearBadgeRow(extraBadgeRow)
		if meta.serverLabel then
			deps.chip.addInfoBadge(extraBadgeRow, meta.serverLabel)
		end
		if meta.placeVersion then
			deps.chip.addInfoBadge(extraBadgeRow, "Place v" .. tostring(meta.placeVersion))
		end
		if meta.jobId then
			deps.chip.addInfoBadge(extraBadgeRow, "Job " .. string.sub(meta.jobId, 1, 8) .. "…")
		end
		if meta.canonicalPath then
			deps.chip.addInfoBadge(extraBadgeRow, "roblox.com" .. meta.canonicalPath)
		end
		if deps.entry then
			deps.chip.addInfoBadge(extraBadgeRow, "Hub script: " .. deps.entry.script)
		end
		extraBadgeRow.Visible = extraBadgeRow:FindFirstChild("Badge") ~= nil
	end

	local function showThumbnailWarning()
		deps.chip.clearBadgeRow(extraBadgeRow)
		deps.chip.addInfoBadge(extraBadgeRow, "Thumbnails could not load")
		extraBadgeRow.Visible = true
	end

	return {
		bodyLbl = bodyLbl,
		renderGameSettings = renderGameSettings,
		addStatBadges = addStatBadges,
		renderExtraBadges = renderExtraBadges,
		showThumbnailWarning = showThumbnailWarning,
	}
end

return {
	build = build,
}
