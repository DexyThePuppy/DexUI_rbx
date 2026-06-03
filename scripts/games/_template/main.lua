--[[
  Starter for a new hub script — copy to scripts/<your-game>.lua and add an entry in scripts/index.lua.

  Pattern (same as fabrik-tycoon.lua / dexui-demo.lua):
    - Single file, no SDK or extra modules
    - getgenv().DexUI is set by the hub before execute
    - Use DexUI.CreateWindow and components only
]]

local DexUI = (getgenv and getgenv().DexUI) or nil
if not DexUI then
	error("[my-game] DexUI not found — launch from the scripts hub.")
end

local Config = { Enabled = false, LoopDelay = 0.5 }

local ui = DexUI.CreateWindow("My Game — DexUI")
ui:AddTab("Main", 4483362458)
ui:AddSection("Automation")
ui:AddSwitch("Master", Config.Enabled, function(v)
	Config.Enabled = v
	if ui.PlayFeedback then
		ui:PlayFeedback(v and "toggleOn" or "toggleOff")
	end
end)
ui:AddDivider()
ui:AddSection("Danger")
ui:AddButton("Unload", function()
	Config.Enabled = false
	ui:Destroy()
end)
ui:Show()

ui:Notify({ Title = "My Game", Content = "Loaded — enable Master when ready.", Duration = 3 })

local RS = game:GetService("RunService")
local loopAcc = 0
RS.Heartbeat:Connect(function(dt)
	if not Config.Enabled then
		return
	end
	loopAcc += dt
	if loopAcc < Config.LoopDelay then
		return
	end
	loopAcc = 0
	-- game logic per tick
end)
