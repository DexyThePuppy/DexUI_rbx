--!nonstrict
-- DexUI showcase: a consumer of the bundled library. Demonstrates every component.
local DexUI = require("./init")

local function buildDemo(withIntro: boolean?)
	local ui = DexUI.CreateWindow("DexUI Example")
	ui:SetReloadCallback(function()
		-- Full reset: rebuild the whole UI from scratch and replay the intro.
		buildDemo(true)
	end)

	--// Tab 1: Components -----------------------------------------------------
	ui:AddTab("Visuals", 4483362458)

	ui:AddSection("Inputs")
	ui:AddTextBox("Textbox Example", function(text, enter)
		if enter then
			print("[DexUI] TextBox Saved: " .. text)
		end
	end)
	ui:AddSlider("Slider Example", 0, 100, 50, function(v)
		print("[DexUI] Slider Value Changed: " .. string.format("%.0f", v))
	end)
	ui:AddSwitch("Switch Example", true, function(s)
		print("[DexUI] Switch Toggled: " .. tostring(s))
	end, "Enable real-time widget updates")
	ui:AddDropdown("Dropdown Example", { "Blue", "Purple", "Green", "Orange", "Red" }, "Blue", function(option)
		print("[DexUI] Dropdown: " .. option)
		ui:ChangePalette(option)
	end)

	ui:AddDivider()

	ui:AddSection("Actions")
	ui:AddButton("Button Example", function()
		ui:Notify({ Title = "Button", Content = "Material 3 button clicked!", Duration = 3 })
	end)
	ui:AddKeybind("Keybind Example", Enum.KeyCode.B, function()
		ui:Notify({ Title = "Keybind", Content = "Key pressed!", Duration = 2 })
	end, "Press to trigger the bound action")
	ui:AddColorPicker("Color Example", Color3.fromRGB(162, 201, 255), function(color)
		print("[DexUI] Color:", color)
	end, "Choose an accent colour")

	--// Tab 2: Info ----------------------------------------------------------
	ui:AddTab("Info", 4483345998)
	ui:AddLabel("Label Example", 4483362458)
	ui:AddParagraph(
		"DexUI",
		"This interface uses Material Design 3 components built entirely in code, with ripple feedback, "
			.. "state layers and Material 3 motion."
	)

	--// Tab 3: Media (Creator Store) -------------------------------------------
	ui:AddTab("Media", 6026671208) -- video_library
	ui:AddMediaBrowser()

	--// Tab 4: Scripts hub -----------------------------------------------------
	ui:AddTab("Scripts", 6023426986) -- find_in_page
	ui:AddParagraph(
		"Scripts hub",
		"Grid of games from scripts/index.lua. Click a card to run that game's standalone script in a new DexUI window."
	)
	ui:PopulateScriptsHub()

	--// Tab 5: Tools ---------------------------------------------------------
	ui:AddTab("Tools", 6031289442) -- settings_remote
	ui:AddParagraph(
		"Tools",
		"External developer utilities. Click a card to download and run the latest release. Right-click a card to copy its GitHub link."
	)
	ui:PopulateToolsHub()

	--// Tab 6: Game info -----------------------------------------------------
	ui:AddTab("Game Info", 6026568227) -- info
	ui:AddGameInfo()

	--// Tab 7: Icons (Material Icons library) --------------------------------
	ui:AddTab("Icons", 6031302950)
	ui:AddParagraph(
		"Material Icons",
		"Browse the Material Icons plugin catalog (~1.4k icons). Search by name or scroll the grid — "
			.. "click any icon to copy its asset ID and rbxassetid string to your clipboard."
	)
	ui:AddIconBrowser()

	if withIntro ~= false then
		ui:PlayIntro({
			OnComplete = function()
				ui:Notify({
					Title = "DexUI",
					Content = "Loaded. Drag the title bar, resize from any edge, or use the search icon.",
					Duration = 5,
				})
			end,
		})
	else
		ui:Show()
		ui:Notify({
			Title = "DexUI",
			Content = "UI reloaded.",
			Duration = 3,
		})
	end

	return ui
end

buildDemo(true)
