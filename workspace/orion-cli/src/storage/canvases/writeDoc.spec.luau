local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local loadDoc = require("@root/storage/canvases/loadDoc")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

test.case("writeDoc writes the document as given, without bumping its revision", function(assert)
	local dir = testing.directory("write-doc")
	local doc = testing.createDoc({ testing.task("a", "A", "todo") })
	doc.revision = 7
	writeDoc(dir, doc)

	local reread = loadDoc(dir)
	assert.eq(reread.revision, 7)
	assert.eq(reread.nodes[1].id, "a")
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)
