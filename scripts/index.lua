-- DexUI scripts hub registry. Each entry maps to a standalone .lua file in this folder.
-- Match the current experience via placeIds and/or universeIds (empty = hub-only, no auto-highlight).

return {
	{
		id = "fabrik-tycoon",
		name = "[UPD] Fabrik-Tycoon",
		thumbnail = "rbxthumb://type=Place&id=15197136141&w=420&h=420",
		placeIds = { 15197136141 },
		universeIds = {},
		images = {
			"rbxthumb://type=Place&id=15197136141&w=768&h=432",
		},
		description = "Auto collect, buy buildings, gem upgrades, rebirth, manual droppers, and ad hiding for Fabrik-Tycoon.",
		script = "fabrik-tycoon.lua",
	},
	{
		id = "dexui-demo",
		name = "DexUI Demo",
		thumbnail = "rbxthumb://type=Place&id=95206881&w=420&h=420",
		placeIds = {},
		universeIds = {},
		images = {
			"rbxthumb://type=Place&id=95206881&w=768&h=432",
		},
		description = "Example script shipped with DexUI. Opens a small Material 3 window with a notify button.",
		script = "dexui-demo.lua",
	},
}
