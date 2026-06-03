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
	local ContentProvider = Services.ContentProvider or game:GetService("ContentProvider")

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
		layout.Padding = UDim.new(0, 14)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = holder

		local titleLbl = Instance.new("TextLabel")
		titleLbl.LayoutOrder = 0
		titleLbl.Size = UDim2.new(1, 0, 0, 0)
		titleLbl.AutomaticSize = Enum.AutomaticSize.Y
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = "Loading experience…"
		titleLbl.FontFace = fontWeight(Enum.FontWeight.Bold)
		titleLbl.TextSize = 22
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.TextWrapped = true
		titleLbl.Parent = holder
		reg(titleLbl, "TextColor3", "fg")

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
		metaLbl.Parent = holder
		reg(metaLbl, "TextColor3", "out")

		local carouselShell = Instance.new("Frame")
		carouselShell.LayoutOrder = 2
		carouselShell.Size = UDim2.new(1, 0, 0, 200)
		carouselShell.BorderSizePixel = 0
		carouselShell.ClipsDescendants = true
		carouselShell.Parent = holder
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
		dots.LayoutOrder = 3
		dots.Size = UDim2.new(1, 0, 0, 8)
		dots.BackgroundTransparency = 1
		dots.Parent = holder

		local dotsLayout = Instance.new("UIListLayout")
		dotsLayout.FillDirection = Enum.FillDirection.Horizontal
		dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		dotsLayout.Padding = UDim.new(0, 6)
		dotsLayout.Parent = dots

		local bodyLbl = Instance.new("TextLabel")
		bodyLbl.LayoutOrder = 4
		bodyLbl.Size = UDim2.new(1, 0, 0, 0)
		bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
		bodyLbl.BackgroundTransparency = 1
		bodyLbl.Text = "Fetching name, description, and thumbnails from Roblox…"
		bodyLbl.FontFace = m3Font
		bodyLbl.TextSize = 14
		bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
		bodyLbl.TextWrapped = true
		bodyLbl.LineHeight = 1.15
		bodyLbl.Parent = holder
		reg(bodyLbl, "TextColor3", "fg")

		local extraLbl = Instance.new("TextLabel")
		extraLbl.LayoutOrder = 5
		extraLbl.Size = UDim2.new(1, 0, 0, 0)
		extraLbl.AutomaticSize = Enum.AutomaticSize.Y
		extraLbl.BackgroundTransparency = 1
		extraLbl.Text = ""
		extraLbl.FontFace = m3Font
		extraLbl.TextSize = 11
		extraLbl.TextXAlignment = Enum.TextXAlignment.Left
		extraLbl.TextWrapped = true
		extraLbl.Parent = holder
		reg(extraLbl, "TextColor3", "out")

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
		end)
	end
end
