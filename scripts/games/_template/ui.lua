return function(ctx)
	local Config = ctx.config
	local unloadScript = ctx.dexui.bindUnload({ masterKey = "Enabled", clearWidgets = true })

	local ui = ctx.DexUI.CreateWindow(ctx.manifest.windowTitle or ctx.name)
	ctx.dexui.publishUi(ui)
	ctx.dexui.applyNotifyStyle(ui)

	ui:AddTab("Main", 4483362458)
	ui:AddSection("Automation")
	ui:AddSwitch("Master", Config.Enabled, function(v)
		Config.Enabled = v
		ctx.feedback.play(v and "toggleOn" or "toggleOff")
	end)

	ui:AddDivider()
	ui:AddSection("Danger")
	ui:AddButton("Unload", unloadScript)

	ctx.dexui.addAboutTab(ui)
	ui:Show()

	ctx.notify.push({
		Title = ctx.name,
		Content = "Loaded — enable Master when ready.",
		Duration = 3,
	})
end
