--!nonstrict
-- Loads scripts/index.lua from the executor workspace and resolves the current game.

local INDEX_PATHS = {
	"scripts/index.lua",
	"DexUI/scripts/index.lua",
}

local FALLBACK_INDEX = {
	{
		id = "fabrik-tycoon",
		name = "[UPD] Fabrik-Tycoon",
		thumbnail = "rbxthumb://type=Place&id=15197136141&w=420&h=420",
		placeIds = { 15197136141 },
		universeIds = {},
		images = {
			"rbxthumb://type=Place&id=15197136141&w=768&h=432",
		},
		description = "Auto farm for Fabrik-Tycoon (collect, buildings, gems, rebirth).",
		script = "games/fabrik-tycoon.lua",
	},
	{
		id = "dexui-demo",
		name = "DexUI Demo",
		thumbnail = "rbxthumb://type=Place&id=95206881&w=420&h=420",
		placeIds = {},
		universeIds = {},
		images = {
			"rbxthumb://type=Place&id=95206881&w=768&h=432",
		},
		description = "Example script shipped with DexUI.",
		script = "tools/dexui-demo.lua",
	},
}

export type GameEntry = {
	id: string,
	name: string,
	thumbnail: string,
	placeIds: { number }?,
	universeIds: { number }?,
	images: { string }?,
	description: string?,
	script: string,
}

local function canReadFiles(): boolean
	return readfile ~= nil and isfile ~= nil
end

local function readIndexSource(): string?
	if not canReadFiles() then
		return nil
	end
	for _, path in INDEX_PATHS do
		if isfile(path) then
			return readfile(path)
		end
	end
	return nil
end

local function normalizeEntry(raw: any): GameEntry?
	if type(raw) ~= "table" or type(raw.id) ~= "string" or type(raw.name) ~= "string" then
		return nil
	end
	if type(raw.script) ~= "string" or raw.script == "" then
		return nil
	end
	local thumb = raw.thumbnail
	if type(thumb) == "number" then
		thumb = "rbxassetid://" .. tostring(thumb)
	elseif type(thumb) ~= "string" or thumb == "" then
		thumb = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	end
	local images: { string } = {}
	if type(raw.images) == "table" then
		for _, img in raw.images do
			if type(img) == "number" then
				table.insert(images, "rbxassetid://" .. tostring(img))
			elseif type(img) == "string" and img ~= "" then
				table.insert(images, img)
			end
		end
	end
	if #images == 0 then
		table.insert(images, thumb)
	end
	local placeIds: { number } = {}
	if type(raw.placeIds) == "table" then
		for _, id in raw.placeIds do
			if type(id) == "number" then
				table.insert(placeIds, id)
			end
		end
	end
	local universeIds: { number } = {}
	if type(raw.universeIds) == "table" then
		for _, id in raw.universeIds do
			if type(id) == "number" then
				table.insert(universeIds, id)
			end
		end
	end
	return {
		id = raw.id,
		name = raw.name,
		thumbnail = thumb,
		placeIds = placeIds,
		universeIds = universeIds,
		images = images,
		description = if type(raw.description) == "string" then raw.description else nil,
		script = raw.script,
	}
end

local function loadFromSource(source: string): { GameEntry }
	local chunk = loadstring(source, "scripts/index.lua")
	if not chunk then
		return {}
	end
	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" then
		return {}
	end
	local entries: { GameEntry } = {}
	for _, raw in data do
		local entry = normalizeEntry(raw)
		if entry then
			table.insert(entries, entry)
		end
	end
	return entries
end

local function load(): { GameEntry }
	local source = readIndexSource()
	if source then
		local entries = loadFromSource(source)
		if #entries > 0 then
			return entries
		end
	end
	local fallback: { GameEntry } = {}
	for _, raw in FALLBACK_INDEX do
		local entry = normalizeEntry(raw)
		if entry then
			table.insert(fallback, entry)
		end
	end
	return fallback
end

local function currentPlaceId(): number
	return game.PlaceId
end

local function currentUniverseId(): number
	return game.GameId
end

local function entryMatchesCurrent(entry: GameEntry): boolean
	local placeId = currentPlaceId()
	local universeId = currentUniverseId()
	if entry.placeIds and #entry.placeIds > 0 then
		for _, id in entry.placeIds do
			if id == placeId then
				return true
			end
		end
	end
	if entry.universeIds and #entry.universeIds > 0 then
		for _, id in entry.universeIds do
			if id == universeId then
				return true
			end
		end
	end
	return false
end

local function findForCurrentGame(entries: { GameEntry }?): GameEntry?
	local list = entries or load()
	for _, entry in list do
		if entryMatchesCurrent(entry) then
			return entry
		end
	end
	return nil
end

local function getLivePlaceContext(): { placeId: number, universeId: number, name: string?, description: string? }
	local GameMetadata = require("./game-metadata")
	local ok, meta = pcall(GameMetadata.fetchCurrentGameMetadata)
	if ok and type(meta) == "table" then
		return {
			placeId = meta.placeId,
			universeId = meta.universeId,
			name = meta.name,
			description = meta.description,
		}
	end
	return {
		placeId = currentPlaceId(),
		universeId = currentUniverseId(),
		name = nil,
		description = nil,
	}
end

return {
	load = load,
	entryMatchesCurrent = entryMatchesCurrent,
	findForCurrentGame = findForCurrentGame,
	getLivePlaceContext = getLivePlaceContext,
	INDEX_PATHS = INDEX_PATHS,
}
