local test = require("@std/test")

local readDoc = require("@root/storage/canvases/readDoc")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

test.case("readDoc is nil until the workspace has a data file", function(assert)
	local dir = testing.directory("read-missing")
	assert.eq(readDoc(dir), nil)

	writeDoc(dir, testing.createDoc({ testing.task("a", "A", "todo") }))
	local doc = readDoc(dir)
	assert.eq(doc and doc.nodes[1].id, "a")
end)
