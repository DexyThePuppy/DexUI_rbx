--!nonstrict
export type MediaHit = { id: number, title: string, subtitle: string? }

export type PlayerApi = {
	stopPlayback: () -> (),
	playHit: (hit: MediaHit, kind: string) -> (),
}

export type CatalogDeps = {
	browseSection: Frame,
	resultsSection: Frame,
	player: PlayerApi,
	curTheme: { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 },
	reg: (Instance, string, string) -> (),
	corner: (Instance, number) -> (),
	tween: (Instance, string, any, number) -> (),
	m3Font: Font,
	fontChrome: Font,
	fontEmphasis: Font,
	applyTextLabel: (TextLabel, Font, number, string?) -> (),
	textSize: (string) -> number,
	playFeedback: (string) -> (),
	tooltip: any?,
	RunService: RunService,
	win: Instance,
	searchCreatorStoreVideos: (string, string?) -> ({ any }, string?, string?),
	searchCreatorStoreAudio: (string, any, boolean) -> ({ any }, any, string?),
	pageSize: number,
	pageCount: number,
}

local function build(deps: CatalogDeps)
	local browseSection = deps.browseSection
	local resultsSection = deps.resultsSection
	local curTheme = deps.curTheme
	local reg = deps.reg
	local corner = deps.corner
	local tween = deps.tween
	local m3Font = deps.m3Font
	local fontChrome = deps.fontChrome
	local fontEmphasis = deps.fontEmphasis
	local applyTextLabel = deps.applyTextLabel
	local textSize = deps.textSize
	local playFeedback = deps.playFeedback
	local tooltip = deps.tooltip
	local RunService = deps.RunService
	local win = deps.win
	local pageSize = deps.pageSize
	local pageCount = deps.pageCount
	local searchCreatorStoreVideos = deps.searchCreatorStoreVideos
	local searchCreatorStoreAudio = deps.searchCreatorStoreAudio

	local keywordText = ""
	local searching = false
	local mediaKind = "Videos"
	local results: { MediaHit } = {}
	local pageIndex = 0
	local nextPageToken: string? = nil
	local audioPagesHandle: any = nil

	local subTabArea = Instance.new("Frame")
	subTabArea.Name = "SubTabs"
	subTabArea.LayoutOrder = 0
	subTabArea.Size = UDim2.new(1, 0, 0, 40)
	subTabArea.BackgroundTransparency = 1
	subTabArea.ClipsDescendants = true
	subTabArea.Parent = browseSection

	local subTabListCont = Instance.new("Frame")
	subTabListCont.Size = UDim2.new(1, 0, 1, 0)
	subTabListCont.BackgroundTransparency = 1
	subTabListCont.Parent = subTabArea

	local subTabListInner = Instance.new("Frame")
	subTabListInner.Size = UDim2.new(1, 0, 1, 0)
	subTabListInner.BackgroundTransparency = 1
	subTabListInner.AutomaticSize = Enum.AutomaticSize.X
	subTabListInner.AnchorPoint = Vector2.new(0.5, 0.5)
	subTabListInner.Position = UDim2.fromScale(0.5, 0.5)
	subTabListInner.ZIndex = 2
	subTabListInner.Parent = subTabListCont

	local subTabButtonRow = Instance.new("Frame")
	subTabButtonRow.Name = "ButtonRow"
	subTabButtonRow.Size = UDim2.new(0, 0, 1, 0)
	subTabButtonRow.AutomaticSize = Enum.AutomaticSize.X
	subTabButtonRow.BackgroundTransparency = 1
	subTabButtonRow.ZIndex = 2
	subTabButtonRow.Parent = subTabListInner

	-- Highlight sits outside the UIListLayout so manual position tweens aren't overwritten.
	local subTabHighlight = Instance.new("Frame")
	subTabHighlight.Name = "SubHighlight"
	subTabHighlight.BackgroundColor3 = curTheme.pri
	subTabHighlight.BorderSizePixel = 0
	subTabHighlight.Size = UDim2.fromOffset(0, 32)
	subTabHighlight.ZIndex = 1
	subTabHighlight.Parent = subTabListInner
	corner(subTabHighlight, 999)
	reg(subTabHighlight, "BackgroundColor3", "pri")

	local subTabLayout = Instance.new("UIListLayout")
	subTabLayout.FillDirection = Enum.FillDirection.Horizontal
	subTabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	subTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	subTabLayout.Padding = UDim.new(0, 8)
	subTabLayout.Parent = subTabButtonRow

	type SubTabData = { btn: TextButton, label: TextLabel, icon: ImageLabel?, kind: string, active: boolean }
	local subTabs: { SubTabData } = {}
	local selectMediaKind: (string) -> ()

	local function moveSubTabHighlight(btn: TextButton, dur: number?)
		task.spawn(function()
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()
			local relX = btn.AbsolutePosition.X - subTabListInner.AbsolutePosition.X
			local relY = btn.AbsolutePosition.Y - subTabListInner.AbsolutePosition.Y
			local d = dur or 0.35
			tween(subTabHighlight, "Position", UDim2.fromOffset(relX, relY), d)
			tween(subTabHighlight, "Size", UDim2.fromOffset(btn.AbsoluteSize.X, btn.AbsoluteSize.Y), d)
		end)
	end

	local function refreshSubTabHighlight(dur: number?)
		for _, tData in subTabs do
			if tData.active then
				moveSubTabHighlight(tData.btn, dur or 0)
				break
			end
		end
	end

	local function applySubTabVisual(tData: SubTabData, active: boolean, dur: number?)
		local d = dur or 0.3
		tData.active = active
		if active then
			moveSubTabHighlight(tData.btn, d)
			tween(tData.label, "TextColor3", curTheme.onpri, d)
			if tData.icon then
				tween(tData.icon, "ImageColor3", curTheme.onpri, d)
			end
		else
			tween(tData.label, "TextColor3", curTheme.out, d)
			if tData.icon then
				tween(tData.icon, "ImageColor3", curTheme.out, d)
			end
		end
	end

	local function makeSubTab(kind: string, iconId: number)
		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.AutomaticSize = Enum.AutomaticSize.X
		btn.Size = UDim2.new(0, 0, 0, 32)
		btn.ZIndex = 2
		btn.Parent = subTabButtonRow

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = btn

		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row.Padding = UDim.new(0, 6)
		row.Parent = btn

		local iconObj = Instance.new("ImageLabel")
		iconObj.Size = UDim2.new(0, 18, 0, 18)
		iconObj.BackgroundTransparency = 1
		iconObj.Image = "rbxassetid://" .. iconId
		iconObj.ImageColor3 = curTheme.out
		iconObj.LayoutOrder = 0
		iconObj.ZIndex = 3
		iconObj.Parent = btn

		local label = Instance.new("TextLabel")
		label.Text = kind
		applyTextLabel(label, fontChrome, textSize("md"), "autoX")
		label.TextColor3 = curTheme.out
		label.LayoutOrder = 1
		label.ZIndex = 3
		label.Parent = btn

		local tData: SubTabData = { btn = btn, label = label, icon = iconObj, kind = kind, active = false }
		table.insert(subTabs, tData)

		btn.MouseButton1Click:Connect(function()
			selectMediaKind(kind)
			playFeedback("selection")
		end)
	end

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Name = "Status"
	statusLbl.LayoutOrder = 2
	statusLbl.Size = UDim2.new(1, 0, 0, 0)
	statusLbl.AutomaticSize = Enum.AutomaticSize.Y
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = "Browse Creator Store videos or audio. Use Search or pick a result to play."
	statusLbl.FontFace = m3Font
	statusLbl.TextSize = textSize("sm")
	statusLbl.TextWrapped = true
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.Parent = browseSection
	reg(statusLbl, "TextColor3", "out")

	local function setStatus(text: string, token: string?)
		statusLbl.Text = text
		if token then
			statusLbl.TextColor3 = curTheme[token]
		else
			statusLbl.TextColor3 = curTheme.out
		end
	end

	local searchFrame = Instance.new("Frame")
	searchFrame.LayoutOrder = 1
	searchFrame.Size = UDim2.new(1, 0, 0, 56)
	searchFrame.BorderSizePixel = 0
	searchFrame.Parent = browseSection
	corner(searchFrame, 14)
	reg(searchFrame, "BackgroundColor3", "bg")

	local searchLbl = Instance.new("TextLabel")
	searchLbl.Size = UDim2.new(1, -120, 0, 20)
	searchLbl.Position = UDim2.new(0, 16, 0, 6)
	searchLbl.BackgroundTransparency = 1
	searchLbl.Text = "Search"
	searchLbl.FontFace = m3Font
	searchLbl.TextSize = textSize("sm")
	searchLbl.TextXAlignment = Enum.TextXAlignment.Left
	searchLbl.Parent = searchFrame
	reg(searchLbl, "TextColor3", "out")

	local searchBtn = Instance.new("TextButton")
	searchBtn.Size = UDim2.new(0, 88, 0, 36)
	searchBtn.AnchorPoint = Vector2.new(1, 0.5)
	searchBtn.Position = UDim2.new(1, -8, 0.5, 0)
	searchBtn.Text = "Search"
	searchBtn.FontFace = fontEmphasis
	searchBtn.TextSize = textSize("md")
	searchBtn.AutoButtonColor = false
	searchBtn.Parent = searchFrame
	corner(searchBtn, 999)
	reg(searchBtn, "BackgroundColor3", "pri")
	reg(searchBtn, "TextColor3", "onpri")

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -112, 0, 24)
	searchBox.Position = UDim2.new(0, 16, 0, 26)
	searchBox.BackgroundTransparency = 1
	searchBox.PlaceholderText = "Keyword (optional — blank shows popular)"
	searchBox.Text = ""
	searchBox.FontFace = m3Font
	searchBox.TextSize = textSize("md")
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = searchFrame
	reg(searchBox, "TextColor3", "fg")

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		keywordText = searchBox.Text
	end)

	local resultsFrame = Instance.new("Frame")
	resultsFrame.Name = "Results"
	resultsFrame.LayoutOrder = 0
	resultsFrame.Size = UDim2.new(1, 0, 0, pageSize * 52)
	resultsFrame.BackgroundTransparency = 1
	resultsFrame.Parent = resultsSection

	local resultsLayout = Instance.new("UIListLayout")
	resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resultsLayout.Padding = UDim.new(0, 6)
	resultsLayout.Parent = resultsFrame

	local resultBtns: { TextButton } = {}

	local function playResult(hit: MediaHit)
		deps.player.playHit(hit, mediaKind)
		local detail = if hit.subtitle then hit.title .. " · " .. hit.subtitle else hit.title
		setStatus("Playing · " .. detail, "fg")
	end

	for i = 1, pageSize do
		local row = Instance.new("TextButton")
		row.Name = "Result" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 46)
		row.BackgroundTransparency = 0.4
		row.Text = ""
		row.AutoButtonColor = false
		row.Visible = false
		row.Parent = resultsFrame
		corner(row, 10)
		reg(row, "BackgroundColor3", "bg")

		local rowTitle = Instance.new("TextLabel")
		rowTitle.Name = "Title"
		rowTitle.Size = UDim2.new(1, -24, 0, 20)
		rowTitle.Position = UDim2.new(0, 12, 0, 4)
		rowTitle.BackgroundTransparency = 1
		rowTitle.Text = ""
		rowTitle.FontFace = fontEmphasis
		rowTitle.TextSize = textSize("md")
		rowTitle.TextXAlignment = Enum.TextXAlignment.Left
		rowTitle.TextTruncate = Enum.TextTruncate.AtEnd
		rowTitle.Parent = row
		reg(rowTitle, "TextColor3", "fg")

		local rowSub = Instance.new("TextLabel")
		rowSub.Name = "Subtitle"
		rowSub.Size = UDim2.new(1, -24, 0, 16)
		rowSub.Position = UDim2.new(0, 12, 0, 24)
		rowSub.BackgroundTransparency = 1
		rowSub.Text = ""
		rowSub.FontFace = m3Font
		rowSub.TextSize = textSize("sm")
		rowSub.TextXAlignment = Enum.TextXAlignment.Left
		rowSub.TextTruncate = Enum.TextTruncate.AtEnd
		rowSub.Parent = row
		reg(rowSub, "TextColor3", "out")

		row.MouseEnter:Connect(function()
			tween(row, "BackgroundTransparency", 0.1, 0.15)
		end)
		row.MouseLeave:Connect(function()
			tween(row, "BackgroundTransparency", 0.4, 0.15)
		end)

		local slot = i
		row.MouseButton1Click:Connect(function()
			local hit = results[pageIndex * pageSize + slot]
			if hit then
				playResult(hit)
			end
		end)

		if tooltip then
			tooltip.attach(row, function()
				local hit = results[pageIndex * pageSize + slot]
				if not hit then
					return nil
				end
				local blocks: { any } = {
					{ kind = "title", text = hit.title },
				}
				if hit.subtitle and hit.subtitle ~= "" then
					table.insert(blocks, { kind = "text", text = hit.subtitle })
				end
				table.insert(blocks, { kind = "divider" })
				table.insert(blocks, {
					kind = "stat",
					label = "Asset ID",
					value = tostring(hit.id),
				})
				return { blocks = blocks, maxWidth = 300 }
			end, { delay = 0.35 })
		end

		resultBtns[i] = row
	end

	local pagerRow = Instance.new("Frame")
	pagerRow.LayoutOrder = 1
	pagerRow.Size = UDim2.new(1, 0, 0, 36)
	pagerRow.BackgroundTransparency = 1
	pagerRow.Parent = resultsSection

	local pagerLayout = Instance.new("UIListLayout")
	pagerLayout.FillDirection = Enum.FillDirection.Horizontal
	pagerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pagerLayout.Padding = UDim.new(0, 6)
	pagerLayout.Parent = pagerRow

	local pageBtns: { TextButton } = {}
	local nextBtn: TextButton

	local function refreshPagerHighlight()
		for idx, btn in pageBtns do
			local active = (idx - 1) == pageIndex
			if active then
				btn.BackgroundColor3 = curTheme.pri
				btn.TextColor3 = curTheme.onpri
			else
				btn.BackgroundColor3 = curTheme.inact
				btn.TextColor3 = curTheme.fg
			end
		end
	end

	local function renderResults()
		local startIdx = pageIndex * pageSize + 1
		for i = 1, pageSize do
			local hit = results[startIdx + i - 1]
			local row = resultBtns[i]
			if hit then
				row.Visible = true
				local titleLbl = row:FindFirstChild("Title") :: TextLabel
				local subLbl = row:FindFirstChild("Subtitle") :: TextLabel
				titleLbl.Text = hit.title
				subLbl.Text = hit.subtitle or ""
			else
				row.Visible = false
			end
		end
		refreshPagerHighlight()
	end

	for pageNum = 0, pageCount - 1 do
		local btn = Instance.new("TextButton")
		btn.Name = "Page" .. pageNum
		btn.Size = UDim2.new(0, 28, 0, 28)
		btn.Text = tostring(pageNum)
		btn.FontFace = fontEmphasis
		btn.TextSize = textSize("sm")
		btn.AutoButtonColor = false
		btn.Parent = pagerRow
		corner(btn, 999)
		reg(btn, "BackgroundColor3", "inact")
		reg(btn, "TextColor3", "fg")
		pageBtns[pageNum + 1] = btn

		btn.MouseButton1Click:Connect(function()
			pageIndex = pageNum
			renderResults()
			playFeedback("light")
		end)
	end

	nextBtn = Instance.new("TextButton")
	nextBtn.Name = "PageNext"
	nextBtn.Size = UDim2.new(0, 28, 0, 28)
	nextBtn.Text = ">"
	nextBtn.FontFace = fontEmphasis
	nextBtn.TextSize = textSize("sm")
	nextBtn.AutoButtonColor = false
	nextBtn.Parent = pagerRow
	corner(nextBtn, 999)
	reg(nextBtn, "BackgroundColor3", "inact")
	reg(nextBtn, "TextColor3", "fg")

	local function runSearch(fetchNext: boolean?)
		if searching then
			return
		end
		local query = keywordText ~= "" and keywordText or searchBox.Text
		searching = true
		setStatus(if fetchNext then "Loading next page…" else "Searching Creator Store…")
		playFeedback("light")

		task.spawn(function()
			local hits: { MediaHit } = {}
			local err: string? = nil

			if mediaKind == "Videos" then
				local token = if fetchNext then nextPageToken else nil
				hits, nextPageToken, err = searchCreatorStoreVideos(query, token)
				audioPagesHandle = nil
			else
				local handle = if fetchNext then audioPagesHandle else nil
				hits, audioPagesHandle, err = searchCreatorStoreAudio(query, handle, fetchNext == true)
				nextPageToken = if audioPagesHandle and not audioPagesHandle.IsFinished then "audio" else nil
			end

			searching = false
			if err and #hits == 0 then
				setStatus(err, "pri")
				return
			end
			if #hits == 0 then
				results = {}
				pageIndex = 0
				renderResults()
				local label = if query ~= "" then "No results for \"" .. query .. "\"." else "No results."
				setStatus(label, "out")
				return
			end

			results = hits
			if not fetchNext then
				pageIndex = 0
			end
			renderResults()
			setStatus(
				string.format("%d result(s) · page %d · %s", #results, pageIndex, mediaKind),
				"fg"
			)
		end)
	end

	nextBtn.MouseButton1Click:Connect(function()
		if searching then
			return
		end
		if pageIndex < pageCount - 1 and (pageIndex + 1) * pageSize < #results then
			pageIndex += 1
			renderResults()
			setStatus(string.format("%d result(s) · page %d", #results, pageIndex), "fg")
			playFeedback("light")
			return
		end
		if mediaKind == "Videos" and nextPageToken then
			pageIndex = 0
			runSearch(true)
		elseif mediaKind == "Audio" and audioPagesHandle and not audioPagesHandle.IsFinished then
			pageIndex = 0
			runSearch(true)
		else
			setStatus("No more pages.", "out")
		end
	end)

	searchBtn.MouseButton1Click:Connect(function()
		runSearch(nil)
	end)

	searchBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			runSearch(nil)
		end
	end)

	local function selectMediaKindImpl(kind: string)
		if mediaKind == kind then
			return
		end
		deps.player.stopPlayback()
		mediaKind = kind
		results = {}
		pageIndex = 0
		nextPageToken = nil
		audioPagesHandle = nil
		searchLbl.Text = if kind == "Videos" then "Search videos" else "Search audio"
		for _, tData in subTabs do
			applySubTabVisual(tData, tData.kind == kind)
		end
		renderResults()
		runSearch(nil)
	end
	selectMediaKind = selectMediaKindImpl

	makeSubTab("Videos", 6026671213) -- videocam (Material Icons)
	makeSubTab("Audio", 6031471489) -- audiotrack (Material Icons)

	subTabArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		refreshSubTabHighlight(0)
	end)
	subTabListInner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		refreshSubTabHighlight(0)
	end)
	subTabButtonRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		refreshSubTabHighlight(0)
	end)
	subTabButtonRow:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		refreshSubTabHighlight(0)
	end)
	subTabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		refreshSubTabHighlight(0)
	end)
	win:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		refreshSubTabHighlight(0)
	end)

	task.defer(function()
		for _, tData in subTabs do
			applySubTabVisual(tData, tData.kind == "Videos", 0)
		end
		task.defer(function()
			refreshSubTabHighlight(0)
		end)
		runSearch(nil)
	end)

	refreshPagerHighlight()
	end

return { build = build }
