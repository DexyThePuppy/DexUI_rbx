return function(ctx)
	local Config = ctx.config
	local LP = ctx.lp
	local track = ctx.track
	local logInfo, logWarn, logDebug = ctx.log.info, ctx.log.warn, ctx.log.debug
	local setPhase = ctx.log.setPhase
	local getTycoon = ctx.game.getTycoon
	local startupReady = ctx.startupReady
	local lastAdCleanAt = ctx.timers.lastAdCleanAt

	local AD_HIDE_YIELD_EVERY = 40
	local AD_HIDE_MIN_INTERVAL = 2
	local adHideBusy = false
	local adHidePending = false
	local adHideDebounceThread = nil
	local adCleanerConnections = {}

	local function stripGuiAd(obj)
		if obj:IsA("GuiObject") then
			if not obj.Visible then
				return
			end
			obj.Visible = false
			if obj:IsA("GuiButton") then
				obj.Active = false
			end
		end
	end

	local BUILD_MONETIZATION_PROPS = {
	VIPBTN = true,
	["2XMONEYBTN"] = true,
	AUTOCOLLECTBTN = true,
	SHINYBTN = true,
}

local function isBuildMonetizationProp(inst)
	return BUILD_MONETIZATION_PROPS[inst.Name] == true
end

-- The game's ShowAndHide script constantly RESTORES button visuals: parts get
-- Transparency = NumberValue_Transparency.Value and BillboardGuis get Enabled = true.
-- So a one-shot hide gets reverted. We instead neutralize the *restore targets*
-- (NumberValue_Transparency -> 1, BoolValue_Collision -> false) and hide the
-- billboard's child GuiObjects (which ShowAndHide never touches â€” it only flips
-- .Enabled). Result: the pad stays invisible even when the game re-shows it.
local function disableWorldAdInstance(inst)
	if inst:IsA("BasePart") or inst:IsA("UnionOperation") or inst:IsA("MeshPart") then
		local nt = inst:FindFirstChild("NumberValue_Transparency")
		if nt and nt:IsA("ValueBase") then nt.Value = 1 end
		local col = inst:FindFirstChild("BoolValue_Collision")
		if col and col:IsA("ValueBase") then col.Value = false end
		inst.Transparency = 1
		inst.LocalTransparencyModifier = 1
		inst.CanCollide = false
		inst.CanTouch = false
		inst.CanQuery = false
		inst:SetAttribute("__FabrikAdHidden2", true)
	elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
		-- Hide the actual ad content permanently; ShowAndHide only resets .Enabled.
		for _, g in inst:GetDescendants() do
			if g:IsA("GuiObject") then g.Visible = false end
		end
		inst.Enabled = false
		inst:SetAttribute("__FabrikAdHidden2", true)
	elseif inst:IsA("ProximityPrompt") then
		inst.Enabled = false
		inst:SetAttribute("__FabrikAdHidden2", true)
	elseif inst:IsA("ClickDetector") then
		inst.MaxActivationDistance = 0
		inst:SetAttribute("__FabrikAdHidden2", true)
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
		inst.Enabled = false
		inst:SetAttribute("__FabrikAdHidden2", true)
	elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
		inst.Enabled = false
		inst:SetAttribute("__FabrikAdHidden2", true)
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		local nt = inst:FindFirstChild("NumberValue_Transparency")
		if nt and nt:IsA("ValueBase") then nt.Value = 1 end
		inst.Transparency = 1
		inst:SetAttribute("__FabrikAdHidden2", true)
	elseif inst:IsA("SpecialMesh") then
		inst.Scale = Vector3.zero
		inst:SetAttribute("__FabrikAdHidden2", true)
	end
end

local function isMonetizationButton(btn)
	return btn:FindFirstChild("GamepassPrice")
		or btn:FindFirstChild("GroupID")
		or btn:FindFirstChild("IsAnAfterGamepass")
end

local function hideMonetizationButton(btn)
	if btn:GetAttribute("__FabrikAdHidden2") then return end
	local vis = btn:FindFirstChild("IsButtonVisible")
	if vis and vis.Value then
		vis.Value = false
	end
	local n = 0
	for _, d in btn:GetDescendants() do
		disableWorldAdInstance(d)
		n += 1
		if n % AD_HIDE_YIELD_EVERY == 0 then
			task.wait()
		end
	end
	btn:SetAttribute("__FabrikAdHidden2", true)
end

local function hideBuildMonetizationProp(inst)
	if inst:GetAttribute("__FabrikAdHidden2") then return end
	local n = 0
	for _, d in inst:GetDescendants() do
		disableWorldAdInstance(d)
		n += 1
		if n % AD_HIDE_YIELD_EVERY == 0 then
			task.wait()
		end
	end
	disableWorldAdInstance(inst)

	local parent = inst.Parent
	if parent then
		for _, sib in parent:GetChildren() do
			if sib ~= inst and sib.Name == "Meshes/pedestal" then
				disableWorldAdInstance(sib)
			end
		end
	end
	inst:SetAttribute("__FabrikAdHidden2", true)
end

local function hideTycoonMonetization(tycoon)
	if not tycoon then return end

	if tycoon:FindFirstChild("Buttons") then
		for _, btn in tycoon.Buttons:GetChildren() do
			if isMonetizationButton(btn) then
				hideMonetizationButton(btn)
			end
		end
	end

	local buildProps = {}
	local pedestals = {}
	local n = 0
	for _, d in tycoon:GetDescendants() do
		n += 1
		if isBuildMonetizationProp(d) then
			buildProps[#buildProps + 1] = d
		elseif d.Name == "Meshes/pedestal"
			and (d:IsA("MeshPart") or d:IsA("BasePart") or d:IsA("UnionOperation"))
		then
			local parent = d.Parent
			if parent
				and (
					parent:FindFirstChild("VIPBTN")
					or parent:FindFirstChild("2XMONEYBTN")
					or parent:FindFirstChild("AUTOCOLLECTBTN")
					or parent:FindFirstChild("SHINYBTN")
				)
			then
				pedestals[#pedestals + 1] = d
			end
		end
		if n % 200 == 0 then
			task.wait()
		end
	end

	for i, inst in buildProps do
		hideBuildMonetizationProp(inst)
		if i % 4 == 0 then
			task.wait()
		end
	end
	for i, inst in pedestals do
		disableWorldAdInstance(inst)
		if i % AD_HIDE_YIELD_EVERY == 0 then
			task.wait()
		end
	end
end

local function hideWorldMonetization()
	local playerTycoon = getTycoon()
	if playerTycoon then
		hideTycoonMonetization(playerTycoon)
		task.wait(0.15)
	end

	local tycoonsFolder = workspace:FindFirstChild("Tycoons")
	if not tycoonsFolder then return end
	for _, tycoon in tycoonsFolder:GetChildren() do
		if tycoon ~= playerTycoon then
			hideTycoonMonetization(tycoon)
			task.wait(0.25)
		end
	end
end

local UI_MONETIZATION_SECTIONS = {
	Gamepass = true,
	Gamepasses = true,
	Diamond = true,
	Cash = true,
	["Starter Pack"] = true,
}

local function hideStoreScrollingAds(scroll)
	if not scroll then return end
	for _, child in scroll:GetChildren() do
		if UI_MONETIZATION_SECTIONS[child.Name] then
			stripGuiAd(child)
		end
	end
end

local function hideMainUiAds(main)
	if not main then return end

	for _, name in { "Starter Pack", "Store", "Not Enough Cash" } do
		local frame = main:FindFirstChild(name)
		if frame then stripGuiAd(frame) end
	end

	local hud = main:FindFirstChild("HUD")
	if hud then
		local shop = hud:FindFirstChild("LeftSidebar")
			and hud.LeftSidebar:FindFirstChild("Buttons")
			and hud.LeftSidebar.Buttons:FindFirstChild("Row1")
			and hud.LeftSidebar.Buttons.Row1:FindFirstChild("Shop")
		if shop then stripGuiAd(shop) end

		local footer = hud:FindFirstChild("Footer")
		if footer then
			local boost = footer:FindFirstChild("5xMoney")
			if boost then stripGuiAd(boost) end
		end
	end

	for _, menuName in { "Upgrades", "Store" } do
		local menu = main:FindFirstChild(menuName)
		local scroll = menu
			and menu:FindFirstChild("ImageLabel")
			and menu.ImageLabel:FindFirstChild("MainFrame")
			and menu.ImageLabel.MainFrame:FindFirstChild("ScrollingFrame")
		hideStoreScrollingAds(scroll)
	end
end

local scheduleAdHide

local function hideMonetizationAdsNow()
	if not Config.HideMonetization then return end
	if adHideBusy then
		adHidePending = true
		return
	end
	adHideBusy = true
	setPhase("adClean")
	local ok, err = pcall(function()
		local pg = LP:FindFirstChild("PlayerGui")
		local main = pg and pg:FindFirstChild("MainUI")
		hideMainUiAds(main)
		hideWorldMonetization()
	end)
	adHideBusy = false
	lastAdCleanAt = os.clock()
	if not ok then
		logWarn("hideMonetizationAds crashed: " .. tostring(err))
	elseif ctx.log.verbose then
		logDebug("ad hide pass complete")
	end
	if adHidePending then
		adHidePending = false
		scheduleAdHide()
	end
end

scheduleAdHide = function()
	if not Config.HideMonetization or not startupReady then return end
	adHidePending = true
	if adHideDebounceThread then return end
	adHideDebounceThread = task.spawn(function()
		while adHidePending and Config.HideMonetization do
			adHidePending = false
			local waitFor = AD_HIDE_MIN_INTERVAL - (os.clock() - lastAdCleanAt)
			if waitFor > 0 then
				task.wait(waitFor)
			end
			if Config.HideMonetization then
				hideMonetizationAdsNow()
			end
		end
		adHideDebounceThread = nil
	end)
end

hideMonetizationAds = function()
	if not Config.HideMonetization then return end
	scheduleAdHide()
end

local function disconnectAdCleanerListeners()
	for _, conn in adCleanerConnections do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(adCleanerConnections)
end

local function bindAdCleanerListeners()
	disconnectAdCleanerListeners()
	if not Config.HideMonetization then return end

	local tycoonRef = LP:FindFirstChild("TycoonOwned")
	if not tycoonRef then return end

	local conn = tycoonRef:GetPropertyChangedSignal("Value"):Connect(function()
		scheduleAdHide()
	end)
	table.insert(adCleanerConnections, conn)
	track(conn)
end

setAdHidingEnabled = function(enabled)
	Config.HideMonetization = enabled
	if not startupReady then return end
	if enabled then
		logInfo("ad hiding ON â€” scheduling clean pass")
		bindAdCleanerListeners()
		task.spawn(hideMonetizationAdsNow)
	else
		logInfo("ad hiding OFF â€” listeners disconnected")
		disconnectAdCleanerListeners()
		if adHideDebounceThread then
			adHidePending = false
		end
	end
end

startAdCleaner = function()
	-- Listeners attach only when the toggle is turned on (setAdHidingEnabled).
	-- Avoids DescendantAdded feedback loops while ads are meant to stay visible.
end

	ctx.ads = {
		hide = hideMonetizationAds,
		setEnabled = setAdHidingEnabled,
		start = startAdCleaner,
	}
end
