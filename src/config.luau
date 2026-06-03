--!nonstrict
-- Brand + constant configuration for DexUI.

return {
	-- Branding
	Brand = "DexUI",
	GuiName = "DexUI",
	Version = "1.0.0",

	-- Intro
	IntroSound = "rbxassetid://118754269860019",
	IntroBrand = "DexUI",

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
		TextSize = 22,
		CornerRadius = 10,
		StackAnchor = Vector2.new(1, 0.5),
		StackPosition = UDim2.new(1, -16, 0.5, 0),
		StackZIndex = 50,
		Background = { Color = "inact", Transparency = 0.18 },
		Border = { Color = "pri", Thickness = 1.5, Transparency = 0.35 },
		Text = { Color = "fg", Gradient = "rainbow" },
		TextStroke = { Color = "pri", Thickness = 3.5, Transparency = 0, Gradient = "rainbow" },
		Rainbow = { HueStep = 0.06, FillHueSpan = 0.045, FillStops = 6 },
	},
}
