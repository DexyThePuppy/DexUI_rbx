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

		local holder = Instance.new("Frame")
		holder.Name = "ToolsHub"
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.Parent = beginCardRow(nil, true)

		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, 0, 0, 22)
		header.BackgroundTransparency = 1
		header.Text = "Developer tools — click a card to load"
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

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = holder
		header.LayoutOrder = 0
		gridHost.LayoutOrder = 1

		local cols = math.max(2, math.min(4, math.ceil(math.sqrt(#list))))
		local rows = math.max(1, math.ceil(#list / cols))
		local gridScroll = Instance.new("ScrollingFrame")
		gridScroll.Size = UDim2.new(1, 0, 0, math.min(420, 64 + rows * 152))
		gridScroll.BackgroundTransparency = 1
		gridScroll.BorderSizePixel = 0
		gridScroll.ScrollBarThickness = 4
		gridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		gridScroll.Parent = gridHost
		corner(gridScroll, 12)
		reg(gridScroll, "BackgroundColor3", "bg")

		local gridPad = Instance.new("UIPadding")
		gridPad.PaddingTop = UDim.new(0, 6)
		gridPad.PaddingBottom = UDim.new(0, 6)
		gridPad.PaddingLeft = UDim.new(0, 6)
		gridPad.PaddingRight = UDim.new(0, 6)
		gridPad.Parent = gridScroll

		local gridInner = Instance.new("Frame")
		gridInner.Size = UDim2.new(1, -12, 0, 0)
		gridInner.AutomaticSize = Enum.AutomaticSize.Y
		gridInner.BackgroundTransparency = 1
		gridInner.Parent = gridScroll

		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellSize = UDim2.fromOffset(136, 152)
		gridLayout.CellPadding = UDim2.fromOffset(6, 6)
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = gridInner

		local sorted = table.clone(list)
		table.sort(sorted, function(a, b)
			return a.name < b.name
		end)

		for order, entry in sorted do
			local btn = Instance.new("TextButton")
			btn.Name = entry.id
			btn.LayoutOrder = order
			btn.BackgroundTransparency = 0
			btn.Text = ""
			btn.AutoButtonColor = false
			btn.ClipsDescendants = true
			btn.Parent = gridInner
			corner(btn, 14)
			reg(btn, "BackgroundColor3", "inact")

			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1
			stroke.Transparency = 0.55
			stroke.Parent = btn
			reg(stroke, "Color", "out")

			local state = Instance.new("Frame")
			state.Size = UDim2.fromScale(1, 1)
			state.BackgroundTransparency = 1
			state.BorderSizePixel = 0
			state.ZIndex = 2
			state.Parent = btn
			corner(state, 14)
			reg(state, "BackgroundColor3", "fg")

			local thumb = Instance.new("ImageLabel")
			thumb.Name = "Thumbnail"
			thumb.Size = UDim2.new(1, -12, 0, 88)
			thumb.Position = UDim2.new(0, 6, 0, 6)
			thumb.BackgroundTransparency = 1
			thumb.Image = formatThumb(entry.thumbnail)
			thumb.ScaleType = Enum.ScaleType.Crop
			ToolAssets.resolveToolThumbnailAsync(entry.thumbnail, function(uri)
				if thumb.Parent and uri and uri ~= ToolAssets.PLACEHOLDER then
					thumb.Image = uri
				end
			end)
			thumb.ZIndex = 3
			thumb.Active = false
			thumb.Selectable = false
			thumb.Parent = btn
			corner(thumb, 10)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, -10, 0, 40)
			nameLbl.AnchorPoint = Vector2.new(0.5, 1)
			nameLbl.Position = UDim2.new(0.5, 0, 1, -6)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = entry.name
			nameLbl.FontFace = fontWeight(Enum.FontWeight.Medium)
			nameLbl.TextSize = 12
			nameLbl.TextWrapped = true
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.TextYAlignment = Enum.TextYAlignment.Top
			nameLbl.ZIndex = 3
			nameLbl.Active = false
			nameLbl.Selectable = false
			nameLbl.Parent = btn
			reg(nameLbl, "TextColor3", "fg")

			local extBadge = Instance.new("TextLabel")
			extBadge.Size = UDim2.new(0, 56, 0, 18)
			extBadge.Position = UDim2.new(1, -6, 0, 6)
			extBadge.AnchorPoint = Vector2.new(1, 0)
			extBadge.BackgroundTransparency = 0
			extBadge.Text = "External"
			extBadge.FontFace = fontWeight(Enum.FontWeight.Bold)
			extBadge.TextSize = 9
			extBadge.ZIndex = 4
			extBadge.Active = false
			extBadge.Selectable = false
			extBadge.Parent = btn
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
	end
end
