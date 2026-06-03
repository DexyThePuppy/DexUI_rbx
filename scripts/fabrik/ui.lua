-- DexUI window, tabs, and widget handles on ctx.widgets.
return function(ctx)
	local Config = ctx.config
	local stats = ctx.stats
	local G = ctx.G
	local DexUI = ctx.DexUI
	local farmNotify = ctx.notify.push
	local farmPlayFeedback = ctx.feedback.play
	local FARM_NOTIF_DURATION = ctx.FARM_NOTIF_DURATION

	local function unloadScript()
		Config.Enabled = false
		ctx.shutdown(true)
		ctx.session = nil
		G.__FabrikFarmSession = nil
		G.__FabrikFarmInjectId = nil
		G.__FabrikFarmConfig = nil
		G.__FabrikFarmStats = nil
		ctx.widgets.status = nil
		ctx.widgets.progress = nil
		ctx.widgets.stats = nil
	end

	local ui = DexUI.CreateWindow("Fabrik-Tycoon Farm")
	ctx.ui = ui
	G.__FabrikFarmUI = ui

	if ui.SetNotificationStyle then
		ui:SetNotificationStyle({
			Life = FARM_NOTIF_DURATION,
			Text = { Gradient = "rainbow" },
			TextStroke = { Gradient = "rainbow", Thickness = 3.5 },
			StackPosition = UDim2.new(1, -16, 0.58, 0),
		})
	end

	if ui.SetFooterConfig then
		ui:SetFooterConfig({
			Enabled = true,
			Height = 28,
			Layout = "split",
			Left = {
				{ id = "farm", kind = "text", text = "Farm OFF", muted = true },
			},
			Right = {
				{ id = "phase", kind = "text", text = "boot", align = "right", muted = true },
				{ id = "spacer", kind = "spacer" },
				{ id = "version", kind = "version" },
			},
		})
	end

	ui:AddTab("Farm", 4483362458)
	ui:AddSection("Auto farm")
	ui:AddSwitch("Master auto farm", Config.Enabled, function(v)
		Config.Enabled = v
		farmPlayFeedback(v and "toggleOn" or "toggleOff")
		ctx.status.updateFooter()
	end)

	ui:AddSection("Include")
	ui:AddSwitch("Collect money", Config.AutoCollect, function(v)
		Config.AutoCollect = v
	end)
	ui:AddSwitch("Buy buildings", Config.AutoButtons, function(v)
		Config.AutoButtons = v
	end)
	ui:AddSwitch("Gem upgrades", Config.AutoGemUpgrades, function(v)
		Config.AutoGemUpgrades = v
	end)
	ui:AddSwitch("Rebirth", Config.AutoRebirth, function(v)
		Config.AutoRebirth = v
	end)
	ui:AddSwitch("Manual droppers", Config.AutoManualDropper, function(v)
		Config.AutoManualDropper = v
	end)

	ui:AddDivider()
	ui:AddSection("Live status")
	local statusWidget = ui:AddLabel(ctx.status.line())
	ctx.widgets.status = {
		Set = function(_, text)
			statusWidget.SetText(text)
		end,
	}
	local statsWidget = ui:AddLabel(ctx.status.statsLine())
	ctx.widgets.stats = {
		Set = function(_, text)
			statsWidget.SetText(text)
		end,
	}

	ui:AddTab("Progress", 4483362458)
	ui:AddSection("Live progression")
	local progressPara = ui:AddParagraph("Progression", ctx.progress.content())
	ctx.widgets.progress = progressPara
	ui:AddButton("Refresh now", function()
		ctx.progress.update(true)
		farmPlayFeedback("selection")
	end)

	ui:AddTab("Settings", 4483362458)
	ui:AddSection("Tuning")
	ui:AddSlider("Loop speed (s)", 0.15, 2, Config.LoopDelay, function(v)
		Config.LoopDelay = v
	end)
	ui:AddSlider("Rebirth check interval (s)", 3, 30, Config.RebirthInterval, function(v)
		Config.RebirthInterval = v
	end)
	ui:AddSlider("Min collect amount", 0, 500, Config.CollectMin, function(v)
		Config.CollectMin = math.floor(v + 0.5)
	end)

	ui:AddDivider()
	ui:AddSection("Extras")
	ui:AddSwitch("Hide Robux / gamepass ads", Config.HideMonetization, function(v)
		ctx.ads.setEnabled(v)
	end)
	ui:AddSwitch(
		"Verbose logging",
		Config.VerboseLogging,
		function(v)
			Config.VerboseLogging = v
			ctx.log.verbose = v
			ctx.log.info("verbose logging " .. (v and "ON" or "OFF"))
		end,
		"Console DEBUG lines + ServerError drain"
	)

	ui:AddDivider()
	ui:AddSection("Tools")
	ui:AddButton("Collect now", function()
		ctx.farm.tryCollect(true)
		ctx.status.update()
		farmPlayFeedback("selection")
	end)
	ui:AddButton("Buy next building", function()
		ctx.farm.tryBuyCheapestButton()
		ctx.status.update()
		farmPlayFeedback("selection")
	end)
	ui:AddButton("Rebirth now", function()
		if ctx.farm.tryRebirth() then
			farmPlayFeedback("toggleOn")
		else
			farmNotify({
				Title = "Rebirth",
				Content = stats.lastMsg ~= "" and stats.lastMsg or "Not ready",
				Duration = 3,
			})
		end
		ctx.status.update()
	end)
	ui:AddButton("Print diagnostics", function()
		local diag = string.format(
			"phase %s · alive %s · cycles %d · errors %d · last %.1fs · %s",
			ctx.log.phase,
			tostring(ctx.isAlive()),
			stats.cycles,
			stats.errors,
			ctx.timers.lastCycleAt > 0 and (os.clock() - ctx.timers.lastCycleAt) or -1,
			ctx.status.line()
		)
		ctx.log.info("DIAG | " .. diag)
		ctx.log.info(string.format(
			"DIAG counts | buttons:%d drops:%d gems:%d collects:%d rebirths:%d",
			stats.buttons,
			stats.manualDrops,
			stats.upgrades,
			stats.collects,
			stats.rebirths
		))
		farmNotify({ Title = "Diagnostics", Content = diag, Duration = 6 })
	end)

	ui:AddDivider()
	ui:AddSection("Danger")
	ui:AddButton("Quit — stop farm & unload", unloadScript)

	if ui.AddGameInfo then
		ui:AddTab("About", 6026568227)
		ui:AddGameInfo()
	end

	ui:Show()
	farmNotify({
		Title = "Fabrik Farm",
		Content = "Loaded — enable Master auto farm when ready.",
		Duration = 3,
	})
end
