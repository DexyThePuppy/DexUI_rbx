--!nonstrict
-- DexUI keybind component. Attached onto the window's lib via the shared ctx.
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

	function lib:AddKeybind(txt: string, default: Enum.KeyCode?, cb: Callback?, sub: string?)
		local current: Enum.KeyCode = default or Enum.KeyCode.Unknown
		local listening = false
		local hasSub = sub ~= nil and sub ~= ""

		local content = beginCardRow(hasSub and 54 or 48, false)
		local r = content
		indexElement(txt, r)

		local textCol = Instance.new("Frame")
		textCol.Size = UDim2.new(1, -110, 1, 0)
		textCol.BackgroundTransparency = 1
		textCol.Parent = r
		fillLabelColumn(textCol, txt, sub)
		if tooltip and hasSub then
			tooltip.attachRowHint(textCol, txt, sub)
		end

		local chip = Instance.new("TextButton")
		chip.Size = UDim2.new(0, 96, 0, 34)
		chip.AnchorPoint = Vector2.new(1, 0.5)
		chip.Position = UDim2.new(1, 0, 0.5, 0)
		chip.Text = current ~= Enum.KeyCode.Unknown and current.Name or "None"
		chip.FontFace = fontWeight(Enum.FontWeight.Medium)
		chip.TextSize = 14
		chip.AutoButtonColor = false
		chip.BackgroundTransparency = 0
		chip.Parent = r
		reg(chip, "TextColor3", "fg")
		reg(chip, "BackgroundColor3", "bg")
		corner(chip, 999)

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Transparency = 0.5
		stroke.Parent = chip
		reg(stroke, "Color", "out")

		chip.MouseButton1Click:Connect(function()
			listening = true
			chip.Text = "..."
			playFeedback("light")
			tween(stroke, "Color", curTheme.pri, 0.2)
			tween(chip, "TextColor3", curTheme.pri, 0.2)
		end)

		onInputBegan(function(input, gpe)
			if listening then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					current = input.KeyCode
					listening = false
					chip.Text = current.Name
					playFeedback("selection")
					tween(stroke, "Color", curTheme.out, 0.2)
					tween(chip, "TextColor3", curTheme.fg, 0.2)
				end
				return
			end
			if not gpe and input.KeyCode == current and current ~= Enum.KeyCode.Unknown then
				ripple(chip, curTheme.pri)
				playFeedback("light")
				if cb then
					cb(current)
				end
			end
		end)
	end

end
