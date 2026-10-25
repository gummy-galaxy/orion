local test = require("@std/test")

local loadDoc = require("@root/store/loadDoc")
local testing = require("@root/testing")

test.case("card create with --after links the card and puts it beside its neighbor, in its group", function(assert)
	local dir, run = testing.createHarness("card-add-after")
	run({ "card", "create", "Announce", "it", "--after", "pub" })
	local doc = loadDoc(dir)
	local pub = doc.nodes[3]
	local added = doc.nodes[#doc.nodes]
	assert.eq(pub.id, "pub")
	assert.eq(added.parentId, "ws")
	assert.eq(added.position.y, pub.position.y)
	assert.eq(added.position.x > pub.position.x, true)
	assert.eq(doc.links[#doc.links].from, "pub")
	assert.eq(doc.links[#doc.links].to, added.id)
end)

test.case("card create with --after and --before splits their link", function(assert)
	local dir, run = testing.createHarness("card-add-between")
	run({ "card", "create", "Check", "--after", "ci", "--before", "pub" })
	local doc = loadDoc(dir)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].from == "ci" or doc.links[2].from == "ci", true)
end)
