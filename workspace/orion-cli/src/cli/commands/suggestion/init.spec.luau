local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local findItem = require("@root/canvas/items/findItem")
local getStored = require("@root/canvas/suggestions/getStored")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local loadDoc = require("@root/storage/canvases/loadDoc")
local runTransaction = require("@root/storage/transactions/runTransaction")
local save = require("@root/canvas/suggestions/save")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

test.case("suggestions apply keeps links, marks layout pending, and prunes empty Unsorted", function(assert)
	local dir = testing.directory("suggest-apply")
	local doc = testing.createDoc({
		testing.group("unsorted", "Unsorted"),
		testing.task(
			"a",
			"Avatar one",
			"todo",
			"unsorted",
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } },
			})
		),
		testing.task(
			"b",
			"Avatar two",
			"todo",
			"unsorted",
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } },
			})
		),
	}, { { "a", "b" } })
	doc.links[1].origin = "mention"
	writeDoc(dir, doc)
	local output = {}

	local function run(args: { string })
		table.clear(output)
		cli.execute(args, {
			dataDir = dir,
			write = function(value)
				table.insert(output, value)
			end,
		})
		return table.concat(output)
	end

	run({ "suggestion", "find", "--dry-run" })
	assert.eq(loadDoc(dir).revision, 0)
	run({ "suggestion", "find" })
	assert.strContains(run({ "suggestion", "list" }), "s1")
	run({ "suggestion", "apply", "s1" })
	local after = loadDoc(dir)
	assert.eq(after.revision, 2)
	assert.eq(findItem(after, "unsorted"), nil)
	assert.eq(#after.links, 1)
	assert.eq(after.links[1].origin, "mention")
	assert.eq(after.nodes[1].parentId, after.nodes[3].id)
	assert.eq(after.nodes[2].parentId, after.nodes[3].id)
	assert.eq(after.nodes[3].data.layout, "pending")
	assert.eq(#getStored(after).groups, 0)
end)

test.case("suggestions apply and dismiss select their workspace", function(assert)
	local root, run = testing.createHarness("suggestions-workspace")
	run({ "canvas", "create", "roblox" })
	local dir = getWorkspaceDir(root, "roblox")

	local function saveSuggestion()
		writeDoc(
			dir,
			testing.createDoc({
				testing.task("a", "First work", "todo"),
				testing.task("b", "Second work", "todo"),
			})
		)
		runTransaction(dir, function(doc)
			save(doc, {
				createdAt = "2026-10-04T00:00:00Z",
				groups = {
					{
						id = "s1",
						title = "Related work",
						members = { "a", "b" },
						reason = "Linked work",
						source = "heuristic",
					},
				},
			})
		end)
	end

	saveSuggestion()
	assert.eq(run({ "suggestion", "list" }), "No group suggestions.")
	assert.strContains(run({ "suggestion", "apply", "--all", "--canvas", "roblox" }), "Applied 1 suggestions")
	assert.eq(#getStored(loadDoc(dir)).groups, 0)
	assert.eq(#loadDoc(root).nodes, 3)
	saveSuggestion()
	assert.strContains(run({ "--canvas", "roblox", "suggestion", "dismiss", "s1" }), "Dismissed 1 suggestions")
	assert.eq(#getStored(loadDoc(dir)).groups, 0)
	assert.eq(#loadDoc(dir).nodes, 2)
end)
