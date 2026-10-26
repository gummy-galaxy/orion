local geometry = require("@root/geometry")

-- The app's spacing between neighbors on the level an item sits on: inside a
-- group, or at the top level.
local function getGap(parentId: string?)
	return if parentId then geometry.GAP.inner else geometry.GAP.top
end

return getGap
