--!nonstrict
-- DexUI window assembler. Builds the chrome/title-bar, tab system, content areas,
-- popup layer, notifications, overlays (settings/search), edge-resize handles,
-- world-pin mode, dragging and the window lifecycle. Components are attached via
-- the shared ctx produced by core/context.luau.

local Services = require("../services")
local Config = require("../config")
local Palettes = require("../theme/palettes")
local Util = require("../core/util")
local Fonts = require("../core/fonts")
local Sound = require("../core/sound")
local SettingsStore = require("../core/settings-store")
local createContext = require("../core/context")
local playWorldIntro = require("./intro")

local componentFactories = {
	require("../components/section"),
	require("../components/divider"),
	require("../components/label"),
	require("../components/paragraph"),
	require("../components/textbox"),
	require("../components/button"),
	require("../components/switch"),
	require("../components/slider"),
	require("../components/dropdown"),
	require("../components/keybind"),
	require("../components/colorpicker"),
	require("../components/media"),
	require("../components/icons"),
	require("../components/notifications"),
	require("../components/footer"),
	require("../components/tooltip"),
	require("../components/scripts-hub"),
	require("../components/tools-hub"),
	require("../components/game-info"),
}

type Palette = { bg: Color3, fg: Color3, pri: Color3, onpri: Color3, inact: Color3, out: Color3 }
type Callback = (...any) -> ()

export type Window = {
	AddTab: (self: Window, text: string, icon: (string | number)?) -> Window,
	SelectTab: (self: Window, text: string) -> (),
	ChangePalette: (self: Window, name: string) -> (),
	ApplyTint: (self: Window, color: Color3) -> (),
	AddSection: (self: Window, text: string) -> (),
	AddDivider: (self: Window) -> (),
	AddLabel: (self: Window, text: string, icon: (string | number)?) -> { SetText: (string) -> () },
	AddParagraph: (self: Window, title: string, body: string) -> (),
	AddButton: (self: Window, text: string, callback: Callback?) -> (),
	AddSwitch: (self: Window, text: string, default: boolean?, callback: Callback?, subtitle: string?) -> (),
	AddSlider: (self: Window, text: string, min: number, max: number, default: number?, callback: Callback?) -> (),
	AddTextBox: (self: Window, label: string, callback: Callback?) -> (),
	AddDropdown: (self: Window, text: string, options: { string }, default: string?, callback: Callback?) -> (),
	AddKeybind: (self: Window, text: string, default: Enum.KeyCode?, callback: Callback?, subtitle: string?) -> (),
	AddColorPicker: (self: Window, text: string, default: Color3?, callback: Callback?, subtitle: string?) -> (),
	AddMediaBrowser: (self: Window) -> (),
	AddIconBrowser: (self: Window) -> (),
	PopulateScriptsHub: (self: Window, entries: { any }?) -> (),
	PopulateToolsHub: (self: Window, entries: { any }?) -> (),
	AddGameInfo: (self: Window) -> (),
	Notify: (self: Window, opts: { Title: string?, Content: string?, Duration: number?, Style: any? }) -> (),
	SetNotificationStyle: (self: Window, style: any?) -> (),
	PlayIntro: (self: Window, opts: { Brand: string?, OnComplete: (() -> ())? }?) -> (),
	Show: (self: Window) -> (),
	Destroy: (self: Window) -> (),
	Reload: (self: Window) -> (),
	SetReloadCallback: (self: Window, callback: () -> ()) -> (),
	SetSoundsEnabled: (self: Window, enabled: boolean) -> (),
	SetSoundVolume: (self: Window, scale: number) -> (),
	SetNotificationSoundAssetId: (self: Window, id: number) -> (),
	GetNotificationSoundAssetId: (self: Window) -> number,
	SetNotificationRandomPitch: (self: Window, enabled: boolean) -> (),
	IsNotificationRandomPitch: (self: Window) -> boolean,
	PreviewNotificationSound: (self: Window) -> (),
	PlayFeedback: (self: Window, pattern: string) -> (),
	SetFooterConfig: (self: Window, config: any?) -> (),
	SetFooterSegmentText: (self: Window, id: string, text: string) -> (),
	SetFooterSegmentVisible: (self: Window, id: string, visible: boolean) -> (),
	RefreshFooter: (self: Window) -> (),
}

type MakeUIOptions = { hub: boolean? }

local function makeUI(titleText: string?, options: MakeUIOptions?): Window
	local lib = {} :: any
	local unloaded = false
	local reloadCallback: (() -> ())? = nil
	local hubMode = options ~= nil and options.hub == true
	local appTitle = titleText or (if hubMode then "DexUI Hub" else "M3 UI Library")
	lib.HubMode = hubMode
	local confirmCloseLayer: Frame? = nil

	local theme = {}
	for k, v in Palettes.Blue do
		theme[k] = v
	end

	local ctx = createContext({
		lib = lib,
		theme = theme,
		util = Util,
		fonts = Fonts,
		sound = Sound,
		palettes = Palettes,
		services = Services,
		config = Config,
	})

	local curTheme = ctx.theme
	local reg, regDynamic = ctx.reg, ctx.regDynamic
	local tween, corner, ripple = ctx.tween, ctx.corner, ctx.ripple
	local textSize = ctx.textSize
	local fontWeight, fontEmphasis, fontTitle, fontDisplay, m3Font = ctx.fontWeight, ctx.fontEmphasis, ctx.fontTitle, ctx.fontDisplay, ctx.m3Font
	local beginCardRow, closeBuildCard, tintRow = ctx.beginCardRow, ctx.closeBuildCard, ctx.tintRow
	local playFeedback = ctx.playFeedback
	local onRender, onInputChanged, onInputEnded = ctx.onRender, ctx.onInputChanged, ctx.onInputEnded
	local STD_TWEEN = ctx.STD_TWEEN
	local isPrimaryInput, isMoveInput, isGrabInput, screenMouseLocation = ctx.isPrimaryInput, ctx.isMoveInput, ctx.isGrabInput, ctx.screenMouseLocation
	local TweenService, UserInputService, RunService = ctx.TweenService, ctx.UserInputService, ctx.RunService
	local Players, SoundService, GuiService = ctx.Players, ctx.SoundService, ctx.GuiService
	local ContextActionService, Workspace, CoreGui = ctx.ContextActionService, ctx.Workspace, ctx.CoreGui
	local trackedConns = ctx.trackedConns
	local INTRO_BRAND, INTRO_SOUND = ctx.INTRO_BRAND, ctx.INTRO_SOUND

	local savedSettings = SettingsStore.load(Config)
	local saveSettingsScheduled = false

	local function collectSettings(): { any }
		local ns = {
			assetId = Sound.getNotificationSoundAssetId(),
			randomPitch = Sound.isNotificationRandomPitch(),
			pitch = Sound.getNotificationPitch(),
		}
		local pitchMin, pitchMax = Sound.getNotificationPitchRange()
		ns.pitchMin = pitchMin
		ns.pitchMax = pitchMax

		local notificationStyle = nil
		if lib.GetNotificationStyle then
			notificationStyle = lib:GetNotificationStyle()
		end

		return {
			version = 1,
			soundsEnabled = Sound.isSoundsEnabled(),
			masterVolume = Sound.getMasterVolume(),
			accentTint = SettingsStore.colorToTable(curTheme.pri),
			notificationSound = ns,
			feedbackSound = {
				assetId = Sound.getFeedbackSoundAssetId(),
			},
			notificationStyle = notificationStyle,
		}
	end

	local function saveSettingsNow()
		SettingsStore.save(collectSettings())
	end

	local function scheduleSaveSettings()
		if saveSettingsScheduled then
			return
		end
		saveSettingsScheduled = true
		task.delay(0.35, function()
			saveSettingsScheduled = false
			saveSettingsNow()
		end)
	end

	local function applySavedSettings()
		local s = savedSettings
		if s.soundsEnabled ~= nil then
			Sound.setSoundsEnabled(s.soundsEnabled)
		end
		if type(s.masterVolume) == "number" then
			Sound.setMasterVolume(s.masterVolume)
		end
		local ns = s.notificationSound
		if type(ns) == "table" then
			if type(ns.assetId) == "number" then
				Sound.setNotificationSoundAssetId(ns.assetId)
			end
			if ns.randomPitch ~= nil then
				Sound.setNotificationRandomPitch(ns.randomPitch)
			end
			if type(ns.pitch) == "number" then
				Sound.setNotificationPitch(ns.pitch)
			end
			if type(ns.pitchMin) == "number" and type(ns.pitchMax) == "number" then
				Sound.setNotificationPitchRange(ns.pitchMin, ns.pitchMax)
			end
		end
		local fs = s.feedbackSound
		if type(fs) == "table" and type(fs.assetId) == "number" then
			Sound.setFeedbackSoundAssetId(fs.assetId)
		end
		local tint = SettingsStore.colorFromTable(s.accentTint)
		if tint then
			lib:ApplyTint(tint)
		end
		if type(s.notificationStyle) == "table" and next(s.notificationStyle) ~= nil and lib.SetNotificationStyle then
			lib:SetNotificationStyle(s.notificationStyle)
		end
	end


	-- Re-injection guard: a previous DexUI instance lives in its own VM, so its
	-- trackedConns (per-frame loops, keybind input handlers, etc.) are unreachable
	-- from here and would keep firing -- e.g. a keybind that's still "heard" after
	-- the old window was closed. We stash the active instance's unloader in the global
	-- env and call it before building a new one.
	local genv = (getgenv and getgenv()) or _G
	if type(genv.__DexUI_Unload) == "function" then
		pcall(genv.__DexUI_Unload)
	end
	genv.__DexUI_Unload = nil

	local old = CoreGui:FindFirstChild("DexUI")
	if old then
		old:Destroy()
	end

    local gui = Instance.new("ScreenGui")
    gui.Name = "DexUI"
    gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = CoreGui

	local win = Instance.new("Frame")
	win.Name = "Window"
	local finalWinSize = UDim2.new(0, 560, 0, 520)
	win.Size = finalWinSize
    win.Position = UDim2.new(0.5, -280, 0.5, -260)
    win.BorderSizePixel = 0
    win.ClipsDescendants = true
	win.Parent = gui
	reg(win, "BackgroundColor3", "bg")
	local WIN_CORNER = 16
	corner(win, WIN_CORNER)
	ctx.WindowCornerRadius = WIN_CORNER

	local function fadeInWin(duration: number?)
		local mask = Instance.new("Frame")
		mask.Name = "FadeIn"
		mask.Size = UDim2.fromScale(1, 1)
		mask.BackgroundColor3 = curTheme.bg
		mask.BackgroundTransparency = 0
		mask.BorderSizePixel = 0
		mask.ZIndex = 200
		mask.Parent = win
		corner(mask, 16)
		tween(mask, "BackgroundTransparency", 1, duration or 0.45)
		task.delay((duration or 0.45) + 0.06, function()
			mask:Destroy()
		end)
	end

	local function centerWin(size: UDim2)
		win.Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2)
	end
	centerWin(finalWinSize)

	-- Window stroke that glows in the accent tint while resizing / hovering edges.
	local winStroke = Instance.new("UIStroke")
	winStroke.Thickness = 1.5
	winStroke.Transparency = 1
	winStroke.Parent = win
	reg(winStroke, "Color", "pri")

	local mouse = Players.LocalPlayer:GetMouse()

	--//---------------------- TITLE BAR ----------------------\\--

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 50)
	titleBar.BackgroundTransparency = 1
	titleBar.Active = true
	titleBar.ZIndex = 70
	titleBar.Parent = win

	local top = Instance.new("TextLabel")
	top.Size = UDim2.new(1, -198, 0, 45)
	top.Position = UDim2.new(0, 24, 0, 6)
    top.BackgroundTransparency = 1
    top.Text = appTitle
	top.FontFace = fontTitle
	top.TextSize = textSize("lg")
    top.TextXAlignment = Enum.TextXAlignment.Left
	top.TextTruncate = Enum.TextTruncate.AtEnd
	top.ZIndex = 71
	top.Parent = titleBar
	reg(top, "TextColor3", "fg")

	-- Invisible grab zone for dragging (TextLabels don't receive input on SurfaceGui).
	local dragHandle = Instance.new("TextButton")
	dragHandle.Name = "DragHandle"
	dragHandle.Size = UDim2.new(1, -174, 1, 0)
	dragHandle.BackgroundTransparency = 1
	dragHandle.Text = ""
	dragHandle.AutoButtonColor = false
	dragHandle.ZIndex = 72
	dragHandle.Parent = titleBar

	local btnRow = Instance.new("Frame")
	btnRow.Name = "Buttons"
	btnRow.AnchorPoint = Vector2.new(1, 0)
	btnRow.Position = UDim2.new(1, -12, 0, 9)
	btnRow.Size = UDim2.new(0, 162, 0, 34)
	btnRow.BackgroundTransparency = 1
	btnRow.ZIndex = 73
	btnRow.Parent = titleBar

	local btnRowLayout = Instance.new("UIListLayout")
	btnRowLayout.FillDirection = Enum.FillDirection.Horizontal
	btnRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	btnRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	btnRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	btnRowLayout.Padding = UDim.new(0, 4)
	btnRowLayout.Parent = btnRow

	-- Material symbols spritesheet (Roblox MaterialIcons sheets).
	local chromeBtnStates: { [TextButton]: { icon: ImageLabel, hover: Color3?, active: boolean } } = {}

	local function setChromeActive(btn: TextButton, active: boolean)
		local state = chromeBtnStates[btn]
		if not state or state.active == active then
			return
		end
		state.active = active
		if active then
			btn.BackgroundColor3 = curTheme.pri
			tween(btn, "BackgroundTransparency", 0.72, 0.15)
			tween(state.icon, "ImageColor3", curTheme.pri, 0.15)
		else
			tween(btn, "BackgroundTransparency", 1, 0.15)
			tween(state.icon, "ImageColor3", state.hover or curTheme.fg, 0.15)
		end
	end

	local function chromeButton(order: number, name: string, sheet: number, rect: Vector2, hover: Color3?, cell: Vector2?): (TextButton, ImageLabel)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.new(0, 34, 0, 34)
		b.BackgroundTransparency = 1
		b.Text = ""
		b.AutoButtonColor = false
		b.LayoutOrder = order
		b.ZIndex = 72
		b.Parent = btnRow
		corner(b, 999)

		-- Ripples live in a CanvasGroup so they clip to the rounded corner (ClipsDescendants alone
		-- only clips to a rectangle and would leave square edges on the press highlight).
		local stateLayer = Instance.new("CanvasGroup")
		stateLayer.Size = UDim2.fromScale(1, 1)
		stateLayer.BackgroundTransparency = 1
		stateLayer.BorderSizePixel = 0
		stateLayer.ZIndex = 72
		stateLayer.Parent = b
		corner(stateLayer, 999)

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 20, 0, 20)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.BackgroundTransparency = 1
		icon.Image = "rbxassetid://" .. sheet
		icon.ImageRectOffset = rect
		icon.ImageRectSize = cell or Vector2.new(36, 36)
		icon.ZIndex = 73
		icon.Parent = b
		reg(icon, "ImageColor3", "fg")

		chromeBtnStates[b] = { icon = icon, hover = hover, active = false }

		b.MouseEnter:Connect(function()
			local state = chromeBtnStates[b]
			b.BackgroundColor3 = hover or curTheme.fg
			if state.active then
				tween(b, "BackgroundTransparency", 0.58, 0.15)
			else
				tween(b, "BackgroundTransparency", 0.85, 0.15)
			end
			playFeedback("hover")
			if hover and not state.active then
				tween(icon, "ImageColor3", hover, 0.15)
			end
		end)
		b.MouseLeave:Connect(function()
			local state = chromeBtnStates[b]
			if state.active then
				b.BackgroundColor3 = curTheme.pri
				tween(b, "BackgroundTransparency", 0.72, 0.15)
				tween(icon, "ImageColor3", curTheme.pri, 0.15)
			else
				tween(b, "BackgroundTransparency", 1, 0.15)
				if hover then
					tween(icon, "ImageColor3", curTheme.fg, 0.15)
				end
			end
		end)
		b.MouseButton1Down:Connect(function()
			ripple(stateLayer, hover or curTheme.fg)
			playFeedback(hover and "error" or "light")
		end)
		return b, icon
	end

	local searchBtn = chromeButton(1, "Search", 3926305904, Vector2.new(964, 324))
	local settingsBtn = chromeButton(2, "Settings", 3926307971, Vector2.new(324, 124))
	local pinBtn = chromeButton(3, "Pin", 3926305904, Vector2.new(684, 564))
	local closeBtn = chromeButton(4, "Close", 3926305904, Vector2.new(284, 4), Color3.fromRGB(255, 95, 95), Vector2.new(24, 24))

	--//---------------------- TAB BAR (vertical sidebar) ----------------------\\--

	local TITLE_BAR_H = 55
	local TAB_SIDEBAR_W = 172

	local footerDefaults = Config.Footer
	local FOOTER_H = if type(footerDefaults) == "table" and footerDefaults.Enabled ~= false
		then (footerDefaults.Height or 28)
		else 0
	local BODY_V_INSET = TITLE_BAR_H + FOOTER_H
	ctx.FooterHeight = FOOTER_H

	local tabArea = Instance.new("Frame")
	tabArea.Size = UDim2.new(0, TAB_SIDEBAR_W, 1, -BODY_V_INSET)
	tabArea.Position = UDim2.new(0, 0, 0, TITLE_BAR_H)
	tabArea.BackgroundTransparency = 1
	tabArea.ClipsDescendants = true
	tabArea.Visible = false
	tabArea.Parent = win

	local tabDivider = Instance.new("Frame")
	tabDivider.Name = "Divider"
	tabDivider.Size = UDim2.new(0, 1, 1, 0)
	tabDivider.AnchorPoint = Vector2.new(1, 0)
	tabDivider.Position = UDim2.new(1, 0, 0, 0)
	tabDivider.BorderSizePixel = 0
	tabDivider.BackgroundTransparency = 0.55
	tabDivider.Parent = tabArea
	reg(tabDivider, "BackgroundColor3", "out")

	local tabListCont = Instance.new("ScrollingFrame")
	tabListCont.Size = UDim2.new(1, 0, 1, 0)
	tabListCont.BackgroundTransparency = 1
	tabListCont.ScrollBarThickness = 0
	tabListCont.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabListCont.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabListCont.ScrollingDirection = Enum.ScrollingDirection.Y
	tabListCont.Parent = tabArea

	local dragTab = false
	local isDraggingTabAction = false
	local dragTabStartMouseY = 0
	local dragTabStartCanvasY = 0

	local function startTabDrag(input: InputObject)
		if isPrimaryInput(input) then
			dragTab = true
			isDraggingTabAction = false
			dragTabStartMouseY = screenMouseLocation().Y
			dragTabStartCanvasY = tabListCont.CanvasPosition.Y
		end
	end
	tabListCont.InputBegan:Connect(startTabDrag)

	onInputChanged(function(input)
		if dragTab and isMoveInput(input) then
			local delta = dragTabStartMouseY - screenMouseLocation().Y
			if math.abs(delta) > 5 then
				isDraggingTabAction = true
				tabListCont.CanvasPosition = Vector2.new(0, dragTabStartCanvasY + delta)
			end
		end
	end)
	onInputEnded(function(input)
		if isPrimaryInput(input) then
			dragTab = false
		end
	end)

	local tabListInner = Instance.new("Frame")
	tabListInner.Size = UDim2.new(1, 0, 0, 0)
	tabListInner.BackgroundTransparency = 1
	tabListInner.AutomaticSize = Enum.AutomaticSize.Y
	tabListInner.Parent = tabListCont

	local tPad = Instance.new("UIPadding")
	tPad.PaddingTop = UDim.new(0, 12)
	tPad.PaddingBottom = UDim.new(0, 12)
	tPad.PaddingLeft = UDim.new(0, 12)
	tPad.PaddingRight = UDim.new(0, 12)
	tPad.Parent = tabListInner

	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Vertical
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabList.Padding = UDim.new(0, 6)
	tabList.Parent = tabListInner

	-- Highlight sits outside the UIListLayout so manual position tweens aren't overwritten.
	local tabHighlight = Instance.new("Frame")
	tabHighlight.Name = "TabHighlight"
	tabHighlight.BackgroundColor3 = curTheme.pri
	tabHighlight.BorderSizePixel = 0
	tabHighlight.Size = UDim2.fromOffset(0, 32)
	tabHighlight.ZIndex = 1
	tabHighlight.Parent = tabListCont
	corner(tabHighlight, 999)
	reg(tabHighlight, "BackgroundColor3", "pri")

	tabListInner.ZIndex = 2

	local function moveTabHighlight(btn: TextButton, dur: number?)
		task.spawn(function()
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()
			-- Canvas-space coords: relative to tabListInner (canvas origin), not the viewport.
			local relX = btn.AbsolutePosition.X - tabListInner.AbsolutePosition.X
			local relY = btn.AbsolutePosition.Y - tabListInner.AbsolutePosition.Y
			local d = dur or 0.35
			tween(tabHighlight, "Position", UDim2.fromOffset(relX, relY), d)
			tween(tabHighlight, "Size", UDim2.fromOffset(btn.AbsoluteSize.X, btn.AbsoluteSize.Y), d)
		end)
	end

	local function applyTabVisual(tData: any, active: boolean, dur: number?)
		local d = dur or 0.3
		tData.active = active
		if active then
			moveTabHighlight(tData.btn, d)
			tween(tData.textLabel, "TextColor3", curTheme.onpri, d)
			if tData.icon then
				tween(tData.icon, "ImageColor3", curTheme.onpri, d)
			end
		else
			tween(tData.textLabel, "TextColor3", curTheme.out, d)
			if tData.icon then
				tween(tData.icon, "ImageColor3", curTheme.out, d)
			end
		end
	end

	--//------------------- CONTENT AREAS -------------------\\--

	local function styleContainer(c: ScrollingFrame)
		c.BackgroundTransparency = 1
		c.ScrollBarThickness = 0
		c.CanvasSize = UDim2.new(0, 0, 0, 0)
		c.AutomaticCanvasSize = Enum.AutomaticSize.Y
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 20)
		pad.PaddingRight = UDim.new(0, 20)
		pad.PaddingBottom = UDim.new(0, 24)
		pad.PaddingTop = UDim.new(0, 16)
		pad.Parent = c
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 16)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = c
	end

	local defaultCont = Instance.new("ScrollingFrame")
	defaultCont.Size = UDim2.new(1, 0, 1, -BODY_V_INSET)
	defaultCont.Position = UDim2.new(0, 0, 0, TITLE_BAR_H)
	defaultCont.Parent = win
	styleContainer(defaultCont)

	local contClip = Instance.new("Frame")
	contClip.Size = UDim2.new(1, -TAB_SIDEBAR_W, 1, -BODY_V_INSET)
	contClip.Position = UDim2.new(0, TAB_SIDEBAR_W, 0, TITLE_BAR_H)
	contClip.BackgroundTransparency = 1
	contClip.BorderSizePixel = 0
	contClip.ClipsDescendants = true
	contClip.Visible = false
	contClip.Parent = win
	corner(contClip, 16)

	-- Floating popup layer: dropdowns/menus render here so they overlay other
	-- content instead of expanding their row's height. Sits above content and
	-- tabs, below the title bar chrome.
	local popupLayer = Instance.new("Frame")
	popupLayer.Name = "PopupLayer"
	popupLayer.Size = UDim2.new(1, 0, 1, 0)
	popupLayer.BackgroundTransparency = 1
	popupLayer.BorderSizePixel = 0
	popupLayer.ClipsDescendants = false
	popupLayer.ZIndex = 90
	popupLayer.Parent = win
	ctx.win = win
	ctx.gui = gui
	ctx.popupLayer = popupLayer

    lib.Tabs = {}
    lib.TabContainers = {}
    lib.ActiveTabIndex = 0
    lib.CurrentBuildContainer = defaultCont
	lib.CurrentBuildTabIndex = 0
    lib.UseTabs = false


	--//============================================================\\--
	--||                      TAB MANAGEMENT                      ||--
	--\\============================================================//--

	function lib:SelectTab(txt: string)
        local targetIdx = 1
        for i, tData in ipairs(lib.Tabs) do
			if tData.label == txt then
				targetIdx = i
				break
			end
		end
		if targetIdx == lib.ActiveTabIndex then
			return
		end
		playFeedback("selection")
        
        local dir = (targetIdx > lib.ActiveTabIndex) and 1 or -1
		if lib.ActiveTabIndex == 0 then
			dir = 0
		end
        
        local oldCont = (lib.ActiveTabIndex > 0) and lib.TabContainers[lib.ActiveTabIndex] or defaultCont
        local newCont = lib.TabContainers[targetIdx]
		local tabDur = lib.ActiveTabIndex == 0 and 0 or 0.35

        for i, tData in ipairs(lib.Tabs) do
			applyTabVisual(tData, i == targetIdx, tabDur)
        end

        if oldCont and dir ~= 0 and oldCont ~= defaultCont then
            newCont.Position = UDim2.new(0, 0, dir, dir * 40)
            newCont.Visible = true
			tween(oldCont, "Position", UDim2.new(0, 0, -dir, -dir * 40), 0.4)
			tween(newCont, "Position", UDim2.new(0, 0, 0, 0), 0.4)
            local savedOld = oldCont
            task.delay(0.4, function() 
				if lib.TabContainers[lib.ActiveTabIndex] ~= savedOld then
					savedOld.Visible = false
				end
            end)
        else
            newCont.Position = UDim2.new(0, 0, 0, 0)
            newCont.Visible = true
			if oldCont and oldCont ~= defaultCont then
				oldCont.Visible = false
			end
        end
        
        lib.ActiveTabIndex = targetIdx
    end

	function lib:AddTab(txt: string, icon: (string | number)?)
        if not lib.UseTabs then
            lib.UseTabs = true
            tabArea.Visible = true
            contClip.Visible = true
            defaultCont.Visible = false
        end

		-- Pill tab: transparent hit target; the sliding tabHighlight carries the fill.
		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Size = UDim2.new(1, 0, 0, 36)
		btn.ZIndex = 2
		btn.Parent = tabListInner

		local uip = Instance.new("UIPadding")
		uip.PaddingLeft = UDim.new(0, 12)
		uip.PaddingRight = UDim.new(0, 12)
		uip.Parent = btn

		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.HorizontalAlignment = Enum.HorizontalAlignment.Left
		row.SortOrder = Enum.SortOrder.LayoutOrder
		row.Padding = UDim.new(0, 8)
		row.Parent = btn

		local iconObj: ImageLabel? = nil
		if icon then
			iconObj = Instance.new("ImageLabel")
			iconObj.Size = UDim2.new(0, 18, 0, 18)
			iconObj.BackgroundTransparency = 1
			iconObj.Image = typeof(icon) == "number" and ("rbxassetid://" .. icon) or (icon :: string)
			iconObj.ImageColor3 = curTheme.out
			iconObj.LayoutOrder = 0
			iconObj.ZIndex = 3
			iconObj.Parent = btn
		end

		local label = Instance.new("TextLabel")
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = txt
		label.FontFace = m3Font
		label.TextSize = textSize("md")
		label.TextColor3 = curTheme.out
		label.LayoutOrder = 1
		label.ZIndex = 3
		label.Parent = btn

		local c = Instance.new("ScrollingFrame")
		c.Size = UDim2.new(1, 0, 1, 0)
        c.Visible = false
		c.Parent = contClip
		styleContainer(c)

		local tData = { btn = btn, icon = iconObj, textLabel = label, label = txt, active = false }
		table.insert(lib.Tabs, tData)
        table.insert(lib.TabContainers, c)
        lib.CurrentBuildContainer = c 
		lib.CurrentBuildTabIndex = #lib.Tabs
		closeBuildCard()

		regDynamic(function(theme, dur)
			if tData.active then
				tween(label, "TextColor3", theme.onpri, dur)
				if iconObj then
					tween(iconObj, "ImageColor3", theme.onpri, dur)
				end
			else
				tween(label, "TextColor3", theme.out, dur)
				if iconObj then
					tween(iconObj, "ImageColor3", theme.out, dur)
				end
			end
		end)

		btn.InputBegan:Connect(startTabDrag)
        btn.MouseButton1Click:Connect(function() 
            if not isDraggingTabAction then
                lib:SelectTab(txt) 
            end
        end)

		if #lib.Tabs == 1 then
			lib:SelectTab(txt)
		end
	end

	for _, __factory in componentFactories do
		__factory(ctx)
	end
	applySavedSettings()

	local _setNotificationStyle = lib.SetNotificationStyle
	function lib:SetNotificationStyle(style: any)
		_setNotificationStyle(style)
		scheduleSaveSettings()
	end
	--//============================================================\\--
	--||                    LAYOUT COMPONENTS                     ||--
	--\\============================================================//--

	--//============================================================\\--
	--||                       TEXT BOX                           ||--
	--\\============================================================//--

	--//============================================================\\--
	--||                        BUTTON                            ||--
	--\\============================================================//--

	--//============================================================\\--
	--||                        SWITCH                            ||--
	--\\============================================================//--

	--//============================================================\\--
	--||                        SLIDER                            ||--
	--\\============================================================//--

	--//============================================================\\--
	--||                       DROPDOWN                           ||--
	--\\============================================================//--

	--//============================================================\\--
	--||                        KEYBIND                           ||--
	--\\============================================================//--

	--//============================================================\\--
	--||                      COLOR PICKER                        ||--
	--\\============================================================//--

	--//============================================================\\--
	--||                   MEDIA (Creator Store)                  ||--
	--\\============================================================//--


	--//============================================================\\--
	--||                   ICON BROWSER (Material Icons)          ||--
	--\\============================================================//--

	--//============================================================\\--
	--||              TITLE-BAR OVERLAYS (SEARCH / SETTINGS)      ||--
	--\\============================================================//--

	-- A CanvasGroup wraps a scrolling content frame so GroupTransparency fades the
	-- background AND every child together (otherwise only the bg would fade).
	local function makeOverlay(): (CanvasGroup, ScrollingFrame)
		local group = Instance.new("CanvasGroup")
		group.Size = UDim2.new(1, 0, 1, -50)
		group.Position = UDim2.new(0, 0, 0, 50)
		group.GroupTransparency = 1
		group.BorderSizePixel = 0
		group.Visible = false
		group.ZIndex = 80
		group.Parent = win
		reg(group, "BackgroundColor3", "bg")
		corner(group, 16)

		local o = Instance.new("ScrollingFrame")
		o.Size = UDim2.new(1, 0, 1, 0)
		o.BackgroundTransparency = 1
		o.BorderSizePixel = 0
		o.ScrollBarThickness = 0
		o.CanvasSize = UDim2.new(0, 0, 0, 0)
		o.AutomaticCanvasSize = Enum.AutomaticSize.Y
		o.Parent = group
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 24)
		pad.PaddingRight = UDim.new(0, 24)
		pad.PaddingTop = UDim.new(0, 16)
		pad.PaddingBottom = UDim.new(0, 16)
		pad.Parent = o
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = o
		return group, o
	end

	local activeOverlay: CanvasGroup? = nil
	local function hideOverlay(group: CanvasGroup)
		if activeOverlay == group then
			activeOverlay = nil
		end
		if group == searchOverlay then
			setChromeActive(searchBtn, false)
		elseif group == settingsOverlay then
			setChromeActive(settingsBtn, false)
		end
		tween(group, "GroupTransparency", 1, 0.22)
		tween(group, "Position", UDim2.new(0, 0, 0, 62), 0.22)
		task.delay(0.24, function()
			if activeOverlay ~= group then
				group.Visible = false
			end
		end)
	end
	local function showOverlay(group: CanvasGroup)
		if activeOverlay and activeOverlay ~= group then
			hideOverlay(activeOverlay)
		end
		activeOverlay = group
		if group == searchOverlay then
			setChromeActive(searchBtn, true)
		elseif group == settingsOverlay then
			setChromeActive(settingsBtn, true)
		end
		group.Visible = true
		group.Position = UDim2.new(0, 0, 0, 62)
		group.GroupTransparency = 1
		tween(group, "Position", UDim2.new(0, 0, 0, 50), 0.3)
		tween(group, "GroupTransparency", 0, 0.3)
	end

	local function dismissConfirmClose()
		if confirmCloseLayer then
			confirmCloseLayer:Destroy()
			confirmCloseLayer = nil
		end
	end

	local function makeDialogButton(
		parent: Instance,
		label: string,
		order: number,
		filled: boolean,
		onClick: () -> ()
	): TextButton
		local b = Instance.new("TextButton")
		b.Name = label
		b.Size = UDim2.new(0, 96, 1, 0)
		b.BackgroundTransparency = filled and 0 or 1
		b.AutoButtonColor = false
		b.Text = ""
		b.LayoutOrder = order
		b.ZIndex = 103
		b.Parent = parent
		corner(b, 999)
		if filled then
			reg(b, "BackgroundColor3", "pri")
		else
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1
			stroke.Parent = b
			reg(stroke, "Color", "out")
		end

		local txl = Instance.new("TextLabel")
		txl.Size = UDim2.fromScale(1, 1)
		txl.BackgroundTransparency = 1
		txl.Text = label
		txl.FontFace = fontEmphasis
		txl.TextSize = textSize("md")
		txl.ZIndex = 104
		txl.Parent = b
		if filled then
			reg(txl, "TextColor3", "onpri")
		else
			reg(txl, "TextColor3", "fg")
		end

		b.MouseEnter:Connect(function()
			playFeedback("hover")
			if filled then
				tween(b, "BackgroundColor3", curTheme.fg, 0.15)
			else
				tween(b, "BackgroundTransparency", 0.92, 0.15)
				b.BackgroundColor3 = curTheme.out
			end
		end)
		b.MouseLeave:Connect(function()
			if filled then
				tween(b, "BackgroundColor3", curTheme.pri, 0.15)
			else
				tween(b, "BackgroundTransparency", 1, 0.15)
			end
		end)
		b.MouseButton1Click:Connect(function()
			ripple(b, filled and curTheme.onpri or curTheme.pri)
			playFeedback(filled and "success" or "selection")
			onClick()
		end)
		return b
	end

	local function showConfirmClose()
		if confirmCloseLayer or unloaded then
			return
		end
		if activeOverlay then
			hideOverlay(activeOverlay)
		end

		local layer = Instance.new("Frame")
		layer.Name = "ConfirmClose"
		layer.Size = UDim2.fromScale(1, 1)
		layer.BackgroundColor3 = Color3.new(0, 0, 0)
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.ZIndex = 100
		layer.Parent = gui
		confirmCloseLayer = layer
		tween(layer, "BackgroundTransparency", 0.45, 0.2)

		local DIALOG_W = 420
		local DIALOG_H = 196
		local CONFIRM_TITLE_H = 50
		local BUTTON_H = 40

		local dialog = Instance.new("Frame")
		dialog.Name = "Dialog"
		dialog.Size = UDim2.new(0, DIALOG_W, 0, DIALOG_H)
		dialog.AnchorPoint = Vector2.new(0.5, 0.5)
		dialog.Position = UDim2.fromScale(0.5, 0.5)
		dialog.BorderSizePixel = 0
		dialog.ClipsDescendants = true
		dialog.ZIndex = 101
		dialog.Parent = layer
		reg(dialog, "BackgroundColor3", "bg")
		corner(dialog, 16)

		local dialogStroke = Instance.new("UIStroke")
		dialogStroke.Thickness = 1.5
		dialogStroke.Transparency = 0.35
		dialogStroke.Parent = dialog
		reg(dialogStroke, "Color", "out")

		local confirmTitleBar = Instance.new("Frame")
		confirmTitleBar.Name = "TitleBar"
		confirmTitleBar.Size = UDim2.new(1, 0, 0, CONFIRM_TITLE_H)
		confirmTitleBar.BackgroundTransparency = 1
		confirmTitleBar.ZIndex = 102
		confirmTitleBar.Parent = dialog

		local confirmTitle = Instance.new("TextLabel")
		confirmTitle.Size = UDim2.new(1, -48, 1, 0)
		confirmTitle.Position = UDim2.new(0, 24, 0, 0)
		confirmTitle.BackgroundTransparency = 1
		confirmTitle.Text = "Confirm Close."
		confirmTitle.FontFace = fontTitle
		confirmTitle.TextSize = textSize("lg")
		confirmTitle.TextXAlignment = Enum.TextXAlignment.Left
		confirmTitle.TextYAlignment = Enum.TextYAlignment.Center
		confirmTitle.ZIndex = 103
		confirmTitle.Parent = confirmTitleBar
		reg(confirmTitle, "TextColor3", "fg")

		local body = Instance.new("TextLabel")
		body.Size = UDim2.new(1, -48, 0, DIALOG_H - CONFIRM_TITLE_H - BUTTON_H - 40)
		body.Position = UDim2.new(0, 24, 0, CONFIRM_TITLE_H + 8)
		body.BackgroundTransparency = 1
		body.Text = "Are you sure you want to quit " .. appTitle .. "?"
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.FontFace = m3Font
		body.TextSize = textSize("md")
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.ZIndex = 102
		body.Parent = dialog
		reg(body, "TextColor3", "fg")

		local btnArea = Instance.new("Frame")
		btnArea.Size = UDim2.new(1, -48, 0, BUTTON_H)
		btnArea.AnchorPoint = Vector2.new(1, 1)
		btnArea.Position = UDim2.new(1, -24, 1, -20)
		btnArea.BackgroundTransparency = 1
		btnArea.ZIndex = 102
		btnArea.Parent = dialog

		local btnLayout = Instance.new("UIListLayout")
		btnLayout.FillDirection = Enum.FillDirection.Horizontal
		btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		btnLayout.Padding = UDim.new(0, 8)
		btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
		btnLayout.Parent = btnArea

		makeDialogButton(btnArea, "Cancel", 1, false, dismissConfirmClose)
		makeDialogButton(btnArea, "OK", 2, true, function()
			dismissConfirmClose()
			lib:Destroy()
		end)
	end

	-- Section heading used above each grouped card in the overlays.
	local function addOverlayHeading(scroll: Instance, text: string, order: number): TextLabel
		local h = Instance.new("TextLabel")
		h.Size = UDim2.new(1, 0, 0, 20)
		h.BackgroundTransparency = 1
		h.Text = text
		h.FontFace = fontEmphasis
		h.TextSize = textSize("sm")
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.LayoutOrder = order
		h.ZIndex = 81
		h.Parent = scroll
		reg(h, "TextColor3", "pri")
		return h
	end

	-- Temporarily redirect the card-build system at `scroll` so the overlays
	-- reuse the exact same grouped-card layout (mixed corner radii) as tabs.
	local function buildOverlayGroup(scroll: Instance, order: number, build: () -> ()): Frame?
		local savedContainer = lib.CurrentBuildContainer
		local savedInner = lib.CurrentBuildCardInner
		local savedRows = lib.CurrentBuildCardRows
		local savedCount = lib.CardRowCount
		local savedItemOrder = lib.CardItemOrder

		lib.CurrentBuildContainer = scroll
		lib.CurrentBuildCardInner = nil
		lib.CurrentBuildCardRows = nil
		lib.CardRowCount = 0
		lib.CardItemOrder = 0

		build()
		local group = lib.CurrentBuildCardInner
		closeBuildCard()
		if group then
			group.LayoutOrder = order
		end

		lib.CurrentBuildContainer = savedContainer
		lib.CurrentBuildCardInner = savedInner
		lib.CurrentBuildCardRows = savedRows
		lib.CardRowCount = savedCount
		lib.CardItemOrder = savedItemOrder
		return group
	end

	--//------------------ SETTINGS OVERLAY ------------------\\--

	local settingsOverlay, settingsScroll = makeOverlay()

	addOverlayHeading(settingsScroll, "Appearance", 0)

	-- A single tint picker replaces the old fixed palette list: pick any colour
	-- and the whole interface re-themes around it.
	local tintActive = false
	buildOverlayGroup(settingsScroll, 1, function()
		lib:AddColorPicker("Accent Tint", curTheme.pri, function(color)
			-- Ignore the picker's initial build-time callback so we don't retint
			-- away from the default palette on load.
			if tintActive then
				lib:ApplyTint(color)
				scheduleSaveSettings()
			end
		end, "Pick any colour to retint the interface")
	end)
	tintActive = true

	--//-------------- SOUND FEEDBACK TOGGLE ----------------\\--

	addOverlayHeading(settingsScroll, "Feedback", 2)

	local soundTrk: Frame = nil :: any
	local soundThm: Frame = nil :: any
	local function refreshSoundToggle()
		tween(soundTrk, "BackgroundColor3", Sound.isSoundsEnabled() and curTheme.pri or curTheme.inact, 0.3)
		TweenService:Create(soundThm, STD_TWEEN, {
			Size = Sound.isSoundsEnabled() and UDim2.new(0, 24, 0, 24) or UDim2.new(0, 16, 0, 16),
			Position = Sound.isSoundsEnabled() and UDim2.new(0, 36, 0.5, 0) or UDim2.new(0, 16, 0.5, 0),
			BackgroundColor3 = Sound.isSoundsEnabled() and curTheme.onpri or curTheme.out,
		}):Play()
	end

	buildOverlayGroup(settingsScroll, 3, function()
		local content = beginCardRow(44, false)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -80, 1, 0)
		lbl.Position = UDim2.new(0, 0, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Interface Sounds"
		lbl.FontFace = m3Font
		lbl.TextSize = textSize("md")
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.ZIndex = 2
		lbl.Parent = content
		reg(lbl, "TextColor3", "fg")

		soundTrk = Instance.new("Frame")
		soundTrk.Size = UDim2.new(0, 52, 0, 32)
		soundTrk.AnchorPoint = Vector2.new(1, 0.5)
		soundTrk.Position = UDim2.new(1, 0, 0.5, 0)
		soundTrk.BackgroundColor3 = Sound.isSoundsEnabled() and curTheme.pri or curTheme.inact
		soundTrk.ZIndex = 2
		soundTrk.Parent = content
		corner(soundTrk, 999)

		soundThm = Instance.new("Frame")
		soundThm.AnchorPoint = Vector2.new(0.5, 0.5)
		soundThm.Size = Sound.isSoundsEnabled() and UDim2.new(0, 24, 0, 24) or UDim2.new(0, 16, 0, 16)
		soundThm.Position = Sound.isSoundsEnabled() and UDim2.new(0, 36, 0.5, 0) or UDim2.new(0, 16, 0.5, 0)
		soundThm.BackgroundColor3 = Sound.isSoundsEnabled() and curTheme.onpri or curTheme.out
		soundThm.ZIndex = 3
		soundThm.Parent = soundTrk
		corner(soundThm, 999)

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.ZIndex = 4
		btn.Parent = content
		btn.MouseButton1Click:Connect(function()
			Sound.setSoundsEnabled(not Sound.isSoundsEnabled())
			refreshSoundToggle()
			playFeedback(Sound.isSoundsEnabled() and "toggleOn" or "toggleOff") -- the "off" tick is the last sound you hear
			scheduleSaveSettings()
		end)
	end)

	regDynamic(function(theme, dur)
		tween(soundTrk, "BackgroundColor3", Sound.isSoundsEnabled() and theme.pri or theme.inact, dur)
		tween(soundThm, "BackgroundColor3", Sound.isSoundsEnabled() and theme.onpri or theme.out, dur)
		for btn, state in chromeBtnStates do
			if state.active then
				if dur > 0 then
					tween(btn, "BackgroundColor3", theme.pri, dur)
					tween(state.icon, "ImageColor3", theme.pri, dur)
				else
					btn.BackgroundColor3 = theme.pri
					state.icon.ImageColor3 = theme.pri
				end
			end
		end
	end)

	local function feedbackIdBoxText(): string
		local id = Sound.getFeedbackSoundAssetId()
		return if id > 0 then tostring(id) else ""
	end

	local function applyFeedbackIdFromBox(text: string): string
		local id = Sound.normalizeAssetId(text)
		if id then
			Sound.setFeedbackSoundAssetId(id)
			return tostring(id)
		end
		if text == "" or text == "0" then
			Sound.setFeedbackSoundAssetId(0)
			return ""
		end
		return feedbackIdBoxText()
	end

	local function addSoundAssetIdRow(
		order: number,
		title: string,
		placeholder: string,
		initialText: string,
		applyId: (string) -> string,
		preview: () -> (),
		afterRow: (() -> ())?
	)
		buildOverlayGroup(settingsScroll, order, function()
			local content = beginCardRow(56, false)

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -108, 0, 20)
			lbl.BackgroundTransparency = 1
			lbl.Text = title
			lbl.FontFace = m3Font
			lbl.TextSize = textSize("sm")
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.ZIndex = 2
			lbl.Parent = content
			reg(lbl, "TextColor3", "out")

			local idBox = Instance.new("TextBox")
			idBox.Size = UDim2.new(1, -108, 0, 24)
			idBox.Position = UDim2.new(0, 0, 0, 26)
			idBox.BackgroundTransparency = 1
			idBox.Text = initialText
			idBox.PlaceholderText = placeholder
			idBox.FontFace = m3Font
			idBox.TextSize = textSize("md")
			idBox.TextXAlignment = Enum.TextXAlignment.Left
			idBox.ClearTextOnFocus = false
			idBox.ZIndex = 2
			idBox.Parent = content
			reg(idBox, "TextColor3", "fg")
			reg(idBox, "PlaceholderColor3", "out")

			local playBtn = Instance.new("TextButton")
			playBtn.Name = "Preview"
			playBtn.Size = UDim2.new(0, 40, 0, 40)
			playBtn.AnchorPoint = Vector2.new(1, 0.5)
			playBtn.Position = UDim2.new(1, 0, 0.5, 0)
			playBtn.AutoButtonColor = false
			playBtn.Text = ""
			playBtn.ZIndex = 3
			playBtn.Parent = content
			reg(playBtn, "BackgroundColor3", "pri")
			corner(playBtn, 999)

			local playIcon = Instance.new("ImageLabel")
			playIcon.Size = UDim2.new(0, 18, 0, 18)
			playIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			playIcon.Position = UDim2.new(0.5, 1, 0.5, 0)
			playIcon.BackgroundTransparency = 1
			playIcon.Image = "rbxassetid://6026663699"
			playIcon.ZIndex = 4
			playIcon.Parent = playBtn
			reg(playIcon, "ImageColor3", "onpri")

			playBtn.MouseEnter:Connect(function()
				tween(playBtn, "BackgroundColor3", curTheme.fg, 0.15)
			end)
			playBtn.MouseLeave:Connect(function()
				tween(playBtn, "BackgroundColor3", curTheme.pri, 0.15)
			end)
			playBtn.MouseButton1Click:Connect(function()
				idBox.Text = applyId(idBox.Text)
				ripple(playBtn, curTheme.onpri)
				preview()
				scheduleSaveSettings()
			end)

			idBox.FocusLost:Connect(function()
				idBox.Text = applyId(idBox.Text)
				scheduleSaveSettings()
			end)

			if afterRow then
				afterRow()
			end
		end)
	end

	addSoundAssetIdRow(
		4,
		"Hover / Click Sound ID",
		"Default UI click (empty)",
		feedbackIdBoxText(),
		applyFeedbackIdFromBox,
		function()
			Sound.previewFeedbackSound()
		end
	)

	addSoundAssetIdRow(
		5,
		"Notification Sound ID",
		"Roblox asset ID",
		tostring(Sound.getNotificationSoundAssetId()),
		function(text)
			local id = Sound.normalizeAssetId(text)
			if id then
				Sound.setNotificationSoundAssetId(id)
				return tostring(id)
			end
			return tostring(Sound.getNotificationSoundAssetId())
		end,
		function()
			Sound.previewNotificationSound()
		end,
		function()
			lib:AddSwitch("Random Notification Pitch", Sound.isNotificationRandomPitch(), function(on)
				Sound.setNotificationRandomPitch(on)
				scheduleSaveSettings()
			end, "Vary playback speed on each toast")
		end
	)

	--//-------------- INTERFACE ACTIONS ----------------\\--

	addOverlayHeading(settingsScroll, "Interface", 6)

	local function addSettingsAction(label: string, destructive: boolean?, onClick: () -> ())
		local content = beginCardRow(44, false)
		local surface = content.Parent.Parent :: Frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.FontFace = m3Font
		lbl.TextSize = textSize("md")
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.ZIndex = 2
		lbl.Parent = content
		if destructive then
			lbl.TextColor3 = Color3.fromRGB(255, 180, 168)
		else
			reg(lbl, "TextColor3", "fg")
		end

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.ZIndex = 3
		btn.Parent = content

		btn.MouseEnter:Connect(function()
			playFeedback("hover")
			tintRow(surface, destructive and Color3.fromRGB(80, 40, 38) or curTheme.out, 0.15)
		end)
		btn.MouseLeave:Connect(function()
			tintRow(surface, curTheme.inact, 0.15)
		end)
		btn.MouseButton1Click:Connect(function()
			ripple(surface, destructive and Color3.fromRGB(255, 180, 168) or curTheme.pri, UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
			playFeedback(destructive and "warning" or "selection")
			onClick()
		end)
	end

	buildOverlayGroup(settingsScroll, 7, function()
		addSettingsAction("Reload UI", false, function()
			hideOverlay(settingsOverlay)
			lib:Reload()
		end)
		addSettingsAction("Quit", true, function()
			hideOverlay(settingsOverlay)
			showConfirmClose()
		end)
	end)

	--//------------------- SEARCH OVERLAY -------------------\\--

	local searchOverlay, searchScroll = makeOverlay()

	local fieldFrame = Instance.new("Frame")
	fieldFrame.Size = UDim2.new(1, 0, 0, 46)
	fieldFrame.BorderSizePixel = 0
	fieldFrame.LayoutOrder = 0
	fieldFrame.ZIndex = 81
	fieldFrame.Parent = searchScroll
	reg(fieldFrame, "BackgroundColor3", "inact")
	corner(fieldFrame, 999)

	local searchIcon = Instance.new("ImageLabel")
	searchIcon.Size = UDim2.new(0, 20, 0, 20)
	searchIcon.Position = UDim2.new(0, 16, 0.5, 0)
	searchIcon.AnchorPoint = Vector2.new(0, 0.5)
	searchIcon.BackgroundTransparency = 1
	searchIcon.Image = "rbxassetid://3926305904"
	searchIcon.ImageRectOffset = Vector2.new(964, 324)
	searchIcon.ImageRectSize = Vector2.new(36, 36)
	searchIcon.ZIndex = 82
	searchIcon.Parent = fieldFrame
	reg(searchIcon, "ImageColor3", "out")

	local searchField = Instance.new("TextBox")
	searchField.Size = UDim2.new(1, -56, 1, 0)
	searchField.Position = UDim2.new(0, 46, 0, 0)
	searchField.BackgroundTransparency = 1
	searchField.Text = ""
	searchField.PlaceholderText = "Search all tabs..."
	searchField.FontFace = m3Font
	searchField.TextSize = textSize("md")
	searchField.TextXAlignment = Enum.TextXAlignment.Left
	searchField.ClearTextOnFocus = false
	searchField.ZIndex = 82
	searchField.Parent = fieldFrame
	reg(searchField, "TextColor3", "fg")
	reg(searchField, "PlaceholderColor3", "out")

	local resultsHolder = Instance.new("Frame")
	resultsHolder.Size = UDim2.new(1, 0, 0, 0)
	resultsHolder.AutomaticSize = Enum.AutomaticSize.Y
	resultsHolder.BackgroundTransparency = 1
	resultsHolder.LayoutOrder = 1
	resultsHolder.ZIndex = 81
	resultsHolder.Parent = searchScroll
	local resultsLayout = Instance.new("UIListLayout")
	resultsLayout.Padding = UDim.new(0, 8)
	resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resultsLayout.Parent = resultsHolder

	local function jumpToEntry(entry)
		local cont = entry.container :: ScrollingFrame
		task.spawn(function()
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()
			local y = entry.instance.AbsolutePosition.Y - cont.AbsolutePosition.Y + cont.CanvasPosition.Y - 12
			tween(cont, "CanvasPosition", Vector2.new(0, math.max(0, y)), 0.4)
			local hl = Instance.new("UIStroke")
			hl.Color = curTheme.pri
			hl.Thickness = 2
			hl.Parent = entry.instance
			task.wait(0.25)
			tween(hl, "Transparency", 1, 1.1)
			task.wait(1.2)
			hl:Destroy()
		end)
	end

	local function buildResults(query: string)
		for _, ch in resultsHolder:GetChildren() do
			if not ch:IsA("UIListLayout") then
				ch:Destroy()
			end
		end
		local q = string.lower(query)

		local matches: { any } = {}
		for _, entry in lib.SearchIndex do
			if q == "" or string.find(string.lower(entry.name), q, 1, true) then
				table.insert(matches, entry)
			end
		end

		if #matches == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 40)
			empty.BackgroundTransparency = 1
			empty.Text = "No matching elements"
			empty.FontFace = m3Font
			empty.TextSize = textSize("md")
			empty.ZIndex = 82
			empty.TextColor3 = curTheme.out
			empty.Parent = resultsHolder
			return
		end

		buildOverlayGroup(resultsHolder, 1, function()
			for _, entry in matches do
				local tabName = (entry.tabIndex > 0 and lib.Tabs[entry.tabIndex])
						and lib.Tabs[entry.tabIndex].label
					or "Main"

				local content = beginCardRow(40, false)
				local surface = content.Parent.Parent :: Frame

				local nameL = Instance.new("TextLabel")
				nameL.Size = UDim2.new(1, -86, 1, 0)
				nameL.Position = UDim2.new(0, 0, 0, 0)
				nameL.BackgroundTransparency = 1
				nameL.Text = entry.name
				nameL.FontFace = m3Font
				nameL.TextSize = textSize("md")
				nameL.TextXAlignment = Enum.TextXAlignment.Left
				nameL.TextTruncate = Enum.TextTruncate.AtEnd
				nameL.ZIndex = 2
				nameL.Parent = content
				reg(nameL, "TextColor3", "fg")

				local tabL = Instance.new("TextLabel")
				tabL.Size = UDim2.new(0, 80, 1, 0)
				tabL.AnchorPoint = Vector2.new(1, 0)
				tabL.Position = UDim2.new(1, 0, 0, 0)
				tabL.BackgroundTransparency = 1
				tabL.Text = tabName
				tabL.FontFace = m3Font
				tabL.TextSize = textSize("sm")
				tabL.TextXAlignment = Enum.TextXAlignment.Right
				tabL.ZIndex = 2
				tabL.Parent = content
				reg(tabL, "TextColor3", "out")

				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 1, 0)
				btn.BackgroundTransparency = 1
				btn.AutoButtonColor = false
				btn.Text = ""
				btn.ZIndex = 3
				btn.Parent = content

				btn.MouseEnter:Connect(function()
					tintRow(surface, curTheme.out, 0.15)
				end)
				btn.MouseLeave:Connect(function()
					tintRow(surface, curTheme.inact, 0.15)
				end)
				btn.MouseButton1Click:Connect(function()
					hideOverlay(searchOverlay)
					if entry.tabIndex > 0 then
						lib:SelectTab(tabName)
					end
					jumpToEntry(entry)
				end)
			end
		end)
	end

	searchField:GetPropertyChangedSignal("Text"):Connect(function()
		buildResults(searchField.Text)
	end)

	--//-------------------- BUTTON WIRING -------------------\\--
	-- unloadUI is defined after world-pin setup (see below).

	searchBtn.MouseButton1Click:Connect(function()
		if activeOverlay == searchOverlay then
			hideOverlay(searchOverlay)
		else
			showOverlay(searchOverlay)
			buildResults("")
			task.defer(function()
				searchField:CaptureFocus()
			end)
		end
	end)
	settingsBtn.MouseButton1Click:Connect(function()
		if activeOverlay == settingsOverlay then
			hideOverlay(settingsOverlay)
		else
			showOverlay(settingsOverlay)
		end
	end)
	-- closeBtn wired after unloadUI is defined below.

	local worldPin = require("./world-pin")({
		win = win,
		gui = gui,
		lib = lib,
		dragHandle = dragHandle,
		pinBtn = pinBtn,
		tabListCont = tabListCont,
		setChromeActive = setChromeActive,
		moveTabHighlight = moveTabHighlight,
		TAB_SIDEBAR_W = TAB_SIDEBAR_W,
		corner = corner,
		reg = reg,
		regDynamic = regDynamic,
		tween = tween,
		playFeedback = playFeedback,
		onInputChanged = onInputChanged,
		onInputEnded = onInputEnded,
		onRender = onRender,
		isPrimaryInput = isPrimaryInput,
		isMoveInput = isMoveInput,
		isGrabInput = isGrabInput,
		UserInputService = UserInputService,
		Workspace = Workspace,
		Players = Players,
		GuiService = GuiService,
		ContextActionService = ContextActionService,
		RunService = RunService,
		mouse = mouse,
		INTRO_BRAND = INTRO_BRAND,
		fontWeight = fontWeight,
		fontDisplay = fontDisplay,
	})


	local function unloadUI(animated: boolean?)
		if unloaded then
			return
		end
		saveSettingsNow()
		unloaded = true
		if genv.__DexUI_Unload then
			genv.__DexUI_Unload = nil
		end
		worldPin.setCameraZoomBlocked(false)

		-- Kill every persistent-service connection so no per-frame loop or input
		-- handler keeps running after the UI is gone.
		for _, c in trackedConns do
			pcall(function()
				c:Disconnect()
			end)
		end
		table.clear(trackedConns)

		if activeOverlay then
			hideOverlay(activeOverlay)
		end
		dismissConfirmClose()

		for _, child in Workspace:GetChildren() do
			if child.Name == "DexUIIntro" and child:IsA("Folder") then
				child:Destroy()
			end
		end

		worldPin.teardown()

		if animated ~= false then
			TweenService:Create(win, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
				Size = UDim2.new(0, win.AbsoluteSize.X, 0, 0),
			}):Play()
			tween(winStroke, "Transparency", 1, 0.2)
			task.delay(0.28, function()
				if gui.Parent then
					gui:Destroy()
    end
end)
		elseif gui.Parent then
			gui:Destroy()
		end
	end

	-- Expose this instance's teardown globally so a later re-injection can fully
	-- unload it (disconnecting connections this VM can no longer reach otherwise).
	genv.__DexUI_Unload = function()
		unloadUI(false)
	end

	-- Title-bar close opens the quit confirmation dialog.
	closeBtn.MouseButton1Click:Connect(function()
		showConfirmClose()
	end)

	-- Fade the UI in without running the 3D intro (used after reload).
	function lib:Show()
		gui.Enabled = true
		if lib.ActiveTabIndex > 0 and lib.Tabs[lib.ActiveTabIndex] then
			moveTabHighlight(lib.Tabs[lib.ActiveTabIndex].btn, 0)
		end
	end

	function lib:Destroy()
		unloadUI(true)
	end

	function lib:SetReloadCallback(callback: () -> ())
		reloadCallback = callback
	end

	function lib:Reload()
		if unloaded then
			return
		end
		if not reloadCallback then
			lib:Notify({
				Title = "Reload",
				Content = "Register a reload handler with SetReloadCallback first.",
				Duration = 3,
			})
			return
		end
		local cb = reloadCallback
		unloadUI(false)
		task.defer(cb)
	end

	-- 3D world intro first, then fade the UI in separately.
	function lib:PlayIntro(opts: { Brand: string?, OnComplete: (() -> ())? }?)
		task.spawn(function()
			opts = opts or {}
			local brand = opts.Brand or INTRO_BRAND

			local introSound = Instance.new("Sound")
			introSound.SoundId = INTRO_SOUND
			introSound.Volume = 0.55 * Sound.getMasterVolume()
			introSound.Parent = SoundService
			introSound:Play()
			introSound.Ended:Once(function()
				introSound:Destroy()
			end)
			task.delay(30, function()
				if introSound.Parent then
					introSound:Destroy()
				end
			end)

			local ok, err = pcall(function()
				playWorldIntro(brand, curTheme.pri, fontDisplay, function()
					gui.Enabled = true
					fadeInWin(0.45)

					if lib.ActiveTabIndex > 0 and lib.Tabs[lib.ActiveTabIndex] then
						moveTabHighlight(lib.Tabs[lib.ActiveTabIndex].btn, 0)
					end

					if opts.OnComplete then
						opts.OnComplete()
					end
				end)
			end)
			if not ok then
				warn("[DexUI] Intro failed:", err)
				gui.Enabled = true
				fadeInWin(0.45)
				if lib.ActiveTabIndex > 0 and lib.Tabs[lib.ActiveTabIndex] then
					moveTabHighlight(lib.Tabs[lib.ActiveTabIndex].btn, 0)
				end
				if opts.OnComplete then
					opts.OnComplete()
				end
			end
		end)
	end

	return lib :: Window
end

return makeUI
