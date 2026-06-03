--!nonstrict
-- DexUI switch component. Attached onto the window's lib via the shared ctx.
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
	type Palette = { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 }
	type Callback = (...any) -> ()
	type MediaHit = { id: number, title: string, subtitle: string? }

	function lib:AddSwitch(txt: string, def: boolean?, cb: Callback?, sub: string?)
        local st = def or false
		local hasSub = sub ~= nil and sub ~= ""
		local content = beginCardRow(hasSub and 54 or 48, false)
		local r = content
		indexElement(txt, r)

		local textCol = Instance.new("Frame")
		textCol.Size = UDim2.new(1, -64, 1, 0)
		textCol.BackgroundTransparency = 1
		textCol.Parent = r

		local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Text = txt
        l.FontFace = m3Font
        l.TextSize = 16
        l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = textCol
		reg(l, "TextColor3", "fg")

		if hasSub then
			l.Size = UDim2.new(1, 0, 0, 20)
			l.Position = UDim2.new(0, 0, 0, 7)
			l.TextYAlignment = Enum.TextYAlignment.Bottom

			local subLbl = Instance.new("TextLabel")
			subLbl.Size = UDim2.new(1, 0, 0, 16)
			subLbl.Position = UDim2.new(0, 0, 0, 29)
			subLbl.BackgroundTransparency = 1
			subLbl.Text = sub :: string
			subLbl.FontFace = m3Font
			subLbl.TextSize = 11
			subLbl.TextXAlignment = Enum.TextXAlignment.Left
			subLbl.TextYAlignment = Enum.TextYAlignment.Top
			subLbl.TextTruncate = Enum.TextTruncate.AtEnd
			subLbl.Parent = textCol
			reg(subLbl, "TextColor3", "out")
		else
			l.Size = UDim2.new(1, 0, 1, 0)
		end

		if tooltip and hasSub then
			tooltip.attachRowHint(textCol, txt, sub)
		end

		local trk = Instance.new("TextButton")
        trk.Size = UDim2.new(0, 52, 0, 32)
        trk.AnchorPoint = Vector2.new(1, 0.5)
        trk.Position = UDim2.new(1, 0, 0.5, 0)
        trk.Text = ""
        trk.AutoButtonColor = false
		trk.BackgroundColor3 = st and curTheme.pri or curTheme.inact
		trk.Parent = r
		corner(trk, 999)

		local thm = Instance.new("Frame")
        thm.AnchorPoint = Vector2.new(0.5, 0.5)
        thm.Size = st and UDim2.new(0, 24, 0, 24) or UDim2.new(0, 16, 0, 16)
        thm.Position = st and UDim2.new(0, 36, 0.5, 0) or UDim2.new(0, 16, 0.5, 0)
        thm.BackgroundColor3 = st and curTheme.onpri or curTheme.out
		thm.Parent = trk
		corner(thm, 999)

		regDynamic(function(theme, dur)
			tween(trk, "BackgroundColor3", st and theme.pri or theme.inact, dur)
			tween(thm, "BackgroundColor3", st and theme.onpri or theme.out, dur)
		end)

        trk.MouseButton1Click:Connect(function()
            st = not st
			playFeedback(st and "toggleOn" or "toggleOff")
			tween(trk, "BackgroundColor3", st and curTheme.pri or curTheme.inact, 0.3)
			TweenService:Create(thm, STD_TWEEN, {
                Size = st and UDim2.new(0, 24, 0, 24) or UDim2.new(0, 16, 0, 16),
                Position = st and UDim2.new(0, 36, 0.5, 0) or UDim2.new(0, 16, 0.5, 0),
				BackgroundColor3 = st and curTheme.onpri or curTheme.out,
            }):Play()
			if cb then
				cb(st)
			end
        end)
    end

end
