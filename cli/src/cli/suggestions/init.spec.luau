local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local graph = require("@root/graph")
local store = require("@root/store")
local suggest = require("@root/suggest")
local testing = require("@root/testing")

test.case("suggestions apply keeps links, marks layout pending, and prunes empty Unsorted", function(assert)
	local directory = testing.directory("suggest-apply")
	local doc = testing.createDoc({
		testing.group("unsorted", "Unsorted"),
		testing.task("a", "Avatar one", "todo", "unsorted", json.object({ repo = "app", branch = "same" })),
		testing.task("b", "Avatar two", "todo", "unsorted", json.object({ repo = "app", branch = "same" })),
	}, { { "a", "b" } })
	doc.links[1].origin = "mention"
	store.write(directory, doc)
	local output = {}

	local function run(args: { string })
		table.clear(output)
		cli.execute(args, {
			dataDirectory = directory,
			write = function(value)
				table.insert(output, value)
			end,
		})
		return table.concat(output)
	end

	run({ "suggest", "--dry-run" })
	assert.eq(store.load(directory).revision, 0)
	run({ "suggest" })
	assert.strContains(run({ "suggestions" }), "s1")
	run({ "suggestions", "apply", "s1" })
	local after = store.load(directory)
	assert.eq(after.revision, 2)
	assert.eq(graph.find(after, "unsorted"), nil)
	assert.eq(#after.links, 1)
	assert.eq(after.links[1].origin, "mention")
	assert.eq(after.nodes[1].parentId, after.nodes[3].id)
	assert.eq(after.nodes[2].parentId, after.nodes[3].id)
	assert.eq(after.nodes[3].data.layout, "pending")
	assert.eq(#suggest.getStored(after).groups, 0)
end)

test.case("suggestions apply and dismiss select their workspace", function(assert)
	local root, run = testing.createHarness("suggestions-workspace")
	run({ "workspace", "create", "roblox" })
	local directory = store.getWorkspaceDirectory(root, "roblox")

	local function saveSuggestion()
		store.write(
			directory,
			testing.createDoc({
				testing.task("a", "First work", "todo"),
				testing.task("b", "Second work", "todo"),
			})
		)
		store.transaction(directory, function(doc)
			suggest.save(doc, {
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
	assert.eq(run({ "suggestions" }), "No group suggestions.")
	assert.strContains(run({ "suggestions", "apply", "--all", "--workspace", "roblox" }), "Applied 1 suggestions")
	assert.eq(#suggest.getStored(store.load(directory)).groups, 0)
	assert.eq(#store.load(root).nodes, 3)
	saveSuggestion()
	assert.strContains(run({ "--workspace", "roblox", "suggestions", "dismiss", "s1" }), "Dismissed 1 suggestions")
	assert.eq(#suggest.getStored(store.load(directory)).groups, 0)
	assert.eq(#store.load(directory).nodes, 2)
end)
