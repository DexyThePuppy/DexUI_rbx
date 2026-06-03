--!nonstrict
-- Resolves tool thumbnails: rbxassetid, GitHub/raw https (cached via getcustomasset), or bundled PNGs.

local Util = require("../core/util")
local EmbeddedAssets = require("./tool-assets-embedded")

local REMOTE_CACHE_FOLDER = "DexUI/tool-assets"
local ASSET_CACHE_FOLDER = REMOTE_CACHE_FOLDER

local remoteUriCache: { [string]: string } = {}
local assetUriCache: { [string]: string } = {}

local ASSET_FILES: { [string]: string } = {
	dexplusplus = "assets/tools/dexplusplus.png",
	cobalt = "assets/tools/cobalt.png",
}

local SEARCH_PREFIXES = {
	"",
	"DexUI/",
}

-- Used when local/embedded bytes are unavailable (e.g. dist-only load without assets/).
local ASSET_REMOTE_FALLBACK: { [string]: string } = {
	dexplusplus = "https://github.com/AZYsGithub/DexPlusPlus/blob/main/preview.png",
	cobalt = "https://github.com/notpoiu/cobalt/blob/main/Assets/Logo.png",
}

local PLACEHOLDER = "rbxasset://textures/ui/GuiImagePlaceholder.png"
local MIN_IMAGE_BYTES = 64

local function canCacheFiles(): boolean
	return writefile ~= nil and getcustomasset ~= nil and isfolder ~= nil and makefolder ~= nil
end

local function ensureCacheFolder()
	if not canCacheFiles() then
		return
	end
	pcall(function()
		if not isfolder("DexUI") then
			makefolder("DexUI")
		end
		if not isfolder(REMOTE_CACHE_FOLDER) then
			makefolder(REMOTE_CACHE_FOLDER)
		end
	end)
end

local function httpGetRaw(url: string): string?
	local httpGet = (game :: any).HttpGet
	if type(httpGet) == "function" then
		local ok, body = pcall(function()
			return httpGet(url)
		end)
		if ok and type(body) == "string" and #body > MIN_IMAGE_BYTES then
			return body
		end
	end
	local ok, res = Util.httpRequest({ Url = url, Method = "GET" })
	if not ok or not res or res.StatusCode ~= 200 or type(res.Body) ~= "string" or #res.Body < MIN_IMAGE_BYTES then
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

-- github.com/owner/repo/blob/branch/path -> raw.githubusercontent.com/owner/repo/branch/path
local function normalizeGithubImageUrl(url: string): string
	if string.find(url, "raw.githubusercontent.com", 1, true) then
		return url
	end
	local owner, repo, branch, path = string.match(
		url,
		"https://github%.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)"
	)
	if owner and repo and branch and path then
		return string.format(
			"https://raw.githubusercontent.com/%s/%s/%s/%s",
			owner,
			repo,
			branch,
			path
		)
	end
	return url
end

local function isRemoteImageUrl(url: string): boolean
	return string.find(url, "https://", 1, true) ~= nil or string.find(url, "http://", 1, true) ~= nil
end

local function extensionForUrl(url: string): string
	local ext = string.match(url:lower(), "%.(%w+)[^%.%/]*$")
	if ext == "jpg" or ext == "jpeg" or ext == "png" or ext == "webp" or ext == "gif" then
		return ext
	end
	return "png"
end

local function bodyToLoadable(cacheKey: string, body: string, ext: string): string?
	ensureCacheFolder()
	local path = REMOTE_CACHE_FOLDER .. "/" .. cacheKey .. "." .. ext
	local writeOk = pcall(writefile, path, body)
	if not writeOk then
		return nil
	end
	local ok, uri = pcall(getcustomasset, path)
	if ok and type(uri) == "string" and uri ~= "" then
		return uri
	end
	return nil
end

-- ImageLabel cannot display raw https:// URLs; download and map to rbxasset://
local function remoteUrlToLoadable(url: string): string?
	local normalized = normalizeGithubImageUrl(url)
	if remoteUriCache[normalized] then
		return remoteUriCache[normalized]
	end
	if not canCacheFiles() then
		return nil
	end
	local body = httpGetRaw(normalized)
	if not body then
		return nil
	end
	local ext = extensionForUrl(normalized)
	local uri = bodyToLoadable("remote_" .. hashSlug(normalized), body, ext)
	if uri then
		remoteUriCache[normalized] = uri
		remoteUriCache[url] = uri
	end
	return uri
end

local function decodeBase64(data: string): string?
	local g = (getgenv and getgenv()) or _G
	if type((g :: any).base64decode) == "function" then
		local ok, out = pcall((g :: any).base64decode, data)
		if ok and type(out) == "string" then
			return out
		end
	end
	if type((g :: any).base64_decode) == "function" then
		local ok, out = pcall((g :: any).base64_decode, data)
		if ok and type(out) == "string" then
			return out
		end
	end
	if crypt and crypt.base64 and crypt.base64.decode then
		local ok, out = pcall(crypt.base64.decode, data)
		if ok and type(out) == "string" then
			return out
		end
	end
	return nil
end

local function readEmbeddedBytes(assetKey: string): string?
	local encoded = EmbeddedAssets[assetKey]
	if type(encoded) ~= "string" or encoded == "" then
		return nil
	end
	return decodeBase64(encoded)
end

local function readAssetBytes(relativePath: string): string?
	if not readfile or not isfile then
		return nil
	end
	for _, prefix in SEARCH_PREFIXES do
		local path = prefix .. relativePath
		if isfile(path) then
			local ok, body = pcall(readfile, path)
			if ok and type(body) == "string" and #body > 32 then
				return body
			end
		end
	end
	return nil
end

local function resolveAssetKey(assetKey: string): string?
	if assetUriCache[assetKey] then
		return assetUriCache[assetKey]
	end
	local relative = ASSET_FILES[assetKey]
	if not relative then
		return nil
	end
	local body = readAssetBytes(relative) or readEmbeddedBytes(assetKey)
	if not body then
		local fallbackUrl = ASSET_REMOTE_FALLBACK[assetKey]
		if fallbackUrl then
			return remoteUrlToLoadable(fallbackUrl)
		end
		return nil
	end
	local uri = bodyToLoadable("bundled_" .. assetKey, body, extensionForUrl(relative))
	if uri then
		assetUriCache[assetKey] = uri
	end
	return uri
end

local function resolveToolThumbnail(thumbnail: string): string
	if not thumbnail or thumbnail == "" then
		return PLACEHOLDER
	end
	if string.find(thumbnail, "rbxasset://", 1, true) then
		return thumbnail
	end
	if string.find(thumbnail, "rbxassetid://", 1, true) or string.find(thumbnail, "rbxthumb://", 1, true) then
		return thumbnail
	end
	if isRemoteImageUrl(thumbnail) then
		local loaded = remoteUrlToLoadable(thumbnail)
		if loaded then
			return loaded
		end
		return PLACEHOLDER
	end
	local assetKey = string.match(thumbnail, "^asset:(.+)$")
	if not assetKey then
		assetKey = string.match(thumbnail, "^assets/tools/([^/]+)%.%w+$")
	end
	if assetKey then
		local resolved = resolveAssetKey(assetKey)
		if resolved then
			return resolved
		end
		local fallbackUrl = ASSET_REMOTE_FALLBACK[assetKey]
		if fallbackUrl then
			local remote = remoteUrlToLoadable(fallbackUrl)
			if remote then
				return remote
			end
		end
	end
	local digits = string.match(thumbnail, "(%d+)")
	if digits then
		return "rbxassetid://" .. digits
	end
	return PLACEHOLDER
end

local function resolveToolThumbnailAsync(thumbnail: string, callback: (string) -> ())
	task.spawn(function()
		local uri = resolveToolThumbnail(thumbnail)
		if callback then
			callback(uri)
		end
	end)
end

return {
	resolveToolThumbnail = resolveToolThumbnail,
	resolveToolThumbnailAsync = resolveToolThumbnailAsync,
	normalizeGithubImageUrl = normalizeGithubImageUrl,
	ASSET_FILES = ASSET_FILES,
	PLACEHOLDER = PLACEHOLDER,
}
