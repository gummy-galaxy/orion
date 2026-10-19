local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local addItem = require("@root/graph/addItem")
local getItem = require("@root/graph/getItem")
local linkItems = require("@root/graph/linkItems")
local loadDoc = require("@root/store/loadDoc")
local runTransaction = require("@root/store/runTransaction")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

-- What stays on this machine, as a canvas folder in a repository would ignore it.
local IGNORED = "local.json\norion.lock\norion.writing\nbackups/\n"

local function git(dir: string, arguments: { string }): string
	local command =
		{ "git", "-c", "user.name=Orion", "-c", "user.email=orion@example.com", "-c", "commit.gpgsign=false" }
	table.move(arguments, 1, #arguments, #command + 1, command)

	local result = process.run(command, { cwd = dir })
	assert(result.ok, `git {table.concat(arguments, " ")} failed: {result.stdout}{result.stderr}`)
	return result.stdout
end

local function commit(dir: string, message: string)
	git(dir, { "add", "--all" })
	git(dir, { "commit", "--quiet", "--message", message })
end

local function changedFiles(dir: string): string
	return git(dir, { "diff", "--name-only", "HEAD~1", "HEAD" })
end

test.case("two branches that edit and add separate cards merge in git without a conflict", function(assert)
	local dir = testing.directory("canvas-git-merge")
	fs.createDirectory(dir, { makeParents = true })
	writeDoc(
		dir,
		testing.createDoc({ testing.task("a", "A", "todo"), testing.task("b", "B", "todo") }, { { "a", "b" } })
	)
	fs.writeStringToFile(path.join(dir, ".gitignore"), IGNORED)
	git(dir, { "init", "--quiet", "--initial-branch", "main" })
	commit(dir, "Start the canvas")

	git(dir, { "checkout", "--quiet", "-b", "left" })
	local left = ""
	runTransaction(dir, function(doc)
		getItem(doc, "a").data.label = "A from the left"
		left = addItem(doc, "Added on the left", {}).id
	end)
	commit(dir, "Edit on the left")

	local leftFiles = changedFiles(dir)
	assert.strContains(leftFiles, "nodes/a.json")
	assert.strNotContains(leftFiles, "canvas.json")
	assert.strNotContains(leftFiles, "nodes/b.json")

	git(dir, { "checkout", "--quiet", "main" })
	git(dir, { "checkout", "--quiet", "-b", "right" })
	local right = ""
	runTransaction(dir, function(doc)
		getItem(doc, "b").data.status = "done"
		right = addItem(doc, "Added on the right", {}).id
		linkItems(doc, "b", right, "blocks")
	end)
	commit(dir, "Edit on the right")
	assert.strNotContains(changedFiles(dir), "canvas.json")

	git(dir, { "checkout", "--quiet", "left" })
	git(dir, { "merge", "--quiet", "--no-edit", "right" })

	local doc = loadDoc(dir)
	assert.eq(#doc.nodes, 4)
	assert.eq(#doc.links, 2)
	assert.eq(getItem(doc, "a").data.label, "A from the left")
	assert.eq(getItem(doc, "b").data.status, "done")
	assert.eq(getItem(doc, left).data.label, "Added on the left")
	assert.eq(getItem(doc, right).data.label, "Added on the right")
end)
