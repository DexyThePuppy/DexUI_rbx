-- Standalone game script for the DexUI hub. Expects getgenv().DexUI (set by the hub before execute).
local DexUI = (getgenv and getgenv().DexUI) or nil
if not DexUI then
	error("[dexui-demo] DexUI not found. Launch this script from the DexUI hub.")
end

local ui = DexUI.CreateWindow("DexUI Demo Script")
ui:AddTab("Main", 4483362458)
ui:AddSection("Hub script")
ui:AddParagraph(
	"Loaded from hub",
	"This window was opened by the scripts hub. It runs without the hub UI and can be executed on its own once DexUI is available."
)
ui:AddButton("Notify", function()
	ui:Notify({ Title = "Demo script", Content = "Running as a standalone hub script.", Duration = 3 })
end)
ui:Show()
