--!nonstrict
export type ServersDeps = {
	section: Frame,
	curTheme: { pri: Color3, fg: Color3, onpri: Color3, inact: Color3 },
	m3Font: Font,
	fontEmphasis: Font,
	textSize: (string) -> number,
	reg: (Instance, string, string) -> (),
	corner: (Instance, number) -> (),
	playFeedback: (string) -> (),
	tooltip: any?,
	Players: Players,
	TeleportService: TeleportService,
	pageSize: number,
	pageCount: number,
}

local function build(deps: ServersDeps)
	local serversSection = deps.section
	local order = 0

	local serversStatusLbl = Instance.new("TextLabel")
	serversStatusLbl.LayoutOrder = order
	serversStatusLbl.Size = UDim2.new(1, 0, 0, 0)
	serversStatusLbl.AutomaticSize = Enum.AutomaticSize.Y
	serversStatusLbl.BackgroundTransparency = 1
	serversStatusLbl.Text = "Loading public servers…"
	serversStatusLbl.FontFace = deps.m3Font
	serversStatusLbl.TextSize = deps.textSize("sm")
	serversStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
	serversStatusLbl.TextWrapped = true
	serversStatusLbl.Parent = serversSection
	deps.reg(serversStatusLbl, "TextColor3", "out")
	order += 1

	local serversList = Instance.new("Frame")
	serversList.Name = "ServerList"
	serversList.LayoutOrder = order
	serversList.Size = UDim2.new(1, 0, 0, deps.pageSize * 52)
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
		return math.ceil(#publicServers / deps.pageSize)
	end

	for i = 1, deps.pageSize do
		local row = Instance.new("TextButton")
		row.Name = "ServerRow" .. i
		row.LayoutOrder = i
		row.Text = ""
		row.AutoButtonColor = false
		row.Size = UDim2.new(1, 0, 0, 46)
		row.BackgroundTransparency = 0.4
		row.Visible = false
		row.Parent = serversList
		deps.corner(row, 10)
		deps.reg(row, "BackgroundColor3", "bg")

		local rowTitle = Instance.new("TextLabel")
		rowTitle.Name = "Title"
		rowTitle.Size = UDim2.new(1, -100, 0, 20)
		rowTitle.Position = UDim2.new(0, 12, 0, 4)
		rowTitle.BackgroundTransparency = 1
		rowTitle.Text = ""
		rowTitle.FontFace = deps.fontEmphasis
		rowTitle.TextSize = deps.textSize("md")
		rowTitle.TextXAlignment = Enum.TextXAlignment.Left
		rowTitle.TextTruncate = Enum.TextTruncate.AtEnd
		rowTitle.Active = false
		rowTitle.Selectable = false
		rowTitle.Parent = row
		deps.reg(rowTitle, "TextColor3", "fg")

		local rowSub = Instance.new("TextLabel")
		rowSub.Name = "Subtitle"
		rowSub.Size = UDim2.new(1, -100, 0, 16)
		rowSub.Position = UDim2.new(0, 12, 0, 24)
		rowSub.BackgroundTransparency = 1
		rowSub.Text = ""
		rowSub.FontFace = deps.m3Font
		rowSub.TextSize = deps.textSize("sm")
		rowSub.TextXAlignment = Enum.TextXAlignment.Left
		rowSub.TextTruncate = Enum.TextTruncate.AtEnd
		rowSub.Active = false
		rowSub.Selectable = false
		rowSub.Parent = row
		deps.reg(rowSub, "TextColor3", "out")

		local joinBtn = Instance.new("TextButton")
		joinBtn.Name = "Join"
		joinBtn.Size = UDim2.fromOffset(72, 30)
		joinBtn.AnchorPoint = Vector2.new(1, 0.5)
		joinBtn.Position = UDim2.new(1, -10, 0.5, 0)
		joinBtn.Text = "Join"
		joinBtn.FontFace = deps.fontEmphasis
		joinBtn.TextSize = deps.textSize("sm")
		joinBtn.AutoButtonColor = false
		joinBtn.ZIndex = 4
		joinBtn.Parent = row
		deps.corner(joinBtn, 8)
		deps.reg(joinBtn, "BackgroundColor3", "pri")
		deps.reg(joinBtn, "TextColor3", "onpri")

		local slot = i
		joinBtn.MouseButton1Click:Connect(function()
			local srv = publicServers[serverPageIndex * deps.pageSize + slot]
			if not srv then
				return
			end
			deps.playFeedback("light")
			local player = deps.Players.LocalPlayer
			if not player then
				return
			end
			serversStatusLbl.Text = "Joining server…"
			pcall(function()
				deps.TeleportService:TeleportToPlaceInstance(joinPlaceId, srv.id, player)
			end)
		end)

		if deps.tooltip then
			local slotIndex = i
			deps.tooltip.attach(row, function()
				return buildServerTooltip(publicServers[serverPageIndex * deps.pageSize + slotIndex])
			end, { delay = 0.35 })
		end

		serverRowBtns[i] = row
	end

	order += 1

	local pagerRow = Instance.new("Frame")
	pagerRow.LayoutOrder = order
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
				btn.BackgroundColor3 = deps.curTheme.pri
				btn.TextColor3 = deps.curTheme.onpri
			else
				btn.BackgroundColor3 = deps.curTheme.inact
				btn.TextColor3 = deps.curTheme.fg
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
		local startIdx = serverPageIndex * deps.pageSize + 1
		for i = 1, deps.pageSize do
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

	for pageNum = 0, deps.pageCount - 1 do
		local btn = Instance.new("TextButton")
		btn.Name = "Page" .. pageNum
		btn.Size = UDim2.fromOffset(28, 28)
		btn.Text = tostring(pageNum)
		btn.FontFace = deps.fontEmphasis
		btn.TextSize = deps.textSize("sm")
		btn.AutoButtonColor = false
		btn.Visible = false
		btn.Parent = pagerRow
		deps.corner(btn, 999)
		deps.reg(btn, "BackgroundColor3", "inact")
		deps.reg(btn, "TextColor3", "fg")
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
				deps.playFeedback("light")
			end
		end)
	end

	local pageNextBtn = Instance.new("TextButton")
	pageNextBtn.Name = "PageNext"
	pageNextBtn.Size = UDim2.fromOffset(28, 28)
	pageNextBtn.Text = ">"
	pageNextBtn.FontFace = deps.fontEmphasis
	pageNextBtn.TextSize = deps.textSize("sm")
	pageNextBtn.AutoButtonColor = false
	pageNextBtn.Parent = pagerRow
	deps.corner(pageNextBtn, 999)
	deps.reg(pageNextBtn, "BackgroundColor3", "inact")
	deps.reg(pageNextBtn, "TextColor3", "fg")

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
			deps.playFeedback("light")
		else
			serversStatusLbl.Text = "No more pages."
		end
	end)

	local function setPublicServers(servers: { any }, placeId: number, err: string?)
		publicServers = servers
		joinPlaceId = placeId
		serverPageIndex = 0
		renderPublicServers()

		local pages = serverPageCount()
		if #publicServers == 0 then
			serversStatusLbl.Text = err or "No public servers returned for this experience."
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
	end

	return {
		statusLbl = serversStatusLbl,
		setPublicServers = setPublicServers,
	}
end

return {
	build = build,
}
