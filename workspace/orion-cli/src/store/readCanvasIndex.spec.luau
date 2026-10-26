local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local getIndexPath = require("@root/store/getIndexPath")
local joinCanvasFiles = require("@root/store/joinCanvasFiles")
local readCanvasFolder = require("@root/store/readCanvasFolder")
local readCanvasIndex = require("@root/store/readCanvasIndex")
local runSqlite = require("@root/sqlite/runSqlite")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

local function read(dir: string): json.Object
	return (assert(readCanvasIndex(dir, false))).document
end

local function readSnapshot(dir: string)
	return assert(readCanvasIndex(dir, false))
end

local function readWithFiles(dir: string)
	return assert(readCanvasIndex(dir, true))
end

local function getLabel(document: json.Object, index: number): unknown
	local node = json.asObject((json.asArray(document.nodes) :: json.Array)[index]) :: json.Object
	return (json.asObject(node.data) :: json.Object).label
end

local function findNode(document: json.Object, id: string): json.Object
	for _, value in json.asArray(document.nodes) :: json.Array do
		local node = json.asObject(value) :: json.Object

		if node.id == id then
			return node
		end
	end

	error(`no node {id}`)
end

local function createCanvas(name: string): string
	local dir = testing.directory(name)
	local doc = testing.createDoc({ testing.task("b", "B", "todo"), testing.task("a", "A", "todo") }, { { "b", "a" } })
	doc.github = json.object({ viewer = "vocksel" })
	writeDoc(dir, doc)
	return dir
end

test.case("readCanvasIndex reads the same canvas as joining its files", function(assert)
	local dir = createCanvas("index-same")
	fs.writeStringToFile(path.join(dir, "nodes", "c.json"), [[{"id":"c","type":"note","position":{"x":0,"y":0}}]])
	fs.writeStringToFile(path.join(dir, "nodes", "0.json"), [[{"id":"0","type":"note","position":{"x":0,"y":0}}]])

	local snapshot = readWithFiles(dir)
	local files = readCanvasFolder(dir)

	local document, entries = joinCanvasFiles(files)
	assert.eq(snapshot.document, document)
	assert.eq(snapshot.entries, entries)
	assert.eq(getLabel(snapshot.document, 1), "B")
	assert.eq(snapshot.files, files)
	assert.eq((snapshot.document.github :: json.Object).viewer, "vocksel")
	assert.eq(fs.exists(getIndexPath(dir)), true)
end)

test.case("readCanvasIndex is nil for a folder without a canvas", function(assert)
	assert.eq(readCanvasIndex(testing.directory("index-missing"), false), nil)
end)

test.case("readCanvasIndex reads again only the files whose time changed", function(assert)
	local dir = createCanvas("index-changed")
	local database = getIndexPath(dir)
	read(dir)

	-- Marks every row as read a second after its file last changed, then gives
	-- `a` text its file doesn't have and `b` an older time. Only `b` is read
	-- again, so `a` keeps the text.
	runSqlite(
		database,
		[[
		UPDATE files SET checked = mtime + 1;
		UPDATE files SET text = json_set(text, '$.data.label', 'Indexed') WHERE path = 'nodes/a.json';
		UPDATE files SET mtime = mtime - 1, text = json_set(text, '$.data.label', 'Stale') WHERE path = 'nodes/b.json';
		]]
	)

	local document = read(dir)
	assert.eq(getLabel(document, 1), "B")
	assert.eq(getLabel(document, 2), "Indexed")

	fs.remove(database)
	assert.eq(getLabel(read(dir), 2), "A")
end)

test.case("readCanvasIndex drops files that went and adds files that came", function(assert)
	local dir = createCanvas("index-removed")
	read(dir)

	fs.remove(path.join(dir, "nodes", "b.json"))
	fs.remove(path.join(dir, "links", "b%3ea.json"))
	fs.writeStringToFile(path.join(dir, "nodes", "d.json"), [[{"id":"d","type":"note","position":{"x":0,"y":0}}]])

	local document = read(dir)
	local nodes = json.asArray(document.nodes) :: json.Array
	assert.eq(#nodes, 2)
	assert.eq((json.asObject(nodes[1]) :: json.Object).id, "a")
	assert.eq((json.asObject(nodes[2]) :: json.Object).id, "d")
	assert.eq(#(json.asArray(document.links) :: json.Array), 0)
end)

test.case("readCanvasIndex builds a damaged index again from the files", function(assert)
	local dir = createCanvas("index-damaged")
	read(dir)

	for _, suffix in { "", "-wal", "-shm" } do
		pcall(fs.remove, getIndexPath(dir) .. suffix)
	end

	fs.writeStringToFile(getIndexPath(dir), string.rep("not a database ", 100))
	assert.eq(getLabel(read(dir), 1), "B")
end)

local CONFLICTED = [[{
  "data": {
    "itemKind": "note",
    "kind": "task",
<<<<<<< HEAD
    "label": "B here",
    "note": "Ours",
=======
    "label": "B there",
    "note": "Theirs",
>>>>>>> origin/main
    "status": "todo"
  },
  "id": "b",
  "position": {"x": 0, "y": 0},
  "type": "task"
}]]

test.case("readCanvasIndex shows a note with a git conflict as a conflicted note", function(assert)
	local dir = createCanvas("index-conflict")
	fs.writeStringToFile(path.join(dir, "nodes", "b.json"), CONFLICTED)

	local snapshot = readSnapshot(dir)
	local data = json.asObject(findNode(snapshot.document, "b").data) :: json.Object

	assert.eq(data.label, "B here")
	assert.eq(data.note, "<<<<<<< HEAD\nOurs\n=======\nTheirs\n>>>>>>> origin/main")
	assert.eq(
		(snapshot.problems :: { string })[1],
		"nodes/b.json has a git conflict; kept HEAD's fields and both versions of its note"
	)
end)

test.case("readCanvasIndex keeps a node file that doesn't parse as a note holding its text", function(assert)
	local dir = createCanvas("index-unreadable")
	fs.writeStringToFile(path.join(dir, "nodes", "b.json"), "{ not json")

	local snapshot = readSnapshot(dir)
	local data = json.asObject(findNode(snapshot.document, "b").data) :: json.Object

	assert.eq(data.label, "Unreadable nodes/b.json")
	assert.strContains(data.note :: string, "{ not json")
	assert.strContains((snapshot.problems :: { string })[1], "nodes/b.json isn't a JSON object")
end)

test.case("readCanvasIndex still fails on a canvas.json that doesn't parse", function(assert)
	local dir = createCanvas("index-unreadable-canvas")
	fs.writeStringToFile(path.join(dir, "canvas.json"), '{"revision": ')

	local succeeded, failure = pcall(readCanvasIndex, dir, false)
	assert.eq(succeeded, false)
	assert.strContains(tostring(failure), "canvas.json isn't a JSON object")
end)

test.case("readCanvasIndex's fingerprint follows file changes the revision doesn't show", function(assert)
	local dir = createCanvas("index-fingerprint")
	local before = readSnapshot(dir).fingerprint
	local file = path.join(dir, "nodes", "a.json")
	fs.writeStringToFile(file, (fs.readFileToString(file):gsub('"A"', '"Pulled"')))

	local after = readSnapshot(dir)
	assert.neq(after.fingerprint, before)
	assert.eq(after.document.revision, 0)
	assert.eq(readSnapshot(dir).fingerprint, after.fingerprint)
end)
