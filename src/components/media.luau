--!nonstrict
-- Media tab: Creator Store browser (modular sections under components/media/).

local mount = require("./media/mount")

return function(ctx)
	local lib = ctx.lib

	function lib:AddMediaBrowser()
		mount(ctx)
	end

	lib.AddVideoSearch = lib.AddMediaBrowser
	lib.AddVideoPlayer = lib.AddMediaBrowser
end
