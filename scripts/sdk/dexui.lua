-- DexUI window helpers shared across game scripts.
return function(ctx)
	function ctx.dexui.applyNotifyStyle(ui, style)
		ui = ui or ctx.getUi()
		if not ui or not ui.SetNotificationStyle then
			return
		end
		style = style or ctx.manifest.notifyStyle or {
			Life = ctx.notifDuration,
			Text = { Gradient = "rainbow" },
			TextStroke = { Gradient = "rainbow", Thickness = 3.5 },
			StackPosition = UDim2.new(1, -16, 0.58, 0),
		}
		ui:SetNotificationStyle(style)
	end

	function ctx.dexui.applyFooter(ui, footerConfig)
		ui = ui or ctx.getUi()
		if not ui or not ui.SetFooterConfig then
			return
		end
		ui:SetFooterConfig(footerConfig or ctx.manifest.footer)
	end

	function ctx.dexui.publishUi(ui)
		ctx.ui = ui
		local genv = ctx.genv
		if genv and genv.ui then
			ctx.G[genv.ui] = ui
		end
	end

	function ctx.dexui.bindUnload(opts)
		opts = opts or {}
		return function()
			local cfg = ctx.config
			if cfg and opts.masterKey then
				cfg[opts.masterKey] = false
			end
			ctx.shutdown(opts.notify ~= false)
			ctx.session = nil
			ctx.clearGenv()
			if opts.clearWidgets and ctx.widgets then
				for key in ctx.widgets do
					ctx.widgets[key] = nil
				end
			end
		end
	end

	function ctx.dexui.addAboutTab(ui)
		ui = ui or ctx.getUi()
		if ui and ui.AddGameInfo then
			ui:AddTab("About", 6026568227)
			ui:AddGameInfo()
		end
	end

	return ctx
end
