--!nonstrict
-- Game info panel: composes modular sections under components/game-info/.

local mount = require("./game-info/mount")

return function(ctx)
	local lib = ctx.lib

	function lib:AddGameInfo()
		mount(ctx)
	end
end
