-- Fabrik helper: money / income-rate formatters (needs ctx.formatGameValue).
return function(ctx)
	function ctx.fmt.money(n)
		n = math.floor((n or 0) + 0.5)
		return "$" .. ctx.formatGameValue(n)
	end

	function ctx.fmt.incomeRate(n)
		n = math.floor((n or 0) + 0.5)
		if n <= 0 then
			return "($0/s)"
		end
		return "(" .. ctx.fmt.money(n) .. "/s)"
	end
end
