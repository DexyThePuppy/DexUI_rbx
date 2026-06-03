--!nonstrict
-- DexUI media component. Attached onto the window's lib via the shared ctx.
return function(ctx)
		local lib = ctx.lib
	local curTheme = ctx.theme
	local reg, regDynamic = ctx.reg, ctx.regDynamic
	local tween, corner, ripple = ctx.tween, ctx.corner, ctx.ripple
	local textSize = ctx.textSize
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

	function lib:AddMediaBrowser()
		local keywordText = ""
		local searching = false
		local mediaKind = "Videos"
		local results: { MediaHit } = {}
		local pageIndex = 0
		local nextPageToken: string? = nil
		local audioPagesHandle: any = nil
		local activeSource: ("video" | "audio")? = nil
		local seekDragging = false
		local volumeDragging = false
		local playerHovering = false
		local mediaVolume = 1
		local ICON_PLAY = "rbxassetid://6026663699" -- play_arrow (Material Icons)
		local ICON_PAUSE = "rbxassetid://6026663719" -- pause (Material Icons)
		local ICON_PLAY_CENTER = "rbxassetid://6026663705" -- play_circle_filled (Material Icons)

		local holder = Instance.new("Frame")
		holder.Name = "MediaBrowser"
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.Parent = beginCardRow(nil, true)
		indexElement("Media Browser", holder)

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 10)
		layout.Parent = holder

		local videoAspect = 16 / 9

		local playerShell = Instance.new("Frame")
		playerShell.Name = "PlayerShell"
		playerShell.LayoutOrder = 1
		playerShell.Size = UDim2.new(1, 0, 0, 200)
		playerShell.BackgroundColor3 = Color3.new(0, 0, 0)
		playerShell.BorderSizePixel = 0
		playerShell.ClipsDescendants = true
		playerShell.Parent = holder
		corner(playerShell, 12)

		local playerCorner = Instance.new("UICorner")
		playerCorner.CornerRadius = UDim.new(0, 12)
		playerCorner.Parent = playerShell

		local player = Instance.new("VideoFrame")
		player.Name = "Player"
		player.Size = UDim2.fromScale(1, 1)
		player.BackgroundColor3 = Color3.new(0, 0, 0)
		player.BorderSizePixel = 0
		player.ZIndex = 1
		player.Parent = playerShell

		local playerInnerCorner = Instance.new("UICorner")
		playerInnerCorner.CornerRadius = UDim.new(0, 12)
		playerInnerCorner.Parent = player

		local clickOverlay = Instance.new("TextButton")
		clickOverlay.Name = "ClickOverlay"
		clickOverlay.Size = UDim2.fromScale(1, 1)
		clickOverlay.BackgroundTransparency = 1
		clickOverlay.Text = ""
		clickOverlay.AutoButtonColor = false
		clickOverlay.ZIndex = 2
		clickOverlay.Parent = playerShell

		local centerPause = Instance.new("Frame")
		centerPause.Name = "CenterPause"
		centerPause.Size = UDim2.fromScale(1, 1)
		centerPause.BackgroundTransparency = 1
		centerPause.Visible = false
		centerPause.Active = false
		centerPause.ZIndex = 3
		centerPause.Parent = playerShell

		local centerPauseIcon = Instance.new("ImageLabel")
		centerPauseIcon.Size = UDim2.new(0, 56, 0, 56)
		centerPauseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		centerPauseIcon.Position = UDim2.fromScale(0.5, 0.5)
		centerPauseIcon.BackgroundTransparency = 1
		centerPauseIcon.Active = false
		centerPauseIcon.Image = ICON_PLAY_CENTER
		centerPauseIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		centerPauseIcon.ImageTransparency = 0.1
		centerPauseIcon.Parent = centerPause

		local controlsBar = Instance.new("Frame")
		controlsBar.Name = "Controls"
		controlsBar.AnchorPoint = Vector2.new(0.5, 1)
		controlsBar.Position = UDim2.new(0.5, 0, 1, -10)
		controlsBar.Size = UDim2.new(1, -20, 0, 40)
		controlsBar.BackgroundColor3 = curTheme.fg
		controlsBar.BackgroundTransparency = 0.04
		controlsBar.BorderSizePixel = 0
		controlsBar.Visible = false
		controlsBar.ZIndex = 4
		controlsBar.Parent = playerShell
		corner(controlsBar, 999)

		local pillFg = curTheme.bg
		local pillTrack = Color3.fromRGB(190, 190, 195)

		local playPauseBtn = Instance.new("ImageButton")
		playPauseBtn.Name = "PlayPause"
		playPauseBtn.Size = UDim2.new(0, 20, 0, 20)
		playPauseBtn.AnchorPoint = Vector2.new(0, 0.5)
		playPauseBtn.Position = UDim2.new(0, 12, 0.5, 0)
		playPauseBtn.BackgroundTransparency = 1
		playPauseBtn.Image = ICON_PLAY
		playPauseBtn.ImageColor3 = pillFg
		playPauseBtn.ZIndex = 2
		playPauseBtn.Parent = controlsBar

		local timeLbl = Instance.new("TextLabel")
		timeLbl.Name = "Time"
		timeLbl.Size = UDim2.new(0, 96, 1, 0)
		timeLbl.Position = UDim2.new(0, 38, 0, 0)
		timeLbl.BackgroundTransparency = 1
		timeLbl.Text = "0:00 / 0:00"
		timeLbl.FontFace = m3Font
		timeLbl.TextSize = textSize("sm")
		timeLbl.TextColor3 = pillFg
		timeLbl.TextXAlignment = Enum.TextXAlignment.Left
		timeLbl.ZIndex = 2
		timeLbl.Parent = controlsBar

		local seekTrack = Instance.new("Frame")
		seekTrack.Name = "SeekTrack"
		seekTrack.Size = UDim2.new(0, 100, 0, 4)
		seekTrack.AnchorPoint = Vector2.new(0, 0.5)
		seekTrack.Position = UDim2.new(0, 138, 0.5, 0)
		seekTrack.BackgroundColor3 = pillTrack
		seekTrack.BorderSizePixel = 0
		seekTrack.ZIndex = 2
		seekTrack.Parent = controlsBar
		corner(seekTrack, 999)

		local seekFill = Instance.new("Frame")
		seekFill.Name = "Fill"
		seekFill.Size = UDim2.new(0, 0, 1, 0)
		seekFill.BackgroundColor3 = pillFg
		seekFill.BorderSizePixel = 0
		seekFill.ZIndex = 3
		seekFill.Parent = seekTrack
		corner(seekFill, 999)

		local seekKnob = Instance.new("Frame")
		seekKnob.Name = "Knob"
		seekKnob.Size = UDim2.new(0, 6, 0, 10)
		seekKnob.AnchorPoint = Vector2.new(0.5, 0.5)
		seekKnob.Position = UDim2.new(0, 0, 0.5, 0)
		seekKnob.BackgroundColor3 = pillFg
		seekKnob.BorderSizePixel = 0
		seekKnob.ZIndex = 4
		seekKnob.Parent = seekTrack
		corner(seekKnob, 999)

		local seekHit = Instance.new("TextButton")
		seekHit.Name = "SeekHit"
		seekHit.Size = UDim2.new(1, 8, 0, 22)
		seekHit.AnchorPoint = Vector2.new(0.5, 0.5)
		seekHit.Position = UDim2.new(0.5, 0, 0.5, 0)
		seekHit.BackgroundTransparency = 1
		seekHit.Text = ""
		seekHit.AutoButtonColor = false
		seekHit.ZIndex = 5
		seekHit.Parent = seekTrack

		local volTrack = Instance.new("Frame")
		volTrack.Name = "VolumeTrack"
		volTrack.Size = UDim2.new(0, 72, 0, 4)
		volTrack.AnchorPoint = Vector2.new(1, 0.5)
		volTrack.Position = UDim2.new(1, -12, 0.5, 0)
		volTrack.BackgroundColor3 = pillTrack
		volTrack.BorderSizePixel = 0
		volTrack.ZIndex = 2
		volTrack.Parent = controlsBar
		corner(volTrack, 999)

		local volFill = Instance.new("Frame")
		volFill.Name = "Fill"
		volFill.Size = UDim2.new(1, 0, 1, 0)
		volFill.BackgroundColor3 = pillFg
		volFill.BorderSizePixel = 0
		volFill.ZIndex = 3
		volFill.Parent = volTrack
		corner(volFill, 999)

		local volKnob = Instance.new("Frame")
		volKnob.Name = "Knob"
		volKnob.Size = UDim2.new(0, 6, 0, 10)
		volKnob.AnchorPoint = Vector2.new(0.5, 0.5)
		volKnob.Position = UDim2.new(1, 0, 0.5, 0)
		volKnob.BackgroundColor3 = pillFg
		volKnob.BorderSizePixel = 0
		volKnob.ZIndex = 4
		volKnob.Parent = volTrack
		corner(volKnob, 999)

		local volHit = Instance.new("TextButton")
		volHit.Name = "VolumeHit"
		volHit.Size = UDim2.new(1, 8, 0, 22)
		volHit.AnchorPoint = Vector2.new(0.5, 0.5)
		volHit.Position = UDim2.new(0.5, 0, 0.5, 0)
		volHit.BackgroundTransparency = 1
		volHit.Text = ""
		volHit.AutoButtonColor = false
		volHit.ZIndex = 5
		volHit.Parent = volTrack

		local function layoutControlsBar()
			local w = controlsBar.AbsoluteSize.X
			if w <= 0 then
				return
			end
			local padR = 12
			local volW = 72
			local seekX = 138
			local seekW = math.max(48, w - seekX - volW - padR - 10)
			seekTrack.Size = UDim2.new(0, seekW, 0, 4)
		end

		controlsBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutControlsBar)
		task.defer(layoutControlsBar)

		local function syncVideoPlayerLayout()
			local width = math.max(holder.AbsoluteSize.X, playerShell.AbsoluteSize.X)
			if width > 0 then
				local targetHeight = math.max(1, math.floor(width / videoAspect + 0.5))
				if playerShell.Size.Y.Offset ~= targetHeight then
					playerShell.Size = UDim2.new(1, 0, 0, targetHeight)
				end
			end
		end

		task.defer(syncVideoPlayerLayout)
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncVideoPlayerLayout)
		win:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncVideoPlayerLayout)

		local audioPlayer = Instance.new("Sound")
		audioPlayer.Name = "AudioPlayer"
		audioPlayer.Parent = holder

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Name = "Status"
		statusLbl.LayoutOrder = 4
		statusLbl.Size = UDim2.new(1, 0, 0, 24)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Text = "Browse Creator Store media. Player stays pinned above the catalog."
		statusLbl.FontFace = m3Font
		statusLbl.TextSize = textSize("sm")
		statusLbl.TextWrapped = true
		statusLbl.TextXAlignment = Enum.TextXAlignment.Left
		statusLbl.TextYAlignment = Enum.TextYAlignment.Top
		statusLbl.Parent = holder
		reg(statusLbl, "TextColor3", "out")

		local function setStatus(text: string, token: string?)
			statusLbl.Text = text
			if token then
				statusLbl.TextColor3 = curTheme[token]
			else
				statusLbl.TextColor3 = curTheme.out
			end
		end

		local function mediaDuration(): number
			if activeSource == "video" and player.Video ~= "" then
				return player.TimeLength or 0
			elseif activeSource == "audio" and audioPlayer.SoundId ~= "" then
				return audioPlayer.TimeLength or 0
			end
			return 0
		end

		local function mediaPosition(): number
			if activeSource == "video" then
				return player.TimePosition or 0
			elseif activeSource == "audio" then
				return audioPlayer.TimePosition or 0
			end
			return 0
		end

		local function mediaIsPlaying(): boolean
			if activeSource == "video" then
				return player.Playing
			elseif activeSource == "audio" then
				return audioPlayer.IsPlaying
			end
			return false
		end

		local function setMediaPosition(seconds: number)
			if activeSource == "video" then
				player.TimePosition = seconds
			elseif activeSource == "audio" then
				audioPlayer.TimePosition = seconds
			end
		end

		local function updateControlsVisibility()
			controlsBar.Visible = playerHovering or seekDragging or volumeDragging
		end

		local function applyMediaVolume(fraction: number)
			mediaVolume = math.clamp(fraction, 0, 1)
			audioPlayer.Volume = mediaVolume
			player.Volume = mediaVolume
			volFill.Size = UDim2.new(mediaVolume, 0, 1, 0)
			volKnob.Position = UDim2.new(mediaVolume, 0, 0.5, 0)
		end

		applyMediaVolume(1)

		local function mediaAtEnd(): boolean
			local duration = mediaDuration()
			if duration <= 0 then
				return false
			end
			return mediaPosition() >= math.max(0, duration - 0.25)
		end

		local mediaUserPaused = false

		local function updatePauseOverlay()
			local hasMedia = activeSource ~= nil
				and ((activeSource == "video" and player.Video ~= "") or (activeSource == "audio" and audioPlayer.SoundId ~= ""))
			centerPause.Visible = hasMedia and not mediaIsPlaying()
		end

		local function updatePlayPauseIcon()
			local playing = mediaIsPlaying()
			playPauseBtn.Image = if playing then ICON_PAUSE else ICON_PLAY
		end

		local function updateTimeLabel()
			local duration = mediaDuration()
			local pos = mediaPosition()
			if duration > 0 then
				timeLbl.Text = formatMediaClock(pos) .. " / " .. formatMediaClock(duration)
			else
				timeLbl.Text = "0:00 / 0:00"
			end
		end

		local function updateSeekBar()
			local duration = mediaDuration()
			if duration > 0 then
				local fraction = math.clamp(mediaPosition() / duration, 0, 1)
				seekFill.Size = UDim2.new(fraction, 0, 1, 0)
				seekKnob.Position = UDim2.new(fraction, 0, 0.5, 0)
			else
				seekFill.Size = UDim2.new(0, 0, 1, 0)
				seekKnob.Position = UDim2.new(0, 0, 0.5, 0)
			end
			updateTimeLabel()
		end

		local function togglePlayPause()
			if activeSource == "video" then
				if player.Video == "" then
					return
				end
				if player.Playing then
					player:Pause()
					mediaUserPaused = true
				else
					if mediaAtEnd() then
						player.TimePosition = 0
					end
					player:Play()
					mediaUserPaused = false
				end
			elseif activeSource == "audio" then
				if audioPlayer.SoundId == "" then
					return
				end
				if audioPlayer.IsPlaying then
					audioPlayer:Pause()
					mediaUserPaused = true
				elseif mediaAtEnd() then
					audioPlayer.TimePosition = 0
					audioPlayer:Play()
					mediaUserPaused = false
				elseif mediaUserPaused then
					audioPlayer:Resume()
					mediaUserPaused = false
				else
					audioPlayer:Play()
					mediaUserPaused = false
				end
			else
				return
			end
			updatePlayPauseIcon()
			updatePauseOverlay()
			playFeedback("light")
		end

		clickOverlay.MouseButton1Click:Connect(togglePlayPause)
		playPauseBtn.MouseButton1Click:Connect(togglePlayPause)

		local seekDragTrack: DragTrack1D? = nil
		local volDragTrack: DragTrack1D? = nil
		seekHit.InputBegan:Connect(function(input)
			if not isPrimaryInput(input) then
				return
			end
			local duration = mediaDuration()
			if duration <= 0 then
				return
			end
			seekDragging = true
			updateControlsVisibility()
			local fraction = math.clamp(mediaPosition() / duration, 0, 1)
			seekDragTrack = captureDragTrack1D(seekTrack, fraction)
			setMediaPosition(fraction * duration)
			updateSeekBar()
		end)
		onInputEnded(function(input)
			if isPrimaryInput(input) then
				seekDragging = false
				seekDragTrack = nil
				volumeDragging = false
				volDragTrack = nil
				updateControlsVisibility()
			end
		end)
		onInputChanged(function(input)
			if seekDragging and seekDragTrack and isMoveInput(input) then
				local duration = mediaDuration()
				if duration <= 0 then
					return
				end
				local fraction = fractionFromDragTrack(seekDragTrack)
				setMediaPosition(fraction * duration)
				updateSeekBar()
			elseif volumeDragging and volDragTrack and isMoveInput(input) then
				applyMediaVolume(fractionFromDragTrack(volDragTrack))
			end
		end)

		volHit.InputBegan:Connect(function(input)
			if not isPrimaryInput(input) then
				return
			end
			volumeDragging = true
			updateControlsVisibility()
			volDragTrack = captureDragTrack1D(volTrack, mediaVolume)
			applyMediaVolume(fractionFromDragTrack(volDragTrack))
		end)

		playerShell.MouseEnter:Connect(function()
			playerHovering = true
			updateControlsVisibility()
		end)
		playerShell.MouseLeave:Connect(function()
			playerHovering = false
			updateControlsVisibility()
		end)

		player.Ended:Connect(function()
			mediaUserPaused = false
			updatePlayPauseIcon()
			updatePauseOverlay()
			updateSeekBar()
		end)
		audioPlayer.Ended:Connect(function()
			mediaUserPaused = false
			updatePlayPauseIcon()
			updatePauseOverlay()
			updateSeekBar()
		end)

		onHeartbeat(function()
			if activeSource == nil then
				return
			end
			updateSeekBar()
			updatePlayPauseIcon()
			updatePauseOverlay()
		end)

		local subTabArea = Instance.new("Frame")
		subTabArea.Name = "SubTabs"
		subTabArea.LayoutOrder = 2
		subTabArea.Size = UDim2.new(1, 0, 0, 40)
		subTabArea.BackgroundTransparency = 1
		subTabArea.ClipsDescendants = true
		subTabArea.Parent = holder

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
			label.AutomaticSize = Enum.AutomaticSize.X
			label.Size = UDim2.new(0, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text = kind
			label.FontFace = m3Font
			label.TextSize = textSize("md")
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

		local searchFrame = Instance.new("Frame")
		searchFrame.LayoutOrder = 3
		searchFrame.Size = UDim2.new(1, 0, 0, 56)
		searchFrame.BorderSizePixel = 0
		searchFrame.Parent = holder
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
		searchBtn.FontFace = fontWeight(Enum.FontWeight.Medium)
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
		resultsFrame.LayoutOrder = 5
		resultsFrame.Size = UDim2.new(1, 0, 0, MEDIA_PAGE_SIZE * 52)
		resultsFrame.BackgroundTransparency = 1
		resultsFrame.Parent = holder

		local resultsLayout = Instance.new("UIListLayout")
		resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		resultsLayout.Padding = UDim.new(0, 6)
		resultsLayout.Parent = resultsFrame

		local resultBtns: { TextButton } = {}

		local function stopPlayback()
			player:Pause()
			player.Video = ""
			audioPlayer:Stop()
			audioPlayer.SoundId = ""
			activeSource = nil
			mediaUserPaused = false
			updateSeekBar()
			updatePlayPauseIcon()
			updatePauseOverlay()
		end

		local function playHit(hit: MediaHit)
			stopPlayback()
			mediaUserPaused = false
			if mediaKind == "Videos" then
				activeSource = "video"
				player.Video = "rbxassetid://" .. tostring(hit.id)
				player:Play()
			else
				activeSource = "audio"
				audioPlayer.SoundId = "rbxassetid://" .. tostring(hit.id)
				audioPlayer:Play()
			end
			updatePlayPauseIcon()
			updatePauseOverlay()
			updateSeekBar()
			local detail = if hit.subtitle then hit.title .. " · " .. hit.subtitle else hit.title
			setStatus("Playing · " .. detail, "fg")
			playFeedback("light")
		end

		for i = 1, MEDIA_PAGE_SIZE do
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
			rowTitle.FontFace = fontWeight(Enum.FontWeight.Medium)
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
				local hit = results[pageIndex * MEDIA_PAGE_SIZE + slot]
				if hit then
					playHit(hit)
				end
			end)

			if tooltip then
				tooltip.attach(row, function()
					local hit = results[pageIndex * MEDIA_PAGE_SIZE + slot]
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
		pagerRow.LayoutOrder = 6
		pagerRow.Size = UDim2.new(1, 0, 0, 36)
		pagerRow.BackgroundTransparency = 1
		pagerRow.Parent = holder

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
			local startIdx = pageIndex * MEDIA_PAGE_SIZE + 1
			for i = 1, MEDIA_PAGE_SIZE do
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

		for pageNum = 0, MEDIA_PAGE_COUNT - 1 do
			local btn = Instance.new("TextButton")
			btn.Name = "Page" .. pageNum
			btn.Size = UDim2.new(0, 28, 0, 28)
			btn.Text = tostring(pageNum)
			btn.FontFace = fontWeight(Enum.FontWeight.Medium)
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
		nextBtn.FontFace = fontWeight(Enum.FontWeight.Medium)
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
			if pageIndex < MEDIA_PAGE_COUNT - 1 and (pageIndex + 1) * MEDIA_PAGE_SIZE < #results then
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
			stopPlayback()
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

	lib.AddVideoSearch = lib.AddMediaBrowser
	lib.AddVideoPlayer = lib.AddMediaBrowser
end
