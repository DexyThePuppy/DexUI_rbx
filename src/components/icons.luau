--!nonstrict
-- DexUI icons component. Attached onto the window's lib via the shared ctx.
return function(ctx)
		local lib = ctx.lib
	local curTheme = ctx.theme
	local reg, regDynamic = ctx.reg, ctx.regDynamic
	local tween, corner, ripple = ctx.tween, ctx.corner, ctx.ripple
	local fontWeight, m3Font = ctx.fontWeight, ctx.m3Font
	local beginBuildCard, beginCardRow, closeBuildCard = ctx.beginBuildCard, ctx.beginCardRow, ctx.closeBuildCard
	local nextCardItemOrder, refreshCardRowCorners, styleGroupedSurfaces, tintRow = ctx.nextCardItemOrder, ctx.refreshCardRowCorners, ctx.styleGroupedSurfaces, ctx.tintRow
	local indexElement, fillLabelColumn = ctx.indexElement, ctx.fillLabelColumn
	local playFeedback, playSliderTick = ctx.playFeedback, ctx.playSliderTick
	local onRender, onHeartbeat = ctx.onRender, ctx.onHeartbeat
	local onInputBegan, onInputChanged, onInputEnded = ctx.onInputBegan, ctx.onInputChanged, ctx.onInputEnded
	local track = ctx.track
	local STD_TWEEN, M3_EASE = ctx.STD_TWEEN, ctx.M3_EASE
	local isPrimaryInput, isMoveInput, isGrabInput, screenMouseLocation = ctx.isPrimaryInput, ctx.isMoveInput, ctx.isGrabInput, ctx.screenMouseLocation
	local captureDragTrack1D, fractionFromDragTrack = ctx.captureDragTrack1D, ctx.fractionFromDragTrack
	local captureDragTrack2D, pointFromDragTrack2D = ctx.captureDragTrack2D, ctx.pointFromDragTrack2D
	local httpRequest, trySetClipboard = ctx.httpRequest, ctx.trySetClipboard
	local formatMediaDuration, formatMediaClock = ctx.formatMediaDuration, ctx.formatMediaClock
	local searchCreatorStoreVideos, searchCreatorStoreAudio = ctx.searchCreatorStoreVideos, ctx.searchCreatorStoreAudio
	local formatMaterialIconCode, loadMaterialIconLibrary = ctx.formatMaterialIconCode, ctx.loadMaterialIconLibrary
	local MEDIA_PAGE_SIZE, MEDIA_PAGE_COUNT = ctx.MEDIA_PAGE_SIZE, ctx.MEDIA_PAGE_COUNT
	local TweenService, UserInputService, RunService = ctx.TweenService, ctx.UserInputService, ctx.RunService
	local Players, HttpService, SoundService = ctx.Players, ctx.HttpService, ctx.SoundService
	local GuiService, ContextActionService, AssetService, Workspace, CoreGui = ctx.GuiService, ctx.ContextActionService, ctx.AssetService, ctx.Workspace, ctx.CoreGui
	local popupLayer = ctx.popupLayer
	local win, gui = ctx.win, ctx.gui
	type Palette = { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 }
	type Callback = (...any) -> ()
	type MediaHit = { id: number, title: string, subtitle: string? }

	function lib:AddIconBrowser()
		local holder = Instance.new("Frame")
		holder.Name = "IconBrowser"
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.Parent = beginCardRow(nil, true)
		indexElement("Icon Browser", holder)

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 10)
		layout.Parent = holder

		local searchFrame = Instance.new("Frame")
		searchFrame.LayoutOrder = 1
		searchFrame.Size = UDim2.new(1, 0, 0, 46)
		searchFrame.BorderSizePixel = 0
		searchFrame.Parent = holder
		corner(searchFrame, 999)
		reg(searchFrame, "BackgroundColor3", "bg")

		local searchIcon = Instance.new("ImageLabel")
		searchIcon.Size = UDim2.new(0, 20, 0, 20)
		searchIcon.AnchorPoint = Vector2.new(0, 0.5)
		searchIcon.Position = UDim2.new(0, 16, 0.5, 0)
		searchIcon.BackgroundTransparency = 1
		searchIcon.Image = "rbxassetid://6031154871" -- search (Material Icons)
		searchIcon.Parent = searchFrame
		reg(searchIcon, "ImageColor3", "out")

		local searchBox = Instance.new("TextBox")
		searchBox.Size = UDim2.new(1, -56, 1, 0)
		searchBox.Position = UDim2.new(0, 46, 0, 0)
		searchBox.BackgroundTransparency = 1
		searchBox.PlaceholderText = "Search Material icons"
		searchBox.Text = ""
		searchBox.FontFace = m3Font
		searchBox.TextSize = 15
		searchBox.TextXAlignment = Enum.TextXAlignment.Left
		searchBox.TextYAlignment = Enum.TextYAlignment.Center
		searchBox.ClearTextOnFocus = false
		searchBox.Parent = searchFrame
		reg(searchBox, "TextColor3", "fg")
		reg(searchBox, "PlaceholderColor3", "out")

		local statusLbl = Instance.new("TextLabel")
		statusLbl.LayoutOrder = 2
		statusLbl.Size = UDim2.new(1, 0, 0, 16)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Text = "Loading Material Icons…"
		statusLbl.FontFace = fontWeight(Enum.FontWeight.Medium)
		statusLbl.TextSize = 11
		statusLbl.TextXAlignment = Enum.TextXAlignment.Left
		statusLbl.Parent = holder
		reg(statusLbl, "TextColor3", "out")

		local gridHost = Instance.new("Frame")
		gridHost.LayoutOrder = 3
		gridHost.Size = UDim2.new(1, 0, 0, 430)
		gridHost.BackgroundTransparency = 1
		gridHost.ClipsDescendants = true
		gridHost.Parent = holder
		corner(gridHost, 16)
		reg(gridHost, "BackgroundColor3", "bg")

		local gridScroll = Instance.new("ScrollingFrame")
		gridScroll.Size = UDim2.fromScale(1, 1)
		gridScroll.BackgroundTransparency = 1
		gridScroll.BorderSizePixel = 0
		gridScroll.ScrollBarThickness = 4
		gridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		gridScroll.Parent = gridHost

		local gridPad = Instance.new("UIPadding")
		gridPad.PaddingTop = UDim.new(0, 10)
		gridPad.PaddingBottom = UDim.new(0, 10)
		gridPad.PaddingLeft = UDim.new(0, 10)
		gridPad.PaddingRight = UDim.new(0, 10)
		gridPad.Parent = gridScroll

		local gridInner = Instance.new("Frame")
		gridInner.Size = UDim2.new(1, -20, 0, 0)
		gridInner.AutomaticSize = Enum.AutomaticSize.Y
		gridInner.BackgroundTransparency = 1
		gridInner.Parent = gridScroll

		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellSize = UDim2.fromOffset(96, 88)
		gridLayout.CellPadding = UDim2.fromOffset(8, 8)
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = gridInner

		type IconCell = { root: TextButton, name: string, nameLower: string, id: number }
		local cells: { IconCell } = {}

		local function setStatusCount(shown: number, total: number, filtering: boolean)
			if filtering then
				statusLbl.Text = string.format("%d of %d icons matching", shown, total)
			else
				statusLbl.Text = string.format("%d icons — click to copy code", total)
			end
		end

		local function applyFilter()
			local query = string.lower(string.gsub(searchBox.Text, "^%s+", ""))
			query = string.gsub(query, "%s+$", "")
			local shown = 0
			for _, cell in cells do
				local match = query == "" or string.find(cell.nameLower, query, 1, true) ~= nil
				cell.root.Visible = match
				if match then
					shown += 1
				end
			end
			setStatusCount(shown, #cells, query ~= "")
		end

		local function copyIcon(cell: IconCell)
			local snippet = formatMaterialIconCode(cell.name, cell.id)
			if trySetClipboard(snippet) then
				lib:Notify({
					Title = "Copied",
					Content = cell.name,
					Duration = 2,
				})
			else
				lib:Notify({
					Title = cell.name,
					Content = snippet,
					Duration = 6,
				})
			end
			playFeedback("selection")
		end

		local function makeIconCell(icon: { name: string, id: number }, order: number)
			local btn = Instance.new("TextButton")
			btn.Name = icon.name
			btn.LayoutOrder = order
			btn.BackgroundTransparency = 0
			btn.Text = ""
			btn.AutoButtonColor = false
			btn.ClipsDescendants = true
			btn.Parent = gridInner
			corner(btn, 14)
			reg(btn, "BackgroundColor3", "inact")

			-- M3 state layer for hover/press feedback.
			local state = Instance.new("Frame")
			state.Size = UDim2.fromScale(1, 1)
			state.BackgroundTransparency = 1
			state.BorderSizePixel = 0
			state.ZIndex = 2
			state.Parent = btn
			corner(state, 14)
			reg(state, "BackgroundColor3", "fg")

			local iconImg = Instance.new("ImageLabel")
			iconImg.Size = UDim2.fromOffset(40, 40)
			iconImg.AnchorPoint = Vector2.new(0.5, 0)
			iconImg.Position = UDim2.new(0.5, 0, 0, 12)
			iconImg.BackgroundTransparency = 1
			iconImg.Image = "rbxassetid://" .. tostring(icon.id)
			iconImg.ScaleType = Enum.ScaleType.Fit
			iconImg.ZIndex = 3
			iconImg.Parent = btn
			reg(iconImg, "ImageColor3", "fg")

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, -10, 0, 26)
			nameLbl.AnchorPoint = Vector2.new(0.5, 1)
			nameLbl.Position = UDim2.new(0.5, 0, 1, -6)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = icon.name:gsub("_", " ")
			nameLbl.FontFace = m3Font
			nameLbl.TextSize = 10
			nameLbl.TextWrapped = true
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.TextYAlignment = Enum.TextYAlignment.Top
			nameLbl.ZIndex = 3
			nameLbl.Parent = btn
			reg(nameLbl, "TextColor3", "out")

			btn.MouseEnter:Connect(function()
				tween(state, "BackgroundTransparency", 0.9, 0.12)
				playFeedback("hover")
			end)
			btn.MouseLeave:Connect(function()
				tween(state, "BackgroundTransparency", 1, 0.12)
			end)
			btn.MouseButton1Click:Connect(function()
				ripple(btn, curTheme.fg, UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
				copyIcon({ root = btn, name = icon.name, nameLower = string.lower(icon.name), id = icon.id })
			end)

			table.insert(cells, {
				root = btn,
				name = icon.name,
				nameLower = string.lower(icon.name),
				id = icon.id,
			})
		end

		searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

		task.spawn(function()
			local icons, err = loadMaterialIconLibrary()
			if err or #icons == 0 then
				statusLbl.Text = err or "No icons found in Material Icons library."
				return
			end

			for i, icon in icons do
				makeIconCell(icon, i)
				if i % 80 == 0 then
					task.wait()
				end
			end

			applyFilter()
		end)
	end

end
