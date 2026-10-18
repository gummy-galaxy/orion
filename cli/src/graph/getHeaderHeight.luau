local sizes = require("@root/graph/sizes")
local types = require("@root/types")

type Item = types.Item

-- The space above a group's cards: its title row, plus the header band when the group has a header.
local function getHeaderHeight(item: Item): number
	local header = item.data.header

	if type(header) == "string" and header:match("%S") then
		return sizes.GROUP_HEADER_HEIGHT + sizes.GROUP_HEADER_BAND
	end

	return sizes.GROUP_HEADER_HEIGHT
end

return getHeaderHeight
