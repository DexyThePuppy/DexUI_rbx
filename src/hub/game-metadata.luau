--!nonstrict
-- Fetches metadata for the experience the client is currently in.
-- Use game.GameId (universe), not the /games/ URL place id alone — sub-places often
-- have no description on MarketplaceService Product lookups.

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

local function placeThumb(placeId: number, w: number, h: number): string
	return string.format("rbxthumb://type=Place&id=%d&w=%d&h=%d", placeId, w, h)
end

local function addImage(list: { string }, seen: { [string]: boolean }, url: string?)
	if not url or url == "" or seen[url] then
		return
	end
	seen[url] = true
	table.insert(list, url)
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

local function httpGet(url: string): any?
	local ok, res = Util.httpRequest({ Url = url, Method = "GET" })
	if not ok or not res or res.StatusCode ~= 200 or not res.Body then
		return nil
	end
	return decodeJson(res.Body)
end

local function fetchFromMarketplace(universeId: number, placeId: number): (string?, string?, string?)
	local name: string? = nil
	local description: string? = nil
	local creatorName: string? = nil

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

	return name, description, creatorName
end

local function fetchFromGamesApi(universeId: number): (string?, string?, string?, number?, number?, number?)
	local data = httpGet("https://games.roblox.com/v1/games?universeIds=" .. tostring(universeId))
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

local function fetchThumbnailUrls(universeId: number): { string }
	local urls: { string } = {}

	local multi = httpGet(
		"https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds="
			.. tostring(universeId)
			.. "&countPerUniverse=5&size=768x432&format=Png&isCircular=false"
	)
	if type(multi) == "table" and type(multi.data) == "table" then
		for _, bucket in multi.data do
			if type(bucket.thumbnails) == "table" then
				for _, thumb in bucket.thumbnails do
					if type(thumb.imageUrl) == "string" then
						table.insert(urls, thumb.imageUrl)
					end
				end
			end
		end
	end

	local icon = httpGet(
		"https://thumbnails.roblox.com/v1/games/icons?universeIds="
			.. tostring(universeId)
			.. "&size=512x512&format=Png&isCircular=false"
	)
	if type(icon) == "table" and type(icon.data) == "table" then
		for _, row in icon.data do
			if type(row.imageUrl) == "string" then
				table.insert(urls, row.imageUrl)
			end
		end
	end

	return urls
end

local function fetchCurrentGameMetadata(): GameMetadata
	local placeId = game.PlaceId
	local universeId = game.GameId

	local name, description, creator = fetchFromMarketplace(universeId, placeId)
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
	for _, url in fetchThumbnailUrls(universeId) do
		addImage(images, seen, url)
	end
	if rootPlaceId then
		addImage(images, seen, placeThumb(rootPlaceId, 768, 432))
	end
	addImage(images, seen, placeThumb(placeId, 768, 432))
	if #images == 0 then
		addImage(images, seen, placeThumb(placeId, 420, 420))
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
