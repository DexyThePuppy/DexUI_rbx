--!nonstrict
-- Tools hub grid: external utilities loaded from release URLs.

local ToolsRegistry = require("../hub/tools-registry")
local ToolAssets = require("../hub/tool-assets")
local runTool = require("../hub/run-tool")

export type ToolEntry = ToolsRegistry.ToolEntry

return function(ctx)
	local lib = ctx.lib
	local curTheme = ctx.theme
	local reg = ctx.reg
	local tween, corner, ripple = ctx.tween, ctx.corner, ctx.ripple
	local m3Font = ctx.m3Font
	local beginCardRow = ctx.beginCardRow
	local playFeedback = ctx.playFeedback
	local fontWeight = ctx.fontWeight
	local tooltip = ctx.tooltip
	local trySetClipboard = ctx.trySetClipboard
	local textSize = ctx.textSize
	local HubGrid = ctx.hubGrid

	local launching: { [string]: boolean } = {}

	local function formatThumb(url: string): string
		return ToolAssets.resolveToolThumbnail(url)
	end

	local function buildToolTooltip(entry: ToolEntry): any
		local blocks: { any } = {
			{ kind = "title", text = entry.name },
		}
		if entry.description and entry.description ~= "" then
			table.insert(blocks, { kind = "text", text = entry.description })
		end
		table.insert(blocks, { kind = "divider" })
		if entry.repo then
			table.insert(blocks, { kind = "stat", label = "Repository", value = entry.repo })
		end
		table.insert(blocks, { kind = "stat", label = "Script URL", value = entry.url })
		table.insert(blocks, { kind = "text", text = "Click to download and run.", muted = true })
		return { blocks = blocks, maxWidth = 300 }
	end

	local function launchTool(entry: ToolEntry)
		if launching[entry.id] then
			return
		end
		launching[entry.id] = true
		lib:Notify({ Title = entry.name, Content = "Downloading…", Duration = 2 })
		task.spawn(function()
			local ok, err = runTool(entry)
			launching[entry.id] = nil
			if not ok then
				lib:Notify({
					Title = "Tool failed",
					Content = err or ("Could not run " .. entry.name),
					Duration = 6,
				})
				return
			end
			lib:Notify({
				Title = entry.name,
				Content = "Tool loaded.",
				Duration = 2.5,
			})
		end)
	end

	function lib:PopulateToolsHub(entries: { ToolEntry }?)
		local list = entries or ToolsRegistry.load()
		local spec = HubGrid.specForCell(HubGrid.toolsCell)

		local holder = Instance.new("Frame")
		holder.Name = "ToolsHub"
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.Parent = beginCardRow(nil, true)

		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, 0, 0, 0)
		header.AutomaticSize = Enum.AutomaticSize.Y
		header.BackgroundTransparency = 1
		header.Text = "Developer tools — click a card to load"
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
		gridHost.Size = UDim2.new(1, 0, 0, 0)

		local sorted = table.clone(list)
		table.sort(sorted, function(a, b)
			return a.name < b.name
		end)

		for order, entry in sorted do
			local btn, _thumbWrap, thumb, nameLbl = HubGrid.createCard(grid.inner, spec, order, corner)
			btn.Name = entry.id
			reg(btn, "BackgroundColor3", "inact")

			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1
			stroke.Transparency = 0.55
			stroke.Parent = btn
			reg(stroke, "Color", "out")

			local state = HubGrid.addStateLayer(btn, spec, corner, reg)

			thumb.Image = formatThumb(entry.thumbnail)
			ToolAssets.resolveToolThumbnailAsync(entry.thumbnail, function(uri)
				if thumb.Parent and uri and uri ~= ToolAssets.PLACEHOLDER then
					thumb.Image = uri
				end
			end)

			nameLbl.Text = entry.name
			nameLbl.FontFace = fontWeight(Enum.FontWeight.Medium)
			nameLbl.TextSize = textSize("sm")
			reg(nameLbl, "TextColor3", "fg")

			local extBadge = Instance.new("TextLabel")
			extBadge.Size = UDim2.new(0, 52, 0, 16)
			extBadge.Position = UDim2.new(1, -4, 0, 4)
			extBadge.AnchorPoint = Vector2.new(1, 0)
			extBadge.BackgroundTransparency = 0
			extBadge.Text = "External"
			extBadge.FontFace = fontWeight(Enum.FontWeight.Bold)
			extBadge.TextSize = textSize("sm")
			extBadge.ZIndex = 4
			extBadge.Parent = thumb.Parent
			corner(extBadge, 6)
			reg(extBadge, "BackgroundColor3", "pri")
			reg(extBadge, "TextColor3", "onpri")

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
				launchTool(entry)
			end)

			if tooltip then
				tooltip.attach(btn, function()
					return buildToolTooltip(entry)
				end, { delay = 0.35 })
			end

			if entry.repo and trySetClipboard then
				btn.MouseButton2Click:Connect(function()
					if trySetClipboard(entry.repo :: string) then
						lib:Notify({ Title = "Copied", Content = "Repository link", Duration = 2 })
					end
				end)
			end
		end

		grid.setCount(#sorted)
	end
end
