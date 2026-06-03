--!nonstrict
-- The shared Context. Given a window's `lib`, live `theme` table and the stateless
-- helper modules, this builds the per-window machinery that every component and the
-- window assembler rely on:
--   * a theming registry (reg / regDynamic + palette switching),
--   * tracked-connection wrappers (so persistent service listeners can be cleaned up),
--   * the contained-card layout system (grouped rows with M3 per-position corners),
--   * the flat search index + the shared title/subtitle label helper.
-- It returns one `ctx` table holding all of the above plus passthroughs to the
-- util / fonts / sound / services modules, so callers only ever destructure `ctx`.

type Palette = { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 }

type Deps = {
	lib: any,
	theme: Palette,
	util: any,
	fonts: any,
	sound: any,
	palettes: any,
	services: any,
	config: any,
}

return function(deps: Deps)
	local lib = deps.lib
	local theme = deps.theme
	local Util = deps.util
	local Fonts = deps.fonts
	local Sound = deps.sound
	local PALETTES = deps.palettes
	local Services = deps.services
	local Config = deps.config

	-- Live theme: read everywhere as `curTheme`. We mutate this table in place on a
	-- palette change (rather than swapping the reference) so every alias stays valid.
	local curTheme = theme

	local tween = Util.tween
	local corner = Util.corner
	local textSize = Util.textSize
	local Grid = require("./grid")
	local fontWeight = Fonts.fontWeight
	local fontRole = Fonts.fontRole
	local fontBody = Fonts.fontBody
	local fontEmphasis = Fonts.fontEmphasis
	local fontTitle = Fonts.fontTitle
	local fontDisplay = Fonts.fontDisplay
	local fontLarge = Fonts.fontLarge
	local fontChrome = Fonts.fontChrome
	local m3Font = Fonts.m3Font
	local applyTextLabel = Util.applyTextLabel

	local RunService = Services.RunService
	local UserInputService = Services.UserInputService

	--//---------------------- TRACKED CONNECTIONS ----------------------\\--
	-- Connections to persistent services (RunService / UserInputService / etc.)
	-- survive gui:Destroy(), so we track them and disconnect on unload to fully
	-- remove the script. (Connections to gui instances auto-disconnect on destroy.)
	local trackedConns: { RBXScriptConnection } = {}
	local function track(c: RBXScriptConnection): RBXScriptConnection
		table.insert(trackedConns, c)
		return c
	end
	local function onRender(fn): RBXScriptConnection
		return track(RunService.RenderStepped:Connect(fn))
	end
	local function onHeartbeat(fn): RBXScriptConnection
		return track(RunService.Heartbeat:Connect(fn))
	end
	local function onInputBegan(fn): RBXScriptConnection
		return track(UserInputService.InputBegan:Connect(fn))
	end
	local function onInputChanged(fn): RBXScriptConnection
		return track(UserInputService.InputChanged:Connect(fn))
	end
	local function onInputEnded(fn): RBXScriptConnection
		return track(UserInputService.InputEnded:Connect(fn))
	end

	--//---------------------- THEMING REGISTRY ----------------------\\--
	type Binding = { obj: Instance, prop: string, token: string }
	local staticBindings: { Binding } = {}
	local dynamicAppliers: { (theme: Palette, duration: number) -> () } = {}

	local function reg(obj: Instance, prop: string, token: string): Instance
		table.insert(staticBindings, { obj = obj, prop = prop, token = token })
		;(obj :: any)[prop] = curTheme[token]
		return obj
	end
	local function regDynamic(fn: (theme: Palette, duration: number) -> ())
		table.insert(dynamicAppliers, fn)
		fn(curTheme, 0)
	end

	local function applyPalette(palette: Palette, d: number)
		-- Mutate the live theme table in place so every `curTheme` alias updates.
		for token, value in palette :: any do
			(curTheme :: any)[token] = value
		end
		for _, b in staticBindings do
			if d > 0 then
				tween(b.obj, b.prop, (curTheme :: any)[b.token], d)
			else
				-- Instant path: avoids spawning hundreds of tweens per frame while
				-- the user drags the tint picker.
				(b.obj :: any)[b.prop] = (curTheme :: any)[b.token]
			end
		end
		for _, apply in dynamicAppliers do
			apply(curTheme, d)
		end
	end

	function lib:ChangePalette(name: string)
		local palette = PALETTES[name]
		if not palette then
			return
		end
		applyPalette(palette, 0.5)
	end

	-- Build a full dark M3 palette derived from a single accent/tint colour,
	-- then apply it. Lets the user pick any tint instead of a fixed preset list.
	local function tintPalette(color: Color3): Palette
		local h, s, v = color:ToHSV()
		-- Keep the accent vivid and bright enough to read on a dark surface.
		local pri = Color3.fromHSV(h, math.clamp(s, 0.25, 0.9), math.clamp(v, 0.7, 1))
		local black = Color3.new(0, 0, 0)
		local white = Color3.new(1, 1, 1)
		return {
			bg = Color3.fromHSV(h, math.min(s, 0.22), 0.11),
			fg = white:Lerp(pri, 0.08),
			pri = pri,
			onpri = Color3.fromHSV(h, math.min(s + 0.1, 1), 0.22):Lerp(black, 0.1),
			inact = Color3.fromHSV(h, math.min(s, 0.2), 0.18),
			out = Color3.fromHSV(h, math.min(s, 0.18), 0.58),
		}
	end

	function lib:ApplyTint(color: Color3)
		-- Instant so live dragging in the tint picker stays smooth.
		applyPalette(tintPalette(color), 0)
	end

	function lib:SetSoundsEnabled(enabled: boolean)
		Sound.setSoundsEnabled(enabled and true or false)
	end

	function lib:SetSoundVolume(scale: number)
		Sound.setMasterVolume(math.clamp(scale, 0, 1))
	end

	function lib:PlayFeedback(pattern: string)
		Sound.playFeedback(pattern)
	end

	function lib:SetNotificationSoundAssetId(id: number)
		Sound.setNotificationSoundAssetId(id)
	end

	function lib:GetNotificationSoundAssetId(): number
		return Sound.getNotificationSoundAssetId()
	end

	function lib:SetNotificationRandomPitch(enabled: boolean)
		Sound.setNotificationRandomPitch(enabled)
	end

	function lib:IsNotificationRandomPitch(): boolean
		return Sound.isNotificationRandomPitch()
	end

	function lib:PreviewNotificationSound()
		Sound.previewNotificationSound()
	end

	--//---------------------- SEARCH INDEX ----------------------\\--
	-- Flat index of every named element so the title-bar search can find them.
	type SearchEntry = { name: string, tabIndex: number, container: Instance, instance: GuiObject }
	lib.SearchIndex = {} :: { SearchEntry }
	local function indexElement(name: string, instance: GuiObject)
		table.insert(lib.SearchIndex, {
			name = name,
			tabIndex = lib.CurrentBuildTabIndex,
			container = lib.CurrentBuildContainer,
			instance = instance,
		})
	end

	--//---------------------- CONTAINED CARD LAYOUT ----------------------\\--
	-- Grouped rows with M3 per-position corner radii.
	local CARD_CORNER = 18
	local CARD_CORNER_SM = 4
	local CARD_ROW_GAP = 3
	local CARD_ROW_PAD_X = 16
	local CARD_ROW_PAD_Y = 8

	lib.CurrentBuildCardInner = nil :: Frame?
	lib.CurrentBuildCardRows = nil :: { Frame }?
	lib.CardRowCount = 0
	lib.CardItemOrder = 0

	local function clearSurfaceCornerDecor(surface: Frame)
		for _, ch in surface:GetChildren() do
			if ch.Name == "CornerPatch" then
				ch:Destroy()
			end
		end
		local existing = surface:FindFirstChildOfClass("UICorner")
		if existing then
			existing:Destroy()
		end
	end

	-- Roblox UICorner is uniform, so to mix a large and a small radius on one
	-- surface we round the whole surface to the large radius, then overlay a
	-- same-colour patch (rounded to the small radius) into the corners that
	-- should read as small. The patch fills the gap between the two arcs.
	local function addCornerPatch(surface: Frame, anchor: Vector2, pos: UDim2)
		local patch = Instance.new("Frame")
		patch.Name = "CornerPatch"
		patch.Size = UDim2.fromOffset(CARD_CORNER + 8, CARD_CORNER + 8)
		patch.AnchorPoint = anchor
		patch.Position = pos
		patch.BorderSizePixel = 0
		patch.ZIndex = 0
		patch.Parent = surface
		reg(patch, "BackgroundColor3", "inact")
		corner(patch, CARD_CORNER_SM)
	end

	local function applyGroupSurfaceCorners(surface: Frame, role: string)
		clearSurfaceCornerDecor(surface)

		if role == "middle" then
			corner(surface, CARD_CORNER_SM)
			return
		end

		corner(surface, CARD_CORNER)
		if role == "first" then
			addCornerPatch(surface, Vector2.new(0, 1), UDim2.new(0, 0, 1, 0)) -- bottom-left
			addCornerPatch(surface, Vector2.new(1, 1), UDim2.new(1, 0, 1, 0)) -- bottom-right
		elseif role == "last" then
			addCornerPatch(surface, Vector2.new(0, 0), UDim2.new(0, 0, 0, 0)) -- top-left
			addCornerPatch(surface, Vector2.new(1, 0), UDim2.new(1, 0, 0, 0)) -- top-right
		end
	end

	-- Apply M3 grouped-list corners across an ordered list of sibling surfaces.
	-- Reusable for the title-bar overlays as well as the build container.
	local function styleGroupedSurfaces(rows: { Frame })
		local n = #rows
		for i, surface in rows do
			local role: string
			if n == 1 then
				role = "only"
			elseif i == 1 then
				role = "first"
			elseif i == n then
				role = "last"
			else
				role = "middle"
			end
			applyGroupSurfaceCorners(surface, role)
		end
	end

	local function refreshCardRowCorners()
		local rows = lib.CurrentBuildCardRows
		if not rows then
			return
		end
		styleGroupedSurfaces(rows)
	end

	-- Tint a grouped surface AND its corner patches together so hover / ripple
	-- feedback stays seamless across the mixed-radius corners.
	local function tintRow(surface: Frame, color: Color3, dur: number)
		tween(surface, "BackgroundColor3", color, dur)
		for _, ch in surface:GetChildren() do
			if ch.Name == "CornerPatch" then
				tween(ch, "BackgroundColor3", color, dur)
			end
		end
	end

	local function closeBuildCard()
		if lib.CurrentBuildCardRows and #lib.CurrentBuildCardRows > 0 then
			refreshCardRowCorners()
		end
		lib.CurrentBuildCardInner = nil
		lib.CurrentBuildCardRows = nil
		lib.CardRowCount = 0
		lib.CardItemOrder = 0
	end

	local function nextCardItemOrder(): number
		lib.CardItemOrder += 1
		return lib.CardItemOrder
	end

	local function beginBuildCard(): Frame
		if lib.CurrentBuildCardInner then
			return lib.CurrentBuildCardInner
		end

		local group = Instance.new("Frame")
		group.Name = "CardGroup"
		group.Size = UDim2.new(1, 0, 0, 0)
		group.AutomaticSize = Enum.AutomaticSize.Y
		group.BackgroundTransparency = 1
		group.BorderSizePixel = 0
		group.Parent = lib.CurrentBuildContainer

		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, CARD_ROW_GAP)
		list.Parent = group

		lib.CurrentBuildCardInner = group
		lib.CurrentBuildCardRows = {}
		lib.CardRowCount = 0
		return group
	end

	local function beginCardRow(height: number?, autoHeight: boolean?): Frame
		local inner = beginBuildCard()
		lib.CardRowCount += 1

		local surface = Instance.new("Frame")
		surface.Name = "Surface"
		surface.BorderSizePixel = 0
		surface.LayoutOrder = nextCardItemOrder()
		surface.Parent = inner
		reg(surface, "BackgroundColor3", "inact")
		table.insert(lib.CurrentBuildCardRows :: { Frame }, surface)

		-- Padding lives on this inner wrapper, NOT the surface, so corner
		-- patches (parented to the surface) can sit on the true corners
		-- instead of being inset by the row padding.
		local rowInner = Instance.new("Frame")
		rowInner.Name = "RowInner"
		rowInner.BackgroundTransparency = 1
		rowInner.BorderSizePixel = 0
		rowInner.ZIndex = 1
		rowInner.Parent = surface

		local rowPad = Instance.new("UIPadding")
		rowPad.PaddingLeft = UDim.new(0, CARD_ROW_PAD_X)
		rowPad.PaddingRight = UDim.new(0, CARD_ROW_PAD_X)
		rowPad.PaddingTop = UDim.new(0, CARD_ROW_PAD_Y)
		rowPad.PaddingBottom = UDim.new(0, CARD_ROW_PAD_Y)
		rowPad.Parent = rowInner

		local content = Instance.new("Frame")
		content.Name = "Content"
		content.BackgroundTransparency = 1
		content.BorderSizePixel = 0
		content.ZIndex = 1
		content.Parent = rowInner

		if autoHeight then
			-- Content drives the height; the surface grows with it.
			surface.Size = UDim2.new(1, 0, 0, 0)
			surface.AutomaticSize = Enum.AutomaticSize.Y
			surface.ClipsDescendants = false
			rowInner.Size = UDim2.new(1, 0, 0, 0)
			rowInner.AutomaticSize = Enum.AutomaticSize.Y
			content.Size = UDim2.new(1, 0, 0, 0)
			content.AutomaticSize = Enum.AutomaticSize.Y
		else
			-- Fixed height. No AutomaticSize anywhere, and the surface clips,
			-- so transient children (e.g. ripples) can never resize the row.
			local full = (height or 0) + CARD_ROW_PAD_Y * 2
			surface.Size = UDim2.new(1, 0, 0, full)
			surface.ClipsDescendants = true
			rowInner.Size = UDim2.new(1, 0, 1, 0)
			content.Size = UDim2.new(1, 0, 1, 0)
		end

		refreshCardRowCorners()
		return content
	end

	-- Shared title + optional subtitle stack used by switch / keybind / colorpicker.
	local function fillLabelColumn(col: Instance, txt: string, sub: string?): TextLabel
		local hasSub = sub ~= nil and sub ~= ""
		local md = textSize("md")
		local sm = textSize("sm")
		local l = Instance.new("TextLabel")
		l.Text = txt
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = col
		reg(l, "TextColor3", "fg")
		if hasSub then
			l.Size = UDim2.new(1, 0, 0, 20)
			l.Position = UDim2.new(0, 0, 0, 7)
			applyTextLabel(l, m3Font, md, "fill")
			l.TextYAlignment = Enum.TextYAlignment.Bottom

			local subLbl = Instance.new("TextLabel")
			subLbl.Size = UDim2.new(1, 0, 0, 16)
			subLbl.Position = UDim2.new(0, 0, 0, 29)
			subLbl.Text = sub :: string
			applyTextLabel(subLbl, m3Font, sm, "fill")
			subLbl.TextXAlignment = Enum.TextXAlignment.Left
			subLbl.TextYAlignment = Enum.TextYAlignment.Top
			subLbl.TextTruncate = Enum.TextTruncate.AtEnd
			subLbl.Parent = col
			reg(subLbl, "TextColor3", "out")
		else
			applyTextLabel(l, m3Font, md, "fill")
			l.Size = UDim2.new(1, 0, 1, 0)
		end
		return l
	end

	--//---------------------- ASSEMBLE CTX ----------------------\\--
	local ctx: any = {
		-- window-owned (assigned by window.luau after creation)
		lib = lib,
		theme = curTheme,
		win = nil,
		gui = nil,
		popupLayer = nil,
		trackedConns = trackedConns,

		-- theming
		reg = reg,
		regDynamic = regDynamic,
		applyPalette = applyPalette,
		tintPalette = tintPalette,

		-- tracked connections
		track = track,
		onRender = onRender,
		onHeartbeat = onHeartbeat,
		onInputBegan = onInputBegan,
		onInputChanged = onInputChanged,
		onInputEnded = onInputEnded,

		-- search index
		indexElement = indexElement,

		-- card system
		beginBuildCard = beginBuildCard,
		beginCardRow = beginCardRow,
		closeBuildCard = closeBuildCard,
		nextCardItemOrder = nextCardItemOrder,
		refreshCardRowCorners = refreshCardRowCorners,
		styleGroupedSurfaces = styleGroupedSurfaces,
		tintRow = tintRow,
		fillLabelColumn = fillLabelColumn,
		CARD_CORNER = CARD_CORNER,
		CARD_CORNER_SM = CARD_CORNER_SM,
		CARD_ROW_GAP = CARD_ROW_GAP,
		CARD_ROW_PAD_X = CARD_ROW_PAD_X,
		CARD_ROW_PAD_Y = CARD_ROW_PAD_Y,

		-- fonts / typography
		m3Font = m3Font,
		fontWeight = fontWeight,
		fontRole = fontRole,
		fontBody = fontBody,
		fontEmphasis = fontEmphasis,
		fontTitle = fontTitle,
		fontDisplay = fontDisplay,
		fontLarge = fontLarge,
		fontChrome = fontChrome,
		applyTextLabel = applyTextLabel,
		textSize = textSize,
		TextSizes = Util.TextSizes,
		grid = Grid,

		-- sound
		playFeedback = Sound.playFeedback,
		playSliderTick = Sound.playSliderTick,
		playNotificationSound = Sound.playNotificationSound,
		previewNotificationSound = Sound.previewNotificationSound,

		-- config
		config = Config,

		-- config passthroughs
		MEDIA_PAGE_SIZE = Config.MediaPageSize,
		MEDIA_PAGE_COUNT = Config.MediaPageCount,
		INTRO_BRAND = Config.IntroBrand,
		INTRO_SOUND = Config.IntroSound,
	}

	-- util passthroughs (tween, corner, ripple, drag tracks, http, media, icons, format)
	for key, value in Util do
		if ctx[key] == nil then
			ctx[key] = value
		end
	end

	-- services passthroughs (TweenService, UserInputService, ...)
	for key, value in Services do
		if ctx[key] == nil then
			ctx[key] = value
		end
	end

	return ctx
end
