local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local getBackups = require("@root/store/getBackups")
local loadDoc = require("@root/store/loadDoc")
local migratePlacements = require("@root/migrations/migratePlacements")
local testing = require("@root/testing")

local function noServer(_root: string)
	return nil
end

local OPTIONS: migratePlacements.Options = { findOtherServer = noServer }

local LEGACY_CANVAS = [[{
	"version": 2,
	"revision": 4,
	"settings": {},
	"nodes": [
		{ "id": "group", "type": "cluster", "position": { "x": 100, "y": 50 }, "data": { "label": "Launch" } },
		{ "id": "card", "type": "task", "position": { "x": 8, "y": 16 }, "parentId": "group", "data": { "label": "Ship" } }
	],
	"links": []
}]]

local function readObject(file: path.Pathlike): json.Object
	return json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value) :: json.Object
end

-- A data folder whose default canvas and one other still keep positions and
-- groups on their nodes.
local function legacyRoot(name: string): string
	local root = testing.directory(name)
	testing.writeCanvasText(root, LEGACY_CANVAS)
	testing.writeCanvasText(tostring(path.join(root, "canvases", "planning")), LEGACY_CANVAS)
	return root
end

test.case("positions and groups move from node files into placements", function(assert)
	local root = legacyRoot("migrate-placements")
	assert.strContains(fs.readFileToString(path.join(root, "nodes", "card.json")), '"parentId"')
	assert.eq(migratePlacements(root, OPTIONS), true)

	for _, dir in { root, tostring(path.join(root, "canvases", "planning")) } do
		local card = readObject(path.join(dir, "nodes", "card.json"))
		assert.eq(card.position, nil)
		assert.eq(card.parentId, nil)
		assert.eq(#fs.listDirectory(path.join(dir, "placements")), 2)
		assert.eq(readObject(path.join(dir, "canvas.json")).version, 3)

		local doc = loadDoc(dir)
		assert.eq(doc.revision, 5)
		assert.eq(doc.nodes[2].position, { x = 8, y = 16 })
		assert.eq(doc.nodes[2].parentId, "group")
		assert.eq(doc.placements[2].node, "card")
		assert.eq(testing.isRandomId(doc.placements[2].id), true)
		assert.eq(#getBackups(dir), 1)
	end

	assert.eq(migratePlacements(root, OPTIONS), false)
end)

test.case("positions don't move while another build of Orion serves the folder", function(assert)
	local root = legacyRoot("migrate-placements-server")
	assert.throwsWith("quit it so Orion can move card positions into placements", function()
		migratePlacements(root, {
			findOtherServer = function()
				return { pid = 42, version = "0.0.1" }
			end,
		})
	end)
	assert.neq(readObject(path.join(root, "nodes", "card.json")).position, nil)
	assert.eq(#fs.listDirectory(path.join(root, "placements")), 0)
end)

return {}
