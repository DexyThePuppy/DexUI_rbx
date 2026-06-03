--!nonstrict
-- Fetches metadata for the experience the client is currently in.
-- ImageLabel cannot display raw https:// CDN URLs — we resolve thumbnails to
-- rbxassetid:// (from API targetId) or executor getcustomasset caches.

local Services = require("../services")
local Util = require("../core/util")

local HttpService = Services.HttpService
local MarketplaceService = game:GetService("MarketplaceService")

export type GameMetadata = {
	placeId: number,
	universeId: number,
	rootPlaceId: number?,
	name: string,
	description: string?,
	creatorName: string?,
	playing: number?,
	visits: number?,
	images: { string },
}

local CDN_CACHE_FOLDER = "DexUI/thumbnails"
local cdnAssetCache: { [string]: string } = {}

local function placeThumb(placeId: number, w: number, h: number): string
	return string.format("rbxthumb://type=Place&id=%d&w=%d&h=%d", placeId, w, h)
end

local function canCacheFiles(): boolean
	return writefile ~= nil and getcustomasset ~= nil and isfolder ~= nil and makefolder ~= nil
end

local function addImage(list: { string }, seen: { [string]: boolean }, uri: string?)
	if not uri or uri == "" or seen[uri] then
		return
	end
	seen[uri] = true
	table.insert(list, uri)
end

local function decodeJson(body: string): any?
	local ok, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if ok then
		return data
	end
	return nil
end

local function httpGetJson(url: string): any?
	local ok, res = Util.httpRequest({ Url = url, Method = "GET" })
	if not ok or not res or res.StatusCode ~= 200 or not res.Body then
		return nil
	end
	return decodeJson(res.Body)
end

local function httpGetRaw(url: string): string?
	-- Prefer binary HttpGet (executor); JSON APIs still use Util.httpRequest above.
	local httpGet = (game :: any).HttpGet
	if type(httpGet) == "function" then
		local ok, body = pcall(function()
			return httpGet(url, true)
		end)
		if ok and type(body) == "string" and #body > 128 then
			return body
		end
	end
	local ok, res = Util.httpRequest({ Url = url, Method = "GET" })
	if not ok or not res or res.StatusCode ~= 200 or type(res.Body) ~= "string" or #res.Body < 128 then
		return nil
	end
	return res.Body
end

local function hashSlug(text: string): string
	local h = 0
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 2147483647
	end
	return tostring(h)
end

-- Roblox ImageLabel rejects https://tr.rbxcdn.com/... ; cache PNG via executor filesystem.
local function cdnUrlToLoadable(cdnUrl: string): string?
	if cdnAssetCache[cdnUrl] then
		return cdnAssetCache[cdnUrl]
	end
	if not canCacheFiles() then
		return nil
	end
	local body = httpGetRaw(cdnUrl)
	if not body then
		return nil
	end
	if not isfolder("DexUI") then
		pcall(makefolder, "DexUI")
	end
	if not isfolder(CDN_CACHE_FOLDER) then
		pcall(makefolder, CDN_CACHE_FOLDER)
	end
	local path = CDN_CACHE_FOLDER .. "/" .. hashSlug(cdnUrl) .. ".png"
	local writeOk = pcall(writefile, path, body)
	if not writeOk then
		return nil
	end
	local assetOk, asset = pcall(getcustomasset, path)
	if not assetOk or type(asset) ~= "string" or asset == "" then
		return nil
	end
	cdnAssetCache[cdnUrl] = asset
	return asset
end

local function targetIdToAssetId(targetId: any, universeId: number): string?
	if type(targetId) ~= "number" or targetId <= 0 or targetId == universeId then
		return nil
	end
	-- Universe ids are small (~1e9); thumbnail content ids are much larger.
	if targetId < 1_000_000_000_000 then
		return nil
	end
	return "rbxassetid://" .. string.format("%.0f", targetId)
end

local function resolveThumbnailEntry(entry: any, universeId: number): string?
	if type(entry) ~= "table" or entry.state ~= "Completed" then
		return nil
	end
	if type(entry.imageUrl) == "string" then
		local cached = cdnUrlToLoadable(entry.imageUrl)
		if cached then
			return cached
		end
	end
	-- targetId on icons is often the universe id, not an rbxasset; multiget ids rarely render as rbxassetid in executors.
	return targetIdToAssetId(entry.targetId, universeId)
end

local function fetchFromMarketplace(universeId: number, placeId: number): (string?, string?, string?, number?)
	local name: string? = nil
	local description: string? = nil
	local creatorName: string? = nil
	local iconAssetId: number? = nil

	local okGame, gameInfo = pcall(function()
		return MarketplaceService:GetProductInfo(universeId, Enum.InfoType.Game)
	end)
	if okGame and type(gameInfo) == "table" then
		if type(gameInfo.Name) == "string" then
			name = gameInfo.Name
		end
		if type(gameInfo.Description) == "string" and gameInfo.Description ~= "" then
			description = gameInfo.Description
		end
		if type(gameInfo.Creator) == "table" and type(gameInfo.Creator.Name) == "string" then
			creatorName = gameInfo.Creator.Name
		elseif type(gameInfo.CreatorName) == "string" then
			creatorName = gameInfo.CreatorName
		end
		if type(gameInfo.IconImageAssetId) == "number" and gameInfo.IconImageAssetId > 0 then
			iconAssetId = gameInfo.IconImageAssetId
		end
	end

	if not description then
		local okPlace, placeInfo = pcall(function()
			return MarketplaceService:GetProductInfo(placeId, Enum.InfoType.Product)
		end)
		if okPlace and type(placeInfo) == "table" then
			if not name and type(placeInfo.Name) == "string" then
				name = placeInfo.Name
			end
			if type(placeInfo.Description) == "string" and placeInfo.Description ~= "" then
				description = placeInfo.Description
			end
		end
	end

	return name, description, creatorName, iconAssetId
end

local function fetchFromGamesApi(universeId: number): (string?, string?, string?, number?, number?, number?)
	local data = httpGetJson("https://games.roblox.com/v1/games?universeIds=" .. tostring(universeId))
	if type(data) ~= "table" or type(data.data) ~= "table" or #data.data == 0 then
		return nil, nil, nil, nil, nil, nil
	end
	local row = data.data[1]
	local name = if type(row.name) == "string" then row.name else nil
	local description = if type(row.description) == "string" and row.description ~= "" then row.description else nil
	local creatorName = if type(row.creator) == "table" and type(row.creator.name) == "string" then row.creator.name else nil
	local playing = if type(row.playing) == "number" then row.playing else nil
	local visits = if type(row.visits) == "number" then row.visits else nil
	local rootPlaceId = if type(row.rootPlaceId) == "number" then row.rootPlaceId else nil
	return name, description, creatorName, playing, visits, rootPlaceId
end

local function fetchLoadableThumbnailUris(universeId: number, iconAssetId: number?): { string }
	local uris: { string } = {}
	local seen: { [string]: boolean } = {}

	if iconAssetId and iconAssetId > 0 then
		addImage(uris, seen, "rbxassetid://" .. tostring(iconAssetId))
	end

	local multi = httpGetJson(
		"https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds="
			.. tostring(universeId)
			.. "&countPerUniverse=5&size=768x432&format=Png&isCircular=false"
	)
	if type(multi) == "table" and type(multi.data) == "table" then
		for _, bucket in multi.data do
			if type(bucket.thumbnails) == "table" then
				for _, thumb in bucket.thumbnails do
					addImage(uris, seen, resolveThumbnailEntry(thumb, universeId))
				end
			end
		end
	end

	local icon = httpGetJson(
		"https://thumbnails.roblox.com/v1/games/icons?universeIds="
			.. tostring(universeId)
			.. "&size=512x512&format=Png&isCircular=false"
	)
	if type(icon) == "table" and type(icon.data) == "table" then
		for _, row in icon.data do
			addImage(uris, seen, resolveThumbnailEntry(row, universeId))
		end
	end

	return uris
end

local function fetchCurrentGameMetadata(): GameMetadata
	local placeId = game.PlaceId
	local universeId = game.GameId

	local name, description, creator, iconAssetId = fetchFromMarketplace(universeId, placeId)
	local playing, visits, rootPlaceId
	local apiName, apiDesc, apiCreator, apiPlaying, apiVisits, apiRoot = fetchFromGamesApi(universeId)
	if apiName then
		name = apiName
	end
	if apiDesc then
		description = apiDesc
	end
	if apiCreator then
		creator = apiCreator
	end
	playing = apiPlaying
	visits = apiVisits
	rootPlaceId = apiRoot

	if not name or name == "" then
		name = "Current experience"
	end

	local images: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, uri in fetchLoadableThumbnailUris(universeId, iconAssetId) do
		addImage(images, seen, uri)
	end
	if rootPlaceId then
		addImage(images, seen, placeThumb(rootPlaceId, 768, 432))
	end
	addImage(images, seen, placeThumb(placeId, 420, 420))
	if #images == 0 then
		addImage(images, seen, placeThumb(placeId, 768, 432))
	end

	return {
		placeId = placeId,
		universeId = universeId,
		rootPlaceId = rootPlaceId,
		name = name,
		description = description,
		creatorName = creator,
		playing = playing,
		visits = visits,
		images = images,
	}
end

return {
	fetchCurrentGameMetadata = fetchCurrentGameMetadata,
	placeThumb = placeThumb,
}
