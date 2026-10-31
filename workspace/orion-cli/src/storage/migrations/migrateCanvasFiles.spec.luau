local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local getDocPath = require("@root/storage/canvases/getDocPath")
local loadDoc = require("@root/storage/canvases/loadDoc")
local migrateCanvasFiles = require("@root/storage/migrations/migrateCanvasFiles")
local testing = require("@root/testing")

local function noServer(_root: string): number?
	return nil
end

local OPTIONS: migrateCanvasFiles.Options = { findLegacyServer = noServer }

local LEGACY_DOC = [[{
	"version": 2,
	"revision": 7,
	"settings": { "sources": [{ "id": "gh", "kind": "github", "owners": ["vocksel"] }], "cover": "image-a.png" },
	"stickers": [{ "id": "star" }],
	"github": { "viewer": "vocksel" },
	"nodes": [
		{
			"id": "group", "type": "cluster", "position": { "x": 0, "y": 0 }, "width": 400, "height": 200,
			"data": { "kind": "cluster", "label": "Group" }
		},
		{
			"id": "a", "type": "task", "parentId": "group", "position": { "x": 10, "y": 20 },
			"data": { "kind": "task", "label": "A", "status": "todo" }
		},
		{ "id": "Upper", "type": "note", "position": { "x": 0, "y": 0 }, "data": { "kind": "note", "text": "Hello" } }
	],
	"links": [{ "from": "a", "to": "Upper", "kind": "blocks" }]
}]]

-- A data folder as an older Orion left it: the default canvas in the root and
-- one named canvas.
local function legacyRoot(name: string): string
	local root = testing.directory(name)
	local planning = path.join(root, "canvases", "planning")
	fs.createDirectory(planning, { makeParents = true })
	fs.writeStringToFile(path.join(root, "orion.json"), LEGACY_DOC)
	fs.writeStringToFile(path.join(planning, "orion.json"), [[{"version":2,"revision":2,"nodes":[],"links":[]}]])
	return root
end

test.case("a data folder without orion.json has nothing to move", function(assert)
	local root = testing.directory("canvas-files-fresh")
	assert.eq(migrateCanvasFiles(root, OPTIONS), false)
	assert.eq(fs.exists(root), false)
end)

test.case("each canvas moves to files that read back as the same canvas", function(assert)
	local root = legacyRoot("canvas-files-migrate")
	assert.eq(migrateCanvasFiles(root, OPTIONS), true)

	assert.eq(fs.exists(path.join(root, "orion.json")), false)
	assert.eq(fs.readFileToString(path.join(root, "orion.backup.json")), LEGACY_DOC)
	assert.eq(fs.exists(path.join(root, "nodes", "group.json")), true)
	assert.eq(fs.exists(path.join(root, "nodes", "%55pper.json")), true)
	assert.eq(fs.exists(path.join(root, "links", "a%3e%55pper.json")), true)
	assert.strContains(fs.readFileToString(path.join(root, "local.json")), "viewer")

	local doc = loadDoc(root)
	assert.eq(doc.revision, 7)
	assert.eq(doc.settings.cover, "image-a.png")
	assert.eq(doc.settings.sources[1].id, "gh")
	assert.eq(#doc.nodes, 3)
	assert.eq(doc.nodes[1].id, "group")
	assert.eq(doc.nodes[2].parentId, "group")
	assert.eq(doc.nodes[2].position.y, 20)
	assert.eq(doc.links[1].id, "a>Upper")
	assert.eq(doc.github and doc.github.viewer, "vocksel")
	assert.eq(doc.raw and doc.raw.stickers ~= nil, true)

	local planning = path.join(root, "canvases", "planning")
	assert.eq(fs.exists(path.join(planning, "orion.json")), false)
	assert.eq(loadDoc(tostring(planning)).revision, 2)
	assert.eq(migrateCanvasFiles(root, OPTIONS), false)
end)

test.case("a move that stopped after writing the files finishes", function(assert)
	local root = legacyRoot("canvas-files-resume")
	assert.eq(migrateCanvasFiles(root, OPTIONS), true)
	fs.writeStringToFile(path.join(root, "orion.json"), LEGACY_DOC)

	assert.eq(migrateCanvasFiles(root, OPTIONS), true)
	assert.eq(fs.exists(path.join(root, "orion.json")), false)
	assert.eq(loadDoc(root).revision, 7)
end)

test.case("orion.json written after the move is refused rather than dropped", function(assert)
	local root = legacyRoot("canvas-files-rewritten")
	assert.eq(migrateCanvasFiles(root, OPTIONS), true)
	local stray = [[{"revision":1,"nodes":[],"links":[]}]]
	fs.writeStringToFile(path.join(root, "orion.json"), stray)

	assert.throws(function()
		migrateCanvasFiles(root, OPTIONS)
	end)
	assert.eq(fs.readFileToString(path.join(root, "orion.json")), stray)
	assert.eq(loadDoc(root).revision, 7)
end)

test.case("one canvas that can't move doesn't hold back the rest", function(assert)
	local root = legacyRoot("canvas-files-broken")
	fs.writeStringToFile(path.join(root, "orion.json"), "{")

	assert.throws(function()
		migrateCanvasFiles(root, OPTIONS)
	end)
	assert.eq(fs.readFileToString(path.join(root, "orion.json")), "{")
	assert.eq(fs.exists(getDocPath(root)), false)
	assert.eq(loadDoc(tostring(path.join(root, "canvases", "planning"))).revision, 2)
end)

test.case("a version 1 orion.json stays in place so an older Orion can upgrade it", function(assert)
	local root = legacyRoot("canvas-files-version-one")
	local versionOne = [[{"version":1,"nodes":[{"id":"a","type":"task","data":{"repo":"orion","pr":12}}],"links":[]}]]
	fs.writeStringToFile(path.join(root, "orion.json"), versionOne)

	local didMove, failure = pcall(migrateCanvasFiles, root, OPTIONS)
	assert.eq(didMove, false)
	assert.strContains(tostring(failure), "orion.json was saved as data version 1")
	assert.eq(fs.readFileToString(path.join(root, "orion.json")), versionOne)
	assert.eq(fs.exists(path.join(root, "orion.backup.json")), false)
	assert.eq(fs.exists(getDocPath(root)), false)
	assert.eq(loadDoc(tostring(path.join(root, "canvases", "planning"))).revision, 2)
end)

test.case("an older Orion still serving the folder stops the move", function(assert)
	local root = legacyRoot("canvas-files-older-server")

	assert.throws(function()
		migrateCanvasFiles(root, {
			findLegacyServer = function(_root: string): number?
				return 4242
			end,
		})
	end)
	assert.eq(fs.exists(path.join(root, "orion.json")), true)
	assert.eq(fs.exists(getDocPath(root)), false)
end)

test.case("a canvas still in orion.json refuses to read as empty", function(assert)
	local root = legacyRoot("canvas-files-unmoved")

	assert.throws(function()
		loadDoc(root)
	end)
end)
