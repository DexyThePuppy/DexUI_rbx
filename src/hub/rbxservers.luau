--!nonstrict
-- VIP / community servers listed on rbxservers.com (same source as the FreeServer extension).
-- Server list is embedded in the game page HTML (__NEXT_DATA__); join requires RBXServers
-- captcha flow in a browser — DexUI surfaces the list and copies server page links.

local Util = require("../core/util")

local HttpService = game:GetService("HttpService")

local GAME_PAGE_URL = "https://rbxservers.com/games/"
local SERVER_PAGE_URL = "https://rbxservers.com/servers/"

export type RbxServerEntry = {
	id: string,
	name: string,
	flags: number?,
	votesPositive: number,
	votesNegative: number,
	community: boolean,
	lastUpdated: number?,
}

local function decodeJson(body: string): any?
	local ok, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if ok then
		return data
	end
	return nil
end

local function httpGetRaw(url: string): string?
	local httpGet = (game :: any).HttpGet
	if type(httpGet) == "function" then
		local ok, body = pcall(function()
			return httpGet(url)
		end)
		if ok and type(body) == "string" and #body > 256 then
			return body
		end
		local okBin, bodyBin = pcall(function()
			return httpGet(url, true)
		end)
		if okBin and type(bodyBin) == "string" and #bodyBin > 256 then
			return bodyBin
		end
	end
	local ok, res = Util.httpRequest({ Url = url, Method = "GET" })
	if not ok or not res or res.StatusCode ~= 200 or type(res.Body) ~= "string" or #res.Body < 256 then
		return nil
	end
	return res.Body
end

local function extractNextDataJson(html: string): string?
	local tag = '<script id="__NEXT_DATA__"'
	local start = string.find(html, tag, 1, true)
	if not start then
		return nil
	end
	local contentStart = string.find(html, ">", start, true)
	if not contentStart then
		return nil
	end
	local contentEnd = string.find(html, "</script>", contentStart + 1, true)
	if not contentEnd then
		return nil
	end
	return string.sub(html, contentStart + 1, contentEnd - 1)
end

local function parseServerRow(row: any, community: boolean): RbxServerEntry?
	if type(row) ~= "table" or type(row.id) ~= "string" or row.id == "" then
		return nil
	end
	local name = if type(row.name) == "string" and row.name ~= "" then row.name else row.id
	local pos, neg = 0, 0
	if type(row.votes) == "table" then
		pos = if type(row.votes.positive) == "number" then row.votes.positive else 0
		neg = if type(row.votes.negative) == "number" then row.votes.negative else 0
	end
	return {
		id = row.id,
		name = name,
		flags = if type(row.flags) == "number" then row.flags else nil,
		votesPositive = pos,
		votesNegative = neg,
		community = community,
		lastUpdated = if type(row.last_updated) == "number" then row.last_updated else nil,
	}
end

local function addRows(
	entries: { RbxServerEntry },
	seen: { [string]: boolean },
	rows: any,
	community: boolean
)
	if type(rows) ~= "table" then
		return
	end
	for _, row in rows do
		local entry = parseServerRow(row, community)
		if entry and not seen[entry.id] then
			seen[entry.id] = true
			table.insert(entries, entry)
		end
	end
end

local function sortEntries(entries: { RbxServerEntry })
	table.sort(entries, function(a, b)
		if a.community ~= b.community then
			return a.community
		end
		if a.votesPositive ~= b.votesPositive then
			return a.votesPositive > b.votesPositive
		end
		if a.votesNegative ~= b.votesNegative then
			return a.votesNegative < b.votesNegative
		end
		return a.name < b.name
	end)
end

local function fetchVipServers(placeId: number): ({ RbxServerEntry }, number?, string?)
	local html = httpGetRaw(GAME_PAGE_URL .. tostring(placeId))
	if not html then
		return {}, nil, "Could not load RBXServers (HTTP failed)."
	end

	local jsonText = extractNextDataJson(html)
	if not jsonText then
		return {}, nil, "RBXServers page did not return server data."
	end

	local data = decodeJson(jsonText)
	if type(data) ~= "table" then
		return {}, nil, "RBXServers response could not be parsed."
	end

	local pageProps = data.props
	if type(pageProps) ~= "table" then
		return {}, nil, "RBXServers page data missing."
	end

	local inner = pageProps.data
	if type(inner) ~= "table" then
		return {}, nil, "This experience is not listed on RBXServers."
	end

	if inner.blacklisted == true then
		return {}, nil, "This game is blacklisted on RBXServers."
	end

	local totalCount = if type(inner.server_count) == "number" then inner.server_count else nil
	local entries: { RbxServerEntry } = {}
	local seen: { [string]: boolean } = {}

	addRows(entries, seen, inner.official_servers, false)
	addRows(entries, seen, inner.community_servers, true)
	addRows(entries, seen, inner.servers, false)

	sortEntries(entries)

	if #entries == 0 then
		local msg = "No VIP servers listed on RBXServers for this experience."
		if totalCount and totalCount > 0 then
			msg = "RBXServers reports servers but none were included in the page snapshot."
		end
		return {}, totalCount, msg
	end

	return entries, totalCount, nil
end

local function serverPageUrl(serverId: string): string
	return SERVER_PAGE_URL .. serverId
end

return {
	fetchVipServers = fetchVipServers,
	serverPageUrl = serverPageUrl,
	GAME_PAGE_URL = GAME_PAGE_URL,
}
