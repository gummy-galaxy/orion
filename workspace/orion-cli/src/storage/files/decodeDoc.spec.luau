local json = require("@std/json")
local test = require("@std/test")

local decodeDoc = require("@root/storage/files/decodeDoc")
local encodeDoc = require("@root/storage/files/encodeDoc")
local findRef = require("@root/canvas/refs/findRef")

local VERSION_ONE_MESSAGE = "This canvas was saved as data version 1, which Orion no longer reads."

test.case("decode refuses a version 1 document and says how to upgrade it", function(assert)
	for _, text in
		{
			[[{"version":1,"settings":{},"nodes":[{"id":"a","type":"task","data":{"repo":"orion","pr":12}}],"links":[]}]],
			[[{"nodes":[],"links":[]}]],
		}
	do
		local didDecode, failure = pcall(decodeDoc, text)
		assert.eq(didDecode, false)
		assert.strContains(tostring(failure), VERSION_ONE_MESSAGE)
		assert.strContains(tostring(failure), "To upgrade it")
	end
end)

test.case("decode reads a version 2 document and keeps unknown fields through a reread", function(assert)
	local doc = decodeDoc([[{
		"version":2,"revision":3,
		"settings":{"githubOwner":"Vocksel","future":"kept","sources":[{"id":"hop-local","kind":"hop"}]},
		"nodes":[
			{"id":"pull","type":"task","data":{"repo":"Vocksel/Orion","refs":[
				{"source":"github","kind":"pull","key":"Vocksel/Orion#12","status":"draft"}
			]}},
			{"id":"jira","type":"task","data":{"refs":[{"source":"jira","kind":"issue","key":"ORN-1","isDone":true}]}},
			{"id":"group","type":"cluster","data":{"repo":"short"}}
		],"links":[],"future":{"kept":true}
	}]])
	assert.eq(doc.version, 3)
	assert.eq(doc.revision, 3)
	assert.eq((findRef(doc.nodes[1], "pull") :: any).key, "Vocksel/Orion#12")
	assert.eq((findRef(doc.nodes[2], "issue") :: any).isDone, true)
	assert.eq(doc.nodes[3].data.repo, "short")

	local encoded = encodeDoc(doc)
	local reread = decodeDoc(encoded)
	assert.eq((findRef(reread.nodes[1], "pull") :: any).key, "Vocksel/Orion#12")
	local root = json.asObject(json.deserialize(encoded) :: json.Value)
	local settings = if root then json.asObject(root.settings) else nil
	assert.eq(settings and settings.githubOwner, nil)
	assert.eq(settings and settings.future, "kept")
	assert.eq(root and root.version, 3)
	local future = if root then json.asObject(root.future) else nil
	assert.eq(future and future.kept, true)
end)

test.case("decode moves an image's workspace to canvas", function(assert)
	local doc = decodeDoc([[{
		"version":2,"revision":1,
		"nodes":[{"id":"picture","type":"image","position":{"x":0,"y":0},
			"data":{"kind":"image","label":"Picture","asset":"a.png","workspace":"planning"}}],
		"links":[]
	}]])
	assert.eq(doc.nodes[1].data.canvas, "planning")
	assert.eq(doc.nodes[1].data.workspace, nil)
end)

test.case("decode places each node at its first placement and leaves a node without one unplaced", function(assert)
	local doc = decodeDoc([[{
		"version":3,
		"nodes":[
			{"id":"group","type":"cluster","data":{}},
			{"id":"card","type":"task","data":{}},
			{"id":"loose","type":"task","data":{}}
		],
		"links":[],
		"placements":[
			{"id":"p1","node":"group","position":{"x":5,"y":6}},
			{"id":"p2","node":"card","parentId":"group","position":{"x":1,"y":2}},
			{"id":"p3","node":"card","position":{"x":300,"y":400}}
		]
	}]])

	assert.eq(doc.nodes[2].position, { x = 1, y = 2 })
	assert.eq(doc.nodes[2].parentId, "group")
	assert.eq(doc.nodes[2].placement, "p2")
	assert.eq(doc.nodes[3].unplaced, true)
	assert.eq(doc.nodes[3].placement, nil)
	assert.eq(#doc.placements, 3)

	local root = json.asObject(json.deserialize(encodeDoc(doc)) :: json.Value) :: json.Object
	local placements = json.asArray(root.placements) :: json.Array
	assert.eq(#placements, 3)
	assert.eq((json.asObject(placements[3]) :: json.Object).id, "p3")

	for _, value in json.asArray(root.nodes) :: json.Array do
		local node = json.asObject(value) :: json.Object
		assert.eq(node.position, nil)
		assert.eq(node.parentId, nil)
	end
end)

test.case("decode keeps the position and group of a node from before placements and encode moves them", function(assert)
	local doc = decodeDoc([[{
		"version":2,
		"nodes":[
			{"id":"group","type":"cluster","position":{"x":5,"y":6},"data":{}},
			{"id":"card","type":"task","position":{"x":1,"y":2},"parentId":"group","data":{}},
			{"id":"bare","type":"task","data":{}}
		],
		"links":[]
	}]])

	assert.eq(doc.nodes[2].position, { x = 1, y = 2 })
	assert.eq(doc.nodes[2].parentId, "group")
	assert.eq(doc.nodes[3].unplaced, nil)

	local reread = decodeDoc(encodeDoc(doc))
	assert.eq(#reread.placements, 3)
	assert.eq(reread.placements[2].node, "card")
	assert.eq(reread.placements[2].parentId, "group")
	assert.eq(reread.placements[2].position, { x = 1, y = 2 })
	assert.eq(reread.placements[3].position, { x = 0, y = 0 })
	assert.eq(reread.nodes[2].placement, reread.placements[2].id)
end)
