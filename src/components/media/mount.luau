--!nonstrict
local Config = require("../../config")
local Section = require("../../core/panel-section")
local Player = require("./player")
local Catalog = require("./catalog")

local SL = Config.SectionLayout or Config.GameInfo or {}

local function mount(ctx)
	local lib = ctx.lib
	local curTheme = ctx.theme
	local reg = ctx.reg
	local tween = ctx.tween
	local corner = ctx.corner
	local m3Font = ctx.m3Font
	local fontWeight = ctx.fontWeight
	local playFeedback = ctx.playFeedback
	local tooltip = ctx.tooltip
	local textSize = ctx.textSize
	local indexElement = ctx.indexElement
	local nextCardItemOrder = ctx.nextCardItemOrder
	local formatMediaClock = ctx.formatMediaClock
	local searchCreatorStoreVideos = ctx.searchCreatorStoreVideos
	local searchCreatorStoreAudio = ctx.searchCreatorStoreAudio
	local onHeartbeat = ctx.onHeartbeat
	local isPrimaryInput = ctx.isPrimaryInput
	local isMoveInput = ctx.isMoveInput
	local captureDragTrack1D = ctx.captureDragTrack1D
	local fractionFromDragTrack = ctx.fractionFromDragTrack
	local onInputBegan = ctx.onInputBegan
	local onInputChanged = ctx.onInputChanged
	local onInputEnded = ctx.onInputEnded
	local MEDIA_PAGE_SIZE = ctx.MEDIA_PAGE_SIZE
	local MEDIA_PAGE_COUNT = ctx.MEDIA_PAGE_COUNT
	local RunService = ctx.RunService
	local win = ctx.win

	local sectionDeps = {
		corner = corner,
		reg = reg,
		fontWeight = fontWeight,
		textSize = textSize,
		padding = SL.SectionPadding or 14,
		innerGap = SL.InnerGap or 8,
		cornerRadius = SL.SectionCorner or 12,
	}

	local holder = Instance.new("Frame")
	holder.Name = "MediaBrowser"
	holder.LayoutOrder = nextCardItemOrder()
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = lib.CurrentBuildContainer
	indexElement("Media Browser", holder)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, SL.SectionGap or 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	local playerSection, playerBase = Section.create(holder, 0, sectionDeps, {
		name = "Player",
		title = "Player",
	})
	local playerApi = Player.build({
		section = playerSection,
		layoutBase = playerBase,
		holder = holder,
		win = win,
		curTheme = curTheme,
		reg = reg,
		corner = corner,
		m3Font = m3Font,
		textSize = textSize,
		formatMediaClock = formatMediaClock,
		playFeedback = playFeedback,
		onHeartbeat = onHeartbeat,
		isPrimaryInput = isPrimaryInput,
		isMoveInput = isMoveInput,
		captureDragTrack1D = captureDragTrack1D,
		fractionFromDragTrack = fractionFromDragTrack,
		onInputBegan = onInputBegan,
		onInputChanged = onInputChanged,
		onInputEnded = onInputEnded,
	})

	local browseSection, browseBase = Section.create(holder, 1, sectionDeps, {
		name = "Browse",
		title = "Browse",
	})
	local resultsSection, resultsBase = Section.create(holder, 2, sectionDeps, {
		name = "Results",
		title = "Results",
	})

	Catalog.build({
		browseSection = browseSection,
		browseBase = browseBase,
		resultsSection = resultsSection,
		resultsBase = resultsBase,
		player = playerApi,
		curTheme = curTheme,
		reg = reg,
		corner = corner,
		tween = tween,
		m3Font = m3Font,
		fontWeight = fontWeight,
		textSize = textSize,
		playFeedback = playFeedback,
		tooltip = tooltip,
		RunService = RunService,
		win = win,
		searchCreatorStoreVideos = searchCreatorStoreVideos,
		searchCreatorStoreAudio = searchCreatorStoreAudio,
		pageSize = MEDIA_PAGE_SIZE,
		pageCount = MEDIA_PAGE_COUNT,
	})
end

return mount
