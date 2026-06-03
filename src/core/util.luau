--!nonstrict
-- Stateless shared helpers: tweening, input classification, drag tracks, HTTP,
-- Creator Store media search, clipboard, the Material icon library, corners, ripples.

local Services = require("../services")
local Typography = require("./typography")

local TweenService = Services.TweenService
local UserInputService = Services.UserInputService
local HttpService = Services.HttpService
local AssetService = Services.AssetService

local Config = require("../config")
local TextLabelUtil = require("./text-label")
local MEDIA_FETCH_LIMIT = Config.MediaFetchLimit
local CREATOR_STORE_SEARCH = Config.CreatorStoreSearch
local TextSizes = Typography.TextSizes

local function tierFromNumber(size: number): string
	-- Map legacy pixel sizes onto the three tiers (minimum readable = sm).
	if size <= TextSizes.sm + 1 then
		return "sm"
	end
	if size <= TextSizes.md + 1 then
		return "md"
	end
	return "lg"
end

-- Universal typography: only sm / md / lg. Accepts tier string or legacy pixel value.
local function textSize(tier: string | number): number
	if type(tier) == "number" then
		tier = tierFromNumber(tier)
	end
	if type(tier) ~= "string" then
		return TextSizes.md
	end
	local key = string.lower(tier)
	return TextSizes[key] or TextSizes.md
end

local M3_EASE = Enum.EasingStyle.Exponential
local STD_TWEEN = TweenInfo.new(0.3, M3_EASE, Enum.EasingDirection.Out)

local function tween(obj: Instance, prop: string, value: any, duration: number?): Tween
	local info = duration and TweenInfo.new(duration, M3_EASE, Enum.EasingDirection.Out) or STD_TWEEN
	local anim = TweenService:Create(obj, info, { [prop] = value })
	anim:Play()
	return anim
end

local function isPrimaryInput(input: InputObject): boolean
	local name = input.UserInputType.Name
	return name:find("MouseButton1") ~= nil or name:find("Touch") ~= nil
end

local function isMoveInput(input: InputObject): boolean
	local name = input.UserInputType.Name
	return name:find("MouseMovement") ~= nil or name:find("Touch") ~= nil
end

local function isGrabInput(input: InputObject): boolean
	return isPrimaryInput(input) or input.UserInputType == Enum.UserInputType.MouseButton2
end

local function screenMouseLocation(): Vector2
	return UserInputService:GetMouseLocation()
end

-- 1D drag tracks freeze widget geometry at press time so moving/rotating SurfaceGuis
-- don't shift AbsolutePosition under the cursor and jump the value.
type DragTrack1D = {
	startMouseX: number,
	startFraction: number,
	trackWidth: number,
}

local function captureDragTrack1D(gui: GuiObject, startFraction: number?): DragTrack1D
	local mouseX = screenMouseLocation().X
	local trackWidth = math.max(1, gui.AbsoluteSize.X)
	local fraction = startFraction
	if fraction == nil then
		fraction = math.clamp((mouseX - gui.AbsolutePosition.X) / trackWidth, 0, 1)
	end
	return {
		startMouseX = mouseX,
		startFraction = fraction,
		trackWidth = trackWidth,
	}
end

local function fractionFromDragTrack(track: DragTrack1D): number
	local mouseX = screenMouseLocation().X
	return math.clamp(track.startFraction + (mouseX - track.startMouseX) / track.trackWidth, 0, 1)
end

type DragTrack2D = {
	startMouse: Vector2,
	startX: number,
	startY: number,
	trackWidth: number,
	trackHeight: number,
}

local function captureDragTrack2D(gui: GuiObject, startX: number, startY: number): DragTrack2D
	return {
		startMouse = screenMouseLocation(),
		startX = startX,
		startY = startY,
		trackWidth = math.max(1, gui.AbsoluteSize.X),
		trackHeight = math.max(1, gui.AbsoluteSize.Y),
	}
end

local function pointFromDragTrack2D(track: DragTrack2D): (number, number)
	local mouse = screenMouseLocation()
	local x = math.clamp(track.startX + (mouse.X - track.startMouse.X) / track.trackWidth, 0, 1)
	local y = math.clamp(track.startY + (mouse.Y - track.startMouse.Y) / track.trackHeight, 0, 1)
	return x, y
end

local function httpRequest(opts: { Url: string, Method: string?, Headers: { [string]: string }?, Body: string? }): (boolean, { StatusCode: number?, Body: string? }?)
	local req = (syn and syn.request) or request or (http and http.request)
	if req then
		local ok, res = pcall(function()
			return req(opts)
		end)
		if ok and type(res) == "table" then
			return true, res
		end
	end
	if opts.Method == nil or opts.Method == "GET" then
		local ok, body = pcall(function()
			return HttpService:GetAsync(opts.Url)
		end)
		if ok then
			return true, { StatusCode = 200, Body = body }
		end
	end
	return false, nil
end

type MediaHit = { id: number, title: string, subtitle: string? }

local function formatMediaDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m > 0 then
		return string.format("%d:%02d", m, s)
	end
	return string.format("0:%02d", s)
end

local function formatMediaClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

local function searchCreatorStoreVideos(keyword: string, pageToken: string?): ({ MediaHit }, string?, string?)
	local hs = HttpService
	local url = string.format(
		"%s?searchCategoryType=Video&maxPageSize=%d",
		CREATOR_STORE_SEARCH,
		MEDIA_FETCH_LIMIT
	)
	if keyword ~= "" then
		url ..= "&query=" .. hs:UrlEncode(keyword)
	end
	if pageToken and pageToken ~= "" then
		url ..= "&pageToken=" .. hs:UrlEncode(pageToken)
	end

	local ok, res = httpRequest({ Url = url, Method = "GET" })
	if not ok or not res or not res.Body then
		return {}, nil, "Creator Store request failed."
	end
	if res.StatusCode ~= 200 then
		return {}, nil, "Video search returned HTTP " .. tostring(res.StatusCode) .. "."
	end

	local decodeOk, data = pcall(function()
		return hs:JSONDecode(res.Body)
	end)
	if not decodeOk or type(data) ~= "table" then
		return {}, nil, "Could not parse Creator Store response."
	end

	local hits: { MediaHit } = {}
	for _, entry in data.creatorStoreAssets or {} do
		if type(entry) == "table" and type(entry.asset) == "table" then
			local asset = entry.asset
			if type(asset.id) == "number" and type(asset.name) == "string" then
				local subtitle: string? = nil
				if type(entry.creator) == "table" and type(entry.creator.name) == "string" then
					subtitle = entry.creator.name
					if entry.creator.verified == true then
						subtitle ..= " · verified"
					end
				end
				table.insert(hits, { id = asset.id, title = asset.name, subtitle = subtitle })
			end
		end
	end

	local nextToken = if type(data.nextPageToken) == "string" and data.nextPageToken ~= ""
		then data.nextPageToken
		else nil
	return hits, nextToken, nil
end

local function searchCreatorStoreAudio(
	keyword: string,
	pagesHandle: any?,
	advance: boolean?
): ({ MediaHit }, any?, string?)
	local handle = pagesHandle

	if advance and handle then
		if handle.IsFinished then
			return {}, handle, "No more audio pages."
		end
		local ok, err = pcall(function()
			handle:AdvanceToNextPageAsync()
		end)
		if not ok then
			return {}, handle, tostring(err)
		end
	elseif not handle then
		local params = Instance.new("AudioSearchParams")
		if keyword ~= "" then
			params.SearchKeyword = keyword
		end
		local ok, newHandle = pcall(function()
			return AssetService:SearchAudioAsync(params)
		end)
		if not ok then
			return {}, nil, tostring(newHandle)
		end
		handle = newHandle
	end

	local pageOk, page = pcall(function()
		return handle:GetCurrentPage()
	end)
	if not pageOk or type(page) ~= "table" then
		return {}, handle, "Could not read audio results."
	end

	local hits: { MediaHit } = {}
	for _, item in page do
		local duration = if type(item.Duration) == "number" then item.Duration else 0
		if type(item.Id) == "number" and type(item.Title) == "string" then
			local subtitle = ""
			if type(item.Artist) == "string" and item.Artist ~= "" then
				subtitle = item.Artist
			end
			if duration > 0 then
				subtitle ..= (subtitle ~= "" and " · " or "") .. formatMediaDuration(duration)
			end
			table.insert(hits, {
				id = item.Id,
				title = item.Title,
				subtitle = if subtitle ~= "" then subtitle else nil,
			})
		end
	end

	return hits, handle, nil
end

local function trySetClipboard(text: string): boolean
	local ok = pcall(function()
		if setclipboard then
			setclipboard(text)
		else
			error("no clipboard")
		end
	end)
	return ok
end

local materialIconLibrary: { { name: string, id: number } }? = nil

local function formatMaterialIconCode(name: string, id: number): string
	return string.format('%d -- %s\nlocal image = "rbxassetid://%d"', id, name, id)
end

local function loadMaterialIconLibrary(): ({ { name: string, id: number } }, string?)
	if materialIconLibrary then
		return materialIconLibrary, nil
	end

	local ok, result = pcall(function()
		local objs = game:GetObjects("rbxassetid://6045494621")
		local model = objs[1]
		local source = model.Main.res.IconDump.Source
		local pattern = '%["([^"]+)"%] = "http://www%.roblox%.com/asset/%?id=(%d+)"'
		local icons: { { name: string, id: number } } = {}
		local pos = 1
		while true do
			local startIdx, endIdx, name, idStr = source:find(pattern, pos)
			if not startIdx then
				break
			end
			table.insert(icons, { name = name, id = tonumber(idStr) :: number })
			pos = endIdx + 1
		end
		table.sort(icons, function(a, b)
			return a.name < b.name
		end)
		model:Destroy()
		return icons
	end)

	if not ok or type(result) ~= "table" then
		return {}, if ok then "Could not parse Material Icons library." else tostring(result)
	end

	materialIconLibrary = result
	return materialIconLibrary, nil
end

local function corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- Material 3 ripple / touch feedback radiating from the press point.
local function ripple(parent: GuiObject, color: Color3, originX: number?, originY: number?)
	parent.ClipsDescendants = true
	local circle = Instance.new("Frame")
	circle.BackgroundColor3 = color
	circle.BackgroundTransparency = 0.78
	circle.BorderSizePixel = 0
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.ZIndex = parent.ZIndex + 5

	local px = originX and (originX - parent.AbsolutePosition.X) or parent.AbsoluteSize.X / 2
	local py = originY and (originY - parent.AbsolutePosition.Y) or parent.AbsoluteSize.Y / 2
	circle.Position = UDim2.fromOffset(px, py)
	circle.Size = UDim2.fromOffset(0, 0)
	corner(circle, 999)
	circle.Parent = parent

	local maxSize = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.2
	TweenService:Create(circle, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(maxSize, maxSize),
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.55, function()
		circle:Destroy()
	end)
end

return {
	M3_EASE = M3_EASE,
	STD_TWEEN = STD_TWEEN,
	TextSizes = TextSizes,
	textSize = textSize,
	tween = tween,
	isPrimaryInput = isPrimaryInput,
	isMoveInput = isMoveInput,
	isGrabInput = isGrabInput,
	screenMouseLocation = screenMouseLocation,
	captureDragTrack1D = captureDragTrack1D,
	fractionFromDragTrack = fractionFromDragTrack,
	captureDragTrack2D = captureDragTrack2D,
	pointFromDragTrack2D = pointFromDragTrack2D,
	httpRequest = httpRequest,
	formatMediaDuration = formatMediaDuration,
	formatMediaClock = formatMediaClock,
	searchCreatorStoreVideos = searchCreatorStoreVideos,
	searchCreatorStoreAudio = searchCreatorStoreAudio,
	trySetClipboard = trySetClipboard,
	formatMaterialIconCode = formatMaterialIconCode,
	loadMaterialIconLibrary = loadMaterialIconLibrary,
	corner = corner,
	ripple = ripple,
	applyTextLabel = TextLabelUtil.applyTextLabel,
}
