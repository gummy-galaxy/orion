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

test.case("update_item passes ref through as --ref and keeps repo and pr as aliases", function(assert)
	assert.eq(
		getToolArgv("orion_update_item", json.object({ id = "pub", ref = "jira:ABC-1" })),
		{ "set", "pub", "--ref", "jira:ABC-1", "--json" }
	)
	assert.eq(
		getToolArgv("orion_add_item", json.object({ title = "Review", repo = "Roblox/avatar", pr = 4 })),
		{ "add", "Review", "--repo", "Roblox/avatar", "--pr", "4", "--json" }
	)
end)

test.case("workspace tools map onto the workspace commands", function(assert)
	assert.eq(
		table.concat(getToolArgv("orion_create_workspace", json.object({ label = "Focus areas" })), " "),
		"workspace create --label Focus areas"
	)
	assert.eq(
		table.concat(getToolArgv("orion_create_workspace", json.object({ name = "focus", label = "Focus" })), " "),
		"workspace create focus --label Focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_rename_workspace", json.object({ name = "focus", label = "Focus" })), " "),
		"workspace rename focus Focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_archive_workspace", json.object({ name = "focus" })), " "),
		"workspace archive focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_restore_workspace", json.object({ name = "focus" })), " "),
		"workspace restore focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_workspaces", json.object({ archived = true })), " "),
		"workspace list --archived --json"
	)
	assert.throwsWith("missing name", function()
		getToolArgv("orion_archive_workspace", json.object({}))
	end)
end)
