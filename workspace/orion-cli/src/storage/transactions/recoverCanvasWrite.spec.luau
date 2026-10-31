local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local getIndexPath = require("@root/storage/index/getIndexPath")
local loadDoc = require("@root/storage/canvases/loadDoc")
local recoverCanvasWrite = require("@root/storage/transactions/recoverCanvasWrite")
local runSqlite = require("@root/storage/index/runSqlite")
local runTransaction = require("@root/storage/transactions/runTransaction")
local testing = require("@root/testing")
local types = require("@root/types")
local writeDoc = require("@root/storage/canvases/writeDoc")

type Doc = types.Doc

local function createCanvas(name: string): string
	local dir = testing.directory(name)
	writeDoc(
		dir,
		testing.createDoc({
			testing.task("a", "A", "todo"),
			testing.task("b", "B", "todo"),
			testing.task("c", "C", "todo"),
		})
	)
	return dir
end

local function relabel(dir: string, suffix: string)
	runTransaction(dir, function(doc)
		for _, node in doc.nodes do
			node.data.label = `{node.id}{suffix}`
		end
	end)
end

local function getLabels(dir: string): string
	local labels = {}

	for _, node in loadDoc(dir).nodes do
		table.insert(labels, node.data.label :: string)
	end

	return table.concat(labels, ",")
end

local function countUnfinished(dir: string): unknown
	local rows = runSqlite(getIndexPath(dir), "SELECT count(*) AS count FROM operations WHERE finishedAt IS NULL;")
	return (json.asObject(rows[1]) :: json.Object).count
end

test.case("a write killed between files comes back whole", function(assert)
	local dir = createCanvas("recover-killed")

	-- A folder where the new card's file goes stops the write after the other
	-- files moved into place, as a kill would. Reads skip folders, so the write
	-- still sees the canvas as it was.
	local blocked = path.join(dir, "nodes", "d.json")
	fs.createDirectory(path.join(blocked, "in-the-way"), { makeParents = true })

	local succeeded = pcall(runTransaction, dir, function(doc: Doc)
		for _, node in doc.nodes do
			node.data.label = `{node.id} after`
		end

		table.insert(doc.nodes, testing.task("d", "d new", "todo"))
	end)
	assert.eq(succeeded, false)

	-- The killed writer also leaves its lock, long enough ago that the next one
	-- may take it.
	local lock = path.join(dir, "orion.lock")
	fs.createDirectory(lock)
	fs.writeStringToFile(path.join(lock, "owner"), `999999 {os.time() - 3600}`)
	fs.removeDirectory(blocked, { recursive = true })

	assert.strContains(fs.readFileToString(path.join(dir, "nodes", "c.json")), "c after")
	assert.strContains(fs.readFileToString(path.join(dir, "local.json")), '"revision": 0')
	assert.eq(countUnfinished(dir), 1)

	assert.eq(getLabels(dir), "a after,b after,c after,d new")
	assert.eq(loadDoc(dir).revision, 1)
	assert.eq(fs.exists(path.join(dir, "orion.writing")), false)
	assert.eq(fs.exists(lock), false)
	assert.eq(countUnfinished(dir), 0)

	relabel(dir, " later")
	assert.eq(getLabels(dir), "a later,b later,c later,d later")
end)

test.case("a write that stopped before journaling leaves the canvas as it was", function(assert)
	local dir = createCanvas("recover-unjournaled")
	fs.writeStringToFile(path.join(dir, "orion.writing"), "999999")

	recoverCanvasWrite(dir)

	assert.eq(fs.exists(path.join(dir, "orion.writing")), false)
	assert.eq(getLabels(dir), "A,B,C")
end)

test.case("a finished write records its files in the index", function(assert)
	local dir = createCanvas("recover-finished")
	relabel(dir, " next")

	local rows = runSqlite(getIndexPath(dir), "SELECT text FROM files WHERE path = 'nodes/b.json';")
	assert.eq((json.asObject(rows[1]) :: json.Object).text, fs.readFileToString(path.join(dir, "nodes", "b.json")))
	assert.eq(countUnfinished(dir), 0)
end)

test.case("a journaled write without its marker is never replayed over later writes", function(assert)
	local dir = createCanvas("recover-stale")
	runSqlite(
		getIndexPath(dir),
		[[INSERT INTO operations (startedAt, batch) VALUES ('2026-01-01T00:00:00Z', ]]
			.. [['{"writes":{"nodes/a.json":"{\"id\":\"a\"}"},"removes":[]}');]]
	)

	relabel(dir, " newer")
	fs.writeStringToFile(path.join(dir, "orion.writing"), "999999")
	recoverCanvasWrite(dir)

	assert.eq(getLabels(dir), "a newer,b newer,c newer")
	assert.eq(countUnfinished(dir), 0)
end)
