--!nonstrict
-- DexUI dropdown component. Attached onto the window's lib via the shared ctx.
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

	function lib:AddDropdown(txt: string, options: { string }, default: string?, cb: Callback?)
		local selected = default or options[1]
		local open = false

		local content = beginCardRow(46, false)
		local frame = content
		frame.BackgroundTransparency = 1
		indexElement(txt, frame)

		local header = Instance.new("TextButton")
		header.Size = UDim2.new(1, 0, 1, 0)
		header.BackgroundTransparency = 1
		header.Text = ""
		header.AutoButtonColor = false
		header.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -32, 0, 16)
		lbl.Position = UDim2.new(0, 0, 0, 4)
		lbl.BackgroundTransparency = 1
		lbl.Text = txt
		lbl.FontFace = m3Font
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = header
		reg(lbl, "TextColor3", "out")

		local valueLbl = Instance.new("TextLabel")
		valueLbl.Size = UDim2.new(1, -32, 0, 20)
		valueLbl.Position = UDim2.new(0, 0, 0, 22)
		valueLbl.BackgroundTransparency = 1
		valueLbl.Text = selected
		valueLbl.FontFace = m3Font
		valueLbl.TextSize = 15
		valueLbl.TextXAlignment = Enum.TextXAlignment.Left
		valueLbl.Parent = header
		reg(valueLbl, "TextColor3", "fg")

		local arrow = Instance.new("ImageLabel")
		arrow.Size = UDim2.new(0, 20, 0, 20)
		arrow.AnchorPoint = Vector2.new(1, 0.5)
		arrow.Position = UDim2.new(1, 0, 0.5, 0)
		arrow.BackgroundTransparency = 1
		arrow.Image = "rbxassetid://6031091004" -- chevron
		arrow.Parent = header
		reg(arrow, "ImageColor3", "out")

		-- Floating menu (in the popup layer) so it overlays content instead of
		-- pushing the card taller.
		local OPT_H = 36
		local POP_MAX = 200

		local catcher = Instance.new("TextButton")
		catcher.Name = "DropdownCatcher"
		catcher.Size = UDim2.new(1, 0, 1, 0)
		catcher.BackgroundTransparency = 1
		catcher.Text = ""
		catcher.AutoButtonColor = false
		catcher.Visible = false
		catcher.ZIndex = 91
		catcher.Parent = popupLayer

		local popup = Instance.new("Frame")
		popup.Name = "DropdownPopup"
		popup.BackgroundTransparency = 0
		popup.BorderSizePixel = 0
		popup.Visible = false
		popup.ZIndex = 95
		popup.ClipsDescendants = true
		popup.Parent = popupLayer
		reg(popup, "BackgroundColor3", "inact")
		corner(popup, 12)

		local popStroke = Instance.new("UIStroke")
		popStroke.Thickness = 1
		popStroke.Transparency = 0.4
		popStroke.Parent = popup
		reg(popStroke, "Color", "out")

		local popScroll = Instance.new("ScrollingFrame")
		popScroll.Size = UDim2.new(1, 0, 1, 0)
		popScroll.BackgroundTransparency = 1
		popScroll.BorderSizePixel = 0
		popScroll.ScrollBarThickness = 3
		popScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		popScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		popScroll.ZIndex = 95
		popScroll.Parent = popup

		local popPad = Instance.new("UIPadding")
		popPad.PaddingTop = UDim.new(0, 6)
		popPad.PaddingBottom = UDim.new(0, 6)
		popPad.PaddingLeft = UDim.new(0, 6)
		popPad.PaddingRight = UDim.new(0, 6)
		popPad.Parent = popScroll

		local popList = Instance.new("UIListLayout")
		popList.SortOrder = Enum.SortOrder.LayoutOrder
		popList.Padding = UDim.new(0, 2)
		popList.Parent = popScroll

		local function positionPopup()
			local lx = header.AbsolutePosition.X - popupLayer.AbsolutePosition.X
			local ly = header.AbsolutePosition.Y - popupLayer.AbsolutePosition.Y
			local h = math.min(POP_MAX, #options * (OPT_H + 2) + 12)
			local headerH = header.AbsoluteSize.Y
			local layerH = popupLayer.AbsoluteSize.Y
			local belowY = ly + headerH + 4
			-- Flip upward when there isn't enough room below (so it never clips
			-- against the window's bottom edge).
			if belowY + h > layerH and (ly - 4 - h) >= 0 then
				popup.Position = UDim2.fromOffset(lx, ly - 4 - h)
			else
				popup.Position = UDim2.fromOffset(lx, belowY)
			end
			popup.Size = UDim2.fromOffset(header.AbsoluteSize.X, h)
		end

		local function setOpen(state: boolean)
			open = state
			tween(arrow, "Rotation", open and 180 or 0, 0.3)
			catcher.Visible = state
			popup.Visible = state
			if state then
				positionPopup()
			end
		end

		onRender(function()
			if open then
				if header.AbsoluteSize.X <= 0 then
					setOpen(false)
				else
					positionPopup()
				end
			end
		end)

		catcher.MouseButton1Click:Connect(function()
			setOpen(false)
		end)

		for i, opt in ipairs(options) do
			local optBtn = Instance.new("TextButton")
			optBtn.Size = UDim2.new(1, 0, 0, OPT_H)
			optBtn.BackgroundTransparency = 1
			optBtn.Text = opt
			optBtn.FontFace = m3Font
			optBtn.TextSize = 14
			optBtn.TextXAlignment = Enum.TextXAlignment.Left
			optBtn.AutoButtonColor = false
			optBtn.LayoutOrder = i
			optBtn.ClipsDescendants = true
			optBtn.ZIndex = 96
			optBtn.Parent = popScroll
			reg(optBtn, "TextColor3", "fg")

			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 12)
			pad.Parent = optBtn
			corner(optBtn, 8)

			optBtn.MouseEnter:Connect(function()
				tween(optBtn, "BackgroundTransparency", 0.9, 0.15)
				tween(optBtn, "BackgroundColor3", curTheme.fg, 0.15)
				playFeedback("hover")
			end)
			optBtn.MouseLeave:Connect(function()
				tween(optBtn, "BackgroundTransparency", 1, 0.15)
			end)
			optBtn.MouseButton1Click:Connect(function()
				selected = opt
				valueLbl.Text = opt
				ripple(optBtn, curTheme.pri, UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
				playFeedback("selection")
				setOpen(false)
				if cb then
					cb(opt)
				end
			end)
		end

		header.MouseButton1Click:Connect(function()
			playFeedback("light")
			setOpen(not open)
		end)
	end

end
