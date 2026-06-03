--!nonstrict
-- Game info panel: title, image carousel, description (registry + live place data).

local Registry = require("../hub/registry")

return function(ctx)
	local lib = ctx.lib
	local curTheme = ctx.theme
	local reg, regDynamic = ctx.reg, ctx.regDynamic
	local tween, corner = ctx.tween, ctx.corner
	local m3Font = ctx.m3Font
	local beginCardRow = ctx.beginCardRow
	local fontWeight = ctx.fontWeight
	local onHeartbeat = ctx.onHeartbeat
	local playFeedback = ctx.playFeedback

	local function formatImage(url: string): string
		if string.find(url, "rbxassetid://", 1, true) or string.find(url, "rbxthumb://", 1, true) then
			return url
		end
		local digits = string.match(url, "(%d+)")
		if digits then
			return "rbxassetid://" .. digits
		end
		return url
	end

	function lib:AddGameInfo()
		local entry = Registry.findForCurrentGame()
		local live = Registry.getLivePlaceContext()

		local titleText = if entry then entry.name else (live.name or "Current experience")
		local description = if entry and entry.description
			then entry.description
			else (live.description or "No description available for this place.")

		local images: { string } = {}
		if entry and entry.images then
			for _, img in entry.images do
				table.insert(images, formatImage(img))
			end
		end
		if #images == 0 then
			table.insert(images, string.format("rbxthumb://type=Place&id=%d&w=768&h=432", live.placeId))
			if entry and entry.thumbnail then
				images[1] = formatImage(entry.thumbnail)
			end
		end

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
		titleLbl.Text = titleText
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
		metaLbl.Text = string.format(
			"Place %d · Universe %d%s",
			live.placeId,
			live.universeId,
			if entry and Registry.entryMatchesCurrent(entry) then " · Recognised in hub" else ""
		)
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
		carouselScroll.CanvasSize = UDim2.new(0, #images * 400, 1, 0)
		carouselScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
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

		for i, imgUrl in images do
			local slide = Instance.new("ImageLabel")
			slide.LayoutOrder = i
			slide.Size = UDim2.new(0, 384, 1, -16)
			slide.Position = UDim2.new(0, 0, 0, 8)
			slide.BackgroundTransparency = 1
			slide.Image = imgUrl
			slide.ScaleType = Enum.ScaleType.Crop
			slide.Parent = carouselScroll
			corner(slide, 10)
		end

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

		local dotFrames: { Frame } = {}
		for i = 1, #images do
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(8, 8)
			dot.BorderSizePixel = 0
			dot.LayoutOrder = i
			dot.Parent = dots
			corner(dot, 999)
			reg(dot, "BackgroundColor3", if i == 1 then "pri" else "out")
			table.insert(dotFrames, dot)
		end

		local slideIndex = 1
		local autoAdvance = 0

		local function showSlide(index: number)
			slideIndex = ((index - 1) % #images) + 1
			local offset = (slideIndex - 1) * 392
			tween(carouselScroll, "CanvasPosition", Vector2.new(offset, 0), 0.35)
			for i, dot in dotFrames do
				tween(dot, "BackgroundColor3", if i == slideIndex then curTheme.pri else curTheme.out, 0.2)
			end
		end

		if #images > 1 then
			onHeartbeat(function()
				autoAdvance += 1
				if autoAdvance >= 240 then
					autoAdvance = 0
					showSlide(slideIndex + 1)
				end
			end)
		end

		local prevBtn = Instance.new("TextButton")
		prevBtn.Size = UDim2.fromOffset(32, 32)
		prevBtn.AnchorPoint = Vector2.new(0, 0.5)
		prevBtn.Position = UDim2.new(0, 8, 0.5, 0)
		prevBtn.Text = "<"
		prevBtn.FontFace = m3Font
		prevBtn.TextSize = 18
		prevBtn.AutoButtonColor = false
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
		nextBtn.ZIndex = 5
		nextBtn.Parent = carouselShell
		corner(nextBtn, 999)
		reg(nextBtn, "BackgroundColor3", "bg")
		reg(nextBtn, "TextColor3", "fg")

		prevBtn.MouseButton1Click:Connect(function()
			playFeedback("light")
			showSlide(slideIndex - 1)
			autoAdvance = 0
		end)
		nextBtn.MouseButton1Click:Connect(function()
			playFeedback("light")
			showSlide(slideIndex + 1)
			autoAdvance = 0
		end)

		if #images <= 1 then
			prevBtn.Visible = false
			nextBtn.Visible = false
			dots.Visible = false
		end

		local bodyLbl = Instance.new("TextLabel")
		bodyLbl.LayoutOrder = 4
		bodyLbl.Size = UDim2.new(1, 0, 0, 0)
		bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
		bodyLbl.BackgroundTransparency = 1
		bodyLbl.Text = description
		bodyLbl.FontFace = m3Font
		bodyLbl.TextSize = 14
		bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
		bodyLbl.TextWrapped = true
		bodyLbl.LineHeight = 1.15
		bodyLbl.Parent = holder
		reg(bodyLbl, "TextColor3", "fg")

		if entry then
			local scriptLbl = Instance.new("TextLabel")
			scriptLbl.LayoutOrder = 5
			scriptLbl.Size = UDim2.new(1, 0, 0, 18)
			scriptLbl.BackgroundTransparency = 1
			scriptLbl.Text = "Hub script: " .. entry.script
			scriptLbl.FontFace = m3Font
			scriptLbl.TextSize = 11
			scriptLbl.TextXAlignment = Enum.TextXAlignment.Left
			scriptLbl.Parent = holder
			reg(scriptLbl, "TextColor3", "out")
		end
	end
end
