return function(ctx)
	local Config = ctx.config
	local stats = ctx.stats
	local unloadScript = ctx.dexui.bindUnload({
		masterKey = "Enabled",
		clearWidgets = true,
	})

	local ui = ctx.DexUI.CreateWindow(ctx.manifest.windowTitle or "Fabrik-Tycoon Farm")
	ctx.dexui.publishUi(ui)
	ctx.dexui.applyNotifyStyle(ui)

	ui:AddTab("Farm", 4483362458)
	ui:AddSection("Auto farm")
	ui:AddSwitch("Master auto farm", Config.Enabled, function(v)
		Config.Enabled = v
		ctx.feedback.play(v and "toggleOn" or "toggleOff")
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
		ctx.feedback.play("selection")
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
		ctx.feedback.play("selection")
	end)
	ui:AddButton("Buy next building", function()
		ctx.farm.tryBuyCheapestButton()
		ctx.status.update()
		ctx.feedback.play("selection")
	end)
	ui:AddButton("Rebirth now", function()
		if ctx.farm.tryRebirth() then
			ctx.feedback.play("toggleOn")
		else
			ctx.notify.push({
				Title = "Rebirth",
				Content = stats.lastMsg ~= "" and stats.lastMsg or "Not ready",
				Duration = 3,
			})
		end
		ctx.status.update()
	end)
	ui:AddButton("Print diagnostics", function()
		local diag = string.format(
			"phase %s Ã‚Â· alive %s Ã‚Â· cycles %d Ã‚Â· errors %d Ã‚Â· last %.1fs Ã‚Â· %s",
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
		ctx.notify.push({ Title = "Diagnostics", Content = diag, Duration = 6 })
	end)

	ui:AddDivider()
	ui:AddSection("Danger")
	ui:AddButton("Quit Ã¢â‚¬â€ stop farm & unload", unloadScript)

	ctx.dexui.addAboutTab(ui)

	ui:Show()
	ctx.notify.push({
		Title = ctx.name,
		Content = "Loaded â€” enable Master auto farm when ready.",
		Duration = 3,
	})
end
