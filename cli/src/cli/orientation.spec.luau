local test = require("@std/test")

local findTool = require("@root/cli/mcp/catalog/findTool")
local orientation = require("@root/cli/orientation")

test.case("orientation names only MCP tools that exist in the catalog", function(assert)
	local text = table.concat(orientation.paragraphs, " ")
	local named = 0

	for name in string.gmatch(text, "orion_[%w_]+") do
		named += 1
		assert.neq(findTool(name), nil)
	end

	assert.eq(named > 0, true)
end)

test.case("orientation keeps the canvas vocabulary and leaves CLI command names out", function(assert)
	local text = table.concat(orientation.paragraphs, " ")

	assert.strContains(text, "canvas")
	assert.strContains(text, "workspace")
	assert.strNotContains(text, "orion add ")
	assert.strNotContains(text, "orion set ")
	assert.strNotContains(text, "orion link ")
end)

test.case("help orientation keeps the vocabulary and leaves MCP tools and advice out", function(assert)
	local text = table.concat(orientation.help, " ")

	assert.strContains(text, "canvas")
	assert.strContains(text, "workspace")
	assert.strContains(text, "replaces its whole text")
	assert.strNotContains(text, "orion_")
	assert.strNotContains(text, "Prefer")
end)
