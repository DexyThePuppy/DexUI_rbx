--!nonstrict
-- Built-in and workspace-defined external tools (Dex++, Cobalt, etc.).

local INDEX_PATHS = {
	"scripts/tools/index.lua",
	"DexUI/scripts/tools/index.lua",
}

local FALLBACK_TOOLS = {
	{
		id = "dexplusplus",
		name = "Dex++",
		description = "Extended Moon Dex explorer — decompiler, save instance, model viewer, console, and mobile input.",
		thumbnail = "https://github.com/AZYsGithub/DexPlusPlus/blob/main/preview.png",
		url = "https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua",
		repo = "https://github.com/AZYsGithub/DexPlusPlus",
	},
	{
		id = "cobalt",
		name = "Cobalt",
		description = "Remote spy — monitor and intercept incoming/outgoing network traffic with replay and blocking.",
		thumbnail = "asset:cobalt",
		url = "https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau",
		repo = "https://github.com/notpoiu/cobalt",
	},
}

export type ToolEntry = {
	id: string,
	name: string,
	description: string?,
	thumbnail: string,
	url: string,
	repo: string?,
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

local function normalizeEntry(raw: any): ToolEntry?
	if type(raw) ~= "table" or type(raw.id) ~= "string" or type(raw.name) ~= "string" then
		return nil
	end
	if type(raw.url) ~= "string" or raw.url == "" then
		return nil
	end
	local thumb = raw.thumbnail or raw.image
	if type(thumb) == "number" then
		thumb = "rbxassetid://" .. tostring(thumb)
	elseif type(thumb) ~= "string" or thumb == "" then
		thumb = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	end
	return {
		id = raw.id,
		name = raw.name,
		description = if type(raw.description) == "string" then raw.description else nil,
		thumbnail = thumb,
		url = raw.url,
		repo = if type(raw.repo) == "string" then raw.repo else nil,
	}
end

local function loadFromSource(source: string): { ToolEntry }
	local chunk = loadstring(source, "scripts/tools/index.lua")
	if not chunk then
		return {}
	end
	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" then
		return {}
	end
	local entries: { ToolEntry } = {}
	for _, raw in data do
		local entry = normalizeEntry(raw)
		if entry then
			table.insert(entries, entry)
		end
	end
	return entries
end

local function load(): { ToolEntry }
	local source = readIndexSource()
	if source then
		local entries = loadFromSource(source)
		if #entries > 0 then
			return entries
		end
	end
	local fallback: { ToolEntry } = {}
	for _, raw in FALLBACK_TOOLS do
		local entry = normalizeEntry(raw)
		if entry then
			table.insert(fallback, entry)
		end
	end
	return fallback
end

return {
	load = load,
	INDEX_PATHS = INDEX_PATHS,
}
