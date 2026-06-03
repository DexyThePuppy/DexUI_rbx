--!nonstrict

local Config = require("../../config")

local Registry = require("../../hub/registry")

local GameMetadata = require("../../hub/game-metadata")

local Services = require("../../services")



local Section = require("../../core/panel-section")

local ChipBadges = require("./chip-badges")

local Header = require("./header")

local Description = require("./description")

local Carousel = require("./carousel")

local AchievementGrid = require("./achievement-grid")

local Servers = require("./servers")

local Format = require("./format")



local GI = Config.SectionLayout or Config.GameInfo or {}

local SECTION_GAP: number = GI.SectionGap or 12

local SECTION_PAD: number = GI.SectionPadding or 14

local INNER_GAP: number = GI.InnerGap or 8

local SECTION_CORNER: number = GI.SectionCorner or 12

local TITLE_GAP: number = GI.TitleGap or 6



local function mount(ctx)

	local lib = ctx.lib

	local curTheme = ctx.theme

	local reg = ctx.reg

	local corner = ctx.corner

	local m3Font = ctx.m3Font

	local fontEmphasis = ctx.fontEmphasis
	local fontTitle = ctx.fontTitle

	local onHeartbeat = ctx.onHeartbeat

	local playFeedback = ctx.playFeedback

	local trySetClipboard = ctx.trySetClipboard

	local tooltip = ctx.tooltip

	local textSize = ctx.textSize

	local Grid = ctx.grid

	local nextCardItemOrder = ctx.nextCardItemOrder

	local MEDIA_PAGE_SIZE = ctx.MEDIA_PAGE_SIZE

	local MEDIA_PAGE_COUNT = ctx.MEDIA_PAGE_COUNT

	local ContentProvider = Services.ContentProvider or game:GetService("ContentProvider")

	local Players = game:GetService("Players")

	local TeleportService = game:GetService("TeleportService")



	local entry = Registry.findForCurrentGame()

	local sectionDeps = {

		corner = corner,

		reg = reg,

		fontTitle = fontTitle,

		textSize = textSize,

		padding = SECTION_PAD,

		innerGap = INNER_GAP,

		cornerRadius = SECTION_CORNER,

		titleGap = TITLE_GAP,

	}



	local holder = Instance.new("Frame")

	holder.Name = "GameInfo"

	holder.LayoutOrder = nextCardItemOrder()

	holder.Size = UDim2.new(1, 0, 0, 0)

	holder.AutomaticSize = Enum.AutomaticSize.Y

	holder.BackgroundTransparency = 1

	holder.Parent = lib.CurrentBuildContainer



	local layout = Instance.new("UIListLayout")

	layout.Padding = UDim.new(0, SECTION_GAP)

	layout.SortOrder = Enum.SortOrder.LayoutOrder

	layout.Parent = holder



	local chip = ChipBadges.create({

		lib = lib,

		curTheme = curTheme,

		corner = corner,

		fontEmphasis = fontEmphasis,

		textSize = textSize,

		playFeedback = playFeedback,

		trySetClipboard = trySetClipboard,

		tooltip = tooltip,

	})



	local overview = Section.create(holder, 0, sectionDeps, {

		name = "Overview",

		title = "Overview",

	})

	local header = Header.build({

		section = overview.card,

		chip = chip,

		entry = entry,

		fontEmphasis = fontEmphasis,

		fontTitle = fontTitle,

		textSize = textSize,

		reg = reg,

		corner = corner,

		playFeedback = playFeedback,

		Players = Players,

		TeleportService = TeleportService,

	})



	local gallery = Section.create(holder, 1, sectionDeps, {

		name = "Gallery",

		title = "Gallery",

	})

	local carousel = Carousel.build({

		section = gallery.card,

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



	local about = Section.create(holder, 2, sectionDeps, {

		name = "About",

		title = "About",

	})

	local description = Description.build({

		section = about.card,

		chip = chip,

		entry = entry,

		curTheme = curTheme,

		m3Font = m3Font,

		fontEmphasis = fontEmphasis,

		textSize = textSize,

		reg = reg,

	})



	local badgesBlock = Section.create(holder, 3, sectionDeps, {

		name = "Badges",

		title = "Badges",

	})

	local achievementGrid = AchievementGrid.build({

		section = badgesBlock.card,

		block = badgesBlock.block,

		heading = badgesBlock.heading,

		Grid = Grid,

		gridDeps = { corner = corner, reg = reg, fontEmphasis = fontEmphasis, textSize = textSize },

		curTheme = curTheme,

		m3Font = m3Font,

		fontTitle = fontTitle,

		textSize = textSize,

		reg = reg,

		corner = corner,

		tooltip = tooltip,

	})



	local serversBlock = Section.create(holder, 4, sectionDeps, {

		name = "Servers",

		title = "Public servers",

	})

	local servers = Servers.build({

		section = serversBlock.card,

		curTheme = curTheme,

		m3Font = m3Font,

		fontEmphasis = fontEmphasis,

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

			achievementGrid.block.Visible = false

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

