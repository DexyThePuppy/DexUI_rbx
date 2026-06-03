--!nonstrict
-- DexUI entry point. darklua bundles every require below into dist/dexui.lua,
-- which returns this table for the executor to loadstring:
--
--   local DexUI = loadstring(game:HttpGet(".../dist/dexui.lua"))()
--   local win = DexUI.CreateWindow("My Script")
--   win:AddTab("Main", 4483362458)
--   win:AddButton("Click", function() end)

local Config = require("./config")
local makeUI = require("./window/window")

local DexUI = {
	Version = Config.Version,
}

function DexUI.CreateWindow(title: string?)
	local ui = makeUI(title)
	ui._dexuiModule = DexUI
	return ui
end

function DexUI.CreateHub(title: string?)
	local ui = makeUI(title or "DexUI Hub", { hub = true })
	ui._dexuiModule = DexUI
	ui:PopulateScriptsHub()
	return ui
end

return DexUI
