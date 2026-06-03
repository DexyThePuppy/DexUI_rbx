--!nonstrict
-- Centralised Roblox service handles shared across every DexUI module.

local Players = game:GetService("Players")

return {
	TweenService = game:GetService("TweenService"),
	UserInputService = game:GetService("UserInputService"),
	RunService = game:GetService("RunService"),
	Players = Players,
	HttpService = game:GetService("HttpService"),
	SoundService = game:GetService("SoundService"),
	GuiService = game:GetService("GuiService"),
	ContextActionService = game:GetService("ContextActionService"),
	AssetService = game:GetService("AssetService"),
	Workspace = game:GetService("Workspace"),
	CoreGui = (game:GetService("CoreGui") :: Instance) or Players.LocalPlayer:WaitForChild("PlayerGui"),
}
