local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local decodeDoc = require("@root/store/decodeDoc")
local findOtherServer = require("@root/server/findOtherServer")
local getActiveWorkspace = require("@root/store/getActiveWorkspace")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local getWorkspaces = require("@root/store/getWorkspaces")
local migrateWorkspaces = require("@root/migrations/migrateWorkspaces")
local testing = require("@root/testing")

local function noServer(_root: string): findOtherServer.Server?
	return nil
end

local OPTIONS: migrateWorkspaces.Options = { findOtherServer = noServer }

-- The revision of the `orion.json` a folder moved with, before it moves to
-- files of its own.
local function readRevision(dir: string): number
	return decodeDoc(fs.readFileToString(path.join(dir, "orion.json"))).revision
end

local LEGACY_LIST = [[{
	"active": "planning",
	"workspaces": [{ "name": "default", "label": "Default" }, { "name": "planning", "label": "Planning" }],
	"archived": [{ "name": "old", "label": "Old" }]
}]]

-- A data folder as an older Orion left it: the list, and a folder for each
-- named workspace.
local function legacyRoot(name: string): string
	local root = testing.directory(name)

	for _, canvas in { "planning", "old" } do
		local dir = tostring(path.join(root, "workspaces", canvas))
		fs.createDirectory(path.join(dir, "backups"), { makeParents = true })
		fs.writeStringToFile(
			path.join(dir, "orion.json"),
			`\{"version":2,"revision":3,"nodes":[],"links":[],"label":"{canvas}"}`
		)
		fs.writeStringToFile(path.join(dir, "backups", "orion-r2-20261001T000000Z.json"), "{}")
	end

	fs.writeStringToFile(path.join(root, "workspaces.json"), LEGACY_LIST)
	return root
end

test.case("a fresh data folder has nothing to move", function(assert)
	local root = testing.directory("migrate-fresh")
	assert.eq(migrateWorkspaces(root, OPTIONS), false)
	assert.eq(fs.exists(root), false)

	local active = getActiveWorkspace(root, nil, nil)
	assert.eq(active, "default")
	assert.eq(fs.exists(path.join(root, "canvases")), false)
end)

test.case("an older data folder moves to canvases with its data, backups, and list", function(assert)
	local root = legacyRoot("migrate-existing")
	assert.eq(migrateWorkspaces(root, OPTIONS), true)

	assert.eq(fs.exists(path.join(root, "workspaces")), false)
	assert.eq(fs.exists(path.join(root, "workspaces.json")), false)
	assert.eq(fs.readFileToString(path.join(root, "workspaces.backup.json")), LEGACY_LIST)

	for _, canvas in { "planning", "old" } do
		local dir = getWorkspaceDir(root, canvas)
		assert.eq(dir, tostring(path.join(root, "canvases", canvas)))
		assert.eq(readRevision(dir), 3)
		assert.eq(fs.exists(path.join(dir, "backups", "orion-r2-20261001T000000Z.json")), true)
	end

	local list = getWorkspaces(root)
	assert.eq(list.active, "planning")
	assert.eq(#list.workspaces, 2)
	assert.eq(list.workspaces[2].label, "Planning")
	assert.eq(list.archived[1].name, "old")

	local raw = json.asObject(json.deserialize(fs.readFileToString(path.join(root, "canvases.json"))) :: json.Value)
	assert.eq(raw and raw.workspaces, nil)
end)

test.case("running the migration twice leaves the moved data alone", function(assert)
	local root = legacyRoot("migrate-twice")
	assert.eq(migrateWorkspaces(root, OPTIONS), true)
	local listed = fs.readFileToString(path.join(root, "canvases.json"))

	assert.eq(migrateWorkspaces(root, OPTIONS), false)
	assert.eq(fs.readFileToString(path.join(root, "canvases.json")), listed)
	assert.eq(readRevision(getWorkspaceDir(root, "planning")), 3)
end)

test.case("a migration that stopped partway finishes on the next run", function(assert)
	local root = legacyRoot("migrate-partway")
	fs.createDirectory(path.join(root, "canvases"))
	fs.move(path.join(root, "workspaces", "planning"), path.join(root, "canvases", "planning"))

	assert.eq(migrateWorkspaces(root, OPTIONS), true)
	assert.eq(fs.exists(path.join(root, "workspaces")), false)
	assert.eq(readRevision(getWorkspaceDir(root, "planning")), 3)
	assert.eq(readRevision(getWorkspaceDir(root, "old")), 3)
	assert.eq(getWorkspaces(root).active, "planning")
end)

test.case("stray files in the old folder don't stop later runs", function(assert)
	local root = legacyRoot("migrate-stray")
	assert.eq(migrateWorkspaces(root, OPTIONS), true)
	fs.createDirectory(path.join(root, "workspaces"))
	fs.writeStringToFile(path.join(root, "workspaces", ".DS_Store"), "")
	fs.writeStringToFile(path.join(root, "canvases", ".DS_Store"), "")

	assert.eq(migrateWorkspaces(root, OPTIONS), true)
	assert.eq(readRevision(getWorkspaceDir(root, "planning")), 3)
end)

test.case("a canvas folder on both sides is reported instead of overwritten", function(assert)
	local root = legacyRoot("migrate-conflict")
	fs.createDirectory(path.join(root, "canvases", "planning"), { makeParents = true })

	assert.throws(function()
		migrateWorkspaces(root, OPTIONS)
	end)
	assert.eq(fs.exists(path.join(root, "workspaces", "planning", "orion.json")), true)
end)

test.case("another Orion still serving the folder stops the move", function(assert)
	local root = legacyRoot("migrate-serving")

	assert.throwsWith(
		`another Orion 0.1.0+abc1234 is serving {root} (pid 42); quit it so Orion can move this data folder to canvases`,
		function()
			migrateWorkspaces(root, {
				findOtherServer = function(_root: string): findOtherServer.Server?
					return { pid = 42, version = "0.1.0+abc1234" }
				end,
			})
		end
	)
	assert.throwsWith(
		`another Orion is serving {root} (pid 7); quit it so Orion can move this data folder to canvases`,
		function()
			migrateWorkspaces(root, {
				findOtherServer = function(_root: string): findOtherServer.Server?
					return { pid = 7 }
				end,
			})
		end
	)
	assert.eq(fs.exists(path.join(root, "workspaces.json")), true)
	assert.eq(fs.exists(path.join(root, "canvases")), false)
end)

test.case("a server record whose process is gone doesn't stop the move", function(assert)
	local root = legacyRoot("migrate-stale-server")
	fs.writeStringToFile(
		path.join(root, "serve.json"),
		[[{"pid":999999,"url":"http://127.0.0.1:1","workspace":"planning","dataFolder":"x","startedAt":"x"}]]
	)

	assert.eq(migrateWorkspaces(root), true)
	assert.eq(fs.exists(path.join(root, "canvases", "planning")), true)
end)
