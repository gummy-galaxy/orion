local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local cli = require("@root/cli")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local runTransaction = require("@root/storage/transactions/runTransaction")
local testing = require("@root/testing")
local types = require("@root/types")

local function listJson(run: (args: { string }, runner: types.CommandRunner?) -> string, args: { string }?): json.Array
	local command = { "history", "list", "--json" }

	for _, arg in args or {} do
		table.insert(command, arg)
	end

	return json.asArray(json.deserialize(run(command)) :: json.Value) :: json.Array
end

test.case("history lists the current revision, then each saved one newest first", function(assert)
	local dir, run = testing.createHarness("history-list")
	local folder = path.join(dir, "backups")
	fs.createDirectory(folder)
	fs.writeStringToFile(path.join(folder, "orion-r2-20261002T010000Z.json"), "old")
	fs.writeStringToFile(path.join(folder, "orion-r1-20261003T010000Z.json"), "newer")
	local values = listJson(run)
	local current = json.asObject(values[1]) :: json.Object
	local first = json.asObject(values[2]) :: json.Object
	assert.eq(#values, 3)
	assert.eq(current.revision, 0)
	assert.eq(current.current, true)
	assert.eq(first.revision, 1)
	assert.eq(first.current, false)
	assert.eq(first.time, "2026-10-03T01:00:00Z")
	assert.eq(first.by, nil)
	assert.strContains(run({ "history", "list" }), "r1  2026-10-03T01:00:00Z  unknown")
end)

test.case("history records whether the CLI, an MCP tool, or the app made each revision", function(assert)
	local dir, run = testing.createHarness("history-writers")
	run({ "card", "create", "Write docs", "--group", "ws" })
	run({ "link", "create", "pub", "ci", "--related" })
	runTransaction(dir, function() end)
	local values = listJson(run)
	local app = json.asObject(values[1]) :: json.Object
	local created = json.asObject(values[3]) :: json.Object
	assert.eq(app.revision, 3)
	assert.eq(app.by, "app")
	assert.eq(app.command, nil)
	assert.eq(created.by, "cli")
	assert.eq(created.command, "card create")
	assert.strContains(run({ "history", "list" }), "  cli link create\n")
end)

test.case("a command an MCP server runs is recorded as the tool's", function(assert)
	local dir, run = testing.createHarness("history-mcp")
	cli.execute({ "card", "create", "Second", "--group", "ws" }, {
		dataDir = dir,
		via = "mcp",
		write = function() end,
	})
	local newest = json.asObject(listJson(run)[1]) :: json.Object
	assert.eq(newest.by, "mcp")
	assert.eq(newest.command, "card create")
end)

test.case("--canvas lists revisions from the selected canvas", function(assert)
	local root, run, setWorkspace = testing.createHarness("workspace-history")
	run({ "canvas", "create", "roblox" })
	local roblox = getWorkspaceDir(root, "roblox")
	runTransaction(root, function() end)
	runTransaction(roblox, function() end)
	runTransaction(roblox, function() end)
	assert.eq(#listJson(run), 2)
	assert.eq(#listJson(run, { "--canvas", "roblox" }), 3)
	setWorkspace("roblox")
	assert.eq(#listJson(run), 3)
	assert.eq(#listJson(run, { "--canvas", "default" }), 2)
end)
