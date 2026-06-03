--!nonstrict
local Registry = require("../../hub/registry")
local GameMetadata = require("../../hub/game-metadata")
local Services = require("../../services")

local Section = require("./section")
local ChipBadges = require("./chip-badges")
local Header = require("./header")
local Description = require("./description")
local Carousel = require("./carousel")
local AchievementGrid = require("./achievement-grid")
local Servers = require("./servers")
local Format = require("./format")

local function mount(ctx)
	local lib = ctx.lib
	local curTheme = ctx.theme
	local reg = ctx.reg
	local corner = ctx.corner
	local m3Font = ctx.m3Font
	local beginCardRow = ctx.beginCardRow
	local fontWeight = ctx.fontWeight
	local onHeartbeat = ctx.onHeartbeat
	local playFeedback = ctx.playFeedback
	local trySetClipboard = ctx.trySetClipboard
	local tooltip = ctx.tooltip
	local textSize = ctx.textSize
	local Grid = ctx.grid
	local MEDIA_PAGE_SIZE = ctx.MEDIA_PAGE_SIZE
	local MEDIA_PAGE_COUNT = ctx.MEDIA_PAGE_COUNT
	local ContentProvider = Services.ContentProvider or game:GetService("ContentProvider")
	local Players = game:GetService("Players")
	local TeleportService = game:GetService("TeleportService")

	local entry = Registry.findForCurrentGame()
	local sectionDeps = { corner = corner, reg = reg }

	local holder = Instance.new("Frame")
	holder.Name = "GameInfo"
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = beginCardRow(nil, true)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 16)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	local chip = ChipBadges.create({
		lib = lib,
		curTheme = curTheme,
		corner = corner,
		fontWeight = fontWeight,
		textSize = textSize,
		playFeedback = playFeedback,
		trySetClipboard = trySetClipboard,
		tooltip = tooltip,
	})

	local headerSection = Section.create(holder, 0, sectionDeps)
	local header = Header.build({
		section = headerSection,
		chip = chip,
		entry = entry,
		fontWeight = fontWeight,
		textSize = textSize,
		reg = reg,
		corner = corner,
		playFeedback = playFeedback,
		Players = Players,
		TeleportService = TeleportService,
	})

	local carouselSection = Section.create(holder, 1, sectionDeps)
	local carousel = Carousel.build({
		section = carouselSection,
		holder = holder,
		curTheme = curTheme,
		m3Font = m3Font,
		textSize = textSize,
		reg = reg,
		corner = corner,
		playFeedback = playFeedback,
		onHeartbeat = onHeartbeat,
		ContentProvider = ContentProvider,
	})

	local descSection = Section.create(holder, 2, sectionDeps)
	local description = Description.build({
		section = descSection,
		chip = chip,
		entry = entry,
		curTheme = curTheme,
		m3Font = m3Font,
		fontWeight = fontWeight,
		textSize = textSize,
		reg = reg,
	})

	local badgesSection = Section.create(holder, 3, sectionDeps)
	local achievementGrid = AchievementGrid.build({
		section = badgesSection,
		Grid = Grid,
		gridDeps = { corner = corner, reg = reg, fontWeight = fontWeight, textSize = textSize },
		curTheme = curTheme,
		m3Font = m3Font,
		fontWeight = fontWeight,
		textSize = textSize,
		reg = reg,
		corner = corner,
		tooltip = tooltip,
	})

	local serversSection = Section.create(holder, 4, sectionDeps)
	local servers = Servers.build({
		section = serversSection,
		curTheme = curTheme,
		m3Font = m3Font,
		fontWeight = fontWeight,
		textSize = textSize,
		reg = reg,
		corner = corner,
		playFeedback = playFeedback,
		tooltip = tooltip,
		Players = Players,
		TeleportService = TeleportService,
		pageSize = MEDIA_PAGE_SIZE,
		pageCount = MEDIA_PAGE_COUNT,
	})

	task.spawn(function()
		local ok, meta = pcall(GameMetadata.fetchCurrentGameMetadata)
		if not ok or type(meta) ~= "table" or not holder.Parent then
			header.titleLbl.Text = "Current experience"
			description.bodyLbl.Text = "Could not load game metadata. Check HttpService / executor request support."
			servers.statusLbl.Text = "Public servers unavailable."
			achievementGrid.section.Visible = false
			return
		end

		local titleText = if entry then entry.name else meta.name
		if entry and Registry.entryMatchesCurrent(entry) then
			titleText = entry.name
		end
		header.titleLbl.Text = titleText

		header.renderMetaBadges(meta)
		description.addStatBadges(meta)

		local bodyText = if entry and entry.description and entry.description ~= ""
			then entry.description
			else (meta.description or "No description returned for this universe.")

		description.renderGameSettings(meta)
		description.bodyLbl.Text = bodyText

		local images: { string } = {}
		if entry and entry.images then
			for _, img in entry.images do
				local resolved = Format.formatImage(img)
				if resolved then
					table.insert(images, resolved)
				end
			end
		end
		for _, img in meta.images do
			table.insert(images, img)
		end
		if #images == 0 then
			local fallback = GameMetadata.resolveLoadableUri(GameMetadata.placeThumb(meta.placeId, 768, 432))
			if fallback then
				table.insert(images, fallback)
			end
		end

		carousel.rebuildCarousel(images)
		achievementGrid.renderBadgeGrid(meta.badges, meta.badgeCountAtLeast)

		if not carousel.hasSlides() and #images > 0 then
			description.showThumbnailWarning()
		else
			description.renderExtraBadges(meta)
		end

		local joinPlaceId = meta.rootPlaceId or meta.placeId
		local serverList, serversErr = GameMetadata.fetchPublicServers(joinPlaceId)
		servers.setPublicServers(serverList, joinPlaceId, serversErr)
	end)
end

return mount
