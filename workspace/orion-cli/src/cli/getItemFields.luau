local cli = require("@batteries/cli")

local graphTypes = require("@root/graph/types")

-- The fields card and group commands set, read from their options.
local function getItemFields(parser: cli.Parser): graphTypes.ItemFields
	return {
		label = parser:get("label"),
		blurb = parser:get("blurb"),
		status = parser:get("status"),
		repo = parser:get("repo"),
		who = parser:get("who"),
		note = parser:get("note"),
		arrange = parser:get("arrange"),
		cover = parser:get("cover"),
		background = parser:get("background"),
		header = parser:get("header"),
		kind = parser:get("kind"),
		shape = parser:get("shape"),
		color = parser:get("color"),
	}
end

return getItemFields
