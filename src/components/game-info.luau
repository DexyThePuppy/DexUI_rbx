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
	local MEDIA_PAGE_SIZE, MEDIA_PAGE_COUNT = ctx.MEDIA_PAGE_SIZE, ctx.MEDIA_PAGE_COUNT
	local ContentProvider = Services.ContentProvider or game:GetService("ContentProvider")
	local Players = game:GetService("Players")
	local TeleportService = game:GetService("TeleportService")

	local function formatImage(uri: string): string
		if string.find(uri, "rbxassetid://", 1, true)
			or string.find(uri, "rbxthumb://", 1, true)
			or string.find(uri, "rbxasset://", 1, true)
		then
			return uri
		end
		-- Never pass CDN https URLs straight to ImageLabel (they will not render).
		local digits = string.match(uri, "(%d+)")
		if digits then
			return "rbxassetid://" .. digits
		end
		return uri
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

	function lib:AddGameInfo()
		local entry = Registry.findForCurrentGame()

		local holder = Instance.new("Frame")
		holder.Name = "GameInfo"
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.Parent = beginCardRow(nil, true)

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 12)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = holder

		local function makeSection(layoutOrder: number): Frame
			local section = Instance.new("Frame")
			section.Name = "Section"
			section.LayoutOrder = layoutOrder
			section.Size = UDim2.new(1, 0, 0, 0)
			section.AutomaticSize = Enum.AutomaticSize.Y
			section.BackgroundTransparency = 1
			section.Parent = holder
			local sectionLayout = Instance.new("UIListLayout")
			sectionLayout.Padding = UDim.new(0, 8)
			sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
			sectionLayout.Parent = section
			return section
		end

		local function makeDivider(layoutOrder: number): Frame
			local div = Instance.new("Frame")
			div.Name = "Divider"
			div.LayoutOrder = layoutOrder
			div.Size = UDim2.new(1, 0, 0, 1)
			div.BorderSizePixel = 0
			div.BackgroundTransparency = 0.65
			div.Parent = holder
			reg(div, "BackgroundColor3", "out")
			return div
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
		titleLbl.TextSize = 22
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
		rejoinBtn.TextSize = 13
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

		local metaLbl = Instance.new("TextLabel")
		metaLbl.LayoutOrder = 1
		metaLbl.Size = UDim2.new(1, 0, 0, 0)
		metaLbl.AutomaticSize = Enum.AutomaticSize.Y
		metaLbl.BackgroundTransparency = 1
		metaLbl.Text = ""
		metaLbl.FontFace = m3Font
		metaLbl.TextSize = 12
		metaLbl.TextXAlignment = Enum.TextXAlignment.Left
		metaLbl.TextWrapped = true
		metaLbl.Parent = headerSection
		reg(metaLbl, "TextColor3", "out")

		-- Carousel
		local carouselSection = makeSection(1)

		local carouselShell = Instance.new("Frame")
		carouselShell.LayoutOrder = 0
		carouselShell.Size = UDim2.new(1, 0, 0, 200)
		carouselShell.BorderSizePixel = 0
		carouselShell.ClipsDescendants = true
		carouselShell.Parent = carouselSection
		corner(carouselShell, 14)
		reg(carouselShell, "BackgroundColor3", "inact")

		local CAROUSEL_H = 184
		local CENTER_W = 332
		local SIDE_W = 248
		local SIDE_GAP = 14
		local AUTO_SEC = 7
		local TWEEN_SEC = 0.45

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
		emptyLbl.TextSize = 14
		emptyLbl.TextColor3 = curTheme.out
		emptyLbl.Visible = false
		emptyLbl.ZIndex = 2
		emptyLbl.Parent = carouselTrack

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

		makeDivider(2)

		-- Description
		local descSection = makeSection(3)

		local VIP_BADGE_RED = Color3.fromRGB(210, 48, 48)
		local VIP_BADGE_ON = Color3.fromRGB(255, 255, 255)

		local settingsRow = Instance.new("Frame")
		settingsRow.Name = "Settings"
		settingsRow.LayoutOrder = 0
		settingsRow.Size = UDim2.new(1, 0, 0, 0)
		settingsRow.AutomaticSize = Enum.AutomaticSize.Y
		settingsRow.BackgroundTransparency = 1
		settingsRow.Parent = descSection

		local settingsLayout = Instance.new("UIListLayout")
		settingsLayout.FillDirection = Enum.FillDirection.Horizontal
		settingsLayout.Padding = UDim.new(0, 6)
		settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		settingsLayout.Parent = settingsRow

		local function clearSettingBadges()
			for _, ch in settingsRow:GetChildren() do
				if ch:IsA("Frame") and ch.Name == "Badge" then
					ch:Destroy()
				end
			end
		end

		local function addSettingBadge(label: string, bg: Color3, fg: Color3)
			local badge = Instance.new("Frame")
			badge.Name = "Badge"
			badge.Size = UDim2.fromOffset(0, 22)
			badge.AutomaticSize = Enum.AutomaticSize.X
			badge.BackgroundColor3 = bg
			badge.BorderSizePixel = 0
			badge.Parent = settingsRow
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
			lbl.TextSize = 11
			lbl.TextColor3 = fg
			lbl.Parent = badge
		end

		local function renderGameSettings(meta: any)
			clearSettingBadges()
			if meta.privateServersEnabled == true then
				addSettingBadge("VIP server", VIP_BADGE_RED, VIP_BADGE_ON)
			end
			settingsRow.Visible = settingsRow:FindFirstChild("Badge") ~= nil
		end

		local bodyLbl = Instance.new("TextLabel")
		bodyLbl.LayoutOrder = 1
		bodyLbl.Size = UDim2.new(1, 0, 0, 0)
		bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
		bodyLbl.BackgroundTransparency = 1
		bodyLbl.Text = "Fetching name, description, and thumbnails from Roblox…"
		bodyLbl.FontFace = m3Font
		bodyLbl.TextSize = 14
		bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
		bodyLbl.TextWrapped = true
		bodyLbl.LineHeight = 1.15
		bodyLbl.Parent = descSection
		reg(bodyLbl, "TextColor3", "fg")

		local extraLbl = Instance.new("TextLabel")
		extraLbl.LayoutOrder = 2
		extraLbl.Size = UDim2.new(1, 0, 0, 0)
		extraLbl.AutomaticSize = Enum.AutomaticSize.Y
		extraLbl.BackgroundTransparency = 1
		extraLbl.Text = ""
		extraLbl.FontFace = m3Font
		extraLbl.TextSize = 11
		extraLbl.TextXAlignment = Enum.TextXAlignment.Left
		extraLbl.TextWrapped = true
		extraLbl.Parent = descSection
		reg(extraLbl, "TextColor3", "out")

		makeDivider(4)

		-- Public servers (sorted low → high, paged like Media tab)
		local serversSection = makeSection(5)

		local serversHeading = Instance.new("TextLabel")
		serversHeading.LayoutOrder = 0
		serversHeading.Size = UDim2.new(1, 0, 0, 20)
		serversHeading.BackgroundTransparency = 1
		serversHeading.Text = "Public servers"
		serversHeading.FontFace = fontWeight(Enum.FontWeight.Medium)
		serversHeading.TextSize = 14
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
		serversStatusLbl.TextSize = 11
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
		local serverRowBtns: { Frame } = {}

		local function serverPageCount(): number
			if #publicServers == 0 then
				return 0
			end
			return math.ceil(#publicServers / MEDIA_PAGE_SIZE)
		end

		for i = 1, MEDIA_PAGE_SIZE do
			local row = Instance.new("Frame")
			row.Name = "ServerRow" .. i
			row.LayoutOrder = i
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
			rowTitle.TextSize = 14
			rowTitle.TextXAlignment = Enum.TextXAlignment.Left
			rowTitle.TextTruncate = Enum.TextTruncate.AtEnd
			rowTitle.Parent = row
			reg(rowTitle, "TextColor3", "fg")

			local rowSub = Instance.new("TextLabel")
			rowSub.Name = "Subtitle"
			rowSub.Size = UDim2.new(1, -100, 0, 16)
			rowSub.Position = UDim2.new(0, 12, 0, 24)
			rowSub.BackgroundTransparency = 1
			rowSub.Text = ""
			rowSub.FontFace = m3Font
			rowSub.TextSize = 11
			rowSub.TextXAlignment = Enum.TextXAlignment.Left
			rowSub.TextTruncate = Enum.TextTruncate.AtEnd
			rowSub.Parent = row
			reg(rowSub, "TextColor3", "out")

			local joinBtn = Instance.new("TextButton")
			joinBtn.Name = "Join"
			joinBtn.Size = UDim2.fromOffset(72, 30)
			joinBtn.AnchorPoint = Vector2.new(1, 0.5)
			joinBtn.Position = UDim2.new(1, -10, 0.5, 0)
			joinBtn.Text = "Join"
			joinBtn.FontFace = fontWeight(Enum.FontWeight.Medium)
			joinBtn.TextSize = 12
			joinBtn.AutoButtonColor = false
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
			btn.TextSize = 13
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
		pageNextBtn.TextSize = 13
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
		local dotFrames: { Frame } = {}
		local carouselConn: RBXScriptConnection? = nil
		local slideEntries: { ImageLabel } = {}

		local prevBtn = Instance.new("TextButton")
		prevBtn.Size = UDim2.fromOffset(32, 32)
		prevBtn.AnchorPoint = Vector2.new(0, 0.5)
		prevBtn.Position = UDim2.new(0, 8, 0.5, 0)
		prevBtn.Text = "<"
		prevBtn.FontFace = m3Font
		prevBtn.TextSize = 18
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
		nextBtn.TextSize = 18
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

		local function relativeOffset(index: number, active: number, count: number): number
			local rel = index - active
			if rel > count / 2 then
				rel -= count
			elseif rel < -count / 2 then
				rel += count
			end
			return rel
		end

		local function layoutCarousel(active: number, animate: boolean)
			local count = #slideEntries
			emptyLbl.Visible = count == 0
			if count == 0 then
				return
			end

			active = wrapIndex(active, count)
			slideIndex = active

			local trackW = math.max(carouselTrack.AbsoluteSize.X, 1)
			local trackH = math.max(carouselTrack.AbsoluteSize.Y, 1)
			local midX = trackW * 0.5
			local midY = trackH * 0.5
			local step = CENTER_W * 0.5 + SIDE_GAP + SIDE_W * 0.5

			for i, slide in slideEntries do
				slide.AnchorPoint = Vector2.new(0.5, 0.5)
				local rel = relativeOffset(i, active, count)
				local show = count == 1 or rel == 0 or rel == -1 or rel == 1
				slide.Visible = show
				if not show then
					continue
				end

				local targetW = if rel == 0 then CENTER_W else SIDE_W
				local targetH = if rel == 0 then CAROUSEL_H - 16 else CAROUSEL_H - 28
				local targetX = midX + rel * step
				local targetTrans = if rel == 0 then 0 else 0.35
				local targetZ = if rel == 0 then 3 else 2

				slide.ZIndex = targetZ
				if animate then
					tween(slide, "Size", UDim2.fromOffset(targetW, targetH), TWEEN_SEC)
					tween(slide, "Position", UDim2.fromOffset(targetX, midY), TWEEN_SEC)
					tween(slide, "ImageTransparency", targetTrans, TWEEN_SEC)
				else
					slide.Size = UDim2.fromOffset(targetW, targetH)
					slide.AnchorPoint = Vector2.new(0.5, 0.5)
					slide.Position = UDim2.fromOffset(targetX, midY)
					slide.ImageTransparency = targetTrans
				end
			end

			for i, dot in dotFrames do
				local color = if i == active then curTheme.pri else curTheme.out
				if animate then
					tween(dot, "BackgroundColor3", color, 0.2)
				else
					dot.BackgroundColor3 = color
				end
			end
		end

		local function goToSlide(index: number)
			local count = #slideEntries
			if count <= 1 then
				return
			end
			layoutCarousel(index, true)
			lastAutoAt = os.clock()
		end

		local function waitForLoaded(slide: ImageLabel, uri: string): boolean
			slide.Image = formatImage(uri)
			slide.ImageTransparency = 1
			pcall(function()
				ContentProvider:PreloadAsync({ slide })
			end)
			for _ = 1, 40 do
				if not slide.Parent then
					return false
				end
				if slide.IsLoaded then
					return true
				end
				task.wait(0.12)
			end
			return slide.IsLoaded
		end

		local function uniqueImages(images: { string }): { string }
			local out: { string } = {}
			local seen: { [string]: boolean } = {}
			for _, uri in images do
				local formatted = formatImage(uri)
				if formatted ~= "" and not seen[formatted] then
					seen[formatted] = true
					table.insert(out, formatted)
				end
			end
			return out
		end

		local function rebuildCarousel(images: { string })
			for _, slide in slideEntries do
				slide:Destroy()
			end
			table.clear(slideEntries)
			for _, ch in carouselTrack:GetChildren() do
				if ch:IsA("ImageLabel") then
					ch:Destroy()
				end
			end
			for _, ch in dots:GetChildren() do
				if ch:IsA("Frame") then
					ch:Destroy()
				end
			end
			table.clear(dotFrames)
			if carouselConn then
				carouselConn:Disconnect()
				carouselConn = nil
			end

			local candidates = uniqueImages(images)
			for _, uri in candidates do
				local probe = Instance.new("ImageLabel")
				probe.Name = "Slide"
				probe.AnchorPoint = Vector2.new(0.5, 0.5)
				probe.BackgroundTransparency = 1
				probe.ScaleType = Enum.ScaleType.Crop
				probe.Visible = false
				probe.Parent = carouselTrack
				corner(probe, 10)
				reg(probe, "BackgroundColor3", "bg")
				if waitForLoaded(probe, uri) then
					probe.Visible = true
					table.insert(slideEntries, probe)
				else
					probe:Destroy()
				end
			end

			local count = #slideEntries
			for i = 1, count do
				local dot = Instance.new("Frame")
				dot.Size = UDim2.fromOffset(8, 8)
				dot.BorderSizePixel = 0
				dot.LayoutOrder = i
				dot.Parent = dots
				corner(dot, 999)
				reg(dot, "BackgroundColor3", if i == 1 then "pri" else "out")
				table.insert(dotFrames, dot)
			end

			local multi = count > 1
			prevBtn.Visible = multi
			nextBtn.Visible = multi
			dots.Visible = multi
			slideIndex = 1
			lastAutoAt = os.clock()

			task.defer(function()
				game:GetService("RunService").RenderStepped:Wait()
				if #slideEntries > 0 then
					layoutCarousel(1, false)
				end
			end)

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

		task.spawn(function()
			local ok, meta = pcall(GameMetadata.fetchCurrentGameMetadata)
			if not ok or type(meta) ~= "table" or not holder.Parent then
				titleLbl.Text = "Current experience"
				bodyLbl.Text = "Could not load game metadata. Check HttpService / executor request support."
				serversStatusLbl.Text = "Public servers unavailable."
				return
			end

			local titleText = if entry then entry.name else meta.name
			if entry and Registry.entryMatchesCurrent(entry) then
				titleText = entry.name
			end
			titleLbl.Text = titleText

			local metaParts = {
				string.format("Place %d · Universe %d", meta.placeId, meta.universeId),
			}
			if meta.rootPlaceId then
				table.insert(metaParts, "Root place " .. tostring(meta.rootPlaceId))
			end
			if meta.creatorName then
				table.insert(metaParts, "By " .. meta.creatorName)
			end
			if meta.playing then
				table.insert(metaParts, formatNumber(meta.playing) .. " playing")
			end
			if meta.visits then
				table.insert(metaParts, formatNumber(meta.visits) .. " visits")
			end
			if entry and Registry.entryMatchesCurrent(entry) then
				table.insert(metaParts, "Recognised in hub")
			end
			metaLbl.Text = table.concat(metaParts, " · ")

			local description = if entry and entry.description and entry.description ~= ""
				then entry.description
				else (meta.description or "No description returned for this universe.")

			renderGameSettings(meta)
			bodyLbl.Text = description

			local images: { string } = {}
			if entry and entry.images then
				for _, img in entry.images do
					table.insert(images, formatImage(img))
				end
			end
			for _, img in meta.images do
				table.insert(images, formatImage(img))
			end
			if #images == 0 then
				table.insert(images, GameMetadata.placeThumb(meta.placeId, 768, 432))
			end

			rebuildCarousel(images)

			if #slideEntries == 0 and #images > 0 then
				extraLbl.Text = "Thumbnails could not load. Executor needs request + getcustomasset, or rbxthumb support."
			end

			if entry then
				extraLbl.Text = "Hub script: " .. entry.script
			elseif meta.rootPlaceId then
				extraLbl.Text = string.format(
					"Website link uses root place id (e.g. roblox.com/games/%d/…)",
					meta.rootPlaceId
				)
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
