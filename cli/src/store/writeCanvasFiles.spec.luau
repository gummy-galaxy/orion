local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local task = require("@std/task")
local test = require("@std/test")

local decodeDoc = require("@root/store/decodeDoc")
local encodeDocObject = require("@root/store/encodeDocObject")
local getBackups = require("@root/store/getBackups")
local getDocPath = require("@root/store/getDocPath")
local loadDoc = require("@root/store/loadDoc")
local readCanvasFiles = require("@root/store/readCanvasFiles")
local testing = require("@root/testing")
local writeCanvasFiles = require("@root/store/writeCanvasFiles")

local function write(dir: string, doc)
	writeCanvasFiles(dir, encodeDocObject(doc), readCanvasFiles(dir))
end

local function modifiedAt(file: path.Pathlike): number
	return fs.metadata(file).modified:toNanoseconds()
end

test.case("writeCanvasFiles writes one file per node and link beside canvas.json", function(assert)
	local dir = testing.directory("canvas-files")
	local doc = testing.createDoc({ testing.task("a", "A", "todo"), testing.task("b", "B", "todo") }, { { "a", "b" } })
	doc.github = json.object({ viewer = "vocksel" })
	write(dir, doc)

	assert.eq(fs.exists(getDocPath(dir)), true)
	assert.eq(fs.exists(path.join(dir, "nodes", "a.json")), true)
	assert.eq(fs.exists(path.join(dir, "nodes", "b.json")), true)
	assert.eq(fs.exists(path.join(dir, "links", "a%3eb.json")), true)
	assert.strContains(fs.readFileToString(path.join(dir, "local.json")), '"viewer": "vocksel"')
	assert.strNotContains(fs.readFileToString(getDocPath(dir)), "viewer")
	assert.strNotContains(fs.readFileToString(getDocPath(dir)), '"label"')
	assert.eq(fs.exists(path.join(dir, "orion.writing")), false)

	local saved = loadDoc(dir)
	assert.eq(#saved.nodes, 2)
	assert.eq(saved.links[1].id, "a>b")
	assert.eq((saved.github :: json.Object).viewer, "vocksel")
end)

test.case("writeCanvasFiles rewrites only the files that changed and removes the ones that went", function(assert)
	local dir = testing.directory("canvas-files-changed")
	local doc = testing.createDoc({ testing.task("a", "A", "todo"), testing.task("b", "B", "todo") }, { { "a", "b" } })
	write(dir, doc)

	local untouched = path.join(dir, "nodes", "a.json")
	local before = modifiedAt(untouched)
	doc.nodes[2].data.label = "Changed"
	table.remove(doc.links, 1)
	doc.revision = 1
	write(dir, doc)

	assert.eq(modifiedAt(untouched), before)
	assert.strContains(fs.readFileToString(path.join(dir, "nodes", "b.json")), "Changed")
	assert.eq(fs.exists(path.join(dir, "links", "a%3eb.json")), false)
	assert.eq(loadDoc(dir).revision, 1)
end)

test.case("canvas files keep node order and sorted keys", function(assert)
	local dir = testing.directory("canvas-files-order")
	write(dir, testing.createDoc({ testing.task("c", "C", "todo"), testing.task("a", "A", "todo") }))

	local saved = loadDoc(dir)
	assert.eq(saved.nodes[1].id, "c")
	assert.eq(saved.nodes[2].id, "a")

	local text = fs.readFileToString(path.join(dir, "nodes", "a.json"))
	assert.eq(text:sub(-1), "\n")
	local data, id, position = text:find('\n  "data"'), text:find('\n  "id"'), text:find('\n  "position"')
	assert.eq((data :: number) < (id :: number) and (id :: number) < (position :: number), true)
end)

test.case("a node file that arrives without Orion joins the canvas after the listed ones", function(assert)
	local dir = testing.directory("canvas-files-arrived")
	write(dir, testing.createDoc({ testing.task("b", "B", "todo") }))
	fs.writeStringToFile(
		path.join(dir, "nodes", "a.json"),
		[[{"id":"a","type":"task","position":{"x":0,"y":0},"data":{"label":"A"}}]]
	)

	local saved = loadDoc(dir)
	assert.eq(saved.nodes[1].id, "b")
	assert.eq(saved.nodes[2].id, "a")
end)

test.case("writeCanvasFiles saves the whole canvas it replaces as one backup", function(assert)
	local dir = testing.directory("canvas-files-backup")
	write(dir, testing.createDoc({ testing.task("a", "Before", "todo") }))
	assert.eq(#getBackups(dir), 0)

	local after = testing.createDoc({ testing.task("a", "After", "todo") })
	after.revision = 1
	write(dir, after)

	local backups = getBackups(dir)
	assert.eq(#backups, 1)
	assert.eq(backups[1].revision, 0)
	assert.eq(decodeDoc(fs.readFileToString(backups[1].file)).nodes[1].data.label, "Before")
	assert.eq(loadDoc(dir).nodes[1].data.label, "After")
end)

test.case("each backup holds the exact revision it replaced", function(assert)
	local dir = testing.directory("backup-chain")
	local doc = testing.createDoc({})

	for revision = 0, 4 do
		doc.revision = revision
		table.insert(doc.nodes, testing.task(`card-{revision}`, `Card {revision}`, "todo"))
		write(dir, doc)
	end

	local backups = getBackups(dir)
	assert.eq(#backups, 4)

	for _, backup in backups do
		local saved = decodeDoc(fs.readFileToString(backup.file))
		assert.eq(saved.revision, backup.revision)
		assert.eq(#saved.nodes, backup.revision + 1)
	end
end)

test.case("a backup that can't be written never blocks the write", function(assert)
	local dir = testing.directory("backup-blocked")
	write(dir, testing.createDoc({}))
	fs.writeStringToFile(path.join(dir, "backups"), "not a folder")

	write(dir, testing.createDoc({ testing.task("a", "A", "todo") }))
	assert.eq(loadDoc(dir).nodes[1].id, "a")
end)

test.case("a marker left without the lock doesn't hold up readers", function(assert)
	local dir = testing.directory("canvas-files-stale-marker")
	write(dir, testing.createDoc({ testing.task("a", "A", "todo") }))
	fs.writeStringToFile(path.join(dir, "orion.writing"), "1")

	assert.eq(loadDoc(dir).nodes[1].id, "a")
end)

test.case("a read waits out a write in progress", function(assert)
	local dir = testing.directory("canvas-files-in-progress")
	write(dir, testing.createDoc({ testing.task("a", "Before", "todo") }))
	fs.createDirectory(path.join(dir, "orion.lock"))
	fs.writeStringToFile(path.join(dir, "orion.writing"), "1")

	task.delay(0.1, function()
		local after = testing.createDoc({ testing.task("a", "After", "todo") })
		after.revision = 1
		writeCanvasFiles(dir, encodeDocObject(after), nil)
		fs.removeDirectory(path.join(dir, "orion.lock"), { recursive = true })
	end)

	local saved = loadDoc(dir)
	assert.eq(saved.revision, 1)
	assert.eq(saved.nodes[1].data.label, "After")
end)
