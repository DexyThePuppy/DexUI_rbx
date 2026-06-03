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
	Notify: (self: Window, opts: { Title: string?, Content: string?, Duration: number? }) -> (),
	PlayIntro: (self: Window, opts: { Brand: string?, OnComplete: (() -> ())? }?) -> (),
	Show: (self: Window) -> (),
	Destroy: (self: Window) -> (),
	Reload: (self: Window) -> (),
	SetReloadCallback: (self: Window, callback: () -> ()) -> (),
	SetSoundsEnabled: (self: Window, enabled: boolean) -> (),
	SetSoundVolume: (self: Window, scale: number) -> (),
	PlayFeedback: (self: Window, pattern: string) -> (),
}

local function makeUI(titleText: string?): Window
	local lib = {} :: any
	local unloaded = false
	local reloadCallback: (() -> ())? = nil

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
	local fontWeight, m3Font = ctx.fontWeight, ctx.m3Font
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
	corner(win, 16)

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
    top.Text = titleText or "M3 UI Library"
	top.FontFace = fontWeight(Enum.FontWeight.Medium)
    top.TextSize = 22
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

		b.MouseEnter:Connect(function()
			b.BackgroundColor3 = hover or curTheme.fg
			tween(b, "BackgroundTransparency", 0.85, 0.15)
			playFeedback("hover")
			if hover then
				tween(icon, "ImageColor3", hover, 0.15)
			end
		end)
		b.MouseLeave:Connect(function()
			tween(b, "BackgroundTransparency", 1, 0.15)
			if hover then
				tween(icon, "ImageColor3", curTheme.fg, 0.15)
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
	local pinBtn, pinIcon = chromeButton(3, "Pin", 3926305904, Vector2.new(684, 564))
	local closeBtn = chromeButton(4, "Close", 3926305904, Vector2.new(284, 4), Color3.fromRGB(255, 95, 95), Vector2.new(24, 24))

	--//---------------------- TAB BAR (vertical sidebar) ----------------------\\--

	local TITLE_BAR_H = 55
	local TAB_SIDEBAR_W = 172

	local tabArea = Instance.new("Frame")
	tabArea.Size = UDim2.new(0, TAB_SIDEBAR_W, 1, -TITLE_BAR_H)
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
	defaultCont.Size = UDim2.new(1, 0, 1, -TITLE_BAR_H)
	defaultCont.Position = UDim2.new(0, 0, 0, TITLE_BAR_H)
	defaultCont.Parent = win
	styleContainer(defaultCont)

	local contClip = Instance.new("Frame")
	contClip.Size = UDim2.new(1, -TAB_SIDEBAR_W, 1, -TITLE_BAR_H)
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
		label.TextSize = 14
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
	--||                     NOTIFICATIONS                        ||--
	--\\============================================================//--

	local notifHolder = Instance.new("Frame")
	notifHolder.Size = UDim2.new(0, 300, 1, -20)
	notifHolder.AnchorPoint = Vector2.new(1, 1)
	notifHolder.Position = UDim2.new(1, -16, 1, -10)
	notifHolder.BackgroundTransparency = 1
	notifHolder.Parent = gui

	local notifLayout = Instance.new("UIListLayout")
	notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	notifLayout.Padding = UDim.new(0, 10)
	notifLayout.Parent = notifHolder

	function lib:Notify(opts: { Title: string?, Content: string?, Duration: number? })
		playFeedback("selection")
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 10)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.BackgroundColor3 = curTheme.inact
		card.BackgroundTransparency = 1
		card.BorderSizePixel = 0
		card.Parent = notifHolder
		corner(card, 14)

		local stroke = Instance.new("UIStroke")
		stroke.Color = curTheme.pri
		stroke.Thickness = 1
		stroke.Transparency = 1
		stroke.Parent = card

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 16)
		pad.Parent = card

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = card

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 18)
		title.BackgroundTransparency = 1
		title.Text = opts.Title or "Notification"
		title.TextTransparency = 1
		title.FontFace = fontWeight(Enum.FontWeight.Medium)
		title.TextColor3 = curTheme.fg
		title.TextSize = 15
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.LayoutOrder = 1
		title.Parent = card

		local content = Instance.new("TextLabel")
		content.Size = UDim2.new(1, 0, 0, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		content.BackgroundTransparency = 1
		content.Text = opts.Content or ""
		content.TextTransparency = 1
		content.FontFace = m3Font
		content.TextColor3 = curTheme.out
		content.TextSize = 13
		content.TextWrapped = true
		content.TextXAlignment = Enum.TextXAlignment.Left
		content.TextYAlignment = Enum.TextYAlignment.Top
		content.LayoutOrder = 2
		content.Parent = card

		-- Slide + fade in.
		card.Position = UDim2.new(1, 0, 0, 0)
		tween(card, "BackgroundTransparency", 0, 0.4)
		tween(stroke, "Transparency", 0.4, 0.4)
		tween(title, "TextTransparency", 0, 0.4)
		tween(content, "TextTransparency", 0, 0.4)

		task.delay(opts.Duration or 3, function()
			tween(card, "BackgroundTransparency", 1, 0.4)
			tween(stroke, "Transparency", 1, 0.4)
			tween(title, "TextTransparency", 1, 0.4)
			tween(content, "TextTransparency", 1, 0.4)
			task.delay(0.45, function()
				card:Destroy()
			end)
		end)
	end

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
		group.Visible = true
		group.Position = UDim2.new(0, 0, 0, 62)
		group.GroupTransparency = 1
		tween(group, "Position", UDim2.new(0, 0, 0, 50), 0.3)
		tween(group, "GroupTransparency", 0, 0.3)
	end

	-- Section heading used above each grouped card in the overlays.
	local function addOverlayHeading(scroll: Instance, text: string, order: number): TextLabel
		local h = Instance.new("TextLabel")
		h.Size = UDim2.new(1, 0, 0, 20)
		h.BackgroundTransparency = 1
		h.Text = text
		h.FontFace = fontWeight(Enum.FontWeight.Medium)
		h.TextSize = 13
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
		lbl.TextSize = 15
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
		end)
	end)

	regDynamic(function(theme, dur)
		tween(soundTrk, "BackgroundColor3", Sound.isSoundsEnabled() and theme.pri or theme.inact, dur)
		tween(soundThm, "BackgroundColor3", Sound.isSoundsEnabled() and theme.onpri or theme.out, dur)
	end)

	--//-------------- INTERFACE ACTIONS ----------------\\--

	addOverlayHeading(settingsScroll, "Interface", 4)

	local function addSettingsAction(label: string, destructive: boolean?, onClick: () -> ())
		local content = beginCardRow(44, false)
		local surface = content.Parent.Parent :: Frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.FontFace = m3Font
		lbl.TextSize = 15
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

	buildOverlayGroup(settingsScroll, 5, function()
		addSettingsAction("Reload UI", false, function()
			hideOverlay(settingsOverlay)
			lib:Reload()
		end)
		addSettingsAction("Quit", true, function()
			hideOverlay(settingsOverlay)
			lib:Destroy()
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
	searchField.TextSize = 15
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
			empty.TextSize = 14
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
				nameL.TextSize = 14
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
				tabL.TextSize = 12
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

	--//============================================================\\--
	--||         RESIZE FROM ANY EDGE / CORNER (W/ GLOW)          ||--
	--\\============================================================//--

	-- Accent highlights: only the hovered edge OR corner lights up (never the whole frame).
	local function glowBar(size: UDim2, pos: UDim2, anchor: Vector2): Frame
		local bar = Instance.new("Frame")
		bar.Size = size
		bar.Position = pos
		bar.AnchorPoint = anchor
		bar.BackgroundTransparency = 1
		bar.BorderSizePixel = 0
		bar.ZIndex = 60
		bar.Parent = win
		corner(bar, 999)
		reg(bar, "BackgroundColor3", "pri")
		return bar
	end

	local WIN_RADIUS = 16 -- must match corner(win, ...)
	local ARM = WIN_RADIUS -- edge highlights stop at the corner curve's tangent point
	local EDGE_DIM = 0.8 -- adjacent edges only glow at ~20% opacity when a corner is hovered
	-- Edge highlights span the edge minus the rounded corners.
	local topBar = glowBar(UDim2.new(1, -2 * ARM, 0, 3), UDim2.new(0, ARM, 0, 0), Vector2.new(0, 0))
	local bottomBar = glowBar(UDim2.new(1, -2 * ARM, 0, 3), UDim2.new(0, ARM, 1, 0), Vector2.new(0, 1))
	local leftBar = glowBar(UDim2.new(0, 3, 1, -2 * ARM), UDim2.new(0, 0, 0, ARM), Vector2.new(0, 0))
	local rightBar = glowBar(UDim2.new(0, 3, 1, -2 * ARM), UDim2.new(1, 0, 0, ARM), Vector2.new(1, 0))
	-- An edge hover lights its own bar fully.
	local glowTop = { { topBar, 0 } }
	local glowBottom = { { bottomBar, 0 } }
	local glowLeft = { { leftBar, 0 } }
	local glowRight = { { rightBar, 0 } }

	-- A curved 3px border segment hugging the window's rounded corner (accent ring carved by a
	-- background-coloured mask, clipped to just the corner quarter so it connects the two edges).
	local function makeCornerArc(ax: number, ay: number): Frame
		local clip = Instance.new("Frame")
		clip.Size = UDim2.fromOffset(WIN_RADIUS, WIN_RADIUS)
		clip.AnchorPoint = Vector2.new(ax, ay)
		clip.Position = UDim2.new(ax, 0, ay, 0)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.ZIndex = 60
		clip.Parent = win

		local d = 2 * WIN_RADIUS
		local accent = Instance.new("Frame")
		accent.Size = UDim2.fromOffset(d, d)
		accent.AnchorPoint = Vector2.new(ax, ay)
		accent.Position = UDim2.new(ax, 0, ay, 0)
		accent.BackgroundTransparency = 1
		accent.BorderSizePixel = 0
		accent.ZIndex = 60
		accent.Parent = clip
		corner(accent, WIN_RADIUS)
		reg(accent, "BackgroundColor3", "pri")

		local cover = Instance.new("Frame")
		cover.Size = UDim2.fromOffset(d, d)
		cover.AnchorPoint = Vector2.new(ax, ay)
		cover.Position = UDim2.new(ax, ax == 0 and 3 or -3, ay, ay == 0 and 3 or -3)
		cover.BorderSizePixel = 0
		cover.ZIndex = 61
		cover.Parent = clip
		corner(cover, WIN_RADIUS - 3)
		reg(cover, "BackgroundColor3", "bg")
		return accent
	end

	-- Corner hover: the curved corner border is the full accent tint, while the two adjacent
	-- edges only glow faintly (EDGE_DIM) so the corner itself reads as the focal point.
	local glowTL = { { makeCornerArc(0, 0), 0 }, { topBar, EDGE_DIM }, { leftBar, EDGE_DIM } }
	local glowTR = { { makeCornerArc(1, 0), 0 }, { topBar, EDGE_DIM }, { rightBar, EDGE_DIM } }
	local glowBL = { { makeCornerArc(0, 1), 0 }, { bottomBar, EDGE_DIM }, { leftBar, EDGE_DIM } }
	local glowBR = { { makeCornerArc(1, 1), 0 }, { bottomBar, EDGE_DIM }, { rightBar, EDGE_DIM } }

	-- Forward-declared so resize handlers (registered below) see the same locals as pin setup.
	local pinned = false
	local worldPanelRotation = CFrame.identity
	local WORLD_PIXELS_PER_STUD = 50
	local pinViewDepth = 20
	local anchorPart: Part
	local keepUpright: AlignOrientation
	local applyUprightTarget: () -> ()

    local resizing = false
	local activeEdges: { [string]: boolean } = {}
	local activeGroup: { any } = {}

	local function setGlow(group: { any }, on: boolean)
		for _, entry in group do
			tween(entry[1], "BackgroundTransparency", on and entry[2] or 1, 0.15)
		end
	end

	-- The tab sidebar is a fixed width, so derive the window's minimum width from a
	-- minimum content-column width. This stops the right-hand tab content from
	-- collapsing into an unusably narrow strip when the window is resized down.
	local MIN_CONTENT_W = 200
	local minW, minH = TAB_SIDEBAR_W + MIN_CONTENT_W, 360
	local resStartPos: Vector2, resStartSize: Vector2, resStartOffset: Vector2
	local resStartPartCenter: Vector3, resStartPartSize: Vector3
	local resScaleX, resScaleY = 0, 0

	local function makeHandle(size: UDim2, pos: UDim2, anchor: Vector2, edges: { [string]: boolean }, cursor: string, group: { any }, name: string)
		local h = Instance.new("TextButton")
		h.Name = "Resize_" .. name
		h.Size = size
		h.Position = pos
		h.AnchorPoint = anchor
		h.BackgroundTransparency = 1
		h.Text = ""
		h.AutoButtonColor = false
		h.ZIndex = 200
		h.Parent = win

		h.MouseEnter:Connect(function()
			mouse.Icon = cursor
			if not resizing then
				setGlow(group, true)
			end
		end)
		h.MouseLeave:Connect(function()
			if not resizing then
				mouse.Icon = ""
				setGlow(group, false)
			end
		end)
		h.InputBegan:Connect(function(i)
			if isPrimaryInput(i) then
				resizing = true
				activeEdges = edges
				activeGroup = group
				resStartPos = UserInputService:GetMouseLocation()
				resStartSize = win.AbsoluteSize
				resStartOffset = Vector2.new(win.Position.X.Offset, win.Position.Y.Offset)
				resScaleX = win.Position.X.Scale
				resScaleY = win.Position.Y.Scale
				if pinned then
					win.Size = UDim2.fromScale(1, 1)
					win.Position = UDim2.fromOffset(0, 0)
					resStartSize = Vector2.new(
						anchorPart.Size.X * WORLD_PIXELS_PER_STUD,
						anchorPart.Size.Y * WORLD_PIXELS_PER_STUD
					)
					keepUpright.Enabled = false
					anchorPart.Anchored = true
					anchorPart.AssemblyLinearVelocity = Vector3.zero
					anchorPart.AssemblyAngularVelocity = Vector3.zero
					resStartPartCenter = anchorPart.Position
					resStartPartSize = anchorPart.Size
				end
				mouse.Icon = cursor
				setGlow(group, true)
			end
		end)
		return h
	end

	local EDGE = 7
	local CORNER = 14
	-- Edges
	makeHandle(UDim2.new(1, -2 * CORNER, 0, EDGE), UDim2.new(0, CORNER, 0, 0), Vector2.new(0, 0), { top = true }, "rbxasset://SystemCursors/SizeNS", glowTop, "Top")
	makeHandle(UDim2.new(1, -2 * CORNER, 0, EDGE), UDim2.new(0, CORNER, 1, 0), Vector2.new(0, 1), { bottom = true }, "rbxasset://SystemCursors/SizeNS", glowBottom, "Bottom")
	makeHandle(UDim2.new(0, EDGE, 1, -2 * CORNER), UDim2.new(0, 0, 0, CORNER), Vector2.new(0, 0), { left = true }, "rbxasset://SystemCursors/SizeEW", glowLeft, "Left")
	makeHandle(UDim2.new(0, EDGE, 1, -2 * CORNER), UDim2.new(1, 0, 0, CORNER), Vector2.new(1, 0), { right = true }, "rbxasset://SystemCursors/SizeEW", glowRight, "Right")
	-- Corners
	makeHandle(UDim2.fromOffset(CORNER, CORNER), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), { top = true, left = true }, "rbxasset://SystemCursors/SizeNWSE", glowTL, "TL")
	makeHandle(UDim2.fromOffset(CORNER, CORNER), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), { top = true, right = true }, "rbxasset://SystemCursors/SizeNESW", glowTR, "TR")
	makeHandle(UDim2.fromOffset(CORNER, CORNER), UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), { bottom = true, left = true }, "rbxasset://SystemCursors/SizeNESW", glowBL, "BL")
	makeHandle(UDim2.fromOffset(CORNER, CORNER), UDim2.new(1, 0, 1, 0), Vector2.new(1, 1), { bottom = true, right = true }, "rbxasset://SystemCursors/SizeNWSE", glowBR, "BR")

	onInputChanged(function(i)
		if resizing and isMoveInput(i) then
			local loc = UserInputService:GetMouseLocation()
			local dx = loc.X - resStartPos.X
			local dy = loc.Y - resStartPos.Y
			local newW, newH = resStartSize.X, resStartSize.Y
			local offX, offY = resStartOffset.X, resStartOffset.Y
			if activeEdges.right then
				newW = resStartSize.X + dx
			end
			if activeEdges.bottom then
				newH = resStartSize.Y + dy
			end
			if activeEdges.left then
				newW = math.max(minW, resStartSize.X - dx)
				offX = resStartOffset.X + (resStartSize.X - newW)
			end
			if activeEdges.top then
				newH = math.max(minH, resStartSize.Y - dy)
				offY = resStartOffset.Y + (resStartSize.Y - newH)
			end
			newW = math.max(minW, newW)
			newH = math.max(minH, newH)

			if pinned then
				local newWStud = newW / WORLD_PIXELS_PER_STUD
				local newHStud = newH / WORLD_PIXELS_PER_STUD
				local shift = Vector3.zero
				local widthDelta = newWStud - resStartPartSize.X
				local heightDelta = newHStud - resStartPartSize.Y
				if activeEdges.right and not activeEdges.left then
					shift -= worldPanelRotation.RightVector * widthDelta * 0.5
				elseif activeEdges.left and not activeEdges.right then
					shift += worldPanelRotation.RightVector * widthDelta * 0.5
				end
				if activeEdges.bottom and not activeEdges.top then
					shift -= worldPanelRotation.UpVector * heightDelta * 0.5
				elseif activeEdges.top and not activeEdges.bottom then
					shift += worldPanelRotation.UpVector * heightDelta * 0.5
				end
				anchorPart.Size = Vector3.new(newWStud, newHStud, resStartPartSize.Z)
				anchorPart.CFrame = CFrame.new(resStartPartCenter + shift) * worldPanelRotation
			else
				win.Size = UDim2.new(0, newW, 0, newH)
				win.Position = UDim2.new(resScaleX, offX, resScaleY, offY)
			end
		end
	end)
	onInputEnded(function(i)
		if isPrimaryInput(i) and resizing then
			resizing = false
			setGlow(activeGroup, false)
			mouse.Icon = ""
			if pinned then
				anchorPart.Anchored = false
				keepUpright.Enabled = true
				applyUprightTarget()
			end
		end
	end)

	--//============================================================\\--
	--||              PIN UI INTO THE 3D WORLD                    ||--
	--\\============================================================//--

	local savedScreenPos = win.Position
	local dragWorldOffset: Vector3? = nil
	local GRAB_DEPTH_STEP = 2

	local oldWorld = Workspace:FindFirstChild("Material3WorldUI")
	if oldWorld then
		oldWorld:Destroy()
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local oldFace = playerGui:FindFirstChild("Material3WorldFace")
	if oldFace then
		oldFace:Destroy()
	end
	local oldBack = playerGui:FindFirstChild("Material3WorldBack")
	if oldBack then
		oldBack:Destroy()
	end

	local worldRoot = Instance.new("Folder")
	worldRoot.Name = "Material3WorldUI"
	worldRoot.Parent = Workspace

	anchorPart = Instance.new("Part")
	anchorPart.Name = "UIAnchor"
	anchorPart.Size = Vector3.new(7.6, 10.4, 0.08)
	anchorPart.Transparency = 1
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CastShadow = false
	anchorPart.Parent = worldRoot

	local panelAtt = Instance.new("Attachment")
	panelAtt.Name = "PanelAttachment"
	panelAtt.Parent = anchorPart

	keepUpright = Instance.new("AlignOrientation")
	keepUpright.Name = "KeepUpright"
	keepUpright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	keepUpright.RigidityEnabled = true
	keepUpright.ReactionTorqueEnabled = true
	keepUpright.MaxTorque = math.huge
	keepUpright.Responsiveness = 200
	keepUpright.Attachment0 = panelAtt
	keepUpright.Enabled = false
	keepUpright.Parent = anchorPart

	local GRAB_MOVE_SPEED = 28
	local GRAB_YAW_LERP = 0.1

	local function uprightRotationAt(pos: Vector3, cam: Camera): CFrame
		local toCam = cam.CFrame.Position - pos
		local flat = Vector3.new(toCam.X, 0, toCam.Z)
		if flat.Magnitude < 0.05 then
			flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		end
		if flat.Magnitude < 0.05 then
			flat = Vector3.new(0, 0, -1)
		end
		return CFrame.lookAt(pos, pos + flat.Unit, Vector3.yAxis).Rotation
	end

	applyUprightTarget = function()
		keepUpright.CFrame = CFrame.new(anchorPart.Position) * worldPanelRotation
	end

	local function enableWorldPhysics()
		anchorPart.Anchored = false
		anchorPart.CanCollide = true
		anchorPart.CustomPhysicalProperties = PhysicalProperties.new(0.75, 0.3, 0.4, 1, 1)
		keepUpright.Enabled = true
		applyUprightTarget()
	end

	local function disableWorldPhysics()
		keepUpright.Enabled = false
		anchorPart.Anchored = true
		anchorPart.CanCollide = false
		anchorPart.AssemblyLinearVelocity = Vector3.zero
		anchorPart.AssemblyAngularVelocity = Vector3.zero
	end

	-- SurfaceGui must live in PlayerGui with Adornee set for input to work in 3D.
	local worldFace = Instance.new("SurfaceGui")
	worldFace.Name = "Material3WorldFace"
	worldFace.ResetOnSpawn = false
	worldFace.Enabled = false
	worldFace.Active = true
	-- Keep AlwaysOnTop off: it would render the panel through walls and break
	-- click input (clicks hit whatever geometry is actually closest). Instead we
	-- stay at world depth and rely on LightInfluence = 0 plus a brightness boost
	-- so the panel reads as flat/unlit without the lighting tint.
	worldFace.AlwaysOnTop = false
	worldFace.Face = Enum.NormalId.Front
	worldFace.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	worldFace.PixelsPerStud = WORLD_PIXELS_PER_STUD
	worldFace.LightInfluence = 0
	worldFace.Brightness = 2
	worldFace.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	worldFace.Parent = playerGui

	local worldBack = Instance.new("SurfaceGui")
	worldBack.Name = "Material3WorldBack"
	worldBack.ResetOnSpawn = false
	worldBack.Enabled = false
	worldBack.Active = true
	worldBack.AlwaysOnTop = false
	worldBack.Face = Enum.NormalId.Back
	worldBack.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	worldBack.PixelsPerStud = WORLD_PIXELS_PER_STUD
	worldBack.LightInfluence = 0
	worldBack.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	worldBack.Parent = playerGui

	local backSurface = Instance.new("Frame")
	backSurface.Name = "BackSurface"
	backSurface.Size = UDim2.fromScale(1, 1)
	backSurface.BorderSizePixel = 0
	backSurface.ClipsDescendants = true
	backSurface.Parent = worldBack
	reg(backSurface, "BackgroundColor3", "bg")
	corner(backSurface, WIN_RADIUS)

	local backLogo = Instance.new("TextLabel")
	backLogo.Name = "DexUIBackLogo"
	backLogo.AnchorPoint = Vector2.new(0.5, 0.5)
	backLogo.Position = UDim2.fromScale(0.5, 0.5)
	backLogo.Size = UDim2.fromScale(0.72, 0.22)
	backLogo.BackgroundTransparency = 1
	backLogo.Text = INTRO_BRAND
	backLogo.TextScaled = true
	backLogo.FontFace = fontWeight(Enum.FontWeight.Heavy)
	backLogo.ZIndex = 1
	backLogo.Parent = backSurface

	local backStroke = Instance.new("UIStroke")
	backStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	backStroke.Thickness = 3.5
	backStroke.Parent = backLogo

	regDynamic(function(palette: Palette, d: number)
		local borderColor = palette.pri:Lerp(Color3.new(0, 0, 0), 0.55)
		if d > 0 then
			tween(backLogo, "TextColor3", palette.pri, d)
			tween(backStroke, "Color", borderColor, d)
		else
			backLogo.TextColor3 = palette.pri
			backStroke.Color = borderColor
		end
	end)

	local backDragHandle = Instance.new("TextButton")
	backDragHandle.Name = "BackDragHandle"
	backDragHandle.Size = UDim2.fromScale(1, 1)
	backDragHandle.BackgroundTransparency = 1
	backDragHandle.Text = ""
	backDragHandle.AutoButtonColor = false
	backDragHandle.ZIndex = 2
	backDragHandle.Parent = backSurface

	local ZOOM_BLOCK_ACTION = "DexUIBlockCameraZoom"
	local cameraZoomBlocked = false

	local function sinkCameraZoom(_actionName: string, _inputState: Enum.UserInputState, _inputObject: InputObject)
		return Enum.ContextActionResult.Sink
	end

	local function setCameraZoomBlocked(block: boolean)
		if block == cameraZoomBlocked then
			return
		end
		cameraZoomBlocked = block
		if block then
			ContextActionService:BindActionAtPriority(
				ZOOM_BLOCK_ACTION,
				sinkCameraZoom,
				false,
				Enum.ContextActionPriority.High.Value,
				Enum.UserInputType.MouseWheel
			)
		else
			ContextActionService:UnbindAction(ZOOM_BLOCK_ACTION)
		end
	end

	local worldRayParams = RaycastParams.new()
	worldRayParams.FilterType = Enum.RaycastFilterType.Exclude
	worldRayParams.FilterDescendantsInstances = { worldRoot }

	local function screenToUnitRay(sx: number, sy: number): Ray
		local cam = Workspace.CurrentCamera
		local inset = GuiService:GetGuiInset()
		local unitRay = cam:ScreenPointToRay(sx, sy + inset.Y)
		return Ray.new(unitRay.Origin, unitRay.Direction)
	end

	local function viewPointToWorld(sx: number, sy: number, depth: number): Vector3
		local ray = screenToUnitRay(sx, sy)
		return ray.Origin + ray.Direction * depth
	end

	local function syncWorldPartSize(w: number?, h: number?)
		w = math.max(1, w or win.AbsoluteSize.X)
		h = math.max(1, h or win.AbsoluteSize.Y)
		anchorPart.Size = Vector3.new(w / WORLD_PIXELS_PER_STUD, h / WORLD_PIXELS_PER_STUD, 0.08)
	end

	local function setPartWorldCFrame(pos: Vector3)
		anchorPart.CFrame = CFrame.new(pos) * worldPanelRotation
	end

	local function mouseUnitRay(): Ray
		local loc = UserInputService:GetMouseLocation()
		return screenToUnitRay(loc.X, loc.Y)
	end

	local function rayCameraDepthPlane(depth: number): Vector3?
		local cam = Workspace.CurrentCamera
		if not cam then
			return nil
		end
		local look = cam.CFrame.LookVector
		local planePoint = cam.CFrame.Position + look * depth
		local ray = mouseUnitRay()
		local denom = ray.Direction:Dot(look)
		if math.abs(denom) < 1e-4 then
			return nil
		end
		local t = (planePoint - ray.Origin):Dot(look) / denom
		if t <= 0 then
			return nil
		end
		return ray.Origin + ray.Direction * t
	end

	local function rayToWorldPoint(): Vector3
		local ray = mouseUnitRay()
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 512, worldRayParams)
		if hit then
			return hit.Position + hit.Normal * (anchorPart.Size.Z / 2 + 0.02)
		end
		return ray.Origin + ray.Direction * pinViewDepth
	end

	local function setPinned(state: boolean)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end

		pinned = state
		if pinned then
			savedScreenPos = win.Position
			local w = math.max(1, win.AbsoluteSize.X)
			local h = math.max(1, win.AbsoluteSize.Y)

			-- Place on a fixed plane in front of the camera through the window center.
			local center = win.AbsolutePosition + win.AbsoluteSize / 2
			local worldPos = viewPointToWorld(center.X, center.Y, pinViewDepth)
			pinViewDepth = (worldPos - cam.CFrame.Position).Magnitude
			worldPanelRotation = uprightRotationAt(worldPos, cam)

			syncWorldPartSize(w, h)
			setPartWorldCFrame(worldPos)
			enableWorldPhysics()

			anchorPart.CanQuery = true
			worldFace.Adornee = anchorPart
			worldFace.Enabled = true
			worldBack.Adornee = anchorPart
			worldBack.Enabled = true
			win.Parent = worldFace
			win.Active = true
			win.AnchorPoint = Vector2.new(0, 0)
			win.Position = UDim2.fromOffset(0, 0)
			win.Size = UDim2.fromScale(1, 1)
			tween(pinIcon, "ImageColor3", curTheme.pri, 0.2)
			playFeedback("toggleOn")
		else
			disableWorldPhysics()
			worldFace.Adornee = nil
			worldFace.Enabled = false
			worldBack.Adornee = nil
			worldBack.Enabled = false
			anchorPart.CanQuery = false
			local screenPos, onScreen = cam:WorldToViewportPoint(anchorPart.Position)
			local w = math.floor(anchorPart.Size.X * WORLD_PIXELS_PER_STUD + 0.5)
			local h = math.floor(anchorPart.Size.Y * WORLD_PIXELS_PER_STUD + 0.5)
			win.Parent = gui
			win.AnchorPoint = Vector2.new(0, 0)
			win.Size = UDim2.fromOffset(w, h)
			if onScreen then
				win.Position = UDim2.new(
					0,
					screenPos.X - win.AbsoluteSize.X / 2,
					0,
					screenPos.Y - win.AbsoluteSize.Y / 2
				)
			else
				win.Position = savedScreenPos
			end
			tween(pinIcon, "ImageColor3", curTheme.fg, 0.2)
			playFeedback("toggleOff")
		end
	end

	pinBtn.MouseButton1Click:Connect(function()
		setPinned(not pinned)
	end)

	--//============================================================\\--
	--||                 DRAG FROM THE TITLE BAR                  ||--
	--\\============================================================//--

	tabListCont:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if lib.ActiveTabIndex > 0 and lib.Tabs[lib.ActiveTabIndex] then
			moveTabHighlight(lib.Tabs[lib.ActiveTabIndex].btn, 0)
		end
	end)

	win:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if pinned and not resizing then
			syncWorldPartSize()
		end
		if lib.ActiveTabIndex > 0 and lib.Tabs[lib.ActiveTabIndex] then
			moveTabHighlight(lib.Tabs[lib.ActiveTabIndex].btn, 0.15)
        end
    end)

	local dragging = false
	local dragInput: InputObject?, dragStart: Vector3, startPos: UDim2
	local activeGrabInput: Enum.UserInputType? = nil
	local grabPlaneDepth: number? = nil

	local function refreshGrabOffset()
		if grabPlaneDepth then
			local hit = rayCameraDepthPlane(grabPlaneDepth)
			if hit then
				dragWorldOffset = anchorPart.Position - hit
			end
		end
	end

	local function beginGrab(input: InputObject)
		dragging = true
		dragInput = input
		dragStart = input.Position
		startPos = win.Position
		activeGrabInput = input.UserInputType
		if pinned then
			anchorPart.Anchored = false
			anchorPart.CanCollide = true
			local cam = Workspace.CurrentCamera
			if cam then
				grabPlaneDepth = (anchorPart.Position - cam.CFrame.Position):Dot(cam.CFrame.LookVector)
				local hit = rayCameraDepthPlane(grabPlaneDepth)
				dragWorldOffset = if hit then anchorPart.Position - hit else Vector3.zero
			end
			setCameraZoomBlocked(true)
		else
			dragWorldOffset = nil
			grabPlaneDepth = nil
		end
	end

	local function endGrab(input: InputObject)
		if not activeGrabInput or input.UserInputType ~= activeGrabInput then
			return
		end
		if pinned and dragging then
			anchorPart.AssemblyLinearVelocity = Vector3.zero
			anchorPart.AssemblyAngularVelocity = Vector3.zero
			applyUprightTarget()
			setCameraZoomBlocked(false)
		end
		dragging = false
		dragInput = nil
		dragWorldOffset = nil
		grabPlaneDepth = nil
		activeGrabInput = nil
	end

	local function connectGrabHandle(handle: TextButton)
		handle.InputBegan:Connect(function(input)
			if not isGrabInput(input) or resizing then
				return
			end
			beginGrab(input)
		end)
		handle.InputEnded:Connect(function(input)
			endGrab(input)
		end)
	end

	connectGrabHandle(dragHandle)
	connectGrabHandle(backDragHandle)

	onInputChanged(function(i)
		if isMoveInput(i) then
			dragInput = i
		elseif pinned and dragging and i.UserInputType == Enum.UserInputType.MouseWheel then
			local scrollDir = i.Position.Z
			if scrollDir ~= 0 then
				local cam = Workspace.CurrentCamera
				if cam and grabPlaneDepth then
					local step = (scrollDir > 0 and 1 or -1) * GRAB_DEPTH_STEP
					grabPlaneDepth += step
					anchorPart.AssemblyLinearVelocity = Vector3.zero
					anchorPart.AssemblyAngularVelocity = Vector3.zero
					local hit = rayCameraDepthPlane(grabPlaneDepth)
					if hit and dragWorldOffset then
						local newPos = hit + dragWorldOffset
						anchorPart.CFrame = CFrame.new(newPos) * worldPanelRotation
					else
						anchorPart.CFrame = CFrame.new(anchorPart.Position + cam.CFrame.LookVector * step) * worldPanelRotation
						refreshGrabOffset()
					end
					applyUprightTarget()
				end
			end
		end
	end)

	onInputEnded(function(i)
		if activeGrabInput and i.UserInputType == activeGrabInput then
			endGrab(i)
		end
	end)

	onRender(function(dt)
		if not dragging or resizing then
			return
		end
		if pinned then
			local cam = Workspace.CurrentCamera
			local target = anchorPart.Position
			if grabPlaneDepth then
				local hit = rayCameraDepthPlane(grabPlaneDepth)
				if hit and dragWorldOffset then
					target = hit + dragWorldOffset
				end
			end

			local offset = target - anchorPart.Position
			if offset.Magnitude > 0.05 then
				anchorPart.AssemblyLinearVelocity = offset.Unit * math.min(GRAB_MOVE_SPEED, offset.Magnitude * 12)
			else
				anchorPart.AssemblyLinearVelocity = Vector3.zero
			end
			anchorPart.AssemblyAngularVelocity = Vector3.zero

			if cam then
				local targetRot = uprightRotationAt(anchorPart.Position, cam)
				worldPanelRotation = worldPanelRotation:Lerp(targetRot, math.clamp(GRAB_YAW_LERP * dt * 60, 0, 1))
				applyUprightTarget()
			end
		elseif dragInput then
			local delta = dragInput.Position - dragStart
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	local function unloadUI(animated: boolean?)
		if unloaded then
			return
		end
		unloaded = true
		if genv.__DexUI_Unload then
			genv.__DexUI_Unload = nil
		end
		setCameraZoomBlocked(false)

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

		for _, child in Workspace:GetChildren() do
			if child.Name == "DexUIIntro" and child:IsA("Folder") then
				child:Destroy()
			end
		end

		if pinned then
			disableWorldPhysics()
			worldFace.Adornee = nil
			worldFace.Enabled = false
			worldBack.Adornee = nil
			worldBack.Enabled = false
			anchorPart.CanQuery = false
			win.Parent = gui
			pinned = false
		end
		if worldFace.Parent then
			worldFace:Destroy()
		end
		if worldBack.Parent then
			worldBack:Destroy()
		end
		if worldRoot.Parent then
			worldRoot:Destroy()
		end

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

	-- Title-bar close behaves exactly like the Settings > Quit action.
	closeBtn.MouseButton1Click:Connect(function()
		lib:Destroy()
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
				playWorldIntro(brand, curTheme.pri, fontWeight(Enum.FontWeight.Heavy), function()
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
