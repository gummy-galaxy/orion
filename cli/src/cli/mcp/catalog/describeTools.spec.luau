local json = require("@std/json")
local test = require("@std/test")

local describeTools = require("@root/cli/mcp/catalog/describeTools")
local findTool = require("@root/cli/mcp/catalog/findTool")

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

test.case("note tools ask agents for a plain-language summary with code formatting", function(assert)
	local addNote = findTool("orion_add_note")
	local updateItem = findTool("orion_update_item")

	assert.neq(addNote, nil)
	assert.neq(updateItem, nil)

	if addNote then
		assert.strContains(addNote.description, "plain-language summary")
		assert.strContains(addNote.description, "code formatting")
	end

	if updateItem then
		for _, field in updateItem.fields do
			if field.name == "note" then
				assert.strContains(field.description or "", "plain-language summary")
				assert.strContains(field.description or "", "Replaces the whole note")
			end
		end
	end
end)
