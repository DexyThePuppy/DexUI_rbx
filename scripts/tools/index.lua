-- DexUI tools registry. Each entry loads from `url` on click (GitHub release recommended).
-- thumbnail: GitHub blob/raw, rbxassetid, or asset:id (bundled PNG in assets/tools/)
-- thumbnailFallback: used when the primary thumbnail cannot be loaded

return {
	{
		id = "dexplusplus",
		name = "Dex++",
		description = "Extended Moon Dex explorer — decompiler, save instance, model viewer, console, and mobile input.",
		thumbnail = "https://github.com/AZYsGithub/DexPlusPlus/blob/main/preview.png",
		thumbnailFallback = "asset:dexplusplus",
		url = "https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua",
		repo = "https://github.com/AZYsGithub/DexPlusPlus",
	},
	{
		id = "cobalt",
		name = "Cobalt",
		description = "Remote spy — monitor and intercept incoming/outgoing network traffic with replay and blocking.",
		thumbnail = "asset:cobalt",
		thumbnailFallback = "https://github.com/notpoiu/cobalt/blob/main/Assets/Logo.png",
		url = "https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau",
		repo = "https://github.com/notpoiu/cobalt",
	},
}
