local geometry = require("@root/geometry")
local types = require("@root/types")

type Item = types.Item

-- The space above a group's cards: its title row, plus the header band when the
-- group has a header.
local function getHeaderHeight(item: Item): number
	local header = item.data.header

	if type(header) == "string" and header:match("%S") then
		return geometry.GROUP_HEADER_HEIGHT + geometry.GROUP_HEADER_BAND
	end

	return geometry.GROUP_HEADER_HEIGHT
end

return getHeaderHeight
