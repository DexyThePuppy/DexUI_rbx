--!nonstrict
-- Game info panel: live universe metadata + thumbnails (Roblox Games / Thumbnails APIs).

local Registry = require("../hub/registry")
local GameMetadata = require("../hub/game-metadata")
local Services = require("../services")

return function(ctx)
	local lib = ctx.lib
	local curTheme = ctx.theme
	local reg = ctx.reg
	local tween, corner = ctx.tween, ctx.corner
	local m3Font = ctx.m3Font
	local beginCardRow = ctx.beginCardRow
	local fontWeight = ctx.fontWeight
	local onHeartbeat = ctx.onHeartbeat
	local playFeedback = ctx.playFeedback
	local trySetClipboard = ctx.trySetClipboard
	local tooltip = ctx.tooltip
	local textSize = ctx.textSize
	local HubGrid = ctx.hubGrid
	local MEDIA_PAGE_SIZE, MEDIA_PAGE_COUNT = ctx.MEDIA_PAGE_SIZE, ctx.MEDIA_PAGE_COUNT
	local ContentProvider = Services.ContentProvider or game:GetService("ContentProvider")
	local Players = game:GetService("Players")
	local TeleportService = game:GetService("TeleportService")

	local function formatImage(uri: string): string?
		return GameMetadata.resolveLoadableUri(uri)
	end

	local function formatNumber(n: number?): string
		if not n then
			return "—"
		end
		if n >= 1_000_000 then
			return string.format("%.1fM", n / 1_000_000)
		end
		if n >= 1_000 then
			return string.format("%.1fK", n / 1_000)
		end
		return tostring(n)
	end

	local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

	local function formatShortDate(iso: string?): string?
		if not iso then
			return nil
		end
		local y, m, d = string.match(iso, "(%d%d%d%d)%-(%d%d)%-(%d%d)")
		if not y or not m or not d then
			return nil
		end
		local mi = tonumber(m)
		if not mi or mi < 1 or mi > 12 then
			return nil
		end
		return MONTHS[mi] .. " " .. tonumber(d) .. ", " .. y
	end

	function lib:AddGameInfo()
		local entry = Registry.findForCurrentGame()

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

		local function makeSection(layoutOrder: number): Frame
			local section = Instance.new("Frame")
			section.Name = "Section"
			section.LayoutOrder = layoutOrder
			section.Size = UDim2.new(1, 0, 0, 0)
			section.AutomaticSize = Enum.AutomaticSize.Y
			section.BorderSizePixel = 0
			section.Parent = holder
			corner(section, 12)
			reg(section, "BackgroundColor3", "inact")

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

		local function notifyCopied(text: string, subtitle: string?)
			if trySetClipboard(text) then
				lib:Notify({
					Title = "Copied",
					Content = subtitle or text,
					Duration = 2,
				})
				playFeedback("selection")
			else
				lib:Notify({
					Title = "Copy",
					Content = text,
					Duration = 5,
				})
			end
		end

		-- Header: title (left) + rejoin (right), then meta line
		local headerSection = makeSection(0)

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
		titleLbl.FontFace = fontWeight(Enum.FontWeight.Bold)
		titleLbl.TextSize = textSize("lg")
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.TextWrapped = true
		titleLbl.Parent = headerRow
		reg(titleLbl, "TextColor3", "fg")

		local rejoinBtn = Instance.new("TextButton")
		rejoinBtn.Name = "Rejoin"
		rejoinBtn.Size = UDim2.fromOffset(88, 32)
		rejoinBtn.AnchorPoint = Vector2.new(1, 0)
		rejoinBtn.Position = UDim2.new(1, 0, 0, 0)
		rejoinBtn.Text = "Rejoin"
		rejoinBtn.FontFace = fontWeight(Enum.FontWeight.Medium)
		rejoinBtn.TextSize = textSize("sm")
		rejoinBtn.AutoButtonColor = false
		rejoinBtn.Parent = headerRow
		corner(rejoinBtn, 10)
		reg(rejoinBtn, "BackgroundColor3", "pri")
		reg(rejoinBtn, "TextColor3", "onpri")

		rejoinBtn.MouseButton1Click:Connect(function()
			playFeedback("light")
			local player = Players.LocalPlayer
			if not player then
				return
			end
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
			end)
		end)

		local function makeBadgeRow(parent: Frame, layoutOrder: number, name: string): Frame
			local row = Instance.new("Frame")
			row.Name = name
			row.LayoutOrder = layoutOrder
			row.Size = UDim2.new(1, 0, 0, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.BackgroundTransparency = 1
			row.Parent = parent
			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.Padding = UDim.new(0, 6)
			rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
			rowLayout.Wraps = true
			rowLayout.Parent = row
			return row
		end

		local function clearBadgeRow(row: Frame)
			for _, ch in row:GetChildren() do
				if ch:IsA("Frame") and ch.Name == "Badge" then
					ch:Destroy()
				end
			end
		end

		local function addInfoBadge(row: Frame, label: string, bg: Color3?, fg: Color3?)
			local badge = Instance.new("TextButton")
			badge.Name = "Badge"
			badge.Text = ""
			badge.AutoButtonColor = false
			badge.Size = UDim2.fromOffset(0, 22)
			badge.AutomaticSize = Enum.AutomaticSize.X
			badge.BackgroundColor3 = bg or curTheme.bg
			badge.BorderSizePixel = 0
			badge.Parent = row
			corner(badge, 6)

			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 8)
			pad.PaddingRight = UDim.new(0, 8)
			pad.Parent = badge

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromOffset(0, 22)
			lbl.AutomaticSize = Enum.AutomaticSize.X
			lbl.BackgroundTransparency = 1
			lbl.Text = label
			lbl.FontFace = fontWeight(Enum.FontWeight.Medium)
			lbl.TextSize = textSize("sm")
			lbl.TextColor3 = fg or curTheme.out
			lbl.Active = false
			lbl.Selectable = false
			lbl.Parent = badge

			badge.MouseButton1Click:Connect(function()
				notifyCopied(label)
			end)

			if tooltip then
				tooltip.attach(badge, label, { delay = 0.35, maxWidth = 260 })
			end
		end

		local metaBadgeRow = makeBadgeRow(headerSection, 1, "MetaBadges")

		-- Carousel
		local carouselSection = makeSection(1)

		local ASPECT_16_9 = 9 / 16
		local SIDE_GAP = 14
		local SLOT_RADIUS = 12
		local carouselCenterW = 320
		local carouselCenterH = math.floor(carouselCenterW * ASPECT_16_9 + 0.5)
		local carouselSideW = 200
		local carouselSideH = math.floor(carouselSideW * ASPECT_16_9 + 0.5)

		local carouselShell = Instance.new("Frame")
		carouselShell.LayoutOrder = 0
		carouselShell.Size = UDim2.new(1, 0, 0, carouselCenterH + 24)
		carouselShell.BorderSizePixel = 0
		carouselShell.ClipsDescendants = true
		carouselShell.Parent = carouselSection
		corner(carouselShell, 14)
		reg(carouselShell, "BackgroundColor3", "bg")
		local AUTO_SEC = 7

		local carouselTrack = Instance.new("Frame")
		carouselTrack.Name = "Track"
		carouselTrack.Size = UDim2.new(1, 0, 1, 0)
		carouselTrack.BackgroundTransparency = 1
		carouselTrack.ClipsDescendants = true
		carouselTrack.Parent = carouselShell

		local emptyLbl = Instance.new("TextLabel")
		emptyLbl.Name = "Empty"
		emptyLbl.Size = UDim2.fromScale(1, 1)
		emptyLbl.BackgroundTransparency = 1
		emptyLbl.Text = "No thumbnails loaded"
		emptyLbl.FontFace = m3Font
		emptyLbl.TextSize = textSize("md")
		emptyLbl.TextColor3 = curTheme.out
		emptyLbl.Visible = false
		emptyLbl.ZIndex = 2
		emptyLbl.Parent = carouselTrack

		local function makeCarouselSlot(name: string): TextButton
			local slot = Instance.new("TextButton")
			slot.Name = name
			slot.AnchorPoint = Vector2.new(0.5, 0.5)
			slot.Text = ""
			slot.AutoButtonColor = false
			slot.BorderSizePixel = 0
			slot.ClipsDescendants = true
			slot.Visible = false
			slot.Parent = carouselTrack
			corner(slot, SLOT_RADIUS)
			reg(slot, "BackgroundColor3", "inact")

			local img = Instance.new("ImageLabel")
			img.Name = "Image"
			img.Size = UDim2.fromScale(1, 1)
			img.BackgroundTransparency = 1
			img.ScaleType = Enum.ScaleType.Crop
			img.Active = false
			img.Selectable = false
			img.Parent = slot
			return slot
		end

		local function slotImage(slot: TextButton): ImageLabel?
			return slot:FindFirstChild("Image") :: ImageLabel?
		end

		local function setSlotImage(slot: TextButton, uri: string, transparency: number)
			local img = slotImage(slot)
			if img then
				img.Image = uri
				img.ImageTransparency = transparency
			end
		end

		local slotLeft = makeCarouselSlot("Left")
		local slotCenter = makeCarouselSlot("Center")
		local slotRight = makeCarouselSlot("Right")

		local dots = Instance.new("Frame")
		dots.LayoutOrder = 1
		dots.Size = UDim2.new(1, 0, 0, 8)
		dots.BackgroundTransparency = 1
		dots.Parent = carouselSection

		local dotsLayout = Instance.new("UIListLayout")
		dotsLayout.FillDirection = Enum.FillDirection.Horizontal
		dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		dotsLayout.Padding = UDim.new(0, 6)
		dotsLayout.Parent = dots

		-- Description
		local descSection = makeSection(2)

		local VIP_BADGE_RED = Color3.fromRGB(210, 48, 48)
		local VIP_BADGE_ON = Color3.fromRGB(255, 255, 255)
		local BADGE_VERIFIED = Color3.fromRGB(0, 162, 255)

		local settingsRow = makeBadgeRow(descSection, 0, "Settings")

		local function addSettingBadge(label: string, bg: Color3, fg: Color3)
			addInfoBadge(settingsRow, label, bg, fg)
		end

		local function renderGameSettings(meta: any)
			clearBadgeRow(settingsRow)
			if meta.createVipServersAllowed == true or meta.privateServersEnabled == true then
				addSettingBadge("VIP server", VIP_BADGE_RED, VIP_BADGE_ON)
			end
			if meta.copyingAllowed == true then
				addSettingBadge("Copying on", curTheme.inact, curTheme.fg)
			end
			if meta.creatorVerified == true then
				addSettingBadge("Verified", BADGE_VERIFIED, VIP_BADGE_ON)
			end
			if meta.universeAvatarType == "MorphToR15" then
				addSettingBadge("R15", curTheme.bg, curTheme.out)
			elseif meta.universeAvatarType == "MorphToR6" then
				addSettingBadge("R6", curTheme.bg, curTheme.out)
			end
			settingsRow.Visible = settingsRow:FindFirstChild("Badge") ~= nil
		end

		local statsBadgeRow = makeBadgeRow(descSection, 1, "StatsBadges")

		local function addStatBadges(meta: any)
			clearBadgeRow(statsBadgeRow)
			if meta.genre then
				for segment in string.gmatch(meta.genre, "([^·]+)") do
					local trimmed = string.match(segment, "^%s*(.-)%s*$")
					if trimmed and trimmed ~= "" then
						addInfoBadge(statsBadgeRow, trimmed)
					end
				end
			end
			if meta.maxPlayers then
				addInfoBadge(statsBadgeRow, meta.maxPlayers .. " players / server")
			end
			if meta.upVotes then
				local down = meta.downVotes or 0
				local total = meta.upVotes + down
				local pct = if total > 0 then math.floor(meta.upVotes / total * 100 + 0.5) else 0
				addInfoBadge(statsBadgeRow, string.format("%s likes (%d%%)", formatNumber(meta.upVotes), pct))
			end
			if meta.favoritedCount then
				addInfoBadge(statsBadgeRow, formatNumber(meta.favoritedCount) .. " favorites")
			end
			if meta.badgeCount and meta.badgeCount > 0 then
				local label = if meta.badgeCountAtLeast
					then tostring(meta.badgeCount) .. "+ badges"
					else tostring(meta.badgeCount) .. " badges"
				if meta.badgesClaimed then
					label ..= string.format(" (%d claimed)", meta.badgesClaimed)
				end
				addInfoBadge(statsBadgeRow, label)
			end
			if meta.groupMemberCount then
				addInfoBadge(statsBadgeRow, formatNumber(meta.groupMemberCount) .. " group members")
			end
			local created = formatShortDate(meta.created)
			if created then
				addInfoBadge(statsBadgeRow, "Created " .. created)
			end
			local updated = formatShortDate(meta.updated)
			if updated and updated ~= created then
				addInfoBadge(statsBadgeRow, "Updated " .. updated)
			end
			statsBadgeRow.Visible = statsBadgeRow:FindFirstChild("Badge") ~= nil
		end

		local function renderMetaBadges(meta: any)
			clearBadgeRow(metaBadgeRow)
			addInfoBadge(metaBadgeRow, string.format("Place %d", meta.placeId))
			addInfoBadge(metaBadgeRow, string.format("Universe %d", meta.universeId))
			if meta.rootPlaceId then
				addInfoBadge(metaBadgeRow, "Root place " .. tostring(meta.rootPlaceId))
			end
			if meta.creatorName then
				addInfoBadge(metaBadgeRow, "By " .. meta.creatorName)
			end
			if meta.playing then
				addInfoBadge(metaBadgeRow, formatNumber(meta.playing) .. " playing")
			end
			if meta.visits then
				addInfoBadge(metaBadgeRow, formatNumber(meta.visits) .. " visits")
			end
			if meta.creatorType then
				addInfoBadge(metaBadgeRow, meta.creatorType)
			end
			if entry and Registry.entryMatchesCurrent(entry) then
				addInfoBadge(metaBadgeRow, "Recognised in hub")
			end
			metaBadgeRow.Visible = metaBadgeRow:FindFirstChild("Badge") ~= nil
		end

		local bodyLbl = Instance.new("TextLabel")
		bodyLbl.LayoutOrder = 2
		bodyLbl.Size = UDim2.new(1, 0, 0, 0)
		bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
		bodyLbl.BackgroundTransparency = 1
		bodyLbl.Text = "Fetching name, description, and thumbnails from Roblox…"
		bodyLbl.FontFace = m3Font
		bodyLbl.TextSize = textSize("md")
		bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
		bodyLbl.TextWrapped = true
		bodyLbl.LineHeight = 1.15
		bodyLbl.Parent = descSection
		reg(bodyLbl, "TextColor3", "fg")

		local extraBadgeRow = makeBadgeRow(descSection, 3, "ExtraBadges")

		local function renderExtraBadges(meta: any)
			clearBadgeRow(extraBadgeRow)
			if meta.serverLabel then
				addInfoBadge(extraBadgeRow, meta.serverLabel)
			end
			if meta.placeVersion then
				addInfoBadge(extraBadgeRow, "Place v" .. tostring(meta.placeVersion))
			end
			if meta.jobId then
				addInfoBadge(extraBadgeRow, "Job " .. string.sub(meta.jobId, 1, 8) .. "…")
			end
			if meta.canonicalPath then
				addInfoBadge(extraBadgeRow, "roblox.com" .. meta.canonicalPath)
			end
			if entry then
				addInfoBadge(extraBadgeRow, "Hub script: " .. entry.script)
			end
			extraBadgeRow.Visible = extraBadgeRow:FindFirstChild("Badge") ~= nil
		end

		local badgeGridDeps = { corner = corner, reg = reg, fontWeight = fontWeight, textSize = textSize }
		local CLAIMED_GREEN = Color3.fromRGB(56, 170, 92)

		local badgesSection = makeSection(3)
		badgesSection.Visible = false

		local badgesHeading = Instance.new("TextLabel")
		badgesHeading.LayoutOrder = 0
		badgesHeading.Size = UDim2.new(1, 0, 0, 20)
		badgesHeading.BackgroundTransparency = 1
		badgesHeading.Text = "Badges"
		badgesHeading.FontFace = fontWeight(Enum.FontWeight.Medium)
		badgesHeading.TextSize = textSize("md")
		badgesHeading.TextXAlignment = Enum.TextXAlignment.Left
		badgesHeading.Parent = badgesSection
		reg(badgesHeading, "TextColor3", "pri")

		local badgesStatusLbl = Instance.new("TextLabel")
		badgesStatusLbl.LayoutOrder = 1
		badgesStatusLbl.Size = UDim2.new(1, 0, 0, 0)
		badgesStatusLbl.AutomaticSize = Enum.AutomaticSize.Y
		badgesStatusLbl.BackgroundTransparency = 1
		badgesStatusLbl.Text = ""
		badgesStatusLbl.FontFace = m3Font
		badgesStatusLbl.TextSize = textSize("sm")
		badgesStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
		badgesStatusLbl.TextWrapped = true
		badgesStatusLbl.Visible = false
		badgesStatusLbl.Parent = badgesSection
		reg(badgesStatusLbl, "TextColor3", "out")

		local badgeGrid = Instance.new("Frame")
		badgeGrid.Name = "BadgeGrid"
		badgeGrid.LayoutOrder = 2
		badgeGrid.Size = UDim2.new(1, 0, 0, 0)
		badgeGrid.AutomaticSize = Enum.AutomaticSize.Y
		badgeGrid.BackgroundTransparency = 1
		badgeGrid.Parent = badgesSection

		local badgeMount = HubGrid.buildInline(badgeGrid, badgeGridDeps)

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
					if tooltip then
						tooltip.detach(ch)
					end
					ch:Destroy()
				end
			end
		end

		local function renderBadgeGrid(badges: { any }, badgeAtLeast: boolean?)
			clearBadgeGrid()
			local count = if badges then #badges else 0
			if count == 0 then
				badgesSection.Visible = false
				return
			end
			badgesSection.Visible = true

			local claimed = 0
			for _, badge in badges do
				if badge.claimed then
					claimed += 1
				end
			end

			local totalLabel = if badgeAtLeast then tostring(count) .. "+" else tostring(count)
			badgesHeading.Text = string.format("Badges · %d / %s claimed", claimed, totalLabel)

			for i, badge in badges do
				local card = badgeMount.addCard(i)
				card.root.Name = "Badge" .. tostring(badge.id)
				card.root.BackgroundTransparency = if badge.claimed then 0.35 else 0.55
				reg(card.root, "BackgroundColor3", "bg")

				card.image.ImageTransparency = if badge.claimed then 0 else 0.45
				card.image.Active = false
				card.image.Selectable = false
				local uri = badgeThumbUri(badge)
				if uri then
					card.image.Image = uri
				end

				if badge.claimed then
					local tick = Instance.new("TextLabel")
					tick.Name = "Claimed"
					tick.Size = UDim2.fromOffset(16, 16)
					tick.Position = UDim2.new(1, -3, 0, 3)
					tick.AnchorPoint = Vector2.new(1, 0)
					tick.BackgroundColor3 = CLAIMED_GREEN
					tick.Text = "✓"
					tick.FontFace = fontWeight(Enum.FontWeight.Bold)
					tick.TextSize = textSize("sm")
					tick.TextColor3 = VIP_BADGE_ON
					tick.ZIndex = 5
					tick.Active = false
					tick.Selectable = false
					tick.Parent = card.thumb
					corner(tick, 999)
				end

				card.title.Text = badge.name
				card.title.FontFace = m3Font
				card.title.TextSize = textSize("sm")
				card.title.TextWrapped = true
				card.title.TextTruncate = Enum.TextTruncate.AtEnd
				card.title.TextColor3 = if badge.claimed then curTheme.fg else curTheme.out
				card.title.Active = false
				card.title.Selectable = false

				if tooltip then
					tooltip.attach(card.root, function()
						return GameMetadata.buildBadgeTooltipContent(badge)
					end)
				end
			end

			task.defer(badgeMount.sync)
		end

		-- Public servers (sorted low → high, paged like Media tab)
		local serversSection = makeSection(4)

		local serversHeading = Instance.new("TextLabel")
		serversHeading.LayoutOrder = 0
		serversHeading.Size = UDim2.new(1, 0, 0, 20)
		serversHeading.BackgroundTransparency = 1
		serversHeading.Text = "Public servers"
		serversHeading.FontFace = fontWeight(Enum.FontWeight.Medium)
		serversHeading.TextSize = textSize("md")
		serversHeading.TextXAlignment = Enum.TextXAlignment.Left
		serversHeading.Parent = serversSection
		reg(serversHeading, "TextColor3", "pri")

		local serversStatusLbl = Instance.new("TextLabel")
		serversStatusLbl.LayoutOrder = 1
		serversStatusLbl.Size = UDim2.new(1, 0, 0, 0)
		serversStatusLbl.AutomaticSize = Enum.AutomaticSize.Y
		serversStatusLbl.BackgroundTransparency = 1
		serversStatusLbl.Text = "Loading public servers…"
		serversStatusLbl.FontFace = m3Font
		serversStatusLbl.TextSize = textSize("sm")
		serversStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
		serversStatusLbl.TextWrapped = true
		serversStatusLbl.Parent = serversSection
		reg(serversStatusLbl, "TextColor3", "out")

		local serversList = Instance.new("Frame")
		serversList.Name = "ServerList"
		serversList.LayoutOrder = 2
		serversList.Size = UDim2.new(1, 0, 0, MEDIA_PAGE_SIZE * 52)
		serversList.BackgroundTransparency = 1
		serversList.Parent = serversSection

		local serversListLayout = Instance.new("UIListLayout")
		serversListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		serversListLayout.Padding = UDim.new(0, 6)
		serversListLayout.Parent = serversList

		local publicServers: { any } = {}
		local joinPlaceId = game.PlaceId
		local serverPageIndex = 0
		local serverRowBtns: { TextButton } = {}

		local function buildServerTooltip(srv: any): any?
			if not srv then
				return nil
			end
			local blocks: { any } = {
				{ kind = "title", text = "Server " .. tostring(srv.id) },
			}
			if srv.maxPlayers and srv.maxPlayers > 0 then
				table.insert(blocks, {
					kind = "stat",
					label = "Players",
					value = string.format("%d / %d", srv.playing or 0, srv.maxPlayers),
				})
			else
				table.insert(blocks, {
					kind = "stat",
					label = "Players",
					value = tostring(srv.playing or 0),
				})
			end
			if srv.ping then
				table.insert(blocks, { kind = "stat", label = "Ping", value = tostring(srv.ping) .. " ms" })
			end
			if srv.fps then
				table.insert(blocks, { kind = "stat", label = "FPS", value = string.format("%.0f", srv.fps) })
			end
			table.insert(blocks, { kind = "text", text = "Use Join to teleport.", muted = true })
			return { blocks = blocks, maxWidth = 260 }
		end

		local function serverPageCount(): number
			if #publicServers == 0 then
				return 0
			end
			return math.ceil(#publicServers / MEDIA_PAGE_SIZE)
		end

		for i = 1, MEDIA_PAGE_SIZE do
			local row = Instance.new("TextButton")
			row.Name = "ServerRow" .. i
			row.LayoutOrder = i
			row.Text = ""
			row.AutoButtonColor = false
			row.Size = UDim2.new(1, 0, 0, 46)
			row.BackgroundTransparency = 0.4
			row.Visible = false
			row.Parent = serversList
			corner(row, 10)
			reg(row, "BackgroundColor3", "bg")

			local rowTitle = Instance.new("TextLabel")
			rowTitle.Name = "Title"
			rowTitle.Size = UDim2.new(1, -100, 0, 20)
			rowTitle.Position = UDim2.new(0, 12, 0, 4)
			rowTitle.BackgroundTransparency = 1
			rowTitle.Text = ""
			rowTitle.FontFace = fontWeight(Enum.FontWeight.Medium)
			rowTitle.TextSize = textSize("md")
			rowTitle.TextXAlignment = Enum.TextXAlignment.Left
			rowTitle.TextTruncate = Enum.TextTruncate.AtEnd
			rowTitle.Active = false
			rowTitle.Selectable = false
			rowTitle.Parent = row
			reg(rowTitle, "TextColor3", "fg")

			local rowSub = Instance.new("TextLabel")
			rowSub.Name = "Subtitle"
			rowSub.Size = UDim2.new(1, -100, 0, 16)
			rowSub.Position = UDim2.new(0, 12, 0, 24)
			rowSub.BackgroundTransparency = 1
			rowSub.Text = ""
			rowSub.FontFace = m3Font
			rowSub.TextSize = textSize("sm")
			rowSub.TextXAlignment = Enum.TextXAlignment.Left
			rowSub.TextTruncate = Enum.TextTruncate.AtEnd
			rowSub.Active = false
			rowSub.Selectable = false
			rowSub.Parent = row
			reg(rowSub, "TextColor3", "out")

			local joinBtn = Instance.new("TextButton")
			joinBtn.Name = "Join"
			joinBtn.Size = UDim2.fromOffset(72, 30)
			joinBtn.AnchorPoint = Vector2.new(1, 0.5)
			joinBtn.Position = UDim2.new(1, -10, 0.5, 0)
			joinBtn.Text = "Join"
			joinBtn.FontFace = fontWeight(Enum.FontWeight.Medium)
			joinBtn.TextSize = textSize("sm")
			joinBtn.AutoButtonColor = false
			joinBtn.ZIndex = 4
			joinBtn.Parent = row
			corner(joinBtn, 8)
			reg(joinBtn, "BackgroundColor3", "pri")
			reg(joinBtn, "TextColor3", "onpri")

			local slot = i
			joinBtn.MouseButton1Click:Connect(function()
				local srv = publicServers[serverPageIndex * MEDIA_PAGE_SIZE + slot]
				if not srv then
					return
				end
				playFeedback("light")
				local player = Players.LocalPlayer
				if not player then
					return
				end
				serversStatusLbl.Text = "Joining server…"
				pcall(function()
					TeleportService:TeleportToPlaceInstance(joinPlaceId, srv.id, player)
				end)
			end)

			if tooltip then
				local slot = i
				tooltip.attach(row, function()
					return buildServerTooltip(publicServers[serverPageIndex * MEDIA_PAGE_SIZE + slot])
				end, { delay = 0.35 })
			end

			serverRowBtns[i] = row
		end

		local pagerRow = Instance.new("Frame")
		pagerRow.LayoutOrder = 3
		pagerRow.Size = UDim2.new(1, 0, 0, 36)
		pagerRow.BackgroundTransparency = 1
		pagerRow.Parent = serversSection

		local pagerLayout = Instance.new("UIListLayout")
		pagerLayout.FillDirection = Enum.FillDirection.Horizontal
		pagerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		pagerLayout.Padding = UDim.new(0, 6)
		pagerLayout.Parent = pagerRow

		local pageBtns: { TextButton } = {}

		local function refreshPagerHighlight()
			local pages = serverPageCount()
			for idx, btn in pageBtns do
				local pageNum = idx - 1
				btn.Visible = pageNum < pages
				if not btn.Visible then
					continue
				end
				local active = pageNum == serverPageIndex
				if active then
					btn.BackgroundColor3 = curTheme.pri
					btn.TextColor3 = curTheme.onpri
				else
					btn.BackgroundColor3 = curTheme.inact
					btn.TextColor3 = curTheme.fg
				end
			end
		end

		local function formatServerStatus(srv: any): string
			local parts = {}
			if srv.maxPlayers > 0 then
				table.insert(parts, string.format("%d / %d players", srv.playing, srv.maxPlayers))
			else
				table.insert(parts, string.format("%d players", srv.playing))
			end
			if srv.ping then
				table.insert(parts, srv.ping .. " ms")
			end
			if srv.fps then
				table.insert(parts, string.format("%.0f fps", srv.fps))
			end
			return table.concat(parts, " · ")
		end

		local function renderPublicServers()
			local pages = serverPageCount()
			if pages > 0 and serverPageIndex >= pages then
				serverPageIndex = pages - 1
			end
			local startIdx = serverPageIndex * MEDIA_PAGE_SIZE + 1
			for i = 1, MEDIA_PAGE_SIZE do
				local srv = publicServers[startIdx + i - 1]
				local row = serverRowBtns[i]
				if srv then
					row.Visible = true
					local title = row:FindFirstChild("Title") :: TextLabel
					local sub = row:FindFirstChild("Subtitle") :: TextLabel
					title.Text = "Server " .. string.sub(srv.id, 1, 8)
					sub.Text = formatServerStatus(srv)
				else
					row.Visible = false
				end
			end
			refreshPagerHighlight()
		end

		for pageNum = 0, MEDIA_PAGE_COUNT - 1 do
			local btn = Instance.new("TextButton")
			btn.Name = "Page" .. pageNum
			btn.Size = UDim2.fromOffset(28, 28)
			btn.Text = tostring(pageNum)
			btn.FontFace = fontWeight(Enum.FontWeight.Medium)
			btn.TextSize = textSize("sm")
			btn.AutoButtonColor = false
			btn.Visible = false
			btn.Parent = pagerRow
			corner(btn, 999)
			reg(btn, "BackgroundColor3", "inact")
			reg(btn, "TextColor3", "fg")
			pageBtns[pageNum + 1] = btn

			btn.MouseButton1Click:Connect(function()
				if pageNum < serverPageCount() then
					serverPageIndex = pageNum
					renderPublicServers()
					local pages = serverPageCount()
					serversStatusLbl.Text = string.format(
						"%d server(s) · players low → high · page %d / %d",
						#publicServers,
						serverPageIndex + 1,
						math.max(1, pages)
					)
					playFeedback("light")
				end
			end)
		end

		local pageNextBtn = Instance.new("TextButton")
		pageNextBtn.Name = "PageNext"
		pageNextBtn.Size = UDim2.fromOffset(28, 28)
		pageNextBtn.Text = ">"
		pageNextBtn.FontFace = fontWeight(Enum.FontWeight.Medium)
		pageNextBtn.TextSize = textSize("sm")
		pageNextBtn.AutoButtonColor = false
		pageNextBtn.Parent = pagerRow
		corner(pageNextBtn, 999)
		reg(pageNextBtn, "BackgroundColor3", "inact")
		reg(pageNextBtn, "TextColor3", "fg")

		pageNextBtn.MouseButton1Click:Connect(function()
			local pages = serverPageCount()
			if pages == 0 then
				return
			end
			if serverPageIndex < pages - 1 then
				serverPageIndex += 1
				renderPublicServers()
				serversStatusLbl.Text = string.format(
					"%d server(s) · players low → high · page %d / %d",
					#publicServers,
					serverPageIndex + 1,
					pages
				)
				playFeedback("light")
			else
				serversStatusLbl.Text = "No more pages."
			end
		end)

		local slideIndex = 1
		local lastAutoAt = os.clock()
		local dotFrames: { TextButton } = {}
		local carouselConn: RBXScriptConnection? = nil
		local slideUris: { string } = {}

		local prevBtn = Instance.new("TextButton")
		prevBtn.Size = UDim2.fromOffset(32, 32)
		prevBtn.AnchorPoint = Vector2.new(0, 0.5)
		prevBtn.Position = UDim2.new(0, 8, 0.5, 0)
		prevBtn.Text = "<"
		prevBtn.FontFace = m3Font
		prevBtn.TextSize = textSize("lg")
		prevBtn.AutoButtonColor = false
		prevBtn.Visible = false
		prevBtn.ZIndex = 5
		prevBtn.Parent = carouselShell
		corner(prevBtn, 999)
		reg(prevBtn, "BackgroundColor3", "bg")
		reg(prevBtn, "TextColor3", "fg")

		local nextBtn = Instance.new("TextButton")
		nextBtn.Size = UDim2.fromOffset(32, 32)
		nextBtn.AnchorPoint = Vector2.new(1, 0.5)
		nextBtn.Position = UDim2.new(1, -8, 0.5, 0)
		nextBtn.Text = ">"
		nextBtn.FontFace = m3Font
		nextBtn.TextSize = textSize("lg")
		nextBtn.AutoButtonColor = false
		nextBtn.Visible = false
		nextBtn.ZIndex = 5
		nextBtn.Parent = carouselShell
		corner(nextBtn, 999)
		reg(nextBtn, "BackgroundColor3", "bg")
		reg(nextBtn, "TextColor3", "fg")

		local function wrapIndex(index: number, count: number): number
			return ((index - 1) % count) + 1
		end

		local function layoutSlotPositions()
			local trackW = math.max(carouselTrack.AbsoluteSize.X, 1)
			local trackH = math.max(carouselTrack.AbsoluteSize.Y, 1)
			local usableW = math.max(trackW - 56, 180)

			local centerW = math.floor(usableW * 0.46)
			centerW = math.clamp(centerW, 180, 420)
			local sideW = math.floor((usableW - centerW - SIDE_GAP * 2) * 0.5)
			sideW = math.clamp(sideW, 96, 240)
			centerW = math.max(160, usableW - sideW * 2 - SIDE_GAP * 2)

			carouselCenterW = centerW
			carouselCenterH = math.floor(centerW * ASPECT_16_9 + 0.5)
			carouselSideW = sideW
			carouselSideH = math.floor(sideW * ASPECT_16_9 + 0.5)

			local shellH = carouselCenterH + 24
			if math.abs(carouselShell.Size.Y.Offset - shellH) > 1 then
				carouselShell.Size = UDim2.new(1, 0, 0, shellH)
			end

			local midX = trackW * 0.5
			local midY = trackH * 0.5
			local step = carouselCenterW * 0.5 + SIDE_GAP + carouselSideW * 0.5

			slotCenter.Size = UDim2.fromOffset(carouselCenterW, carouselCenterH)
			slotCenter.Position = UDim2.fromOffset(midX, midY)
			slotCenter.ZIndex = 3

			slotLeft.Size = UDim2.fromOffset(carouselSideW, carouselSideH)
			slotLeft.Position = UDim2.fromOffset(midX - step, midY)
			slotLeft.ZIndex = 2

			slotRight.Size = UDim2.fromOffset(carouselSideW, carouselSideH)
			slotRight.Position = UDim2.fromOffset(midX + step, midY)
			slotRight.ZIndex = 2
		end

		local carouselLayoutQueued = false

		local function refreshDots(active: number)
			for i, dot in dotFrames do
				dot.BackgroundColor3 = if i == active then curTheme.pri else curTheme.out
			end
		end

		-- Three fixed slots always show prev / active / next (infinite loop, no flying slides).
		local function applySlots(active: number)
			local count = #slideUris
			emptyLbl.Visible = count == 0
			if count == 0 then
				slotLeft.Visible = false
				slotCenter.Visible = false
				slotRight.Visible = false
				return
			end

			layoutSlotPositions()
			active = wrapIndex(active, count)
			slideIndex = active
			refreshDots(active)

			if count == 1 then
				slotLeft.Visible = false
				slotRight.Visible = false
				slotCenter.Visible = true
				setSlotImage(slotCenter, slideUris[1], 0)
				return
			end

			slotLeft.Visible = true
			slotRight.Visible = true
			slotCenter.Visible = true

			local prevIdx = wrapIndex(active - 1, count)
			local nextIdx = wrapIndex(active + 1, count)

			setSlotImage(slotLeft, slideUris[prevIdx], 0.35)
			setSlotImage(slotRight, slideUris[nextIdx], 0.35)
			setSlotImage(slotCenter, slideUris[active], 0)
		end

		local function refreshCarouselLayout()
			if #slideUris == 0 then
				return
			end
			applySlots(slideIndex)
		end

		local function scheduleCarouselLayout()
			if carouselLayoutQueued then
				return
			end
			carouselLayoutQueued = true
			task.defer(function()
				carouselLayoutQueued = false
				game:GetService("RunService").RenderStepped:Wait()
				if carouselTrack.Parent and carouselTrack.AbsoluteSize.X > 1 then
					refreshCarouselLayout()
				end
			end)
		end

		local function goToSlide(index: number)
			local count = #slideUris
			if count <= 1 then
				return
			end
			local nextIndex = wrapIndex(index, count)
			if nextIndex == slideIndex then
				return
			end
			applySlots(nextIndex)
			lastAutoAt = os.clock()
		end

		local MAX_CAROUSEL_SLIDES = 8

		local function isCachedUri(uri: string): boolean
			return string.find(uri, "rbxasset://", 1, true) ~= nil
		end

		local function uniqueImages(images: { string }): { string }
			local out: { string } = {}
			local seen: { [string]: boolean } = {}
			for _, uri in images do
				local resolved = if isCachedUri(uri) or string.find(uri, "rbxassetid://", 1, true)
					then uri
					else formatImage(uri)
				if resolved and resolved ~= "" and not seen[resolved] then
					seen[resolved] = true
					table.insert(out, resolved)
				end
			end
			return out
		end

		local function rebuildCarousel(images: { string })
			table.clear(slideUris)
			for _, ch in dots:GetChildren() do
				if ch:IsA("TextButton") and ch.Name ~= "UIListLayout" then
					ch:Destroy()
				end
			end
			table.clear(dotFrames)
			if carouselConn then
				carouselConn:Disconnect()
				carouselConn = nil
			end

			local candidates = uniqueImages(images)
			if #candidates > MAX_CAROUSEL_SLIDES then
				local trimmed: { string } = {}
				for i = 1, MAX_CAROUSEL_SLIDES do
					trimmed[i] = candidates[i]
				end
				candidates = trimmed
			end
			slideUris = candidates

			local count = #slideUris
			for i = 1, count do
				local dot = Instance.new("TextButton")
				dot.Text = ""
				dot.AutoButtonColor = false
				dot.Size = UDim2.fromOffset(8, 8)
				dot.BorderSizePixel = 0
				dot.LayoutOrder = i
				dot.Parent = dots
				corner(dot, 999)
				reg(dot, "BackgroundColor3", if i == 1 then "pri" else "out")
				dot.MouseButton1Click:Connect(function()
					playFeedback("light")
					goToSlide(i)
				end)
				table.insert(dotFrames, dot)
			end

			local multi = count > 1
			prevBtn.Visible = multi
			nextBtn.Visible = multi
			dots.Visible = multi
			slideIndex = 1
			lastAutoAt = os.clock()

			if count > 0 then
				local preload: { Instance } = {}
				for _, slot in { slotLeft, slotCenter, slotRight } do
					local img = slotImage(slot)
					if img then
						table.insert(preload, img)
					end
				end
				pcall(function()
					ContentProvider:PreloadAsync(preload)
				end)
			end

			scheduleCarouselLayout()

			if multi then
				carouselConn = onHeartbeat(function()
					if os.clock() - lastAutoAt >= AUTO_SEC then
						goToSlide(slideIndex + 1)
					end
				end)
			end
		end

		prevBtn.MouseButton1Click:Connect(function()
			playFeedback("light")
			goToSlide(slideIndex - 1)
		end)
		nextBtn.MouseButton1Click:Connect(function()
			playFeedback("light")
			goToSlide(slideIndex + 1)
		end)

		slotLeft.MouseButton1Click:Connect(function()
			playFeedback("light")
			goToSlide(slideIndex - 1)
		end)
		slotCenter.MouseButton1Click:Connect(function()
			playFeedback("light")
			goToSlide(slideIndex)
		end)
		slotRight.MouseButton1Click:Connect(function()
			playFeedback("light")
			goToSlide(slideIndex + 1)
		end)

		carouselTrack:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleCarouselLayout)
		carouselShell:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleCarouselLayout)

		local tabScroll: Instance? = holder
		while tabScroll and not tabScroll:IsA("ScrollingFrame") do
			tabScroll = tabScroll.Parent
		end
		if tabScroll then
			tabScroll:GetPropertyChangedSignal("Visible"):Connect(function()
				if tabScroll.Visible then
					scheduleCarouselLayout()
				end
			end)
			tabScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleCarouselLayout)
		end

		local winNode: Instance? = holder
		while winNode and winNode.Name ~= "Window" do
			winNode = winNode.Parent
		end
		if winNode then
			winNode:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleCarouselLayout)
		end

		task.spawn(function()
			local ok, meta = pcall(GameMetadata.fetchCurrentGameMetadata)
			if not ok or type(meta) ~= "table" or not holder.Parent then
				titleLbl.Text = "Current experience"
				bodyLbl.Text = "Could not load game metadata. Check HttpService / executor request support."
				serversStatusLbl.Text = "Public servers unavailable."
				badgesSection.Visible = false
				return
			end

			local titleText = if entry then entry.name else meta.name
			if entry and Registry.entryMatchesCurrent(entry) then
				titleText = entry.name
			end
			titleLbl.Text = titleText

			renderMetaBadges(meta)
			addStatBadges(meta)

			local description = if entry and entry.description and entry.description ~= ""
				then entry.description
				else (meta.description or "No description returned for this universe.")

			renderGameSettings(meta)
			bodyLbl.Text = description

			local images: { string } = {}
			if entry and entry.images then
				for _, img in entry.images do
					local resolved = formatImage(img)
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

			rebuildCarousel(images)
			renderBadgeGrid(meta.badges, meta.badgeCountAtLeast)

			if #slideUris == 0 and #images > 0 then
				clearBadgeRow(extraBadgeRow)
				addInfoBadge(extraBadgeRow, "Thumbnails could not load")
				extraBadgeRow.Visible = true
			else
				renderExtraBadges(meta)
			end

			joinPlaceId = meta.rootPlaceId or meta.placeId
			local servers, serversErr = GameMetadata.fetchPublicServers(joinPlaceId)
			publicServers = servers
			serverPageIndex = 0
			renderPublicServers()

			local pages = serverPageCount()
			if #publicServers == 0 then
				serversStatusLbl.Text = serversErr or "No public servers returned for this experience."
				pagerRow.Visible = false
			else
				pagerRow.Visible = pages > 1
				serversStatusLbl.Text = string.format(
					"%d server(s) · players low → high · page %d / %d",
					#publicServers,
					1,
					math.max(1, pages)
				)
			end
		end)
	end
end
