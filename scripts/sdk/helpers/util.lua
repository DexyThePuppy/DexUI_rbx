--[[
  Generic helpers (not game-specific). Attached as ctx.util.*
]]
return function(ctx)
	ctx.util = ctx.util or {}

	function ctx.util.tableCount(t)
		if not t then
			return 0
		end
		local n = 0
		for _ in t do
			n += 1
		end
		return n
	end

	function ctx.util.copyTable(t)
		if not t then
			return {}
		end
		local out = {}
		for k, v in t do
			out[k] = v
		end
		return out
	end

	return ctx.util
end
