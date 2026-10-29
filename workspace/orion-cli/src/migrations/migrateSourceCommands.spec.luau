local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local loadDoc = require("@root/store/loadDoc")
local migrateSourceCommands = require("@root/migrations/migrateSourceCommands")
local readSourceCommands = require("@root/sources/readSourceCommands")
local testing = require("@root/testing")

local function noServer(_root: string)
	return nil
end

local OPTIONS: migrateSourceCommands.Options = { findOtherServer = noServer }

local JIRA_CANVAS = [[{
	"version": 2,
	"settings": { "sources": [
		{ "id": "jira", "kind": "jira", "command": ["acli", "jira", "workitem", "search"], "browse": "https://jira.example.com/browse" },
		{ "id": "gh", "kind": "github", "host": "github.com", "owners": ["vocksel"] }
	] }
}]]

local HOP_CANVAS = [[{"version":2,"settings":{"sources":[{"id":"hop","kind":"hop","command":["hop"]}]}}]]

-- A data folder whose canvases still keep their sources' commands in
-- `canvas.json`.
local function legacyRoot(name: string): string
	local root = testing.directory(name)
	local planning = path.join(root, "canvases", "planning")
	fs.createDirectory(planning, { makeParents = true })
	fs.writeStringToFile(path.join(root, "canvas.json"), JIRA_CANVAS)
	fs.writeStringToFile(path.join(planning, "canvas.json"), HOP_CANVAS)
	return root
end

test.case("commands move out of canvas.json into this machine's commands.json", function(assert)
	local root = legacyRoot("migrate-source-commands")
	assert.eq(migrateSourceCommands(root, OPTIONS), true)

	assert.eq(readSourceCommands(root, "default"), { jira = { "acli", "jira", "workitem", "search" } })
	assert.eq(readSourceCommands(root, "planning"), { hop = { "hop" } })
	assert.strNotContains(fs.readFileToString(path.join(root, "canvas.json")), "acli")
	assert.strNotContains(fs.readFileToString(path.join(root, "canvases", "planning", "canvas.json")), "command")

	local sources = loadDoc(root).settings.sources
	assert.eq(#sources, 2)
	assert.eq(sources[1].browse, "https://jira.example.com/browse")
	assert.eq(sources[2].owners, { "vocksel" })
end)

test.case("after the first run, a command a cloned canvas brings stays unread", function(assert)
	local root = testing.directory("migrate-source-commands-once")
	fs.createDirectory(root, { makeParents = true })
	assert.eq(migrateSourceCommands(root, OPTIONS), false)
	assert.eq(fs.exists(path.join(root, "commands.json")), true)

	local cloned = path.join(root, "canvases", "cloned")
	fs.createDirectory(cloned, { makeParents = true })
	fs.writeStringToFile(path.join(cloned, "canvas.json"), JIRA_CANVAS)
	assert.eq(migrateSourceCommands(root, OPTIONS), false)
	assert.eq(readSourceCommands(root, "cloned"), {})
end)

test.case("commands don't move while another build of Orion serves the folder", function(assert)
	local root = legacyRoot("migrate-source-commands-server")
	assert.throwsWith("quit it so Orion can move source commands out of canvas files", function()
		migrateSourceCommands(root, {
			findOtherServer = function()
				return { pid = 42, version = "0.0.1" }
			end,
		})
	end)
	assert.eq(fs.exists(path.join(root, "commands.json")), false)
	assert.strContains(fs.readFileToString(path.join(root, "canvas.json")), "acli")
end)
