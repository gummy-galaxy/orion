local cli = require("@batteries/cli")

local graph = require("@root/graph")

-- The fields card and group commands set, read from their options.
local function getItemFields(parser: cli.Parser): graph.ItemFields
	local pr = parser:get("pr")
	local number = if pr then tonumber((pr:gsub("^#", ""))) else nil
	assert(pr == nil or number, "pr must be a number")

	return {
		label = parser:get("label"),
		blurb = parser:get("blurb"),
		status = parser:get("status"),
		repo = parser:get("repo"),
		pr = number,
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
