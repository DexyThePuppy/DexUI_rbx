--!nonstrict
-- Tools hub grid: external utilities loaded from release URLs.

local Config = require("../config")
local ToolsRegistry = require("../hub/tools-registry")
local SL = Config.SectionLayout or Config.GameInfo or {}
local ToolAssets = require("../hub/tool-assets")
local runTool = require("../hub/run-tool")

export type ToolEntry = ToolsRegistry.ToolEntry

return function(ctx)
	local lib = ctx.lib
	local curTheme = ctx.theme
	local reg = ctx.reg
	local tween, corner, ripple = ctx.tween, ctx.corner, ctx.ripple
	local nextCardItemOrder = ctx.nextCardItemOrder
	local playFeedback = ctx.playFeedback
	local fontWeight = ctx.fontWeight
	local fontLarge = ctx.fontLarge
	local tooltip = ctx.tooltip
	local trySetClipboard = ctx.trySetClipboard
	local textSize = ctx.textSize
	local Grid = ctx.grid

	local gridDeps = { corner = corner, reg = reg, fontWeight = fontWeight, textSize = textSize }
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

		local panelDeps = {
			corner = corner,
			reg = reg,
			fontLarge = fontLarge,
			textSize = textSize,
			padding = SL.SectionPadding or 14,
			innerGap = SL.InnerGap or 8,
			cornerRadius = SL.SectionCorner or 12,
			titleGap = SL.TitleGap or 6,
		}
		local _, mount = Grid.buildPanelSection(lib.CurrentBuildContainer, nextCardItemOrder(), panelDeps, gridDeps, {
			name = "ToolsHub",
			title = "Developer tools — click a card to load",
			maxHeight = Grid.spec.maxViewport,
		})

		local sorted = table.clone(list)
		table.sort(sorted, function(a, b)
			return a.name < b.name
		end)

		for order, entry in sorted do
			local card = mount.addCard(order)
			card.root.Name = entry.id
			reg(card.root, "BackgroundColor3", "inact")

			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 1
			stroke.Transparency = 0.55
			stroke.Parent = card.root
			reg(stroke, "Color", "out")

			card.image.Image = formatThumb(entry.thumbnail)
			ToolAssets.resolveToolThumbnailAsync(entry.thumbnail, function(uri)
				if card.image.Parent and uri and uri ~= ToolAssets.PLACEHOLDER then
					card.image.Image = uri
				end
			end)

			card.title.Text = entry.name
			card.title.FontFace = fontWeight(Enum.FontWeight.Medium)
			card.title.TextSize = textSize("sm")
			reg(card.title, "TextColor3", "fg")

			local extBadge = Instance.new("TextLabel")
			extBadge.Size = UDim2.fromOffset(52, 16)
			extBadge.Position = UDim2.new(1, -4, 0, 4)
			extBadge.AnchorPoint = Vector2.new(1, 0)
			extBadge.BackgroundTransparency = 0
			extBadge.Text = "External"
			extBadge.FontFace = fontWeight(Enum.FontWeight.Bold)
			extBadge.TextSize = textSize("sm")
			extBadge.ZIndex = 5
			extBadge.Parent = card.thumb
			corner(extBadge, 6)
			reg(extBadge, "BackgroundColor3", "pri")
			reg(extBadge, "TextColor3", "onpri")

			card.root.MouseEnter:Connect(function()
				tween(card.state, "BackgroundTransparency", 0.92, 0.12)
				playFeedback("hover")
			end)
			card.root.MouseLeave:Connect(function()
				tween(card.state, "BackgroundTransparency", 1, 0.12)
			end)
			card.root.MouseButton1Click:Connect(function()
				ripple(card.root, curTheme.pri)
				playFeedback("selection")
				launchTool(entry)
			end)

			if tooltip then
				tooltip.attach(card.root, function()
					return buildToolTooltip(entry)
				end, { delay = 0.35 })
			end

			if entry.repo and trySetClipboard then
				card.root.MouseButton2Click:Connect(function()
					if trySetClipboard(entry.repo :: string) then
						lib:Notify({ Title = "Copied", Content = "Repository link", Duration = 2 })
					end
				end)
			end
		end

		task.defer(mount.sync)
	end
end
