--!nonstrict
-- Persists DexUI user settings to the executor workspace via writefile/readfile.
-- Falls back gracefully when filesystem globals are unavailable (vanilla client).

local Services = require("../services")
local HttpService = Services.HttpService

local STORE_VERSION = 1
local STORE_FOLDER = "DexUI"
local STORE_FILE = STORE_FOLDER .. "/settings.json"

local function canPersist(): boolean
	return writefile ~= nil and readfile ~= nil and isfile ~= nil and makefolder ~= nil and isfolder ~= nil
end

local function deepMerge(into: { any }, from: { any }?)
	if not from then
		return into
	end
	for key, value in from do
		if type(value) == "table" and type(into[key]) == "table" then
			deepMerge(into[key], value)
		else
			into[key] = value
		end
	end
	return into
end

local function colorToTable(color: Color3): { r: number, g: number, b: number }
	return { r = color.R, g = color.G, b = color.B }
end

local function colorFromTable(t: any): Color3?
	if type(t) ~= "table" then
		return nil
	end
	if type(t.r) ~= "number" or type(t.g) ~= "number" or type(t.b) ~= "number" then
		return nil
	end
	return Color3.new(t.r, t.g, t.b)
end

local function defaultsFromConfig(config: any): { any }
	local notif = (config and config.NotificationSound) or {}
	local feedback = (config and config.FeedbackSound) or {}
	return {
		version = STORE_VERSION,
		soundsEnabled = true,
		masterVolume = 1,
		accentTint = nil,
		notificationSound = {
			assetId = notif.AssetId or 121045990444676,
			randomPitch = if notif.RandomPitch ~= nil then notif.RandomPitch else true,
			pitch = notif.Pitch or 1,
			pitchMin = notif.PitchMin or 0.92,
			pitchMax = notif.PitchMax or 1.08,
		},
		feedbackSound = {
			assetId = feedback.AssetId or 0,
		},
		notificationStyle = nil,
	}
end

local function load(config: any): { any }
	local snapshot = defaultsFromConfig(config)
	if not canPersist() or not isfile(STORE_FILE) then
		return snapshot
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(STORE_FILE))
	end)
	if not ok or type(decoded) ~= "table" then
		return snapshot
	end
	deepMerge(snapshot, decoded)
	snapshot.version = STORE_VERSION
	return snapshot
end

local function save(snapshot: { any }): boolean
	if not canPersist() then
		return false
	end
	if not isfolder(STORE_FOLDER) then
		makefolder(STORE_FOLDER)
	end
	snapshot.version = STORE_VERSION
	local ok = pcall(function()
		writefile(STORE_FILE, HttpService:JSONEncode(snapshot))
	end)
	return ok
end

return {
	canPersist = canPersist,
	load = load,
	save = save,
	defaultsFromConfig = defaultsFromConfig,
	colorToTable = colorToTable,
	colorFromTable = colorFromTable,
	STORE_FILE = STORE_FILE,
}
