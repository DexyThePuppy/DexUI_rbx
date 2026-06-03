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

return {
	Version = Config.Version,
	CreateWindow = function(title: string?)
		return makeUI(title)
	end,
}
