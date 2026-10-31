local json = require("@std/json")
local test = require("@std/test")

local loadDoc = require("@root/storage/canvases/loadDoc")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

test.case("ref remove takes a ref off by its repository's old name", function(assert)
	local dir = testing.directory("ref-remove-moved")
	local doc = testing.createDoc({
		testing.task(
			"moved",
			"Moved",
			"active",
			nil,
			json.object({
				refs = { json.object({ source = "github", kind = "pull", key = "gummy-galaxy/orion#12", id = "1#12" }) },
			})
		),
	})
	doc.repositories = json.object({
		["1"] = json.object({ name = "gummy-galaxy/orion", aliases = { "vocksel/orion" } }),
	})
	writeDoc(dir, doc)

	testing.run(dir, { "ref", "remove", "moved", "vocksel/orion#12" })

	assert.eq(#(json.asArray(loadDoc(dir).nodes[1].data.refs) or {}), 0)
end)
