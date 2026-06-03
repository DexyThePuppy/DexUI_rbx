--!nonstrict
export type MediaHit = { id: number, title: string, subtitle: string? }

export type PlayerDeps = {
	section: Frame,
	holder: Frame,
	win: Instance,
	curTheme: { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 },
	reg: (Instance, string, string) -> (),
	corner: (Instance, number) -> (),
	m3Font: Font,
	textSize: (string) -> number,
	formatMediaClock: (number) -> string,
	playFeedback: (string) -> (),
	onHeartbeat: (() -> ()) -> RBXScriptConnection,
	isPrimaryInput: (InputObject) -> boolean,
	isMoveInput: (InputObject) -> boolean,
	captureDragTrack1D: (Frame, number) -> any,
	fractionFromDragTrack: (any) -> number,
	onInputBegan: ((InputObject) -> ()) -> (),
	onInputChanged: ((InputObject) -> ()) -> (),
	onInputEnded: ((InputObject) -> ()) -> (),
}

local ICON_PLAY = "rbxassetid://6026663699"
local ICON_PAUSE = "rbxassetid://6026663719"
local ICON_PLAY_CENTER = "rbxassetid://6026663705"

local function build(deps: PlayerDeps)
	local section = deps.section
	local holder = deps.holder
	local win = deps.win
	local curTheme = deps.curTheme
	local reg = deps.reg
	local corner = deps.corner
	local m3Font = deps.m3Font
	local textSize = deps.textSize
	local formatMediaClock = deps.formatMediaClock
	local playFeedback = deps.playFeedback
	local onHeartbeat = deps.onHeartbeat
	local isPrimaryInput = deps.isPrimaryInput
	local isMoveInput = deps.isMoveInput
	local captureDragTrack1D = deps.captureDragTrack1D
	local fractionFromDragTrack = deps.fractionFromDragTrack
	local onInputBegan = deps.onInputBegan
	local onInputChanged = deps.onInputChanged
	local onInputEnded = deps.onInputEnded
	local activeSource: ("video" | "audio")? = nil

	local videoAspect = 16 / 9

	local playerShell = Instance.new("Frame")
	playerShell.Name = "PlayerShell"
	playerShell.LayoutOrder = 0
	playerShell.Size = UDim2.new(1, 0, 0, 200)
	playerShell.BackgroundColor3 = Color3.new(0, 0, 0)
	playerShell.BorderSizePixel = 0
	playerShell.ClipsDescendants = true
	playerShell.Parent = section
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
	audioPlayer.Parent = section

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

	local function playHit(hit: MediaHit, kind: string)
		stopPlayback()
		mediaUserPaused = false
		if kind == "Videos" then
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
		playFeedback("light")
	end

	return {
		stopPlayback = stopPlayback,
		playHit = playHit,
	}
end

return { build = build }
