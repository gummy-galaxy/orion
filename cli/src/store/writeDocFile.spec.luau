local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local decodeDoc = require("@root/store/decodeDoc")
local encodeDoc = require("@root/store/encodeDoc")
local getBackups = require("@root/store/getBackups")
local getDocPath = require("@root/store/getDocPath")
local loadDoc = require("@root/store/loadDoc")
local testing = require("@root/testing")
local writeDocFile = require("@root/store/writeDocFile")

test.case("writeDocFile writes the first data file without a backup", function(assert)
	local dir = testing.directory("first-write")
	fs.createDirectory(dir, { makeParents = true })
	writeDocFile(dir, encodeDoc(testing.createDoc({ testing.task("a", "A", "todo") })))

	assert.eq(loadDoc(dir).nodes[1].id, "a")
	assert.eq(#getBackups(dir), 0)
end)

test.case("writeDocFile saves the exact previous file before replacing it", function(assert)
	local dir = testing.directory("backup")
	fs.createDirectory(dir, { makeParents = true })
	writeDocFile(dir, encodeDoc(testing.createDoc({ testing.task("a", "Before", "todo") })))
	local before = fs.readFileToString(getDocPath(dir))
	local after = testing.createDoc({ testing.task("a", "After", "todo") })
	after.revision = 1
	writeDocFile(dir, encodeDoc(after))

	local backups = getBackups(dir)
	assert.eq(#backups, 1)
	assert.eq(backups[1].revision, 0)
	assert.eq(backups[1].size, #before)
	assert.eq(fs.readFileToString(backups[1].file), before)
	assert.eq(loadDoc(dir).nodes[1].data.label, "After")

	writeDocFile(dir, encodeDoc(testing.createDoc({})))
	local replaced = getBackups(dir)
	assert.eq(#replaced, 2)
	assert.eq(replaced[1].revision, 1)
	assert.eq(decodeDoc(fs.readFileToString(replaced[1].file)).nodes[1].data.label, "After")
end)

test.case("each backup holds the exact revision it replaced", function(assert)
	local dir = testing.directory("backup-chain")
	local written: { [number]: string } = {}
	local doc = testing.createDoc({})
	fs.createDirectory(dir, { makeParents = true })

	for revision = 0, 4 do
		doc.revision = revision
		table.insert(doc.nodes, testing.task(`card-{revision}`, `Card {revision}`, "todo"))
		writeDocFile(dir, encodeDoc(doc))
		written[revision] = fs.readFileToString(getDocPath(dir))
	end

	local backups = getBackups(dir)
	assert.eq(#backups, 4)

	for _, backup in backups do
		assert.eq(fs.readFileToString(backup.file), written[backup.revision])
	end
end)

test.case("a backup that can't be written never blocks the write", function(assert)
	local dir = testing.directory("backup-blocked")
	fs.createDirectory(dir, { makeParents = true })
	writeDocFile(dir, encodeDoc(testing.createDoc({})))
	fs.writeStringToFile(path.join(dir, "backups"), "not a folder")

	writeDocFile(dir, encodeDoc(testing.createDoc({ testing.task("a", "A", "todo") })))
	assert.eq(loadDoc(dir).nodes[1].id, "a")
end)
