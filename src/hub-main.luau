--!nonstrict
-- Standalone DexUI scripts hub (no tabs): title bar + game grid from scripts/index.lua.
--
--   loadstring(readfile("dist/hub.lua"))()
-- Place scripts/index.lua and game scripts under scripts/ next to this file.

local DexUI = require("./init")

local hub = DexUI.CreateHub("DexUI Scripts Hub")
hub:Show()

hub:Notify({
	Title = "DexUI Hub",
	Content = "Select a game to launch its script. Entries load from scripts/index.lua.",
	Duration = 5,
})
