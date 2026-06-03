--!nonstrict
-- Fetches metadata for the experience the client is currently in.
-- ImageLabel cannot display raw https:// CDN URLs — we resolve thumbnails to
-- rbxassetid:// (from API targetId) or executor getcustomasset caches.

local Services = require("../services")
local Util = require("../core/util")

local HttpService = Services.HttpService
local MarketplaceService = game:GetService("MarketplaceService")
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

export type GameMetadata = {
	placeId: number,
	universeId: number,
	rootPlaceId: number?,
	name: string,
	description: string?,
	creatorName: string?,
	creatorId: number?,
	creatorType: string?,
	creatorVerified: boolean?,
	playing: number?,
	visits: number?,
	maxPlayers: number?,
	favoritedCount: number?,
	upVotes: number?,
	downVotes: number?,
	genre: string?,
	created: string?,
	updated: string?,
	badges: { GameBadgeEntry },
	badgeCount: number?,
	badgeCountAtLeast: boolean?,
	badgesClaimed: number?,
	groupMemberCount: number?,
	copyingAllowed: boolean?,
	createVipServersAllowed: boolean?,
	universeAvatarType: string?,
	canonicalPath: string?,
	placeVersion: number?,
	jobId: string?,
	serverLabel: string?,
	images: { string },
	privateServersEnabled: boolean?,
}

export type GameBadgeEntry = {
	id: number,
	name: string,
	displayName: string?,
	description: string?,
	iconImageId: number,
	iconUri: string?,
	claimed: boolean,
}

export type PublicServerEntry = {
	id: string,
	playing: number,
	maxPlayers: number,
	ping: number?,
	fps: number?,
}

local CDN_CACHE_FOLDER = "DexUI/thumbnails"
local cdnAssetCache: { [string]: string } = {}

local function placeThumb(placeId: number, w: number, h: number): string
	return string.format("rbxthumb://type=GameThumbnail&id=%d&w=%d&h=%d", placeId, w, h)
end

local function normalizeRbxThumbUri(uri: string): string
	local id = string.match(uri, "id=(%d+)")
	if not id then
		return uri
	end
	local w, h = string.match(uri, "w=(%d+)&h=(%d+)")
	w = w or "420"
	h = h or "420"
	if string.find(uri, "type=Place", 1, true) or string.find(uri, "type=GameThumbnail", 1, true) then
		return string.format("rbxthumb://type=GameThumbnail&id=%s&w=%s&h=%s", id, w, h)
	end
	if string.find(uri, "type=BadgeAsset", 1, true) or string.find(uri, "type=BadgeIcon", 1, true) then
		return string.format("rbxthumb://type=BadgeIcon&id=%s&w=150&h=150", id)
	end
	if string.find(uri, "type=GameIcon", 1, true) then
		return string.format("rbxthumb://type=GameIcon&id=%s&w=%s&h=%s", id, w, h)
	end
	return uri
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

local function resolveLoadableUri(uri: string?): string?
	if not uri or uri == "" then
		return nil
	end
	if string.find(uri, "rbxasset://", 1, true) then
		return uri
	end
	if string.find(uri, "https://", 1, true) or string.find(uri, "http://", 1, true) then
		return cdnUrlToLoadable(uri)
	end
	if string.find(uri, "rbxassetid://", 1, true) then
		return uri
	end
	if string.find(uri, "rbxthumb://", 1, true) then
		return normalizeRbxThumbUri(uri)
	end
	return uri
end

local function addResolvedImage(list: { string }, seen: { [string]: boolean }, uri: string?)
	local resolved = resolveLoadableUri(uri)
	if resolved then
		addImage(list, seen, resolved)
	end
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
	-- Prefer game:HttpGet (executor); Volt rejects HttpGet(url, true).
	local httpGet = (game :: any).HttpGet
	if type(httpGet) == "function" then
		local ok, body = pcall(function()
			return httpGet(url)
		end)
		if ok and type(body) == "string" and #body > 128 then
			return body
		end
		local okBin, bodyBin = pcall(function()
			return httpGet(url, true)
		end)
		if okBin and type(bodyBin) == "string" and #bodyBin > 128 then
			return bodyBin
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

local function fetchGamesApiRow(universeId: number): any?
	local data = httpGetJson("https://games.roblox.com/v1/games?universeIds=" .. tostring(universeId))
	if type(data) ~= "table" or type(data.data) ~= "table" or #data.data == 0 then
		return nil
	end
	return data.data[1]
end

local function formatGenre(row: any): string?
	if type(row) ~= "table" then
		return nil
	end
	local parts: { string } = {}
	if type(row.genre_l1) == "string" and row.genre_l1 ~= "" then
		local g1 = row.genre_l1
		table.insert(parts, string.upper(g1:sub(1, 1)) .. g1:sub(2))
	end
	if type(row.genre_l2) == "string" and row.genre_l2 ~= "" then
		table.insert(parts, row.genre_l2)
	elseif type(row.genre) == "string" and row.genre ~= "" and row.genre ~= "All" then
		table.insert(parts, row.genre)
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, " · ")
end

local function fetchVotes(universeId: number): (number?, number?)
	local data = httpGetJson("https://games.roblox.com/v1/games/votes?universeIds=" .. tostring(universeId))
	if type(data) ~= "table" or type(data.data) ~= "table" or #data.data == 0 then
		return nil, nil
	end
	local row = data.data[1]
	return if type(row.upVotes) == "number" then row.upVotes else nil,
		if type(row.downVotes) == "number" then row.downVotes else nil
end

local function fetchGroupMemberCount(groupId: number): number?
	local data = httpGetJson("https://groups.roblox.com/v1/groups/" .. tostring(groupId))
	if type(data) == "table" and type(data.memberCount) == "number" then
		return data.memberCount
	end
	return nil
end

local MAX_BADGE_PAGES = 5

local function fetchBadgeIconUri(badgeId: number): string?
	local data = httpGetJson(
		"https://thumbnails.roblox.com/v1/badges/icons?badgeIds="
			.. tostring(badgeId)
			.. "&size=150x150&format=Png&isCircular=false"
	)
	if type(data) ~= "table" or type(data.data) ~= "table" or #data.data == 0 then
		return string.format("rbxthumb://type=BadgeIcon&id=%d&w=150&h=150", badgeId)
	end
	local row = data.data[1]
	if type(row) == "table" and type(row.imageUrl) == "string" then
		local cached = cdnUrlToLoadable(row.imageUrl)
		if cached then
			return cached
		end
	end
	return string.format("rbxthumb://type=BadgeIcon&id=%d&w=150&h=150", badgeId)
end

local function userHasBadge(userId: number, badgeId: number): boolean
	local ok, has = pcall(function()
		return BadgeService:UserHasBadgeAsync(userId, badgeId)
	end)
	return ok and has == true
end

local function fetchUniverseBadges(universeId: number, userId: number?): ({ GameBadgeEntry }, boolean)
	local raw: { GameBadgeEntry } = {}
	local cursor: string? = nil
	local atLeast = false

	for page = 1, MAX_BADGE_PAGES do
		local url = string.format(
			"https://badges.roblox.com/v1/universes/%d/badges?limit=100&sortOrder=Asc",
			universeId
		)
		if cursor then
			url ..= "&cursor=" .. HttpService:UrlEncode(cursor)
		end

		local data = httpGetJson(url)
		if type(data) ~= "table" or type(data.data) ~= "table" then
			break
		end

		for _, row in data.data do
			if type(row) == "table" and type(row.id) == "number" then
				local iconId = if type(row.displayIconImageId) == "number" then row.displayIconImageId
					elseif type(row.iconImageId) == "number" then row.iconImageId
					else 0
				table.insert(raw, {
					id = row.id,
					name = if type(row.displayName) == "string" and row.displayName ~= "" then row.displayName
						elseif type(row.name) == "string" then row.name
						else "Badge",
					displayName = if type(row.displayName) == "string" then row.displayName else nil,
					description = if type(row.displayDescription) == "string" then row.displayDescription
						elseif type(row.description) == "string" then row.description
						else nil,
					iconImageId = iconId,
					iconUri = fetchBadgeIconUri(row.id),
					claimed = false,
				})
			end
		end

		cursor = if type(data.nextPageCursor) == "string" and data.nextPageCursor ~= "" then data.nextPageCursor else nil
		if not cursor then
			break
		end
		if page == MAX_BADGE_PAGES then
			atLeast = true
		end
	end

	if userId then
		for i, badge in raw do
			raw[i] = {
				id = badge.id,
				name = badge.name,
				displayName = badge.displayName,
				description = badge.description,
				iconImageId = badge.iconImageId,
				iconUri = badge.iconUri,
				claimed = userHasBadge(userId, badge.id),
			}
			if i % 8 == 0 then
				task.wait()
			end
		end
	end

	return raw, atLeast
end

local function fetchMediaAssetIds(universeId: number): { number }
	local data = httpGetJson("https://games.roblox.com/v2/games/" .. tostring(universeId) .. "/media?limit=10")
	local ids: { number } = {}
	if type(data) ~= "table" or type(data.data) ~= "table" then
		return ids
	end
	for _, row in data.data do
		if type(row) == "table" and type(row.imageId) == "number" and row.imageId > 0 then
			table.insert(ids, row.imageId)
		end
	end
	return ids
end

local function readSessionInfo(): (number?, string?, string?)
	local placeVersion: number? = nil
	pcall(function()
		placeVersion = game.PlaceVersion
	end)
	local jobId = if type(game.JobId) == "string" then game.JobId else nil
	local vipId = ""
	pcall(function()
		vipId = game.PrivateServerId
	end)
	local serverLabel = if type(vipId) == "string" and vipId ~= "" then "VIP session" else "Public session"
	return placeVersion, jobId, serverLabel
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

local function fetchPrivateServersEnabled(universeId: number): boolean?
	local data = httpGetJson(
		"https://games.roblox.com/v1/private-servers/enabled-in-universe/" .. tostring(universeId)
	)
	if type(data) == "table" and type(data.privateServersEnabled) == "boolean" then
		return data.privateServersEnabled
	end
	return nil
end

local MAX_PUBLIC_SERVER_PAGES = 6
local PUBLIC_SERVER_PAGE_LIMIT = 100

local function fetchPublicServers(placeId: number): ({ PublicServerEntry }, string?)
	local entries: { PublicServerEntry } = {}
	local cursor: string? = nil

	for _ = 1, MAX_PUBLIC_SERVER_PAGES do
		local url = string.format(
			"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=false&limit=%d",
			placeId,
			PUBLIC_SERVER_PAGE_LIMIT
		)
		if cursor then
			url ..= "&cursor=" .. HttpService:UrlEncode(cursor)
		end

		local data = httpGetJson(url)
		if type(data) ~= "table" then
			if #entries == 0 then
				return {}, "Could not load public servers (HTTP failed)."
			end
			break
		end

		if type(data.errors) == "table" and #data.errors > 0 and #entries == 0 then
			local msg = if type(data.errors[1].message) == "string" then data.errors[1].message else "Public servers unavailable."
			return {}, msg
		end

		if type(data.data) == "table" then
			for _, row in data.data do
				if type(row) == "table" and type(row.id) == "string" and row.id ~= "" then
					table.insert(entries, {
						id = row.id,
						playing = if type(row.playing) == "number" then row.playing else 0,
						maxPlayers = if type(row.maxPlayers) == "number" then row.maxPlayers else 0,
						ping = if type(row.ping) == "number" then row.ping else nil,
						fps = if type(row.fps) == "number" then row.fps else nil,
					})
				end
			end
		end

		cursor = if type(data.nextPageCursor) == "string" and data.nextPageCursor ~= "" then data.nextPageCursor else nil
		if not cursor then
			break
		end
	end

	table.sort(entries, function(a, b)
		if a.playing ~= b.playing then
			return a.playing < b.playing
		end
		if (a.ping or 9999) ~= (b.ping or 9999) then
			return (a.ping or 9999) < (b.ping or 9999)
		end
		return a.id < b.id
	end)

	return entries, nil
end

local function fetchCurrentGameMetadata(): GameMetadata
	local placeId = game.PlaceId
	local universeId = game.GameId

	local name, description, creator, iconAssetId = fetchFromMarketplace(universeId, placeId)
	local row = fetchGamesApiRow(universeId)

	local playing: number? = nil
	local visits: number? = nil
	local rootPlaceId: number? = nil
	local maxPlayers: number? = nil
	local favoritedCount: number? = nil
	local copyingAllowed: boolean? = nil
	local createVipServersAllowed: boolean? = nil
	local universeAvatarType: string? = nil
	local canonicalPath: string? = nil
	local created: string? = nil
	local updated: string? = nil
	local genre: string? = nil
	local creatorId: number? = nil
	local creatorType: string? = nil
	local creatorVerified: boolean? = nil

	if type(row) == "table" then
		if type(row.name) == "string" then
			name = row.name
		end
		if type(row.description) == "string" and row.description ~= "" then
			description = row.description
		end
		if type(row.creator) == "table" then
			if type(row.creator.name) == "string" then
				creator = row.creator.name
			end
			if type(row.creator.id) == "number" then
				creatorId = row.creator.id
			end
			if type(row.creator.type) == "string" then
				creatorType = row.creator.type
			end
			if type(row.creator.hasVerifiedBadge) == "boolean" then
				creatorVerified = row.creator.hasVerifiedBadge
			end
		end
		playing = if type(row.playing) == "number" then row.playing else nil
		visits = if type(row.visits) == "number" then row.visits else nil
		rootPlaceId = if type(row.rootPlaceId) == "number" then row.rootPlaceId else nil
		maxPlayers = if type(row.maxPlayers) == "number" then row.maxPlayers else nil
		favoritedCount = if type(row.favoritedCount) == "number" then row.favoritedCount else nil
		copyingAllowed = if type(row.copyingAllowed) == "boolean" then row.copyingAllowed else nil
		createVipServersAllowed = if type(row.createVipServersAllowed) == "boolean" then row.createVipServersAllowed else nil
		universeAvatarType = if type(row.universeAvatarType) == "string" then row.universeAvatarType else nil
		canonicalPath = if type(row.canonicalUrlPath) == "string" then row.canonicalUrlPath else nil
		created = if type(row.created) == "string" then row.created else nil
		updated = if type(row.updated) == "string" then row.updated else nil
		genre = formatGenre(row)
	end

	if not name or name == "" then
		name = "Current experience"
	end

	local upVotes, downVotes = fetchVotes(universeId)
	local userId = if Players.LocalPlayer then Players.LocalPlayer.UserId else nil
	local badges, badgeAtLeast = fetchUniverseBadges(universeId, userId)
	local badgeCount = #badges
	local badgesClaimed = 0
	for _, badge in badges do
		if badge.claimed then
			badgesClaimed += 1
		end
	end
	local groupMemberCount: number? = nil
	if creatorType == "Group" and creatorId then
		groupMemberCount = fetchGroupMemberCount(creatorId)
	end

	local images: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, uri in fetchLoadableThumbnailUris(universeId, iconAssetId) do
		addResolvedImage(images, seen, uri)
	end
	for _, assetId in fetchMediaAssetIds(universeId) do
		addResolvedImage(images, seen, "rbxassetid://" .. string.format("%.0f", assetId))
	end
	if rootPlaceId then
		addResolvedImage(images, seen, placeThumb(rootPlaceId, 768, 432))
	end
	addResolvedImage(images, seen, placeThumb(placeId, 420, 420))
	if #images == 0 then
		addResolvedImage(images, seen, placeThumb(placeId, 768, 432))
	end

	local placeVersion, jobId, serverLabel = readSessionInfo()
	local vipEnabled = fetchPrivateServersEnabled(universeId)

	return {
		placeId = placeId,
		universeId = universeId,
		rootPlaceId = rootPlaceId,
		name = name,
		description = description,
		creatorName = creator,
		creatorId = creatorId,
		creatorType = creatorType,
		creatorVerified = creatorVerified,
		playing = playing,
		visits = visits,
		maxPlayers = maxPlayers,
		favoritedCount = favoritedCount,
		upVotes = upVotes,
		downVotes = downVotes,
		genre = genre,
		created = created,
		updated = updated,
		badges = badges,
		badgeCount = badgeCount,
		badgeCountAtLeast = badgeAtLeast,
		badgesClaimed = badgesClaimed,
		groupMemberCount = groupMemberCount,
		copyingAllowed = copyingAllowed,
		createVipServersAllowed = createVipServersAllowed,
		universeAvatarType = universeAvatarType,
		canonicalPath = canonicalPath,
		placeVersion = placeVersion,
		jobId = jobId,
		serverLabel = serverLabel,
		images = images,
		privateServersEnabled = if vipEnabled ~= nil then vipEnabled else createVipServersAllowed,
	}
end

return {
	fetchCurrentGameMetadata = fetchCurrentGameMetadata,
	fetchPublicServers = fetchPublicServers,
	fetchPrivateServersEnabled = fetchPrivateServersEnabled,
	resolveLoadableUri = resolveLoadableUri,
	placeThumb = placeThumb,
}
