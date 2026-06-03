-- DexUI tools registry. Each entry loads from `url` on click (GitHub release recommended).
-- thumbnail / image supports:
--   https://github.com/owner/repo/blob/branch/path.png  (converted to raw GitHub)
--   https://raw.githubusercontent.com/owner/repo/branch/path.png
--   rbxassetid://, rbxthumb://, asset:dexplusplus (bundled PNG fallback)

return {
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
		thumbnail = "https://github.com/notpoiu/cobalt/blob/main/Assets/Logo.png",
		url = "https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau",
		repo = "https://github.com/notpoiu/cobalt",
	},
}
