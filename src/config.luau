--!nonstrict
-- Brand + constant configuration for DexUI.

return {
	-- Branding
	Brand = "DexUI",
	GuiName = "DexUI",
	Version = "1.0.0",

	-- MUI/M3-style type scale: fixed tiers + per-role weights (see core/typography.luau).
	-- WeightAdjustment: Android-style +N on each role (0 = off).
	-- Family: Roblox built-in Builder Sans (per-weight masters; distinct from Roboto).
	-- ChromeWeight: tabs/small UI — emphasis matches body tier when everything is bold.
	Typography = {
		Family = "rbxasset://fonts/families/BuilderSans.json",
		ChromeWeight = "emphasis", -- tabs: regular | medium | bold | emphasis
		-- false = built-in family masters only; true = force legacy TTF download; nil = auto
		Small = 12, -- caption / helper
		Medium = 14, -- body (MUI default)
		Large = 22, -- section titles (M3 Title Large)
		WeightAdjustment = 400,
		Weight = {
			Body = 600, -- → Heavy (900) with +400
			Emphasis = 600, -- buttons, chips, row titles
			Title = 800, -- section headings, paragraph titles
			Display = 900, -- intro / hero moments
		},
	},

	-- Stacked section cards (Game Info, Media, etc.).
	SectionLayout = {
		SectionGap = 12,
		TitleGap = 6,
		SectionPadding = 14,
		InnerGap = 8,
		SectionCorner = 12,
	},

	-- Alias for Game Info mount (same as SectionLayout).
	GameInfo = {
		SectionGap = 12,
		TitleGap = 6,
		SectionPadding = 14,
		InnerGap = 8,
		SectionCorner = 12,
	},

	-- Modular grid layout (card cells; used across tabs and panels).
	Grid = {
		Cell = { 96, 104 },
		ScrollPad = 6,
		CellGap = 8,
		CardInset = 4,
		NameBand = 20,
		GapThumbTitle = 2,
		CardCorner = 10,
		ThumbCorner = 8,
		MaxViewport = 320,
		BadgeIcon = 36,
		ThumbFillBackground = true,
		ThumbBackground = "bg",
	},

	-- Intro
	IntroSound = "rbxassetid://118754269860019",
	IntroBrand = "DexUI",

	-- 3D world-pin panel (SurfaceGui). PixelsPerStud caps sharpness; pin mode also scales
	-- part size to match on-screen footprint (see world-pin studsSizeForScreenPixels).
	WorldPin = {
		PixelsPerStud = 512,
	},

	-- Media browser (Creator Store)
	MediaPageSize = 5,
	MediaPageCount = 6,
	MediaFetchLimit = 30,
	CreatorStoreSearch = "https://apis.roblox.com/toolbox-service/v2/assets:search",

	-- Notification feed (see components/notifications.luau).
	-- Colors can be theme tokens ("pri", "fg", "inact", …) or Color3 values.
	-- Gradients: "rainbow" (shifted per message, anchored to accent hue), "tint", ColorSequence, or false.
	Notifications = {
		Max = 8,
		Life = 4.2,
		FadeIn = 0.22,
		FadeOut = 0.3,
		Slide = 0.24,
		Width = 440,
		Height = 36,
		Gap = 5,
		PadRight = 18,
		PadInner = 12,
		TextSize = 18,
		CornerRadius = 10,
		StackAnchor = Vector2.new(1, 0.5),
		StackPosition = UDim2.new(1, -16, 0.5, 0),
		StackZIndex = 50,
		-- Background/Border tokens apply when Text.Gradient is false; with "rainbow" the card
		-- tint and outline are derived from the same per-toast hue as the label.
		Background = { Color = "inact", Transparency = 0.18 },
		Border = { Color = "pri", Thickness = 1.5, Transparency = 0.35 },
		Text = { Color = "fg", Gradient = "rainbow" },
		TextStroke = { Color = "pri", Thickness = 3.5, Transparency = 0, Gradient = "rainbow" },
		Rainbow = { HueStep = 0.06, FillHueSpan = 0.045, FillStops = 6 },
	},

	-- Notification toast sound (Creator Store asset by default).
	NotificationSound = {
		AssetId = 121045990444676,
		Volume = 0.65,
		RandomPitch = true,
		PitchMin = 0.92,
		PitchMax = 1.08,
		Pitch = 1,
	},

	-- Hover / click / slider UI feedback (0 = built-in switch.wav).
	FeedbackSound = {
		AssetId = 0,
	},
}
