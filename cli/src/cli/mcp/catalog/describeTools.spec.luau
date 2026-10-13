local json = require("@std/json")
local test = require("@std/test")

local describeTools = require("@root/cli/mcp/catalog/describeTools")

test.case("each tool is described with an input schema", function(assert)
	local names: { [string]: boolean } = {}

	for _, description in describeTools() do
		local tool = json.asObject(description)

		if tool and type(tool.name) == "string" then
			names[tool.name] = true
			assert.neq(json.asObject(tool.inputSchema), nil)
		end
	end

	assert.eq(names.orion_add_item, true)
	assert.eq(names.orion_inspect, true)
	assert.eq(names.orion_add_image, true)
	assert.eq(names.orion_apply, true)
end)
