local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local getToolArgv = require("@root/cli/mcp/catalog/getToolArgv")
local testing = require("@root/testing")

test.case("tool arguments map onto the command each tool runs", function(assert)
	assert.eq(
		table.concat(getToolArgv("orion_inspect", json.object({ view = "show", id = "ci" })), " "),
		"show ci --json"
	)
	assert.eq(table.concat(getToolArgv("orion_move", json.object({ id = "ci" })), " "), "move ci --top")
	assert.eq(
		table.concat(getToolArgv("orion_move", json.object({ id = "ci", group = "release" })), " "),
		"move ci --to release"
	)
	assert.throwsWith("missing id", function()
		getToolArgv("orion_inspect", json.object({ view = "show" }))
	end)
end)

test.case("tools reject arguments their schemas do not allow", function(assert)
	assert.throwsWith("unknown argument: colour", function()
		getToolArgv("orion_add_item", json.object({ title = "A", colour = "red" }))
	end)
	assert.throwsWith("status must be one of: todo, active, review, blocked, deferred, done", function()
		getToolArgv("orion_add_item", json.object({ title = "A", status = "later" }))
	end)
	assert.throwsWith("pr must be a positive integer", function()
		getToolArgv("orion_add_item", json.object({ title = "A", pr = 1.5 }))
	end)
	assert.throwsWith("items must be a list of strings", function()
		getToolArgv("orion_group", json.object({ label = "G", items = { 1 } }))
	end)
end)

test.case("mcp tool arguments run the existing command", function(assert)
	local dir = testing.createHarness("mcp-argv")
	local output: { string } = {}
	cli.execute(getToolArgv("orion_add_item", json.object({ title = "From the catalog" })), {
		dataDir = dir,
		write = function(text)
			table.insert(output, text)
		end,
	})
	assert.strContains(table.concat(output, "\n"), "From the catalog")
end)
