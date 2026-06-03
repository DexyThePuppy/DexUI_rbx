--!nonstrict
-- Voiced version of web-haptics (github.com/lochie/web-haptics). Their presets
-- model Apple's UIFeedbackGenerator as sequences of taps: each tap has a
-- duration (ms), an intensity (0-1) and an optional pre-delay (ms).
--
-- Notification toasts use a separate Roblox audio asset (configurable in Settings).

local Services = require("../services")
local Config = require("../config")
local SoundService = Services.SoundService

local FEEDBACK_BASE = "rbxasset://sounds/switch.wav" -- short broadband click, not a tone

local soundCfg = Config.NotificationSound or {}
local notificationSoundId: number = soundCfg.AssetId or 121045990444676
local notificationVolume: number = soundCfg.Volume or 0.65
local notificationRandomPitch: boolean = if soundCfg.RandomPitch ~= nil then soundCfg.RandomPitch else true
local notificationPitch: number = soundCfg.Pitch or 1
local notificationPitchMin: number = soundCfg.PitchMin or 0.92
local notificationPitchMax: number = soundCfg.PitchMax or 1.08

type Tap = { duration: number, intensity: number, delay: number? }
type FeedbackSpec = { taps: { Tap }, gap: number? }

-- Ported directly from web-haptics' defaultPatterns.
local FEEDBACK: { [string]: FeedbackSpec } = {
	-- Selection (subtle) -------------------------------------------------------
	selection = { taps = { { duration = 8, intensity = 0.3 } }, gap = 0.03 },
	hover     = { taps = { { duration = 8, intensity = 0.18 } }, gap = 0.05 },
	tick      = { taps = { { duration = 8, intensity = 0.22 } }, gap = 0.045 },
	-- Impact -------------------------------------------------------------------
	light     = { taps = { { duration = 15, intensity = 0.4 } } },
	medium    = { taps = { { duration = 25, intensity = 0.7 } } },
	heavy     = { taps = { { duration = 35, intensity = 1.0 } } },
	soft      = { taps = { { duration = 40, intensity = 0.5 } } },
	rigid     = { taps = { { duration = 10, intensity = 1.0 } } },
	toggleOn  = { taps = { { duration = 25, intensity = 0.7 } } }, -- medium impact
	toggleOff = { taps = { { duration = 40, intensity = 0.5 } } }, -- soft impact
	-- Notification (multi-tap) -------------------------------------------------
	success   = { taps = { { duration = 30, intensity = 0.5 }, { delay = 60, duration = 40, intensity = 1.0 } } },
	warning   = { taps = { { duration = 40, intensity = 0.8 }, { delay = 100, duration = 40, intensity = 0.6 } } },
	error     = { taps = {
		{ duration = 40, intensity = 0.7 },
		{ delay = 40, duration = 40, intensity = 0.7 },
		{ delay = 40, duration = 40, intensity = 0.9 },
		{ delay = 40, duration = 50, intensity = 0.6 },
	} },
}

local soundsEnabled = true
local masterVolume = 1
local lastPlayed: { [string]: number } = {}

-- Shape a single click purely by intensity, mirroring web-haptics' playClick:
-- louder + slightly brighter as the tap gets harder, with a touch of random
-- jitter so repeats don't sound robotic. Pitch stays near 1.0 (the sample is
-- already a low, percussive click) so nothing turns into a squeaky beep.
local function playTap(intensity: number)
	local sound = Instance.new("Sound")
	sound.SoundId = FEEDBACK_BASE
	sound.Volume = math.clamp(intensity * 0.45 * masterVolume, 0, 1)
	local brightness = 0.82 + intensity * 0.26 -- 0.82 (soft) .. 1.08 (hard)
	sound.PlaybackSpeed = brightness * (1 + (math.random() - 0.5) * 0.08)
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(2, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Slider feedback: same soft click, but the pitch rides the value's position in
-- its range (0 = low, 1 = high) so scrubbing sounds like a glide. Throttled and
-- de-duped so holding still / tiny jitters don't retrigger.
local SLIDER_PITCH_LOW = 0.72
local SLIDER_PITCH_HIGH = 1.55
local lastSliderPct = -1
local function playSliderTick(pct: number)
	if not soundsEnabled then
		return
	end
	pct = math.clamp(pct, 0, 1)
	local now = os.clock()
	if lastPlayed.tick and (now - lastPlayed.tick) < 0.035 then
		return
	end
	if math.abs(pct - lastSliderPct) < 0.004 then
		return -- value didn't really move
	end
	lastPlayed.tick = now
	lastSliderPct = pct

	local sound = Instance.new("Sound")
	sound.SoundId = FEEDBACK_BASE
	sound.Volume = math.clamp(0.16 * masterVolume, 0, 1)
	sound.PlaybackSpeed = SLIDER_PITCH_LOW + pct * (SLIDER_PITCH_HIGH - SLIDER_PITCH_LOW)
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(2, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

local function playFeedback(name: string)
	if not soundsEnabled then
		return
	end
	local spec = FEEDBACK[name]
	if not spec then
		return
	end
	local now = os.clock()
	local gap = spec.gap or 0.02
	if lastPlayed[name] and (now - lastPlayed[name]) < gap then
		return -- throttle rapid repeats (drags, hover spam)
	end
	lastPlayed[name] = now

	-- Walk the tap sequence, advancing the clock by each pre-delay + duration so
	-- multi-tap notifications keep their intended rhythm (timbre is intensity-only).
	local clock = 0
	for _, tap in spec.taps do
		clock += (tap.delay or 0) / 1000
		local intensity = tap.intensity
		if clock <= 0 then
			playTap(intensity)
		else
			task.delay(clock, function()
				if soundsEnabled then
					playTap(intensity)
				end
			end)
		end
		clock += tap.duration / 1000
	end
end

local function setSoundsEnabled(enabled: boolean)
	soundsEnabled = enabled and true or false
end

local function isSoundsEnabled(): boolean
	return soundsEnabled
end

local function setMasterVolume(scale: number)
	masterVolume = math.clamp(scale, 0, 1)
end

local function getMasterVolume(): number
	return masterVolume
end

local function normalizeAssetId(raw: string | number): number?
	if typeof(raw) == "number" then
		return if raw > 0 then math.floor(raw) else nil
	end
	local digits = string.match(tostring(raw), "(%d+)")
	local id = digits and tonumber(digits)
	if id and id > 0 then
		return id
	end
	return nil
end

local function resolveNotificationPlaybackSpeed(): number
	if notificationRandomPitch then
		local lo = math.min(notificationPitchMin, notificationPitchMax)
		local hi = math.max(notificationPitchMin, notificationPitchMax)
		return lo + math.random() * (hi - lo)
	end
	return math.clamp(notificationPitch, 0.1, 3)
end

local function spawnSound(soundId: string, volume: number, playbackSpeed: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = math.clamp(volume, 0, 1)
	sound.PlaybackSpeed = playbackSpeed
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(8, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

local function playNotificationSound()
	if not soundsEnabled then
		return
	end
	if not notificationSoundId or notificationSoundId <= 0 then
		return
	end
	spawnSound(
		"rbxassetid://" .. tostring(notificationSoundId),
		notificationVolume * masterVolume,
		resolveNotificationPlaybackSpeed()
	)
end

local function previewNotificationSound()
	if not notificationSoundId or notificationSoundId <= 0 then
		return
	end
	spawnSound(
		"rbxassetid://" .. tostring(notificationSoundId),
		notificationVolume * masterVolume,
		resolveNotificationPlaybackSpeed()
	)
end

local function getNotificationSoundAssetId(): number
	return notificationSoundId
end

local function setNotificationSoundAssetId(id: number)
	local normalized = normalizeAssetId(id)
	if normalized then
		notificationSoundId = normalized
	end
end

local function isNotificationRandomPitch(): boolean
	return notificationRandomPitch
end

local function setNotificationRandomPitch(enabled: boolean)
	notificationRandomPitch = enabled and true or false
end

local function getNotificationPitch(): number
	return notificationPitch
end

local function setNotificationPitch(pitch: number)
	notificationPitch = math.clamp(pitch, 0.1, 3)
end

local function getNotificationPitchRange(): (number, number)
	return notificationPitchMin, notificationPitchMax
end

local function setNotificationPitchRange(minPitch: number, maxPitch: number)
	notificationPitchMin = math.clamp(minPitch, 0.1, 3)
	notificationPitchMax = math.clamp(maxPitch, 0.1, 3)
end

return {
	playFeedback = playFeedback,
	playSliderTick = playSliderTick,
	playNotificationSound = playNotificationSound,
	previewNotificationSound = previewNotificationSound,
	setSoundsEnabled = setSoundsEnabled,
	isSoundsEnabled = isSoundsEnabled,
	setMasterVolume = setMasterVolume,
	getMasterVolume = getMasterVolume,
	normalizeAssetId = normalizeAssetId,
	getNotificationSoundAssetId = getNotificationSoundAssetId,
	setNotificationSoundAssetId = setNotificationSoundAssetId,
	isNotificationRandomPitch = isNotificationRandomPitch,
	setNotificationRandomPitch = setNotificationRandomPitch,
	getNotificationPitch = getNotificationPitch,
	setNotificationPitch = setNotificationPitch,
	getNotificationPitchRange = getNotificationPitchRange,
	setNotificationPitchRange = setNotificationPitchRange,
}
