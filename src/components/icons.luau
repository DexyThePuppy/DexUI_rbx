--!nonstrict
-- DexUI icons component. Attached onto the window's lib via the shared ctx.

local Config = require("../config")
local PanelSection = require("../core/panel-section")
local SL = Config.SectionLayout or Config.GameInfo or {}

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
	local tooltip = ctx.tooltip
	local textSize = ctx.textSize
	local Grid = ctx.grid
	type Palette = { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 }
	type Callback = (...any) -> ()
	type MediaHit = { id: number, title: string, subtitle: string? }

	function lib:AddIconBrowser()
		local panelDeps = {
			corner = corner,
			reg = reg,
			fontWeight = fontWeight,
			textSize = textSize,
			padding = SL.SectionPadding or 14,
			innerGap = SL.InnerGap or 8,
			cornerRadius = SL.SectionCorner or 12,
			titleGap = SL.TitleGap or 6,
		}
		local block = PanelSection.create(lib.CurrentBuildContainer, nextCardItemOrder(), panelDeps, {
			name = "IconBrowser",
			title = "Material Icons",
		})
		indexElement("Icon Browser", block.block)

		local card = block.card

		local searchFrame = Instance.new("Frame")
		searchFrame.LayoutOrder = 0
		searchFrame.Size = UDim2.new(1, 0, 0, 46)
		searchFrame.BorderSizePixel = 0
		searchFrame.Parent = card
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
		searchBox.TextSize = textSize("md")
		searchBox.TextXAlignment = Enum.TextXAlignment.Left
		searchBox.TextYAlignment = Enum.TextYAlignment.Center
		searchBox.ClearTextOnFocus = false
		searchBox.Parent = searchFrame
		reg(searchBox, "TextColor3", "fg")
		reg(searchBox, "PlaceholderColor3", "out")

		local statusLbl = Instance.new("TextLabel")
		statusLbl.LayoutOrder = 1
		statusLbl.Size = UDim2.new(1, 0, 0, 16)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Text = "Loading Material Icons…"
		statusLbl.FontFace = fontWeight(Enum.FontWeight.Medium)
		statusLbl.TextSize = textSize("sm")
		statusLbl.TextXAlignment = Enum.TextXAlignment.Left
		statusLbl.Parent = card
		reg(statusLbl, "TextColor3", "out")

		local gridHost = Instance.new("Frame")
		gridHost.LayoutOrder = 2
		gridHost.Size = UDim2.new(1, 0, 0, 0)
		gridHost.AutomaticSize = Enum.AutomaticSize.Y
		gridHost.BackgroundTransparency = 1
		gridHost.Parent = card

		local gridMount = Grid.buildScroll(gridHost, {
			corner = corner,
			reg = reg,
			fontWeight = fontWeight,
			textSize = textSize,
		}, 360)

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
			local card = gridMount.addCard(order)
			card.root.Name = icon.name
			reg(card.root, "BackgroundColor3", "inact")

			card.image.Size = UDim2.fromOffset(32, 32)
			card.image.AnchorPoint = Vector2.new(0.5, 0.5)
			card.image.Position = UDim2.new(0.5, 0, 0.5, 0)
			card.image.Image = "rbxassetid://" .. tostring(icon.id)
			card.image.ScaleType = Enum.ScaleType.Fit
			reg(card.image, "ImageColor3", "fg")

			card.title.Text = icon.name:gsub("_", " ")
			card.title.FontFace = m3Font
			card.title.TextSize = textSize("sm")
			reg(card.title, "TextColor3", "out")

			card.root.MouseEnter:Connect(function()
				tween(card.state, "BackgroundTransparency", 0.9, 0.12)
				playFeedback("hover")
			end)
			card.root.MouseLeave:Connect(function()
				tween(card.state, "BackgroundTransparency", 1, 0.12)
			end)
			card.root.MouseButton1Click:Connect(function()
				ripple(card.root, curTheme.fg, UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
				copyIcon({ root = card.root, name = icon.name, nameLower = string.lower(icon.name), id = icon.id })
			end)

			if tooltip then
				local displayName = icon.name:gsub("_", " ")
				tooltip.attach(card.root, {
					blocks = {
						{ kind = "title", text = displayName },
						{ kind = "stat", label = "Asset ID", value = tostring(icon.id) },
						{ kind = "text", text = formatMaterialIconCode(icon.name, icon.id), muted = true },
						{ kind = "text", text = "Click to copy", muted = true },
					},
					maxWidth = 280,
				}, { delay = 0.35 })
			end

			table.insert(cells, {
				root = card.root,
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
			gridMount.sync()
		end)
	end

end
