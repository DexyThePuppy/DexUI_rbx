--!nonstrict
local Format = require("./format")

export type CarouselDeps = {
	section: Frame,
	layoutBase: number?,
	holder: Instance,
	curTheme: { pri: Color3, out: Color3, inact: Color3 },
	m3Font: Font,
	textSize: (string) -> number,
	reg: (Instance, string, string) -> (),
	corner: (Instance, number) -> (),
	playFeedback: (string) -> (),
	onHeartbeat: (() -> ()) -> RBXScriptConnection,
	ContentProvider: ContentProvider,
}

local ASPECT_16_9 = 9 / 16
local SIDE_GAP = 14
local SLOT_RADIUS = 12
local AUTO_SEC = 7
local MAX_CAROUSEL_SLIDES = 8

local function build(deps: CarouselDeps)
	local carouselSection = deps.section
	local base = deps.layoutBase or 0

	local carouselCenterW = 320
	local carouselCenterH = math.floor(carouselCenterW * ASPECT_16_9 + 0.5)
	local carouselSideW = 200
	local carouselSideH = math.floor(carouselSideW * ASPECT_16_9 + 0.5)

	local carouselShell = Instance.new("Frame")
	carouselShell.LayoutOrder = base
	carouselShell.Size = UDim2.new(1, 0, 0, carouselCenterH + 24)
	carouselShell.BorderSizePixel = 0
	carouselShell.ClipsDescendants = true
	carouselShell.Parent = carouselSection
	deps.corner(carouselShell, 14)
	deps.reg(carouselShell, "BackgroundColor3", "bg")

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
	emptyLbl.FontFace = deps.m3Font
	emptyLbl.TextSize = deps.textSize("md")
	emptyLbl.TextColor3 = deps.curTheme.out
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
		deps.corner(slot, SLOT_RADIUS)
		deps.reg(slot, "BackgroundColor3", "inact")

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
	dots.LayoutOrder = base + 1
	dots.Size = UDim2.new(1, 0, 0, 8)
	dots.BackgroundTransparency = 1
	dots.Parent = carouselSection

	local dotsLayout = Instance.new("UIListLayout")
	dotsLayout.FillDirection = Enum.FillDirection.Horizontal
	dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dotsLayout.Padding = UDim.new(0, 6)
	dotsLayout.Parent = dots

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
	prevBtn.FontFace = deps.m3Font
	prevBtn.TextSize = deps.textSize("lg")
	prevBtn.AutoButtonColor = false
	prevBtn.Visible = false
	prevBtn.ZIndex = 5
	prevBtn.Parent = carouselShell
	deps.corner(prevBtn, 999)
	deps.reg(prevBtn, "BackgroundColor3", "bg")
	deps.reg(prevBtn, "TextColor3", "fg")

	local nextBtn = Instance.new("TextButton")
	nextBtn.Size = UDim2.fromOffset(32, 32)
	nextBtn.AnchorPoint = Vector2.new(1, 0.5)
	nextBtn.Position = UDim2.new(1, -8, 0.5, 0)
	nextBtn.Text = ">"
	nextBtn.FontFace = deps.m3Font
	nextBtn.TextSize = deps.textSize("lg")
	nextBtn.AutoButtonColor = false
	nextBtn.Visible = false
	nextBtn.ZIndex = 5
	nextBtn.Parent = carouselShell
	deps.corner(nextBtn, 999)
	deps.reg(nextBtn, "BackgroundColor3", "bg")
	deps.reg(nextBtn, "TextColor3", "fg")

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
			dot.BackgroundColor3 = if i == active then deps.curTheme.pri else deps.curTheme.out
		end
	end

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

	local function isCachedUri(uri: string): boolean
		return string.find(uri, "rbxasset://", 1, true) ~= nil
	end

	local function uniqueImages(images: { string }): { string }
		local out: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, uri in images do
			local resolved = if isCachedUri(uri) or string.find(uri, "rbxassetid://", 1, true)
				then uri
				else Format.formatImage(uri)
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
			deps.corner(dot, 999)
			deps.reg(dot, "BackgroundColor3", if i == 1 then "pri" else "out")
			dot.MouseButton1Click:Connect(function()
				deps.playFeedback("light")
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
				deps.ContentProvider:PreloadAsync(preload)
			end)
		end

		scheduleCarouselLayout()

		if multi then
			carouselConn = deps.onHeartbeat(function()
				if os.clock() - lastAutoAt >= AUTO_SEC then
					goToSlide(slideIndex + 1)
				end
			end)
		end
	end

	prevBtn.MouseButton1Click:Connect(function()
		deps.playFeedback("light")
		goToSlide(slideIndex - 1)
	end)
	nextBtn.MouseButton1Click:Connect(function()
		deps.playFeedback("light")
		goToSlide(slideIndex + 1)
	end)
	slotLeft.MouseButton1Click:Connect(function()
		deps.playFeedback("light")
		goToSlide(slideIndex - 1)
	end)
	slotCenter.MouseButton1Click:Connect(function()
		deps.playFeedback("light")
		goToSlide(slideIndex)
	end)
	slotRight.MouseButton1Click:Connect(function()
		deps.playFeedback("light")
		goToSlide(slideIndex + 1)
	end)

	carouselTrack:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleCarouselLayout)
	carouselShell:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleCarouselLayout)

	local tabScroll: Instance? = deps.holder
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

	local winNode: Instance? = deps.holder
	while winNode and winNode.Name ~= "Window" do
		winNode = winNode.Parent
	end
	if winNode then
		winNode:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleCarouselLayout)
	end

	return {
		rebuildCarousel = rebuildCarousel,
		hasSlides = function(): boolean
			return #slideUris > 0
		end,
	}
end

return {
	build = build,
}
