--!nonstrict
-- Material 3 dark palettes + the Palette type used throughout DexUI.

export type Palette = {
	bg: Color3, -- surface / window background
	fg: Color3, -- on-surface text
	pri: Color3, -- primary accent
	onpri: Color3, -- on-primary (text/icon on accent)
	inact: Color3, -- surface-variant / inactive container
	out: Color3, -- outline / muted text
}

local PALETTES: { [string]: Palette } = {
	Purple     = { bg = Color3.fromRGB(28, 27, 31),  fg = Color3.fromRGB(230, 225, 229), pri = Color3.fromRGB(208, 188, 255), onpri = Color3.fromRGB(56, 30, 114),  inact = Color3.fromRGB(43, 41, 48), out = Color3.fromRGB(147, 143, 153) },
	Blue       = { bg = Color3.fromRGB(26, 28, 30),  fg = Color3.fromRGB(226, 226, 230), pri = Color3.fromRGB(162, 201, 255), onpri = Color3.fromRGB(0, 50, 90),     inact = Color3.fromRGB(40, 42, 46), out = Color3.fromRGB(141, 145, 153) },
	Red        = { bg = Color3.fromRGB(32, 26, 25),  fg = Color3.fromRGB(237, 224, 222), pri = Color3.fromRGB(255, 180, 168), onpri = Color3.fromRGB(105, 0, 5),     inact = Color3.fromRGB(50, 40, 38), out = Color3.fromRGB(160, 140, 137) },
	Green      = { bg = Color3.fromRGB(26, 28, 25),  fg = Color3.fromRGB(225, 227, 223), pri = Color3.fromRGB(143, 215, 135), onpri = Color3.fromRGB(0, 57, 10),     inact = Color3.fromRGB(40, 43, 40), out = Color3.fromRGB(142, 145, 143) },
	Orange     = { bg = Color3.fromRGB(32, 27, 24),  fg = Color3.fromRGB(236, 224, 219), pri = Color3.fromRGB(255, 183, 123), onpri = Color3.fromRGB(76, 38, 0),     inact = Color3.fromRGB(50, 42, 38), out = Color3.fromRGB(159, 141, 132) },
	PitchBlack = { bg = Color3.fromRGB(0, 0, 0),     fg = Color3.fromRGB(230, 225, 229), pri = Color3.fromRGB(208, 188, 255), onpri = Color3.fromRGB(56, 30, 114),  inact = Color3.fromRGB(28, 28, 30), out = Color3.fromRGB(147, 143, 153) },
}

return PALETTES
