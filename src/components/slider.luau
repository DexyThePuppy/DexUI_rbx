--!nonstrict
-- DexUI slider component. Attached onto the window's lib via the shared ctx.
return function(ctx)
	local textSize = ctx.textSize
		local lib = ctx.lib
	local curTheme = ctx.theme
	local reg, regDynamic = ctx.reg, ctx.regDynamic
	local tween, corner, ripple = ctx.tween, ctx.corner, ctx.ripple
	local fontEmphasis, m3Font = ctx.fontEmphasis, ctx.m3Font
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

	function lib:AddSlider(txt: string, m: number, mx: number, df: number?, cb: Callback?)
        local v = math.clamp(df or m, m, mx)
        local drag = false
		local dragTrack: DragTrack1D? = nil

		local content = beginCardRow(56, false)
		local r = content
		indexElement(txt, r)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.6, 0, 0, 20)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = txt
		nameLbl.FontFace = m3Font
		nameLbl.TextSize = textSize("md")
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Parent = r
		reg(nameLbl, "TextColor3", "out")

		local vl = Instance.new("TextLabel")
		vl.Size = UDim2.new(0.4, 0, 0, 20)
		vl.Position = UDim2.new(0.6, 0, 0, 0)
        vl.BackgroundTransparency = 1
        vl.Text = string.format("%.2f", v)
		vl.FontFace = fontEmphasis
        vl.TextSize = textSize("md")
		vl.TextXAlignment = Enum.TextXAlignment.Right
		vl.Parent = r
		reg(vl, "TextColor3", "fg")

		local hb = Instance.new("TextButton")
        hb.Size = UDim2.new(1, 0, 0, 34)
        hb.Position = UDim2.new(0, 0, 0, 22)
        hb.BackgroundTransparency = 1
        hb.Text = ""
		hb.Parent = r

		local act = Instance.new("CanvasGroup")
        act.AnchorPoint = Vector2.new(0, 0.5)
        act.Position = UDim2.new(0, 0, 0.5, 0)
        act.BorderSizePixel = 0
		act.Parent = hb
		corner(act, 8)
		reg(act, "BackgroundColor3", "pri")

		local inact = Instance.new("CanvasGroup")
        inact.AnchorPoint = Vector2.new(1, 0.5)
        inact.Position = UDim2.new(1, 0, 0.5, 0)
        inact.BorderSizePixel = 0
		inact.Parent = hb
		corner(inact, 8)
		-- Darker than the card surface so the unfilled track is actually visible.
		reg(inact, "BackgroundColor3", "bg")

		local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 4, 0, 4)
        dot.AnchorPoint = Vector2.new(1, 0.5)
        dot.Position = UDim2.new(1, -6, 0.5, 0)
		dot.Parent = inact
		corner(dot, 999)
		reg(dot, "BackgroundColor3", "pri")

		local thm = Instance.new("Frame")
        thm.Size = UDim2.new(0, 4, 0, 28)
        thm.AnchorPoint = Vector2.new(0.5, 0.5)
		thm.Parent = hb
		corner(thm, 2)
		reg(thm, "BackgroundColor3", "pri")

		local gap = 6
		local function layoutFromPercent(pc: number)
			local tx = hb.AbsoluteSize.X * pc
			act.Size = UDim2.new(0, math.max(0, tx - gap), 0, 16)
			inact.Size = UDim2.new(0, math.max(0, hb.AbsoluteSize.X - tx - gap), 0, 16)
			thm.Position = UDim2.new(0, tx, 0.5, 0)
		end

		local function applyFraction(pc: number)
            v = m + ((mx - m) * pc)
            vl.Text = string.format("%.2f", v)
			layoutFromPercent(pc)
			playSliderTick(pc)
			if cb then
				cb(v)
			end
		end

		local function updFromTrack()
			if dragTrack then
				applyFraction(fractionFromDragTrack(dragTrack))
			end
		end

		local function refresh()
			layoutFromPercent((v - m) / (mx - m))
		end
		task.defer(refresh)
		hb:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)

        hb.InputBegan:Connect(function(i) 
			if isPrimaryInput(i) then
				drag = true
				dragTrack = captureDragTrack1D(hb, (v - m) / (mx - m))
				updFromTrack()
            end 
        end)
		onInputChanged(function(i)
			if drag and isMoveInput(i) then
                updFromTrack()
            end 
        end)
		onInputEnded(function(i)
			if isPrimaryInput(i) then
                drag = false
				dragTrack = nil
            end 
        end)
    end

end
