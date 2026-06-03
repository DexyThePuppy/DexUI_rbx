--!nonstrict
-- Resolves bundled tool thumbnails (PNG) to rbxasset:// via executor file APIs.

local ASSET_CACHE_FOLDER = "DexUI/tool-assets"
local assetUriCache: { [string]: string } = {}

local ASSET_FILES: { [string]: string } = {
	dexplusplus = "assets/tools/dexplusplus.png",
	cobalt = "assets/tools/cobalt.png",
}

local SEARCH_PREFIXES = {
	"",
	"DexUI/",
}

local function canCacheFiles(): boolean
	return readfile ~= nil and writefile ~= nil and getcustomasset ~= nil and isfolder ~= nil and makefolder ~= nil
end

local function ensureCacheFolder()
	if not canCacheFiles() then
		return
	end
	pcall(function()
		if not isfolder("DexUI") then
			makefolder("DexUI")
		end
		if not isfolder(ASSET_CACHE_FOLDER) then
			makefolder(ASSET_CACHE_FOLDER)
		end
	end)
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

local function cacheToCustomAsset(assetKey: string, body: string): string?
	ensureCacheFolder()
	local ext = string.match(ASSET_FILES[assetKey] or "", "%.(%w+)$") or "png"
	local cachePath = ASSET_CACHE_FOLDER .. "/" .. assetKey .. "." .. ext
	local writeOk = pcall(writefile, cachePath, body)
	if not writeOk then
		return nil
	end
	local ok, uri = pcall(getcustomasset, cachePath)
	if ok and type(uri) == "string" and uri ~= "" then
		return uri
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
	local body = readAssetBytes(relative)
	if not body then
		return nil
	end
	local uri = cacheToCustomAsset(assetKey, body)
	if uri then
		assetUriCache[assetKey] = uri
	end
	return uri
end

local function resolveToolThumbnail(thumbnail: string): string
	if not thumbnail or thumbnail == "" then
		return "rbxasset://textures/ui/GuiImagePlaceholder.png"
	end
	if string.find(thumbnail, "rbxasset://", 1, true) then
		return thumbnail
	end
	if string.find(thumbnail, "rbxassetid://", 1, true) or string.find(thumbnail, "rbxthumb://", 1, true) then
		return thumbnail
	end
	if string.find(thumbnail, "http://", 1, true) or string.find(thumbnail, "https://", 1, true) then
		return thumbnail
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
	end
	local digits = string.match(thumbnail, "(%d+)")
	if digits then
		return "rbxassetid://" .. digits
	end
	return thumbnail
end

return {
	resolveToolThumbnail = resolveToolThumbnail,
	ASSET_FILES = ASSET_FILES,
}
