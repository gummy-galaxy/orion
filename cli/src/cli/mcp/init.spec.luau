local json = require("@std/json")
local test = require("@std/test")

local catalog = require("@root/cli/mcp/catalog")
local cli = require("@root/cli")
local testing = require("@root/testing")

test.case("the catalog describes each tool and maps arguments to commands", function(assert)
	local tools = json.asArray(catalog.schema().tools)
	local names: { [string]: boolean } = {}

	for _, tool in tools or {} do
		local item = json.asObject(tool)

		if item and type(item.name) == "string" then
			names[item.name] = true
		end
	end

	assert.eq(names.orion_add_item, true)
	assert.eq(names.orion_inspect, true)
	assert.eq(names.orion_add_image, true)
	assert.eq(
		table.concat(catalog.argv("orion_inspect", json.object({ view = "show", id = "ci" })), " "),
		"show ci --json"
	)
	assert.eq(table.concat(catalog.argv("orion_move", json.object({ id = "ci" })), " "), "move ci --top")
	assert.throwsWith("missing id", function()
		catalog.argv("orion_inspect", json.object({ view = "show" }))
	end)
end)

test.case("the catalog rejects arguments its schema does not allow", function(assert)
	assert.throwsWith("unknown argument: colour", function()
		catalog.argv("orion_add_item", json.object({ title = "A", colour = "red" }))
	end)
	assert.throwsWith("status must be one of: todo, active, review, blocked, deferred, done", function()
		catalog.argv("orion_add_item", json.object({ title = "A", status = "later" }))
	end)
	assert.throwsWith("pr must be a positive integer", function()
		catalog.argv("orion_add_item", json.object({ title = "A", pr = 1.5 }))
	end)
	assert.throwsWith("items must be a list of strings", function()
		catalog.argv("orion_group", json.object({ label = "G", items = { 1 } }))
	end)
end)

test.case("mcp tool arguments run the existing command", function(assert)
	local dir = testing.createHarness("mcp-argv")
	local output: { string } = {}
	cli.execute(catalog.argv("orion_add_item", json.object({ title = "From the catalog" })), {
		dataDir = dir,
		write = function(text)
			table.insert(output, text)
		end,
	})
	assert.strContains(table.concat(output, "\n"), "From the catalog")
end)
