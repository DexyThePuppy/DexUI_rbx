--!nonstrict
-- Scripts hub grid: game thumbnails from scripts/index.lua, launches standalone scripts.

local Registry = require("../hub/registry")
local runScript = require("../hub/run-script")

export type GameEntry = Registry.GameEntry

return function(ctx)
	local lib = ctx.lib
	local curTheme = ctx.theme
	local reg, regDynamic = ctx.reg, ctx.regDynamic
	local tween, corner, ripple = ctx.tween, ctx.corner, ctx.ripple
	local m3Font = ctx.m3Font
	local beginCardRow = ctx.beginCardRow
	local playFeedback = ctx.playFeedback
	local fontWeight = ctx.fontWeight
	local tooltip = ctx.tooltip

	local activeSessions: { any } = {}

	local function formatThumb(url: string): string
		if string.find(url, "rbxassetid://", 1, true) or string.find(url, "rbxthumb://", 1, true) or string.find(url, "http", 1, true) then
			return url
		end
		local digits = string.match(url, "(%d+)")
		if digits then
			return "rbxassetid://" .. digits
		end
		return url
	end

	local function destroySession(entry: GameEntry)
		for i, session in activeSessions do
			if session.entryId == entry.id then
				if session.ui and session.ui.Destroy then
					pcall(function()
						session.ui:Destroy()
					end)
				end
				table.remove(activeSessions, i)
				return
			end
		end
	end

	local function buildScriptTooltip(entry: GameEntry): any
		local blocks: { any } = {
			{ kind = "title", text = entry.name },
		}
		if entry.description and entry.description ~= "" then
			table.insert(blocks, { kind = "text", text = entry.description })
		end
		table.insert(blocks, { kind = "divider" })
		table.insert(blocks, { kind = "stat", label = "Script", value = entry.script })
		if entry.placeIds and #entry.placeIds > 0 then
			local placeParts: { string } = {}
			for _, id in entry.placeIds do
				table.insert(placeParts, tostring(id))
			end
			table.insert(blocks, {
				kind = "stat",
				label = "Place IDs",
				value = table.concat(placeParts, ", "),
			})
		end
		if entry.universeIds and #entry.universeIds > 0 then
			local uniParts: { string } = {}
			for _, id in entry.universeIds do
				table.insert(uniParts, tostring(id))
			end
			table.insert(blocks, {
				kind = "stat",
				label = "Universe IDs",
				value = table.concat(uniParts, ", "),
			})
		end
		if Registry.entryMatchesCurrent(entry) then
			table.insert(blocks, { kind = "text", text = "Matches your current experience.", muted = true })
		end
		table.insert(blocks, { kind = "text", text = "Click to launch script.", muted = true })
		return { blocks = blocks, maxWidth = 280 }
	end

	local function launchEntry(entry: GameEntry)
		local dexui = lib._dexuiModule
		if not dexui then
			lib:Notify({ Title = "Hub", Content = "DexUI module reference missing.", Duration = 4 })
			return
		end
		destroySession(entry)
		local ok, err = runScript(entry.script, dexui)
		if not ok then
			lib:Notify({
				Title = "Script failed",
				Content = err or ("Could not run " .. entry.script),
				Duration = 5,
			})
			return
		end
		table.insert(activeSessions, { entryId = entry.id, ui = nil })
		lib:Notify({
			Title = entry.name,
			Content = "Script loaded.",
			Duration = 2.5,
		})
	end

	function lib:PopulateScriptsHub(entries: { GameEntry }?)
		local list = entries or Registry.load()
		local recognized = Registry.findForCurrentGame(list)

		local holder = Instance.new("Frame")
		holder.Name = "ScriptsHub"
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.Parent = beginCardRow(nil, true)

		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, 0, 0, 22)
		header.BackgroundTransparency = 1
		header.Text = if recognized
			then ("Recognised: " .. recognized.name .. " — pick a script or launch yours")
			else "Scripts hub — select a game"
		header.FontFace = fontWeight(Enum.FontWeight.Medium)
		header.TextSize = 13
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextWrapped = true
		header.Parent = holder
		reg(header, "TextColor3", "out")

		local gridHost = Instance.new("Frame")
		gridHost.Size = UDim2.new(1, 0, 0, 0)
		gridHost.AutomaticSize = Enum.AutomaticSize.Y
		gridHost.BackgroundTransparency = 1
		gridHost.Parent = holder

		local CARD_W, CARD_H = 108, 118
		local GAP, INSET = 4, 4

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = holder
		header.LayoutOrder = 0
		gridHost.LayoutOrder = 1

		local estCols = math.max(1, math.floor(360 / (CARD_W + GAP)))
		local rows = math.max(1, math.ceil(#list / estCols))
		local gridScroll = Instance.new("ScrollingFrame")
		gridScroll.Size = UDim2.new(1, 0, 0, math.min(360, 36 + rows * (CARD_H + GAP)))
		gridScroll.BackgroundTransparency = 1
		gridScroll.BorderSizePixel = 0
		gridScroll.ScrollBarThickness = 4
		gridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		gridScroll.Parent = gridHost
		corner(gridScroll, 8)
		reg(gridScroll, "BackgroundColor3", "bg")

		local gridPad = Instance.new("UIPadding")
		gridPad.PaddingTop = UDim.new(0, GAP)
		gridPad.PaddingBottom = UDim.new(0, GAP)
		gridPad.PaddingLeft = UDim.new(0, GAP)
		gridPad.PaddingRight = UDim.new(0, GAP)
		gridPad.Parent = gridScroll

		local gridInner = Instance.new("Frame")
		gridInner.Size = UDim2.new(1, -(GAP * 2), 0, 0)
		gridInner.AutomaticSize = Enum.AutomaticSize.Y
		gridInner.BackgroundTransparency = 1
		gridInner.Parent = gridScroll

		local gridLayout = Instance.new("UIListLayout")
		gridLayout.FillDirection = Enum.FillDirection.Horizontal
		gridLayout.Wraps = true
		gridLayout.Padding = UDim.new(0, GAP)
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = gridInner

		local sorted = table.clone(list)
		table.sort(sorted, function(a, b)
			local ar = Registry.entryMatchesCurrent(a)
			local br = Registry.entryMatchesCurrent(b)
			if ar ~= br then
				return ar
			end
			return a.name < b.name
		end)

		for order, entry in sorted do
			local isCurrent = Registry.entryMatchesCurrent(entry)
			local btn = Instance.new("TextButton")
			btn.Name = entry.id
			btn.LayoutOrder = order
			btn.BackgroundTransparency = 0
			btn.Text = ""
			btn.AutoButtonColor = false
			btn.Size = UDim2.fromOffset(CARD_W, CARD_H)
			btn.ClipsDescendants = true
			btn.Parent = gridInner
			corner(btn, 10)
			reg(btn, "BackgroundColor3", "inact")

			local stroke = Instance.new("UIStroke")
			stroke.Thickness = if isCurrent then 2 else 1
			stroke.Transparency = if isCurrent then 0.1 else 0.55
			stroke.Parent = btn
			if isCurrent then
				stroke.Color = curTheme.pri
			else
				reg(stroke, "Color", "out")
			end

			local state = Instance.new("Frame")
			state.Size = UDim2.fromScale(1, 1)
			state.BackgroundTransparency = 1
			state.BorderSizePixel = 0
			state.ZIndex = 2
			state.Parent = btn
			corner(state, 10)
			reg(state, "BackgroundColor3", "fg")

			local thumb = Instance.new("ImageLabel")
			thumb.Size = UDim2.new(1, -(INSET * 2), 0, 72)
			thumb.Position = UDim2.new(0, INSET, 0, INSET)
			thumb.BackgroundTransparency = 1
			thumb.Image = formatThumb(entry.thumbnail)
			thumb.ScaleType = Enum.ScaleType.Crop
			thumb.ZIndex = 3
			thumb.Parent = btn
			corner(thumb, 8)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, -8, 0, 24)
			nameLbl.AnchorPoint = Vector2.new(0.5, 1)
			nameLbl.Position = UDim2.new(0.5, 0, 1, -INSET)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = entry.name
			nameLbl.FontFace = m3Font
			nameLbl.TextSize = 12
			nameLbl.TextWrapped = true
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.TextYAlignment = Enum.TextYAlignment.Top
			nameLbl.ZIndex = 3
			nameLbl.Parent = btn
			reg(nameLbl, "TextColor3", "fg")

			if isCurrent then
				local badge = Instance.new("TextLabel")
				badge.Size = UDim2.new(0, 72, 0, 18)
				badge.Position = UDim2.new(0, INSET, 0, INSET)
				badge.BackgroundTransparency = 0
				badge.Text = "This game"
				badge.FontFace = fontWeight(Enum.FontWeight.Bold)
				badge.TextSize = 10
				badge.ZIndex = 4
				badge.Parent = btn
				corner(badge, 6)
				reg(badge, "BackgroundColor3", "pri")
				reg(badge, "TextColor3", "onpri")
			end

			btn.MouseEnter:Connect(function()
				tween(state, "BackgroundTransparency", 0.92, 0.12)
				playFeedback("hover")
			end)
			btn.MouseLeave:Connect(function()
				tween(state, "BackgroundTransparency", 1, 0.12)
			end)
			btn.MouseButton1Click:Connect(function()
				ripple(btn, curTheme.pri)
				playFeedback("selection")
				launchEntry(entry)
			end)

			if tooltip then
				tooltip.attach(btn, function()
					return buildScriptTooltip(entry)
				end, { delay = 0.35 })
			end

			regDynamic(function(theme, dur)
				if isCurrent then
					if dur > 0 then
						tween(stroke, "Color", theme.pri, dur)
					else
						stroke.Color = theme.pri
					end
				end
			end)
		end
	end
end
