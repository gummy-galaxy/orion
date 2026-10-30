local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local project = require("@repository/project")

local applyOperations = require("@root/operations/applyOperations")
local decodeDoc = require("@root/store/decodeDoc")
local getBackups = require("@root/store/getBackups")
local getDocPath = require("@root/store/getDocPath")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local loadDoc = require("@root/store/loadDoc")
local parseOperations = require("@root/operations/parseOperations")
local runTransaction = require("@root/store/runTransaction")
local setFields = require("@root/graph/setFields")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

test.case("transaction writes the data file on the first change", function(assert)
	local dir = testing.directory("first-change")
	runTransaction(dir, function(doc)
		table.insert(doc.nodes, testing.task("a", "A", "todo"))
	end)

	local reread = loadDoc(dir)
	assert.eq(reread.revision, 1)
	assert.eq(reread.nodes[1].id, "a")
	assert.eq(#getBackups(dir), 0)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("transaction bumps the revision and keeps fields it doesn't know about", function(assert)
	local dir = testing.directory("roundtrip")
	local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { future = "kept" }) })
	writeDoc(dir, doc)
	local after = runTransaction(dir, function(current)
		current.nodes[1].data.status = "done"
	end)

	assert.eq(after.revision, 1)
	local reread = loadDoc(dir)
	assert.eq(reread.revision, 1)
	assert.eq(reread.nodes[1].data.status, "done")
	assert.eq(reread.nodes[1].data.future, "kept")
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("transaction releases the lock when the change fails", function(assert)
	local dir = testing.directory("failure")
	writeDoc(dir, testing.createDoc({}))
	assert.throws(function()
		runTransaction(dir, function()
			error("nope")
		end)
	end)

	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
	assert.eq(loadDoc(dir).revision, 0)
end)

test.case("store keeps the canvas cover and background across later saves", function(assert)
	local dir = testing.directory("canvas-style-store")
	fs.createDirectory(path.join(dir, "assets"), { makeParents = true })
	fs.writeStringToFile(path.join(dir, "assets", "image-logo.png"), "bytes")
	runTransaction(dir, function(doc)
		doc.settings.cover = "image-logo.png"
		doc.settings.background = "#1d1b2e"
	end)
	local reread = loadDoc(dir)
	assert.eq(reread.settings.cover, "image-logo.png")
	assert.eq(reread.settings.background, "#1d1b2e")
	assert.eq(reread.revision, 1)
	runTransaction(dir, function(doc)
		doc.settings.background = nil
	end)
	local afterLaterSave = loadDoc(dir)
	assert.eq(afterLaterSave.settings.background, nil)
	assert.eq(afterLaterSave.settings.cover, "image-logo.png")
	assert.eq(afterLaterSave.revision, 2)
	assert.strContains(fs.readFileToString(getDocPath(dir)), '"cover": "image-logo.png"')
end)

test.case("a transaction flags a card that turns done and clears the flag on reopen", function(assert)
	local dir = testing.directory("celebrate-transaction")
	writeDoc(
		dir,
		testing.createDoc({ testing.task("a", "A", "active"), testing.task("b", "B", "todo") }, { { "a", "b" } })
	)

	runTransaction(dir, function(doc)
		setFields(doc, "a", { status = "done" })
	end)
	local finished = loadDoc(dir)
	assert.eq(finished.nodes[1].data.celebrate, true)
	assert.eq(finished.nodes[2].data.celebrate, nil)

	runTransaction(dir, function(doc)
		setFields(doc, "a", { status = "todo" })
	end)
	assert.eq(loadDoc(dir).nodes[1].data.celebrate, nil)
end)

test.case("a save flags the cards it finishes and leaves the rest without the flag", function(assert)
	local dir = testing.directory("celebrate-save")
	writeDoc(dir, testing.createDoc({ testing.task("a", "A", "active"), testing.task("b", "B", "todo") }))
	runTransaction(dir, function(doc)
		doc.nodes[1].data.status = "done"
	end)
	local saved = loadDoc(dir)
	assert.eq(saved.nodes[1].data.celebrate, true)
	assert.eq(saved.nodes[2].data.celebrate, nil)
end)

test.case("concurrent CLI writers never lose a change", function(assert)
	local root = testing.directory("concurrent-writers")
	local writers, writesEach = 6, 3
	local environment: { [string]: string } = {}

	for key, value in process.env do
		environment[key] = value
	end

	environment.ORION_DATA_DIR = root
	environment.ORION_CANVAS = nil

	-- Each writer adds its cards one at a time while the others do the same.
	local script = [[
for writer in $(seq 1 "$3"); do
	(for write in $(seq 1 "$4"); do output=$("$1" run "$2" card create "card-$writer-$write" --canvas default 2>&1) || { echo "$output" >&2; exit 1; }; done) &
done
failed=0
for job in $(jobs -p); do wait "$job" || failed=1; done
exit "$failed"
]]
	local result = process.run({
		"sh",
		"-c",
		script,
		"sh",
		tostring(process.execPath()),
		tostring(path.join(project.CLI_PATH, "cli.luau")),
		tostring(writers),
		tostring(writesEach),
	}, { env = environment })
	assert.eq(result.stderr, "")
	assert.eq(result.ok, true)

	local doc = loadDoc(getWorkspaceDir(root, "default"))
	local labels: { [string]: boolean } = {}

	for _, node in doc.nodes do
		labels[tostring(node.data.label)] = true
	end

	assert.eq(doc.revision, writers * writesEach)
	assert.eq(#doc.nodes, writers * writesEach)

	for writer = 1, writers do
		for write = 1, writesEach do
			assert.eq(labels[`card-{writer}-{write}`], true)
		end
	end
end)

test.case("a data file that can't be read refuses writes and stays as it was", function(assert)
	local unreadable: { [string]: string } = { truncated = '{"nodes": [', empty = "", array = "[]", null = "null" }

	for name, contents in unreadable do
		local dir = testing.directory(`unreadable-{name}`)
		fs.createDirectory(dir, { makeParents = true })
		fs.writeStringToFile(getDocPath(dir), contents)

		assert.throws(function()
			runTransaction(dir, function(doc)
				table.insert(doc.nodes, testing.task("a", "A", "todo"))
			end)
		end)

		assert.eq(fs.readFileToString(getDocPath(dir)), contents)
		assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
		assert.eq(#getBackups(dir), 0)
	end
end)

test.case("an operation list from the app keeps what other writers own", function(assert)
	local dir = testing.directory("save-keeps-others")
	fs.createDirectory(dir, { makeParents = true })
	testing.writeCanvasText(
		dir,
		[[{"version":2,"revision":4,"settings":{"sources":[{"id":"gh","kind":"github","owners":["vocksel"]}]},"github":{"viewer":"vocksel"},"future":{"kept":true},"nodes":[],"links":[]}]]
	)

	local doc = runTransaction(dir, function(current)
		applyOperations(
			current,
			parseOperations({
				json.object({ op = "addCard", id = "a", x = 0, y = 0, data = json.object({ label = "A" }) }),
			})
		)
	end)
	assert.eq(doc.revision, 5)

	local saved = json.asObject(json.deserialize(testing.readCanvasText(dir)) :: json.Value) :: json.Object
	local settings = json.asObject(saved.settings) :: json.Object
	local sources = json.asArray(settings.sources) :: json.Array
	assert.eq((json.asObject(sources[1]) :: json.Object).id, "gh")
	assert.eq((json.asObject(saved.github) :: json.Object).viewer, "vocksel")
	assert.eq((json.asObject(saved.future) :: json.Object).kept, true)
	assert.eq(#(json.asArray(saved.nodes) :: json.Array), 1)
end)

test.case("an operation list closes out the cards the app finished and closed out at once", function(assert)
	local dir = testing.directory("celebrate-closed-out")
	writeDoc(
		dir,
		testing.createDoc({
			testing.task("a", "A", "active"),
			testing.task("b", "B", "done", nil, { celebrate = true }),
		})
	)
	local edits: json.Array = {}

	for _, id in { "a", "b" } do
		table.insert(edits, json.object({ op = "setFields", id = id, fields = json.object({ status = "done" }) }))
		table.insert(edits, json.object({ op = "closeOut", id = id }))
	end

	runTransaction(dir, function(doc)
		applyOperations(doc, parseOperations(edits))
	end)
	local saved = loadDoc(dir)
	assert.eq(saved.nodes[1].data.celebrate, nil)
	assert.eq(saved.nodes[2].data.celebrate, nil)
	assert.strNotContains(testing.readCanvasText(dir), "celebrate")
end)

test.case("a transaction backs up the revision it replaces", function(assert)
	local dir = testing.directory("transaction-backup")
	writeDoc(dir, testing.createDoc({ testing.task("a", "Before", "todo") }))
	runTransaction(dir, function(doc)
		doc.nodes[1].data.label = "After"
	end)

	local backups = getBackups(dir)
	assert.eq(#backups, 1)
	assert.eq(backups[1].revision, 0)
	assert.eq(decodeDoc(fs.readFileToString(backups[1].file)).nodes[1].data.label, "Before")
	assert.eq(loadDoc(dir).nodes[1].data.label, "After")
end)
