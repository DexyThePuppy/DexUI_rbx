--!nonstrict
-- Fetches and executes a remote tool script (GitHub release URL).

local Util = require("../core/util")

local function httpGetBody(url: string): (boolean, string?)
	local httpGet = (game :: any).HttpGet
	if type(httpGet) == "function" then
		local ok, body = pcall(function()
			return httpGet(url)
		end)
		if ok and type(body) == "string" and #body > 32 then
			return true, body
		end
	end
	local ok, res = Util.httpRequest({ Url = url, Method = "GET" })
	if ok and res and res.StatusCode == 200 and type(res.Body) == "string" and #res.Body > 32 then
		return true, res.Body
	end
	return false, nil
end

return function(entry: { url: string, name: string? }): (boolean, string?)
	if type(entry.url) ~= "string" or entry.url == "" then
		return false, "Invalid tool URL"
	end
	local fetched, source = httpGetBody(entry.url)
	if not fetched or not source then
		return false, "Could not download tool (HttpGet / request failed)"
	end
	local chunk, err = loadstring(source, "@" .. (entry.name or "tool"))
	if not chunk then
		return false, err or "Failed to compile tool"
	end
	local ok, runErr = pcall(chunk)
	if not ok then
		return false, tostring(runErr)
	end
	return true, nil
end
