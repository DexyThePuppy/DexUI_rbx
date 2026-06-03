--!nonstrict
-- DexUI button component. Attached onto the window's lib via the shared ctx.
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

	function lib:AddButton(txt: string, cb: Callback?)
		local content = beginCardRow(44, false)
		local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 1, 0)
        b.Text = ""
        b.AutoButtonColor = false
		b.ClipsDescendants = true
		b.Parent = content
		reg(b, "BackgroundColor3", "pri")
		corner(b, 999)
		indexElement(txt, b)

		local txl = Instance.new("TextLabel")
        txl.Size = UDim2.new(1, 0, 1, 0)
        txl.BackgroundTransparency = 1
        txl.Text = txt
		txl.FontFace = fontEmphasis
        txl.TextSize = textSize("md")
		txl.ZIndex = 2
		txl.Parent = b
		reg(txl, "TextColor3", "onpri")

		-- M3 state layer: subtle hover/press overlay tint.
		b.MouseEnter:Connect(function()
			tween(b, "BackgroundColor3", curTheme.fg, 0.2)
		end)
		b.MouseLeave:Connect(function()
			tween(b, "BackgroundColor3", curTheme.pri, 0.2)
		end)
		b.MouseEnter:Connect(function()
			playFeedback("hover")
		end)
		b.MouseButton1Down:Connect(function()
			local m = UserInputService:GetMouseLocation()
			ripple(b, curTheme.onpri, m.X, m.Y)
			playFeedback("success")
		end)
        b.MouseButton1Click:Connect(function() 
			if cb then
				cb()
			end
        end)
    end

	-- Shared title + optional subtitle stack used by switch / keybind / colorpicker.
end
