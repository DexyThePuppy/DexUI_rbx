-- DexUI hub registry (scripts + external tools).
--
-- scripts: standalone .lua files (paths relative to scripts/).
-- tools: load from `url` on click. thumbnail supports GitHub raw URLs, rbxassetid://, asset:cobalt, asset:dexplusplus.

return {
	scripts = {
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
			script = "games/fabrik-tycoon.lua",
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
			script = "tools/dexui-demo.lua",
		},
	},

	tools = {
		{
			id = "dexplusplus",
			name = "Dex++",
			description = "Extended Moon Dex explorer — decompiler, save instance, model viewer, console, and mobile input.",
			thumbnail = "https://github.com/AZYsGithub/DexPlusPlus/blob/main/preview.png",
			url = "https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua",
			repo = "https://github.com/AZYsGithub/DexPlusPlus",
		},
		{
			id = "cobalt",
			name = "Cobalt",
			description = "Remote spy — monitor and intercept incoming/outgoing network traffic with replay and blocking.",
			thumbnail = "asset:cobalt",
			url = "https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau",
			repo = "https://github.com/notpoiu/cobalt",
		},
	},
}
