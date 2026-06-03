-- DexUI scripts hub registry. Each entry maps to a standalone .lua file in this folder.
-- Match the current experience via placeIds and/or universeIds (empty = hub-only, no auto-highlight).

return {
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
