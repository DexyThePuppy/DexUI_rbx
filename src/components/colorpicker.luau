--!nonstrict
-- DexUI colorpicker component. Attached onto the window's lib via the shared ctx.
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

	function lib:AddColorPicker(txt: string, default: Color3?, cb: Callback?, sub: string?)
		local hue, sat, val = (default or Color3.fromRGB(162, 201, 255)):ToHSV()
		local open = false
		local hasSub = sub ~= nil and sub ~= ""

		local content = beginCardRow(hasSub and 54 or 48, false)
		local frame = content
		frame.BackgroundTransparency = 1
		indexElement(txt, frame)

		local header = Instance.new("TextButton")
		header.Size = UDim2.new(1, 0, 1, 0)
		header.BackgroundTransparency = 1
		header.Text = ""
		header.AutoButtonColor = false
		header.Parent = frame

		local textCol = Instance.new("Frame")
		textCol.Size = UDim2.new(1, -90, 1, 0)
		textCol.BackgroundTransparency = 1
		textCol.Parent = header
		fillLabelColumn(textCol, txt, sub)

		local arrow = Instance.new("ImageLabel")
		arrow.Size = UDim2.new(0, 20, 0, 20)
		arrow.AnchorPoint = Vector2.new(1, 0.5)
		arrow.Position = UDim2.new(1, 0, 0.5, 0)
		arrow.BackgroundTransparency = 1
		arrow.Image = "rbxassetid://6031091004" -- chevron
		arrow.Parent = header
		reg(arrow, "ImageColor3", "out")

		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 36, 0, 24)
		swatch.AnchorPoint = Vector2.new(1, 0.5)
		swatch.Position = UDim2.new(1, -28, 0.5, 0)
		swatch.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		swatch.BorderSizePixel = 0
		swatch.Parent = header
		corner(swatch, 8)

		-- Floating picker body so it overlays content instead of expanding.
		local POP_H = 168

		local catcher = Instance.new("TextButton")
		catcher.Name = "ColorCatcher"
		catcher.Size = UDim2.new(1, 0, 1, 0)
		catcher.BackgroundTransparency = 1
		catcher.Text = ""
		catcher.AutoButtonColor = false
		catcher.Visible = false
		catcher.ZIndex = 91
		catcher.Parent = popupLayer

		local popup = Instance.new("Frame")
		popup.Name = "ColorPopup"
		popup.BackgroundTransparency = 0
		popup.BorderSizePixel = 0
		popup.Visible = false
		popup.ZIndex = 95
		popup.Parent = popupLayer
		reg(popup, "BackgroundColor3", "inact")
		corner(popup, 12)

		local popStroke = Instance.new("UIStroke")
		popStroke.Thickness = 1
		popStroke.Transparency = 0.4
		popStroke.Parent = popup
		reg(popStroke, "Color", "out")

		local body = Instance.new("Frame")
		body.Size = UDim2.new(1, -24, 1, -24)
		body.Position = UDim2.new(0, 12, 0, 12)
		body.BackgroundTransparency = 1
		body.ZIndex = 96
		body.Parent = popup

		local svMap = Instance.new("ImageButton")
		svMap.Size = UDim2.new(1, 0, 0, 100)
		svMap.AutoButtonColor = false
		svMap.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svMap.BorderSizePixel = 0
		svMap.ZIndex = 96
		svMap.Parent = body
		corner(svMap, 8)

		local whiteGrad = Instance.new("UIGradient")
		whiteGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
		whiteGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		local whiteOverlay = Instance.new("Frame")
		whiteOverlay.Size = UDim2.new(1, 0, 1, 0)
		whiteOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
		whiteOverlay.BorderSizePixel = 0
		whiteOverlay.Parent = svMap
		whiteGrad.Parent = whiteOverlay
		corner(whiteOverlay, 8)

		local blackOverlay = Instance.new("Frame")
		blackOverlay.Size = UDim2.new(1, 0, 1, 0)
		blackOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
		blackOverlay.BorderSizePixel = 0
		blackOverlay.Parent = svMap
		local blackGrad = Instance.new("UIGradient")
		blackGrad.Rotation = 90
		blackGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		blackGrad.Parent = blackOverlay
		corner(blackOverlay, 8)

		local svDot = Instance.new("Frame")
		svDot.Size = UDim2.new(0, 10, 0, 10)
		svDot.AnchorPoint = Vector2.new(0.5, 0.5)
		svDot.BackgroundColor3 = Color3.new(1, 1, 1)
		svDot.BorderSizePixel = 0
		svDot.ZIndex = 5
		svDot.Parent = svMap
		corner(svDot, 999)
		local svDotStroke = Instance.new("UIStroke")
		svDotStroke.Color = Color3.new(0, 0, 0)
		svDotStroke.Thickness = 1
		svDotStroke.Parent = svDot

		local hueStrip = Instance.new("ImageButton")
		hueStrip.Size = UDim2.new(1, 0, 0, 16)
		hueStrip.Position = UDim2.new(0, 0, 0, 116)
		hueStrip.AutoButtonColor = false
		hueStrip.BorderSizePixel = 0
		hueStrip.ZIndex = 96
		hueStrip.Parent = body
		corner(hueStrip, 999)
		local hueGrad = Instance.new("UIGradient")
		hueGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		})
		hueGrad.Parent = hueStrip

		local hueDot = Instance.new("Frame")
		hueDot.Size = UDim2.new(0, 4, 1, 4)
		hueDot.AnchorPoint = Vector2.new(0.5, 0.5)
		hueDot.Position = UDim2.new(0, 0, 0.5, 0)
		hueDot.BackgroundColor3 = Color3.new(1, 1, 1)
		hueDot.BorderSizePixel = 0
		hueDot.ZIndex = 5
		hueDot.Parent = hueStrip
		corner(hueDot, 999)

		local function refresh()
			local color = Color3.fromHSV(hue, sat, val)
			swatch.BackgroundColor3 = color
			svMap.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			svDot.Position = UDim2.new(sat, 0, 1 - val, 0)
			hueDot.Position = UDim2.new(hue, 0, 0.5, 0)
			if cb then
				cb(color)
			end
		end
		refresh()

		local function positionPopup()
			local lx = header.AbsolutePosition.X - popupLayer.AbsolutePosition.X
			local ly = header.AbsolutePosition.Y - popupLayer.AbsolutePosition.Y
			local headerH = header.AbsoluteSize.Y
			local layerH = popupLayer.AbsoluteSize.Y
			local belowY = ly + headerH + 4
			if belowY + POP_H > layerH and (ly - 4 - POP_H) >= 0 then
				popup.Position = UDim2.fromOffset(lx, ly - 4 - POP_H)
			else
				popup.Position = UDim2.fromOffset(lx, belowY)
			end
			popup.Size = UDim2.fromOffset(header.AbsoluteSize.X, POP_H)
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

		header.MouseButton1Click:Connect(function()
			playFeedback("light")
			setOpen(not open)
		end)

		local dragSV, dragHue = false, false
		local svTrack: DragTrack2D? = nil
		local hueTrack: DragTrack1D? = nil

		svMap.InputBegan:Connect(function(i)
			if isPrimaryInput(i) then
				dragSV = true
				local mouse = screenMouseLocation()
				sat = math.clamp((mouse.X - svMap.AbsolutePosition.X) / math.max(1, svMap.AbsoluteSize.X), 0, 1)
				val = 1 - math.clamp((mouse.Y - svMap.AbsolutePosition.Y) / math.max(1, svMap.AbsoluteSize.Y), 0, 1)
				svTrack = captureDragTrack2D(svMap, sat, 1 - val)
				refresh()
			end
		end)
		hueStrip.InputBegan:Connect(function(i)
			if isPrimaryInput(i) then
				dragHue = true
				local mouse = screenMouseLocation()
				hue = math.clamp((mouse.X - hueStrip.AbsolutePosition.X) / math.max(1, hueStrip.AbsoluteSize.X), 0, 1)
				hueTrack = captureDragTrack1D(hueStrip, hue)
				refresh()
			end
		end)
		onInputEnded(function(i)
			if isPrimaryInput(i) then
				dragSV, dragHue = false, false
				svTrack = nil
				hueTrack = nil
			end
		end)
		onInputChanged(function(i)
			if not isMoveInput(i) then
				return
			end
			if dragSV and svTrack then
				local nx, ny = pointFromDragTrack2D(svTrack)
				sat = nx
				val = 1 - ny
				refresh()
			elseif dragHue and hueTrack then
				hue = fractionFromDragTrack(hueTrack)
				refresh()
			end
		end)
	end

end
