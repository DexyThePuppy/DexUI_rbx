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
	local textSize = ctx.textSize
	local HubGrid = ctx.hubGrid

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
		local spec = HubGrid.specForCell(HubGrid.scriptsCell)

		local holder = Instance.new("Frame")
		holder.Name = "ScriptsHub"
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.Parent = beginCardRow(nil, true)

		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, 0, 0, 0)
		header.AutomaticSize = Enum.AutomaticSize.Y
		header.BackgroundTransparency = 1
		header.Text = if recognized
			then ("Recognised: " .. recognized.name .. " — pick a script or launch yours")
			else "Scripts hub — select a game"
		header.FontFace = fontWeight(Enum.FontWeight.Medium)
		header.TextSize = textSize("sm")
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextWrapped = true
		header.Parent = holder
		reg(header, "TextColor3", "out")

		local gridHost = Instance.new("Frame")
		gridHost.Size = UDim2.new(1, 0, 0, 0)
		gridHost.AutomaticSize = Enum.AutomaticSize.Y
		gridHost.BackgroundTransparency = 1
		gridHost.Parent = holder

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = holder
		header.LayoutOrder = 0
		gridHost.LayoutOrder = 1

		local grid = HubGrid.createGridHost(gridHost, spec, 400, corner, reg)

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
			local btn, _thumbWrap, thumb, nameLbl = HubGrid.createCard(grid.inner, spec, order, corner)
			btn.Name = entry.id
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

			local state = HubGrid.addStateLayer(btn, spec, corner, reg)

			thumb.Image = formatThumb(entry.thumbnail)
			nameLbl.Text = entry.name
			nameLbl.FontFace = m3Font
			nameLbl.TextSize = textSize("sm")
			reg(nameLbl, "TextColor3", "fg")

			if isCurrent then
				local badge = Instance.new("TextLabel")
				badge.Size = UDim2.new(0, 64, 0, 16)
				badge.Position = UDim2.new(0, 4, 0, 4)
				badge.BackgroundTransparency = 0
				badge.Text = "This game"
				badge.FontFace = fontWeight(Enum.FontWeight.Bold)
				badge.TextSize = textSize("sm")
				badge.ZIndex = 4
				badge.Parent = thumb.Parent
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

		grid.setCount(#sorted)
	end
end
