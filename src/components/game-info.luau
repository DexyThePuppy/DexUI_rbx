--!nonstrict
-- Game info panel: live universe metadata + thumbnails (Roblox Games / Thumbnails APIs).

local Registry = require("../hub/registry")
local GameMetadata = require("../hub/game-metadata")

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

	local function formatImage(url: string): string
		if string.find(url, "rbxassetid://", 1, true)
			or string.find(url, "rbxthumb://", 1, true)
			or string.find(url, "http", 1, true)
		then
			return url
		end
		local digits = string.match(url, "(%d+)")
		if digits then
			return "rbxassetid://" .. digits
		end
		return url
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

		local carouselScroll = Instance.new("ScrollingFrame")
		carouselScroll.Size = UDim2.fromScale(1, 1)
		carouselScroll.BackgroundTransparency = 1
		carouselScroll.BorderSizePixel = 0
		carouselScroll.ScrollBarThickness = 0
		carouselScroll.ScrollingDirection = Enum.ScrollingDirection.X
		carouselScroll.CanvasSize = UDim2.new(0, 0, 1, 0)
		carouselScroll.Parent = carouselShell

		local carouselPad = Instance.new("UIPadding")
		carouselPad.PaddingLeft = UDim.new(0, 8)
		carouselPad.PaddingRight = UDim.new(0, 8)
		carouselPad.Parent = carouselScroll

		local carouselList = Instance.new("UIListLayout")
		carouselList.FillDirection = Enum.FillDirection.Horizontal
		carouselList.Padding = UDim.new(0, 8)
		carouselList.SortOrder = Enum.SortOrder.LayoutOrder
		carouselList.Parent = carouselScroll

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
		local autoAdvance = 0
		local dotFrames: { Frame } = {}
		local carouselConn: RBXScriptConnection? = nil

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

		local function showSlide(index: number, count: number)
			if count <= 0 then
				return
			end
			slideIndex = ((index - 1) % count) + 1
			local offset = (slideIndex - 1) * 392
			tween(carouselScroll, "CanvasPosition", Vector2.new(offset, 0), 0.35)
			for i, dot in dotFrames do
				tween(dot, "BackgroundColor3", if i == slideIndex then curTheme.pri else curTheme.out, 0.2)
			end
		end

		local function rebuildCarousel(images: { string })
			for _, ch in carouselScroll:GetChildren() do
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

			local count = #images
			carouselScroll.CanvasSize = UDim2.new(0, math.max(0, count * 400), 1, 0)
			for i, imgUrl in images do
				local slide = Instance.new("ImageLabel")
				slide.LayoutOrder = i
				slide.Size = UDim2.new(0, 384, 1, -16)
				slide.Position = UDim2.new(0, 0, 0, 8)
				slide.BackgroundTransparency = 1
				slide.Image = formatImage(imgUrl)
				slide.ScaleType = Enum.ScaleType.Crop
				slide.Parent = carouselScroll
				corner(slide, 10)
			end

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
			carouselScroll.CanvasPosition = Vector2.zero

			if multi then
				autoAdvance = 0
				carouselConn = onHeartbeat(function()
					autoAdvance += 1
					if autoAdvance >= 240 then
						autoAdvance = 0
						showSlide(slideIndex + 1, count)
					end
				end)
			end
		end

		prevBtn.MouseButton1Click:Connect(function()
			playFeedback("light")
			showSlide(slideIndex - 1, #dotFrames)
			autoAdvance = 0
		end)
		nextBtn.MouseButton1Click:Connect(function()
			playFeedback("light")
			showSlide(slideIndex + 1, #dotFrames)
			autoAdvance = 0
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
